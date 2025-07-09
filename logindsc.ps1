$ThemePath = "C:\Windows\Resources\Themes\avd-dark.theme"
$CurrentTheme = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes").CurrentTheme
$groupName = "docker-users"
$currentUserName = [System.Environment]::UserName
$group = Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue
msg $currentUserName "$currentUserName."
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

            msg $currentUserName "System will be rebooting in 10 seconds to finish Dev setup for $currentUserName. Please log back in to continue."
            Start-Sleep 10
	    Remove-Item -Path 'C:\\Users\\Public\\Desktop\\*'
            Restart-Computer -Force
            Write-Output "Restarting Computer, please log back in shortly to continue developer setup."
        } catch {
            Write-Error "Failed to add user '$currentUserName' to group '$groupName'. Error: $_"
        }
    }
} else {
    Write-Error "Group '$groupName' not found."
}
