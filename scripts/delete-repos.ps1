[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Org,
    [ValidateScript({
        if(-Not ($_ | Test-Path) ){
            throw "File or folder does not exist"
        }

        if(-Not ($_ | Test-Path -PathType Leaf) ){
            throw "The ReposFile argument must be a file. Folder paths are not allowed."
        }

        if($_ -notmatch "(\.csv$)"){
            throw "The file specified in the ReposFile argument must be of type csv"
        }

        return $true 
    })]
    [System.IO.FileInfo]
    $ReposFile,
    [Parameter(Mandatory = $false)]
    [string]
    $Token,
    [Parameter(Mandatory = $false)]
    [switch]
    $Confirm
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

function ConfirmDelete($org, $repo, $token){
    if($Confirm){
        DeleteRepo -org $org -repo $repo -token $token
    }else{
        $delete = $Host.UI.PromptForChoice("Delete repo '$repo'", 'Are you sure you want to continue?', @('&Yes', '&No'), 1)

        if($delete -eq 0){
            DeleteRepo -org $org -repo $repo -toke $token
        }else{
            Write-Host "Skipped repo '$repo'." -ForegroundColor Yellow
        }
    }
}

$token = GetToken -token $Token -envToken $env:GH_PAT

@(Import-Csv -Path $ReposFile) | ForEach-Object { 
    ConfirmDelete -org $Org -repo $_.name -token $token
}