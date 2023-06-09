. $PSScriptRoot\common.ps1

function GetEnvironments ($org, $repo, $token) {
    $secretsApi = "https://api.github.com/repos/$org/$repo/environments"
    return @(Get -uri $secretsApi -token $token | Select-Object -ExpandProperty environments)
}

function GetEnvironmentVariables($repoId, $environmentName, $token) {
    $environmentVariablesApi = "https://api.github.com/repositories/$repoId/environments/$environmentName/variables"

    try {
        return @(Get -uri $environmentVariablesApi -token $token | Select-Object -ExpandProperty variables)
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            return @()
        }

        throw
    }
}

function GetEnvironmentSecrets($repoId, $environmentName, $token) {
    $secretsApi = "https://api.github.com/repositories/$repoId/environments/$environmentName/secrets"
    return @(Get -uri $secretsApi -token $token | Select-Object -ExpandProperty secrets)
}

function GetEnvironmentPublicyKey ($repoId, $environmentName, $token) {
    $secretsApi = "https://api.github.com/repositories/$repoId/environments/$environmentName/secrets/public-key"
    return Get -uri $secretsApi -token $token
}

function CreateEnvironment($org, $repo, $environmentName, $environment, $token) {
    $secretsApi = "https://api.github.com/repos/$org/$repo/environments/$environmentName"
    
    return Put -uri $secretsApi -token $token -body $environment
}

function CreateEnvironmentVariable($repoId, $environmentName, $variableName, $variableValue, $token) {
    $environmentVariablesApi = "https://api.github.com/repositories/$repoId/environments/$environmentName/variables"
    
    $variable = @{
        name  = $variableName
        value = $variableValue
    }

    try {
        Post -uri $environmentVariablesApi -token $token -body $variable | Out-Null
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict) {
            throw
        }

        Patch -uri "$environmentVariablesApi/$variableName" -token $token -body $variable | Out-Null
    }
}

function CreateEnvironmentSecret ($repoId, $environmentName, $secretName, $secretValue, $token) {
    $secretsApi = "https://api.github.com/repositories/$repoId/environments/$environmentName/secrets/$secretName"
    return Put -uri $secretsApi -token $token -body $secretValue
}

function MigrateEnvironment ($org, $repo, $environment, $token) {
    $newEnvironment = @{
        deployment_branch_policy = $environment.deployment_branch_policy
    }

    $wait_timer = $environment.protection_rules | Where-Object -Property type -EQ wait_timer | Select-Object -ExpandProperty wait_timer
    $reviewers = @($environment.protection_rules | Where-Object -Property type -EQ required_reviewers | Select-Object -ExpandProperty reviewers | Select-Object -Property type, @{Name = 'id'; Expression = { $_.reviewer.id } })

    if ($wait_timer) {
        $newEnvironment.wait_timer = $wait_timer
    }

    if ($reviewers) {
        $newEnvironment.reviewers = $reviewers
    }

    CreateEnvironment -org $org -repo $repo -environmentName $environment.name -environment $newEnvironment -token $token | Out-Null
}