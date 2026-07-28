{{- define "xfsc-nats.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "xfsc-nats.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}
{{- .Values.openbaoInit.secretPath -}}
{{- else -}}
{{- printf "xfsc-nats/%s" (include "xfsc-nats.fullname" .) -}}
{{- end -}}
{{- end }}

{{- define "xfsc-nats.authSecret" -}}
{{- if .Values.externalSecret.target.name -}}
{{- .Values.externalSecret.target.name -}}
{{- else -}}
{{- printf "%s-root-auth" (include "xfsc-nats.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}
