. $PSScriptRoot\common.ps1

function GetPackages($org, $type, $token){
    $packagesApi = "https://api.github.com/orgs/$org/packages?package_type=$type&page={0}&per_page=100"
    $allPackages = @()
    $page = 0

    do {
        $page += 1  
        $packages = Get -uri "$($packagesApi -f $page)" -token $token
        $allPackages += $packages 
    } while ($packages.Length -gt 0)


    return $allPackages
}

function GetPackageVersions($org, $type, $package, $max, $token){
    $packagesApi = "https://api.github.com/orgs/$org/packages/$type/$package/versions?page={0}&per_page=100"
    $allVersions = @()
    $page = 0

    try {
        do {    
            $page += 1  
            $versions = Get -uri "$($packagesApi -f $page)" -token $token
            $allVersions += $versions 
        } while ($versions.Length -gt 0)
    
        return $allVersions | Sort-Object -Property id -Descending | Select-Object -Property id, name, metadata -First $max
    }
    catch {
        return @()
    }
}

function GetPackageVersion($org, $type, $package, $version, $token){
    $packagesApi = "https://api.github.com/orgs/$org/packages/$type/$package/versions/$version"

    try {
        return Get -uri $packagesApi -token $token
    }
    catch {
        return $null
    }
}

function Cleanup([System.IO.FileInfo]$path){
    If(Test-Path -Path $path -PathType Container){
        Remove-Item "$($path.FullName.TrimEnd("\"))\*" -Recurse -Force
    }
}

function CleanupConfig($org, $path){
    If(Test-Path -Path "$path\$org"){
        Remove-Item "$path\$org" -Recurse -Force
    }
}