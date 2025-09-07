{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "app.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" $name .Release.Namespace | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create instance name based on app version and short image sha.
*/}}
{{- define "app.revision" -}}
{{- default .Release.Name .Values.appRel | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Istio labels
*/}}
{{- define "app.istioLabels" -}}
{{- if ((.Values.istio).injection).pod -}}
sidecar.istio.io/inject: "true"
{{- else if eq (((.Values.istio).injection).pod) false -}}
sidecar.istio.io/inject: "false"
{{- end -}}
{{- end -}}
{{/*

Selector labels
*/}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/component: {{ include "app.fullname" . }}
{{- end -}}

{{/*
Metrics Annotations
*/}}
{{- define "app.metricsAnnotations" -}}
{{- if .Values.metrics.enabled -}}
prometheus.io/scrape: "true"
prometheus.io/port: "{{ .Values.metrics.port }}"
prometheus.io/path: {{ .Values.metrics.path | default "/metrics" | quote }}
{{- end -}}
{{- end -}}

{{/*
Image string
*/}}
{{- define "app.image" -}}
{{- if .Values.image.sha -}}
{{ .Values.image.repository }}/{{ .Values.image.name }}@{{ .Values.image.sha }}
{{- else -}}
{{ .Values.image.repository }}/{{ .Values.image.name }}:{{ default .Chart.AppVersion .Values.image.tag }}
{{- end -}}
{{- end -}}

{{/*
Security context
*/}}
{{- define "app.securitycontext" -}}
runAsNonRoot: {{ .Values.security.runAsNonRoot | default false }}
runAsGroup: {{ .Values.security.runAsGid | default 0 }}
runAsUser: {{ .Values.security.runAsUid | default 0 }}
fsGroup: {{ .Values.security.runAsGid | default 0 }}
{{- end -}}

{{/*
PostgreSQL Connection  string URI
*/}}
{{- define "app.postgresql.connectionstring" -}}
postgresql://{{ .Values.connectionManager.database.user }}:{{ .Values.connectionManager.database.password }}@{{ .Values.connectionManager.database.host }}:{{ .Values.connectionManager.database.port }}/{{ .Release.Namespace }}_{{ include "app.name" . | replace "-" "_" }}?schema={{ .Values.connectionManager.database.schema }}
{{- end -}}

