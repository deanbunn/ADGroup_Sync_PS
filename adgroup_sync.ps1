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
                                                    AD_User_Search_Base="OU=CampusUsers,DC=parent,DC=mycollege,DC=edu"; 
                                                    AD_Groups=@(@{AD_Group="Group1";
                                                                  Object_GUID="8394daff-0da7-4b62-9c5f-d603328c7858";
                                                                  Data_Source_Text_File=".\Group1_UserIDs_Or_Email_Addresses.txt";
                                                                  Payroll_Groups=@("024000","024001");},
                                                                @{AD_Group="Group2";
                                                                  Object_GUID="1bde534c-80ef-4a79-9117-54206e6eaede";
                                                                  Data_Source_Text_File=".\Group2_UserIDs_Or_Email_Addresses.txt";
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
                    $fcADUser = Get-ADUser -Filter $fltrAD -SearchBase $cnfgSettings.AD_User_Search_Base -Server $cnfgSettings.AD_Parent_Domain -ResultSetSize 1;

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
    
    #Check for Payroll Groups to Query
    if($cfgADGrp.Payroll_Groups.Length -gt 0)
    {

        foreach($payrollGrp in $cfgADGrp.Payroll_Groups)
        {
            #Format AD Filter for Payroll Group Information
            [string]$fltPRGrp = "extensionAttribute9 -Like '*appt" + $payrollGrp + "*' -and extensionAttribute11 -ne 'D'";
            
            #Pull Users with Extension Attribute Set for Payroll Group
            $arrADUsersPR = Get-ADUser -Filter $fltPRGrp -Properties extensionAttribute9,extensionAttribute8,extensionAttribute7 -SearchBase $cnfgSettings.AD_User_Search_Base -Server $cnfgSettings.AD_Parent_Domain;

            foreach($ADuserPR in $arrADUsersPR)
            {
                #Check DN Before Loading (Prevent Accounts In Not Controlled OUs)
                if([string]::IsNullOrEmpty($ADuserPR.DistinguishedName) -eq $false -and $htDSDNs.ContainsKey($ADuserPR.DistinguishedName) -eq $false)
                {
                    #Add to Data Source DNs HashTable
                    $htDSDNs.Add($ADuserPR.DistinguishedName,"1");
                }#End of DN Checks

            }#End of $arrADUsersPR Foreach
            
        }#End of Payroll_Groups Foreach

    }#End of Payroll Groups Empty Check

    #Pull AD Group Membership
    $crntGrpMembers = Get-ADGroupMember -Identity $cfgADGrp.Object_GUID -Server $cnfgSettings.AD_Child_Domain;

    #Load Current Members Into Removals HashTable
    foreach($crntGrpMember in $crntGrpMembers)
    {
        #Check DN for AD Users OU Path (No Child Domain Accounts or Groups)
        if([string]::IsNullOrEmpty($crntGrpMember.distinguishedName) -eq $false -and $crntGrpMember.distinguishedName.ToString().ToLower().Contains($cnfgSettings.AD_User_Search_Base.ToString().ToLower()) -eq $true)
        {
            $htMTRFG.Add($crntGrpMember.distinguishedName,"1");
        }
        
    }

    #Check Data Source Accounts
    if($htDSDNs.Count -gt 0)
    {
        #Check Data Source Members
        foreach($dsDN in $htDSDNs.Keys)
        {
            #Don't Remove Existing Members In Data Source Listing
            if($htMTRFG.ContainsKey($dsDN) -eq $true)
            {
                $htMTRFG.Remove($dsDN);
            }
            else 
            {
                #Add Them to List to Be Added to Group
                $htMTATG.Add($dsDN.ToString(),"1");
            }

        }#End of Data Source Members Add or Remove Checks

    }#End of Data Source Accounts Checks

    #Check for Members to Remove
    if($htMTRFG.Count -gt 0)
    {
        foreach($mtrfg in $htMTRFG.Keys)
        {
            #Remove Existing Member
            Remove-ADGroupMember -Identity $cfgADGrp.Object_GUID -members (Get-ADUser -Identity $mtrfg.ToString() –Server $cnfgSettings.AD_Parent_Domain) -Server $cnfgSettings.AD_Child_Domain -Confirm:$false;
        }
    }#End of Members to Remove

    #Check for Members to Add
    if($htMTATG.Count -gt 0)
    {
        foreach($mtatg in $htMTATG.Keys)
        {
            #Add New Member
            Add-ADGroupMember -Identity $cfgADGrp.Object_GUID -members (Get-ADUser -Identity $mtatg.ToString() –Server $cnfgSettings.AD_Parent_Domain) -Server $cnfgSettings.AD_Child_Domain -Confirm:$false;
        }

    }#End of Members to Add

}#End of AD_Groups Foreach
