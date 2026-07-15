{{- define "cass.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- define "cass.headless" -}}
{{- printf "%s-headless" (include "cass.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}
{{- define "cass.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}{{ .Values.openbaoInit.secretPath }}{{- else -}}{{ printf "cassandra/%s" (include "cass.fullname" .) }}{{- end -}}
{{- end }}
{{- define "cass.authSecret" -}}
{{- if .Values.externalSecret.target.name -}}{{ .Values.externalSecret.target.name }}{{- else -}}{{ printf "%s-root-auth" (include "cass.fullname" .) }}{{- end -}}
{{- end }}
{{- define "cass.seed" -}}
{{- printf "%s-0.%s.%s.svc.cluster.local" (include "cass.fullname" .) (include "cass.headless" .) .Release.Namespace -}}
{{- end }}
