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
    $SlugMappingsFile,
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1
. $PSScriptRoot\common-teams.ps1

function GetSlugMappings ($path) {
    if ($null -eq $path) {
        return @()
    }
    
    if (-Not ($path | Test-Path) ) {
        throw "File or folder does not exist"
    }

    if (-Not ($path | Test-Path -PathType Leaf) ) {
        throw "The SlugMappingsFile argument must be a file. Folder paths are not allowed."
    }

    if ($path -notmatch "(\.csv$)") {
        throw "The file specified in the SlugMappingsFile argument must be of type csv"
    }

    return @(Import-Csv -Path $path)
}

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$slugMappings = GetSlugMappings -path $SlugMappingsFile

Write-Host "Fetching teams from organization '$SourceOrg'..." -ForegroundColor Blue
$sourceTeams = GetTeams -org $SourceOrg -token $sourcePat

if ($sourceTeams.Length -eq 0) {
    Write-Host "No teams found in organization '$SourceOrg'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Creating teams in the organization '$TargetOrg'..." -ForegroundColor Blue

$newTeams = @()

$sourceTeams | ForEach-Object {
    $sourceTeam = $_
    $targetTeam = $sourceTeam | Select-Object -Property @{name = "name"; expr = { $_.slug } }, description, privacy, permission

    $newTeam = CreateOrFetchTeam -org $TargetOrg -team $targetTeam -token $targetPat | Select-Object -Property id, name, slug

    $newTeams += $newTeam
}

Write-Host "Creating teams hierarchy in the organization '$TargetOrg'..." -ForegroundColor Blue

$sourceTeams | ForEach-Object {
    $sourceTeam = $_    

    if (-Not ($sourceTeam.parent -eq $null)) {
        $targetTeam = $newTeams | Where-Object -Property slug -EQ -Value $sourceTeam.slug
        $targetParentTeam = $newTeams | Where-Object -Property slug -EQ -Value $sourceTeam.parent.slug

        AddTeamToParent -org $TargetOrg -team $targetTeam.slug -parent $targetParentTeam.id -token $targetPat
    }
}

Write-Host "Adding team members in the organization '$TargetOrg'..." -ForegroundColor Blue

$sourceTeams | ForEach-Object {
    $sourceTeam = $_    
    $sourceTeamMembers = GetTeamMembers -org $SourceOrg -team $sourceTeam.slug -token $sourcePat

    $targetTeam = $newTeams | Where-Object -Property slug -EQ -Value $sourceTeam.slug

    $sourceTeamMembers | ForEach-Object {
        $sourceTeamMember = $_
        $sourceTeamMemberRole = GetTeamMemberRole -org $SourceOrg -team $sourceTeam.slug -teamMember $sourceTeamMember.login -token $sourcePat
        
        $targetTeamMemberSlug = $slugMappings | Where-Object -Property slug_source_org -EQ -Value $sourceTeamMember.login | Select-Object -First 1 -ExpandProperty slug_target_org

        if ([string]::IsNullOrWhiteSpace($targetTeamMemberSlug)) {
            $targetTeamMemberSlug = $sourceTeamMember.login
        }

        UpdateTeamMemberRole -org $TargetOrg -team $targetTeam.slug -teamMember $targetTeamMemberSlug -role $sourceTeamMemberRole -token $targetPat
    }
}

Write-Host "Adding team repositories in the organization '$TargetOrg'..." -ForegroundColor Blue

$defaultPermissions = @("pull", "triage", "push", "maintain", "admin")

$sourceTeams | ForEach-Object {
    $sourceTeam = $_    
    $sourceTeamRepos = GetTeamRepos -org $SourceOrg -team $sourceTeam.slug -token $sourcePat

    $targetTeam = $newTeams | Where-Object -Property slug -EQ -Value $sourceTeam.slug

    $sourceTeamRepos | ForEach-Object {
        $sourceTeamRepo = $_
        
        if (ExistsRepo -org $TargetOrg -repo $sourceTeamRepo.name -token $targetPat) {
            $permissions = $defaultPermissions | ForEach-Object { if ($sourceTeamRepo.permissions.$_) { return $_ } }
            $permissions | ForEach-Object { UpdateTeamRepoPermission -org $TargetOrg -team $targetTeam.slug -repo "$TargetOrg/$($sourceTeamRepo.name)" -permission $_ -token $targetPat }
        }
        else {
            Write-Host "The team '$($targetTeam.name)' cannot be added to repo '$($sourceTeamRepo.name)' in org '$TargetOrg'. This repo does not exist." -ForegroundColor Yellow
        }
    }
}

Write-Host "Done." -ForegroundColor Green