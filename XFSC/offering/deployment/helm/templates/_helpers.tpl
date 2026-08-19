{{- define "credential-offering-bootstrap.name" -}}credential-offering-bootstrap{{- end }}
{{- define "credential-offering-bootstrap.fullname" -}}{{ printf "%s-%s" .Release.Name (include "credential-offering-bootstrap.name" .) | trunc 63 | trimSuffix "-" }}{{- end }}
