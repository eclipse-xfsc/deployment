{{/*
Expand the chart name.
*/}}
{{- define "universal-resolver.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end }}

{{/*
Create the full name.
*/}}
{{- define "universal-resolver.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "universal-resolver.name" . | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{/*
Service name.
*/}}
{{- define "universal-resolver.serviceName" -}}
{{- printf "%s" (include "universal-resolver.fullname" .) -}}
{{- end }}