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

## AI providers

Pick a provider in **Settings → AI Provider**:

| Provider | Model | API key | Data leaves device |
|---|---|---|---|
| Apple Intelligence | On-device Foundation Model | Not needed | No |
| OpenAI | `gpt-4o` | Required | Yes |
| Anthropic | `claude-sonnet-4-20250514` | Required | Yes |

**Apple Intelligence** is the default and runs entirely on-device via the [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels). It requires iOS 26 or later on an Apple Intelligence–capable device with the feature enabled; the app surfaces a clear message when it isn't available.

The **OpenAI** and **Anthropic** providers send your question along with the relevant knowledge base entries to that provider's API. Use them only if you're comfortable with that.

## Requirements

- Xcode 26
- iOS 17.0+ to build and run (iOS 26+ for the Apple Intelligence provider)
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
  AIProvider.swift        Provider enum and model names
  AppSettings.swift       Persisted user settings
Services/
  AIService.swift         Provider-agnostic protocol, shared prompts, response parsing
  FoundationModelsClient.swift  On-device Apple Intelligence client
  OpenAIClient.swift      OpenAI provider
  AnthropicClient.swift   Anthropic provider
  KnowledgeStore.swift    JSON-file persistence, search, import/export
  SpeechRecognizer.swift  Speech-to-text
  ImportExportService.swift
Views/                    SwiftUI screens and components
```

All three AI clients implement the same `AIService` protocol and share prompt construction, so adding a provider means writing one client and one enum case.

## Data and privacy

- Entries live in a single `knowledge.json` file in the app's Documents directory. Deleting the app deletes them.
- Nothing is uploaded anywhere unless you choose OpenAI or Anthropic as your provider.
- API keys are stored in `UserDefaults` via `@AppStorage`, not the Keychain.
- No analytics, no tracking, no third-party SDKs.

## License

No license has been chosen yet — all rights reserved until one is added.
