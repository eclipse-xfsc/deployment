# Deployment

## Local Bootstrapping

Docker compose setup can be used to bootstrap the local environment. Please use this bootstrapping [readme](https://gitlab.eclipse.org/eclipse/xfsc/organisational-credential-manager-w-stack/bdd/-/blob/main/bootstrap/README.md?ref_type=heads) used for running integration tests.
This [repository](https://gitlab.eclipse.org/eclipse/xfsc/organisational-credential-manager-w-stack/bdd) contains the docker-compose and necessary configurations to run the services locally. 

## Minikube Usage

### Security Notice

This setup is for demo purposes, so the vault is not sealed and the traffic inside the cluster not secured. Be aware of this, and dont use this setup in production.

### Reverse Proxy

If you plan to open the kube to the public, install nginx [Reverse Proxy](https://www.digitalocean.com/community/tutorials/how-to-install-nginx-on-ubuntu-20-04) 
and add config to /etc/nginx/[nginx.conf](./Reverse%20Proxy/nginx.conf) before you run the install script


### Local Minikube 

If you wanna use minikube, install minikube according to the [docu](https://minikube.sigs.k8s.io/docs/start) 

Install Helm in your /usr/local/bin.

Enable: minikube addons enable ingress

Follow step [1-3](https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/#Mac)

Install the reverse proxy if you plan

After this all helms can be install via helm install service name or by using the [install script](./install.sh)

### Remote
If you plan to setup it remote, dont forget to open your loadbalancer/vm with a public IP and set a domain on it via DNS records. After this, ensure that the kube admin api is locally mapped to the machine by using NAT rules: 

DNAT: 

```
sudo iptables -t nat -A PREROUTING -p tcp --dport 8443 -j DNAT --to-destination 192.168.49.2:8443
sudo iptables -t nat -A POSTROUTING -p tcp --dport 443 -d 192.168.49.2 -j MASQUERADE
```

if this is not working use: 

```
ptables -A FORWARD -p tcp -d 192.168.49.2 --dport 443 -j ACCEPT
``` 

Then you can open port 8443 to the public and export your kube yaml: 

```
kubectl config view --minify --flatten > kubeconfig.yaml
```

With this you can access the cluster from outside. 

Note: Ensure that the kubeconfig contains the right ip to access the service. 

## Scaling

The application can be scaled horizontally by running multiple instances of the application. The application is stateless and can be scaled horizontally. The application can be deployed on Kubernetes or any other container orchestration platform.

To configure autoscaling for a Kubernetes deployment using Helm, you typically need to:
Enable the Horizontal Pod Autoscaler (HPA) in your Helm chart.
Define the autoscaling parameters in your values.yaml file or directly in the Helm chart.

1. Define values in your values.yaml file:
```yaml
autoscaling:
    enabled: true
    minReplicas: 1
    maxReplicas: 10
    targetCPUUtilizationPercentage: 50
```

2. Create an HPA resource:

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mychart.fullname" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "mychart.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```
See the [Horizontal Pod Autoscaler documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) for more information.

## Tenant creation

Tenant isolation is managed by ingress forwarding rules. Each tenant has a `tenant_id` which is used by ocm-w-stack to identify the tenant.To register a new tenant, the following steps are required:

1. Create am ingress resource

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ template "app.name" . }}
  namespace: {{ .Release.Namespace }}
  annotations:
{{ toYaml .Values.ingress.annotations | indent 4 }}
  labels:
    {{- include "app.labels" . | nindent 4 }}
spec:
  ingressClassName: nginx
  tls:
  {{- range .Values.ingress.tls }}
    - hosts:
      {{- range .hosts }}
        - {{ . | quote }}
      {{- end }}
      secretName: {{ .secretName }}
  {{- end }}
  rules:
  {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
        {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType}}
            backend:
              service:
                name: {{ template "app.name" $ }}
                port:
                  number: {{ .port }}
        {{- end }}
  {{- end }}
{{- end }}
```

2. Define ingress config in values.yaml

```yaml
ingress:
  enabled: true
  annotations:
    nginx.org/client-max-body-size: 2K #Maximum Size of Credentials which are uploadable
    nginx.ingress.kubernetes.io/rewrite-target: /v1/tenants/example_tenant_id/example_path/$2
  hosts:
    - host: example.dev
      paths:
        - path: /api/example_path(/|$)(.*)
          port: 8080
          pathType: ImplementationSpecific

  tls:
    - secretName: example-wildcard
      hosts:
        - example.dev
```

3. Create a new secret engine in the used vault instance

```shell
vault secrets enable -path=example_tenant_id transit
```

4. Create for the tenant id a new cassandra key space for the tenant id.

# Important Considerations for the Deployment

1. Collect the infrastructure tasks, means Redis, Postgres, Cassandra, Nats, Vault and other components excepting the application services, and deploy it first in HA setup with a proper user and secret management (e.g. by using Hashicorp Vault Injection, Terraform Scripting, Ansible Playbooks, External Secret Operator etc.)
2. Limit the Infrastructure Items properly for resource management
3. Consider the right order of the application Components: 
  - Start with signer service first
  - Universal Resolver
  - sd jwt service
  - storage service
  - statuslist service
  - ...
  - ...
