[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if (-Not ($_ | Test-Path) ) {
                throw "File or folder does not exist"
            }

            if (-Not ($_ | Test-Path -PathType Leaf) ) {
                throw "The ReposFile argument must be a file. Folder paths are not allowed."
            }

            if ($_ -notmatch "(\.csv$)") {
                throw "The file specified in the ActionsFile argument must be of type csv"
            }

            return $true 
        })]
    [System.IO.FileInfo]
    $ActionsFile
)

$ErrorActionPreference = 'Stop'

$allowed_actions = @(Import-Csv -Path $ActionsFile) `
| Where-Object -Property is_allowed -EQ $true `
| Where-Object -Property is_internal -EQ $false `
| Where-Object -Property is_github_or_verified -EQ $false `
| Select-Object -Property @{ Name = "action_reference"; Expression = { "$($_.action_name)@$($_.action_version)" } } `
| Select-Object -ExpandProperty action_reference

if($allowed_actions.Length -eq 0) {
    Write-Host "No allowed actions found in '$ActionsFile'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Copy the following list of actions to the allow-list in the GitHub enterprise/organization settings:" -ForegroundColor Blue
Write-Host ""
Write-Host $($allowed_actions | Join-String -Separator ",") -ForegroundColor Green