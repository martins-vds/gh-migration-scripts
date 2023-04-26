. $PSScriptRoot\common.ps1

function GetTeams ($org, $token) {
    $teamsApi = "https://api.github.com/orgs/$org/teams?page={0}&per_page=100"
    $allTeams = @()
    $page = 0

    do {    
        $page += 1  
        $teams = Get -uri "$($teamsApi -f $page)" -token $token
        $allTeams += $teams
    } while ($teams.Length -gt 0)

    return $allTeams
}

function CreateOrFetchTeam ($org, $team, $token) {
    $teamsApi = "https://api.github.com/orgs/$org/teams"

    try {
        return Post -uri $teamsApi -body $team -token $token
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::UnprocessableEntity -and $_.ErrorDetails.Message -like "*name must be unique for this org*") {
            return Get -uri "$teamsApi/$($team.name)" -token $token
        }
    }
}

function AddTeamToParent ($org, $team, $parent, $token) {
    $teamsApi = "https://api.github.com/orgs/$org/teams/$team"

    $body = @{
        parent_team_id = $parent
    }

    Patch -uri $teamsApi -body $body -token $token | Out-Null
}

function GetTeamMembers ($org, $team, $token){
    $teamsApi = "https://api.github.com/orgs/$org/teams/$team/members?page={0}&per_page=100"
    $allMembers = @()
    $page = 0

    do {    
        $page += 1  
        $members = Get -uri "$($teamsApi -f $page)" -token $token
        $allMembers += $members | Select-Object -Property login
    } while ($members.Length -gt 0)

    return $allMembers
}

function GetTeamMemberRole ($org, $team, $teamMember, $token){
    $teamsApi = "https://api.github.com/orgs/$org/teams/$team/memberships/$teamMember"
    
    return Get -uri $teamsApi -token $token | Select-Object -Property role
}

function UpdateTeamMemberRole($org, $team, $teamMember, $role, $token){
    $teamsApi = "https://api.github.com/orgs/$org/teams/$team/memberships/$teamMember"

    Put -uri $teamsApi -body $role -token $token | Out-Null
}

function GetTeamRepos ($org, $team, $token){
    $teamsApi = "https://api.github.com/orgs/$org/teams/$team/repos?page={0}&per_page=100"
    $allRepos = @()
    $page = 0

    do {    
        $page += 1  
        $repos = Get -uri "$($teamsApi -f $page)" -token $token
        $allRepos += $repos | Select-Object -Property name, permissions
    } while ($repos.Length -gt 0)

    return $allRepos
}

function UpdateTeamRepoPermission($org, $team, $repo, $permission, $token){
    $teamsApi = "https://api.github.com/orgs/$org/teams/$team/repos/$repo"

    try {
        Put -uri $teamsApi -body @{ permission = $permission } -token $token | Out-Null
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            Write-Host "       Failed to update team repository permission '$($permission)' for team '$org/$team'. Repo '$repo' doesn't exist."
        }
    }
}