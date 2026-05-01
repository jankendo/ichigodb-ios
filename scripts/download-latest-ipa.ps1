param(
  [string]$Repository = "jankendo/ichigodb-ios",
  [string]$Workflow = "build-ios.yml",
  [string]$Artifact = "ichigodb-ipa",
  [string]$OutputDirectory = ".\artifacts"
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$runId = gh run list --repo $Repository --workflow $Workflow --status success --limit 1 --json databaseId --jq ".[0].databaseId"
if (-not $runId) {
  throw "No successful workflow run found for $Workflow"
}

gh run download $runId --repo $Repository --name $Artifact --dir $OutputDirectory
Write-Host "Downloaded $Artifact from run $runId to $OutputDirectory"
