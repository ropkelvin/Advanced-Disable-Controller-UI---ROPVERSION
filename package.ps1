$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonFolder = Join-Path $repoRoot "ESOHybridUI"
$manifestPath = Join-Path $addonFolder "ESOHybridUI.txt"

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Expected addon manifest not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath
$versionLine = $manifest | Where-Object { $_ -match '^## Version:\s*(.+)$' } | Select-Object -First 1
$addonVersionLine = $manifest | Where-Object { $_ -match '^## AddOnVersion:\s*(\d+)$' } | Select-Object -First 1
$apiLine = $manifest | Where-Object { $_ -match '^## APIVersion:\s*(.+)$' } | Select-Object -First 1

if (-not $versionLine -or -not $addonVersionLine -or -not $apiLine) {
    throw "Manifest must declare ## Version, numeric ## AddOnVersion and ## APIVersion."
}

$version = [regex]::Match($versionLine, '^## Version:\s*(.+)$').Groups[1].Value.Trim()
$addonVersion = [regex]::Match($addonVersionLine, '^## AddOnVersion:\s*(\d+)$').Groups[1].Value
$apiVersions = @(([regex]::Match($apiLine, '^## APIVersion:\s*(.+)$').Groups[1].Value.Trim() -split '\s+'))
if ($apiVersions.Count -gt 2) {
    throw "ESO supports at most two APIVersion values in the manifest."
}
$apiVersion = $apiVersions -join ' '

# Every non-directive manifest line is a file ESO will load.
$manifestFiles = @($manifest | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith("##") })
$missingFiles = foreach ($entry in $manifestFiles) {
    $path = Join-Path $addonFolder ($entry -replace '/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $entry
    }
}
if ($missingFiles) {
    throw "Manifest references missing files: $($missingFiles -join ', ')"
}

# Hidden/system files are not part of a release package.
$hiddenFiles = Get-ChildItem -LiteralPath $addonFolder -Force -Recurse |
    Where-Object { ($_.Attributes -band [IO.FileAttributes]::Hidden) -ne 0 -or $_.Name -in @("desktop.ini", ".DS_Store", ".gitkeep") }
if ($hiddenFiles) {
    throw "Remove hidden or system files before packaging: $($hiddenFiles.FullName -join ', ')"
}

$distFolder = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Path $distFolder -Force | Out-Null
$zipPath = Join-Path $distFolder "ESOHybridUI-$version.zip"

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

# Pass the addon folder itself so the ZIP root contains ESOHybridUI/, not an
# extra repository or versioned parent folder.
Compress-Archive -LiteralPath $addonFolder -DestinationPath $zipPath -CompressionLevel Optimal

$null = Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = @($archive.Entries | ForEach-Object { $_.FullName -replace '\\', '/' })
    $unexpected = @($entries | Where-Object { -not $_.StartsWith("ESOHybridUI/") })
    if ($unexpected.Count -gt 0) {
        throw "Unexpected paths at ZIP root: $($unexpected -join ', ')"
    }

    foreach ($entry in $manifestFiles) {
        $expectedEntry = "ESOHybridUI/$entry"
        if ($entries -notcontains $expectedEntry) {
            throw "ZIP is missing manifest file: $expectedEntry"
        }
    }
}
finally {
    $archive.Dispose()
}

Write-Host "Package created: $zipPath"
Write-Host "Addon version: $version (AddOnVersion $addonVersion)"
Write-Host "API versions: $apiVersion"
Write-Host "ZIP layout verified: ESOHybridUI/ is the archive root."
