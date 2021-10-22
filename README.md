## AD Group Sync 

A PowerShell solution for syncing AD group membership with either text files with user IDs or payroll information listed on AD accounts extended properties. 

### Required Setup

The PowerShell Active Directory Module must be installed on the system.

```powershell
# On Windows 10 systems
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```


