[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetOrg,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $SourceUsername,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $TargetUsername,
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

function AuthenticateRegistry ($user, $token){
    Exec { $token | docker login ghcr.io --username $user --password-stdin } | Out-Null
    # Start-Process docker -ArgumentList "login ghcr.io --username $user --password $token" -Wait -NoNewWindow | Out-Null
}

function PullImage($owner, $image, $tag){
    Exec { docker pull "ghcr.io/$($owner.ToLower())/$($image):$tag" } | Out-Null    
}

function PullImage($owner, $image, $sha){
    Exec { docker pull "ghcr.io/$($owner.ToLower())/$($image)@$($sha)" } | Out-Null
}

function TagImage($owner, $newOwner, $image, $sha, $tag){
    Exec { docker tag "ghcr.io/$($owner.ToLower())/$($image)@$($sha)" "ghcr.io/$($newOwner.ToLower())/$($image):$tag"} | Out-Null
}

function PushImage($owner, $image, $tag){
    Exec { docker push "ghcr.io/$($owner.ToLower())/$($image):$tag" } | Out-Null
}

function TryDeleteImage($owner, $image, $sha){
    try {
        $imageId = Exec { docker images --filter="reference=ghcr.io/$($owner.ToLower())/$image@$sha" --format="{{.ID}}" }
        Exec { docker image rmi "$imageId" -f } | Out-Null 
    }catch{}
}

function GetImageOS($owner, $image, $tag, $token){
    $dockerManifestApi = "https://ghcr.io/v2/$owner/$image/manifests/$tag"
    $headers = @{
        Accept = "application/vnd.docker.distribution.manifest.v2+json"
        Authorization = "Bearer $([Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($token)))"
    }
    
    $imageManifest = Invoke-RestMethod -Uri $dockerManifestApi -Method Get -Headers $headers

    $dockerBlobApi = "https://ghcr.io/v2/$owner/$image/blobs/$($imageManifest.config.digest)"

    return Invoke-RestMethod -Uri $dockerBlobApi -Method Get -Headers $headers | Select-Object -ExpandProperty "os"
}

function SwitchDockerOS($os){
    $dockerServer = Docker version -f json | ConvertFrom-Json | Select-Object -ExpandProperty Server

    $os = "*$($os.ToLower())*"

    if($dockerServer.Os -notlike $os)
    {
        & "c:\program files\docker\docker\dockercli" -SwitchDaemon

        if($LASTEXITCODE -ne 0){
            throw "Failed to switch Docker to '$SwitchTo' containers!"
        }
    }
}

$sourcePat = GetToken -token $SourceToken -envToken $env:GH_SOURCE_PAT
$targetPat = GetToken -token $TargetToken -envToken $env:GH_PAT

$sourceContainerImages = GetPackages -org $SourceOrg -type "container" -token $sourcePat

if($sourceContainerImages.Length -eq 0){
    Write-Host "No container images found in organization '$SourceOrg'." -ForegroundColor Yellow
    exit 0
}

$sourceContainerImages | ForEach-Object {
    $sourceContainerImage = $_
    $sourceContainerImageTags = GetPackageVersions -org $SourceOrg -type "container" -package $sourceContainerImage.name -max $MaxVersions -token $sourcePat

    $targetContainerImageTags = GetPackageVersions -org $TargetOrg -type "container" -package $sourceContainerImage.name -max $MaxVersions -token $targetPat

    $sourceContainerImageTags | ForEach-Object {
        $sourceContainerImageTag = $_
        
        $targetContainerImage = $targetContainerImageTags | Where-Object -Property name -EQ $sourceContainerImageTag.name

        $containerImageName = "$($sourceContainerImage.name):$($sourceContainerImageTag.name.Substring(0,15))"
        if($targetContainerImage){
            Write-Host "Skipping container image '$containerImageName'. It already exists in organization '$TargetOrg'." -ForegroundColor Yellow
            continue
        }else{
            Write-Host "Migrating container image '$containerImageName' to organization '$TargetOrg'..." -ForegroundColor Blue
        }

        try {
            SwitchDockerOS -os $(GetImageOS -owner $SourceOrg -image $sourceContainerImage.name -tag $sourceContainerImageTag.name -token $sourcePat)

            AuthenticateRegistry -user $SourceUsername -token $sourcePat

            PullImage -owner $SourceOrg -image $sourceContainerImage.name -sha $sourceContainerImageTag.name

            AuthenticateRegistry -user $TargetUsername -token $targetPat

            $sourceContainerImageTag.metadata.container.tags | ForEach-Object {
                $tag = $_

                TagImage -owner $SourceOrg -newOwner $TargetOrg -image $sourceContainerImage.name -sha $sourceContainerImageTag.name -tag $tag
                PushImage -owner $TargetOrg -image $sourceContainerImage.name -tag $tag
            }
        }catch{
            Write-Host "Failed to migrate container image '$containerImageName'. Reason: $($_.Exception.Message)." -ForegroundColor Red
        }
        finally {
            TryDeleteImage -owner $SourceOrg -image $sourceContainerImage.name -sha $sourceContainerImageTag.name
        }
    }
}

Write-Host "Done." -ForegroundColor Green