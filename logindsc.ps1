$ThemePath = "C:\Windows\Resources\Themes\avd-dark.theme"
$CurrentTheme = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes").CurrentTheme


    Start-Process -FilePath $ThemePath
    Start-Sleep -Seconds 3
    Stop-Process -Name "SystemSettings" -Force
    Write-Output "Theme has been changed to avd-dark."


$groupName = "docker-users"
$currentUserName = [System.Environment]::UserName
$group = Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue

if ($group) {
    $isMember = Get-LocalGroupMember -Group $groupName -Member "AzureAD\$currentUserName" -ErrorAction SilentlyContinue
    if ($isMember) {
        Write-Output "User '$currentUserName' is already a member of group '$groupName'. No action taken."
    } else {
        try {
            Add-LocalGroupMember -Group $groupName -Member $currentUserName
            Add-LocalGroupMember -Group $groupName -Member "NT AUTHORITY\Authenticated Users"
            Write-Output "Successfully added user '$currentUserName' and authenticated users to group '$groupName'."

            wsl --install -d ubuntu --no-launch
            wsl --update
            Write-Output "WSL installation and update complete. Preparing to restart for development environment setup."
           
	        #choco install python3 -y
            #choco install multipass -y
            #Get-HNSNetwork | ? Name -Like "Default Switch" | Remove-HNSNetwork
            #Disable-WindowsOptionalFeature -FeatureName "Windows-Defender-ApplicationGuard" -Online 

            $registryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"

            $propertyName = "RestartApps"
            if (Test-Path -Path "$registryPath\$propertyName") {
                Set-ItemProperty -Path $registryPath -Name $propertyName -Value 1
                Write-Output "Restart apps feature is now enabled."
            } else {
                New-ItemProperty -Path $registryPath -Name $propertyName -Value 1 -PropertyType DWORD
                Write-Output "Restart apps feature is now enabled and configured."
            }

            $uri="https://github.com/coder/coder/releases/download/v2.9.1/coder_2.9.1_windows_amd64_installer.exe"
                Invoke-WebRequest -Uri $uri -OutFile "C:\Windows\Temp\coder_2.9.1_windows_amd64_installer.exe"
                $uri="https://github.com/coder/coder/releases/download/v2.9.1/coder_2.9.1_checksums.txt"
                Invoke-WebRequest -Uri $uri -OutFile "C:\Windows\Temp\coder_2.9.1_checksums.txt"

                $checksum = (Get-Content "C:\Windows\Temp\coder_2.9.1_checksums.txt" | Select-String -Pattern "coder_2.9.1_windows_amd64_installer.exe").ToString().Split()[0]
                $checksum_validation = Get-FileHash -Path "C:\Windows\Temp\coder_2.9.1_windows_amd64_installer.exe" -Algorithm SHA256

                if ($checksum -eq $checksum_validation.Hash) {
                    # Install coder
                    Start-Process -FilePath "C:\Windows\Temp\coder_2.9.1_windows_amd64_installer.exe" -ArgumentList "/S" -Wait
                } else {
                    Write-Host "Checksum validation failed"
                    exit 1
                }

                New-NetFirewallRule -DisplayName "Allow Coder Executable" -Direction Inbound -Program "C:\program files\coder\bin\coder.exe" -Action Allow
                
                Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
                Start-Process -FilePath "C:\Program Files\Coder\bin\coder" -ArgumentList "server" -WindowStyle Hidden
                
                Set-Content -Path "C:\Program Files\Coder\CoderInit.ps1" -Value $script

                # create registry key to run coder on startup for all users
                $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
                $regName = "Coder"
                $regValue = 'powershell -ExecutionPolicy Bypass -File "C:\Program Files\Coder\CoderInit.ps1"'
                New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force

            msg $currentUserName "System will be rebooting in 10 seconds to finish Dev setup for $currentUserName. Please log back in to continue."
            Start-Sleep 10

            Restart-Computer -Force
            Write-Output "Restarting Computer, please log back in shortly to continue developer setup."
        } catch {
            Write-Error "Failed to add user '$currentUserName' to group '$groupName'. Error: $_"
        }
    }
} else {
    Write-Error "Group '$groupName' not found."
}
