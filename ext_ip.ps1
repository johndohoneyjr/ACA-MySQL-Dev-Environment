# Define variables
$resourceGroupName = "abc-drupal-rg"

# Get the list of all Container Apps in the resource group
$containerApps = az containerapp list --resource-group $resourceGroupName --query "[].{name:name}" --output tsv

# Iterate over each Container App and get its external IP addresses
foreach ($containerAppName in $containerApps) {
    # Get the FQDN of the Container App
    $fqdn = az containerapp show --name $containerAppName --resource-group $resourceGroupName --query properties.configuration.ingress.fqdn --output tsv

    if ($fqdn) {
        # Resolve the FQDN to get the external IP addresses
        $ips = [System.Net.Dns]::GetHostAddresses($fqdn) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -ExpandProperty IPAddressToString

        # Output the external IP addresses
        Write-Output "External IP addresses for ${containerAppName}:"
        $ips | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output "No FQDN found for ${containerAppName}"
    }
}