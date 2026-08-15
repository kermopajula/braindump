# BrainDump

A personal knowledge vault for iOS. Dump anything you want to remember — measurements, where you put things, instructions, notes — by voice or text, then ask questions in plain language and get answers from your own knowledge base.

Everything is stored locally on your device. There is no account, no server, and no sync.

## Features

- **Capture by voice or text** — speech-to-text uses Apple's on-device recognition when the device supports it.
- **AI-structured entries** — raw input is cleaned up into a title, content, and tags, and the app detects when new input updates an entry you already have.
- **Ask questions** — answers are grounded only in your own entries; the app says so when it doesn't know.
- **Suggested updates** — when a question contains newer information than an entry, the app offers to update it.
- **Search and browse** — word-scored search over titles, content, and tags.
- **Import / export** — plain-text round-trip of the whole knowledge base.

## AI

All AI runs on-device via Apple's [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels) — no API key, no account, no network calls. Structured results come back through `@Generable` types rather than JSON parsing.

This requires **iOS 26 or later** on an Apple Intelligence–capable device with the feature enabled. When it isn't available, the app says why (device not eligible, Apple Intelligence turned off, model still downloading) and falls back to saving entries without AI structuring. **Settings → AI → Test On-Device Model** runs a quick round-trip to confirm it's working.

There are no cloud providers. The `AIService` protocol keeps the door open for adding one later, but nothing in the app talks to a remote API today.

## Requirements

- Xcode 26
- iOS 17.0+ to build and run (iOS 26+ for any of the AI features)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Building

The Xcode project is generated from `project.yml` and is not checked in.

```sh
git clone https://github.com/kermopajula/braindump.git
cd braindump
xcodegen generate
open BrainDump.xcodeproj
```

Then build and run the `BrainDump` scheme on a simulator or device. Signing is disabled in `project.yml`; set your own `DEVELOPMENT_TEAM` there to run on a physical device.

## Project layout

```
BrainDumpApp.swift        App entry point
ContentView.swift         Tab shell: Add / Knowledge / Ask / Settings
Models/
  KnowledgeEntry.swift    The stored entry type
  AppSettings.swift       Persisted settings and on-device AI availability
Services/
  AIService.swift         AI protocol, shared prompts, errors
  FoundationModelsClient.swift  On-device Apple Intelligence client
  KnowledgeStore.swift    JSON-file persistence, search, import/export
  SpeechRecognizer.swift  Speech-to-text
  ImportExportService.swift
Views/                    SwiftUI screens and components
```

## Data and privacy

- Entries live in a single `knowledge.json` file in the app's Documents directory. Deleting the app deletes them.
- Nothing is uploaded anywhere. The app makes no network requests at all.
- No accounts, no API keys, no analytics, no tracking, no third-party SDKs.

## License

MIT — see [LICENSE](LICENSE).
