[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Org,
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if($_ -notmatch "(\.csv$)"){
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

. $PSScriptRoot\common-orgs.ps1

$token= GetToken -token $Token -envToken $env:GH_PAT

Write-Host "Fetching members from organization '$Org'..." -ForegroundColor Blue
$members = GetOrgMembers -org $Org -token $token

if($members.Length -eq 0){
    Write-Host "No members found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

$members | ForEach-Object {
    $member = $_

    $membership = GetOrgUserMembership -org $Org -member $member.login -token $token

    return [ordered]@{
        org_member_slug = $member.login
        org_member_role = $membership.role
        org_member_state = $membership.state    
    }
} | SaveTo-Csv -OutputFile $OutputFile -Confirm $Confirm

Write-Host "Done." -ForegroundColor Green