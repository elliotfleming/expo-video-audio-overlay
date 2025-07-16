// android/src/main/java/expo/modules/videoaudiooverlay/ExpoVideoAudioOverlayModule.kt

package expo.modules.videoaudiooverlay

import android.media.*
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlinx.coroutines.*
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID

class ExpoVideoAudioOverlayModule : Module() {
  // Keep jobs so JS can cancel them.
  private val jobs = mutableMapOf<String, Job>()

  override fun definition() = ModuleDefinition {
    Name("ExpoVideoAudioOverlay")
    Events("progress", "error")

    AsyncFunction("overlayAudio") { opts: Map<String, Any>, promise: Promise ->
      val taskId = UUID.randomUUID().toString()
      val job = CoroutineScope(Dispatchers.IO).launch {
        try {
          val p = Params(opts)
          overlayInternal(p, taskId)
          promise.resolve(p.output)
        } catch (t: Throwable) {
          sendEvent("error", mapOf("taskId" to taskId, "message" to t.message))
          promise.reject("OVERLAY_ERROR", t)
        } finally {
          jobs.remove(taskId)
        }
      }
      jobs[taskId] = job
    }

    AsyncFunction("cancel") { taskId: String, promise: Promise ->
      jobs.remove(taskId)?.cancel()
      promise.resolve(null)
    }
  }

  // ---------- Params ----------

  private data class Params(
    val video: String,
    val audio: String,
    val output: String,
    val loop: Boolean,
    val audioStartOffsetUs: Long,
    val originalAudio: String
  ) {
    constructor(m: Map<String, Any>) : this(
      video  = m["video"]  as String,
      audio  = m["audio"]  as String,
      output = m["output"] as String,
      loop   = m["loop"] as? Boolean ?: true,
      audioStartOffsetUs = (((m["audioStartOffset"] ?: 0) as Number).toDouble() * 1_000_000L).toLong(),
      originalAudio = (m["originalAudio"] as? String ?: "mix").lowercase()
    )
  }

  // ---------- Core work ----------

  private fun overlayInternal(p: Params, taskId: String) {
    File(p.output).delete()

    val videoEx = MediaExtractor().apply { setDataSource(p.video) }
    val audioEx = MediaExtractor().apply { setDataSource(p.audio) }

    val muxer = MediaMuxer(p.output, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

    val vIdx = selectTrack(videoEx, "video/")
    val vFmt = videoEx.getTrackFormat(vIdx)
    val muxV = muxer.addTrack(vFmt)
    val vidDur = vFmt.getLong(MediaFormat.KEY_DURATION)

    val aSrcIdx = selectTrack(audioEx, "audio/")
    val aFmt = audioEx.getTrackFormat(aSrcIdx)
    val muxA = muxer.addTrack(aFmt)
    val audDur = aFmt.getLong(MediaFormat.KEY_DURATION)

    // Optional: bring original audio from the video
    val vAudIdx = if (p.originalAudio == "mix")
      selectTrack(videoEx, "audio/", true) else -1

    muxer.start()

    // Copy video
    copyTrack(videoEx, muxer, muxV, 0, vidDur) { pts ->
      sendEvent("progress", mapOf("taskId" to taskId, "progress" to pts.toFloat() / (2f * vidDur)))
    }

    // Copy original soundtrack if requested
    if (vAudIdx != -1) {
      copyTrack(videoEx, muxer, muxA, 0, vidDur, vAudIdx)
    }

    // Loop overlay audio
    var dstTime = p.audioStartOffsetUs
    while (dstTime < vidDur) {
      copyTrack(audioEx, muxer, muxA, dstTime, audDur, aSrcIdx)
      dstTime += audDur
      if (!p.loop) break
    }

    muxer.stop(); muxer.release()
    videoEx.release(); audioEx.release()

    sendEvent("progress", mapOf("taskId" to taskId, "progress" to 1))
  }

  // ---------- Helpers ----------

  private fun selectTrack(ex: MediaExtractor, mimePrefix: String, allowNone: Boolean = false): Int {
    for (i in 0 until ex.trackCount) {
      val mime = ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
      if (mime.startsWith(mimePrefix)) {
        ex.selectTrack(i)
        return i
      }
    }
    if (allowNone) return -1
    throw IllegalStateException("Track $mimePrefix not found in source")
  }

  private fun copyTrack(
    ex: MediaExtractor,
    muxer: MediaMuxer,
    dstTrack: Int,
    dstStartUs: Long,
    maxDurUs: Long,
    trackOverride: Int? = null,
    onProgress: ((Long) -> Unit)? = null
  ) {
    val idx = trackOverride ?: ex.sampleTrackIndex
    ex.unselectTrack(idx)
    ex.selectTrack(idx)
    ex.seekTo(0, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

    val buffer = ByteBuffer.allocate(1 * 1024 * 1024)
    val info = MediaCodec.BufferInfo()
    var writtenUs = 0L
    while (true) {
      val sz = ex.readSampleData(buffer, 0)
      if (sz < 0) break
      info.apply {
        offset = 0
        size = sz
        flags = ex.sampleFlags
        presentationTimeUs = ex.sampleTime + dstStartUs
      }
      if (info.presentationTimeUs - dstStartUs >= maxDurUs) break
      muxer.writeSampleData(dstTrack, buffer, info)
      writtenUs = info.presentationTimeUs
      onProgress?.invoke(writtenUs)
      ex.advance()
    }
    ex.unselectTrack(idx)
  }
}
