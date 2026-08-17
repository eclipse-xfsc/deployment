{{- define "xfsc-tenant-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "xfsc-tenant-gateway.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "xfsc-tenant-gateway.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "xfsc-tenant-gateway.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
app.kubernetes.io/name: {{ include "xfsc-tenant-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "xfsc-tenant-gateway.hostname" -}}
{{- $subdomain := required "tenant.subdomain is required" .Values.tenant.subdomain -}}
{{- $domain := required "tenant.domain is required" .Values.tenant.domain -}}
{{- printf "%s.%s" $subdomain $domain -}}
{{- end }}

{{- define "xfsc-tenant-gateway.tenantId" -}}
{{- required "tenant.id is required" .Values.tenant.id -}}
{{- end }}

{{- define "xfsc-tenant-gateway.did" -}}
{{- printf "did:web:%s" (include "xfsc-tenant-gateway.hostname" .) -}}
{{- end }}

{{- define "xfsc-tenant-gateway.openbaoServiceAccountName" -}}
{{- if .Values.openbao.serviceAccount.name -}}
{{- .Values.openbao.serviceAccount.name -}}
{{- else -}}
{{- printf "%s-openbao-bootstrap" (include "xfsc-tenant-gateway.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "xfsc-tenant-gateway.transitMountPath" -}}
{{- if .Values.openbao.transit.mountPath -}}
{{- .Values.openbao.transit.mountPath | trimSuffix "/" -}}
{{- else -}}
{{- include "xfsc-tenant-gateway.tenantId" . -}}
{{- end -}}
{{- end }}

{{- define "xfsc-tenant-gateway.tlsSecretName" -}}
{{- if .Values.certificate.secretName -}}
{{- .Values.certificate.secretName -}}
{{- else -}}
{{- printf "%s-tls" (include "xfsc-tenant-gateway.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}
