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
    [ValidateRange(1,10)]    
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

function ConfigureNpm ($org, $path, $token){
    $orgConfig = "$path\$($org.Trim())"

    if(-Not(Test-Path -Path $orgConfig)){
        New-Item -Path $orgConfig -ItemType Directory | Out-Null
    }
    
    $npmrc = "$orgConfig\.npmrc"

    If(Test-Path -Path $npmrc){
        Remove-Item -Path $npmrc | Out-Null    
    }

    New-Item -Path $npmrc | Out-Null
    Add-Content -Path $npmrc -Value "@$($org):registry=https://npm.pkg.github.com"
    Add-Content -Path $npmrc -Value "//npm.pkg.github.com/:_authToken=$token"

    return $orgConfig
}

function DownloadNpmPackage($org, $package, $version, $configPath, $packagesPath){
    #Start-Process npm -ArgumentList "pack @$($org)/$package@$($version) --pack-destination=$packagesPath --silent --registry=https://npm.pkg.github.com" -WorkingDirectory $configPath -Wait -NoNewWindow | Out-Null
    ExecProcess -filePath npm -argumentList "pack @$($org)/$package@$($version) --pack-destination=$packagesPath --silent --registry=https://npm.pkg.github.com" -workingDirectory $configPath
    Move-Item -Path "$packagesPath\$org-$package-$version.tgz" -Destination "$packagesPath\$package-$version.tgz" -Force | Out-Null
}

function UnzipNpmPackage($package, $version, $outputPath){
    if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
        Install-Package -Scope CurrentUser -Force 7Zip4PowerShell -PackageManagementProvider PowerShellGet > $null
    }

    if(Test-Path -Path "$outputPath\$package-$version"){
        Remove-Item -Path "$outputPath\$package-$version" -Recurse -Force | Out-Null
    }

    Expand-7Zip "$outputPath\$package-$version.tgz" "$outputPath\$package-$version" | Out-Null
    Expand-7Zip "$outputPath\$package-$version\$package-$version.tar" "$outputPath\$package-$version" | Out-Null

    Remove-Item -Path "$outputPath\$package-$version.tgz" -Force | Out-Null
    Remove-Item -Path "$outputPath\$package-$version\$package-$version.tar" -Force | Out-Null

    Move-Item -Path "$outputPath\$package-$version\package\*" "$outputPath\$package-$version" | Out-Null
    Remove-Item -Path "$outputPath\$package-$version\package" -Force | Out-Null
}

function InstallNpmPackageCommonDependencies($package, $version, $packagesPath){
    #Start-Process npm -ArgumentList "install @types/node --save-dev --silent" -WorkingDirectory "$packagesPath\$package-$version" -Wait -NoNewWindow | Out-Null
    ExecProcess -filePath npm -argumentList "install @types/node --save-dev --silent" -workingDirectory "$packagesPath\$package-$version"
}

function LoadNpmPackageMetadata($package, $version, $packagesPath){
    $packageConfig = Get-Content -Path "$packagesPath\$package-$version\package.json" -Raw | ConvertFrom-Json

    if($packageConfig.PSobject.Properties.name -notcontains 'name'){
        $packageConfig | Add-Member -MemberType NoteProperty -Name 'name' -Value ''
    }

    if($packageConfig.PSobject.Properties.name -notcontains 'repository'){
        $packageConfig | Add-Member -MemberType NoteProperty -Name 'repository' -Value ''
    }

    return $packageConfig
}

function PublishNpmPackage($org, $package, $version, $configPath, $packagesPath){
    UnzipNpmPackage -package $package -version $version -outputPath $packagesPath

    $packageConfig = LoadNpmPackageMetadata -package $package -version $version -packagesPath $packagesPath
    $packageConfig.name = "@$($org)/$package"
    $packageConfig.repository = "$($org)/$package"

    $packageConfig | ConvertTo-Json -Depth 10 | Set-Content -Path "$packagesPath\$package-$version\package.json" | Out-Null
    
    InstallNpmPackageCommonDependencies -package $package -version $version -packagesPath $packagesPath

    ExecProcess -filePath npm -argumentList "publish $packagesPath\$package-$version --registry=https://npm.pkg.github.com" -workingDirectory $configPath     
}

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$sourceNpmPackages = GetPackages -org $SourceOrg -type "npm" -token $sourcePat

if($sourceNpmPackages.Length -eq 0){
    Write-Host "No npm packages found in organization '$SourceOrg'." -ForegroundColor Yellow
    exit 0
}

$sourceNpmConfig = ConfigureNpm -org $SourceOrg -path $PackagesPath.FullName -token $sourcePat
$targetNpmConfig = ConfigureNpm -org $TargetOrg -path $PackagesPath.FullName -token $targetPat

$sourceNpmPackages | ForEach-Object {
    $sourceNpmPackage = $_
    $sourceNpmPackageVersions = GetPackageVersions -org $SourceOrg -type "npm" -package $sourceNpmPackage.name -max $MaxVersions -token $sourcePat

    $targetNpmPackageVersions = GetPackageVersions -org $TargetOrg -type "npm" -package $sourceNpmPackage.name -max $MaxVersions -token $targetPat

    $sourceNpmPackageVersions | ForEach-Object {
        $sourceNpmPackageVersion = $_
        
        $targetNpmPackage = $targetNpmPackageVersions | Where-Object -Property name -EQ $sourceNpmPackageVersion.name

        if($targetNpmPackage){
            Write-Host "Skipping container image '$($sourceNpmPackage.name).$($sourceNpmPackageVersion.name)'. It already exists in organization '$TargetOrg'." -ForegroundColor Yellow
            continue
        }else{
            Write-Host "Migrating npm package '$($sourceNpmPackage.name).$($sourceNpmPackageVersion.name)' to organization '$TargetOrg'..." -ForegroundColor Blue
        }

        try {
            DownloadNpmPackage -org $SourceOrg -package $sourceNpmPackage.name -version $sourceNpmPackageVersion.name -configPath $sourceNpmConfig -packagesPath $PackagesPath.FullName
            PublishNpmPackage  -org $TargetOrg -package $sourceNpmPackage.name -version $sourceNpmPackageVersion.name -configPath $targetNpmConfig -packagesPath $PackagesPath.FullName
        }
        catch {
            Write-Host "Failed to migrate npm package '$($sourceNpmPackage.name).$($sourceNpmPackageVersion.name)' to organization '$TargetOrg'. Reason: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Cleanup -path $PackagesPath

Write-Host "Done." -ForegroundColor Green