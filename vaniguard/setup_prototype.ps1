# PURPOSE: One-click setup script for physical Android phone prototype demo.
# ROLE IN SYSTEM: Executes ADB port reversal, verifies Supabase connection, and prepares device connection.
# TALKS TO: adb, server/app/database.py

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " VaniGuard Prototype Setup & Device Bind " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Reverse ADB port for USB connected phone
Write-Host "[1/3] Binding phone USB port (adb reverse tcp:8000 tcp:8000)..." -ForegroundColor Yellow
adb reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -eq 0) {
    Write-Host "  -> ADB Port Reverse SUCCESS! Phone will use http://localhost:8000" -ForegroundColor Green
} else {
    Write-Host "  -> Warning: ADB reverse skipped (ensure USB debugging is ON if phone is connected)." -ForegroundColor Red
}

# 2. Check Python environment and database connection
Write-Host "[2/3] Verifying live Supabase database & Python environment..." -ForegroundColor Yellow
.venv\Scripts\python -c "from server.app.database import is_pg_available; print('  -> Supabase DB Connection:', 'OK' if is_pg_available() else 'FAILED')"

# 3. Print device & backend readiness
Write-Host "[3/3] System Setup Complete!" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Phone REST API Base URL: http://localhost:8000" -ForegroundColor Green
Write-Host "  Phone WebSocket Stream:  ws://localhost:8000/ws/voice-session" -ForegroundColor Green
Write-Host "  Health Check URL:        http://localhost:8000/health" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
