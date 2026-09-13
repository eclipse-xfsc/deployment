{{- define "bind.name" -}}{{ .Values.bind9.name | trunc 63 | trimSuffix "-" }}{{- end }}
{{- define "bind.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}{{ .Values.openbaoInit.secretPath }}{{- else -}}{{ printf "bind/%s" (include "bind.name" .) }}{{- end -}}
{{- end }}
{{- define "bind.configSecret" -}}
{{- if .Values.externalSecret.target.name -}}{{ .Values.externalSecret.target.name }}{{- else -}}{{ .Values.tenant.tenant.configuration.name }}{{- end -}}
{{- end }}
