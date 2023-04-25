[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateScript({
        if (-Not ($_ | Test-Path) ) {
            throw "File or folder does not exist"
        }
    
        if (-Not ($_ | Test-Path -PathType Container) ) {
            throw "The Path argument must be a folder. File paths are not allowed."
        }

        return $true
    })]
    [System.IO.FileInfo]
    $Path,
    [Parameter(Mandatory)]
    [ValidateScript({
        if($_ -notmatch "(\.csv$)"){
            throw "The file specified in the OutputFile argument must have the extension 'csv'"
        }
        return $true 
    })]
    [System.IO.FileInfo]
    $OutputFile
)

$csvFiles = @(Get-ChildItem -Path $Path -Include *.csv -Recurse | Select-Object -ExpandProperty FullName)

if($csvFiles.Length -eq 0){
    Write-Error "No csv files were found in the folder '$Path'." -ForegroundColor Red
    exit 1
}

if(-Not(Test-Path -Path $OutputFile.Directory.FullName)){
    New-Item -Path $OutputFile.Directory.FullName -ItemType Directory -Force | Out-Null
}

$csvFiles | Import-Csv | Export-Csv $OutputFile -Append -UseQuotes AsNeeded -NoTypeInformation -Encoding utf8

Write-Host "$($csvFiles.Length) csv files were merged into '$($OutputFile.FullName)'." -ForegroundColor Green