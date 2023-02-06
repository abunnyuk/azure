param (
    [Parameter(Mandatory)]
    [string] $appShort,
    [Parameter(Mandatory)]
    [string] $envShort,
    [Parameter(Mandatory)]
    [string] $jsonString,
    [Parameter(Mandatory)]
    [string] $sqlUser,
    [Parameter()]
    [string] $outputPath,
    [Parameter()]
    [string] $clientId,
    [Parameter()]
    [string] $tenantId
)

$clientSecret = "$env:CLIENT_SECRET"

if (!$outputPath) {
    $outputPath = Get-Location
}

# convert the json
$sqlJson = $jsonString | ConvertFrom-Json

$publicIp = Invoke-RestMethod https://ipinfo.io/json | Select-Object -exp ip
$publicIpLastOctet = $publicIp.Split('.')[3]

$ruleNum = Get-Random -Minimum 2000 -Maximum 2999
$ruleName = "SQL Roles Task - $($env:COMPUTERNAME) - $ruleNum"

if ($?) {
    Write-Host "$env:COMPUTERNAME : $publicIp"
}
else {
    throw "Could not retrieve public IP!"
}

# for each defined connection:
# - build server FQDN
# - create firewall/nsg rule depending on server name prefix
# - authenticate and retrieve an access token
# - run sqlcmd queries
# - remove firewall/nsg rule
foreach ($connection in $sqlJson) {
    $sqlServer = $connection.server
    $sqlServerFqdn = -Join ($connection.server, $connection.suffix)

    # if SQL Database
    if ($sqlServerFqdn -clike 'sql-*') {
        # Remove-AzSqlServerFirewallRule `
        #     -ResourceGroupName $connection.group `
        #     -ServerName $connection.server `
        #     -FirewallRuleName $ruleName `
        #     -Force

        $firewallRule = New-AzSqlServerFirewallRule `
            -ResourceGroupName $connection.group `
            -ServerName $connection.server `
            -FirewallRuleName $ruleName `
            -StartIpAddress $publicIp `
            -EndIpAddress $publicIp

        if ($firewallRule) {
            Write-Host "`nAllowing time for rule to apply before proceeding..."
            Start-Sleep -Second 30
        }
        else {
            throw "Could not set firewall rule!"
        }
    }

    # if SQL Managed Instance
    if ($sqlServerFqdn -clike 'sqlmi-*') {
        if ($connection.nsg) {
            $nsg = Get-AzNetworkSecurityGroup -Name $connection.nsg -ResourceGroupName $connection.group
        }
        else {
            throw "Could not retrieve NSG name!"
        }
        
        Remove-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name "AzureDevOpsAgent"
        $nsgRule = Add-AzNetworkSecurityRuleConfig `
            -NetworkSecurityGroup $nsg `
            -Name $ruleName `
            -Description 'Allow 3342 inbound from Azure DevOps build agent. SQL roles task.' `
            -Access Allow `
            -Protocol Tcp `
            -Direction Inbound `
            -Priority $ruleNum `
            -SourceAddressPrefix $publicIp `
            -SourcePortRange * `
            -DestinationAddressPrefix 'VirtualNetwork' `
            -DestinationPortRange 3342 |
        Set-AzNetworkSecurityGroup

        if ($nsgRule) {
            Write-Host "`nAllowing time for rule to apply before proceeding..."
            Start-Sleep -Second 30
        }
        else {
            throw "Could not set NSG rule!"
        }
    }

    # authenticate and retrieve the access token
    if ($clientId -And $clientSecret -And $sqlServer -And $tenantId) {
        $request = Invoke-RestMethod -Method POST `
            -Uri "https://login.microsoftonline.com/$tenantId/oauth2/token"`
            -Body @{ resource = "https://database.windows.net/"; grant_type = "client_credentials"; client_id = $clientId; client_secret = $clientSecret }`
            -ContentType "application/x-www-form-urlencoded"

        if ($?) {
            Write-Host "Token obtained."
            $access_token = $request.access_token
        }
        else {
            # if authentication fails then remove the firewall/nsg rule
            if ($sqlServerFqdn -clike 'sql-*') {
                Remove-AzSqlServerFirewallRule `
                    -ResourceGroupName $connection.group `
                    -ServerName $connection.server `
                    -FirewallRuleName $ruleName
            }
        
            if ($sqlServerFqdn -clike 'sqlmi-*') {
                Remove-AzNetworkSecurityRuleConfig `
                    -NetworkSecurityGroup $nsg `
                    -Name $ruleName  |
                Set-AzNetworkSecurityGroup
            }

            throw "Authentication failed!"
        }
    }

    $database = $connection.database
    $databaseFile = "$outputPath/$database.sql"
        
    # remove sql file if already exists
    if (Test-Path -Path $databaseFile -PathType Leaf) {
        Remove-Item $databaseFile
    }

    # build the t-sql that creates the user
    $sqlQuery = @()
    $sqlQuery += "-- $sqlServerFqdn\$database`n"
    $sqlQuery += "-- IF EXISTS(SELECT * FROM sys.database_principals WHERE name = '$sqlUser')"
    $sqlQuery += "-- DROP USER [$sqlUser]"
    $sqlQuery += "-- GO`n"

    $sqlQuery += "IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE name = '$sqlUser')"
    $sqlQuery += "CREATE USER [$sqlUser] FROM EXTERNAL PROVIDER"
    $sqlQuery += "GO`n"

    # adds member to each role found
    foreach ($role in $connection.roles) {
        $roleName = ($role).ToLower()
        $sqlQuery += "ALTER ROLE $roleName ADD MEMBER [$sqlUser]"
        $sqlQuery += "GO`n"
    }

    # grants execute to each stored procedure found
    foreach ($spr in $connection.sprs) {
        $sprName = $spr
        $sqlQuery += "IF EXISTS(SELECT * FROM sys.objects WHERE name = '$sprName')"
        $sqlQuery += "GRANT EXECUTE ON [$sprName] TO [$sqlUser]"
        $sqlQuery += "GO`n"
    }

    # permissions
    foreach ($perm in $connection.perms) {
        $permAction = ($perm.action).ToUpper()
        $permPermission = ($perm.permission).ToUpper()
        $sqlQuery += "$permAction $permPermission TO [$sqlUser]"
        $sqlQuery += "GO`n"
    }

    # save the t-sql
    $sqlQuery | Out-File -Append -FilePath $databaseFile

    # if the t-sql script can be found and access token exists then run it against the server
    if ((Test-Path -Path $databaseFile -PathType Leaf) -And $access_token) {
        Get-Content $databaseFile

        Write-Host "Invoke-Sqlcmd -ServerInstance $sqlServerFqdn -Database $database -EncryptConnection -AccessToken ***** -InputFile $databaseFile"

        Invoke-Sqlcmd `
            -ServerInstance $sqlServerFqdn `
            -Database $database `
            -EncryptConnection `
            -AccessToken $access_token `
            -InputFile $databaseFile `
            -ConnectionTimeout 120 `
            -QueryTimeout 120
    }
    else {
        if ($sqlServerFqdn -clike 'sql-*') {
            Remove-AzSqlServerFirewallRule `
                -ResourceGroupName $connection.group `
                -ServerName $connection.server `
                -FirewallRuleName $ruleName
        }
    
        if ($sqlServerFqdn -clike 'sqlmi-*') { 
            Remove-AzNetworkSecurityRuleConfig `
                -NetworkSecurityGroup $nsg `
                -Name $ruleName  |
            Set-AzNetworkSecurityGroup
        }

        throw "Could not access T-SQL script!"
    }

    # remove the firewall/nsg rule
    if ($sqlServerFqdn -clike 'sql-*') {
        Remove-AzSqlServerFirewallRule `
            -ResourceGroupName $connection.group `
            -ServerName $connection.server `
            -FirewallRuleName $ruleName
    }

    if ($sqlServerFqdn -clike 'sqlmi-*') {
        Remove-AzNetworkSecurityRuleConfig `
            -NetworkSecurityGroup $nsg `
            -Name $ruleName  |
        Set-AzNetworkSecurityGroup
    }
}
