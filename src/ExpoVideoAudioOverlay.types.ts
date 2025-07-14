// src/ExpoVideoAudioOverlay.types.ts

// Events the native layer may emit.
export interface ExpoVideoAudioOverlayModuleEvents {
  // Emits `{ taskId, progress /* 0‒1 */ }` roughly every 250 ms.
  progress: { taskId: string; progress: number }
  // Fires once per task if an error bubbles up from native.
  error: { taskId: string; message: string }
  // Satisfy EventsMap type
  [eventName: string]: any
}

/** Options for the overlayAudio operation. */
export interface OverlayOptions {
  // Required: absolute/local URI of the source video.
  video: string

  // Required: absolute/local URI of the audio file to lay over.
  audio: string

  // Where to write the new asset (will be overwritten).
  output: string

  /**
   * If true (default), the audio is looped until it meets or exceeds
   * the video duration, then trimmed to match the final frame.
   */
  loop?: boolean

  /**
   * Offset (in seconds) where the audio should **start** relative to
   * the beginning of the video. Negative values delay the audio.
   * Defaults to `0`.
   */
  audioStartOffset?: number

  // Volume (linear 0 – 1). Defaults to `1`.
  volume?: number

  /**
   * What to do with the existing video soundtrack, if any.
   *  - "mix" (default) – combine original + new audio
   *  - "replace" – drop original track entirely
   *  - "mute" – keep the track but silence it
   */
  originalAudio?: 'mix' | 'replace' | 'mute'

  /**
   * Container/codec choice; let native fall back to the platform                       *
   * default if omitted.
   */
  container?: 'mp4' | 'mov'
}
