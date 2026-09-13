{{- define "redis.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "redis.secretPath" -}}
{{- if .Values.openbaoInit.secretPath -}}
{{- .Values.openbaoInit.secretPath -}}
{{- else -}}
{{- printf "redis/%s" (include "redis.fullname" .) -}}
{{- end -}}
{{- end }}

{{- define "redis.authSecret" -}}
{{- if .Values.externalSecret.target.name -}}
{{- .Values.externalSecret.target.name -}}
{{- else -}}
{{- printf "%s-root-auth" (include "redis.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "redis.clusterHosts" -}}
{{- $root := . -}}
{{- $hosts := list -}}
{{- range $i := until (int $root.Values.redis.cluster.nodes) -}}
{{- $host := printf "%s-leader-%d.%s-leader-headless.%s.svc.cluster.local:%d"
    (include "redis.fullname" $root)
    $i
    (include "redis.fullname" $root)
    $root.Release.Namespace
    (int $root.Values.redis.port) -}}
{{- $hosts = append $hosts $host -}}
{{- end -}}
{{- join "," $hosts -}}
{{- end -}}
