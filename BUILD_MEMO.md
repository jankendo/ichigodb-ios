# IchigoDB Build Memo

This project mirrors the Windows-to-iOS workflow from `jankendo/windows-ios-app`, adapted for IchigoDB.

## Output

- Artifact: `ichigodb-ipa`
- IPA: `IchigoDB.ipa`
- Bundle id: `app.ichigodb.native`
- Display name: `IchigoDB`

## Workflow

1. Windows edits source files.
2. Push to `main`.
3. `.github/workflows/build-ios.yml` runs on `macos-latest`.
4. `scripts/write_supabase_config.py` injects Supabase secrets into the generated Swift config.
5. XcodeGen creates `Config/IchigoDB.xcodeproj`.
6. `xcodebuild` validates the simulator build and runs unit tests when an iPhone simulator destination is available.
7. `xcodebuild` produces an unsigned device build.
8. The workflow zips `Payload/IchigoDB.app` into `IchigoDB.ipa`.

## Windows Commands

```powershell
pwsh -File .\scripts\sync-supabase-secrets.ps1
pwsh -File .\scripts\trigger-build.ps1 -Watch
pwsh -File .\scripts\download-latest-ipa.ps1
```

## Secret Safety

Do not commit real Supabase values. The committed `SupabaseConfig.generated.swift` must stay empty; CI overwrites it in the runner workspace.
