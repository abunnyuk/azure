param (
    [Parameter(Mandatory = $true)]
    [string] $memberId,
    [Parameter(Mandatory = $true)]
    [string] $memberName,
    [Parameter(Mandatory = $true)]
    [string] $role,
    [Parameter(Mandatory = $true)]
    [string] $targetName,
    [Parameter(Mandatory = $true)]
    [string] $targetType,
    [Parameter(Mandatory = $true)]
    [string] $memberGroup
)

Write-Host "Member: $memberGroup - $memberName - $memberId"
Write-Host "Target: $targetType/$targetname - $role"

$targetId = az resource show --resource-group $memberGroup --name $targetname --resource-type "$targetType" --query id --output tsv

if ($targetId) {
    Write-Host "Target ID:" $targetId
    az role assignment create --assignee-object-id $memberId --assignee-principal-type ServicePrincipal --scope $targetId --role $role
}
else {
    Write-Host Variables not defined!
    exit 1
}