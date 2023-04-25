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
    $SecretsFile,
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common.ps1

function GetRepos ($org, $token) {
    $page = 0
    $reposApi="https://api.github.com/orgs/$org/repos?page={0}&per_page=100"
    $allRepos = @()

    do 
    {    
        $page += 1         
        $repos = Get -uri "$($reposApi -f $page)" -token $token
        $allRepos += $repos | Select-Object -Property id, name 
    } while($repos.Length -gt 0)

    return $allRepos
}

function GetRepo ($org, $repo, $token){
    $secretsApi="https://api.github.com/repos/$org/$repo"

    return Get -uri $secretsApi -token $token | Select-Object -Property id, name
}

function GetRepoSecrets ($org, $repo, $token){
    $secretsApi="https://api.github.com/repos/$org/$repo/actions/secrets"

    return @(Get -uri $secretsApi -token $token | Select-Object -ExpandProperty secrets)
}

function CreateRepoSecret ($org, $repo, $secretName, $secretValue, $token){
    $secretsApi="https://api.github.com/repos/$org/$repo/actions/secrets/$secretName"
    return Put -uri $secretsApi -token $token -body $secretValue
}

function GetRepoPublicyKey ($org, $repo, $token){
    $secretsApi="https://api.github.com/repos/$org/$repo/actions/secrets/public-key"
    return Get -uri $secretsApi -token $token
}

function GetEnvironments ($org, $repo, $token) {
    $secretsApi="https://api.github.com/repos/$org/$repo/environments"
    return @(Get -uri $secretsApi -token $token | Select-Object -ExpandProperty environments)
}

function GetEnvironmentSecrets($repoId, $environmentName, $token){
    $secretsApi="https://api.github.com/repositories/$repoId/environments/$environmentName/secrets"
    return @(Get -uri $secretsApi -token $token | Select-Object -ExpandProperty secrets)
}

function GetEnvironmentPublicyKey ($repoId, $environmentName, $token){
    $secretsApi="https://api.github.com/repositories/$repoId/environments/$environmentName/secrets/public-key"
    return Get -uri $secretsApi -token $token
}

function CreateEnvironment($org, $repo, $environmentName, $environment, $token){
    $secretsApi="https://api.github.com/repos/$org/$repo/environments/$environmentName"
    return Put -uri $secretsApi -token $token -body $environment
}

function CreateEnvironmentSecret ($repoId, $environmentName, $secretName, $secretValue, $token){
    $secretsApi="https://api.github.com/repositories/$repoId/environments/$environmentName/secrets/$secretName"
    return Put -uri $secretsApi -token $token -body $secretValue
}

function Migrate-Environment ($org, $repo, $environment, $token){
    $newEnvironment = @{
        deployment_branch_policy = $environment.deployment_branch_policy
    }

    $wait_timer = $environment.protection_rules | Where-Object -Property type -EQ wait_timer | Select-Object -ExpandProperty wait_timer
    $reviewers = @($environment.protection_rules | Where-Object -Property type -EQ required_reviewers | Select-Object -ExpandProperty reviewers | Select-Object -Property type,@{Name='id'; Expression= {$_.reviewer.id}})

    if($wait_timer){
        $newEnvironment.wait_timer = $wait_timer
    }

    if($reviewers){
        $newEnvironment.reviewers = $reviewers
    }

    CreateEnvironment -org $TargetOrg -repo $targetRepo.name -environmentName $environment.name -environment $newEnvironment -token $token | Out-Null
}

function GetSecretsFromFile($path){
    if($null -eq $path){
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

function GetSecretOrDefault($secrets, $repo, $environment, $secretKey, $default){
    $secretValue = $secrets | `
                    Where-Object -Property repo -EQ -Value $repo | `
                    Where-Object -Property environment -EQ $environment | `
                    Where-Object -Property secret_name -EQ $secretKey | `
                    Select-Object -First 1

    if($secretValue){
        return $secretValue
    }else{
        return $default
    }
}

$ErrorActionPreference = 'Stop'

Import-Module PSSodium

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$secrets = GetSecretsFromFile -path $SecretsFile

Write-Host "Fetching repositories from org '$SourceOrg'..." -ForegroundColor White
$sourceRepos = GetRepos -org $SourceOrg -token $sourcePat

if($sourceRepos.Length -eq 0){
    Write-Host "No repositories found in organization '$SourceOrg'." -ForegroundColor Yellow
    exit 0
}

$sourceRepos | ForEach-Object {
    $sourceRepo = $_

    $sourceRepoSecrets = GetRepoSecrets -org $SourceOrg -repo $sourceRepo.name -token $sourcePat

    if($sourceRepoSecrets.Length -gt 0){
        Write-Host "Migrating repository secrets from repo '$SourceOrg/$($sourceRepo.name)' to '$TargetOrg/$($sourceRepo.name)'..." -ForegroundColor White
        
        $targetRepoPubKey = GetRepoPublicyKey -org $TargetOrg -repo $sourceRepo.name -token $targetPat
        
        $sourceRepoSecrets | ForEach-Object{
            $sourceRepoSecret = $_
            $sourceRepoSecretValue = GetSecretOrDefault -secrets $secrets -repo $sourceRepo.name -environment "" -secretKey $sourceRepoSecret.name -default "CHANGE_ME"

            $newTargetRepoSecret = @{            
                encrypted_value = ConvertTo-SodiumEncryptedString -Text $sourceRepoSecretValue -PublicKey $targetRepoPubKey.key
                key_id = $targetRepoPubKey.key_id
            }
    
            CreateRepoSecret -org $TargetOrg -repo $sourceRepo.name -secretName $sourceRepoSecret.name -secretValue $newTargetRepoSecret -token $targetPat
        }
    }else{
        Write-Host "Repo '$SourceOrg/$($sourceRepo.name)' has no repository secrets." -ForegroundColor Yellow
    }

    $sourceRepoEnvironments = GetEnvironments -org $SourceOrg -repo $sourceRepo.name -token $sourcePat

    $sourceRepoEnvironments | ForEach-Object {
        $sourceRepoEnvironment = $_

        $sourceRepoEnvironmentSecrets = GetEnvironmentSecrets -repoId $sourceRepo.id -environmentName $sourceRepoEnvironment.name -token $sourcePat

        if($sourceRepoEnvironmentSecrets.Length -gt 0){
            Write-Host "  Migrating environment secrets from environment '$SourceOrg/$($sourceRepo.name)/$($sourceRepoEnvironment.name)' to environment '$TargetOrg/$($sourceRepo.name)/$($sourceRepoEnvironment.name)'..." -ForegroundColor White
            
            $targetRepo = GetRepo -org $TargetOrg -repo $sourceRepo.name -token $targetPat

            Migrate-Environment -org $TargetOrg -repo $sourceRepo.name -environment $sourceRepoEnvironment -token $targetPat

            $targetRepoEnvironmentPublicKey = GetEnvironmentPublicyKey -repoId $targetRepo.id -environmentName $sourceRepoEnvironment.name -token $targetPat

            $sourceRepoEnvironmentSecrets | ForEach-Object {
                $sourceRepoEnvironmentSecret = $_
                $sourceRepoEnvironmentSecretValue = GetSecretOrDefault -secrets $secrets -repo $sourceRepo.name -environment $sourceRepoEnvironment.name -secretKey $sourceRepoEnvironmentSecret.name -default "CHANGE_ME"

                $newTargetRepoEnvironmentSecret = @{
                    encrypted_value = ConvertTo-SodiumEncryptedString -Text $sourceRepoEnvironmentSecretValue -PublicKey $targetRepoEnvironmentPublicKey.key
                    key_id = $targetRepoEnvironmentPublicKey.key_id
                }

                CreateEnvironmentSecret -repoId $targetRepo.id -environmentName $sourceRepoEnvironment.name -secretName $sourceRepoEnvironmentSecret.name -secretValue $newTargetRepoEnvironmentSecret -token $targetPat
            }
        }else{
            Write-Host "  Repo '$SourceOrg/$($sourceRepo.name)' has no environment secrets." -ForegroundColor Yellow
        }
    }
}

Write-Host "Done." -ForegroundColor Cyan
