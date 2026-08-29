# TestFlight CI pipeline

Every push to `main` runs unit tests, then builds and uploads **Aap-SC** to TestFlight via GitHub Actions.

Workflow file: [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml)

## One-time setup

### 1. App Store Connect app

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com/).
2. Create an app with bundle ID **`com.aapft.aapsc`** (must match the Xcode project).
3. Complete the minimum metadata App Store Connect requires for TestFlight builds.

### 2. App Store Connect API key

1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**.
2. Create a key with **App Manager** (or **Admin**) access.
3. Download the `.p8` file once (you cannot download it again).

### 3. GitHub repository secrets

In the repo: **Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value |
|--------|--------|
| `APP_STORE_CONNECT_KEY_ID` | Key ID from App Store Connect (e.g. `ABC123DEF4`) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID on the API keys page (UUID) |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Base64-encoded contents of the `.p8` file (see below) |
| `APPLE_TEAM_ID` | Apple Developer Team ID (project default: `LT8J5AAD2V`) |

Encode the private key:

```bash
base64 -i AuthKey_XXXXXX.p8 | pbcopy   # macOS
base64 -w 0 AuthKey_XXXXXX.p8          # Linux
```

Paste the single-line base64 string into `APP_STORE_CONNECT_PRIVATE_KEY`.

### 4. Code signing

The project uses **Automatic** signing with team `LT8J5AAD2V`. The CI build passes `-allowProvisioningUpdates` so Xcode can create/update provisioning profiles using the API key.

Ensure the API key’s user has access to the team and app in App Store Connect.

## What the pipeline does

1. **Test job** — `xcodebuild test` on iPhone 16 simulator (no signing).
2. **TestFlight job** — Fastlane `beta` lane:
   - Sets build number to `github.run_number`
   - Archives with Release configuration
   - Uploads to TestFlight
   - Does not wait for Apple processing (build appears in App Store Connect shortly after upload)

## Manual run

**Actions → TestFlight → Run workflow** (branch `main`).

## Local Fastlane (optional)

```bash
cd ios
bundle install
export APP_STORE_CONNECT_KEY_ID=...
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_PRIVATE_KEY=...
export APPLE_TEAM_ID=LT8J5AAD2V
bundle exec fastlane beta
```

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| Missing secrets | All four secrets set in GitHub |
| Provisioning profile | API key user has Developer access; bundle ID registered |
| Duplicate build number | Re-run is OK — each run uses a new `run_number` |
| HealthKit entitlement | Enabled in Apple Developer portal for `com.aapft.aapsc` |

Build numbers increment automatically (`1`, `2`, `3`, … per workflow run). Bump **marketing version** (`MARKETING_VERSION` / `CFBundleShortVersionString`) in Xcode when you release a new user-facing version.
