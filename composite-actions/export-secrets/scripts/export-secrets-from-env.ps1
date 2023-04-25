[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]    
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^(?<owner>[^/]+)/(?<repo>.+)$")]
    [string]
    $RepoName,
    [Parameter(Mandatory)]
    [ValidateScript({
        if($_ -notmatch "(\.csv$)"){
            throw "The file specified in the OutputFile argument must have the extension 'csv'"
        }
        return $true 
    })]
    [System.IO.FileInfo]    
    $OutputFile,
    [Parameter(Mandatory = $false)]    
    [ValidateNotNull()]
    [ValidatePattern("(?<ends_with>_$)")]
    [string]
    $SecretsPrefix = "",
    [Parameter(Mandatory = $false)]    
    [ValidateNotNull()]
    [string]
    $EnvironmentName = ""
)

$RepoName -match "^(?<owner>[^/]+)/(?<repo>.+)$" | Out-Null
$org, $repo = $Matches.owner, $Matches.repo

$secrets = @(Get-ChildItem -Path Env:$($SecretsPrefix)* | Sort-Object Name | ForEach-Object {
    if([string]::IsNullOrWhiteSpace($SecretsPrefix)){
        $secret_name = $_.Name
    }else{
        $secret_name = $_.Name.Replace($SecretsPrefix,"")
    }
    $secret_name = $secret_name.Trim('_')

    return [ordered] @{
        org = $org
        repo = $repo
        environment_name = $EnvironmentName.ToLowerInvariant()
        secret_name = $secret_name
        secret_value = $_.Value
    }
})

if($secrets.Length -eq 0){
    Write-Error "No environment variables with prefix '$SecretsPrefix' were found."
    exit 1
}else {
    Write-Host "$($secrets.Length) environment variables with prefix '$SecretsPrefix' were found." -ForegroundColor Green
    $secrets | Export-Csv -Path $OutputFile -Force -UseQuotes AsNeeded -NoTypeInformation -Encoding utf8
}







