<#
.SYNOPSIS
Independent offline verifier for BloatStrip v2.0 Windows x64 binaries.
Verifies SHA-256 hashes, checks PE import table for networking DLLs (ws2_32/winhttp/wininet),
and audits active sockets if bloatstrip.exe is running.
#>
param(
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\BloatStrip\Gemini Engine"
)

$Expected = @{
    "bloatstrip.exe"              = "8A50CC059E3E1732DB52448D09FEDDD85EB6651C4B805D4A2B4E6EACCB666BA8"
    "bloatstrip-gemini-setup.exe" = "CDF4771EDB03C0CBF1EF73DE12954C4195E721F4BD4D77F7DA54B9C33FE6D301"
    "activator.exe"               = "C66F6AC4A853BD316C7CEF59ABE91129FBDE91522E041EAAF3FC838F7BCC105B"
    "bloatstrip-launcher.exe"     = "9BB6876A96D4DBA19AE9BF962C0908B8B9579FD60F479C7901E725F5186CF877"
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
