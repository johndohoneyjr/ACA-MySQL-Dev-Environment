# Import the necessary Azure modules
Import-Module Az.Accounts
Import-Module Az.Resources
Import-Module Microsoft.Graph

# Login to Azure
Connect-AzAccount

# Set subscription and role names
$SUB ""
$RN = "MyCustomRole"
$PN = "myTest"

# Set the Azure subscription
Set-AzContext -SubscriptionId $SUB

# Create the custom role definition
$customRole = @{
    Name = $RN
    IsCustom = $true
    Description = "Custom role to create service principals and assign roles"
    Actions = @(
        "Microsoft.Authorization/roleAssignments/read",
        "Microsoft.Authorization/roleAssignments/write",
        "Microsoft.Authorization/roleAssignments/delete",
        "Microsoft.Authorization/roleDefinitions/read"
    )
    NotActions = @()
    AssignableScopes = @("/subscriptions/$SUB")
}

# Convert the custom role to JSON
$customRoleJson = $customRole | ConvertTo-Json -Depth 10

# Save the custom role JSON to a file
$customRoleJson | Out-File -FilePath "customRole.json" -Encoding utf8

# Create the custom role
New-AzRoleDefinition -InputFile "customRole.json"

# Retrieve the custom role definition to get its ID
$role = Get-AzRoleDefinition -Name $RN

# List custom roles to verify
Get-AzRoleDefinition | Where-Object { $_.IsCustom -eq $true }

# Create the service principal
$sp = New-AzADServicePrincipal -DisplayName $PN

# Create a role assignment with the custom role
New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionId $role.Id -Scope "/subscriptions/$SUB"

# Get the service principal object ID
$SP_DISPLAY_NAME = $PN
$sp = Get-AzADServicePrincipal -DisplayName $SP_DISPLAY_NAME

# Check if the service principal is retrieved
if (-not $sp) {
    Write-Host "Service principal not found."
    exit 1
}

# Define the API permissions
$apiPermissions = @(
    "19dbc75e-c2e2-444c-a770-ec69d8559fc7",
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
    "06da0dbc-49e2-44d2-8312-53f166ab848a"
)

# Authenticate with Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
## az ad sp show --id 00000003-0000-0000-c000-000000000000 >microsoft_graph_permission_list.json


# Assign the Application.ReadWrite.Ownedby role using Microsoft Graph API
foreach ($permission in $apiPermissions) {
    $params = @{
        "principalId" = $sp.Id
        "resourceId" = "00000003-0000-0000-c000-000000000000"
        "appRoleId" = $permission
    }
   
    try {
       New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -ResourceId "00000003-0000-0000-c000-000000000000" -AppRoleId $permission
       Write-Host "Successfully assigned permission $permission"
    } catch {
        Write-Host "Failed to assign permission $permission"
        Write-Host $_.Exception.Message
    }
}

# Grant admin consent
try {
    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/appRoleAssignments" -Body $params
    Write-Host "Admin consent granted"
} catch {
    Write-Host "Failed to grant admin consent"
    Write-Host $_.Exception.Message
}

# Verify the assignment
try {
    $response = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/appRoleAssignments"
    $response | Select-Object id, resourceAppId, resourceAppDisplayName, scope, roleDefinitionId, roleDefinitionName, adminConsentDescription, adminConsentDisplayName, consentType, grantedTime, principalId, principalDisplayName, principalType
} catch {
    Write-Host "Failed to verify the assignment"
    Write-Host $_.Exception.Message
}