param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("windows", "linux")]
    [string] $SwitchTo 
)

$os = "*" + $SwitchTo.ToLower() + "*";

#We want the server portion of the OS/Arch string
$dockerServer = Docker version -f json | ConvertFrom-Json | Select-Object -ExpandProperty Server

#$dockerServerOs = Docker version
if ($dockerServer.Os -like $os) {
    Write-Host "Docker is already set to '$SwitchTo' containers" -ForegroundColor Blue
}
else {
    Write-Host "Switching Docker to '$SwitchTo' containers..." -ForegroundColor Blue
    
    & "c:\program files\docker\docker\dockercli" -SwitchDaemon

    if($LASTEXITCODE -eq 0){
        Write-Host "Successfully switched Docker to '$SwitchTo' containers!" -ForegroundColor Green
    }else{
        Write-Host "Failed to switch Docker to '$SwitchTo' containers!" -ForegroundColor Red
    }
}