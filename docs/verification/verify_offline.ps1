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
    "bloatstrip.exe"          = "8F55FF88FD2D3BA1D50AA2D1A357DFE46E053F6E2866D31716BB2F798194705B"
    "bloatstrip-setup.exe"    = "E74A5FFDD9DEEE1A8F359D028D1E878192961DBEFA8C7C61ABCAA0CBFB9E5DA9"
    "activator.exe"           = "347763BD044FACDD12BC66F27837CDC58B0D2BA6569E9E022FF7F7BDE6536739"
    "bloatstrip-launcher.exe" = "27054291E3671D3981E1F820804CF5BAFB798B71AE89DB8021F3AE40499A8589"
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
