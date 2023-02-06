param (
    [Parameter(Mandatory)]
    [string] $appHealth,

    [Parameter(Mandatory)]
    [string] $appHostname,
    
    [Parameter(Mandatory)]
    [string] $urlPrefix,
    
    [Parameter(Mandatory)]
    [string] $gatewayGroup,
    
    [Parameter(Mandatory)]
    [string] $gatewayName,
    
    [Parameter(Mandatory)]
    [string] $jsonString,
    
    [Parameter(Mandatory)]
    [string] $subscription
)

# $targetAzVersion = "2.39.0"
# pip3 install azure-cli==$targetAzVersion

# convert the json
$listenersJson = $jsonString | ConvertFrom-Json

# for each defined connection, do stuff
foreach ($listener in $listenersJson) {
   
    $listenerUrl = $urlPrefix + "." + $listener.name

    Write-Host @"

    az network application-gateway address-pool create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name pool_$listenerUrl `
        --servers $appHostname `
        --no-wait

"@
    
    az network application-gateway address-pool create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name pool_$listenerUrl `
        --servers $appHostname `
        --no-wait

    Write-Host @"

    az network application-gateway probe create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name probe_$listenerUrl `
        --host-name-from-http-settings true `
        --protocol Https `
        --path $appHealth `
        --interval 30 `
        --threshold 3 `
        --timeout 30 `
        --no-wait

"@

    az network application-gateway probe create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name probe_$listenerUrl `
        --host-name-from-http-settings true `
        --protocol Https `
        --path $appHealth `
        --interval 30 `
        --threshold 3 `
        --timeout 30 `
        --no-wait

    Write-Host @"

    az network application-gateway http-listener create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name listener_$listenerUrl `
        --frontend-port frontendPort443 `
        --host-name $listenerUrl `
        --ssl-cert $listener.cert `
        --no-wait

"@

    az network application-gateway http-listener create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name listener_$listenerUrl `
        --frontend-port frontendPort443 `
        --host-name $listenerUrl `
        --ssl-cert $listener.cert `
        --no-wait

    Write-Host @"

    az network application-gateway http-settings create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name settings_$listenerUrl `
        --port 443 `
        --probe probe_$listenerUrl `
        --protocol Https `
        --host-name-from-backend-pool true `
        --no-wait

"@

    az network application-gateway http-settings create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --name settings_$listenerUrl `
        --port 443 `
        --probe probe_$listenerUrl `
        --protocol Https `
        --host-name-from-backend-pool true `
        --no-wait

    Write-Host @"

    az network application-gateway rule create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --address-pool pool_$listenerUrl `
        --http-listener listener_$listenerUrl `
        --http-settings settings_$listenerUrl `
        --name rule_$listenerUrl `
        --rule-type Basic `
        --no-wait

"@

    az network application-gateway rule create `
        --resource-group $gatewayGroup `
        --gateway-name $gatewayName `
        --address-pool pool_$listenerUrl `
        --http-listener listener_$listenerUrl `
        --http-settings settings_$listenerUrl `
        --name rule_$listenerUrl `
        --rule-type Basic `
        --no-wait
}
