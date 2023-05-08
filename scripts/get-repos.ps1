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

. $PSScriptRoot\common-repos.ps1

function CountIssues ($org, $repo, $token) {
    $page = 0
    $repoIssuesApi="https://api.github.com/orgs/$org/$repo/issues?page={0}&per_page=100"
    $issuesCount = 0

    do 
    {    
        try {
            $page += 1         
            $issues = Get -uri "$($repoIssuesApi -f $page)" -token $token
            $issuesCount += $issues.Length
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
                throw
            }
        }
    } while($issues.Length -gt 0)

    return $issuesCount
}

function CountPullRequests ($org, $repo, $token) {
    $page = 0
    $repoPullRequestsApi="https://api.github.com/orgs/$org/$repo/pulls?page={0}&per_page=100"
    $pullRequestCount = 0

    do 
    {    
        try {
            $page += 1         
            $pullRequests = Get -uri "$($repoPullRequestsApi -f $page)" -token $token
            $pullRequestCount += $pullRequests.Length
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
                throw
            }
        }
    } while($pullRequests.Length -gt 0)

    return $pullRequestCount
}

$token= GetToken -token $Token -envToken $env:GH_PAT

Write-Host "Fetching repos from organization '$Org'..." -ForegroundColor Blue
$repos = GetReposFromApi -org $Org -token $token

if($repos.Length -eq 0){
    Write-Host "No repos found in organization '$Org'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Calculating number of issues and pull requests for all repos..." -ForegroundColor Blue

$reposWithMetrics = $repos | ForEach-Object {
    $repo = $_

    $issuesCount = CountIssues -org $Org -repo $repo.name -token $token
    $pullRequestsCount = CountPullRequests -org $Org -repo $repo.name -token $token

    return [ordered] @{
        id = $repo.id
        org = $Org
        name = $repo.name
        owner_slug = $repo.owner_slug
        owner_type = $repo.owner_type
        issues = $issuesCount
        pull_requests = $pullRequestsCount
    }
}

SaveTo-Csv -Data $reposWithMetrics -OutputFile $OutputFile -Confirm $Confirm

Write-Host "Done." -ForegroundColor Green