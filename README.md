## AD Group Sync 

A PowerShell solution for syncing AD group membership with text files, containing user IDs or email addresses, and\or payroll information listed on AD accounts extended properties. 

Upon first run, the script will create the config.json file used to store the settings. Edit the file to fit your environment. 

Currently, the AD group being sync'd are located in a child domain and the user accounts are located in the parent domain.

Group retrieval by GUID reduces configuration file maintenance. 

### Required Setup

The PowerShell Active Directory Module must be installed on the system.

```powershell
# On Windows 10 systems
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

Pull the GUID of an AD Group
```powershell
(Get-ADGroup -Identity MyGroupName -Server child.parent.mycollege.edu).ObjectGUID.ToString();
```

