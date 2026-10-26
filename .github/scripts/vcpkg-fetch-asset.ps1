# vcpkg asset source (X_VCPKG_ASSET_SOURCES=x-script,...): serves a source tarball or tool
# download from the mirror directory when it is there, otherwise downloads it with retries
# and stores it. vcpkg names assets by their SHA-512, checks the hash of whatever this
# script produces, and falls back to the original URL if the script fails.
#
# Retries matter because the runners share egress addresses and git.openldap.org (lmdb,
# needed by cyrus-sasl) answers 429 to them; curl waits the server's Retry-After between
# attempts. vcpkg's own download makes one attempt.
param(
    [Parameter(Mandatory = $true)] [string] $Mirror,
    [Parameter(Mandatory = $true)] [string] $Url,
    [string] $Sha512,
    [Parameter(Mandatory = $true)] [string] $Dst
)
$ErrorActionPreference = 'Stop'
$mirrored = if ($Sha512) { Join-Path $Mirror $Sha512.ToLower() } else { $null }
if ($mirrored -and (Test-Path $mirrored)) {
    Copy-Item $mirrored $Dst -Force
    exit 0
}
& curl.exe --fail --silent --show-error --location `
    --retry 10 --retry-all-errors --retry-max-time 600 `
    --output $Dst $Url
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($mirrored) {
    New-Item -ItemType Directory -Force -Path $Mirror | Out-Null
    Copy-Item $Dst $mirrored -Force
}
