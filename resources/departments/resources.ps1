########################################################################
# HelloID-Conn-Prov-Target-Smile-Resources-Departments
# PowerShell V2
# Note: Smile webhook for resource creation:
# - No OAuth token authentication needed (only webhook URL with GUIDs)
# - No HTTP.GET available: cannot check if resource exists
# - Resource creation is a POST that creates OR updates automatically
# - Minimal error handling: webhook only returns generic HTTP errors
######################################################

# Make sure the resourceContext data is unique. Fill in the required fields after -unique
$resourceData = $resourceContext.SourceData | Select-Object -Unique ExternalId, DisplayName

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-SmileError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            # Make sure to inspect the error result object and add only the error message as a FriendlyMessage.
            # $httpErrorObj.FriendlyMessage = $errorDetailsObject.message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}
#endregion functions

try {
    $actionMessage = "creating [$(($resourceContext.SourceData | Measure-Object).Count)] department resources"
    Write-Information "Creating [$($resourceContext.SourceData.Count)] department resources"
    
    foreach ($resource in $resourceContext.SourceData) {
        try {
            $actionMessage = "creating department resource with code [$($resource.ExternalId)] and name [$($resource.DisplayName)]"
            
            # Create department body
            $departmentBody = @{
                DepartmentCode = $resource.ExternalId
                DepartmentName = $resource.DisplayName
            }

            $createDepartmentSplatParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/api/webhook/$($actionContext.Configuration.EnvGUID)/employee/$($actionContext.Configuration.WebhookGUID)/$($actionContext.Configuration.TenantGUID)"
                Method      = 'POST'
                Headers     = @{
                    'Content-Type' = 'application/json;charset=utf-8'
                }
                Body        = ([System.Text.Encoding]::UTF8.GetBytes(($departmentBody | ConvertTo-Json -Depth 10)))
                ContentType = "application/json;charset=utf-8"
                Verbose     = $false
                ErrorAction = "Stop"
            }

            if (-not ($actionContext.DryRun -eq $true)) {
                Write-Information "Creating department resource: $($departmentBody | ConvertTo-Json)"
                $createDepartmentResponse = Invoke-RestMethod @createDepartmentSplatParams
                
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = 'CreateResource'
                        Message = "Created department resource with code [$($resource.ExternalId)] and name [$($resource.DisplayName)]"
                        IsError = $false
                    })
            }
            else {
                Write-Information "[DryRun] Would create department resource with code [$($resource.ExternalId)] and name [$($resource.DisplayName)]"
            }
        }
        catch {
            $outputContext.Success = $false
            $ex = $PSItem
            if ($($ex.Exception.GetType().FullName -eq "Microsoft.PowerShell.Commands.HttpResponseException") -or
                $($ex.Exception.GetType().FullName -eq "System.Net.WebException")) {
                $errorObj = Resolve-SmileError -ErrorObject $ex
                $warningMessage = "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
                $errorMessage = "Error $($actionMessage). Error: $($errorObj.FriendlyMessage)"
            }
            else {
                $warningMessage = "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
                $errorMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
            }
            Write-Warning $warningMessage

            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = $errorMessage
                    IsError = $true
                })
        }
    }

    $outputContext.Success = $true
}
catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq "Microsoft.PowerShell.Commands.HttpResponseException") -or
        $($ex.Exception.GetType().FullName -eq "System.Net.WebException")) {
        $errorObj = Resolve-SmileError -ErrorObject $ex
        $warningMessage = "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
        $errorMessage = "Error $($actionMessage). Error: $($errorObj.FriendlyMessage)"
    }
    else {
        $warningMessage = "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        $errorMessage = "Error $($actionMessage). Error: $($ex.Exception.Message)"
    }
    Write-Warning $warningMessage

    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
}