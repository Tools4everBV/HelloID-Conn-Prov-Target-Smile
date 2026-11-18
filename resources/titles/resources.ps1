########################################################################
# HelloID-Conn-Prov-Target-Smile-Resources-Titles
# PowerShell V2
# Note: See the README (Remarks) for how the Smile webhook works and its limitations.
# - Resource creation is a POST that creates OR updates automatically (no existence check)
# - Uses its own webhook key (TitleWebhookGUID); enter the same value as WebhookGUID when one webhook is used
######################################################

# Make sure the resourceContext data is unique. Fill in the required fields after -unique
$resourceData = $resourceContext.SourceData | Select-Object -Unique ExternalId, Name

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
        # The webhook returns no error details, so the friendly message is the raw error
        $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
        Write-Output $httpErrorObj
    }
}
#endregion functions

try {
    $actionMessage = "creating [$(($resourceContext.SourceData | Measure-Object).Count)] title resources"
    Write-Information "Creating [$($resourceContext.SourceData.Count)] title resources"

    if ([string]::IsNullOrEmpty($actionContext.Configuration.TitleWebhookGUID)) {
        throw 'TitleWebhookGUID is not configured'
    }

    foreach ($resource in $resourceContext.SourceData) {
        try {
            $actionMessage = "creating title resource with code [$($resource.ExternalId)] and name [$($resource.Name)]"
            
            # Create title body
            $titleBody = @{
                TitleCode = $resource.ExternalId
                TitleName = $resource.Name
            }

            $createTitleSplatParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/api/webhook/$($actionContext.Configuration.EnvGUID)/employee/$($actionContext.Configuration.TitleWebhookGUID)/$($actionContext.Configuration.TenantGUID)"
                Method      = 'POST'
                Headers     = @{
                    'Content-Type' = 'application/json;charset=utf-8'
                }
                Body        = ([System.Text.Encoding]::UTF8.GetBytes(($titleBody | ConvertTo-Json -Depth 10)))
                ContentType = "application/json;charset=utf-8"
                Verbose     = $false
                ErrorAction = "Stop"
            }

            if (-not ($actionContext.DryRun -eq $true)) {
                Write-Information "Creating title resource: $($titleBody | ConvertTo-Json)"
                [void](Invoke-RestMethod @createTitleSplatParams)
                
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = 'CreateResource'
                        Message = "Created title resource with code [$($resource.ExternalId)] and name [$($resource.Name)]"
                        IsError = $false
                    })
            }
            else {
                Write-Information "[DryRun] Would create title resource with code [$($resource.ExternalId)] and name [$($resource.Name)]"
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