param(
  [string]$Out = "build/quick_changes.patch"
)

$repo = Resolve-Path "."
$target = Join-Path $repo $Out
$dir = Split-Path $target -Parent
if (-not (Test-Path $dir)) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

git -C $repo diff > $target
Write-Host "Wrote patch: $target"
