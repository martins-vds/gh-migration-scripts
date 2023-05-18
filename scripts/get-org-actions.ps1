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

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

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

            return @{
                action_reference = "$($actionName)@$($actionVersion)"
                is_internal = $actionName -match "^${Org}/"
            }
        })

    $actions += $repoActions
}

$actions = $actions | Sort-Object -Unique -Property action_reference

if ($actions) {
    SaveTo-Csv -Data $actions -OutputFile $OutputFile -Confirm $Confirm
    Write-Host "Done." -ForegroundColor Green
}
else {
    Write-Host "No actions found in organization '$Org'." -ForegroundColor Yellow
}