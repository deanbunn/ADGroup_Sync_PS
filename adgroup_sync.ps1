<#
    Title: adgroup_sync.ps1
    Authors: Dean Bunn and Shriver
    Last Edit: 2021-10-25
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

#Write-Output $cnfgSettings.AD_Parent_Domain;

foreach($cfgADGrp in $cnfgSettings.AD_Groups)
{
    #Hash Table for Data Source DNs 
    $htDSDNs = @{};

    #Hash Table for Members to Remove from AD Group  
    $htMTRFG = @{};

    #HashTable for Members to Add to AD Group
    $htMTATG = @{};

    #Check for Name of Data Source Text File to Load
    if([string]::IsNullOrEmpty($cfgADGrp.Data_Source_Text_File) -eq $false)
    {
        #Var for Data Source File Path
        [string]$dsFilePath = $cfgADGrp.Data_Source_Text_File;

        #Check for Data Source Text File (with user IDs or email addresses)
        if((Test-Path -Path $dsFilePath) -eq $true)
        {
            #Get List of User IDs or Email Addresses
            $fcUsers = Get-Content -Path $dsFilePath;

            #Load User Into Users to Add Hash Table
            foreach($fcUser in $fcUsers)
            {
                #Check for Null\Empty Entries
                if([string]::IsNullOrEmpty($fcUser) -eq $false)
                {
                    #Var for AD Filter
                    [string]$fltrAD = "";

                    #Check for User Login vs Email Address
                    if($fcUser.ToString().Contains("@") -eq $false)
                    {
                        $fltrAD = "sAMAccountName -eq '" + $fcUser.ToString().Trim() + "'";
                    }
                    else
                    {
                        $fltrAD = "userPrincipalName -eq '" + $fcUser.ToString().Trim() + "' -or proxyAddresses -eq 'smtp:" + $fcUser.ToString().Trim() + "'";
                    }

                    #Check Parent Domain for User Account
                    $fcADUser = Get-ADUser -Filter $fltrAD -Server $cnfgSettings.AD_Parent_Domain -ResultSetSize 1;

                    #Check User to Add HashTable for Existing DN
                    if([string]::IsNullOrEmpty($fcADUser.DistinguishedName) -eq $false -and $htDSDNs.ContainsKey($fcADUser.DistinguishedName) -eq $false)
                    {
                        #Add to Data Source DNs HashTable
                        $htDSDNs.Add($fcADUser.DistinguishedName,"1");
                        
                    }#End of $fcADUser DN Checks

                }#End of Null\Empty Checks

            }#End of $fcUsers Foreach

        }#End of Data Source Text File

    }#End of Data Source Text File Name Null\Empty Check
    
    


    #Write-Output $cfgADGrp.AD_Group;
    #Write-Output $cfgADGrp.Object_GUID;
    #Write-Output $cfgADGrp.Data_Source_Text_File;

    Write-Output " ";
    Write-Output " ";

}#End of AD_Groups Foreach
