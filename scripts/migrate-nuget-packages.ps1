[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceUsername,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetUsername,
    [Parameter(Mandatory = $true)]
    [ValidateScript({
            if (-Not ($_ | Test-Path) ) {
                throw "Folder '$_' does not exist. Make sure to create it before running the script."
            }

            if (-Not ($_ | Test-Path -PathType Container) ) {
                throw "The Path '$_' argument must be a directory. File paths are not allowed."
            }
        
            return $true 
        })]
    [System.IO.FileInfo]
    $PackagesPath,
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]    
    [int]
    $MaxVersions = 1,
    [Parameter(Mandatory = $false)]
    [string]
    $SourceToken,
    [Parameter(Mandatory = $false)]
    [string]
    $TargetToken
)

$ErrorActionPreference = 'Stop'

. $PSScriptRoot\common-packages.ps1

function ConfigureNuget ($org, $username, $path, $token) {
    $orgConfig = "$path\$($org.Trim())"

    if (-Not(Test-Path -Path $orgConfig)) {
        New-Item -Path $orgConfig -ItemType Directory | Out-Null
    }
    
    $nugetConfig = "$orgConfig\nuget.config"

    If (Test-Path -Path $nugetConfig) {
        Remove-Item -Path $nugetConfig | Out-Null
    }

    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <packageSources>
        <clear />
        <add key="github" value="https://nuget.pkg.github.com/$org/index.json" />
        <add key="nuget" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    </packageSources>
    <packageSourceCredentials>
        <github>
            <add key="Username" value="$username" />
            <add key="ClearTextPassword" value="$token" />
        </github>
    </packageSourceCredentials>
</configuration>
"@
    
    New-Item -Path $nugetConfig -Value $xml | Out-Null

    return $orgConfig
}

function DownloadNugetPackage($org, $package, $version, $configPath, $packagesPath) {
    Exec { nuget install $package -Version $version -Source github -Source nuget -OutputDirectory $packagesPath -ConfigFile $configPath\nuget.config -NonInteractive } | Out-Null

    Move-Item -Path $packagesPath\$($package).$($version)\$($package).$($version).nupkg -Destination $packagesPath -Force | Out-Null
    Remove-Item -Path $packagesPath\$($package).$($version) -Recurse -Force | Out-Null
}

function UnzipNugetPackage($package, $version, $packagesPath) {
    Expand-Archive -Path $packagesPath\$($package).$($version).nupkg -DestinationPath $packagesPath\$($package).$($version) | Out-Null    
}

function ExtractNugetPackageSpec($package, $version, $packagesPath) {
    [xml] $spec = Get-Content $packagesPath\$($package).$($version)\$($package).nuspec
    return $spec
}

function UpdateNugetPackageRepositoryName($nuspec, $org, $repository) {  
    $nuspec.package.metadata.repository.url = "https://github.com/$org/$repository"

    return $nuspec
}

function UpdateNugetPackageProjectUrl($nuspec, $org, $repository) {  
    if ($nuspec.package.metadata.projectUrl) {
        $nuspec.package.metadata.projectUrl = "https://github.com/$org/$repository.git"
    }

    return $nuspec
}

function RepackNugetPackage($nuspec, $package, $version, $packagesPath) {
    $nuspec.OuterXml | Set-Content -Path $packagesPath\$($package).$($version)\$($package).nuspec -Force | Out-Null
    Exec { nuget pack $packagesPath\$($package).$($version)\$($package).nuspec -OutputDirectory $packagesPath -NonInteractive } | Out-Null    
}

function RepositoryExits($org, $repository, $token) {
    $reposApi = "https://api.github.com/repos/$org/$repository"

    try {
        Get -uri $reposApi -token $token | Out-Null

        return $true;
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            return $false;
        }
    }
}

function ExtractNugetPackageRepositoryName($nuspec) {
    return  $nuspec.package.metadata.repository.url -replace 'https://github.com/[^/]+/(?<repoName>.*(?=\.git)|.*)', '${repoName}' -replace '.git', ''
}

function PushNugetPackage($org, $package, $version, $configPath, $packagesPath) {
    Exec { nuget push $packagesPath\$($package).$($version).nupkg -Source github -ConfigFile $configPath\nuget.config -NonInteractive -SkipDuplicate } | Out-Null
    Remove-Item -Path $packagesPath\$($package).$($version).nupkg -Force | Out-Null
}

function DeleteNugetPackage($package, $version, $packagesPath) {
    Remove-Item -Path $packagesPath\$($package).$($version) -Recurse -Force | Out-Null
}

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$sourceNugetPackages = GetPackages -org $SourceOrg -type "nuget" -token $sourcePat

if ($sourceNugetPackages.Length -eq 0) {
    Write-Host "No nuget packages found in organization '$SourceOrg'." -ForegroundColor Yellow
    exit 0
}

$sourceNugetConfig = ConfigureNuget -org $SourceOrg -username $SourceUsername -path $PackagesPath.FullName -token $sourcePat
$targetNugetConfig = ConfigureNuget -org $TargetOrg -username $TargetUsername -path $PackagesPath.FullName -token $targetPat

$sourceNugetPackages | ForEach-Object {
    $sourceNugetPackage = $_
    $sourceNugetPackageVersions = GetPackageVersions -org $SourceOrg -type "nuget" -package $sourceNugetPackage.name -max $MaxVersions -token $sourcePat

    $sourceNugetPackageVersions | ForEach-Object {
        $sourceNugetPackageVersion = $_
        
        Write-Host "Migrating package '$($sourceNugetPackage.name).$($sourceNugetPackageVersion.name)'..." -ForegroundColor Cyan

        DownloadNugetPackage -org $SourceOrg -package $sourceNugetPackage.name -version $sourceNugetPackageVersion.name -configPath $sourceNugetConfig -packagesPath $PackagesPath.FullName
        
        UnzipNugetPackage -package $sourceNugetPackage.name -version $sourceNugetPackageVersion.name -packagesPath $PackagesPath.FullName

        $spec = ExtractNugetPackageSpec -package $sourceNugetPackage.name -version $sourceNugetPackageVersion.name -packagesPath $PackagesPath.FullName

        $sourceNugetPackageRepository = ExtractNugetPackageRepositoryName -nuspec $spec

        if (RepositoryExits -org $TargetOrg -repository $sourceNugetPackageRepository -token $targetPat) {
            $spec = UpdateNugetPackageRepositoryName -nuspec $spec -org $TargetOrg -repository $sourceNugetPackageRepository
            $spec = UpdateNugetPackageProjectUrl -nuspec $spec -org $TargetOrg -repository $sourceNugetPackageRepository

            RepackNugetPackage -nuspec $spec -package $sourceNugetPackage.name -version $sourceNugetPackageVersion.name -packagesPath $PackagesPath.FullName

            PushNugetPackage  -org $TargetOrg -package $sourceNugetPackage.name -version $sourceNugetPackageVersion.name -configPath $targetNugetConfig -packagesPath $PackagesPath.FullName
        }
        else {
            Write-Host "Failed to migrate package '$($sourceNugetPackage.name).$($sourceNugetPackageVersion.name)'. Repo '$sourceNugetPackageRepository' does not exist in org '$TargetOrg'." -ForegroundColor Red
        }

        DeleteNugetPackage -package $sourceNugetPackage.name -version $sourceNugetPackageVersion.name -packagesPath $PackagesPath.FullName 
    }
}

CleanupConfig -org $SourceOrg -path $PackagesPath
CleanupConfig -org $TargetOrg -path $PackagesPath

Write-Host "Done." -ForegroundColor Green