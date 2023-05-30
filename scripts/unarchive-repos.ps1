[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $Org,
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if (-Not ($_ | Test-Path) ) {
                throw "File or folder does not exist"
            }

            if (-Not ($_ | Test-Path -PathType Leaf) ) {
                throw "The ReposFile argument must be a file. Folder paths are not allowed."
            }

            if ($_ -notmatch "(\.csv$)") {
                throw "The file specified in the ReposFile argument must be of type csv"
            }

            return $true 
        })]
    [System.IO.FileInfo]
    $ReposFile,
    [Parameter(Mandatory = $true)]
    [string]
    $Token,
    [Parameter(Mandatory = $false)]
    [switch]
    $Confirm
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

function ConfirmUnarchive($org, $repo, $token){
    if($Confirm){
        UnarchiveRepo -org $org -repo $repo -token $token
    }else{
        $unarchive = $Host.UI.PromptForChoice("Unarchive repo '$repo'", 'Are you sure you want to continue?', @('&Yes', '&No'), 1)

        if($unarchive -eq 0){
            UnarchiveRepo -org $org -repo $repo -toke $token
        }else{
            Write-Host "Skipped repo '$repo'." -ForegroundColor Yellow
        }
    }
}

@(Import-Csv -Path $ReposFile) | ForEach-Object { 
    ConfirmUnarchive -org $Org -repo $_.name -token $Token
}

