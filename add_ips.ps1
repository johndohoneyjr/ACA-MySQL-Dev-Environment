# Connect to Azure with TenantId
$tenantId = "<tenant-id>"
Connect-AzAccount -TenantId $tenantId

# Define variables
$resourceGroupName = "abc-drupal-rg"
$serverName = "acacmsmysqlserver" 
$ipAddresses = @(
    "20.175.131.120", "20.175.131.81", "20.175.131.103", "20.175.131.130",
    "20.116.137.89", "20.116.137.87", "20.116.137.109", "20.116.137.103",
    "20.116.137.113", "20.116.137.115", "20.200.119.152", "20.200.119.174",
    "20.200.119.159", "20.200.119.172", "4.172.39.65", "4.172.39.74",
    "4.172.39.70", "4.172.39.51", "4.172.39.53", "4.172.39.43",
    "20.175.254.189", "20.175.253.103", "20.175.253.223", "20.175.252.193",
    "20.175.200.30", "20.175.253.76", "20.175.252.227", "20.175.253.30",
    "20.175.200.11", "20.175.253.9", "20.175.163.9"
)

# Add each IP address to the firewall rules
foreach ($ip in $ipAddresses) {
    $ruleName = "AllowIP_$ip"
    New-AzMySqlFlexibleServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $serverName -FirewallRuleName $ruleName -StartIpAddress $ip -EndIpAddress $ip
    Write-Output "Added firewall rule for IP: $ip"
}