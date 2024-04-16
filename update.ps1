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

    Write-Information "Retrieving internally stored properties of Smile account for [$($personContext.Person.DisplayName)]"
    foreach ($accountKey in $personContext.Person.Accounts.PSObject.Properties.Name) {
        $account = $personContext.Person.Accounts.$accountKey
        if ($account.SystemName -and $account.SystemName -eq $actionContext.Data.SystemName) {
            $correlatedAccount = $account
            break
        }
    }

    # Always compare the account against the current account in target system
    $desiredAccount = [PSCustomObject]$actionContext.Data
    if ($null -ne $correlatedAccount) {
        $splatCompareProperties = @{
            ReferenceObject  = @($correlatedAccount.PSObject.Properties)
            DifferenceObject = @($desiredAccount.PSObject.Properties)
        }
        $propertiesChanged = Compare-Object @splatCompareProperties -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
        if ($propertiesChanged) {
            $action = 'UpdateAccount'
            $dryRunMessage = "Account property(s) required to update: $($propertiesChanged.Name -join ', ')"
        } else {
            $action = 'NoChanges'
            $dryRunMessage = 'No changes will be made to the account during enforcement'
        }
    } else {
        $action = 'NotFound'
        $dryRunMessage = "Previous Smile account values for: [$($personContext.person.DisplayName)] could not be found in person.accounts."
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'UpdateAccount' {
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
                        Action  = 'CreateAccount'
           s             Message = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)"
                        IsError = $false
                    })
                break
            }

            'NoChanges' {
                Write-Information "No changes to Smile account with accountReference: [$($actionContext.References.Account)]"
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = 'No changes will be made to the account during enforcement'
                    IsError = $false
                })
                break
            }

            'NotFound' {
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
                $outputContext.PreviousData = $correlatedAccount
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Previous Smile account values for: [$($personContext.person.DisplayName)] could not be found in person.accounts. Falling back to updating all properties"
                    IsError = $true
                })
                break
            }
        }
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
