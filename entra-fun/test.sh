#!/bin/bash
 set -x
# Login to Azure
az login

# Set subscription and role names
SUB=""
RN="MyCustomRole"
PN="myTest"

# Set the Azure subscription
az account set --subscription $SUB

# Create the custom role definition
cat <<EOF > customRole.json
{
  "Name": "$RN",
  "IsCustom": true,
  "Description": "Custom role to create service principals and assign roles",
  "Actions": [
    "Microsoft.Authorization/roleAssignments/read",
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/delete",
    "Microsoft.Authorization/roleDefinitions/read"
  ],
  "NotActions": [],
  "AssignableScopes": [
    "/subscriptions/$SUB"
  ]
}
EOF

# Create the custom role
az role definition create --role-definition customRole.json

# Retrieve the custom role definition to get its ID
role_id=$(az role definition list --name $RN --query "[0].id" -o tsv)

# List custom roles to verify
az role definition list --custom-role-only true

# Create the service principal
sp=$(az ad sp create-for-rbac --name $PN --skip-assignment)
sp_id=$(echo $sp | jq -r '.appId')

# Create a role assignment with the custom role
az role assignment create --assignee $sp_id --role $role_id --scope "/subscriptions/$SUB"

# Define the API permissions
api_permissions=(
    "19dbc75e-c2e2-444c-a770-ec69d8559fc7"
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61"
    "06da0dbc-49e2-44d2-8312-53f166ab848a"
)

# Authenticate with Microsoft Graph
az account get-access-token --resource https://graph.microsoft.com > token.json
token=$(jq -r '.accessToken' token.json)

# Assign the Application.ReadWrite.Ownedby role using Microsoft Graph API
for permission in "${api_permissions[@]}"; do
    params=$(jq -n --arg principalId "$sp_id" --arg resourceId "00000003-0000-0000-c000-000000000000" --arg appRoleId "$permission" '{
        "principalId": $principalId,
        "resourceId": $resourceId,
        "appRoleId": $appRoleId
    }')

    response=$(curl -s -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$params" "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignments")
    if echo $response | jq -e '.error' > /dev/null; then
        echo "Failed to assign permission $permission"
        echo $response | jq -r '.error.message'
    else
        echo "Successfully assigned permission $permission"
    fi
done

# Grant admin consent
response=$(curl -s -X POST -H "Authorization: Bearer $token" -H "Content-Type: application/json" -d "$params" "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignments")
if echo $response | jq -e '.error' > /dev/null; then
    echo "Failed to grant admin consent"
    echo $response | jq -r '.error.message'
else
    echo "Admin consent granted"
fi

# Verify the assignment
response=$(curl -s -X GET -H "Authorization: Bearer $token" "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignments")
if echo $response | jq -e '.error' > /dev/null; then
    echo "Failed to verify the assignment"
    echo $response | jq -r '.error.message'
else
    echo $response | jq -r '.value[] | {id, resourceAppId, resourceAppDisplayName, scope, roleDefinitionId, roleDefinitionName, adminConsentDescription, adminConsentDisplayName, consentType, grantedTime, principalId, principalDisplayName, principalType}'
fi