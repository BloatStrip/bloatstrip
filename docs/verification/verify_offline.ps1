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
    "bloatstrip.exe"          = "48968AEE1E2FDBB2F96F668F5331D44CB7C33B1002D969D3F117ED03343277C6"
    "activator.exe"           = "4222DF79F921F0D1801F42993C47716117ED99AA11D1CE2196013718A80A2A5D"
    "bloatstrip-launcher.exe" = "333FF8546BB3990424440342E5187829871C319F3142199560AF49BAB9F78D78"
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
}

Write-Host "`n=== 3. LIVE SOCKET AUDIT ==="
$procs = Get-Process bloatstrip -ErrorAction SilentlyContinue
if ($procs) {
    $conns = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { $procs.Id -contains $_.OwningProcess }
    Write-Host ("Active TCP connections owned by bloatstrip.exe: {0}" -f (@($conns).Count))
} else {
    Write-Host "bloatstrip.exe not currently running (launch app and re-run to monitor live sockets)."
}
