
# HelloID-Conn-Prov-Target-Smile

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://ribwtest.smilesaas.eu/img/poweredbysmile.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Smile](#helloid-conn-prov-target-smile)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
    - [Endpoints](#endpoints)
    - [Remarks](#remarks)
      - [No validation if the user account exists](#no-validation-if-the-user-account-exists)
      - [Minimal error handling within the webhook](#minimal-error-handling-within-the-webhook)
      - [Field mapping values are stored within the account data](#field-mapping-values-are-stored-within-the-account-data)
      - [`SystemName` property](#systemname-property)
      - [`POST` calls only](#post-calls-only)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Smile_ is a provisioning PowerShell V2 _target_ connector. Unlike conventional APIs, _Smile_ provides a webhook that exclusively supports either a 'push' or 'HTTP.POST'.

The following resources are available:

| Action             | Description                           |
| ------------------ | ------------------------------------- |
| create.ps1         | PowerShell _create_ lifecycle action  |
| update.ps1         | PowerShell _update_ lifecycle action  |
| disable.ps1        | PowerShell _disable_ lifecycle action |
| enable.ps1         | PowerShell _enable_ lifecycle action  |
| configuration.json | Default _configuration_               |
| fieldMapping.json  | Default _fieldMapping_                |

## Getting started

#### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

### Connection settings

The following settings are required to connect to the webhook.

| Setting     | Description                           | Mandatory |
| ----------- | ------------------------------------- | --------- |
| BaseUrl     | The URL to the webhook                    | Yes       |
| EnvGUID     | The EnvGUID to connect to the webhook     | Yes       |
| WebhookGUID | The WebhookGUID to connect to the webhook | Yes       |
| TenantGUID  | The TenantGUID to connect to the webhook  | Yes       |

### Endpoints

The following endpoint is being used.

| Endpoint                                                                                            |
| --------------------------------------------------------------------------------------------------- |
| https://__{TenantName}__.smilesaas.eu/api/webhook/__{EnvGUID}__/__{WebhookGUID}__/__{TenantGUID}__  |

> [!NOTE]
> Note that the __TenantName__ is not part of the configuration.

### Remarks

#### No validation if the user account exists

Because there's no _HTTP.GET_ available to retrieve an account, the _create_ lifecycle action will __always__ create the account. If the account already exists, it will be updated instead. If the user is successfully created or updated, you will get back a random number. The connector doesn't actually handle this number since it has no meaning.

Because there's no way to validate the existence of an account within _Smile_, the correlation configuration is not necessary.

#### Minimal error handling within the webhook

The webhook does not return any error information. If something fails, you will only receive a generic HTTP error code.

#### Field mapping values are stored within the account data

Since the _Smile_ webhook does not provide an _HTTP.GET_ we are unable to retrieve the current state of the _Smile_ account. We therefore store each field mapping value within the `$PersonContext.Person.Accounts`.

The _update_ lifecycle action compares the desired account specified in the fieldMapping or `$actionContext.Data` and the currentAccount as specified in the `$PersonContext.Person.Accounts`. In case the value of one of the properties has changed, the _Smile_ account will be updated.

#### `SystemName` property

> [!WARNING]
> Changing the value of this field will result in the account always being updated.

Note that the fieldMapping contains an extra property called `SystemName`. This property is used to loop through the `$PersonContext.Person.Accounts` and filter on the _Smile_ system. The property is send to the _Smile_ webhook within the create and update actions. However, additional properties in the request body that are unknown to _Smile_ are not being handled by the WebHook.

#### `POST` calls only

One important thing to note is that the request to create or update an account is _in both cases_ an _HTTP.POST_.

## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_.

> [!TIP]
>  _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_.

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
