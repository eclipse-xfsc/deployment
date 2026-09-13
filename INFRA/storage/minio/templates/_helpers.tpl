{{- define "minio.name" -}}{{ .Values.tenant.tenant.name | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "minio.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}{{ .Values.openbaoInit.secretPath }}{{- else -}}{{ printf "minio/%s" (include "minio.name" .) }}{{- end -}}
{{- end }}
{{- define "minio.configSecret" -}}
{{- if .Values.externalSecret.target.name -}}{{ .Values.externalSecret.target.name }}{{- else -}}{{ .Values.tenant.tenant.configuration.name }}{{- end -}}
{{- end }}
