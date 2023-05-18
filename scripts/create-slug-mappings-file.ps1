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

. $PSScriptRoot\common-users.ps1
. $PSScriptRoot\common-orgs.ps1

$token = GetToken -token $Token -envToken $env:GH_SOURCE_PAT

Write-Host "Fetching members from organization '$Org'..." -ForegroundColor Blue
$members = GetOrgMembers -org $Org -token $token

if ($members.Length -eq 0) {
    Write-Host "No members found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

$slugMappings = @($members | ForEach-Object {
        $member = $_

        return [ordered]@{
            slug_source_org = $member.login
            slug_target_org = ""
        }
    }) | ForEach-Object {
    $teamMemberDetails = GetUserDetails -username $_.slug_source_org -token $token

    if ($teamMemberDetails.email -ne $null) {
        $new_slug = "$($teamMemberDetails.email.Split("@")[0].Replace(".", "-"))_emu"

        $_.slug_target_org = $new_slug        
    }
    else {
        Write-Host "No publicaly visible email found for user '$($_.slug_source_org)'. Skipping..." -ForegroundColor Yellow
    }

    return $_
} | Sort-Object -Property slug_source_org

SaveTo-Csv -Data $slugMappings -OutputFile $OutputFile -Confirm $Confirm

Write-Host "Done." -ForegroundColor Green