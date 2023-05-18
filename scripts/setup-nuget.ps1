$ErrorActionPreference = "Stop"; 

# If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole( [Security.Principal.WindowsBuiltInRole] "Administrator")) { 
#     throw "Run command in an administrator PowerShell prompt" 
# };

If ($PSVersionTable.PSVersion -lt (New-Object System.Version("7.0"))) { 
    throw "The minimum version of Windows PowerShell that is required by the script (7.0) does not match the currently running version of Windows PowerShell." 
};

If (-NOT (Test-Path $env:SystemDrive\'nuget')) { 
    mkdir $env:SystemDrive\'nuget' 
};


Push-Location $env:SystemDrive\'nuget'; 

$nugetExe = "$PWD\nuget.exe"; 
$DefaultProxy = [System.Net.WebRequest]::DefaultWebProxy; 
$securityProtocol = @(); 
$securityProtocol += [Net.ServicePointManager]::SecurityProtocol; 
$securityProtocol += [Net.SecurityProtocolType]::Tls12; 
[Net.ServicePointManager]::SecurityProtocol = $securityProtocol; 
$WebClient = New-Object Net.WebClient; 
$Uri = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'; 
if ($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri))) { 
    $WebClient.Proxy = New-Object Net.WebProxy($DefaultProxy.GetProxy($Uri).OriginalString, $True); 
};

$WebClient.DownloadFile($Uri, $nugetExe);

Move-Item -Path $nugetExe -Destination $env:SystemDrive\'nuget' -Force

Function Add-PathVariable {
    param (
        [string]$addPath
    )
    if (Test-Path $addPath) {
        $regexAddPath = [regex]::Escape($addPath)
        $arrPath = $env:Path -split ';' | Where-Object { $_ -notMatch "^$regexAddPath\\?" }
        return ($arrPath + $addPath) -join ';'
    }
    else {
        Throw "'$addPath' is not a valid path."
    }
}

[Environment]::SetEnvironmentVariable("PATH", $(Add-PathVariable $env:SystemDrive\'nuget'), [EnvironmentVariableTarget]::User)

Pop-Location