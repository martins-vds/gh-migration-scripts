. $PSScriptRoot\common.ps1

function GetUserDetails($username, $token){
    $userApi = "https://api.github.com/users/$username"

    return Get -uri $userApi -token $token
}