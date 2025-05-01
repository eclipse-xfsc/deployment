
# OCM API flows


## Create a connection with a PCM

-> under connection-manager

1. Create an invitation url


POST
{{baseUrl}}/v1/invitation-url?alias=trust

- in the response copy
       e.g. -> "invitationUrl": "https://example.com:443/ocm/didcomm?c_i=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wL2ludml0YXRpb24iLCJAaWQiOiI0ZDA2N2FlMi1kNTQ5LTRlYzQtYmU2OC00MzFmMzdkMjJlODUiLCJsYWJlbCI6InNzaS1hYnN0cmFjdGlvbi1hZ2VudCIsInJlY2lwaWVudEtleXMiOlsiNVl6U21xcjY5d0RFSzVvQWpzZFQ3UktjazJuaHdmS0phVVVneUVESEFuNWQiXSwic2VydmljZUVuZHBvaW50IjoiaHR0cHM6Ly9nYWlheC52ZXJlaWduLmNvbTo0NDMvb2NtL2RpZGNvbW0iLCJyb3V0aW5nS2V5cyI6W119",
	or "invitationUrlShort"

2. Convert the invitation URL to a QR code and scan with the PCM

## Create a connection with another OCM

-> under connection-manager

1. Create an invitation url


POST
{{baseUrl}}/v1/invitation-url?alias=trust

- in the response copy
       e.g. -> "invitationUrl": "https://example.com:443/ocm/didcomm?c_i=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wL2ludml0YXRpb24iLCJAaWQiOiI0ZDA2N2FlMi1kNTQ5LTRlYzQtYmU2OC00MzFmMzdkMjJlODUiLCJsYWJlbCI6InNzaS1hYnN0cmFjdGlvbi1hZ2VudCIsInJlY2lwaWVudEtleXMiOlsiNVl6U21xcjY5d0RFSzVvQWpzZFQ3UktjazJuaHdmS0phVVVneUVESEFuNWQiXSwic2VydmljZUVuZHBvaW50IjoiaHR0cHM6Ly9nYWlheC52ZXJlaWduLmNvbTo0NDMvb2NtL2RpZGNvbW0iLCJyb3V0aW5nS2V5cyI6W119",


2. Accept connection on the other OCM

POST
{{baseUrl}}/v1/accept-connection-invitation

body: 
{
  "invitationUrl": "https://example.com:443/ocm-provider/didcomm?c_i=eyJAdHlwZSI6Imh0dHBzOi8vZGlkY29tbS5vcmcvY29ubmVjdGlvbnMvMS4wL2ludml0YXRpb24iLCJAaWQiOiJhNzE1OGFkZS1iMjBkLTQwYmQtODliNy1jM2RhMjg1NWU0ZDAiLCJsYWJlbCI6IkdYRlMtSW50ZWdyYXRpb24iLCJyZWNpcGllbnRLZXlzIjpbIkNYYlViTTNEeEJ3SzNWTFptaXBWOEtDYmQyVmVXM1NDa3BOb01qblRSb1JiIl0sInNlcnZpY2VFbmRwb2ludCI6Imh0dHBzOi8vaW50ZWdyYXRpb24uZ3hmcy5kZXY6NDQzL29jbS1wcm92aWRlci9kaWRjb21tIiwicm91dGluZ0tleXMiOltdfQ",
  "autoAcceptConnection": true
}



## Issue a credential to an already established connection

-> under attestation-manager

1. create a schema (optional in case the desired schema already exists on the ledger)

POST
{{baseUrl}}/v1/schemas

body: 
**make sure to create a unique name for it and choose whatever, however many attributes you want**
```
{
  "name": "BasicCredential-oct-3-2022",
  "createdBy": "asdasdasd",
  "version": "1.0.0",
  "attributes": [
    "firstName",
    "lastName"
  ]
}
```

2. Create credential definition

POST
{{baseUrl}}/v1/credentialDef


body: 
**make sure to use the schemaID from the previous response and create a unique name here as well**
```
{
  "schemaID": "the schema id from the response of 1.",
  "name": "BasicCredential-oct-3-2022-credDef.1.0.2",
  "isRevokable": false,
  "isAutoIssue": false,
  "expiryHours": "23",
  "createdBy": "asdasdasfas"
}
```

3. Offer a credential

POST
{{baseUrl}}/v1/create-offer-credential

body:
**make sure to use here the connection id from ## Create a connection 2. response and the credential definition id from the previous response**
**make sure the names of the attributes here match the names of the attributes in the schema**
```
{
  "connectionId": "12926da1-916f-46d3-8f44-56df4d79c2c3",
  "credentialDefinitionId": "7KuDTpQh3GJ7Gp6kErpWvM:3:CL:520446:BasicCredential-oct-3-2022-credDef.1.0.2",
  "comment": "Issueacredential.1.0",
  "attributes": [
    {
      "name": "firstName",
      "value": "Jon"
    },
    {
      "name": "lastName",
      "value": "Doe"
    }
  ],
  "autoAcceptCredential": "always"
}
```


## Accept a credential (OCM - OCM) 

**on the PCM, it is part of the GUI**

**on the OCM, the procedure is the following:**

-> under attestation-manager

1. Get all credentials and find the one of interest (unaccepted credential will be in **state: offer-received**)

POST
{{baseUrl}}/v1/credential

response example:
```
{
    "statusCode": 200,
    "message": "Credential fetch successfully",
    "data": {
        "count": 2,
        "records": [
            {
                "id": "6a6ee15d-a68b-46af-ac9b-e07bc544dc3b",
                "credentialId": "624a76fd-f8f7-4f92-b4f8-d7497ce70a04",
                "credDefId": "8y8oycXjnQCRT2t3mRuzbP:3:CL:37720:LegalInformation-1.0.2",
                "threadId": "9f95a52a-1387-40c7-a4b0-96d9d8d0b63b",
                "state": "done",
                "principalDid": "KGaeQVaF3FzjWTU6bJJ21Y",
                "connectionId": "12cd39de-d792-410a-8db2-39140cfc3579",
                "createdDate": "2023-02-22T13:28:58.149Z",
                "updatedDate": "2023-02-22T13:34:48.467Z",
                "expirationDate": null
            },
            {
                "id": "de74fafe-7a35-45c2-b872-2ea07ae0d952",
                "credentialId": "5623fceb-3d40-4d99-a230-c142c646d5fe",
                "credDefId": "8y8oycXjnQCRT2t3mRuzbP:3:CL:37720:LegalInformation-1.0.2",
                "threadId": "fa5aab2c-4ecb-4b69-bc00-8b83de3444a1",
                "state": "offer-received",
                "principalDid": "KGaeQVaF3FzjWTU6bJJ21Y",
                "connectionId": "12cd39de-d792-410a-8db2-39140cfc3579",
                "createdDate": "2023-02-23T07:09:34.143Z",
                "updatedDate": "2023-02-23T07:09:34.143Z",
                "expirationDate": null
            }
        ]
    }
}
```


2.  accept credential offer

POST
{{baseUrl}}/v1/accept-offer?credentialID={{copy-the-credentialId-from-the-previous-response}}







## To send a proof request to someone in order to present claims for a custom issued credential

-> under proof manager

POST
/v1/send-presentation-request

**the connection id can be found in a connection record**
**the credential definition id can be found on attestation-manager -> GET {{baseUrl}}/v1/credentialDef**

body:
```
{
    "comment": "Proof Presenation",
    "attributes": [
        {
            "schemaId": "",
            "credentialDefId": "7KuDTpQh3GJ7Gp6kErpWvM:3:CL:520446:BasicCredential-oct-3-2022-credDef.1.0.2",
            "attributeName": "lastName",
            "value": "",
            "condition": ""
        }
    ],
    "connectionId": "a4c01f34-c292-4e8a-b59a-2036d31e4988"
}
```






## Accept a proof request

**on the PCM it is done through the GUI**
**on the OCM follow this procedure:**

1. Find the desired proof request id

GET
{{baseUrl}}/v1/agent-proofs

The proof request will be in **state: request-received**


2. Accept the proof request

POST
{{baseUrl}}/v1/accept-proof-request?proofRecordId={{proofId}}


Response example:
```
{
    "statusCode": 200,
    "message": "Request accepted successfully",
    "data": {
        "_tags": {
            "threadId": "6b5c57b3-137f-4f52-87f5-bd086596503c",
            "state": "request-received",
            "connectionId": "653b8cdc-d919-4b65-b399-7bf17ce36ffc"
        },
        "metadata": {},
        "id": "19c5269f-c3e5-4369-b8d0-87fe22accc9a",
        "createdAt": "2023-03-10T10:56:07.498Z",
        "requestMessage": {
            "@type": "https://didcomm.org/present-proof/1.0/request-presentation",
            "@id": "6b5c57b3-137f-4f52-87f5-bd086596503c",
            "comment": "Proof Presenation",
            "request_presentations~attach": [
                {
                    "@id": "libindy-request-presentation-0",
                    "mime-type": "application/json",
                    "data": {
                        "base64": "eyJuYW1lIjoiUHJvb2YgUmVxdWVzdCIsInZlcnNpb24iOiJQcm9vZiBSZXF1ZXN0Iiwibm9uY2UiOiI5MTAwMDg3="
                    }
                }
            ]
        },
        "state": "presentation-sent",
        "connectionId": "653b8cdc-d919-4b65-b399-7bf17ce36ffc",
        "threadId": "6b5c57b3-137f-4f52-87f5-bd086596503c",
        "presentationMessage": {
            "@type": "https://didcomm.org/present-proof/1.0/presentation",
            "@id": "c1089096-b834-4fe8-a51d-f3472b1b1dcd",
            "presentations~attach": [
                {
                    "@id": "libindy-presentation-0",
                    "mime-type": "application/json",
                    "data": {
                        "base64": "eyJwcm9vZiI6eyJwcm9vZnMiOlt7InByaW1hcnlfcHJvb2YiOnsiZXFfcHJvb2YiOnsicmV2ZWFsZWRfYXR0cnMiOnsicHJjZmlyc3RuYW1lIjoiNjgyMTE2NTZCI6bnVsbCwidGltZXN0YW1wIjpudWxsfV19"
                    }
                }
            ],
            "~thread": {
                "thid": "6b5c57b3-137f-4f52-87f5-bd086596503c"
            }
        }
    }
}
```




















## Credential types can be used for automatically requesting proof on a specific credential during login when OCM and TSA are integrated with AA Services
**with the following type: principalMemberCredential**

By default, there will be no credential type on the OCM. An existing schema on the chosen ledger can be linked, or a new schema can be created and linked to this credential type.


## In order to create a credential type:

-> under attestation manager

POST 
{{baseUrl}}/v1/credentialType

body:
```
{
    "type": "principalMemberCredential",
    "schemaId": "7KuDTpQh3GJ7Gp6kErpWvM:2:test_profileCredential-220722:1.0"
}
```


## In order to update schema type for credential type:

-> under attestation manager

PATCH 
/v1/updateSchemaIdByType?type={credentialType}

Example: /v1/updateSchemaIdByType?type=principalMemberCredential

body:
```
{
    "schemaId": "7KuDTpQh3GJ7Gp6kErpWvM:2:test_principalMemberCredential-060722:1.0"
}
```









## To check interactions with an existing connection

GET
{{baseUrl}}/v1/connection-information?connectionId={{the-connectionId-you-are-looking-for}}

example response:
```
{
    "statusCode": 200,
    "message": "Connection information fetch successfully",
    "data": {
        "records": {
            "issueCredentials": [
                {
                    "id": "6a6ee15d-a68b-46af-ac9b-e07bc544dc3b",
                    "credentialId": "624a76fd-f8f7-4f92-b4f8-d7497ce70a04",
                    "credDefId": "8y8oycXjnQCRT2t3mRuzbP:3:CL:37720:LegalInformation-1.0.2",
                    "threadId": "9f95a52a-1387-40c7-a4b0-96d9d8d0b63b",
                    "state": "done",
                    "principalDid": "KGaeQVaF3FzjWTU6bJJ21Y",
                    "connectionId": "12cd39de-d792-410a-8db2-39140cfc3579",
                    "createdDate": "2023-02-22T13:28:58.149Z",
                    "updatedDate": "2023-02-22T13:34:48.467Z",
                    "expirationDate": null
                },
                {
                    "id": "de74fafe-7a35-45c2-b872-2ea07ae0d952",
                    "credentialId": "5623fceb-3d40-4d99-a230-c142c646d5fe",
                    "credDefId": "8y8oycXjnQCRT2t3mRuzbP:3:CL:37720:LegalInformation-1.0.2",
                    "threadId": "fa5aab2c-4ecb-4b69-bc00-8b83de3444a1",
                    "state": "offer-received",
                    "principalDid": "KGaeQVaF3FzjWTU6bJJ21Y",
                    "connectionId": "12cd39de-d792-410a-8db2-39140cfc3579",
                    "createdDate": "2023-02-23T07:09:34.143Z",
                    "updatedDate": "2023-02-23T07:09:34.143Z",
                    "expirationDate": null
                }
            ],
            "presentProofs": []
        }
    }
}
```



