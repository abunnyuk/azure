param (
    [Parameter(Mandatory = $true)]
    [string] $outputName,
    [Parameter(Mandatory = $true)]
    [string] $outputObject
)

Write-Output "Retrieved input: $armOutputString"
$armOutputObj = $outputObject | convertfrom-json

$armOutputObj.PSObject.Properties | ForEach-Object {
    $type = ($_.value.type).ToLower()
    $keyname = "_" + $_.name
    $value = $_.value.value

    if ($type -eq "securestring") {
        Write-Output "##vso[task.setvariable variable=$outputName$keyname;issecret=true]$value"
        Write-Output "Added variable '$outputName$keyname' ('$type')"
    }
    elseif ($type -eq "string") {
        Write-Output "##vso[task.setvariable variable=$outputName$keyname]$value"
        Write-Output "Added variable '$outputName$keyname' ('$type') with value '$value'"
    }
    else {
        Write-Host "Type '$type' is not supported for '$keyname'"
    }
}