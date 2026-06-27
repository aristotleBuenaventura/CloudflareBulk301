# Cloudflare Bulk 301

Flutter desktop app for **macOS** and **Windows** that applies bulk **301 redirects** across many Cloudflare zones, redirecting each domain to a single target domain.

## Features

- **Login with Cloudflare API token** — required before using the app
- **API token is never saved** — kept in memory only for the current session
- **Manual domain entry** or **CSV upload**
- **Preserve path** and **query string** options
- Per-domain results (success / skipped / failed)

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable)
- macOS: Xcode command-line tools
- Windows: Visual Studio with Desktop development with C++

## Setup

```bash
git clone <repo-url>
cd CloudflareBulk301
flutter pub get
```

## Run

**macOS:**

```bash
flutter run -d macos
```

**Windows:**

```bash
flutter run -d windows
```

## Build

```bash
flutter build macos
flutter build windows
```

## Cloudflare API token

Create a token at [Cloudflare Dashboard → API Tokens](https://dash.cloudflare.com/profile/api-tokens) with:

| Permission | Access |
|---|---|
| Zone | Read |
| Zone Rules | Edit |

Use **Account Resources** or **All zones** depending on your setup.

## CSV format

Either one domain per line:

```text
oldsite1.com
oldsite2.com
www.oldsite3.com
```

Or a CSV with a header column named `domain`:

```text
domain
oldsite1.com
oldsite2.com
```

## How it works

For each source domain, the app:

1. Finds the matching Cloudflare zone in your account
2. Creates (or updates) a **Dynamic Redirect** rule (`http_request_dynamic_redirect`)
3. Redirects all traffic to your target domain with HTTP **301**

If an identical redirect rule already exists, that domain is marked as **skipped**.

## Security

- The API token is **not** written to disk, `SharedPreferences`, or any local storage
- Closing the app or signing out clears the token from memory
- Enter your token again on each new session

## Sample CSV

See `assets/sample_domains.csv` for an example file.
