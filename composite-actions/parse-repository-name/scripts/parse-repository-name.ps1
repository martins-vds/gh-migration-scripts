[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^(?<owner>[^/]+)/(?<repo>.+)$")]
    [string]
    $RepositoryName
)

$RepositoryName -match "^(?<owner>[^/]+)/(?<repo>.+)$" | Out-Null
$owner, $repo = $Matches.owner.ToLowerInvariant(), $Matches.repo.ToLowerInvariant()

Write-Output "owner=$owner" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append
Write-Output "repository=$repo" | Out-File -FilePath $Env:GITHUB_OUTPUT -Encoding utf8 -Append