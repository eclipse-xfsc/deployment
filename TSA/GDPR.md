# GDPR Compliance Document
The objective of this document is to detail, the data being stored and proccessed by the Trust Service API.

# Issuing Verifiable Credential 

## What information is stored
### Source User Information (Private)
The Open Id connect claims MAY contain all sorts of personal data (like email, name, age and others), typically received from an external source.

### Technical User Information (Public)

- Schema information (public)
- Credential/credential definition ids and states
- DID of issuer
- DID of holder
- Created/updated dates
- Offered credential attributes and attachments

## How is the information stored and used
### Source User Information
Source User Information is encrypted using the Private Key of the organizational deployment, thereby creating the Verifiable Credential. This Verifiable Credential is shared with the legitimate recipient. Subsequently Source User Information(including the Verifiable Credential), is permanently erased from organizational deployment. 

### Technical User Information (Public)
Technical User Information is used to send the Verifiable credential to legitimate recipient. After successful issuance of the Verifiable Credential, per default Technical User information is permenetly erased from organizational deployment.


## Who can access the information
The Source User Information and Technical User Information both are accessible only by the system administrators of the organizational deployment.

## How long will the information stay 
### Source User Information
The Source User Information is wiped out once the Verifiable Credential is issued.

### Technical User Information (Public)
The Technical User Information is wiped out per default after Vereifiable Credential is isssued or optionally stored according to retention periods (not defined yet).

# Receiving Verifiable Credential 

## What information is stored
### Source User Information (Private)
The Open Id connect claims MAY contain all sorts of personal data (like email, name, age and others), typically received from an external source.

### Technical User Information (Public)

- Schema information (public)
- Credential/credential definition ids and states
- DID of issuer
- DID of holder
- Created/updated dates
- Offered credential attributes and attachments

## How is the information stored and used
### Source User Information
Source User Information is decrypted. Per default received Verifiable Credential is not stored permanently. In case this is changed within a specific organizational deployment, an amendment of this GDPR Compliance Document will be necessary. This is the due to the fact that these details depend on the specific use cases and intentions.


### Technical User Information (Public)
Technical User Information is used to received the Verifiable credential from legitimate sender. After successful acceptance of the Verifiable Credential, per default Technical User information is permanently erased from the organizational deployment.

## Who can access the information
The Source User Information and Technical User Information both are accessible only by the system administrators of the organizational deployment.

## How long will the information stay 
### Source User Information
The Source User Information is wiped out per default once the Verifiable Credential is received.

### Technical User Information (Public)
The Technical User Information is wiped out per default after Vereifiable Credential is received or stored according to retention periods (not defined yet).
