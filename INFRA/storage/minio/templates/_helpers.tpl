{{- define "xfsc-minio.secretPath" -}}
{{- if .Values.openbaoInit.kv.path -}}
{{- .Values.openbaoInit.kv.path -}}
{{- else -}}
{{- printf "minio/%s" .Release.Name -}}
{{- end -}}
{{- end }}

{{- define "xfsc-minio.host" -}}
{{- if .Values.minioUser.host -}}
{{- .Values.minioUser.host -}}
{{- else -}}
{{- printf "%s-minio" .Release.Name -}}
{{- end -}}
{{- end }}
