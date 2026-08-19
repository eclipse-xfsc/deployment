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

{{- define "xfsc-tenant-gateway.tenantId" -}}
{{- required "tenant.id is required" .Values.tenant.id -}}
{{- end }}

{{- define "xfsc-tenant-gateway.namespace" -}}
{{- required "tenant.id is required" .Values.tenant.namespace -}}
{{- end }}

{{- define "xfsc-tenant-gateway.subdomain" -}}
{{- if .Values.tenant.subdomain -}}
{{- .Values.tenant.subdomain | lower | replace "_" "-" -}}
{{- else -}}
{{- include "xfsc-tenant-gateway.tenantId" . | lower | replace "_" "-" -}}
{{- end -}}
{{- end }}

{{- define "xfsc-tenant-gateway.hostname" -}}
{{- $domain := required "tenant.domain is required" .Values.tenant.domain -}}
{{- printf "%s.%s" (include "xfsc-tenant-gateway.subdomain" .) $domain -}}
{{- end }}

{{- define "xfsc-tenant-gateway.uri" -}}
{{- $domain := required "tenant.domain is required" .Values.tenant.domain -}}
{{- printf "https://%s.%s" (include "xfsc-tenant-gateway.subdomain" .) $domain -}}
{{- end }}

{{- define "xfsc-tenant-gateway.did" -}}
{{- printf "did:web:%s" (include "xfsc-tenant-gateway.hostname" .) -}}
{{- end }}

{{- define "xfsc-tenant-gateway.tlsSecretName" -}}
{{- if .Values.certificate.secretName -}}
{{- .Values.certificate.secretName -}}
{{- else -}}
{{- printf "%s-tls" (include "xfsc-tenant-gateway.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
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

{{/*
Expand the name of the chart.
*/}}
{{- define "tenant.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "tenant.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common chart label.
*/}}
{{- define "tenant.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "tenant.labels" -}}
helm.sh/chart: {{ include "tenant.chart" . }}
{{ include "tenant.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "tenant.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tenant.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
