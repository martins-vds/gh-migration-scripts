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
    [ValidateRange(1, [int]::MaxValue) ]
    [int]
    $Parallel = 1,
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-repos.ps1

function ExecAndGetMigrationID {
    param (
        [scriptblock]$ScriptBlock
    )
    $MigrationID = Exec $ScriptBlock | ForEach-Object {        
        $_
    } | Select-String -Pattern "\(ID: (.+)\)" | ForEach-Object { $_.matches.groups[1].Value }
    return $MigrationID
}

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$repos = @(Import-Csv -Path $ReposFile | Sort-Object -Property pull_requests, issues)

$parallelMigrations = 1

if ($Parallel -le $repos.Length) {    
    $parallelMigrations = $Parallel
}else{
    $parallelMigrations = [System.Environment]::ProcessorCount
}

$batches = [int]($repos.Length / $parallelMigrations)
$oddBatches = $repos.Length % $parallelMigrations -gt 0

if($oddBatches){
    $batches++
}

Write-Verbose "Batches: $batches"
Write-Verbose "Odd batches: $oddBatches"

$succeeded = 0
$failed = 0
$unknown = 0
$repoMigrations = [ordered]@{}

$skip = 0
$take = $parallelMigrations

$executionDuration = Measure-Command {
    for ($i = 0; $i -lt $batches; $i++) {
        $skip = $i * $take;
        if ($i + 1 -eq $batches -and $oddBatches) {
            $take = $repos.Length % $parallelMigrations
        }
    
        Write-Verbose "Batch $($i): skip $skip, take $take"

        $reposToMigrate = $repos | Select-Object -Skip $skip -First $take
        
        $reposToMigrate | ForEach-Object {
            $repoName = $_.name
            $repoVisibility = $_.visibility

            if (-Not(ExistsRepo -org $TargetOrg -repo $repoName -token $targetPat)) {
                Write-Host "Queueing migration for repo '$repoName'..." -ForegroundColor Cyan

                $migrationID = ExecAndGetMigrationID { gh gei migrate-repo --queue-only --github-source-org $SourceOrg --source-repo $repoName --github-target-org $TargetOrg --target-repo $repoName --target-repo-visibility $repoVisibility --github-source-pat $sourcePat --github-target-pat $targetPat }
    
                if ($lastexitcode -eq 0) { 
                    $RepoMigrations[$repoName] = @{
                        MigrationId = $migrationID
                        Repository  = $repoName
                        State       = "Queued"
                    }
                }
                else {
                    $RepoMigrations[$repoName] = @{
                        MigrationId = ""
                        Repository  = $repoName
                        State       = "Failed"
                    }
                    Write-Host "Failed to queue migration for repo '$repoName'." -ForegroundColor Red
                }       
            }
            else {
                $RepoMigrations[$repoName] = @{
                    MigrationId = ""
                    Repository  = $repoName
                    State       = "Skipped"
                }
                Write-Host "The organization '$TargetOrg' already contains a repository with the name '$($repoName)'. No operation will be performed" -ForegroundColor Yellow
            }
        }

        $reposToMigrate | Foreach-Object -Parallel {
            . $using:PSScriptRoot\common-gh.ps1
            
            $repoName = $_.name

            $sourcePat = $using:sourcePat
            $targetPat = $using:targetPat
            $repoMigrations = $using:RepoMigrations            
            $repoMigrationId = $repoMigrations[$repoName].MigrationId
            $repoMigrationState = $repoMigrations[$repoName].State

            if ($repoMigrationState -eq "Queued" -and ![string]::IsNullOrWhiteSpace($repoMigrationId)) {
                Write-Host "Waiting migration for repo '$repoName' to finish..." -ForegroundColor White               

                try {                    
                    $waitOutput = ExecProcess -filePath gh -argumentList @("gei", "wait-for-migration", "--migration-id", "$repoMigrationId", "--github-target-pat", "$targetPat") -workingDirectory $using:PSScriptRoot

                    if ($waitOutput.exitCode -eq 0) {
                        Write-Host "Successfully migrated repo '$repoName'." -ForegroundColor Green

                        $repoMigrations[$repoName].State = "Succeeded"
                        $succeeded++
                    }
                    else {
                        Write-Host "Failed to wait for migration of repo '$repoName'. Reason: $(waitOutput.exitMessage)" -ForegroundColor Red
                
                        $repoMigrations[$repoName].State = "Failed"
                        $failed++ 
                
                        try {
                            $dowloadLogsOutput = ExecProcess -filePath gh -argumentList @("gei", "download-logs", "--github-target-org", "$TargetOrg", "--target-repo", "$repoName", "--github-target-pat", "$targetPat", "--migration-log-file", "migration-log-$TargetOrg-$repoName-$(Get-Date -Format "yyyyMMddHHmmss").log") -workingDirectory $using:PSScriptRoot

                            if($dowloadLogsOutput.exitCode -ne 0){
                                Write-Host "Failed to download migration logs for repo '$repoName'. Reason: $($dowloadLogsOutput.errors)" -ForegroundColor Red
                            }
                        }
                        catch {
                            Write-Host "Failed to download migration logs for repo '$repoName'. Reason: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                }
                catch {
                    $repoMigrations[$repoName].State = "Unknown"
                    $unknown++

                    Write-Host "Failed to wait for migration of repo '$repoName' to finish. Reason: $($_.Exception.Message)" -ForegroundColor Red
                }     
            }
        } 
    }
}

Write-Host "The migration of $($repos.Length) repos took $("{0:dd}d:{0:hh}h:{0:mm}m:{0:ss}s" -f $executionDuration)" -ForegroundColor White

$logFile = "migration-$(Get-Date -Format "yyyyMMddHHmmss").csv"
$repoMigrations.GetEnumerator() | Select-Object Value | ForEach-Object { $_.Value } | ConvertTo-Csv -NoTypeInformation | Out-File -Path $logFile -Force -Encoding utf8

Write-Host "Migrations log files saved to '$logFile'." -ForegroundColor White