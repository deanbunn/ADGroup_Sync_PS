<#
    Title: adgroup_sync.ps1
    Authors: Dean Bunn and Shriver
    Last Edit: 2021-10-28
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
                                                                  Payroll_Filter="faculty,staff";
                                                                  Payroll_Groups=@("024000","024001");},
                                                                @{AD_Group="Group2";
                                                                  Object_GUID="1bde534c-80ef-4a79-9117-54206e6eaede";
                                                                  Data_Source_Text_File=".\Group2_UserIDs_Or_Email_Addresses.txt";
                                                                  Payroll_Filter="";
                                                                  Payroll_Groups=@("024003","024004");}
                                                                );
                                                  });

    #Payroll Filter Types employee, external, faculty, hs, staff, student

    $blnkConfig | ConvertTo-Json -Depth 4 | Out-File .\config.json;

    #Exit Script
    exit;
}

# Go Through Each of the Sync Groups Listed in the Config file
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
        #HashTable for Payroll Affiliation Types 
        $htPRAF = @{};

        #Check for Payroll Affilition Types to Load
        if([string]::IsNullOrEmpty($cfgADGrp.Payroll_Filter) -eq $false)
        {
            #If Comma Separated List Found Load PR Hash with It
            if($cfgADGrp.Payroll_Filter.ToString().Contains(",") -eq $true)
            {
                foreach($strPRType in $cfgADGrp.Payroll_Filter.ToString().Split(','))
                {
                    $htPRAF.Add($strPRType.ToString().ToLower().Trim(),"1");
                }
            }
            else 
            {
                #Just Load the One Value
                $htPRAF.Add($cfgADGrp.Payroll_Filter.ToString().ToLower().Trim(),"1");
            }#End of Comma Check on PR Fitler
            
        }#End of Payroll Filter Setup Checks
        

        foreach($payrollGrp in $cfgADGrp.Payroll_Groups)
        {

            #Format AD Filter for Payroll Group Information (Not Pull Department Accounts)
            [string]$fltPRGrp = "extensionAttribute9 -Like '*appt" + $payrollGrp + "*' -and extensionAttribute11 -ne 'D'";
            
            #Pull Users with Extension Attribute Set for Payroll Group
            $arrADUsersPR = Get-ADUser -Filter $fltPRGrp -Properties extensionAttribute8 -SearchBase $cnfgSettings.AD_User_Search_Base -Server $cnfgSettings.AD_Parent_Domain;

            foreach($ADuserPR in $arrADUsersPR)
            {

                #Var for Add User
                $bAddToDS = $false;

                #Check DN Before Loading (Prevent Accounts In Not Controlled OUs)
                if([string]::IsNullOrEmpty($ADuserPR.DistinguishedName) -eq $false -and $htDSDNs.ContainsKey($ADuserPR.DistinguishedName) -eq $false)
                {

                    #Check for Payroll Filter
                    if($htPRAF.Count -gt 0)
                    {
                        #Check User Extension Attribute 8 Value
                        if([string]::IsNullOrEmpty($ADuserPR.extensionAttribute8) -eq $false)
                        {
                            #Var for Individual User's Payroll Association Types
                            $arrUsrPrTypes = @();

                            #Check for Multiple Values on IAM Affiliations
                            if($ADuserPR.extensionAttribute8.ToString().Contains(",") -eq $true)
                            {
                                foreach($prType in $ADuserPR.extensionAttribute8.ToString().ToLower().Trim().Split(','))
                                {
                                    $arrUsrPrTypes += $prType;
                                }
                            }
                            else 
                            {
                                #Add Singular Affiliation Enty
                                $arrUsrPrTypes += $ADuserPR.extensionAttribute8.ToString().ToLower().Trim();
                            }

                            #Check Payroll Association Types for Changing Add Status
                            foreach($prUsrAsc in $arrUsrPrTypes)
                            {
                                if($htPRAF.ContainsKey($prUsrAsc) -eq $true)
                                {
                                    $bAddToDS = $true;
                                }
                            }#End of Payroll Association Check

                        }#End of Extension Attribute 8 Check
                        
                    }
                    else 
                    {
                        $bAddToDS = $true;
                    }#End of Payroll Filter Checks

                    #Check Status Before Adding to Data Source DN HashTable
                    if($bAddToDS -eq $true)
                    {
                        #Add to Data Source DNs HashTable
                        $htDSDNs.Add($ADuserPR.DistinguishedName,"1");
                    }

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









