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

. $PSScriptRoot\common-teams.ps1

$token = GetToken -token $Token -envToken $env:GH_SOURCE_PAT

Write-Host "Fetching teams from organization '$Org'..." -ForegroundColor Blue
$teams = GetTeams -org $Org -token $token

if ($teams.Length -eq 0) {
    Write-Host "No teams found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

$teamRepos = $teams | ForEach-Object {
    $team = $_

    Write-Host "Fetching repositories of team '$($team.name)'..." -ForegroundColor Blue
    $repos = GetTeamRepos -org $Org -team $team.slug -token $token

    $repos | ForEach-Object {
        $repo = $_

        return [ordered]@{
            team_slug = $team.slug
            team_repo = $repo.name
        }
    }
}

SaveTo-Csv -Data $teamRepos -OutputFile $OutputFile -Confirm $Confirm

Write-Host "Done." -ForegroundColor Green