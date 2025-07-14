# Expo Video Audio Overlay

[![npm version](https://badge.fury.io/js/expo-video-audio-overlay.svg)](https://badge.fury.io/js/expo-video-audio-overlay) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**On-device video + audio overlay for React-Native & Expo**

*No FFmpeg • No GPL • Just the platform media APIs — `AVMutableComposition` (iOS) & `MediaMuxer` (Android)*

## Table of Contents

- [Expo Video Audio Overlay](#expo-video-audio-overlay)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Installation](#installation)
  - [Usage](#usage)
    - [API](#api)
  - [Troubleshooting](#troubleshooting)
  - [Contributing](#contributing)
  - [License](#license)

## Features

* **Offline** – runs entirely on-device, no upload required
* **Tiny footprint** – adds ≈150 kB native code, zero third-party binaries
* **Expo-friendly** – ships with a config-plugin; just add it to `app.json`
* **Classic & New Architecture** – works if the host app opts into TurboModule/Fabric later

## Installation

> **Supported React-Native versions:** 0.79 (Expo SDK 53).
> Older versions may compile but are not tested.

```bash
npx expo install expo-video-audio-overlay
```

Add the plugin entry to **`app.json` / `app.config.js`** so EAS can autolink:

```jsonc
{
  "expo": {
    "plugins": ["expo-video-audio-overlay"]
  }
}
```

That’s it — run a development build or EAS production build and the native module is ready.

> **Local testing:** run `npx expo run:ios` or `npx expo run:android` after installing the library; Expo Go will **not** include the native code.

## Usage

```ts
import { overlayAudio } from 'expo-video-audio-overlay';
import * as FileSystem from 'expo-file-system';

const videoUri = FileSystem.cacheDirectory + 'screen-recording.mp4';
const audioUri = FileSystem.bundleDirectory + 'music/background.mp3';

const outputUri = await overlayAudio({
  video:  videoUri,
  audio:  audioUri,
  loop:   true, // repeat audio to match video length
  output: FileSystem.documentDirectory + 'share-video.mp4',
});

console.log('Video with sound saved at', outputUri);
```

### API

| Option   | Type    | Description                                                                  |
| -------- | ------- | ---------------------------------------------------------------------------- |
| `video`  | string  | Absolute path to the **input video** file                                    |
| `audio`  | string  | Absolute path to the **audio** file to overlay                               |
| `loop`   | boolean | Whether to loop the audio so it matches the video duration (default: `true`) |
| `output` | string  | Absolute path for the **output video** (overwritten if already exists)       |

Returns **`Promise<string>`** – absolute file URI of the saved video.

> ⚠️ The module does **not** down-mix or re-sample audio; ensure your track uses a sample rate & codec accepted by the device encoder (e.g. AAC 48 kHz).

## Troubleshooting

| Problem                        | Fix                                                                                                 |
| ------------------------------ | --------------------------------------------------------------------------------------------------- |
| **`Native module not linked`** | Rebuild the dev client (`eas build --profile development`) or run `npx expo run-android / run-ios`. |
| **Audio not looping**          | Verify `loop` is `true`; ensure the audio file is a supported codec (AAC/MP3).                      |
| **iOS < 12 crash**             | The podspec targets iOS 12+. Older OS versions are not supported.                                   |

## Contributing

PRs are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT © 2025 Elliot Fleming
See [LICENSE](LICENSE) for details.
