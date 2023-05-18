[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $OrgName,
    [Parameter(Mandatory = $false)]
    [string]
    $Token
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common.ps1

$migrationsApi = "https://api.github.com/orgs/$OrgName/migrations?page={0}&per_page=100"
$token = GetToken -token $Token -envToken $env:GH_SOURCE_PAT
$allMigrations = @()
$page = 0

do {    
    $page += 1    
    $migrations = Get -uri "$($migrationsApi -f $page)" -token $token
    $allMigrations += $migrations | Select-Object -Property @{name = "migration_id"; expr = { $_.id } }, state, @{name = "repositories"; expr = { $_.repositories | Select-Object -Property @{name = "repo_id"; expr = { $_.id } }, @{name = "repo_node_id"; expr = { $_.node_id } }, @{name = "repo_full_name"; expr = { $_.full_name } } } } | Select-Object -Property migration_id, state -ExpandProperty repositories
} while ($migrations.Length -gt 0)

if ($allMigrations.Length -eq 0) {
    Write-Host "No migrations found." -ForegroundColor Yellow
}
else {
    $migrationsFile = "migration-history-$(Get-Date -Format "yyyyMMddHHmmss").csv"
    $allMigrations | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $migrationsFile -Encoding utf8
    Write-Host "Migrations file saved to '$migrationsFile'." -ForegroundColor White
}