# librenms

![Version: 6.1.0](https://img.shields.io/badge/Version-6.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 25.11.0](https://img.shields.io/badge/AppVersion-25.11.0-informational?style=flat-square)

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

The following table lists the main configurable parameters of the librenms chart v6.1.0 and their default values. Please, refer to [values.yaml](./values.yaml) for the full list of configurable parameters.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.security.allowInsecureImages | bool | `true` |  |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | LibreNMS ingress configuration |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable or disable ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Ingress ingress rules |
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
| librenms.image.tag | string | `"25.11.0"` | tag is image tag to pull. |
| librenms.initContainer | object | `{"image":{"pullPolicy":"Always","repository":"busybox","tag":"1.37"},"resources":{},"securityContext":{}}` | initContainer configuration options |
| librenms.initContainer.image.pullPolicy | string | `"Always"` | pullPolicy is the Kubernetes image pull policy for the init container image. |
| librenms.initContainer.image.repository | string | `"busybox"` | repository is the init container image repository to pull from. |
| librenms.initContainer.image.tag | string | `"1.37"` | tag is the init container image tag to pull. |
| librenms.initContainer.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the init container. |
| librenms.initContainer.securityContext | object | `{}` | securityContext defines the security settings for the init container. |
| librenms.poller.extraEnvFrom | list | `[]` | Extra envFrom sources for poller containers |
| librenms.poller.extraEnvs | list | `[]` | Extra environment variables for poller containers |
| librenms.poller.extraVolumeMounts | list | `[]` | Extra volume mounts for poller containers |
| librenms.poller.extraVolumes | list | `[]` | Extra volumes for poller pods |
| librenms.poller.nodeSelector | object | `{}` | nodeSelector for poller pods |
| librenms.poller.privileged | bool | `false` |  |
| librenms.poller.replicas | int | `2` | Poller replicas |
| librenms.poller.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.privileged | bool | `false` |  |
| librenms.rrdcached | object | `{"envs":[{"name":"WRITE_JITTER","value":"1800"},{"name":"WRITE_TIMEOUT","value":"1800"}],"extraEnvFrom":[],"extraEnvs":[],"extraVolumeMounts":[],"extraVolumes":[],"image":{"pullPolicy":"Always","repository":"crazymax/rrdcached","tag":"1.8.0"},"livenessProbe":{"initialDelaySeconds":15,"periodSeconds":20,"tcpSocket":{"port":42217}},"nodeSelector":{},"persistence":{"enabled":true,"journal":{"size":"1Gi","storageClassName":""},"rrdcached":{"size":"10Gi","storageClassName":""}},"readinessProbe":{"initialDelaySeconds":5,"periodSeconds":10,"tcpSocket":{"port":42217}},"resources":{}}` | RRD cached is the tool that allows for distributed polling and is mandatory in this LibreNMS helm chart. See the rrdcached documentation for more information: https://oss.oetiker.ch/rrdtool/doc/rrdcached.en.html |
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
| librenms.rrdcached.readinessProbe.tcpSocket | object | `{"port":42217}` | RRD cached readiness probe |
| librenms.rrdcached.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.snmp_scanner | object | `{"cron":"15 * * * *","enabled":false,"extraEnvFrom":[],"extraEnvs":[],"nodeSelector":{},"resources":{},"securityContext":{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}}` | SNMP network discovery scanner cron job. This job is optional and only use when having snmp network discovery enabled. For this to work either set the 'nets' configuration in the custom config on in the admin interface See the following link for more information: https://docs.librenms.org/Extensions/Auto-Discovery/ |
| librenms.snmp_scanner.cron | string | `"15 * * * *"` | SNMP scanner cronjob syntax interval |
| librenms.snmp_scanner.enabled | bool | `false` | SNMP scanner enabled |
| librenms.snmp_scanner.extraEnvFrom | list | `[]` | Extra envFrom sources for SNMP scanner containers |
| librenms.snmp_scanner.extraEnvs | list | `[]` | Extra environment variables for SNMP scanner containers |
| librenms.snmp_scanner.nodeSelector | object | `{}` | nodeSelector for SNMP scanner pods |
| librenms.snmp_scanner.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.snmp_scanner.securityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | securityContext defines the security settings for the SNMP scanner pod. These settings are required for the SNMP scanner to run properly. See: https://github.com/librenms/docker/pull/530 |
| librenms.timezone | string | `"UTC"` | Timezone used by librenms for communication with RRD cached |
| mysql | object | `{"auth":{"database":"librenms","username":"librenms"},"enabled":true,"image":{"repository":"bitnamilegacy/mysql"}}` | Configuration for MySQL dependency chart by Bitnami. See their chart for more information: https://github.com/bitnami/charts/tree/master/bitnami/mysql |
| redis | object | `{"architecture":"standalone","auth":{"enabled":false,"sentinel":false},"enabled":true,"image":{"repository":"bitnamilegacy/redis"},"master":{"disableCommands":[]},"sentinel":{"enabled":false}}` | Configuration for redis dependency chart by Bitnami. See their chart for more information: https://github.com/bitnami/charts/tree/master/bitnami/redis |

## Uninstalling the Chart

To delete the chart:

```shell
$ helm delete my-release
```

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | mysql | ~14.0.0 |
| https://charts.bitnami.com/bitnami | redis | 24.0.0 |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| jacobw |  | <https://github.com/jacobw> |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
