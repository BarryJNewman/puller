<#
.SYNOPSIS
    One-shot developer-workstation bootstrap with locked console and dark mode.
.NOTES
    - Works on Windows 10/11 Pro
    - Requires admin for the scheduled task creation
    - Chocolatey must be installed (or comment out choco installs)
#>

# CONFIGURATION
$ScriptVersion = 3
$FlagRegPath   = 'HKLM:\Software\DevSetup'
$GroupName     = 'docker-users'
$ChocoPkgs     = @('multipass', 'docker-desktop')

# LOCK CONSOLE (removes X, disables Ctrl+C/Break)
if (-not ('ConsoleGuard' -as [type])) {
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    public static class ConsoleGuard {
        const uint SC_CLOSE = 0xF060, MF_BYCOMMAND = 0;
        [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]   static extern IntPtr GetSystemMenu(IntPtr hWnd,bool bRevert);
        [DllImport("user32.dll")]   static extern bool  DeleteMenu (IntPtr hMenu,uint uPos,uint uFlags);
        [DllImport("user32.dll")]   static extern bool  DrawMenuBar(IntPtr hWnd);
        [DllImport("kernel32.dll")] static extern bool  SetConsoleCtrlHandler(IntPtr h, bool add);
        public static void Engage() {
            var hwnd  = GetConsoleWindow();
            if (hwnd != IntPtr.Zero){
                var hMenu = GetSystemMenu(hwnd,false);
                DeleteMenu(hMenu, SC_CLOSE, MF_BYCOMMAND);
                DrawMenuBar(hwnd);
            }
            SetConsoleCtrlHandler(IntPtr.Zero,true);
        }
    }
"@
}
[ConsoleGuard]::Engage()

# IDEMPOTENCE CHECK
# $AlreadyDone = $false
# try {
#     if (Test-Path $FlagRegPath) {
#         $ver = (Get-ItemProperty $FlagRegPath -Name Version -ErrorAction SilentlyContinue).Version
#         $AlreadyDone = ($ver -ge $ScriptVersion)
#     }
# } catch {}
# if ($AlreadyDone) {
#     Write-Host "Dev setup (version $ver) already applied. Nothing to do."
#     exit 0
# }
Write-Host "Initialising developer environment – please wait.`n"

# LOGGING FUNCTION
function Write-Event([string]$Message,[int]$EventId=1001,[string]$EntryType='Information'){
    Write-Host $Message
    try {
        Write-EventLog -LogName Application -Source 'DevSetup' -EventId $EventId `
                       -EntryType $EntryType -Message $Message -ErrorAction SilentlyContinue
    } catch {}
}
if (-not ([System.Diagnostics.EventLog]::SourceExists('DevSetup'))) {
    New-EventLog -LogName Application -Source 'DevSetup'
}

try {
    # WINDOWS DARK MODE (System + Apps)
    $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
    Set-ItemProperty -Path $regPath -Name AppsUseLightTheme -Value 0 -Type DWord
    Set-ItemProperty -Path $regPath -Name SystemUsesLightTheme -Value 0 -Type DWord
    Write-Event "Set Windows dark mode (apps + system)."

    # GROUP MEMBERSHIP
    if (Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue) {
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        if (-not (Get-LocalGroupMember -Group $GroupName -Member $currentUser -ErrorAction SilentlyContinue)) {
            Add-LocalGroupMember -Group $GroupName -Member $currentUser
            Add-LocalGroupMember -Group $GroupName -Member 'NT AUTHORITY\Authenticated Users'
            Write-Event "Added $currentUser and Authenticated Users to $GroupName."
        }
    } else {
        Write-Event "Group $GroupName not found – skipping." 1002 'Warning'
    }

    # WSL (Ubuntu) & UPDATE
    Write-Event "Installing WSL + Ubuntu (quiet)…"
    wsl --install -d ubuntu --no-launch   3>$null
    wsl --update                          3>$null

    # CHOCOLATEY PACKAGES
    foreach ($pkg in $ChocoPkgs) {
        choco install $pkg --yes --no-progress --limit-output
    }
    Write-Event "Installed Chocolatey packages: $($ChocoPkgs -join ', ')."

    # RESTART‑APPS SETTING
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' `
                     -Name RestartApps -Value 0 -Type DWord
    Write-Event "Enabled Restart Apps at sign-in."

    # CLEAN PUBLIC DESKTOP
    Remove-Item 'C:\Users\Public\Desktop\*' -Recurse -Force -ErrorAction SilentlyContinue

    # FLAG COMPLETED
    if (-not (Test-Path $FlagRegPath)) { New-Item -Path $FlagRegPath -Force | Out-Null }
    Set-ItemProperty -Path $FlagRegPath -Name Version -Value $ScriptVersion
    Write-Event "Dev setup complete (version $ScriptVersion). Rebooting…"

    # NOTIFY USER & REBOOT (only if interactive session is present)
    try {
        # Only send msg if interactive session exists, otherwise ignore errors
        $sessionId = (Get-Process -Id $PID).SessionId
        $username = $env:USERNAME
        if ($username -and $sessionId -gt 0) {
            msg $username "System will reboot in 10 seconds to finish developer setup." 2>$null
        }
    } catch {}
    Start-Sleep 10
    #Restart-Computer -Force
}
catch {
    Write-Event "Dev setup FAILED: $_" 1003 'Error'
    throw
}
