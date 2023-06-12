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

    $guid = [guid]::NewGuid().ToString()

    $tmpOutputLogPath = Join-Path $workingDirectory "output-$guid.log"
    $tmpErrorsLogPath = Join-Path $workingDirectory "errors-$guid.log"

    New-Item -Path $tmpOutputLogPath -ItemType File -Force | Out-Null
    New-Item -Path $tmpErrorsLogPath -ItemType File -Force | Out-Null 

    $proc = Start-Process -FilePath $filePath -ArgumentList $argumentList -WorkingDirectory $workingDirectory -Wait -NoNewWindow -PassThru -RedirectStandardError $tmpErrorsLogPath -RedirectStandardOutput $tmpOutputLogPath

    $result.exitCode = $proc.ExitCode

    try {
        $proc.Close()
        $proc.Dispose()
        $proc = $null
    }
    catch {
    }

    $result.output += Get-Content -Path $tmpOutputLogPath
    $result.errors += Get-Content -Path $tmpErrorsLogPath

    if ($result.exitCode -eq 0) {
        Remove-Item -Path $tmpErrorsLogPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        $result.exitMessage = "[Exit Code = $($result.exitCode)] Failed to execute '$filePath $($argumentList | Join-String -Separator " ")'. Check '$tmpErrorsLogPath' for more details."
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

function ArchiveRepo ($org, $repo, $token) {
    $archiveApi = "https://api.github.com/repos/$org/$repo"
    $body = @{ archived = $true }

    try {
        Invoke-RestMethod -Method Patch -Uri $archiveApi -Headers $(BuildHeaders -token $token) -body $($body | ConvertTo-Json -Depth 100) | Out-Null
    }
    catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Forbidden) {
            throw
        }
    }
}

function UnarchiveRepo ($org, $repo, $token) {
    $archiveApi = "https://api.github.com/repos/$org/$repo"
    $body = @{ archived = $false }

    try {
        Invoke-RestMethod -Method Patch -Uri $archiveApi -Headers $(BuildHeaders -token $token) -body $($body | ConvertTo-Json -Depth 100) | Out-Null
    }
    catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Forbidden) {
            throw
        }
    }
}

function Delete ($uri, $token) {
    return Invoke-RestMethod -Uri $uri -Method Delete -Headers $(BuildHeaders -token $token)
}

function BuildHeaders ($token) {
    $headers = @{
        Accept                 = "application/vnd.github+json"
        Authorization          = "Bearer $token"
        "Content-Type"         = "application/json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    return $headers
}