{{- define "git.bootstrapName" -}}
{{- printf "%s-bootstrap" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
