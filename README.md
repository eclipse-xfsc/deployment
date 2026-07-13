# Deployment

The deployment setup is orchestrated by ORCE and finally executed/operated by [argoCD Applicationsets](https://argo-cd.readthedocs.io/en/latest/user-guide/application-set/). Each applicationset deploys a layer of applications sorted by context. 

# ORCE Integration

To integrate the cluster bootstrap better in the orchestration engine, an [installer](./XFSC/orce-clusteradmin/) provides an rest api for easier usage with kubernetes clusters. The ORCE can then decide if some features of the products are installed or not. 

# Layer

## Argo CD

Contains ArgoCD and all app projects

## Observability

The network provides essential network components which are required to bootstrap the core functionality. 

|Component|Purpose|Mandatory|Install Prio|
|--|--|--|--|
|Open Telemtry|The Open Telemetry stack installs standard tools like grafana, prometheus, alertmanager, loki, jeager, tempo und promtail.  |✅ |0|

## Security

The XFSC security has the task to provide essential security components. This components must be installed first. The layer consists of the following components: 

|Component|Purpose|Mandatory|Install Prio|
|--|--|--|--|
|[Kyverno](https://kyverno.io)|Kyverno is an zero trust component which evaluates pod starts and cluster setups by policy. It's later used for evaluating f.e. correct container signings. To enable label the namespace with image-signature-policy.xsfc.io/enabled=true |❌ |0|
|[OpenBao](https://openbao.org/docs/what-is-openbao/)|Open Bao is used for all scenarios where a transit engine or other secret engines are required.|✅|1|
|[External Secret Operator](https://external-secrets.io/latest/)| Secret management of XFSC. Manages handling of cluster secrets. Can be connected to external stores but it's by default connected to openbao. |✅|2|

The installation of those components is made via helm install directly in the cluster to prepare the proper setup. 

## Application Management

After the security, the application management is installed, because it is relying on external secret operator and openbao. The namepaces must be installed over the security namespace, because the service account for openbao is requried.

|Component|Purpose|Mandatory|Install Prio|
|--|--|--|--|
|Infra App Namespace| An namespace package for infrastructure. |✅|0|
|OCM App Namespace| An namespace package for OCM. |✅|0|
|Catalogue App Namespace| An namespace package for Catalogue. |✅|0|
|OCM W-Stack App Namespace| An namespace package for OCM-Stack. |✅|0|
|TSA App Namespace| An namespace package for TSA. |✅|0|
|DCS App Namespace| An namespace package for DCS. |✅|0|
|ORCE App Namespace| An namespace package for ORCE. |✅|0|
|[Kubernetes Operator](https://github.com/eclipse-xfsc/kubernetes-operator)| 
The operator is an special xfsc operator and is installed first, to observe xfsc resources and injection requests for xfsc components. It has the task to decide, when an injection request has to be fullfilled or when a resource must be created (e.g. for databases, kyverno etc.)|✅|1|


## Storage

The storage package provides essential storage components like cassandra, postgres and redis.


## Network

The network provides essential network components which are required to bootstrap the core functionality. 

|Component|Purpose|Mandatory|Install Prio|
|--|--|--|--|
|[Cert Manager](https://cert-manager.io)|Cert Manager is used for let's encrypt certifcates. The package installs an DNS based resolver. |✅ |0|
|[Ingress](https://developer.konghq.com/kubernetes-ingress-controller/)|The ingress manages the incoming traffic for the cluster. In this case Kong Ingress is used.|✅|1|
|[Power DNS](https://github.com/PowerDNS/pdns)|Power DNS is an RFC compliant dns for usage together with cert manager|✅ |2|
|[External DNS](https://github.com/kubernetes-sigs/external-dns)|External DNS manages the connection between ingress and dns.|✅|3|

## Core

The core layer consits basic tools which are required for operating the xfsc stack. This layer is installed via argo [applicationset](XFSC/Applicationsets/values/core-values.yaml). The set contains the following:

|Component|Purpose|Mandatory|Install Prio|
|--|--|--|--|

|[Nats](https://nats.io)| Nats is used as light weight message bus to provide for the application and eventing system. |✅|3|
|[Universal Resolver](https://github.com/decentralized-identity/universal-resolver/)| The universal resolver provides for applications the capability to resolve DIDs. |✅|3|


## Tenant Management

