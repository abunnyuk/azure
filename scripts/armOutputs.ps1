param (
    [Parameter(Mandatory = $true)]
    [string] $armName,
    [Parameter(Mandatory = $true)]
    [string] $armOutputString
)

Write-Output "Retrieved input: $armOutputString"
$armOutputObj = $armOutputString | convertfrom-json

$armOutputObj.PSObject.Properties | ForEach-Object {
    $type = ($_.value.type).ToLower()
    $keyname = "_" + $_.name
    $value = $_.value.value

    if ($type -eq "securestring") {
        Write-Output "##vso[task.setvariable variable=$armName$keyname;issecret=true]$value"
        Write-Output "Added variable '$armName$keyname' ('$type')"
    }
    elseif ($type -eq "string") {
        Write-Output "##vso[task.setvariable variable=$armName$keyname]$value"
        Write-Output "Added variable '$armName$keyname' ('$type') with value '$value'"
    }
    else {
        Throw "Type '$type' is not supported for '$keyname'"
    }
}