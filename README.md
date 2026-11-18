# HelloID-Conn-Prov-Target-Smile

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as webhook GUIDs. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Smile/refs/heads/main/Logo.png">
</p>

> [!WARNING]
> The Smile webhook only accepts POST requests and returns no data. Keep the following in mind:
>
> - Nothing can be read back: no correlation and no import, see [No HTTP.GET available](#no-httpget-available)
> - Errors are generic, so verify the result in Smile, see [The webhook returns no error details](#the-webhook-returns-no-error-details)
> - EmployeeNumber is the identifier and is mapped for Create only, see [EmployeeNumber handling](#employeenumber-handling)
> - Delete only empties Email and Username, see [Delete behavior](#delete-behavior)
>
> Read the [Remarks](#remarks) carefully and test in the Smile acceptance environment first.

## Table of contents

- [HelloID-Conn-Prov-Target-Smile](#helloid-conn-prov-target-smile)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
    - [Account Lifecycle Actions](#account-lifecycle-actions)
  - [Getting started](#getting-started)
    - [HelloID Icon URL](#helloid-icon-url)
    - [Requirements](#requirements)
    - [Setup in Smile](#setup-in-smile)
    - [Connection settings](#connection-settings)
    - [Correlation configuration](#correlation-configuration)
    - [Field mapping](#field-mapping)
      - [Fixed Value Fields](#fixed-value-fields)
    - [Account Reference](#account-reference)
  - [Remarks](#remarks)
    - [No HTTP.GET available](#no-httpget-available)
    - [The webhook returns no error details](#the-webhook-returns-no-error-details)
    - [Create behavior](#create-behavior)
    - [Update behavior](#update-behavior)
    - [Enable and disable behavior](#enable-and-disable-behavior)
    - [Departments and titles are not checked or maintained](#departments-and-titles-are-not-checked-or-maintained)
    - [EmployeeNumber handling](#employeenumber-handling)
    - [Delete behavior](#delete-behavior)
    - [Testing JSON before go-live](#testing-json-before-go-live)
  - [Development resources](#development-resources)
    - [Webhook endpoints](#webhook-endpoints)
    - [API documentation](#api-documentation)
    - [Script conventions](#script-conventions)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

HelloID-Conn-Prov-Target-Smile is a _target_ connector. Smile provides a webhook API that exclusively supports HTTP POST requests. Unlike conventional REST APIs with full CRUD operations, the Smile webhook automatically determines whether to create or update resources based on unique identifiers in the request body. There is no OAuth or token authentication: the GUIDs in the webhook URL act as the key, so treat them as secrets.

## Supported features

The following features are available:

✅ = implemented, ✅⚠️ = implemented with limitations, ❌ = not implemented. See the [Remarks](#remarks).

| Feature                        | Supported | Actions                                    | Remarks                                    |
| ------------------------------ | --------- | ------------------------------------------ | ------------------------------------------ |
| Account Lifecycle              | ✅⚠️       | Create, Update, Enable, Disable, Delete    | No delete endpoint, see [Account Lifecycle Actions](#account-lifecycle-actions) |
| Correlation                    | ❌         | N/A                                        | Not possible (see [Remarks](#remarks))     |
| Permissions                    | ❌         | N/A                                        | Not available                              |
| Resources                      | ✅⚠️       | Create/Update                              | Departments, Titles. Only created, not maintained, see [Remarks](#departments-and-titles-are-not-checked-or-maintained) |
| Entitlement Import: Accounts   | ❌         | N/A                                        | Not available (no GET endpoint)            |
| Entitlement Import: Permissions| ❌         | N/A                                        | Not available (no GET endpoint)            |

### Account Lifecycle Actions

The following lifecycle actions are available:

| Action     | Description                                                           |
| ---------- | --------------------------------------------------------------------- |
| create.ps1 | Creates or correlates an account (webhook determines action automatically) |
| update.ps1 | Updates an existing account                                           |
| enable.ps1 | Enables an account (sets Active=true)                                |
| disable.ps1| Disables an account (sets Active=false)                              |
| delete.ps1 | Cleans up the unique fields (Email, Username) of an account          |

## Getting started

### HelloID Icon URL

The logo can be used in HelloID to represent this connector.

```
https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Smile/refs/heads/main/Logo.png
```

### Requirements

- Access to the Smile webhook API
- The following GUIDs provided by Smile:
  - Environment GUID (EnvGUID)
  - Webhook GUID (WebhookGUID)
  - Tenant GUID (TenantGUID)
- Configured import templates in Smile (see [Setup in Smile](#setup-in-smile))

> [!IMPORTANT]
> The import templates and webhook configuration must be set up in Smile before the connector can function. Depending on your organization's Smile knowledge and permissions, this can be done by:
> - Your internal Smile administrator (if they have the required access and expertise)
> - Smile support (by submitting a configuration request)
> 
> Coordinate with your Smile contact to determine the best approach for your implementation.

### Setup in Smile

Before configuring the connector in HelloID, the following steps must be completed in Smile:

1. **Determine who will configure Smile:**
   - If your organization has a Smile administrator with the required knowledge and access, they can configure the import templates and webhook
   - Otherwise, contact Smile support to request configuration assistance

2. **Review and prepare JSON structure:**
   - Example JSON payloads are available in the `assets/` folder of this repository (employees, departments, titles)
   - These examples can be used as-is to configure the Smile import template, or modified to match your specific requirements
   - If you modify the structure, ensure that HelloID has access to all the data fields you want to include
   - Share the JSON structure with whoever will configure the import templates in Smile

3. **Configure import templates in Smile:**
   - Import templates must be created for: employees (required), departments (optional), and titles (optional)
   - The templates define field mappings and import lookups for link fields
   - Use the manual import function (import.action) in Smile to test and validate the templates with your JSON examples

4. **Create and activate the webhook:**
   - The webhook must be created in Smile and linked to the import templates
   - You will receive the webhook URL containing the EnvGUID and WebhookGUID
   - These GUIDs are used to configure the connection in HelloID

### Connection settings

The connector builds the webhook URL from the settings below:

```
{BaseUrl}/api/webhook/{EnvGUID}/employee/{WebhookGUID}/{TenantGUID}
```

| Setting      | Description                      | Mandatory | Where to find it                                                  |
| ------------ | -------------------------------- | --------- | ----------------------------------------------------------------- |
| BaseUrl      | The URL to the Smile environment | Yes       | Start of the webhook URL, without path (e.g. https://example.kader-platform.nl) |
| EnvGUID      | The Environment GUID             | Yes       | Part of the URL between `/api/webhook/` and `/employee/`          |
| WebhookGUID  | The Webhook GUID                 | Yes       | API key of the Employee (Medewerker) webhook in Smile            |
| TenantGUID   | The Tenant GUID                  | No*      | Last part of the employee webhook URL, after the WebhookGUID      |
| DepartmentWebhookGUID | The Department webhook GUID | No   | API key of the Department (Afdeling) webhook, only for resource creation |
| TitleWebhookGUID | The Title webhook GUID       | No        | API key of the Title (Functie) webhook, only for resource creation |

> [!NOTE]
> The account lifecycle only uses the Employee webhook. Department and title resource creation each use their own webhook key; leave them empty when resource creation is not used. When one webhook is used for everything, enter the WebhookGUID value in both.

> [!NOTE]
> *TenantGUID is only relevant for multi-tenant Smile environments. For single-tenant implementations, this GUID is included in the URL pattern but may not be actively used for authentication.

### Correlation configuration

Correlation is **not possible** in this connector because:
- Smile does not provide a GET endpoint to retrieve existing accounts
- There is no way to validate account existence before creating
- The create action automatically creates OR updates based on unique identifiers (EmployeeNumber)

The correlation configuration should be left disabled.

> [!TIP]
> For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages.

### Field mapping

The field mapping can be imported by using the `fieldMapping.json` file.

> [!NOTE]
> The provided field mapping contains a **standard set of commonly used fields** (such as EmployeeNumber, FirstName, LastName, Email, Username, Department, Title, etc.). This mapping can be extended with additional fields as needed for your implementation. Any additional fields must be configured in the Smile import template before they can be processed.

> [!NOTE]
> **EmployeeNumber is NOT mapped for Update actions.** The update script automatically adds the EmployeeNumber from the AccountReference to prevent duplicates when the source EmployeeNumber value changes. See [EmployeeNumber handling](#employeenumber-handling) for more details.

> [!NOTE]
> **Department and Title:** `Department` and `Title` contain the department and title codes as used in Smile (mapped from `Department.ExternalId` and `Title.ExternalId`). Customer-specific changes to the mapping are made during the implementation, not in this connector.

#### Fixed Value Fields

Some fields can be configured as fixed values directly in the Smile import template instead of mapping them in HelloID. This simplifies the field mapping and reduces maintenance.

Common examples:
- **Type** - Employee type (Employee, Contractor, etc.)
- **RemoteUser** - Remote user flag
- Any other field requiring a constant value

### Account Reference

The account reference is populated with the `EmployeeNumber` field value, as Smile does not return account identifiers in the webhook response.

## Remarks

### No HTTP.GET available

The webhook only accepts POST requests, so an account cannot be retrieved. The create action therefore always sends the account: if it already exists, Smile updates it instead. Smile returns a random number that has no meaning and is not used by the connector. As a result, correlation, account and permission import and reconciliation are not possible.

### The webhook returns no error details

If something fails, you only receive a generic HTTP error code. A success in HelloID only means Smile accepted the request, not that the data was processed as expected, so verify the result in Smile during testing.

### Create behavior

Create sends all fields mapped for Create. Smile creates the account, or updates it when the EmployeeNumber already exists. `Active` is sent as `false` for Create, so the account becomes active through the Enable action. The AccountReference is the EmployeeNumber, because Smile returns no identifier.

### Update behavior

Update sends the fields mapped for Update, plus the EmployeeNumber from the AccountReference. `Active` is not sent, so Update is not expected to change the active state; verify this during testing.

### Enable and disable behavior

Enable and disable only send `Active` (`true` or `false`) plus the EmployeeNumber from the AccountReference. Other fields are not sent, so Smile must accept a partial body for an existing account; verify this during testing. Disable leaves Email and Username filled until Delete.

### Departments and titles are not checked or maintained

Departments and titles are sent as plain codes; the connector does not check if they exist or are active in Smile. Resource creation can create them, but does not update, deactivate or clean them up. Expired departments and titles must be maintained in Smile. When Smile maintains them itself, resource creation is not needed.

### EmployeeNumber handling

To prevent duplicate accounts when the EmployeeNumber changes in the source system:

1. **EmployeeNumber is NOT mapped** in the field mapping for Update, Enable, Disable, and Delete actions
2. The lifecycle scripts automatically add the EmployeeNumber from the HelloID AccountReference
3. This ensures the correct account is updated, even if the source EmployeeNumber has changed

As a result, the EmployeeNumber itself cannot be updated: a changed value would create a new account in Smile.

> [!WARNING]
> Map EmployeeNumber for **Create only**. If it is also mapped for Update, the script still sends the AccountReference value, which is then stored as account data. A changed source value then differs from the stored value on every run, causing endless updates.

### Delete behavior

Smile has no delete endpoint. The delete action is an update that sets the unique fields Email and Username to empty strings, so these values can be reused for other accounts. The account itself remains in Smile. If the account is granted again later, the create action fills Email and Username again.

### Testing JSON before go-live

Before activating the webhook, you can test your JSON structure using the manual import function in Smile:
1. Navigate to the import section in Smile (import.action)
2. Upload your JSON file manually
3. Smile will validate the structure and show which fields it recognizes
4. Preview what will be created or updated
5. Make adjustments to your JSON or import template as needed

This helps ensure the import template is correctly configured before the webhook goes live.

## Development resources

### Webhook endpoints

All webhooks use the same URL pattern; only the webhook key differs per webhook (employee, department, title):

```
{BaseUrl}/api/webhook/{EnvGUID}/employee/{WebhookGUID}/{TenantGUID}
```

Where:
- **BaseUrl**: Your Smile environment URL
- **EnvGUID**: Environment GUID (identifies your Smile environment)
- **WebhookGUID**: Webhook key (`WebhookGUID` for employees, `DepartmentWebhookGUID` for departments, `TitleWebhookGUID` for titles)
- **TenantGUID**: Tenant GUID (only relevant for multi-tenant environments)

| Endpoint                                                               | Method | Description                    |
| ---------------------------------------------------------------------- | ------ | ------------------------------ |
| /api/webhook/{EnvGUID}/employee/{WebhookGUID}/{TenantGUID}            | POST   | Employee lifecycle (create, update, enable, disable, delete) with `WebhookGUID`; department creation with `DepartmentWebhookGUID`; title creation with `TitleWebhookGUID`. The Smile import template determines how to process the data based on the fields present in the JSON payload. |

> [!NOTE]
> Departments and titles are stored as employee objects in Smile's organizational table (MVI) and differentiated by their **Type** field and the fields sent in the request body. Confirm with Smile that the URL of the department and title webhook also uses the `employee` path.

### API documentation

The Smile API documentation is not publicly available. Please contact Smile support for detailed API documentation.

### Script conventions

- Every action posts the mapped fields as JSON to the webhook with `Invoke-RestMethod`; the response is not used, as Smile returns no data
- Errors are resolved by `Resolve-SmileError`, which returns the raw error because the webhook gives no error details
- Enable, disable and delete add the EmployeeNumber from the AccountReference to the body, see [EmployeeNumber handling](#employeenumber-handling)
- DryRun only logs what would be sent

## Getting help

> [!TIP]
> For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

