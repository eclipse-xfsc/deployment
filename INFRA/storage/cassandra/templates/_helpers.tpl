{{- define "xfsc-cassandra.secretPath" -}}
{{- if .Values.openbaoInit.kv.path -}}
{{- .Values.openbaoInit.kv.path -}}
{{- else -}}
{{- printf "cassandra/%s" .Release.Name -}}
{{- end -}}
{{- end }}

{{- define "xfsc-cassandra.host" -}}
{{- if .Values.cassandraRole.host -}}
{{- .Values.cassandraRole.host -}}
{{- else -}}
{{- printf "%s-cassandra" .Release.Name -}}
{{- end -}}
{{- end }}
