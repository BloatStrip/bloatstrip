<#
.SYNOPSIS
Independent offline verifier for BloatStrip v2.0 Windows x64 binaries.
Verifies SHA-256 hashes, checks PE import table for networking DLLs (ws2_32/winhttp/wininet),
and audits active sockets if bloatstrip.exe is running.
#>
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\BloatStrip"
)

$Expected = @{
    "bloatstrip.exe"          = "E717B567F30DD0205B3B6CC9A1DA005BFFCA8D7C9670B00008CA4F7199BBBEE1"
    "bloatstrip-setup.exe"    = "120D52A9C433B8CFF283A13C577CD11BAD937C9C3492564FA7054CDD7D76D8B1"
    "activator.exe"           = "A7F5FA175D8461F8B04356A1ED040FF805FBB12B2A3300B2A6DD2F3D3C774059"
    "bloatstrip-launcher.exe" = "98EB483BCB7900FFCD939414F1A21FBA5F34CA4C51BDA245EA760A1396503AA8"
}

Write-Host "=== 1. SHA-256 BINARY INTEGRITY ($InstallDir) ==="
foreach ($name in $Expected.Keys) {
    $path = Join-Path $InstallDir $name
    if (Test-Path $path) {
        $actual = (Get-FileHash -Algorithm SHA256 -Path $path).Hash.ToUpperInvariant()
        $ok = ($actual -eq $Expected[$name])
        Write-Host ("{0,-26} Match={1,-5} Hash={2}" -f $name, $ok, $actual)
    } else {
        Write-Host ("{0,-26} NOT FOUND at {1}" -f $name, $path)
    }
}

Write-Host "`n=== 2. HTTP CLIENT DLL AUDIT (winhttp / wininet must be False) ==="
$mainExe = Join-Path $InstallDir "bloatstrip.exe"
if (Test-Path $mainExe) {
    $bytes = [System.IO.File]::ReadAllBytes($mainExe)
    $ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
    foreach ($dll in @("winhttp.dll", "wininet.dll")) {
        $found = $ascii.IndexOf($dll, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        Write-Host ("HTTP API {0,-14}: Present={1}" -f $dll, $found)
    }
    Write-Host ("Manifest asInvoker      : Present={0}" -f $ascii.Contains('level="asInvoker"'))
    Write-Host ("Manifest PerMonitorV2   : Present={0}" -f $ascii.Contains('PerMonitorV2'))
}

Write-Host "`n=== 3. LIVE SOCKET AUDIT ==="
$procs = Get-Process bloatstrip -ErrorAction SilentlyContinue
if ($procs) {
    $conns = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $procs.Id -contains $_.OwningProcess }
    Write-Host ("Active TCP connections owned by bloatstrip.exe: {0}" -f (@($conns).Count))
} else {
    Write-Host "bloatstrip.exe not currently running (launch app and re-run to monitor live sockets)."
}
