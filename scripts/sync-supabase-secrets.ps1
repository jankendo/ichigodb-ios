param(
  [string]$Repository = "jankendo/ichigodb-ios",
  [string]$SecretsPath = "..\いちごDB\.streamlit\secrets.toml"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SecretsPath)) {
  throw "Secrets file not found: $SecretsPath"
}

$content = Get-Content -LiteralPath $SecretsPath -Raw

function Read-TomlString([string]$Name) {
  $pattern = "(?m)^\s*$Name\s*=\s*['""](?<value>[^'""]+)['""]\s*$"
  $match = [regex]::Match($content, $pattern)
  if (-not $match.Success) {
    throw "Missing $Name in $SecretsPath"
  }
  return $match.Groups["value"].Value
}

$supabaseUrl = Read-TomlString "SUPABASE_URL"
$supabaseAnonKey = Read-TomlString "SUPABASE_ANON_KEY"

$supabaseUrl | gh secret set SUPABASE_URL --repo $Repository
$supabaseAnonKey | gh secret set SUPABASE_ANON_KEY --repo $Repository

Write-Host "Supabase secrets synced to $Repository"
