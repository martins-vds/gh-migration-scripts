function Exec {
    param (
        [scriptblock]$ScriptBlock
    )
    & @ScriptBlock
    if ($lastexitcode -ne 0) {
        throw "Script block '$($ScriptBlock.ToString().Substring(0, 10))...' failed with code $($lastexitcode)"
    }
}

function ExecProcess($filePath, $argumentList, $workingDirectory) {
    $errorsLogPath = Join-Path $Env:Temp "errors-$(New-Guid).log"
    New-Item -Type File -Path $errorsLogPath | Out-Null

    $proc = Start-Process -FilePath $filePath -ArgumentList $argumentList -WorkingDirectory $workingDirectory -Wait -NoNewWindow -PassThru -RedirectStandardError $errorsLogPath  

    if ($proc.ExitCode -ne 0) {
        throw "Failed to run command '$filePath $argumentList'. Check the file '$errorsLogPath' for more information."
    }
}

function GetToken ($token, $envToken) {
    if (![string]::IsNullOrEmpty($token)) {
        return $token
    }
    
    if (![string]::IsNullOrEmpty($envToken)) {
        return $envToken
    }

    throw "Either Source or Target Token is missing. Either provide it through the '-SourceToken' or '-TargetToken' parameter or create the env. variables 'GH_PAT' and 'GH_SOURCE_PAT'"
}

function BuildHeaders ($token) {
    $headers = @{
        Accept        = "application/vnd.github+json"
        Authorization = "Bearer $token"
    }

    return $headers
}

function Get ($uri, $token) {
    return Invoke-RestMethod -Uri $uri -Method Get -Headers $(BuildHeaders -token $token)
}

function Put ($uri, $body, $token) {
    return Invoke-RestMethod -Uri $uri -Method Put -Headers $(BuildHeaders -token $token) -Body $($body | ConvertTo-Json)
}

function Patch ($uri, $body, $token) {
    return Invoke-RestMethod -Uri $uri -Method Patch -Headers $(BuildHeaders -token $token) -Body $($body | ConvertTo-Json)
}

function Post ($uri, $body, $token) {
    return Invoke-RestMethod -Uri $uri -Method Post -Headers $(BuildHeaders -token $token) -Body $($body | ConvertTo-Json)
}

function Delete ($uri, $token) {
    return Invoke-RestMethod -Uri $uri -Method Delete -Headers @{"Authorization" = "token $token" }
}

function SaveTo-Csv(
    [Parameter(Mandatory, ValueFromPipeline)]
    $Data, 
    [Parameter(Mandatory)]
    $OutputFile,
    [bool]$Confirm) {
    if (Test-Path -Path $OutputFile) {
        if ($Confirm) {
            $Data | Export-Csv -Path $OutputFile -Force -UseQuotes AsNeeded -NoTypeInformation -Encoding utf8
        }
        else {
            $override = $Host.UI.PromptForChoice("File '$OutputFile' already exists!", 'Do you want to override it?', @('&Yes', '&No'), 1)
    
            if ($override -eq 0) {
                $Data | Export-Csv -Path $OutputFile -Force -UseQuotes AsNeeded -NoTypeInformation -Encoding utf8
            }
        }
    }
    else {
        $Data | Export-Csv -Path $OutputFile -Force -UseQuotes AsNeeded -NoTypeInformation -Encoding utf8
    }
}