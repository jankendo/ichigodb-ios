# IchigoDB iOS

IchigoDB is a fully native SwiftUI iOS app for strawberry variety research. It connects directly to the existing Supabase project used by the Streamlit version and requires Supabase Auth before any DB access.

## Features

- 品種図鑑: search, prefecture filter, discovered/undiscovered state, details, latest review, images.
- 品種登録: create/edit varieties, traits, tags, parent varieties, and variety images.
- 品種評価: fast tasting review entry, automatic overall score, duplicate-date overwrite confirmation, review images.
- 分析: review history, ranking, trend, comparison, and cost-performance views.

The app does not embed Streamlit or WebView content.

## Windows Development Flow

1. Edit Swift files on Windows.
2. Push to GitHub.
3. GitHub Actions generates `Config/IchigoDB.xcodeproj` with XcodeGen on a macOS runner.
4. Actions builds and tests for iOS Simulator.
5. Actions builds an unsigned device `.app`, packages `IchigoDB.ipa`, and uploads artifact `ichigodb-ipa`.

## Supabase Secrets

The repo commits only an empty placeholder at `Sources/Generated/SupabaseConfig.generated.swift`.
GitHub Actions overwrites it from repository secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

From this repo folder on Windows:

```powershell
pwsh -File .\scripts\sync-supabase-secrets.ps1
```

## Build

Trigger the workflow:

```powershell
pwsh -File .\scripts\trigger-build.ps1 -Watch
```

Download the latest successful IPA:

```powershell
pwsh -File .\scripts\download-latest-ipa.ps1
```

The downloaded file is `artifacts\IchigoDB.ipa`.

## Notes

- The unsigned IPA is intended for a sideloading/signing workflow such as Sideloadly.
- The anon key is still compiled as the public Supabase client key, but all table and Storage access is restricted by RLS.
- Only authenticated users listed in `public.app_users` with `role = 'admin'` can read or write app data.
- The committed migration `20260507062000_restrict_ios_access_to_admin_auth.sql` removes legacy anon read/write policies.
