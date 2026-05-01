param(
  [string]$Repository = "jankendo/ichigodb-ios",
  [string]$Workflow = "build-ios.yml",
  [string]$Ref = "main",
  [switch]$Watch
)

$ErrorActionPreference = "Stop"

gh workflow run $Workflow --repo $Repository --ref $Ref
Write-Host "Triggered $Workflow on $Repository@$Ref"

if ($Watch) {
  Start-Sleep -Seconds 5
  $runId = gh run list --repo $Repository --workflow $Workflow --limit 1 --json databaseId --jq ".[0].databaseId"
  gh run watch $runId --repo $Repository --exit-status
}
