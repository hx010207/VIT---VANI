# PURPOSE: Setup script for single or multi-device Android prototype.
# ROLE IN SYSTEM: Iterates through all connected ADB devices and reverses port 8000 to http://localhost:8000.
# TALKS TO: adb, server/app/database.py

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " VaniGuard ADB Port Reverse & Multi-Device Setup " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Fetch connected ADB devices
$devices = (adb devices | Select-String -Pattern "\tdevice$") | ForEach-Object { ($_ -split "\s+")[0] }

if ($devices) {
    Write-Host "[1/3] Found $($devices.Count) connected device(s): $($devices -join ', ')" -ForegroundColor Yellow
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
    Write-Host "[1/3] Warning: No ADB devices detected. Reversing default port anyway..." -ForegroundColor Red
    adb reverse tcp:8000 tcp:8000
}

# 2. Check Python environment and database connection
Write-Host "[2/3] Verifying live Supabase database & Python environment..." -ForegroundColor Yellow
.venv\Scripts\python -c "from server.app.database import is_pg_available; print('  -> Supabase DB Connection:', 'OK' if is_pg_available() else 'FAILED')"

# 3. Print readiness
Write-Host "[3/3] Readiness Summary" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Device REST API Base URL: http://localhost:8000" -ForegroundColor Green
Write-Host "  Device WebSocket Stream:  ws://localhost:8000/ws/voice-session" -ForegroundColor Green
Write-Host "  Health Check URL:        http://localhost:8000/health" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
