# PURPOSE: Root PowerShell setup script for single or multi-device Android prototype.
# ROLE IN SYSTEM: Iterates through all connected ADB devices and reverses port 8000 to http://localhost:8000.
# TALKS TO: adb, vaniguard/.venv

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " VaniGuard ADB Port Reverse & Multi-Device Setup " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Fetch connected ADB devices
$devices = (adb devices | Select-String -Pattern "\tdevice$") | ForEach-Object { ($_ -split "\s+")[0] }

if ($devices) {
    Write-Host "[1/2] Found $($devices.Count) connected device(s): $($devices -join ', ')" -ForegroundColor Yellow
    foreach ($dev in $devices) {
        Write-Host "  -> Setting up ADB reverse tcp:8000 tcp:8000 for device: $dev ..." -ForegroundColor Yellow
        adb -s $dev reverse tcp:8000 tcp:8000
        if ($LASTEXITCODE -eq 0) {
            Write-Host "     [SUCCESS] Device $dev bound to http://localhost:8000" -ForegroundColor Green
        } else {
            Write-Host "     [FAILED] Device $dev binding failed" -ForegroundColor Red
        }
    }
} else {
    Write-Host "[1/2] Warning: No ADB devices detected. Reversing default port anyway..." -ForegroundColor Red
    adb reverse tcp:8000 tcp:8000
}

# 2. Print readiness
Write-Host "[2/2] Setup Complete!" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Device REST API Base URL: http://localhost:8000" -ForegroundColor Green
Write-Host "  Device WebSocket Stream:  ws://localhost:8000/ws/voice-session" -ForegroundColor Green
Write-Host "  Health Check URL:        http://localhost:8000/health" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
