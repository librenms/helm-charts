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
Database host - returns the database host based on mode (without port)
*/}}
{{- define "librenms.dbHost" -}}
{{- if eq .Values.librenms.database.mode "external" -}}
{{- $host := required "librenms.database.external.host is required when database.mode is external" .Values.librenms.database.external.host -}}
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
{{- if eq .Values.librenms.database.mode "external" -}}
{{- $host := required "librenms.database.external.host is required when database.mode is external" .Values.librenms.database.external.host -}}
{{- if contains ":" $host -}}
{{- $host | splitList ":" | last -}}
{{- else -}}
{{- .Values.librenms.database.external.port | default 3306 -}}
{{- end -}}
{{- else -}}
{{- print "3306" -}}
{{- end -}}
{{- end -}}

{{/*
Database name - returns the database name based on mode
*/}}
{{- define "librenms.dbName" -}}
{{- if eq .Values.librenms.database.mode "external" -}}
{{- required "librenms.database.external.name is required when database.mode is external" .Values.librenms.database.external.name -}}
{{- else -}}
{{- .Values.mysql.auth.database -}}
{{- end -}}
{{- end -}}

{{/*
Database user - returns the database username based on mode
*/}}
{{- define "librenms.dbUser" -}}
{{- if eq .Values.librenms.database.mode "external" -}}
{{- required "librenms.database.external.user is required when database.mode is external" .Values.librenms.database.external.user -}}
{{- else -}}
{{- .Values.mysql.auth.username -}}
{{- end -}}
{{- end -}}

{{/*
Database timeout - returns the database timeout based on mode
*/}}
{{- define "librenms.dbTimeout" -}}
{{- if eq .Values.librenms.database.mode "external" -}}
{{- .Values.librenms.database.external.timeout | default 60 -}}
{{- else -}}
{{- print "60" -}}
{{- end -}}
{{- end -}}

{{/*
Database password environment variable - returns the env var definition for DB_PASSWORD
*/}}
{{- define "librenms.dbPasswordEnv" -}}
{{- if eq .Values.librenms.database.mode "external" -}}
{{- if .Values.librenms.database.external.existingSecret.name -}}
valueFrom:
  secretKeyRef:
    name: {{ .Values.librenms.database.external.existingSecret.name }}
    key: {{ .Values.librenms.database.external.existingSecret.key | default "mysql-password" }}
{{- else if .Values.librenms.database.external.password -}}
value: {{ .Values.librenms.database.external.password | quote }}
{{- else -}}
{{- fail "Either librenms.database.external.existingSecret.name or librenms.database.external.password must be set when database.mode is external" -}}
{{- end -}}
{{- else -}}
valueFrom:
  secretKeyRef:
    name: {{ .Release.Name }}-mysql
    key: mysql-password
{{- end -}}
{{- end -}}

{{/*
Validate external database configuration
*/}}
{{- define "librenms.validateExternalDB" -}}
{{- if eq .Values.librenms.database.mode "external" -}}
{{- if not .Values.librenms.database.external.host -}}
{{- fail "librenms.database.external.host is required when database.mode is external" -}}
{{- end -}}
{{- if not .Values.librenms.database.external.name -}}
{{- fail "librenms.database.external.name is required when database.mode is external" -}}
{{- end -}}
{{- if not .Values.librenms.database.external.user -}}
{{- fail "librenms.database.external.user is required when database.mode is external" -}}
{{- end -}}
{{- if and (not .Values.librenms.database.external.existingSecret.name) (not .Values.librenms.database.external.password) -}}
{{- fail "Either librenms.database.external.existingSecret.name or librenms.database.external.password must be set when database.mode is external" -}}
{{- end -}}
{{- end -}}
{{- end -}}