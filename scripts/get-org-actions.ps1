[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Org,
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if ($_ -notmatch "(\.csv$)") {
                throw "The file specified in the OutputFile argument must have the extension 'csv'"
            }
            return $true 
        })]
    [System.IO.FileInfo]    
    $OutputFile,
    [Parameter(Mandatory = $false)]
    [string]
    $Token,
    [Parameter(Mandatory = $false)]
    [switch]
    $Confirm
)

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

function FetchMarketplaceLink($action) {  
    $html = Invoke-WebRequest -Uri "https://github.com/$action" -UseBasicParsing

    if ($html.StatusCode -ne 200) {
        return ""
    }

    $marketplaceLink = $html.Links | Where-Object -Property "href" -Match "^/marketplace" | Select-Object -First 1 -ExpandProperty href

    if ($null -eq $marketplaceLink) {
        return ""
    }

    return "https://github.com$marketplaceLink"
}

function VerifyActionOnMarketplace($link) {    
    $marketplaceHtml = Invoke-WebRequest -Uri $link -UseBasicParsing

    if ($marketplaceHtml.StatusCode -ne 200) {
        return $false
    }

    return $marketplaceHtml.Content -match "Verified creator"
}

$token = GetToken -token $Token -envToken $env:GH_SOURCE_PAT

Write-Host "Fetching repos from organization '$Org'..." -ForegroundColor Blue
$repos = GetReposFromApi -org $Org -token $token

if ($repos.Length -eq 0) {
    Write-Host "No repos found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Fetching actions from organization '$Org'..." -ForegroundColor Blue

$actions = @()

$repos | ForEach-Object {
    $repo = $_
    
    $sbom = GetRepoSbom -org $Org -repo $repo.name -token $token

    if ($sbom -eq $null) {
        return
    }

    $repoActions = @($sbom.sbom.packages | Where-Object -Property "SPDXID" -Match "^SPDXRef-actions" | ForEach-Object {
            $repoAction = $_

            $actionName = $repoAction.name -replace "actions:", ""
            $actionVersion = $repoAction.versionInfo

            return [PSCustomObject]@{
                action_name           = $actionName
                action_version        = $actionVersion
                is_internal           = $actionName -match "^${Org}/"
                is_allowed            = $false
                is_github_or_verified = $false
                marketplace_link      = ""
            }
        })

    $actions += $repoActions
}

if ($null -eq $actions) {
    Write-Host "No actions found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

$uniqueActions = $actions | Sort-Object -Property "action_name" -Unique

$uniqueActions | ForEach-Object {
    $action = $_

    $actionName = $action.action_name

    Write-Host "Fetching marketplace link for action '$actionName'..." -ForegroundColor White

    $marketplaceLink = FetchMarketplaceLink -action $actionName

    $isAllowed = $false
    $isGithubOrVerified = $false

    if ($actionName -match "^github/" -or $actionName -match "^actions/" -or $actionName -match "^azure/") {
        $isAllowed = $true
        $isGithubOrVerified = $true
    }
    elseif ($actionName -notmatch "^${Org}/") {
        Write-Host "Checking if action $actionName is verified on marketplace..." -ForegroundColor Yellow 

        if ($(VerifyActionOnMarketplace $marketplaceLink)) {
            $isAllowed = $true
            $isGithubOrVerified = $true
        }
    }

    $action.is_allowed = $isAllowed
    $action.is_github_or_verified = $isGithubOrVerified
    $action.marketplace_link = $marketplaceLink
}

Write-Host "Saving actions to '$($OutputFile.FullName)'..." -ForegroundColor Magenta

SaveTo-Csv -Data $uniqueActions -OutputFile $OutputFile -Confirm $Confirm

Write-Host "Done." -ForegroundColor Green