// src/index.ts

export { default } from './ExpoVideoAudioOverlayModule'
export * from './ExpoVideoAudioOverlay.types'

import ExpoVideoAudioOverlayModule from './ExpoVideoAudioOverlayModule'
import type { OverlayOptions } from './ExpoVideoAudioOverlay.types'

/**
 * Overlay (and optionally loop) an audio track on top of a video.
 * Resolves with an absolute path to the newly-created file.
 */
export function overlayAudio(options: OverlayOptions): Promise<string> {
  return ExpoVideoAudioOverlayModule.overlayAudio(options)
}
