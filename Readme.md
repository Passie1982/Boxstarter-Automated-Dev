## Automate development Environment ##


### Requirements ###

- Powershell 4.0 (installing powershell is out of scope, see: [http://www.microsoft.com/web/downloads/platform.aspx](http://www.microsoft.com/web/downloads/platform.aspx))
- Boxstarter

### Install Boxstarter ###
Download the boxstarter package from: [http://boxstarter.org/](http://boxstarter.org/). Unzip the package and run the setup.bat file. After installation Boxstarter is ready to run some scripts.

### Run the script ###
Download the the file Azure-CreateAndPrepareVM.ps1 from the repository. Use powershell in administrative mode and execute the script by the following commands:

    .\Azure-CreateAndPrepareVM.ps1 -imageFamilyName "Visual Studio Premium 2013 Update 4 on Windows 8.1 Enterprise N (x64)" -azurePublishSettingsFile "c:\temp\publishfile.publishsettings" -subscriptionName "Subscription name" -storageAccountName "Storage account name" -vmName “VM name" -vmSize "Large" -vmLocation "West Europe" -vmUserName "User name" -cloudServiceName "Cloud service name"

Please note that the parameters have to filled with correct data and that tha cloudServiceName parameter is optional