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
Create the name of the pollers
*/}}
{{- define "librenms.poller.name" -}}
{{- if .Values.librenms.poller.name -}}
{{- .Values.librenms.poller.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{ .Release.Name }}-poller
{{- end -}}
{{- end -}}

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
Database host - returns the database host based on mode (without port)
*/}}
{{- define "librenms.dbHost" -}}
{{- if not .Values.mysql.enabled -}}
{{- $host := required "externalDatabase.host is required when mysql.enabled is false" .Values.externalDatabase.host -}}
{{- if contains ":" $host -}}
{{- $host | splitList ":" | first -}}
{{- else -}}
{{- $host -}}
{{- end -}}
{{- else -}}
{{- printf "%s-mysql" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
Database port - returns the database port based on mode
Extracts port from host string if present (host:port), otherwise uses explicit port field
*/}}
{{- define "librenms.dbPort" -}}
{{- if not .Values.mysql.enabled -}}
{{- $host := required "externalDatabase.host is required when mysql.enabled is false" .Values.externalDatabase.host -}}
{{- if contains ":" $host -}}
{{- $host | splitList ":" | last -}}
{{- else -}}
{{- .Values.externalDatabase.port | default 3306 -}}
{{- end -}}
{{- else -}}
{{- print "3306" -}}
{{- end -}}
{{- end -}}

{{/*
Database name - returns the database name based on mode
*/}}
{{- define "librenms.dbName" -}}
{{- if not .Values.mysql.enabled -}}
{{- required "externalDatabase.name is required when mysql.enabled is false" .Values.externalDatabase.name -}}
{{- else -}}
{{- .Values.mysql.auth.database -}}
{{- end -}}
{{- end -}}

{{/*
Database user - returns the database username based on mode
*/}}
{{- define "librenms.dbUser" -}}
{{- if not .Values.mysql.enabled -}}
{{- required "externalDatabase.user is required when mysql.enabled is false" .Values.externalDatabase.user -}}
{{- else -}}
{{- .Values.mysql.auth.username -}}
{{- end -}}
{{- end -}}

{{/*
Database timeout - returns the database timeout based on mode
*/}}
{{- define "librenms.dbTimeout" -}}
{{- if not .Values.mysql.enabled -}}
{{- .Values.externalDatabase.timeout | default 60 -}}
{{- else -}}
{{- print "60" -}}
{{- end -}}
{{- end -}}

{{/*
Database password environment variable - returns the env var definition for DB_PASSWORD
*/}}
{{- define "librenms.dbPasswordEnv" -}}
{{- if not .Values.mysql.enabled -}}
{{- if .Values.externalDatabase.existingSecret.name -}}
valueFrom:
  secretKeyRef:
    name: {{ .Values.externalDatabase.existingSecret.name }}
    key: {{ .Values.externalDatabase.existingSecret.key | default "mysql-password" }}
{{- else if .Values.externalDatabase.password -}}
value: {{ .Values.externalDatabase.password | quote }}
{{- else -}}
{{- fail "Either externalDatabase.existingSecret.name or externalDatabase.password must be set when mysql.enabled is false" -}}
{{- end -}}
{{- else -}}
{{- if and .Values.mysql.existingAuthSecret .Values.mysql.existingAuthSecret.name -}}
valueFrom:
  secretKeyRef:
    name: {{ .Values.mysql.existingAuthSecret.name }}
    key: {{ .Values.mysql.existingAuthSecret.key | default "mysql-user-password" }}
{{- else -}}
valueFrom:
  secretKeyRef:
    name: {{ .Release.Name }}-mysql-auth
    key: mysql-user-password
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Redis is in use when either the bundled subchart is enabled or an external host
is configured. Without one, LibreNMS falls back to the file cache/session driver.
*/}}
{{- define "librenms.redisEnabled" -}}
{{- if or .Values.redis.enabled .Values.externalRedis.host -}}
true
{{- end -}}
{{- end -}}

{{/*
Redis host - bundled subchart service or the configured external host
*/}}
{{- define "librenms.redisHost" -}}
{{- if .Values.redis.enabled -}}
{{- printf "%s-redis-client" .Release.Name -}}
{{- else -}}
{{- .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/*
Redis port
*/}}
{{- define "librenms.redisPort" -}}
{{- if .Values.redis.enabled -}}
{{- print "6379" -}}
{{- else -}}
{{- .Values.externalRedis.port | default 6379 -}}
{{- end -}}
{{- end -}}

{{/*
Redis database number
*/}}
{{- define "librenms.redisDb" -}}
{{- if .Values.redis.enabled -}}
{{- print "0" -}}
{{- else -}}
{{- .Values.externalRedis.db | default 0 -}}
{{- end -}}
{{- end -}}
