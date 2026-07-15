{{- define "redis.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "redis.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}
{{- .Values.openbaoInit.secretPath -}}
{{- else -}}
{{- printf "redis/%s" (include "redis.fullname" .) -}}
{{- end -}}
{{- end }}

{{- define "redis.authSecret" -}}
{{- if .Values.externalSecret.target.name -}}
{{- .Values.externalSecret.target.name -}}
{{- else -}}
{{- printf "%s-root-auth" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}
