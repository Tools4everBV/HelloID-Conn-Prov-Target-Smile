# HelloID-Conn-Prov-Target-Smile

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as webhook GUIDs. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://raw.githubusercontent.com/Tools4everBV/HelloID-Conn-Prov-Target-Smile/refs/heads/main/Logo.png">
</p>

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
    - [No validation if the user account exists](#no-validation-if-the-user-account-exists)
    - [Minimal error handling within the webhook](#minimal-error-handling-within-the-webhook)
    - [EmployeeNumber handling](#employeenumber-handling)
    - [Delete lifecycle action](#delete-lifecycle-action)
    - [Testing JSON before go-live](#testing-json-before-go-live)
  - [Development resources](#development-resources)
    - [Webhook endpoints](#webhook-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

HelloID-Conn-Prov-Target-Smile is a _target_ connector. Smile provides a webhook API that exclusively supports HTTP POST requests. Unlike conventional REST APIs with full CRUD operations, the Smile webhook automatically determines whether to create or update resources based on unique identifiers in the request body.

## Supported features

The following features are available:

| Feature                        | Supported | Actions                                    | Remarks                                    |
| ------------------------------ | --------- | ------------------------------------------ | ------------------------------------------ |
| Account Lifecycle              | ✅         | Create, Update, Enable, Disable, Delete    | See [Account Lifecycle Actions](#account-lifecycle-actions) |
| Correlation                    | ❌         | N/A                                        | Not possible (see [Remarks](#remarks))     |
| Permissions                    | ❌         | N/A                                        | Not available                              |
| Resources                      | ✅         | Create/Update                              | Departments, Titles                        |
| Entitlement Import: Accounts   | ❌         | N/A                                        | Not available (no GET endpoint)            |
| Entitlement Import: Permissions| ❌         | N/A                                        | Not available (no GET endpoint)            |

### Account Lifecycle Actions

The following lifecycle actions are available:

| Action     | Description                                                           |
| ---------- | --------------------------------------------------------------------- |
| create.ps1 | Creates or correlates an account (webhook determines action automatically) |
| update.ps1 | Updates an existing account                                           |
| enable.ps1 | Enables an account (sets Active=true, Archived=false)                |
| disable.ps1| Disables an account (sets Active=false, Archived=true)               |
| delete.ps1 | Archives an account by cleaning up unique fields (Email, Username)   |

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

The following settings are required to connect to the API.

| Setting      | Description                      | Mandatory | Example                              |
| ------------ | -------------------------------- | --------- | ------------------------------------ |
| BaseUrl      | The URL to the Smile environment | Yes       | https://example.smilesaas.eu         |
| EnvGUID      | The Environment GUID             | Yes       | 12345678-1234-1234-1234-123456789abc |
| WebhookGUID  | The Webhook GUID                 | Yes       | 12345678-1234-1234-1234-123456789abc |
| TenantGUID   | The Tenant GUID                  | Yes*      | 12345678-1234-1234-1234-123456789abc |

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

The field mapping can be imported by using the `fieldMapping_standard.json` file.

> [!NOTE]
> The provided field mapping contains a **standard set of commonly used fields** (such as EmployeeNumber, FirstName, LastName, Email, Username, Department, Title, etc.). This mapping can be extended with additional fields as needed for your implementation. Any additional fields must be configured in the Smile import template before they can be processed.

> [!NOTE]
> **EmployeeNumber is NOT mapped for Update actions.** The update script automatically adds the EmployeeNumber from the AccountReference to prevent duplicates when the source EmployeeNumber value changes. See [EmployeeNumber handling](#employeenumber-handling) for more details.

#### Fixed Value Fields

Some fields can be configured as fixed values directly in the Smile import template instead of mapping them in HelloID. This simplifies the field mapping and reduces maintenance.

Common examples:
- **Type** - Employee type (Employee, Contractor, etc.)
- **RemoteUser** - Remote user flag
- Any other field requiring a constant value

### Account Reference

The account reference is populated with the `EmployeeNumber` field value, as Smile does not return account identifiers in the webhook response.

## Remarks

### No validation if the user account exists

Because there's no HTTP.GET available to retrieve an account, the create lifecycle action will **always** create the account. If the account already exists, it will be updated instead. If the user is successfully created or updated, you will get back a random number. The connector doesn't actually handle this number since it has no meaning.

### Minimal error handling within the webhook

The webhook does not return any error information. If something fails, you will only receive a generic HTTP error code.

### EmployeeNumber handling

To prevent duplicate accounts when the EmployeeNumber changes in the source system:

1. **EmployeeNumber is NOT mapped** in the field mapping for Update, Enable, Disable, and Delete actions
2. The lifecycle scripts automatically add the EmployeeNumber from the HelloID AccountReference
3. This ensures the correct account is updated, even if the source EmployeeNumber has changed

**Consequence:** Updating the EmployeeNumber itself is not possible, as this would create a new account in Smile by design.

### Delete lifecycle action

Smile does not provide an actual delete endpoint. The delete action performs an update that:
- Cleans up unique fields (Email, Username, PhoneNumber) by setting them to empty strings
- This allows these values to be reused for other accounts
- The account remains in Smile but is marked as archived

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

The connector uses a single webhook endpoint for all operations (employee accounts, departments, and titles):

```
{BaseUrl}/api/webhook/{EnvGUID}/employee/{WebhookGUID}/{TenantGUID}
```

Where:
- **BaseUrl**: Your Smile environment URL
- **EnvGUID**: Environment GUID (identifies your Smile environment)
- **WebhookGUID**: Webhook GUID (unique identifier for the webhook)
- **TenantGUID**: Tenant GUID (only relevant for multi-tenant environments)

| Endpoint                                                               | Method | Description                    |
| ---------------------------------------------------------------------- | ------ | ------------------------------ |
| /api/webhook/{EnvGUID}/employee/{WebhookGUID}/{TenantGUID}            | POST   | Used for all operations: employee lifecycle (create, update, enable, disable, delete), department creation, and title creation. The Smile import template determines how to process the data based on the fields present in the JSON payload. |

> [!NOTE]
> All three resource types (employee, department, title) use the **same webhook endpoint**. They are stored as employee objects in Smile's organizational table (MVI) and differentiated by their **Type** field and the fields sent in the request body.

### API documentation

The Smile API documentation is not publicly available. Please contact Smile support for detailed API documentation.

## Getting help

> [!TIP]
> For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

