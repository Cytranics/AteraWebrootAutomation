#Created by Cory Coddington 2022
#Enter your Atera API Key and Custom Field that contains the webroot key.
$AteraAPIKey = 'API KEY'
$FieldName = 'WebRootKey'

#Check if webroot is installed.
$service = Get-Service -Name WRSVC -ErrorAction SilentlyContinue
if (-Not $service -eq $null -Or $service.Status -eq "Running") {
    write-host "Webroot appears to be running and installed. Exiting, please uninstall webroot before proceeding"
    Exit
    }
    Write-Host "Webroot Appears to be missing or uninstalled, lets proceed."

#Install Atera module and pre-reqs
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityPotocol -bor 3072; Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force;
Install-Module PSAtera -Force

Import-Module -Name PSAtera -MinimumVersion 1.3.1

Set-AteraAPIKey -APIKey $AteraAPIKey

# Get the agent information for the PC that's running the script
$agent = Get-AteraAgent

# Get the value from the Customer endpoint
$customValue = Get-AteraCustomValue -ObjectType Customer -ObjectId $agent.CustomerID -FieldName $FieldName


# This script will need to run under system context in order for the start-process cmdlet to initiate the installer with proper privledges
# Check for existing paths. Create if not existant.  Kill script if write access to C: isn't available.
function install-webroot {
    try {
        $test = gci "C:\AteraTmp\webroot" -ErrorAction SilentlyContinue
        if ($test -eq $true){
            write-host "Path Exists, proceeding..."
        } else {
            write-host "Path does not exist, creating"
            New-item -ItemType Directory -Path "C:\AteraTmp" -ErrorAction SilentlyContinue | out-null
            New-item -ItemType Directory -Path "C:\AteraTmp\webroot" -ErrorAction SilentlyContinue | out-null
        }
    } catch {
        write-host "Path Created Successfully."
        Break
    }
    #
    # Set TLS 1.2.  Without this setting invoke-webrequest frequently returns an error saying the "The underlying connection was closed: An unexpected error occurred on a send"
    #
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    #
    # Initiate file download, overwrite if existing
    #
    Invoke-WebRequest -Uri "https://downbox.webrootanywhere.com/wsasmeexe/wsasme.exe" -UseBasicParsing -OutFile "C:\AteraTmp\webroot\wsasme.exe"
    Sleep 1
    #
    # Start installation process
    #
    Start-Process -FilePath "C:\AteraTmp\webroot\wsasme.exe" -ArgumentList "/key=$($customValue.ValueAsString) /silent"
    #
    # Monitor the process for completion
    #
    do {
        $install = get-process | where {$_.Name -eq "wsasme"}
        Sleep 5
    } while ($install -ne $null)
    #
    # Finally write or do something indicating the install is complete
    #
    write-host "Installation Complete."
}
install-webroot
