# MacWisper

A small native macOS dictation app built with SwiftUI, AVFoundation, and transcribe.cpp with Metal acceleration.

## Current first iteration

- An orange retro pilot light floats above app windows at the horizontal center and 20% down the display under the pointer. It depresses while recording, springs up when recording stops, then disappears.
- Option + Space is the default system-wide shortcut. Choose hold-to-dictate or press-to-toggle in Settings.
- The microphone can stay ready and retain only a configurable 1–8 second in-memory pre-roll ring. Audio before activation is included in the saved recording.
- transcribe.cpp 0.1.3 transcribes recordings locally using the same pinned GGUF artifacts as Hex. The default is Parakeet Unified English.
- Custom written words provide initial-prompt hints for Whisper. Optional Apple Speech uses X-SAMPA pronunciations and its custom language model; the other GGUF models do not support recognition hints.
- Transcripts and WAV recordings are kept for 7 days, 30 days, 90 days, or one year, then purged when the app starts or the retention setting changes.
- Completed text is copied and sent as Command-V to the app that was focused before dictation.

## Permissions

The first run requests Microphone access. Speech Recognition access is requested only when preparing the optional Apple Speech model. The global keyboard event tap and simulated paste require Accessibility access in System Settings → Privacy & Security → Device Control and Data Access (called Accessibility on earlier macOS versions). The app automatically retries the global shortcut after Accessibility access is granted. Without that permission, shortcut keystrokes still reach the focused app.

The always-ready mode records a rolling in-memory pre-roll, discarding older buffers as they expire. When dictation is not active, it does not write audio to disk or submit audio for transcription. Dictation is capped at 60 seconds per clip. Audio is averaged to mono and resampled to 16 kHz for local inference; models with shorter input limits are processed in chunks.

## Build and run

```sh
./script/build_and_run.sh
```

The project is a Swift Package Manager macOS app targeting macOS 26 or later. It bundles the upstream transcribe.cpp 0.1.3 XCFramework (MIT license, with ggml license included under `vendor/TranscribeCpp.xcframework`). The build script embeds and signs the framework.

Requires macOS 26 or later. The interface uses native Liquid Glass navigation and controls. In Settings, click the shortcut box and press a modifier plus a supported key; release to save, or press Escape to cancel.

## Transcription models

Open Settings → Transcription, choose a model and language, then click **Download / Prepare Model**. Downloads are checked against Hex's pinned byte counts, SHA-256 hashes, architecture and variant. Installed models load automatically on app startup. The app keeps a warm model and recreates inference sessions for each clip/chunk to bound scratch memory. Model preparation and transcription run away from the main UI thread.

The supported GGUF models match Hex: Parakeet Unified English, Parakeet v2, Parakeet v3, Whisper large-v3-turbo, Qwen3-ASR 0.6B, SenseVoice Small, and Cohere Transcribe. Apple Speech remains available as an optional legacy backend. Language choices and automatic detection follow each model's capabilities; only Whisper accepts custom dictionary hints.

Models download from Hugging Face into `~/Library/Application Support/MacWisper/Models/`. Downloads range from about 253 MB to 2.41 GB. After installation, transcription requires no network connection and audio stays on this Mac. No running Hex application or Hex checkout is required.

Run checks with `swift test`. For the optional real Metal inference check, set `MACWISPER_TEST_MODEL` to the pinned Parakeet Unified English GGUF file and `MACWISPER_TEST_AUDIO` to an audio file saying “The quick brown fox jumps over the lazy dog.”

## Local signing and permission troubleshooting

The build script signs the completed app bundle and verifies its signature before launch. To use a persistent signing identity, run:

```sh
MACWISPER_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./script/build_and_run.sh
```

Use an identity actually installed in your keychain (`security find-identity -v -p codesigning`). Without one, the script uses ad hoc signing for local development. Its designated requirement is tied to the built code, so changing the binary can invalidate a previous privacy grant even if System Settings still displays an enabled entry. Refresh the MacWisper entry after rebuilding; if toggling fails, remove that entry and add `dist/MacWisper.app` again. Restart the existing bundle without rebuilding to verify the refreshed grant.
