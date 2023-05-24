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
    [System.IO.FileInfo]
    $SecretsFile,
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

function GetSecretsFromFile($path) {
    if ($null -eq $path) {
        return @()
    }

    if (-Not ($path | Test-Path) ) {
        throw "File or folder does not exist"
    }

    if (-Not ($path | Test-Path -PathType Leaf) ) {
        throw "The SecretsFile argument must be a file. Folder paths are not allowed."
    }

    if ($path -notmatch "(\.csv$)") {
        throw "The file specified in the SecretsFile argument must be of type csv"
    }

    return @(Import-Csv -Path $path)
}

function GetSecretOrDefault($secrets, $repo, $environment, $secretKey, $secretType, $default) {
    $secretValue = $secrets | `
        Where-Object -Property repo -EQ -Value $repo | `
        Where-Object -Property environment -EQ $environment | `
        Where-Object -Property secret_name -EQ $secretKey | `
        Where-Object -Property secret_type -EQ $secretType | `
        Select-Object -First 1

    if ($secretValue) {
        return $secretValue
    }
    else {
        return $default
    }
}

$ErrorActionPreference = 'Stop'

Import-Module PSSodium

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$secrets = GetSecretsFromFile -path $SecretsFile
$defaultSecretValue = "CHANGE_ME"

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

    $sourceRepoSecrets = GetRepoSecrets -org $SourceOrg -repo $sourceRepo.name -token $sourcePat

    if ($sourceRepoSecrets.Length -gt 0) {
        Write-Host "Migrating repository secrets from repo '$SourceOrg/$($sourceRepo.name)' to '$TargetOrg/$($sourceRepo.name)'..." -ForegroundColor White
        
        $targetRepoPubKey = GetRepoPublicyKey -org $TargetOrg -repo $sourceRepo.name -token $targetPat
        
        $sourceRepoSecrets | ForEach-Object {
            $sourceRepoSecret = $_
            $sourceRepoSecretValue = GetSecretOrDefault -secrets $secrets -repo $sourceRepo.name -environment "" -secretKey $sourceRepoSecret.name -secretType 'repo' -default $defaultSecretValue

            if ($sourceRepoSecretValue -eq $defaultSecretValue) {
                Write-Host "   Secret '$($sourceRepoSecret.name)' not found in secrets file. Using default value '$defaultSecretValue'." -ForegroundColor Yellow
            }

            $newTargetRepoSecret = @{            
                encrypted_value = ConvertTo-SodiumEncryptedString -Text $sourceRepoSecretValue -PublicKey $targetRepoPubKey.key
                key_id          = $targetRepoPubKey.key_id
            }
    
            CreateRepoSecret -org $TargetOrg -repo $sourceRepo.name -secretName $sourceRepoSecret.name -secretValue $newTargetRepoSecret -token $targetPat
        }
    }
    else {
        Write-Host "Repo '$SourceOrg/$($sourceRepo.name)' has no repository secrets." -ForegroundColor Yellow
    }

    $sourceRepoEnvironments = GetEnvironments -org $SourceOrg -repo $sourceRepo.name -token $sourcePat

    $sourceRepoEnvironments | ForEach-Object {
        $sourceRepoEnvironment = $_

        $sourceRepoEnvironmentSecrets = GetEnvironmentSecrets -repoId $sourceRepo.id -environmentName $sourceRepoEnvironment.name -token $sourcePat

        if ($sourceRepoEnvironmentSecrets.Length -gt 0) {
            Write-Host "  Migrating environment secrets from environment '$SourceOrg/$($sourceRepo.name)/$($sourceRepoEnvironment.name)' to environment '$TargetOrg/$($sourceRepo.name)/$($sourceRepoEnvironment.name)'..." -ForegroundColor White
            
            $targetRepo = GetRepo -org $TargetOrg -repo $sourceRepo.name -token $targetPat

            Migrate-Environment -org $TargetOrg -repo $sourceRepo.name -environment $sourceRepoEnvironment -token $targetPat

            $targetRepoEnvironmentPublicKey = GetEnvironmentPublicyKey -repoId $targetRepo.id -environmentName $sourceRepoEnvironment.name -token $targetPat

            $sourceRepoEnvironmentSecrets | ForEach-Object {
                $sourceRepoEnvironmentSecret = $_
                $sourceRepoEnvironmentSecretValue = GetSecretOrDefault -secrets $secrets -repo $sourceRepo.name -environment $sourceRepoEnvironment.name -secretKey $sourceRepoEnvironmentSecret.name -secretType 'env' -default $defaultSecretValue

                if ($sourceRepoEnvironmentSecretValue -eq $defaultSecretValue) {
                    Write-Host "   Secret '$($sourceRepoEnvironmentSecret.name)' not found in secrets file. Using default value '$defaultSecretValue'." -ForegroundColor Yellow
                }

                $newTargetRepoEnvironmentSecret = @{
                    encrypted_value = ConvertTo-SodiumEncryptedString -Text $sourceRepoEnvironmentSecretValue -PublicKey $targetRepoEnvironmentPublicKey.key
                    key_id          = $targetRepoEnvironmentPublicKey.key_id
                }

                CreateEnvironmentSecret -repoId $targetRepo.id -environmentName $sourceRepoEnvironment.name -secretName $sourceRepoEnvironmentSecret.name -secretValue $newTargetRepoEnvironmentSecret -token $targetPat
            }
        }
        else {
            Write-Host "  Repo '$SourceOrg/$($sourceRepo.name)' has no environment secrets." -ForegroundColor Yellow
        }
    }
}

Write-Host "Done." -ForegroundColor Cyan
