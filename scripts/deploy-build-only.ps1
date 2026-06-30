$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$outDir = Join-Path $repoRoot "out"
$deployBranch = "gh-pages"
$commitMessage = "Deploy static site build"

Set-Location $repoRoot

Write-Host "Building static export..."
npm.cmd run build

if (-not (Test-Path -LiteralPath $outDir)) {
  throw "Build output folder was not found: $outDir"
}

$nojekyll = Join-Path $outDir ".nojekyll"
if (-not (Test-Path -LiteralPath $nojekyll)) {
  New-Item -ItemType File -Path $nojekyll | Out-Null
}

$remote = (git remote get-url origin).Trim()
if (-not $remote) {
  throw "Git remote 'origin' was not found."
}

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$deployDir = Join-Path $tempRoot ("sbs-gh-pages-" + [guid]::NewGuid().ToString("N"))
$deployDir = [System.IO.Path]::GetFullPath($deployDir)

if (-not $deployDir.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Refusing to use deployment directory outside temp: $deployDir"
}

Write-Host "Preparing $deployBranch branch in temp..."
git clone --branch $deployBranch --single-branch $remote $deployDir

$items = Get-ChildItem -LiteralPath $deployDir -Force | Where-Object { $_.Name -ne ".git" }
foreach ($item in $items) {
  $itemPath = [System.IO.Path]::GetFullPath($item.FullName)
  if (-not $itemPath.StartsWith($deployDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove path outside deployment directory: $itemPath"
  }

  Remove-Item -LiteralPath $itemPath -Recurse -Force
}

Write-Host "Copying only out/ into $deployBranch..."
Get-ChildItem -LiteralPath $outDir -Force | Copy-Item -Destination $deployDir -Recurse -Force

$globalName = git config --global user.name
$globalEmail = git config --global user.email
if (-not $globalName) {
  git -C $deployDir config user.name "Codex"
}
if (-not $globalEmail) {
  git -C $deployDir config user.email "codex@openai.com"
}

git -C $deployDir add -A
$pending = git -C $deployDir status --porcelain
if (-not $pending) {
  Write-Host "No deployment changes to commit."
  exit 0
}

Write-Host "Committing and pushing build output..."
git -C $deployDir commit -m $commitMessage
git -C $deployDir push origin $deployBranch

Write-Host "Done. Only out/ was pushed to $deployBranch."
