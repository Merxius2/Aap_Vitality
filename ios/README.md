# Aap-SC — Native iOS App

Native **SwiftUI** swim coach app for iPhone and iPad.

Open and build in **Xcode** on macOS:

```bash
open ios/AapSC.xcodeproj
```

## Requirements

- macOS with **Xcode 15.4+**
- iOS **17.0+**
- Apple Developer account for physical devices

## Navigation

| Tab | Screen |
|-----|--------|
| Settings | Profile, themes, background vibes, upload, import/export |
| Medals | Medal gallery and monthly history |
| **Progress (center FAB)** | Charts, challenges, records, coach feedback |
| Benchmark | Age-group pace comparison |
| History | Session list and detail |

Upload is available from **Settings → Upload swim session**.

## What's included

| Feature | Status |
|---------|--------|
| Progress dashboard with Swift Charts + moving averages | ✅ |
| Chart interaction toggle (scroll-friendly by default) | ✅ |
| Upload Apple Fitness screenshots (Vision OCR) | ✅ |
| HealthKit swim import | ✅ |
| Medals + monthly challenges | ✅ |
| All themes + background vibe overlays | ✅ |
| Dark mode | ✅ |
| i18n: en, nl, ru, tr | ✅ |
| JSON import/export (v10) | ✅ |
| AI coach (optional OpenAI key) | ✅ |

## Architecture

```
ios/AapSC/
├── AapSCApp.swift
├── ContentView.swift        # Tab shell + sheets
├── Models/
├── Services/
├── ViewModels/
├── Views/
├── Lib/                       # Business logic + ChartMovingAverage
└── Resources/
    ├── Assets.xcassets
    └── Localizations/         # en.json, nl.json, ru.json, tr.json
```

## Tests

```bash
xcodebuild test -project ios/AapSC.xcodeproj -scheme AapSC \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## TestFlight CI

Every merge to `main` triggers [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml): simulator tests, then a Fastlane upload to TestFlight. Build numbers use the GitHub run number.

See [docs/TESTFLIGHT.md](../docs/TESTFLIGHT.md) for App Store Connect API key and GitHub secrets setup.

## Signing

1. Select **AapSC** target → **Signing & Capabilities**
2. Set your **Team**
3. Adjust **Bundle Identifier** if needed (default `com.aapft.aapsc`)
