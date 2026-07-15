{{- define "cass.fullname" -}}
{{- if .Values.fullnameOverride -}}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{- else -}}{{ .Release.Name | trunc 63 | trimSuffix "-" }}{{- end -}}
{{- end }}
{{- define "cass.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}{{ .Values.openbaoInit.secretPath }}{{- else -}}{{ printf "cassandra/%s" (include "cass.fullname" .) }}{{- end -}}
{{- end }}
{{- define "cass.superuserSecret" -}}
{{- if .Values.externalSecret.target.name -}}{{ .Values.externalSecret.target.name }}{{- else -}}{{ printf "%s-superuser" (include "cass.fullname" .) }}{{- end -}}
{{- end }}
