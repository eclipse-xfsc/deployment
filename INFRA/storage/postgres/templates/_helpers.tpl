{{- define "xfsc-postgresql.secretPath" -}}
{{- if .Values.openbaoInit.kv.path -}}
{{- .Values.openbaoInit.kv.path -}}
{{- else -}}
{{- printf "postgresql/%s" .Release.Name -}}
{{- end -}}
{{- end }}
