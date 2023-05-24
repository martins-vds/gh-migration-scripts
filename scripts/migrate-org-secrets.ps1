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

function GetOrgSecrets ($org, $token) {
    $secretsApi = "https://api.github.com/orgs/$org/actions/secrets"
    return @(Get -uri $secretsApi -token $token | Select-Object -Property secrets | Select-Object -ExpandProperty secrets)
}

function CreateOrgSecret ($org, $secret, $token) {
    $secretsApi = "https://api.github.com/orgs/$org/actions/secrets/$($secret.secret_name)"
    return Put -uri $secretsApi -token $token -body $secret | Out-Null
}

function GetPublicyKey ($org, $token) {
    $secretsApi = "https://api.github.com/orgs/$org/actions/secrets/public-key"
    return Get -uri $secretsApi -token $token
}

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

function GetSecretOrDefault($secrets, $org, $secretKey, $default) {
    $secretValue = $secrets | `
        Where-Object -Property owner -EQ -Value $org | `
        Where-Object -Property secret_type -EQ -Value 'org' | `
        Where-Object -Property secret_name -EQ -Value $secretKey | `
        Select-Object -First 1

    if ($secretValue) {
        return $secretValue
    }
    else {        
        return $default
    }
}

Import-Module PSSodium

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$secrets = GetSecretsFromFile -path $SecretsFile
$defaultSecretValue = "CHANGE_ME"

$sourceOrgSecrets = GetOrgSecrets -org $SourceOrg -token $sourcePat

$targetPubKey = GetPublicyKey -org $TargetOrg -token $targetPat

if ($sourceOrgSecrets.Length -gt 0) {
    Write-Host "Migrating organization secrets from org '$SourceOrg' to '$TargetOrg'..." -ForegroundColor White

    $sourceOrgSecrets | ForEach-Object {
        $secret = $_
        $secretValue = GetSecretOrDefault -secrets $secrets -org $SourceOrg -secretKey $secret.name -secretType 'org' -default $defaultSecretValue

        if ($secretValue -eq $defaultSecretValue) {
            Write-Host "Secret '$($secret.name)' not found in secrets file. Using default value '$defaultSecretValue'." -ForegroundColor Yellow
        }

        $newSecret = @{
            org                     = $TargetOrg
            secret_name             = $secret.name
            visibility              = $secret.visibility
            encrypted_value         = ConvertTo-SodiumEncryptedString -Text $secretValue -PublicKey $targetPubKey.key
            key_id                  = $targetPubKey.key_id
            selected_repository_ids = @()
        }
    
        if ($secret.visibility -eq 'selected') {
            $repos = @(Get -uri $secret.selected_repositories_url -token $sourcePat | Select-Object -ExpandProperty repositories | Select-Object -ExpandProperty id)
            $newSecret.selected_repository_ids = $repos
        }
    
        CreateOrgSecret -org $TargetOrg -secret $newSecret -token $targetPat
    }
}
else {
    Write-Host "Organization '$SourceOrg' has no secrets." -ForegroundColor Yellow
}

Write-Host "Done." -ForegroundColor Green