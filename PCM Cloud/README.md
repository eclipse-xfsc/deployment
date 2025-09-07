# PCMcloud Deployment Guide

## 1. Overview
This guide provides step-by-step instructions to deploy an **end-to-end instance of PCMcloud** on a Kubernetes cluster.  
PCMcloud provides a cloud-native platform for credential management, service orchestration, and secure Web-UI access.  

Deployment leverages **Helm charts, kubectl, and automation scripts** to ensure reproducibility, scalability, and maintainability.

---

## 2. Prerequisites

*PCMCloud should be in the same cluster as the OCM-W-Stack as PCMCloud sits on top of OCM-W-Stack. The namespaces however, should be different.*

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
- `docker` (for building and pushing the Web-UI image)

### 2.3 Security Requirements
- **TLS Certificate**: Valid **full chain certificate** (`fullchain.pem`).  
- **Private Key**: Matching key (`privkey.pem`).  
- **Storage**: Certificates should be stored securely with restricted permissions (`chmod 600`).  

### 2.4 Access Requirements
- **Kubeconfig**: Path to the cluster configuration file with admin access.  
- **Container Registry**: Credentials for Docker Hub (or equivalent).  
- **Ingress Credentials**: Username and password for Web-UI basic auth.  

---

## 3. Deployment Instructions

### 3.1 Script Preparation
1. Download the deployment script (`deploy.sh`) from the PCMcloud release package.  
2. Grant execution permissions:  
   ```bash
   chmod +x deploy.sh
   ```

### 3.2 Script Execution
Run the deployment script with the following parameters:

```bash
./deploy.sh PCMNAMESPACE OCMNAMESPACE DOMAIN CERTIFICATEPATH KEYPATH KUBECONFIG REGISTRYREPO REGISTRYUSERNAME REGISTRYPASS WUIINGRESSUSER WUIINGRESSPASS
```

#### Example:
```bash
./deploy.sh pcm ocm example.com ./certs/fullchain.pem ./certs/privkey.pem ~/.kube/config myrepo myuser mypass admin adminpass
```

**Arguments:**
- `PCMNAMESPACE` → Namespace for PCMcloud deployment.  
- `OCMNAMESPACE` → Namespace where OCM components (Postgres, Keycloak) already exist.  
- `DOMAIN` → Base domain (e.g., `example.com`).  
- `CERTIFICATEPATH` → Path to TLS full chain certificate.  
- `KEYPATH` → Path to TLS private key.  
- `KUBECONFIG` → Path to kubeconfig file.  
- `REGISTRYREPO` → Container registry repository.  
- `REGISTRYUSERNAME` → Registry username.  
- `REGISTRYPASS` → Registry password.  
- `WUIINGRESSUSER` → Username for Web-UI ingress basic authentication.  
- `WUIINGRESSPASS` → Password for Web-UI ingress basic authentication.  

---

## 4. Deployment Workflow

1. **Namespace & TLS Setup**  
   Creates the target namespace and injects TLS secrets.  

2. **Helm Resource Reowning**  
   Ensures Helm takes ownership of pre-existing resources.  

3. **Configuration Service Deployment**  
   Installs the Configuration Service with domain substitution.  

4. **Kong Gateway Deployment**  
   Deploys Kong ingress controller and configures ingress class ownership.  

5. **Plugin Discovery Service**  
   Deploys the Plugin Discovery Service with namespace references.  

6. **Database Integration**  
   - Retrieves Postgres credentials from OCM namespace.  
   - Creates secrets in PCM namespace.  
   - Runs migrations to provision the `accounts` schema.  

7. **Account Service Deployment**  
   Deploys Account Service, referencing OCM Postgres and Keycloak.  

8. **Keycloak Credential Sharing**  
   Copies Keycloak secrets from OCM namespace to PCM namespace.  

9. **Web-UI Deployment**  
   - Builds and pushes a custom Docker Web-UI image.  
   - Creates registry and basic-auth secrets.  
   - Installs Web-UI via Helm.  

10. **Keycloak Web-UI Client Setup**  
    Configures a Keycloak client for Web-UI OIDC integration.  

---

## 5. Post-Deployment Validation

Run the following checks after deployment:

```bash
kubectl get pods -n <PCMNAMESPACE>
kubectl get svc -n <PCMNAMESPACE>
kubectl get ingress -n <PCMNAMESPACE>
```

---

## 6. Output
If successful, deployment produces:  
- A fully functional **PCMcloud instance** accessible at `https://cloud-wallet.DOMAIN`.  
- Ingress secured with the provided TLS certificate.  
- Web-UI protected with basic authentication and integrated with Keycloak.  

---
