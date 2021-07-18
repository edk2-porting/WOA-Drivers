Param([Parameter(Mandatory=$true)][String]$CodeName)
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$Configs="definitions"
$DefConfig="sdm845-generic"
$Config=Join-Path `
    -Path $Configs `
    -ChildPath (-Join ($CodeName,".txt"))
If( -Not (Test-Path -Path $Config)){
    Write-Output "warning: your model has no definition file, use default"
    $Config=Join-Path `
        -Path $Configs `
        -ChildPath (-Join ($DefConfig,".txt"))
    if( -Not (Test-Path -Path $Config)){
        Write-Output "default definition file not found"
        exit 1
    }
}
If(Test-Path -Path output){
    Remove-Item `
        -Recurse `
        -Force `
        -Path output
}
Write-Output "copying drivers..."
$Output=New-Item `
    -ItemType Directory `
    -Path output
Get-Content `
    -Path $Config | `
    Copy-Item `
        -Recurse `
        -Path { "."+$_ } `
        -Destination $Output
Write-Output "rename drivers..."
Get-ChildItem `
    -Recurse `
    -Path $Output `
    -Filter *.inf_ | `
    Rename-Item `
        -NewName { `
            $_.FullName `
                -Replace '\.inf_','.inf' `
        }
Write-Output "done"

