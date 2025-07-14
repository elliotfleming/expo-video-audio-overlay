// ios/ExpoVideoAudioOverlayModule.swift

import AVFoundation
import ExpoModulesCore

public class ExpoVideoAudioOverlayModule: Module {
  // Keep track of live exports so JS can cancel
  private static var exports: [String: AVAssetExportSession] = [:]

  public func definition() -> ModuleDefinition {
    Name("ExpoVideoAudioOverlay")
    Events("progress", "error")

    AsyncFunction("overlayAudio") { (options: [String: Any]) async throws -> String in
      let params = try OverlayParams(dict: options)
      let taskId = UUID().uuidString

      return try await withCheckedThrowingContinuation { continuation in
        Task(priority: .userInitiated) {
          do {
            try await Self.runOverlay(params: params, module: self, taskId: taskId)
            continuation.resume(returning: params.output)
          } catch {
            self.sendEvent("error", ["taskId": taskId, "message": error.localizedDescription])
            continuation.resume(throwing: error)
          }
        }
      }
    }

    AsyncFunction("cancel") { (taskId: String) -> Void in
      Self.exports[taskId]?.cancelExport()
      Self.exports.removeValue(forKey: taskId)
    }
  }

  // MARK: - Core work

  private static func runOverlay(
    params p: OverlayParams, module: ExpoVideoAudioOverlayModule, taskId: String
  ) async throws {
    // Clean existing output
    try? FileManager.default.removeItem(atPath: p.output)

    let videoAsset = AVURLAsset(url: URL(fileURLWithPath: p.video))
    let audioAsset = AVURLAsset(url: URL(fileURLWithPath: p.audio))

    let comp = AVMutableComposition()
    guard
      let videoTrack = videoAsset.tracks(withMediaType: .video).first,
      let videoCompTrack = comp.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else {
      throw NSError(
        domain: "ExpoVideoAudioOverlay", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "No video track"])
    }

    try videoCompTrack.insertTimeRange(
      CMTimeRange(start: .zero, duration: videoAsset.duration),
      of: videoTrack,
      at: .zero)

    if p.originalAudio == "mix" {
      for t in videoAsset.tracks(withMediaType: .audio) {
        if let dst = comp.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        {
          try? dst.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoAsset.duration), of: t, at: .zero)
        }
      }
    }

    if let audioSrcTrack = audioAsset.tracks(withMediaType: .audio).first,
      let audioDstTrack = comp.addMutableTrack(
        withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    {

      let vidDur = videoAsset.duration
      let audDur = audioAsset.duration
      var insertTime = CMTime(
        seconds: max(p.audioStartOffset, 0), preferredTimescale: vidDur.timescale)

      while insertTime < vidDur {
        let remaining = CMTimeSubtract(vidDur, insertTime)
        let range =
          remaining < audDur
          ? CMTimeRange(start: .zero, duration: remaining)
          : CMTimeRange(start: .zero, duration: audDur)
        try? audioDstTrack.insertTimeRange(range, of: audioSrcTrack, at: insertTime)
        if !p.loop { break }
        insertTime = CMTimeAdd(insertTime, audDur)
      }
    }

    let exporter = AVAssetExportSession(
      asset: comp,
      presetName: AVAssetExportPresetHighestQuality)!
    exporter.outputURL = URL(fileURLWithPath: p.output)
    exporter.outputFileType = p.container == "mov" ? .mov : .mp4

    exports[taskId] = exporter

    // Progress polling
    let poll = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
    poll.schedule(deadline: .now(), repeating: .milliseconds(250))
    poll.setEventHandler {
      module.sendEvent("progress", ["taskId": taskId, "progress": exporter.progress])
    }
    poll.resume()

    try await withCheckedThrowingContinuation { cont in
      exporter.exportAsynchronously {
        poll.cancel()
        exports.removeValue(forKey: taskId)

        switch exporter.status {
        case .completed:
          cont.resume(returning: ())
        case .cancelled:
          cont.resume(
            throwing: NSError(
              domain: "ExpoVideoAudioOverlay", code: 2,
              userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
        default:
          cont.resume(
            throwing: exporter.error
              ?? NSError(
                domain: "ExpoVideoAudioOverlay", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))
        }
      }
    }
  }

  // MARK: - Params

  private struct OverlayParams {
    let video: String
    let audio: String
    let output: String
    let loop: Bool
    let audioStartOffset: Double
    let volume: Float  // Currently unused; ready for AudioMix
    let originalAudio: String
    let container: String

    init(dict: [String: Any]) throws {
      guard
        let video = dict["video"] as? String,
        let audio = dict["audio"] as? String,
        let output = dict["output"] as? String
      else {
        throw NSError(
          domain: "ExpoVideoAudioOverlay", code: 0,
          userInfo: [NSLocalizedDescriptionKey: "Missing required options"])
      }
      self.video = Self.clean(video)
      self.audio = Self.clean(audio)
      self.output = Self.clean(output)

      self.loop = dict["loop"] as? Bool ?? true
      self.audioStartOffset = (dict["audioStartOffset"] as? NSNumber)?.doubleValue ?? 0
      self.volume = (dict["volume"] as? NSNumber)?.floatValue ?? 1
      self.originalAudio = (dict["originalAudio"] as? String)?.lowercased() ?? "mix"
      self.container = (dict["container"] as? String)?.lowercased() ?? "mp4"
    }

    private static func clean(_ path: String) -> String {
      if let url = URL(string: path), url.scheme == "file" { return url.path }
      return path
    }
  }
}
