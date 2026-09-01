[CmdletBinding()]
param(
    [string]$Destination = (Join-Path $PSScriptRoot '..\backend\bin\deno.exe')
)

$ErrorActionPreference = 'Stop'
$version = '2.9.6'
$archiveSha256 = '15E5300B0BA3C3695A7621D90160A746EC9E710228CEE639AFA9D580F6E3CD11'
$archiveUrl = "https://github.com/denoland/deno/releases/download/v$version/deno-x86_64-pc-windows-msvc.zip"
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mkvoodoo-deno-$([guid]::NewGuid())"
$archivePath = Join-Path $temporaryRoot 'deno.zip'
$extractPath = Join-Path $temporaryRoot 'extract'

$backendBin = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\backend\bin'))
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$allowedPrefix = $backendBin + [System.IO.Path]::DirectorySeparatorChar
if (-not $destinationPath.StartsWith($allowedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination must remain inside $backendBin"
}

try {
    New-Item -ItemType Directory -Path $temporaryRoot, $extractPath -Force | Out-Null
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath

    $actualSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    if ($actualSha256 -ne $archiveSha256) {
        throw "Deno archive checksum mismatch. Expected $archiveSha256, received $actualSha256."
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractPath
    $executable = Join-Path $extractPath 'deno.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw 'The verified Deno archive did not contain deno.exe.'
    }

    New-Item -ItemType Directory -Path $backendBin -Force | Out-Null
    Move-Item -LiteralPath $executable -Destination $destinationPath -Force

    $reportedVersion = (& $destinationPath --version | Select-Object -First 1).Trim()
    if (-not $reportedVersion.StartsWith("deno $version ", [System.StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $destinationPath -Force
        throw "Unexpected Deno version: $reportedVersion"
    }

    Write-Output "Installed Deno $version at $destinationPath"
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        try {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        } catch {
            Write-Warning "Could not immediately clean temporary Deno files: $_"
        }
    }
}
