# OCM-W-Stack Deployment Guide

## 1. Overview
This guide provides step-by-step instructions to deploy an **end-to-end instance of OCM-W-Stack** on a Kubernetes cluster. The OCM-W-Stack enables secure, centralized credential management and integrates seamlessly with enterprise infrastructure.  

Deployment leverages **Helm charts, kubectl, and automation scripts** to ensure reproducibility, scalability, and maintainability.

---

## 2. Prerequisites

### 2.1 Infrastructure Requirements
- **Kubernetes cluster**  
  - Minimum version: `1.22+`  
  - At least 3 nodes (4 vCPU, 16 GB RAM recommended per node for production).  
  - Network policies enabled for security.  

- **Ingress Controller**  
  - NGINX ingress controller or equivalent.  
  - Configured with TLS termination.  

- **DNS**  
  - Wildcard DNS entry `*.DOMAIN` pointing to your ingress load balancer IP/hostname.  

### 2.2 Software Requirements
Ensure the following utilities are installed on the deployment host:
- `kubectl` (aligned with your cluster version)  
- `helm` (v3.10+)  
- `curl`  
- `jq`  
- `openssl`  
- `sed`

### 2.3 Security Requirements
- **TLS Certificate**: Valid **full chain certificate** (`fullchain.pem`).  
- **Private Key**: Matching key (`privkey.pem`).  
- **Storage**: Certificates should be stored securely with restricted permissions (`chmod 600`).  

### 2.4 Access Requirements
- **Kubeconfig**: Path to the cluster configuration file with admin access.  
- **Email Address**: Valid email for Let’s Encrypt notifications and system alerts.  

---

## 3. Deployment Instructions

### 3.1 Script Preparation
1. Download the deployment script (`deploy.sh`) from the OCM-W-Stack release package.  
2. Grant execution permissions:  
   ```bash
   chmod +x deploy.sh
   ```

### 3.2 Script Execution
Run the deployment script with the following parameters:

```bash
./deploy.sh NAMESPACE DOMAIN CERT_PATH KEY_PATH EMAIL KUBECONFIG
```

#### Example:
```bash
./deploy.sh ocm example.com ./certs/fullchain.pem ./certs/privkey.pem ops@example.com ~/.kube/config
```

**Arguments:**
- `NAMESPACE` → Kubernetes namespace where the stack will be deployed.  
- `DOMAIN` → Base domain (e.g., `example.com`).  
- `CERT_PATH` → Path to TLS full chain certificate.  
- `KEY_PATH` → Path to TLS private key.  
- `EMAIL` → Ops email address for alerts and notifications.  
- `KUBECONFIG` → Path to kubeconfig file.  

---

## 4. Deployment Workflow

1. **Namespace Creation**  
   Script creates or validates the specified namespace.  

2. **TLS Secret Injection**  
   TLS certificate and private key are stored as Kubernetes secrets.  

3. **Helm Chart Installation**  
   - OCM-W-Stack components are deployed via Helm.  
   - Configurations include ingress rules, service accounts, and RBAC.  

4. **Ingress Setup**  
   Wildcard ingress is configured for `*.DOMAIN`.  

5. **Verification & Health Checks**  
   - Script validates pod readiness.

---

## 5. Post-Deployment Validation

Run the following checks after deployment:

```bash
kubectl get pods -n <NAMESPACE>
kubectl get svc -n <NAMESPACE>
kubectl get ingress -n <NAMESPACE>
```

## 6. Output
If successful, deployment produces:  
- A fully functional **OCM-W-Stack instance** accessible via `https://cloud-wallet.DOMAIN`.  
- Ingress secured with the provided TLS certificate.  

---

# Paradym Integration Specifics

## Overview

The Paradym/Credo integration exposed several important details around
OID4VCI issuance and SD-JWT VC verification. The most important finding
was the relationship between the issuer signing key, the `did:web` DID
Document, and the `assertionMethod` verification relationship.

## Issuer DID

The SD-JWT VC issuer must be consistent with the DID used for issuer key
resolution.

Instead of:

``` json
{
  "iss": "https://demo-tenant2.dccuitl.de"
}
```

the working credential used:

``` json
{
  "iss": "did:web:demo-tenant2.dccuitl.de"
}
```

This allows Paradym/Credo to resolve the issuer through the DID
Document.

## JWT `kid` and Verification Method

The `kid` in the SD-JWT VC header must point to the corresponding
verification method in the DID Document.

Working header:

``` json
{
  "typ": "dc+sd-jwt",
  "alg": "ES256",
  "kid": "did:web:demo-tenant2.dccuitl.de#eckey"
}
```

The DID Document therefore needs a matching verification method:

``` json
{
  "verificationMethod": [
    {
      "id": "did:web:demo-tenant2.dccuitl.de#eckey",
      "type": "JsonWebKey2020",
      "controller": "did:web:demo-tenant2.dccuitl.de",
      "publicKeyJwk": {
        "alg": "ES256",
        "crv": "P-256",
        "kid": "eckey",
        "kty": "EC",
        "x": "...",
        "y": "..."
      }
    }
  ]
}
```

## Signing Key Consistency

The public key exposed through `publicKeyJwk` must correspond exactly to
the private key used to sign the SD-JWT VC.

For an ES256/P-256 key, the `x` and `y` coordinates published in the DID
Document must belong to the actual signing key.

A correct `kid` is not sufficient if the credential was signed using a
different private key.

## `assertionMethod` Is Required for the Paradym Integration

This was the key integration-specific finding.

Having the signing key only in `verificationMethod` was not sufficient
for Paradym/Credo. The verification method also had to be explicitly
authorized for assertions through `assertionMethod`.

``` json
{
  "assertionMethod": [
    "did:web:demo-tenant2.dccuitl.de#eckey"
  ]
}
```

The relevant DID Document therefore looks like:

``` json
{
  "@context": [
    "https://www.w3.org/ns/did/v1",
    "https://w3id.org/security/suites/jws-2020/v1"
  ],
  "id": "did:web:demo-tenant2.dccuitl.de",
  "controller": "did:web:demo-tenant2.dccuitl.de",
  "verificationMethod": [
    {
      "id": "did:web:demo-tenant2.dccuitl.de#eckey",
      "type": "JsonWebKey2020",
      "controller": "did:web:demo-tenant2.dccuitl.de",
      "publicKeyJwk": {
        "alg": "ES256",
        "crv": "P-256",
        "kid": "eckey",
        "kty": "EC",
        "x": "...",
        "y": "..."
      }
    }
  ],
  "assertionMethod": [
    "did:web:demo-tenant2.dccuitl.de#eckey"
  ]
}
```

After adding `assertionMethod`, Paradym accepted the credential.

## Holder Binding via `cnf.jwk`

Paradym creates a holder key for the credential request and includes its
public JWK in the OID4VCI proof JWT.

Example proof header:

``` json
{
  "alg": "ES256",
  "typ": "openid4vci-proof+jwt",
  "jwk": {
    "kty": "EC",
    "crv": "P-256",
    "kid": "...",
    "x": "...",
    "y": "..."
  }
}
```

The same holder key must be bound to the issued SD-JWT VC using
`cnf.jwk`:

``` json
{
  "cnf": {
    "jwk": {
      "kty": "EC",
      "crv": "P-256",
      "kid": "...",
      "x": "...",
      "y": "..."
    }
  }
}
```

The holder key in `cnf.jwk` must correspond to the key from the
credential proof. In particular, the `x` and `y` coordinates must match.

## SD-JWT VC Header

The working SD-JWT VC header was:

``` json
{
  "typ": "dc+sd-jwt",
  "alg": "ES256",
  "kid": "did:web:demo-tenant2.dccuitl.de#eckey"
}
```

## VCT

The credential type was exposed as a URL:

``` json
{
  "vct": "https://demo-tenant2.dccuitl.de/api/schema/SD_JWT_DEVELOPER_CREDENTIAL"
}
```

This URL can also be used to expose the corresponding Type Metadata.

## Status List URI

The status reference must contain a valid and consistently constructed
URL:

``` json
{
  "status": {
    "status_list": {
      "idx": 1,
      "uri": "https://demo-tenant2.dccuitl.de/api/status/2"
    }
  }
}
```

Care must be taken when constructing this URI. If the status service
already returns an absolute URL, the issuer must not append that URL to
the public origin a second time.

## Credential Response

The credential was returned using the OID4VCI credential response
structure:

``` json
{
  "credentials": [
    {
      "credential": "<SD-JWT VC>"
    }
  ]
}
```

## Successful Paradym Verification Flow

``` text
OID4VCI Credential Request
        |
        v
Proof JWT containing the holder JWK
        |
        v
Holder JWK is propagated into cnf.jwk
        |
        v
SD-JWT VC
  typ = dc+sd-jwt
  iss = did:web:demo-tenant2.dccuitl.de
  kid = did:web:demo-tenant2.dccuitl.de#eckey
        |
        v
Paradym/Credo resolves the issuer DID
        |
        v
DID Document exposes the signing key
through verificationMethod
        |
        v
assertionMethod authorizes the same key
for credential assertions
        |
        v
ES256 signature is verified using publicKeyJwk
        |
        v
Holder binding is verified using cnf.jwk
        |
        v
Credential is accepted
```

## Key Takeaway

For the Paradym/Credo integration, publishing the issuer signing key
under `verificationMethod` alone was not sufficient.

The signing key used for the SD-JWT VC also had to be explicitly
referenced by `assertionMethod`:

``` json
{
  "assertionMethod": [
    "did:web:demo-tenant2.dccuitl.de#eckey"
  ]
}
```

This was the decisive missing piece in the integration.



