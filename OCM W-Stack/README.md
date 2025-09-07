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
