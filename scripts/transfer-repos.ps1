[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetOrg,
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
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$reposToTransfer = @(Import-Csv -Path $ReposFile | Sort-Object -Property pull_requests, issues)

$executionDuration = Measure-Command {
    $reposToTransfer | ForEach-Object {
        $repoName = $_.name

        try {
            if (-Not(ExistsRepo -org $TargetOrg -repo $repoName -token $targetPat)) {
                Write-Host "Queueing transfer for repo '$repoName'..." -ForegroundColor Cyan
    
                TransferRepo -org $SourceOrg -repo $repoName -newOrg $TargetOrg -token $sourcePat
            }
            else {
                
                Write-Host "The organization '$TargetOrg' already contains a repository with the name '$($repoName)'. No operation will be performed" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "An error occurred while transferring the repository '$repoName': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "The transfer of $($reposToTransfer.Length) repo(s) took $("{0:dd}d:{0:hh}h:{0:mm}m:{0:ss}s" -f $executionDuration)" -ForegroundColor White