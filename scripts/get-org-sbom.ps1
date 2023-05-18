[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Org,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.IO.FileInfo]    
    $OutputDirectory,
    [Parameter(Mandatory = $false)]
    [string]
    $Token,
    [Parameter(Mandatory = $false)]
    [switch]
    $Confirm
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

$token= GetToken -token $Token -envToken $env:GH_SOURCE_PAT

Write-Host "Fetching repos from organization '$Org'..." -ForegroundColor Blue
$repos = GetReposFromApi -org $Org -token $token

if($repos.Length -eq 0){
    Write-Host "No repos found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

EnsureDirectoryExists $OutputDirectory

$repos | ForEach-Object{
    $repo = $_

    Write-Host "Fetching software bill of materials for repo '$($repo.name)'..." -ForegroundColor White
    $sbom = GetRepoSbom -org $Org -repo $repo.name -token $token

    if($sbom -ne $null){
        Write-Host "No software bill of materials found for repo '$($repo.name)'." -ForegroundColor Yellow
        return
    }

    $repoSbomOutputFile = Join-Path -Path $OutputDirectory -ChildPath "sbom-$($Org.ToLowerInvariant())-$($repo.name).json"

    SaveTo-Json -Data $sbom -OutputFile $repoSbomOutputFile -Confirm:$Confirm
}