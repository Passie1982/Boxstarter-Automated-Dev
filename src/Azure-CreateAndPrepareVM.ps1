﻿<#
.SYNOPSIS
    Create a new Virtual Machine and install all the pre-defined programs.
.DESCRIPTION
    Create a new Virtual Machine based on the parameters that were given. 
    The script configures the Windows environment and installs all the pre-defined programs from a script.

    The script must be executed with elevated privileges.
.EXAMPLE
    .\Azure-CreateAndPrepareVM.ps1 -imageFamilyName "Visual Studio Premium 2013 Update 4 on Windows 8.1 Enterprise N (x64)" -azurePublishSettingsFile "c:\temp\publishfile.publishsettings" -subscriptionName "Subscription name" -storageAccountName "Storage account name" -vmName “VM name" -vmSize "Large" -vmLocation "West Europe" -vmUserName "User name" -cloudServiceName "Cloud service name"
    .\Azure-CreateAndPrepareVM.ps1 -imageFamilyName "Visual Studio Premium 2013 Update 4*" -azurePublishSettingsFile "c:\temp\publishfile.publishsettings" -subscriptionName "Subscription name" -storageAccountName "Storage name" -vmName “VM name" -vmSize "Large" -vmLocation "West Europe" -vmUserName "User name"
#>

Param(
    # The family name of the image. Please note that this string can contain the wildcard character *
    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$false)]
    [string]$imageFamilyName, 

    # The path of the Azure Publish Settings file
    [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$false)]
    [string]$azurePublishSettingsFile, 

    # The name of the subscription
    [Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$false)]
    [string]$subscriptionName, 

    # The name of the Storage Account which will be used to store the Virtual Machine. Please note the script will not create a storage account
    [Parameter(Mandatory=$true, Position=3, ValueFromPipeline=$false)]
    [string]$storageAccountName, 

    # The name of the Virtual Machine. The name will also be used as the Cloud Service name that will be created
    [Parameter(Mandatory=$true, Position=4, ValueFromPipeline=$false)]
    [string]$vmName, 

    # The size of the Virtual Machine
    [Parameter(Mandatory=$true, Position=5, ValueFromPipeline=$false)]
    [ValidateSet("extra small", "small", "medium", "large", "extra large")] 
    [string]$vmSize, 

    # The location where the Virtual Machine will be stored
    [Parameter(Mandatory=$true, Position=6, ValueFromPipeline=$false)]
    [ValidateSet("Central US", "East US", "East US 2", "US Gov Iowa", "US Gov Virginia", "North Central US", "South Central US", "West US", "North Europe", "West Europe", "East Asia", "Southeast Asia", "Japan East", "Japan West", "Brazil South", "Australia East", "Australia Southeast")] 
    [string]$vmLocation,

    # The username for logging into the Virtual Machine
    [Parameter(Mandatory=$true, Position=7, ValueFromPipeline=$false)]
    [string]$vmUserName,

    # The cloud servixe name where the Virtual Machine will be stored in
    [Parameter(Mandatory=$false, Position=8, ValueFromPipeline=$false)]
    [string]$cloudServiceName

    )

<#
.SYNOPSIS
    Get the latest image disk name for a specific imageFamily.
.DESCRIPTION
    Get the latest image disk name for a specific imageFamily.
.INPUTS
    $imageFamilyName - The image family name of an operating system.
    $vmLocation - The image 
.OUTPUTS
    None.
#>

function GetLatestImage
{
    param(
        # The image family name of the vm image
        [string]$imageFamilyName,

        # The location of the vm
        [string]$vmLocation
        )

    $image = get-azurevmimage | where { $_.imagefamily -eq $imageFamilyName } | where { $_.location.split(";") -contains $vmLocation} | sort-object -descending -property publisheddate
	
    if($image -eq $null){
        Write-Host "$(Get-Date): No image found for $imageFamilyName on location $vmLocation." 

        return $null
    }	
    else{
         Write-Host "$(Get-Date): Image found for $imageFamilyName on location $vmLocation."
         Write-Host "$(Get-Date): Image disk: " $image.ImageName

         return $image.ImageName
    } 
}

<#
.SYNOPSIS
    Create a new Virtual Machine.
.DESCRIPTION
    Create a new Virtual Machine. If there exits a Cloud Service with the same name, it will be removed along with its deployments.
.INPUTS
    $imageName - The name of the base Virtual Machine image.
    $storageAccountName - The name of the Storage Account which will be used to store the Virtual Machine.
    $serviceName - The name of the Cloud Service for the Virtual Machine.
    $vmName - The name of the Virtual Machine.
    $vmSize - The size of the Virtual Machine.
    $vmUserName - The name of the admin account.
    $vmUserPassword - The password of the admin account. 
.OUTPUTS
    None.
#>

function CreateVirtualMachine
{
    param(
        # The name of the base Virtual Machine image
        [string]$imageName,
         
        # The name of the Storage Account which will be used to store the Virtual Machine
        [string]$storageAccountName, 

        # The name of the Cloud Service for the Virtual Machine
        [string]$serviceName, 

        # The name of the Virtual Machine
        [string]$vmName, 

        # The size of the Virtual Machine
        [string]$vmSize,

        # The size of the Virtual Machine
        [string]$vmUserName, 

        # The credentials of the vm
        [string]$vmUserPassword 

        )

    # Check if storage account exists
    $storageAccount = Get-AzureStorageAccount -StorageAccountName $storageAccountName
    if(!$storageAccount)
    {
        Write-Host "$(Get-Date): $storageAccountName doesn't exist. Run New-AzureStorageAccount to create a new one."
        return
    }

    # Determine new vm configuration with provisioning
    $vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize $vmSize -ImageName $imageName |
                    Add-AzureProvisioningConfig -Windows -EnableWinRMHttp -AdminUsername $vmUserName -Password $vmUserPassword
         
    Write-Host "$(Get-Date): Start to create virtual machine: $vmName." 

    New-AzureVM -VMs $vmConfig -Location $storageAccount.Location -ServiceName $serviceName -WaitForBoot
}

<#
.Synopsis
   Download and install a WinRm certificate to the certficate store
.DESCRIPTION
   Gets the WinRM certificate from the specified Virtual Machine, and install it on the LocalMachine store.
.INPUTS
   $serviceName - The name of the Cloud Service.
   $vmName - The name of the Virtual Machine.
.OUTPUTS
   NONE
#>

function DownloadAndInstallWinRMCert
{
    param(
        # The name of the Cloud Service
        [string]$serviceName, 

        # The name of the Virtual Machine
        [string]$vmName
        )
    
    $winRMCert = (Get-AzureVM -ServiceName $serviceName -Name $vmname | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
 
    $AzureX509cert = Get-AzureCertificate -ServiceName $serviceName -Thumbprint $winRMCert -ThumbprintAlgorithm sha1
 
    $certTempFile = [IO.Path]::GetTempFileName()

    $AzureX509cert.Data | Out-File $certTempFile
 
    $certToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile
 
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"

    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

    $exists = $false
    foreach($certificate in $store.Certificates)
    {
        if($certificate.Thumbprint -eq $certToImport.Thumbprint)
        {
            $exists = $true
            break
        }
    }
    
    if(!$exists)
    {
        $store.Add($certToImport)
    }

    $store.Close()
 
    Remove-Item $certTempFile
}

<#
.Synopsis
   Decorates the vm image with pre configured setings and applications
.DESCRIPTION
   Decorates the vm image with pre configured setings and applications.
.INPUTS
   $serviceName - The name of the Cloud Service.
   $vmName - The name of the Virtual Machine.
   $credentials vor the vm $vmName/$vmUsername
.OUTPUTS
   NONE
#>

function DecorateVM
{
    param(
        # The name of the Cloud Service
        [string]$serviceName, 

        # The name of the Virtual Machine
        [string]$vmName,

        # The name of the Virtual Machine
        $credentials

        )
    
    Enable-BoxstarterVM -provider Azure -CloudServiceName $serviceName `
        -VMName $vmName -Credential $credentials  | 
    Install-BoxstarterPackage `
     -Package https://gist.githubusercontent.com/anonymous/0efc2c8de71ca1a72e34/raw/a5f337017ed19a4ffadbae155e9aff8feb12d55b/gistfile1.txt
    
}

# Prepare azure environement

# Get the credentials from the user 
$credentials = Get-Credential  $vmName\$vmUserName

Import-AzurePublishSettingsFile -PublishSettingsFile $azurePublishSettingsFile -ErrorAction Stop
Select-AzureSubscription -SubscriptionName $subscriptionName -ErrorAction Stop
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccount $storageAccountName -ErrorAction Stop

$imageName = GetLatestImage $imageFamilyName $vmLocation

if($imageName -eq $null){
    Write-Error "$(Get-Date): No valid image found. Please check if the imageFamilyName is correct or change the vmLocation"
    return
}

# Use vmName as serviceName. Clean up the existing one before creation.
if($cloudServiceName -eq $null){
    $cloudServiceName = $vmName
}

CreateVirtualMachine $imageName $storageAccountName $cloudServiceName $vmName $vmSize $vmUserName $credentials.GetNetworkCredential().Password

Write-Host "$(Get-Date): Start to download and install the remoting cert (self-signed) to local machine trusted root." -ForegroundColor Green
DownloadAndInstallWinRMCert $cloudServiceName $vmName

Write-Host "$(Get-Date): Start to decorate the vm image with configuration and applications" -ForegroundColor Green
DecorateVM $cloudServiceName $vmName $credentials

Write-Host "$(Get-Date): Please run Get-AzureRemoteDesktopFile to connect the machine and login as $vmName\$vmUserName." -ForegroundColor Green 