{{- define "app-namespace.targetNamespace" -}}
{{- required "targetNamespace.name is required" .Values.targetNamespace.name -}}
{{- end -}}

{{- define "app-namespace.resourceProvisionerServiceAccount" -}}
{{- required "openbao.resourceProvisioner.serviceAccount.name is required" .Values.openbao.resourceProvisioner.serviceAccount.name -}}
{{- end -}}

{{- define "app-namespace.storeReaderServiceAccount" -}}
{{- required "openbao.storeReader.serviceAccount.name is required" .Values.openbao.storeReader.serviceAccount.name -}}
{{- end -}}

{{- define "app-namespace.resourceProvisionerPolicy" -}}
{{- default (printf "xfsc-%s-resource-provisioner" (include "app-namespace.targetNamespace" .)) .Values.openbao.resourceProvisioner.policyName | trunc 128 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-namespace.resourceProvisionerRole" -}}
{{- default (printf "xfsc-%s-resource-provisioner" (include "app-namespace.targetNamespace" .)) .Values.openbao.resourceProvisioner.roleName | trunc 128 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-namespace.storeReaderPolicy" -}}
{{- default (printf "xfsc-%s-store-reader" (include "app-namespace.targetNamespace" .)) .Values.openbao.storeReader.policyName | trunc 128 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-namespace.storeReaderRole" -}}
{{- default (printf "xfsc-%s-store-reader" (include "app-namespace.targetNamespace" .)) .Values.openbao.storeReader.roleName | trunc 128 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-namespace.clusterSecretStoreName" -}}
{{- default (printf "%s-openbao" (include "app-namespace.targetNamespace" .)) .Values.clusterSecretStore.name | trunc 253 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-namespace.secretStoreName" -}}
{{- default "openbao" .Values.secretStore.name | trunc 253 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-namespace.resourceProvisionerTokenRole" -}}
{{- if .Values.openbao.resourceProvisioner.serviceToken.roleName -}}
{{- .Values.openbao.resourceProvisioner.serviceToken.roleName -}}
{{- else -}}
{{- printf "xfsc-%s-resource-token" (include "app-namespace.targetNamespace" .) | trunc 128 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "app-namespace.resourceProvisionerTokenDisplayName" -}}
{{- if .Values.openbao.resourceProvisioner.serviceToken.displayName -}}
{{- .Values.openbao.resourceProvisioner.serviceToken.displayName -}}
{{- else -}}
{{- printf "xfsc-%s-resource-token" (include "app-namespace.targetNamespace" .) | trunc 128 | trimSuffix "-" -}}
{{- end -}}
{{- end }}
