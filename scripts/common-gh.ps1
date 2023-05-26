function ExecGh {
    param (
        [scriptblock]$ScriptBlock
    )
    & @ScriptBlock
    if ($lastexitcode -ne 0) {
        throw "Script block '$(Substring($ScriptBlock.ToString().Trim(), 0, 60))...' failed with code $($lastexitcode)"
    }
}

function ExecProcess($filePath, $argumentList, $workingDirectory) {
    $result = @{
        exitCode    = 0
        exitMessage = ""
        errors      = @()
        output      = @()
    }

    # $timestamp = (Get-Date).ToString("yyyyMMddHHmmssfff")
    $guid = [guid]::NewGuid().ToString()

    $tmpOutputLogPath = Join-Path $workingDirectory "output-$guid.log"
    $tmpErrorsLogPath = Join-Path $workingDirectory "errors-$guid.log"

    New-Item -Path $tmpOutputLogPath -ItemType File -Force | Out-Null
    New-Item -Path $tmpErrorsLogPath -ItemType File -Force | Out-Null 

    $proc = Start-Process -FilePath $filePath -ArgumentList $argumentList -WorkingDirectory $workingDirectory -Wait -NoNewWindow -PassThru -RedirectStandardError $tmpErrorsLogPath -RedirectStandardOutput $tmpOutputLogPath

    $result.exitCode = $proc.ExitCode    
    $result.output += Get-Content -Path $tmpOutputLogPath
    $result.errors += Get-Content -Path $tmpErrorsLogPath
    
    if ($result.exitCode -eq 0) {
        Remove-Item -Path $tmpErrorsLogPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        $result.exitMessage = "Failed to execute '$filePath $($argumentList | Join-String -Separator " ")'. Check '$tmpErrorsLogPath' for more details."
    }

    Remove-Item -Path $tmpOutputLogPath -Force -ErrorAction SilentlyContinue | Out-Null

    return $result
}

function Substring {
    param (
        [string]$String,
        [int]$Start,
        [int]$Length
    )

    if ($Start -lt 0 -or $Start -gt $String.Length) {
        throw "Start index must be between 0 and $($String.Length)"
    }

    if ($Length -lt 0) {
        throw "Length must be greater than 0"
    }

    if ($Start + $Length -gt $String.Length) {
        $actualLength = $String.Length - $Start
    }
    else {
        $actualLength = $Length
    }

    $String.Substring($Start, $actualLength)
}

function MaskString($string, [string[]] $mask) {
    $maskedString = $string

    foreach ($m in $mask) {
        $maskedString = $maskedString -replace $m, "********"
    }

    return $maskedString
}

function UnlockRepo($migrationId, $org, $repo, $token){
    $unlockUri = "https://api.github.com/orgs/$org/migrations/$migrationId/repos/$repo/lock"

    Delete -uri $unlockUri -token $token | Out-Null
}

function Delete ($uri, $token) {
    return Invoke-RestMethod -Uri $uri -Method Delete -Headers @{"Authorization" = "token $token" }
}