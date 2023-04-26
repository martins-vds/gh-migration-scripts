. $PSScriptRoot\common.ps1

function ExistsRepo ($org, $repo, $token) {
    $reposApi = "https://api.github.com/repos/$org/$repo"

    try {
        $repo = Get -uri $reposApi -token $token

        return $true
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
            throw
        }

        return $false
    }
}

function GetRepos ($org, $token, $path) {
    if($path){
        return GetReposFromFile -path $path
    }
    else {
        return GetReposFromApi -org $org -token $token
    }
}

function GetReposFromApi ($org, $token) {
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

function GetReposFromFile ($path){
    if($null -eq $path){
        return @()
    }

    if (-Not ($path | Test-Path) ) {
        throw "File or folder does not exist"
    }

    if (-Not ($path | Test-Path -PathType Leaf) ) {
        throw "The ReposFile argument must be a file. Folder paths are not allowed."
    }

    if ($path -notmatch "(\.csv$)") {
        throw "The file specified in the ReposFile argument must be of type csv"
    }

    return @(Import-Csv -Path $path)
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

function DeleteRepo($org, $repo, $token){
    try {
        Delete -uri "https://api.github.com/repos/$org/$repo" -token $token | Out-Null             
        Write-Host "Successfully deleted repo '$repo' from org '$org'." -ForegroundColor Green
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) {
            throw
        }

        Write-Host "The repo '$repo' does not exist in org '$org'. No operation will be performed." -ForegroundColor Yellow
    }
}