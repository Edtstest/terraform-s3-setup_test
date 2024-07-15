# Hardcoded Variables for Testing
$TERRAFORM_API_TOKEN = $env:TERRAFORM_API_TOKEN
$ORG_NAME = "Edts"
$DEV_WORKSPACE_NAME = "terraform-s3-setup"
$TEST_WORKSPACE_NAME  = "Terraform-s3-setup-Test-POS"

# Log the initial variables
Write-Host "TERRAFORM_API_TOKEN: $TERRAFORM_API_TOKEN"
Write-Host "ORG_NAME: $ORG_NAME"
Write-Host "DEV_WORKSPACE_NAME: $DEV_WORKSPACE_NAME"

# Function to make API requests
function Invoke-TerraformApi {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null
    )
    
    # Log the input parameters
    Write-Host "Invoke-TerraformApi called with parameters:"
    Write-Host "Uri: $Uri"
    Write-Host "Method: $Method"
    Write-Host "Body: $Body"

    $headers = @{
        "Authorization" = "Bearer $TERRAFORM_API_TOKEN"
        "Content-Type" = "application/vnd.api+json"
    }
    
    # Log the headers
    Write-Host "Headers: $($headers | ConvertTo-Json -Compress)"
    
    try {
        if ($Method -eq "POST" -and $Body) {
            $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method -Body $Body
        } else {
            $response = Invoke-RestMethod -Uri $Uri -Headers $headers -Method $Method
        }
        
        # Log the response
      # Write-Host "Response: $($response | ConvertTo-Json -Compress)"
        
        return $response
    } catch {
        # Log any errors
        Write-Host "Error: $($_ | ConvertTo-Json -Compress)"
        throw $_
    }
}


# Get workspace ID
function Get-WorkspaceID {
    param ($WorkspaceName)
    $uri = "https://app.terraform.io/api/v2/organizations/$ORG_NAME/workspaces/$WorkspaceName"
    $workspaceId = (Invoke-TerraformApi -Uri $uri).data.id
    Write-Host "Workspace ID for ${WorkspaceName}: $workspaceId"
    return $workspaceId
}

# Get latest run status
function Get-LatestRunStatus {
    param ($WorkspaceID)
    $uri = "https://app.terraform.io/api/v2/workspaces/$WorkspaceID/runs"
    $latestRunStatus = (Invoke-TerraformApi -Uri $uri).data[0].attributes.status
    Write-Host "Latest run status for workspace ID ${WorkspaceID}: $latestRunStatus"
    return $latestRunStatus
}

# Function to trigger a run with detailed logging
function Trigger-Run {
    param ($WorkspaceID)
    $uri = "https://app.terraform.io/api/v2/runs"
    
    Write-Host "Trigger-Run called with WorkspaceID: $WorkspaceID"
    Write-Host "API URI: $uri"

    $body = @{
        data = @{
            attributes = @{
                "is-destroy" = $false
                "message" = "Triggered by Dev deployment"
            }
            type = "runs"
            relationships = @{
                workspace = @{
                    data = @{
                        type = "workspaces"
                        id = $WorkspaceID
                    }
                }
            }
        }
    }

    $bodyJson = $body | ConvertTo-Json -Depth 4
    Write-Host "Request Body (JSON): $bodyJson"

    try {
        Write-Host "Making API request..."
        
        $headers = @{
            "Authorization" = "Bearer $TERRAFORM_API_TOKEN"
            "Content-Type" = "application/vnd.api+json"
        }

        # Log headers to verify they are set correctly
        Write-Host "Headers: $($headers | ConvertTo-Json -Compress)"

        # Directly use Invoke-RestMethod for the POST request
        $response = Invoke-RestMethod -Uri $uri -Method "POST" -Headers $headers -Body $bodyJson -ErrorAction Stop

        Write-Host "API request completed successfully."
        Write-Host "Trigger run response: $($response | ConvertTo-Json -Compress)"
        return $response
    } catch {
        Write-Host "Error occurred during API request:"
        Write-Host "Error Message: $($_.Exception.Message)"
        Write-Host "Error Stack Trace: $($_.Exception.StackTrace)"
        
        if ($_.Exception.Response -ne $null) {
            $stream = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $responseBody = $stream.ReadToEnd()
            Write-Host "Response Body: $responseBody"
        }
        
        throw $_
    }
}



$devWorkspaceID = Get-WorkspaceID -WorkspaceName $DEV_WORKSPACE_NAME
 $testWorkspaceID = Get-WorkspaceID -WorkspaceName $TEST_WORKSPACE_NAME



if ($devWorkspaceID) {
    Write-Host "Checking latest run status for dev workspace..."
    do {
        $latestRunStatus = Get-LatestRunStatus -WorkspaceID $devWorkspaceID
        Write-Host "Latest run status for dev workspace: $latestRunStatus"
        Start-Sleep -Seconds 60  # Polling interval
    } while ($latestRunStatus -ne "applied" -and $latestRunStatus -ne "failed" -and $latestRunStatus -ne "errored")

    if ($latestRunStatus -eq "applied") {
        Write-Host "Latest run in dev workspace was successfully applied. Triggering test workspace..."
        $triggerResponse = Trigger-Run -WorkspaceID $testWorkspaceID
        Write-Host "Test workspace triggered successfully. Response: $($triggerResponse | ConvertTo-Json -Compress)"
    } else {
        Write-Host "Latest run in dev workspace did not succeed. No action taken."
    }
} else {
    Write-Host "Failed to retrieve dev workspace ID."
    exit 1
}
