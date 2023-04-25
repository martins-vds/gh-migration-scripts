[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetOrg,
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common.ps1

function GetOrgSecrets ($org, $token){
    $secretsApi="https://api.github.com/orgs/$org/actions/secrets"
    return @(Get -uri $secretsApi -token $token | Select-Object -Property secrets | Select-Object -ExpandProperty secrets)
}

function CreateOrgSecret ($org, $secret, $token){
    $secretsApi="https://api.github.com/orgs/$org/actions/secrets/$($secret.secret_name)"
    return Put -uri $secretsApi -token $token -body $secret | Out-Null
}

function GetPublicyKey ($org, $token){
    $secretsApi="https://api.github.com/orgs/$org/actions/secrets/public-key"
    return Get -uri $secretsApi -token $token
}

Import-Module PSSodium

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$sourceOrgSecrets = GetOrgSecrets -org $SourceOrg -token $sourcePat

$targetPubKey = GetPublicyKey -org $TargetOrg -token $targetPat

if($sourceOrgSecrets.Length -gt 0){
    Write-Host "Migrating organization secrets from org '$SourceOrg' to '$TargetOrg'..." -ForegroundColor White

    $sourceOrgSecrets | ForEach-Object {
        $secret = $_
    
        $newSecret = @{
            org = $TargetOrg
            secret_name = $secret.name
            visibility = $secret.visibility
            encrypted_value = ConvertTo-SodiumEncryptedString -Text "CHANGE_ME" -PublicKey $targetPubKey.key
            key_id = $targetPubKey.key_id
            selected_repository_ids = @()
        }
    
        if($secret.visibility -eq 'selected'){
            $repos = @(Get -uri $secret.selected_repositories_url -token $sourcePat | Select-Object -ExpandProperty repositories | Select-Object -ExpandProperty id)
            $newSecret.selected_repository_ids = $repos
        }
    
        CreateOrgSecret -org $TargetOrg -secret $newSecret -token $targetPat
    }
}else{
    Write-Host "Organization '$SourceOrg' has no secrets." -ForegroundColor Yellow
}

Write-Host "Done." -ForegroundColor Green