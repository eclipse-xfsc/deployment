{{- define "xfsc-redis-openbao.secretPath" -}}
{{- if .Values.openbaoInit.kv.path -}}
{{- .Values.openbaoInit.kv.path -}}
{{- else -}}
{{- printf "redis/%s" .Release.Name -}}
{{- end -}}
{{- end }}

{{- define "xfsc-redis-openbao.redisHost" -}}
{{- if .Values.redisAcl.host -}}
{{- .Values.redisAcl.host -}}
{{- else -}}
{{- printf "%s-redis-master" .Release.Name -}}
{{- end -}}
{{- end }}
