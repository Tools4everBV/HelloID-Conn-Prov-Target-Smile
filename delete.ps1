########################################################################
# HelloID-Conn-Prov-Target-Smile-Delete
# PowerShell V2
# Note: See the README (Remarks) for how the Smile webhook works and its limitations.
# - No actual delete endpoint: Delete is an update that sets Active=false and empties the unique fields (Email, Username)
# - EmployeeNumber is NOT mapped for Delete; the script adds it from the AccountReference
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
    # Process
    $actionMessage = "deleting account with AccountReference [$($actionContext.References.Account)]"

    # EmployeeNumber is not mapped for Delete (prevents duplicates when the source value changes); add it from the AccountReference to the request body only, so Smile can identify the account
    $deleteAccountBody = $actionContext.Data.PSObject.Copy()
    $deleteAccountBody | Add-Member -MemberType NoteProperty -Name 'EmployeeNumber' -Value $actionContext.References.Account -Force

    $tenantPath = if ([string]::IsNullOrEmpty($actionContext.configuration.TenantGUID)) { '' } else { "/$($actionContext.configuration.TenantGUID)" } # TenantGUID is optional
    $deleteAccountSplatParams = @{
        Uri         = "$($actionContext.configuration.BaseUrl)/api/webhook/$($actionContext.configuration.EnvGUID)/employee/$($actionContext.configuration.WebhookGUID)$tenantPath"
        Method      = 'POST'
        Headers     = @{
            'Content-Type' = 'application/json;charset=utf-8'
        }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes(($deleteAccountBody | ConvertTo-Json -Depth 10)))
        ContentType = "application/json;charset=utf-8"
        Verbose     = $false
        ErrorAction = "Stop"
    }

    if (-Not($actionContext.DryRun -eq $true)) {
        $deleteAccountResponse = Invoke-RestMethod @deleteAccountSplatParams
        # The response is the Smile database ID; it is only logged, not stored or used

        # Note: Smile webhook returns no data, so we return the mapped fields as output
        $outputContext.Data = $actionContext.Data

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "DeleteAccount"
                Message = "Deleted account with AccountReference [$($actionContext.References.Account)] (cleaned up unique fields). Smile ID: [$deleteAccountResponse]"
                IsError = $false
            })
    }
    else {
        Write-Information "[DryRun] Would delete account with AccountReference [$($actionContext.References.Account)] (cleanup unique fields)"
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