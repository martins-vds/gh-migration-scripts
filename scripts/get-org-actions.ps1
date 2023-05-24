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

function IsKnownCreator($action) {

    $knownCreators = @(
        "github",
        "actions",
        "docker",
        "azure",
        "snyk",
        "redhat-actions",
        "aws-actions",
        "hashicorp",
        "microsoft"
    )

    return $knownCreators | Where-Object { $action -match "^$_" } | Select-Object -First 1
}

function FixVersionInfo($action, $version) {
    $githubTreeUrl = "https://github.com/$action/tree"

    $response = Invoke-WebRequest -Uri "$githubTreeUrl/$version" -UseBasicParsing -SkipHttpErrorCheck

    if($response.StatusCode -eq 200) {
        return $version
    }

    $response = Invoke-WebRequest -Uri "$githubTreeUrl/v$version" -UseBasicParsing -SkipHttpErrorCheck

    if($response.StatusCode -eq 200) {
        return "v$version"
    }

    return $version
}

function FetchMarketplaceLink($action) {  
    $html = Invoke-WebRequest -Uri "https://github.com/$action" -UseBasicParsing -SkipHttpErrorCheck

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
                is_allowed            = $actionName -match "^${Org}/"
                is_github_or_verified = $false
                marketplace_link      = ""
                github_link           = "https://github.com/$actionName"
            }
        })

    $actions += $repoActions
}

if ($null -eq $actions) {
    Write-Host "No actions found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

$uniqueActions = $actions | Sort-Object -Property "action_name", "action_version" -Unique

$uniqueActions | ForEach-Object {
    $action = $_

    $actionName = $action.action_name

    Write-Verbose "Fixing version info for action '$actionName'..."

    $actionVersion = FixVersionInfo -action $actionName -version $action.action_version

    Write-Verbose "Fetching marketplace link for action '$actionName'..."

    $marketplaceLink = FetchMarketplaceLink -action $actionName

    $isAllowed = $false
    $isGithubOrVerified = $false

    if (IsKnownCreator $actionName) {
        $isAllowed = $true
        $isGithubOrVerified = $true
    }
    elseif ($actionName -notmatch "^${Org}/") {
        if (![string]::IsNullOrEmpty($marketplaceLink)) {
            Write-Host "Checking if action '$actionName@$actionVersion' is verified on marketplace..." -ForegroundColor Yellow 

            if ($(VerifyActionOnMarketplace $marketplaceLink)) {
                $isAllowed = $true
                $isGithubOrVerified = $true
            }
        }
        else {
            Write-Host "Unable to check if action '$actionName@$actionVersion' is verified on marketplace because no marketplace link was found." -ForegroundColor Yellow
        }
    }

    $action.action_version = $actionVersion
    $action.is_allowed = $isAllowed
    $action.is_github_or_verified = $isGithubOrVerified
    $action.marketplace_link = $marketplaceLink
}

Write-Host "Saving actions to '$($OutputFile.FullName)'..." -ForegroundColor Magenta

SaveTo-Csv -Data $uniqueActions -OutputFile $OutputFile -Confirm $Confirm

Write-Host "Done." -ForegroundColor Green