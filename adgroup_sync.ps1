<#
    Title: adgroup_sync.ps1
    Authors: Dean Bunn and Shriver
    Last Edit: 2021-10-22
#>

#Var for Config Settings
$cnfgSettings = $null; 

#Check for Settings File 
if((Test-Path -Path ./config.json) -eq $true)
{
  
    #Import Json Configuration File
    $cnfgSettings =  Get-Content -Raw -Path .\config.json | ConvertFrom-Json;

}
else
{
    #Create Blank Config Object and Export to Json File
    $blnkConfig = new-object PSObject -Property (@{ AD_Parent_Domain="parent.mycollege.edu"; 
                                                    AD_Child_Domain="child.parent.mycollege.edu"; 
                                                    AD_Groups=@(@{AD_Group="Group1";
                                                                  Object_GUID="8394daff-0da7-4b62-9c5f-d603328c7858";
                                                                  Data_Source_Text_File=".\Group1_UserIDs.txt";
                                                                  Payroll_Groups=@("024000","024001");},
                                                                @{AD_Group="Group2";
                                                                  Object_GUID="1bde534c-80ef-4a79-9117-54206e6eaede";
                                                                  Data_Source_Text_File=".\Group2_UserIDs.txt";
                                                                  Payroll_Groups=@("024003","024004");}
                                                                );
                                                  });

    $blnkConfig | ConvertTo-Json -Depth 4 | Out-File .\config.json;

    #Exit Script
    exit;
}

Write-Output $cnfgSettings.AD_Parent_Domain;

foreach($cfgADGrp in $cnfgSettings.AD_Groups)
{
    Write-Output $cfgADGrp.AD_Group;
    Write-Output $cfgADGrp.Object_GUID;
    Write-Output $cfgADGrp.Data_Source_Text_File;
}
