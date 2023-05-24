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
        exitCode = 0
        errors = @()
        output = @()
    }
    
    $outputLogPath = Join-Path $workingDirectory "output-$(New-Guid).log"
    $errorsLogPath = Join-Path $workingDirectory "errors-$(New-Guid).log"

    New-Item -Type File -Path $outputLogPath | Out-Null
    New-Item -Type File -Path $errorsLogPath | Out-Null

    $proc = Start-Process -FilePath $filePath -ArgumentList $argumentList -WorkingDirectory $workingDirectory -Wait -NoNewWindow -PassThru -RedirectStandardError $errorsLogPath -RedirectStandardOutput $outputLogPath

    $result.exitCode = $proc.ExitCode    
    $result.errors += Get-Content -Path $errorsLogPath
    $result.output += Get-Content -Path $outputLogPath

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
    }else{
        $actualLength = $Length
    }

    $String.Substring($Start, $actualLength)
}
