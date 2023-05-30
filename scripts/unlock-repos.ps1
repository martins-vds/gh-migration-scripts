$owner = "findmycare"
$name = "findmycare"
$token = $env:GH_SOURCE_PAT

$repoUri = "https://api.github.com/repos/$owner/$name"

$response = Invoke-RestMethod -Uri $repoUri -Method Get -Headers @{ Authorization = "token $token" }

$id = $response.node_id

Write-Host "Unlocking repository $owner/$name with global id $id" -ForegroundColor Cyan

$unlockQuery = 'mutation unlockRepository($id: ID!)'
$unlockGql = 'unlockLockable(input: {lockableId: $id}) {
    actor {
      login
    }
    unlockedRecord {
      locked
      activeLockReason
    }
  }'

$unlockQuery += " { $($unlockGql) }"

$unlockPayload = @{
    query = $unlockQuery
    variables = @{
        id = $id
    }
    operationName = "unlockRepository"
}

$unlockResponse = Invoke-RestMethod -Uri $baseUri -Method Post -Headers @{ Authorization = "token $token" } -Body $($unlockPayload | ConvertTo-Json -Depth 100)

$unlockResponse | ConvertTo-Json -Depth 100