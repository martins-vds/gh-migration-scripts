. $PSScriptRoot\common.ps1

function GetOrgMembers ($org, $token) {
    $orgsApi = "https://api.github.com/orgs/$org/members?page={0}&per_page=100"
    $allMembers = @()
    $page = 0

    do {
        Write-Verbose "Fetching page $page of members from organization '$org'..."
        $page += 1  
        $members = Get -uri "$($orgsApi -f $page)" -token $token
        $allMembers += $members
    } while ($members.Length -gt 0)

    return $allMembers
}

function GetOrgUserMembership ($org, $member, $token) {
    $orgsApi = "https://api.github.com/orgs/$org/memberships/$member"

    try {
        $membership = Get -uri $orgsApi -token $token

        return $membership | Select-Object -Property state, role
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
            throw
        }

        return @{state = ""; role = "" }
    }
}