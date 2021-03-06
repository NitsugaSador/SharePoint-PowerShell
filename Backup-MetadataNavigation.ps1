﻿Param(
    [Parameter(Position=0,mandatory=$true)]
    [string]$targetLocation
    [Parameter(Position=1,mandatory=$false)]
    [string]$WebAppUrl = "",
    
)

if((Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue) -eq $null){
    Add-PSSnapin -Name Microsoft.SharePoint.PowerShell
}

Set-Location $targetLocation

$currentDate = Get-Date
$targetFolder = [System.String]::Concat($currentDate.Year, $currentDate.Month.ToString("D2"), $currentDate.Day.ToString("D2"))
$pathFolder = ([System.IO.Path]::Combine((Get-Location),$targetFolder))

Function Get-SPTerms($navTerms, $metdataFilePath){
    foreach($navTerm in $navTerms){
        Add-Content -Path $metadataFilePath -Value ([System.String]::Format("{0};{1};{2};{3};{4};{5};{6};{7}", 
                                                        $navTerm.TaxonomyName, 
							$navTerm.Terms.Count,
							$navTerm.LinkType,
                                                        $navTerm.ExcludeFromGlobalNavigation, 
                                                        $navTerm.ExcludeFromCurrentNavigation, 
                                                        $navTerm.FriendlyUrlSegment, 
                                                        $navTerm.TargetUrl, 
                                                        $navTerm.Parent))    
        if($navTerm.Terms.Count -gt 0){
            Get-SPTerms -navTerms $navTerm.Terms -metadataFilePath $metadataFilePath
        }
    }    
}

Function Backup-MetadataService([Microsoft.SharePoint.SPSite]$site){
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Taxonomy")
    $session = Get-SPTaxonomySession -Site $site
    $termStore = $session.TermStores["Servicio de metadatos administrados"]
    $group = $termStore.GetSiteCollectionGroup($site)
    $termSet = $group.TermSets["Navegación del sitio"]
    $navTermSet = [Microsoft.SharePoint.Publishing.Navigation.NavigationTermSet]::GetAsResolvedByWeb($termSet, 
								$site.RootWeb, "GlobalNavigationTaxonomyProvider")

    if($navTermSet.Terms.Count -gt 0){
        $metadataFilePath = [System.IO.Path]::Combine($pathFolder, $site.RootWeb.Title + $group.Name + ".txt")
        Get-SPTerms -navTerms $navTermSet.Terms -metadataFilePath $metadataFilePath
    }
}

if((Test-Path -Path $pathFolder) -ne $true){
    New-Item -ItemType directory -Path $pathFolder
}

Try{
    $webApps = @()
    if([System.String]::IsNullOrEmpty($WebAppUrl) -ne $true){
        $webApps = Get-SPWebApplication -Identity $WebAppUrl
    }
    else{
        $webApps = Get-SPWebApplication
    }
    foreach($webApp in $webApps){
        foreach($site in $webApp.Sites){
            Backup-MetadataService $site
        }
    }
}
Catch{
    Write-Error "This application doesn't exist"
}
