#################################################
# HelloID-Conn-Prov-Target-Smile-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        $outputContext.Success = $true
        $outputContext.AccountReference = "Currently not available"
        Write-Information "[DryRun] Create Smile account for: [$($personContext.Person.DisplayName)], will be executed during enforcement"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        Write-Information 'Creating and correlating Smile account'

        $body = $actionContext.Data | ConvertTo-Json
        $splatRestParams = @{
            Uri     = "$($actionContext.configuration.BaseUrl)/api/webhook/$($actionContext.configuration.EnvGUID)/employee/$($actionContext.configuration.WebhookGUID)/$($actionContext.configuration.TenantGUID)"
            Headers = @{
                'Content-Type' = 'application/json;charset=utf-8'
            }
            Body   = ([System.Text.Encoding]::UTF8.GetBytes($body))
            Method = 'POST'
        }
        $null = Invoke-WebRequest @splatRestParams -Verbose:$false
        $outputContext.success = $true
        $outputContext.Data = $actionContext.Data
        $outputContext.AccountReference = $actionContext.Data.Nummer
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Action  = 'CreateAccount'
                Message = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)"
                IsError = $false
            })
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    $auditMessage = "Could not create or correlate Smile account. Error: $($ex.Exception.Message)"
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
