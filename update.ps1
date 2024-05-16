#################################################
# HelloID-Conn-Prov-Target-Smile-Update
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

try {
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        Write-Information "Updating Smile account with accountReference: [$($actionContext.References.Account)]"

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
        $outputContext.AuditLogs.Add([PSCustomObject]@{
                Message = "Update account was successful."
                IsError = $false
            })
    }
} catch {
    $outputContext.Success  = $false
    $ex = $PSItem
    $auditMessage = "Could not update Smile account. Error: $($ex.Exception.Message)"
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
