# Aap Vitality

Scaffolding copied from [Merxius2/swimming_app](https://github.com/Merxius2/swimming_app) (Aap-SC Swim Coach). Adapt this codebase for the Vitality app while reusing the existing iOS architecture, services, and UI patterns.

Native iOS app for tracking Apple Fitness swim workouts, progress, medals, benchmarks, and the swim coin economy.

The repository contains **only the iOS app**. Open `ios/AapSC.xcodeproj` in Xcode on macOS to build and run.

## Requirements

- macOS with Xcode 15.4+
- iOS 17.0+ (iPhone or iPad)
- Apple Developer account for physical devices

## Quick start

```bash
open ios/AapSC.xcodeproj
```

Select the **AapSC** scheme, choose a simulator, and press **⌘R**.

See [ios/README.md](ios/README.md) for signing, architecture, and feature details.

## Features

- Progress charts with optional interaction toggle and 3-session moving averages
- Upload swim sessions from Apple Fitness screenshots (Vision OCR) or HealthKit
- History, benchmarks, medals, and monthly challenges
- Swim coin store with themes, icons, vibes, and boosts
- Mini games: Wheel of Fortune, Coin Flip, Pace Pick, Lane Timer
- Mascot coaches, i18n (en/nl/ru/tr), themes including Olympic Pool, dark mode

## Asset scripts

Optional Node scripts under `scripts/` generate app/page icon assets for the iOS catalog:

```bash
node scripts/generate-page-icons.mjs
node scripts/generate-app-icons.mjs
```

## Tests

Run unit tests in Xcode (**⌘U**) or:

```bash
xcodebuild test -project ios/AapSC.xcodeproj -scheme AapSC -destination 'platform=iOS Simulator,name=iPhone 16'
```

## TestFlight (automatic builds)

Pushes to **`main`** run [`.github/workflows/testflight.yml`](.github/workflows/testflight.yml): unit tests on macOS, then a Fastlane upload to TestFlight. Each run gets a unique build number (`github.run_number`).

**One-time setup:** configure App Store Connect API secrets in GitHub. See [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).
