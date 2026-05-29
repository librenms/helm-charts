# librenms

![Version: 8.1.0](https://img.shields.io/badge/Version-8.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.5.1](https://img.shields.io/badge/AppVersion-26.5.1-informational?style=flat-square)

LibreNMS is an autodiscovering PHP/MySQL-based network monitoring system.

## TL;DR

```shell
$ helm repo add librenms https://www.librenms.org/helm-charts
$ helm install my-release librenms/librenms
```

## Prerequisites

- This chart has only been tested on Kubernetes 1.18+, but should work on 1.14+
- Recent versions of Helm 3 are supported

## Installing the Chart

To install the chart with the release name `my-release` and default configuration:

```shell
$ helm repo add librenms https://www.librenms.org/helm-charts
$ helm install my-release librenms/librenms
```

## Database Configuration

### Internal Database (Default)

By default, the chart deploys [HelmForge MySQL](https://github.com/helmforgedev/charts/tree/main/charts/mysql) as part of the release (`mysql.enabled: true`).
No additional database configuration is needed.

The chart sets `collation-server=utf8mb4_unicode_ci` by default, which satisfies the
[LibreNMS database collation requirement](https://community.librenms.org/t/new-default-database-charset-collation/14956)
automatically on fresh installs.

### Migrating from Bitnami MySQL (chart versions < 8.0.0)

Chart v8.0.0 replaced the Bitnami MySQL subchart with [HelmForge MySQL](https://github.com/helmforgedev/charts/tree/main/charts/mysql). The two charts use **different data-directory layouts** on disk (Bitnami: `/bitnami/mysql`, HelmForge: `/var/lib/mysql`), so a **backup and restore is required** even though the PVC name (`data-RELEASE-mysql-0`) is unchanged.

> **Note:** Replace `RELEASE` and `NAMESPACE` below with your Helm release name and Kubernetes namespace.

**Step 1: Back up your database**

```bash
kubectl exec -n NAMESPACE RELEASE-mysql-0 -- mysqldump -uroot \
  -p"$(kubectl get secret RELEASE-mysql -n NAMESPACE -o jsonpath='{.data.mysql-root-password}' | base64 -d)" \
  --all-databases > backup.sql
```

**Step 2: Delete the old MySQL StatefulSet and its PVC**

```bash
kubectl delete statefulset RELEASE-mysql -n NAMESPACE --cascade=orphan
kubectl delete pod RELEASE-mysql-0 -n NAMESPACE
kubectl delete pvc data-RELEASE-mysql-0 -n NAMESPACE
```

**Step 3: Upgrade the chart**

Point LibreNMS at the old Bitnami secret during the first upgrade so it can connect while HelmForge MySQL initializes:

```yaml
mysql:
  existingAuthSecret:
    name: RELEASE-mysql        # old Bitnami secret name
    key: mysql-password        # old Bitnami secret key
```

```bash
helm upgrade RELEASE ./charts/librenms -f values.yaml
```

**Step 4: Restore the backup**

> **Note:** After upgrading, the HelmForge chart creates a new secret named `RELEASE-mysql-auth` (replacing the old Bitnami `RELEASE-mysql` secret).

```bash
kubectl cp backup.sql NAMESPACE/RELEASE-mysql-0:/tmp/backup.sql
kubectl exec -n NAMESPACE RELEASE-mysql-0 -- mysql -uroot \
  -p"$(kubectl get secret RELEASE-mysql-auth -n NAMESPACE -o jsonpath='{.data.mysql-root-password}' | base64 -d)" \
  -e "SOURCE /tmp/backup.sql;"
```

**Step 5: Once verified, remove the `existingAuthSecret` override**

After confirming everything works, remove the `mysql.existingAuthSecret` block from your values and run `helm upgrade` again. The chart will use the new HelmForge-generated secret going forward.

### External Database

To use an external MySQL or MariaDB database, disable the bundled MySQL subchart and configure `externalDatabase`:

```yaml
mysql:
  enabled: false

externalDatabase:
  host: mysql.example.com:3306      # hostname:port (port is optional, defaults to 3306)
  port: 3306                         # (optional if included in host)
  name: librenms
  user: librenms
  password: "your-password"          # or use existingSecret
  # existingSecret:
  #   name: my-db-secret             # reference to existing K8s secret
  #   key: mysql-password            # key in the secret containing the password
  timeout: 60                        # database connection timeout in seconds
```

**Note:** You can specify the port in either the `host` field (`mysql.example.com:3306`) OR the `port` field, but not both.

**Example with existing Kubernetes secret:**

```bash
# Create a secret with the database password
kubectl create secret generic db-credentials \
  --from-literal=mysql-password=your-password \
  -n default
```

Then in your values:

```yaml
mysql:
  enabled: false

externalDatabase:
  host: mysql.example.com
  name: librenms
  user: librenms
  existingSecret:
    name: db-credentials           # K8s secret name
    key: mysql-password            # key in the secret
  timeout: 60
```

**Pre-requisites for external database:**
- MySQL 8.0+ or MariaDB 10.5+
- Database user with CREATE, ALTER, DROP, INSERT, UPDATE, DELETE privileges
- Network connectivity from cluster to database host
- MySQL server configured with `character-set-server=utf8mb4` and `collation-server=utf8mb4_unicode_ci`
  (see [LibreNMS collation docs](https://community.librenms.org/t/new-default-database-charset-collation/14956))

## Persistence

RRDCached uses persistent storage for time-series database files. Two separate PersistentVolumeClaims are configured:

- **RRD Database** (`/data/db/rrd`): Stores the actual RRD files (default: `10Gi`)
- **Journal** (`/data/db/journal`): Stores write journal for durability (default: `1Gi`)

To customize the storage class or size:

```yaml
librenms:
  rrdcached:
    persistence:
      rrdcached:
        size: 10Gi
        storageClassName: "fast-ssd"
      journal:
        size: 1Gi
        storageClassName: "fast-ssd"
```

## Values
Check the [values.yaml](./values.yaml) file for the available settings for this chart and its dependencies.

### APP_KEY Handling

By default, LibreNMS auto-generates a secure Laravel APP_KEY on first install and persists it in a Kubernetes Secret. You only need to set `librenms.appkey` if you want to provide your own key (e.g., for migration or backup consistency).

Alternatively, you can reference an existing Kubernetes secret by setting `librenms.existingSecret` to the name of a secret containing the `appkey` key. This is useful for advanced scenarios or when sharing a key between releases.

To generate a custom APP_KEY:
```bash
php artisan key:generate --show
```
Set the value in your `values.yaml` as:
```yaml
librenms:
  appkey: base64:YOUR_BASE64_KEY
```
Or reference an existing secret:
```yaml
librenms:
  existingSecret: my-librenms-appkey-secret
```
If both are left blank, the chart will generate and persist a random key automatically.

### Recommendations

* `librenms.poller.replicas`: Depending on the scale of your installation, the amount of poller pods needs to be scaled up. Use the poller page in the LibreNMS interface to check for scaling issues.

### Security Context

- Main workloads: use the `privileged` flags (global `librenms.privileged` or component overrides `librenms.frontend.privileged`, `librenms.poller.privileged`).
- Init containers: optionally set `librenms.initContainer.securityContext` for stricter clusters.

Example:
```yaml
librenms:
  privileged: false     # global default
  frontend:
    privileged: false   # component override
  poller:
    privileged: false   # component override

  initContainer:
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      runAsUser: 1000
```

### Available values

The following table lists the main configurable parameters of the librenms chart v8.1.0 and their default values. Please, refer to [values.yaml](./values.yaml) for the full list of configurable parameters.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| externalDatabase | object | `{"existingSecret":{"key":"mysql-password","name":""},"host":"","name":"librenms","password":"","port":3306,"timeout":60,"user":"librenms"}` | External database configuration. Used when mysql.enabled is false. When mysql.enabled is true (default), the bundled MySQL subchart is used and these values are ignored. |
| externalDatabase.existingSecret | object | `{"key":"mysql-password","name":""}` | Where to get the DB password: Option A: reference an existing Secret (recommended for production) |
| externalDatabase.existingSecret.key | string | `"mysql-password"` | Key in the secret that contains the database password |
| externalDatabase.existingSecret.name | string | `""` | Name of the secret containing the database password |
| externalDatabase.host | string | `""` | DB host (DNS name or IP). Supports both "hostname" or "hostname:port" formats. If port is included in the host field, it takes precedence over the separate port field. Example: "mysql.example.svc.cluster.local", "10.0.0.12", or "mysql.example.com:3307" |
| externalDatabase.name | string | `"librenms"` | Database name |
| externalDatabase.password | string | `""` | Database password (plain text). Use existingSecret instead for production. |
| externalDatabase.port | int | `3306` | DB port (MySQL default 3306). Optional if port is included in the host field. |
| externalDatabase.timeout | int | `60` | Optional: DB connection timeout in seconds |
| externalDatabase.user | string | `"librenms"` | Database username |
| global.security.allowInsecureImages | bool | `true` |  |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | LibreNMS ingress configuration |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable or disable ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Ingress rules |
| librenms.appkey | string | `""` | Laravel APP_KEY for encryption. If blank, a random 32-character key will be generated and persisted in a Kubernetes Secret. You may also provide a base64-encoded key (prefix with 'base64:'). Example: appkey: "base64:QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm==" |
| librenms.configuration | string | `"$config['distributed_poller_group']          = '0';\n$config['distributed_poller']                = true;\n"` | Custom configuration options for LibreNMS. For more information on options in this file check the following link: https://docs.librenms.org/Support/Configuration/ |
| librenms.existingSecret | bool | `false` | Existing secret name to use for appkey Must have the key 'appkey' as above |
| librenms.extraEnvFrom | list | `[]` | Extra envFrom sources applied to all LibreNMS components |
| librenms.extraEnvs | list | `[]` | Extra environment variables applied to all LibreNMS components |
| librenms.frontend.extraEnvFrom | list | `[]` | Extra envFrom sources for frontend containers |
| librenms.frontend.extraEnvs | list | `[]` | Extra environment variables for frontend containers |
| librenms.frontend.extraVolumeMounts | list | `[]` | Extra volume mounts for frontend containers |
| librenms.frontend.extraVolumes | list | `[]` | Extra volumes for frontend pods |
| librenms.frontend.nodeSelector | object | `{}` | nodeSelector for frontend pods |
| librenms.frontend.podAnnotations | object | `{}` | podAnnotations for frontend pods |
| librenms.frontend.privileged | bool | `false` |  |
| librenms.frontend.readinessProbe.httpGet.path | string | `"/login"` | Check endpoint path |
| librenms.frontend.readinessProbe.httpGet.port | int | `8000` | Check endpoint port |
| librenms.frontend.readinessProbe.initialDelaySeconds | int | `30` |  |
| librenms.frontend.readinessProbe.periodSeconds | int | `60` |  |
| librenms.frontend.readinessProbe.timeoutSeconds | int | `10` |  |
| librenms.frontend.replicas | int | `1` | Frontend replicas |
| librenms.frontend.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.image.pullPolicy | string | `"Always"` | pullPolicy is the Kubernetes image pull policy for the main LibreNMS image. |
| librenms.image.repository | string | `"librenms/librenms"` | repository is the image repository to pull from. |
| librenms.image.tag | string | `"26.5.1"` | tag is image tag to pull. |
| librenms.initContainer | object | `{"image":{"pullPolicy":"Always","repository":"busybox","tag":"1.38"},"resources":{},"securityContext":{}}` | initContainer configuration options |
| librenms.initContainer.image.pullPolicy | string | `"Always"` | pullPolicy is the Kubernetes image pull policy for the init container image. |
| librenms.initContainer.image.repository | string | `"busybox"` | repository is the init container image repository to pull from. |
| librenms.initContainer.image.tag | string | `"1.38"` | tag is the init container image tag to pull. |
| librenms.initContainer.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the init container. |
| librenms.initContainer.securityContext | object | `{}` | securityContext defines the security settings for the init container. |
| librenms.poller.extraEnvFrom | list | `[]` | Extra envFrom sources for poller containers |
| librenms.poller.extraEnvs | list | `[]` | Extra environment variables for poller containers |
| librenms.poller.extraVolumeMounts | list | `[]` | Extra volume mounts for poller containers |
| librenms.poller.extraVolumes | list | `[]` | Extra volumes for poller pods |
| librenms.poller.nodeSelector | object | `{}` | nodeSelector for poller pods |
| librenms.poller.podAnnotations | object | `{}` | podAnnotations for poller pods |
| librenms.poller.privileged | bool | `false` |  |
| librenms.poller.replicas | int | `2` | Poller replicas |
| librenms.poller.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.privileged | bool | `false` |  |
| librenms.rrdcached | object | `{"envs":[{"name":"WRITE_JITTER","value":"1800"},{"name":"WRITE_TIMEOUT","value":"1800"}],"extraEnvFrom":[],"extraEnvs":[],"extraVolumeMounts":[],"extraVolumes":[],"image":{"pullPolicy":"Always","repository":"crazymax/rrdcached","tag":"1.8.0"},"livenessProbe":{"initialDelaySeconds":15,"periodSeconds":20,"tcpSocket":{"port":42217}},"nodeSelector":{},"persistence":{"enabled":true,"journal":{"size":"1Gi","storageClassName":""},"rrdcached":{"size":"10Gi","storageClassName":""}},"podAnnotations":{},"readinessProbe":{"initialDelaySeconds":5,"periodSeconds":10,"tcpSocket":{"port":42217}},"resources":{}}` | RRD cached is the tool that allows for distributed polling and is mandatory in this LibreNMS helm chart. See the rrdcached documentation for more information: https://oss.oetiker.ch/rrdtool/doc/rrdcached.en.html |
| librenms.rrdcached.envs[0] | object | `{"name":"WRITE_JITTER","value":"1800"}` | env variables RRD Cached |
| librenms.rrdcached.extraEnvFrom | list | `[]` | Extra envFrom sources for RRDCached containers |
| librenms.rrdcached.extraEnvs | list | `[]` | Extra environment variables for RRDCached containers |
| librenms.rrdcached.extraVolumeMounts | list | `[]` | Extra volume mounts for rrdcached containers |
| librenms.rrdcached.extraVolumes | list | `[]` | Extra volumes for rrdcached pods |
| librenms.rrdcached.image.pullPolicy | string | `"Always"` | pullPolicy is the Kubernetes image pull policy for the RRDCached image. |
| librenms.rrdcached.image.repository | string | `"crazymax/rrdcached"` | repository is the image repository to pull from. |
| librenms.rrdcached.image.tag | string | `"1.8.0"` | tag is image tag to pull. |
| librenms.rrdcached.livenessProbe.tcpSocket | object | `{"port":42217}` | RRD cached liveness probe |
| librenms.rrdcached.nodeSelector | object | `{}` | nodeSelector for rrdcached pods |
| librenms.rrdcached.persistence.enabled | bool | `true` | RRDCached persistent volume enabled |
| librenms.rrdcached.persistence.journal.size | string | `"1Gi"` | RRDCached journal PV size |
| librenms.rrdcached.persistence.journal.storageClassName | string | `""` | RRDCached journal storage class name |
| librenms.rrdcached.persistence.rrdcached.size | string | `"10Gi"` | RRDCached RRD storage PV size |
| librenms.rrdcached.persistence.rrdcached.storageClassName | string | `""` | RRDCached RRD storage class name |
| librenms.rrdcached.podAnnotations | object | `{}` | podAnnotations for rrdcached pods |
| librenms.rrdcached.readinessProbe.tcpSocket | object | `{"port":42217}` | RRD cached readiness probe |
| librenms.rrdcached.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.snmp_scanner | object | `{"cron":"15 * * * *","enabled":false,"extraEnvFrom":[],"extraEnvs":[],"nodeSelector":{},"podAnnotations":{},"resources":{},"securityContext":{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}}` | SNMP network discovery scanner cron job. This job is optional and only use when having snmp network discovery enabled. For this to work either set the 'nets' configuration in the custom config on in the admin interface See the following link for more information: https://docs.librenms.org/Extensions/Auto-Discovery/ |
| librenms.snmp_scanner.cron | string | `"15 * * * *"` | SNMP scanner cronjob syntax interval |
| librenms.snmp_scanner.enabled | bool | `false` | SNMP scanner enabled |
| librenms.snmp_scanner.extraEnvFrom | list | `[]` | Extra envFrom sources for SNMP scanner containers |
| librenms.snmp_scanner.extraEnvs | list | `[]` | Extra environment variables for SNMP scanner containers |
| librenms.snmp_scanner.nodeSelector | object | `{}` | nodeSelector for SNMP scanner pods |
| librenms.snmp_scanner.podAnnotations | object | `{}` | podAnnotations for SNMP scanner pods |
| librenms.snmp_scanner.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.snmp_scanner.securityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | securityContext defines the security settings for the SNMP scanner pod. These settings are required for the SNMP scanner to run properly. See: https://github.com/librenms/docker/pull/530 |
| librenms.syslogng | object | `{"enabled":false,"extraEnvFrom":[],"extraEnvs":[],"nodeSelector":{},"podAnnotations":{},"replicas":1,"resources":{}}` | syslog-ng sidecar for receiving syslog messages from network devices on port 514. Requires $config['enable_syslog'] = true; in librenms.configuration to store messages. See: https://docs.librenms.org/Extensions/Syslog/ |
| librenms.syslogng.enabled | bool | `false` | Enable syslog-ng |
| librenms.syslogng.extraEnvFrom | list | `[]` | Extra envFrom sources for syslogng containers |
| librenms.syslogng.extraEnvs | list | `[]` | Extra environment variables for syslogng containers |
| librenms.syslogng.nodeSelector | object | `{}` | nodeSelector for syslogng pods |
| librenms.syslogng.podAnnotations | object | `{}` | podAnnotations for syslogng pods |
| librenms.syslogng.replicas | int | `1` | syslogng replicas |
| librenms.syslogng.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the syslog-ng container. |
| librenms.timezone | string | `"UTC"` | Timezone used by librenms for communication with RRD cached |
| mysql | object | `{"architecture":"standalone","auth":{"database":"librenms","username":"librenms"},"config":{"myCnf":"[mysqld]\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\n"},"enabled":true,"existingAuthSecret":{},"standalone":{"persistence":{"enabled":true,"size":"8Gi"}}}` | Configuration for MySQL dependency chart by HelmForge. See their chart for more information: https://github.com/helmforgedev/charts/tree/main/charts/mysql |
| mysql.config | object | `{"myCnf":"[mysqld]\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\n"}` | Set the default collation to utf8mb4_unicode_ci, which is required by LibreNMS. MySQL 8.4 defaults to utf8mb4_0900_ai_ci, which causes validation warnings. See: https://community.librenms.org/t/new-default-database-charset-collation/14956 |
| mysql.existingAuthSecret | object | `{}` | Use an existing secret for MySQL authentication instead of the auto-generated one. This is useful when migrating from the Bitnami MySQL subchart, which created a secret named "RELEASE-mysql" with key "mysql-password". Example for Bitnami migration:   existingAuthSecret:     name: my-release-mysql     key: mysql-password |
| redis | object | `{"architecture":"standalone","auth":{"enabled":false,"sentinel":false},"enabled":true,"image":{"repository":"bitnamilegacy/redis"},"master":{"disableCommands":[]},"sentinel":{"enabled":false}}` | Configuration for redis dependency chart by Bitnami. See their chart for more information: https://github.com/bitnami/charts/tree/master/bitnami/redis |

## Uninstalling the Chart

To delete the chart:

```shell
$ helm delete my-release
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | redis | 24.0.0 |
| https://repo.helmforge.dev | mysql | ~1.8.0 |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| jacobw |  | <https://github.com/jacobw> |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
