{{- define "xfsc-postgresql-cnpg.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "xfsc-postgresql-cnpg.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}
{{- .Values.openbaoInit.secretPath -}}
{{- else -}}
{{- printf "postgresql/%s" (include "xfsc-postgresql-cnpg.fullname" .) -}}
{{- end -}}
{{- end }}

{{- define "xfsc-postgresql-cnpg.superuserSecret" -}}
{{- if .Values.externalSecret.target.name -}}
{{- .Values.externalSecret.target.name -}}
{{- else -}}
{{- printf "%s-postgres-superuser" (include "xfsc-postgresql-cnpg.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}
