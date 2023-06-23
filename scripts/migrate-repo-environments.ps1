[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetOrg,
    [Parameter(Mandatory = $false)]
    [System.IO.FileInfo]
    $ReposFile,
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1
. $PSScriptRoot\common-environments.ps1

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

Write-Host "Fetching repositories from org '$SourceOrg'..." -ForegroundColor White
$sourceRepos = GetRepos -org $SourceOrg -token $sourcePat -path $ReposFile

if ($sourceRepos.Length -eq 0) {
    Write-Host "No repositories found in organization '$SourceOrg'." -ForegroundColor Yellow
    exit 0
}

$sourceRepos | ForEach-Object {
    $sourceRepo = $_

    if (-Not(ExistsRepo -org $TargetOrg -repo $sourceRepo.name -token $targetPat)) {
        Write-Host "The repository '$($sourceRepo.name)' does not exist in org '$TargetOrg'. Skipping..." -ForegroundColor Yellow
        return
    }

    $targetRepo = GetRepo -org $TargetOrg -repo $sourceRepo.name -token $targetPat

    $sourceRepoEnvironments = GetEnvironments -org $SourceOrg -repo $sourceRepo.name -token $sourcePat

    if ($sourceRepoEnvironments.Length -gt 0) {
        $sourceRepoEnvironments | ForEach-Object {
            $sourceRepoEnvironment = $_
    
            MigrateEnvironment -org $TargetOrg -repo $sourceRepo.name -environment $sourceRepoEnvironment -token $targetPat

            $sourceRepoEnvironmentVariables = GetEnvironmentVariables -repoId $sourceRepo.id -environmentName $sourceRepoEnvironment.name -token $sourcePat
    
            if ($sourceRepoEnvironmentVariables.Length -gt 0) {
                $sourceRepoEnvironmentVariables | ForEach-Object {
                    $sourceRepoEnvironmentVariable = $_
        
                    Write-Host "Creating environment variable '$($sourceRepoEnvironmentVariable.name)' in environment '$($sourceRepoEnvironment.name)' in repo '$SourceOrg/$($sourceRepo.name)'..." -ForegroundColor White
                    CreateEnvironmentVariable -repoId $targetRepo.id -environmentName $sourceRepoEnvironment.name -variableName $sourceRepoEnvironmentVariable.name -variableValue $sourceRepoEnvironmentVariable.value -token $targetPat
                }
            }
            else {
                Write-Host "No environment variables found in environment '$($sourceRepoEnvironment.name)' in the repo '$SourceOrg/$($sourceRepo.name)'." -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "No environments found in repository '$($sourceRepo.name)' in org '$SourceOrg'." -ForegroundColor Yellow
    }
}