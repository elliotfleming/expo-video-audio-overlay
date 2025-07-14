// src/ExpoVideoAudioOverlayModule.ts

import { NativeModule, requireNativeModule } from 'expo'
import { OverlayOptions, ExpoVideoAudioOverlayModuleEvents } from './ExpoVideoAudioOverlay.types'

declare class ExpoVideoAudioOverlayModule extends NativeModule<ExpoVideoAudioOverlayModuleEvents> {
  overlayAudio(options: OverlayOptions): Promise<string>
  cancel(taskId: string): Promise<void>
}

export default requireNativeModule<ExpoVideoAudioOverlayModule>('ExpoVideoAudioOverlay')
