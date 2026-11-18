########################################################################
# HelloID-Conn-Prov-Target-Smile-Update
# PowerShell V2
# Note: See the README (Remarks) for how the Smile webhook works and its limitations.
# - EmployeeNumber is NOT mapped for Update; the script adds it from the AccountReference
######################################################

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
    # Add EmployeeNumber from AccountReference to body (needed for Smile to identify the account)
    # EmployeeNumber should NOT be mapped in fieldMapping for Update to prevent duplicates when source value changes
    $actionContext.Data | Add-Member -MemberType NoteProperty -Name 'EmployeeNumber' -Value $actionContext.References.Account -Force
    
    # Process
    $actionMessage = "updating account with AccountReference [$($actionContext.References.Account)] and Username [$($actionContext.Data.Username)]"

    $updateAccountBody = $actionContext.Data

    $tenantPath = if ([string]::IsNullOrEmpty($actionContext.configuration.TenantGUID)) { '' } else { "/$($actionContext.configuration.TenantGUID)" } # TenantGUID is optional
    $updateAccountSplatParams = @{
        Uri         = "$($actionContext.configuration.BaseUrl)/api/webhook/$($actionContext.configuration.EnvGUID)/employee/$($actionContext.configuration.WebhookGUID)$tenantPath"
        Method      = 'POST'
        Headers     = @{
            'Content-Type' = 'application/json;charset=utf-8'
        }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes(($updateAccountBody | ConvertTo-Json -Depth 10)))
        ContentType = "application/json;charset=utf-8"
        Verbose     = $false
        ErrorAction = "Stop"
    }

    if (-Not($actionContext.DryRun -eq $true)) {
        $updateAccountResponse = Invoke-RestMethod @updateAccountSplatParams
        # The response is the Smile database ID; it is only logged, not stored or used

        # Note: Smile webhook returns no data, so we return the mapped fields as output
        $outputContext.Data = $actionContext.Data

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "UpdateAccount"
                Message = "Updated account with AccountReference [$($actionContext.References.Account)] and Username [$($actionContext.Data.Username)]. Smile ID: [$updateAccountResponse]"
                IsError = $false
            })
    }
    else {
        Write-Information "[DryRun] Would update account with AccountReference [$($actionContext.References.Account)] and Username [$($actionContext.Data.Username)]"
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