{{- define "librenms.configChecksum" -}}
{{- include (print $.Template.BasePath "/librenms-configmap.yml") . | sha256sum -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "librenms.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "librenms.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "librenms.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "librenms.labels" -}}
helm.sh/chart: {{ include "librenms.chart" . }}
{{ include "librenms.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "librenms.selectorLabels" -}}
app.kubernetes.io/name: {{ include "librenms.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "librenms.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "librenms.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "librenms.secretName" -}}
{{- if .Values.librenms.existingSecret -}}
{{- .Values.librenms.existingSecret -}}
{{- else -}}
{{- .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Get the MySQL host
*/}}
{{- define "librenms.mysqlHost" -}}
{{- if .Values.mysql.enabled -}}
{{ .Release.Name }}-mysql
{{- else -}}
{{ .Values.mysql.external.host }}
{{- end -}}
{{- end -}}

{{/*
Get the MySQL secret
*/}}
{{- define "librenms.mysqlSecret" -}}
{{- if .Values.mysql.enabled -}}
{{ .Release.Name }}-mysql
{{- else -}}
{{ .Values.mysql.external.existingSecret }}
{{- end -}}
{{- end -}}

{{/*
Get the MySQL secret key
*/}}
{{- define "librenms.mysqlSecretKey" -}}
{{- if .Values.mysql.enabled -}}
mysql-password
{{- else -}}
{{ .Values.mysql.external.existingSecretKey }}
{{- end -}}
{{- end -}}

{{/*
Get the MySQL port
*/}}
{{- define "librenms.mysqlPort" -}}
{{- if .Values.mysql.enabled -}}
3306
{{- else -}}
{{ .Values.mysql.external.port }}
{{- end -}}
{{- end -}}

{{/*
Get the Redis host
*/}}
{{- define "librenms.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{ .Release.Name }}-redis-master
{{- else -}}
{{ .Values.redis.external.host }}
{{- end -}}
{{- end -}}

{{/*
Get the Redis port
*/}}
{{- define "librenms.redisPort" -}}
{{- if .Values.redis.enabled -}}
6379
{{- else -}}
{{ .Values.redis.external.port }}
{{- end -}}
{{- end -}}
