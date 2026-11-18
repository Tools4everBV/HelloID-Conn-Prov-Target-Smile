########################################################################
# HelloID-Conn-Prov-Target-Smile-Create
# PowerShell V2
# Note: See the README (Remarks) for how the Smile webhook works and its limitations.
# - Create always creates the account OR updates the existing one (no correlation)
# - AccountReference comes from $actionContext.Data.EmployeeNumber
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
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Process
    $actionMessage = "creating account with EmployeeNumber [$($actionContext.Data.EmployeeNumber)] and Username [$($actionContext.Data.Username)]"

    $createAccountBody = $actionContext.Data

    $tenantPath = if ([string]::IsNullOrEmpty($actionContext.configuration.TenantGUID)) { '' } else { "/$($actionContext.configuration.TenantGUID)" } # TenantGUID is optional
    $createAccountSplatParams = @{
        Uri         = "$($actionContext.configuration.BaseUrl)/api/webhook/$($actionContext.configuration.EnvGUID)/employee/$($actionContext.configuration.WebhookGUID)$tenantPath"
        Method      = 'POST'
        Headers     = @{
            'Content-Type' = 'application/json;charset=utf-8'
        }
        Body        = ([System.Text.Encoding]::UTF8.GetBytes(($createAccountBody | ConvertTo-Json -Depth 10)))
        ContentType = "application/json;charset=utf-8"
        Verbose     = $false
        ErrorAction = "Stop"
    }

    if (-Not($actionContext.DryRun -eq $true)) {
        [void](Invoke-RestMethod @createAccountSplatParams)

        # Note: Smile webhook returns no data, so we return the mapped fields as output and use the mapped field EmployeeNumber as AccountReference
        $outputContext.Data = $actionContext.Data
        $outputContext.AccountReference = $actionContext.Data.EmployeeNumber

        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = "CreateAccount" # Optional
                Message = "Created account with EmployeeNumber [$($actionContext.Data.EmployeeNumber)] and Username [$($actionContext.Data.Username)]. AccountReference is: [$($outputContext.AccountReference)]"
                IsError = $false
            })
    }
    else {
        Write-Information "[DryRun] Would create account with with EmployeeNumber [$($actionContext.Data.EmployeeNumber)] and Username [$($actionContext.Data.Username)]"
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