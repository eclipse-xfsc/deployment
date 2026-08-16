{{- define "xfsc-tenant-gateway.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "xfsc-tenant-gateway.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "xfsc-tenant-gateway.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "xfsc-tenant-gateway.labels" -}}
app.kubernetes.io/name: {{ include "xfsc-tenant-gateway.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "xfsc-tenant-gateway.tlsSecretName" -}}
{{- default (printf "%s-tls" (include "xfsc-tenant-gateway.fullname" .)) .Values.certificate.secretName | trunc 253 | trimSuffix "-" -}}
{{- end -}}
