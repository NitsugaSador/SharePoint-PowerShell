if(!(Get-PSSnapin Microsoft.SharePoint.PowerShell -ea 0)){ 
    Write-Progress -Activity "Loading Modules" -Status "Loading Microsoft.SharePoint.PowerShell" 
    Add-PSSnapin Microsoft.SharePoint.PowerShell 
} 

$webApp = Get-SPWebApplication -Identity $WebAppUrl;

#Create TermSet Navigation.
$site = Get-SPSite -identity $webApp.Url

$session = Get-SPTaxonomySession -Site $site
$termStore = $session.TermStores[0]
$group = $termStore.GetSiteCollectionGroup($webApp.Url)
$termSet = $group.TermSets["Navegación del sitio"]

if($termSet -eq $null)
{
    $group.CreateTermSet("Navegación del sitio")
    $termStore.CommitAll()
    $termSet = $group.TermSets["Navegación del sitio"]
}
else{
    $termSet.Delete()
    $termStore.CommitAll()
}

$navTermSet = [Microsoft.SharePoint.Publishing.Navigation.NavigationTermSet]::GetAsResolvedByWeb($termSet, $site.RootWeb, "GlobalNavigationTaxonomyProvider")

$navigationContent = Get-Content -Path $pathTermSetTXT
$term = $null;
$parentTerm = $null;

for ($i=0; $i -le $navigationContent.Length; $i++){
    $lineContent = $navigationContent[$i].Split(';')
    if([System.String]::IsNullOrEmpty($lineContent[0]<#TaxonomyName#>) -ne $true){
        if([System.String]::IsNullOrEmpty($lineContent[2]<#LinkType#>) -ne $true){
            $navigationLinkType = ([Microsoft.SharePoint.Publishing.Navigation.NavigationLinkType]$lineContent[2]<#LinkType#>);
            switch ($navigationLinkType) { 
                FriendlyUrl {
                    if([System.String]::IsNullOrEmpty($lineContent[7]<#Parent#>) -ne $true){
                         if($lineContent[7].Equals($parentTerm.TaxonomyName)){
                            $term = $parentTerm.CreateTerm($lineContent[0], $navigationLinkType, [GUID]::NewGuid())
                         }
                         else{
                            $term = $navTermSet.CreateTerm($lineContent[0], $navigationLinkType, [GUID]::NewGuid())
                         }
                    }
                    else{
                        $term = $navTermSet.CreateTerm($lineContent[0], $navigationLinkType, [GUID]::NewGuid())
                    }
                } 
                SimpleLink {
                    if([System.String]::IsNullOrEmpty($lineContent[7]<#Parent#>) -ne $true){
                         if($lineContent[7].Equals($parentTerm.TaxonomyName)){
                            $term = $parentTerm.CreateTerm($lineContent[0], $navigationLinkType, [GUID]::NewGuid())
                         }
                         else{
                            $term = $navTermSet.CreateTerm($lineContent[0], $navigationLinkType, [GUID]::NewGuid())
                         }
                    }
                    else{
                        $term = $navTermSet.CreateTerm($lineContent[0], $navigationLinkType, [GUID]::NewGuid())
                    }
                } 
                default { throw "Not implemented link type"}
            }
        }
        
        if([System.String]::IsNullOrEmpty($lineContent[3]<#ExcludeFromGlobalNavigation#>) -ne $true){
             $term.ExcludeFromGlobalNavigation = ([System.Boolean]::Parse($lineContent[3]));
        }
        if([System.String]::IsNullOrEmpty($lineContent[4]<#ExcludeFromCurrentNavigation#>) -ne $true){
             $term.ExcludeFromCurrentNavigation = ([System.Boolean]::Parse($lineContent[4]));
        }
        if([System.String]::IsNullOrEmpty($lineContent[5]<#FriendlyUrlSegment#>) -ne $true){
             $term.FriendlyUrlSegment.Value = $lineContent[5];
        }
        if([System.String]::IsNullOrEmpty($lineContent[6]<#TargetUrl#>) -ne $true){
             $term.TargetUrl.Value = $lineContent[6];
        }
        if([System.String]::IsNullOrEmpty($lineContent[1]<#NumberOfChild#>) -ne $true){
            if(([int]$lineContent[1]) -gt 0){
                $parentTerm = $term;
            }
        }
    }
    else{
        Write-Host "Imposible create Term because Taxonomy Name doesn't exist"
    }
}

$termstore.CommitAll()
$termStore.FlushCache()

$assignment = Start-SPAssignment

$web = Get-SPWeb -Identity $webApp.Url -AssignmentCollection $assignment

$termSet = $group.TermSets["Navegación del sitio"]
$navSettings = New-Object Microsoft.SharePoint.Publishing.Navigation.WebNavigationSettings($web)
$taxSession = Get-SPTaxonomySession -Site $webApp.Url

$navSettings.GlobalNavigation.Source = 2
$navSettings.GlobalNavigation.TermStoreId = $termStore.Id
$navSettings.GlobalNavigation.TermSetId = $termSet.Id


#Quick Launch
$navSettings.CurrentNavigation.Source = 2
$navSettings.CurrentNavigation.TermStoreId = $termStore.Id
$navSettings.CurrentNavigation.TermSetId = $termSet.Id

$navSettings.Update()

$web.Update()

Stop-SPAssignment $assignment
