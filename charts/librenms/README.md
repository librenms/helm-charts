# librenms

![Version: 10.0.0](https://img.shields.io/badge/Version-10.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 26.8.1](https://img.shields.io/badge/AppVersion-26.8.1-informational?style=flat-square)

LibreNMS is an autodiscovering PHP/MySQL-based network monitoring system.

## TL;DR

```shell
$ helm repo add librenms https://www.librenms.org/helm-charts
$ helm install my-release librenms/librenms
```

## Prerequisites

- Kubernetes 1.26 or newer. The chart declares this as `kubeVersion`, so Helm refuses to
  install on older clusters.
- Recent versions of Helm 3 are supported

## Installing the Chart

To install the chart with the release name `my-release` and default configuration:

```shell
$ helm repo add librenms https://www.librenms.org/helm-charts
$ helm install my-release librenms/librenms
```

## Upgrading to 10.0.0

10.0.0 corrects the chart's labels. `app.kubernetes.io/name` now holds the chart name and
`app.kubernetes.io/instance` the release name, and the component moves to
`app.kubernetes.io/component`.

`spec.selector` is immutable on Deployments and StatefulSets, so `helm upgrade` fails with
`field is immutable`. Delete the workloads first, then upgrade. Releases before 10.0.0 put
no labels on the workload objects themselves, so they have to be named:

```shell
$ kubectl delete deployment -n NAMESPACE --ignore-not-found \
    RELEASE-frontend RELEASE-rrdcached RELEASE-syslogng RELEASE-snmptrapd
$ kubectl delete statefulset -n NAMESPACE --ignore-not-found RELEASE-poller
$ helm upgrade RELEASE librenms/librenms -n NAMESPACE
```

Set the StatefulSet name to `librenms.poller.name` instead if that value is overridden.

The PersistentVolumeClaims are separate objects and are not deleted, so RRD data and the
database survive. The frontend and pollers are unavailable between the delete and the
upgrade.

## Database Configuration

### Internal Database (Default)

By default, the chart deploys [HelmForge MySQL](https://github.com/helmforgedev/charts/tree/main/charts/mysql) as part of the release (`mysql.enabled: true`).
No additional database configuration is needed.

The chart sets `collation-server=utf8mb4_unicode_ci` by default, which satisfies the
[LibreNMS database collation requirement](https://community.librenms.org/t/new-default-database-charset-collation/14956)
automatically on fresh installs.

#### Binary logging

The chart also sets `skip-log-bin`, disabling the MySQL binary log. MySQL 8+ enables it by
default and keeps 30 days of it, and because LibreNMS writes to the database on every poll the
binlog can grow by tens of GB and fill the data PVC. The binary log is only needed for
replication or point-in-time recovery, so it is off for the standalone default; the subchart
still enables it on the source pod when `mysql.architecture` is set to `replication`.

To keep it, override the setting in your values:

```yaml
mysql:
  config:
    myCnf: |
      [mysqld]
      character-set-server=utf8mb4
      collation-server=utf8mb4_unicode_ci
      binlog_expire_logs_seconds=86400
```

Existing binary logs are not deleted when logging is turned off. To reclaim that space on an
existing install, purge them **before** upgrading:

```bash
kubectl exec -n NAMESPACE RELEASE-mysql-0 -- mysql -uroot \
  -p"$(kubectl get secret RELEASE-mysql-auth -n NAMESPACE -o jsonpath='{.data.mysql-root-password}' | base64 -d)" \
  -e "PURGE BINARY LOGS BEFORE NOW();"
```

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

## Redis

Redis backs the Laravel cache and session stores. The chart deploys a bundled Redis by
default (`redis.enabled: true`).

To use a Redis you manage yourself, disable the bundled one and point `externalRedis` at it:

```yaml
redis:
  enabled: false
externalRedis:
  host: redis.example.internal
  port: 6379
  db: 0
```

With `redis.enabled: false` and no `externalRedis.host`, the chart sets the cache and
session drivers to `file`. Pods then keep cache and session state on their own
filesystems, so this is only safe for a single frontend replica and is not suitable for
distributed polling.

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

## Gateway API

As an alternative to `ingress`, the chart can expose the frontend with a Gateway API
[`HTTPRoute`](https://gateway-api.sigs.k8s.io/api-types/httproute/). The Gateway itself is **not**
created by this chart — it is normally shared across namespaces and managed separately — so this
attaches a route to a Gateway you already run.

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: https
  hostnames:
    - librenms.example.com
  paths:
    - path: /
      pathType: PathPrefix

ingress:
  enabled: false
```

Each entry in `paths` becomes one HTTPRoute rule backed by the frontend service on port 8000.
`ingress` and `gateway` are independent; leave `ingress.enabled: false` if you only want the route.

Requires the Gateway API CRDs to be installed in the cluster and a controller implementing them.
`HTTPRoute` has been stable at `gateway.networking.k8s.io/v1` since Gateway API v1.0.

The CRDs carry their own Kubernetes requirement, separate from this chart's. Gateway API
v1.6.1 needs Kubernetes 1.31 or newer — its `standard-install.yaml` fails on 1.30 and below.
Older Gateway API releases support older clusters.

When the Gateway terminates TLS, set `librenms.frontend.appUrl` and
`librenms.frontend.appTrustedProxies` as described under
[TLS termination at an ingress](#tls-termination-at-an-ingress-app_url--app_trusted_proxies) —
a Gateway is just another proxy in front of LibreNMS, and the same Laravel settings apply.

### Why only the frontend

The syslog-ng and snmptrapd sidecars are deliberately left on plain Services and have no route
equivalent here. `UDPRoute` and `TCPRoute` are GA at `v1`, so this is not a maturity limitation.

Gateway implementations terminate and forward connections, and whether the sender's address
reaches the backend is implementation-defined rather than guaranteed by the API. LibreNMS
resolves both syslog messages and traps to a device by that address and discards what it cannot
match, so the guarantee matters. HTTP carries the original client in `X-Forwarded-For`, which is
why the frontend is unaffected. Raw syslog and SNMP traps have no equivalent, and PROXY protocol
is TCP-only while both protocols are predominantly UDP.

For those two, expose the Service directly and preserve the source address with
`externalTrafficPolicy: Local`, as described under
[Receiving syslog from outside the cluster](#receiving-syslog-from-outside-the-cluster).

## Syslog

The chart can run the LibreNMS image as a `syslog-ng` sidecar, which receives syslog on port 514
(UDP and TCP) and pipes each message to LibreNMS' `syslog.php`. See the
[Syslog docs](https://docs.librenms.org/Extensions/Syslog/).

```yaml
librenms:
  syslogng:
    enabled: true
  configuration: |
    $config['distributed_poller_group'] = '0';
    $config['distributed_poller']       = true;
    $config['enable_syslog']            = true;
```

`$config['enable_syslog']` is required — without it the sidecar receives messages but LibreNMS
does not store them.

### Receiving syslog from outside the cluster

LibreNMS resolves each message to a device by matching syslog-ng's `$HOST` against the device's
hostname, sysName or IP, and **discards any message it cannot match**. The image's
`syslog-ng.conf` sets `use_dns(no)` and leaves `keep-hostname()` at its default of `no`, which
means syslog-ng overwrites the message's HOSTNAME field with the **address the packet came
from**. Device attribution therefore depends on the source address surviving the trip to the pod.

A `ClusterIP` service is enough for senders inside the cluster. For devices outside it, a
`LoadBalancer` or `NodePort` service under the default `externalTrafficPolicy: Cluster` lets
kube-proxy SNAT the source to a node address — which drops every external message, or, if your
nodes are themselves monitored, files all of them against the node that received them. Set
`externalTrafficPolicy: Local` to avoid the SNAT:

```yaml
librenms:
  syslogng:
    enabled: true
    replicas: 1
    service:
      type: LoadBalancer
      externalTrafficPolicy: Local
      annotations:
        metallb.io/loadBalancerIPs: 192.168.1.50
```

The same applies to the [snmptrapd sidecar](#snmp-traps), which has an identical `service` block.

#### Notes for MetalLB

MetalLB [respects `externalTrafficPolicy`](https://metallb.io/usage/#traffic-policies) in both L2
and BGP mode, and documents that under `Local` "your pods can see the real source IP address of
incoming connections". Notes:

- Prefer the `metallb.io/loadBalancerIPs` annotation over the chart's `loadBalancerIP` value.
  MetalLB honours both, but `spec.loadBalancerIP` is deprecated in the Kubernetes API. Use
  `metallb.io/address-pool` instead if you only care which pool the address comes from.
- Under `Local`, only nodes running a pod attract traffic. With `replicas: 1` the announcement
  follows the pod, so a reschedule causes a brief gap — unavoidable for UDP, which has no
  retransmit.
- **Syslog and traps cannot share one address** while either uses `Local`. MetalLB's
  `metallb.io/allow-shared-ip` requires both services to use `Cluster`, or to select the *exact*
  same pods; the syslog-ng and snmptrapd services select different pods. Give them separate
  addresses.
- A single service carrying both TCP and UDP needs MetalLB 0.13.6+ (which
  [validated mixed-protocol services](https://github.com/metallb/metallb/issues/1050)) and
  Kubernetes 1.26+, where `MixedProtocolLBService` reached GA.

## SNMP Traps

The chart can run the LibreNMS image a second time as an `snmptrapd` sidecar, which receives
SNMP traps on port 162 (UDP and TCP) and hands them to LibreNMS' `snmptrap.php` handler.
See the [SNMP Trap Handler docs](https://docs.librenms.org/Extensions/SNMP-Trap-Handler/).

```yaml
librenms:
  snmptrapd:
    enabled: true
    community: my-trap-community
```

LibreNMS attributes an incoming trap to a device by the **source address of the trap** and
discards any trap it cannot match, so the sending device must already be monitored and its
address must survive the trip to the pod. A `ClusterIP` service is enough for senders inside the
cluster. Devices outside it need a `LoadBalancer` or `NodePort` service, and
`externalTrafficPolicy: Local` so that kube-proxy does not SNAT the trap to a node address --
which drops every external trap, or, if your nodes are themselves monitored, silently attributes
all of them to the node that received them:

```yaml
librenms:
  snmptrapd:
    enabled: true
    service:
      type: LoadBalancer
      externalTrafficPolicy: Local
      annotations:
        metallb.io/loadBalancerIPs: 192.168.1.51
```

If you run MetalLB, see [Notes for MetalLB](#notes-for-metallb) above — in particular, traps and
syslog need separate addresses when either uses `Local`.

### Authorization

By default the sidecar inherits the image's `disableAuthorization: yes`, which accepts every
trap that arrives regardless of community string or SNMPv3 user. To enforce the configured
credentials instead:

```yaml
librenms:
  snmptrapd:
    enabled: true
    disableAuthorization: "no"
    community: my-trap-community
```

> **Note:** `disableAuthorization` is a string. Write `"no"` in quotes — bare `no` is parsed as a
> boolean by YAML and rejected by the values schema.

### SNMPv3

SNMPv3 trap authentication is configured under `librenms.snmptrapd.snmpv3`. The image ships
placeholder passwords (`auth_pass` / `priv_pass`) that apply when none are set, so set your own.
Rather than putting them in your values, point the chart at an existing secret:

```bash
kubectl create secret generic snmpv3-credentials \
  --from-literal=snmp-auth-password=YOUR_AUTH_PASSWORD \
  --from-literal=snmp-priv-password=YOUR_PRIV_PASSWORD \
  -n default
```

```yaml
librenms:
  snmptrapd:
    enabled: true
    snmpv3:
      user: librenms_user
      authProtocol: SHA
      privProtocol: AES
      securityLevel: priv
      engineId: "1234567890"
      existingSecret:
        name: snmpv3-credentials
        authKey: snmp-auth-password
        privKey: snmp-priv-password
```

`existingSecret.name` takes precedence over `snmpv3.authPassword` and `snmpv3.privPassword`.

### MIBs

The standard and Cisco MIB directories are always loaded. Add vendor directories with
`librenms.snmptrapd.extraMibDirs` (colon separated):

```yaml
librenms:
  snmptrapd:
    extraMibDirs: "/opt/librenms/mibs/veeam:/opt/librenms/mibs/dell"
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

The generated key is read back from the release Secret on each `helm upgrade`, so it stays
stable for the life of the release. Rotating APP_KEY logs out every session and makes
existing Laravel-encrypted values undecryptable, so it only changes if you set
`librenms.appkey` explicitly.

### TLS termination at an ingress (APP_URL / APP_TRUSTED_PROXIES)

When TLS is terminated at an ingress or load balancer, the pod only ever sees plain HTTP, so Laravel generates `http://` links and the UI ends up serving mixed content that browsers block.

Setting these through `extraEnvs` is not reliable: the LibreNMS image runs PHP-FPM with `clear_env = yes`, so container environment variables are invisible to the workers serving web requests. It appears to work only until something runs `config:clear` (for example from the admin UI), after which Laravel falls back to reading `.env` directly. These two values are written into `.env` by the init container instead, so they survive a config cache clear.

Both are empty by default and omitted entirely when unset:

```yaml
librenms:
  frontend:
    appUrl: "https://librenms.example.com"
    appTrustedProxies:
      - "10.0.0.0/8"   # or "*" to trust all
```

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

The following table lists the main configurable parameters of the librenms chart v10.0.0 and their default values. Please, refer to [values.yaml](./values.yaml) for the full list of configurable parameters.

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
| externalRedis | object | `{"db":0,"host":"","port":6379}` | External Redis configuration. Used when `redis.enabled` is false. Leave `host` blank to run without Redis at all, in which case LibreNMS falls back to the file cache and session drivers -- only safe for a single frontend replica, since pollers and frontends no longer share cache or session state. |
| externalRedis.db | int | `0` | Redis database number |
| externalRedis.host | string | `""` | Redis host (DNS name or IP address) |
| externalRedis.port | int | `6379` | Redis port |
| gateway | object | `{"annotations":{},"enabled":false,"hostnames":[],"parentRefs":[],"paths":[{"path":"/","pathType":"PathPrefix"}]}` | LibreNMS Gateway API configuration. Renders an HTTPRoute for the frontend as an alternative to `ingress`, for clusters running a Gateway API implementation. The Gateway itself is not created by this chart -- it is usually shared across namespaces and managed separately. Requires the Gateway API CRDs (HTTPRoute is stable at gateway.networking.k8s.io/v1 as of Gateway API v1.0).  Only the frontend is exposed this way. The syslog-ng and snmptrapd sidecars are deliberately left on plain Services: routing them through a Gateway replaces the sender's address with the Gateway's, and LibreNMS resolves a message or trap to a device by that address. See the Syslog section of the README. |
| gateway.annotations | object | `{}` | Annotations for the HTTPRoute |
| gateway.enabled | bool | `false` | Enable or disable the HTTPRoute |
| gateway.hostnames | list | `[]` | Hostnames this route matches. Leave empty to match every hostname the parent Gateway listener accepts. |
| gateway.parentRefs | list | `[]` | Gateways this route attaches to. Required when enabled. Each entry accepts the usual parentRef fields (name, namespace, sectionName, port). |
| gateway.paths | list | `[{"path":"/","pathType":"PathPrefix"}]` | Path matches. Each entry becomes an HTTPRoute rule backed by the frontend service on port 8000. |
| ingress | object | `{"annotations":{},"className":"","enabled":false,"hosts":[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}],"tls":[]}` | LibreNMS ingress configuration |
| ingress.annotations | object | `{}` | Ingress annotations. Use `className` above to select the controller; the `kubernetes.io/ingress.class` annotation it replaced is retired. |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable or disable ingress |
| ingress.hosts | list | `[{"host":"chart-example.local","paths":[{"path":"/","pathType":"ImplementationSpecific"}]}]` | Ingress rules |
| librenms.appkey | string | `""` | Laravel APP_KEY for encryption. If blank, a random 32-character key will be generated and persisted in a Kubernetes Secret. You may also provide a base64-encoded key (prefix with 'base64:'). Example: appkey: "base64:QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm==" |
| librenms.configuration | string | `"$config['distributed_poller_group']          = '0';\n$config['distributed_poller']                = true;\n"` | Custom configuration options for LibreNMS. For more information on options in this file check the following link: https://docs.librenms.org/Support/Configuration/ |
| librenms.existingSecret | bool | `false` | Existing secret name to use for appkey Must have the key 'appkey' as above |
| librenms.extraEnvFrom | list | `[]` | Extra envFrom sources applied to all LibreNMS components |
| librenms.extraEnvs | list | `[]` | Extra environment variables applied to all LibreNMS components |
| librenms.frontend.appTrustedProxies | list | `[]` | Proxy IPs/CIDRs (or "*") whose X-Forwarded-* headers Laravel should trust. Written to Laravel's .env as APP_TRUSTED_PROXIES. |
| librenms.frontend.appUrl | string | `""` | Externally visible base URL of this instance, including scheme (e.g. "https://librenms.example.com"). Written to Laravel's .env as APP_URL so URLs are generated correctly when TLS is terminated at an ingress. |
| librenms.frontend.enabled | bool | `true` | Frontend enabled |
| librenms.frontend.extraEnvFrom | list | `[]` | Extra envFrom sources for frontend containers |
| librenms.frontend.extraEnvs | list | `[]` | Extra environment variables for frontend containers |
| librenms.frontend.extraVolumeMounts | list | `[]` | Extra volume mounts for frontend containers |
| librenms.frontend.extraVolumes | list | `[]` | Extra volumes for frontend pods |
| librenms.frontend.livenessProbe | object | `{"failureThreshold":6,"httpGet":{"path":"/login","port":8000},"initialDelaySeconds":60,"periodSeconds":30,"timeoutSeconds":10}` | Frontend liveness probe. Restarts the container when PHP-FPM stops answering, which a TCP check on port 8000 cannot detect because nginx and PHP-FPM are separate processes. Deliberately not Laravel's /up endpoint: LibreNMS registers a DiagnosingHealth listener that opens a database connection, so /up returns 500 whenever MySQL is down and would restart every frontend pod for the duration of a database outage. /login is rendered by PHP-FPM but does not query the database, so it fails only when PHP-FPM itself is unresponsive. Set to null to disable. |
| librenms.frontend.livenessProbe.httpGet.path | string | `"/login"` | Check endpoint path |
| librenms.frontend.livenessProbe.httpGet.port | int | `8000` | Check endpoint port |
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
| librenms.frontend.serviceAccountName | string | `""` | Name of an existing ServiceAccount to run the pods under. The chart does not create ServiceAccounts; leave blank to use the namespace default. |
| librenms.image.pullPolicy | string | `"Always"` | pullPolicy is the Kubernetes image pull policy for the main LibreNMS image. |
| librenms.image.repository | string | `"librenms/librenms"` | repository is the image repository to pull from. |
| librenms.image.tag | string | `"26.8.1"` | tag is image tag to pull. |
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
| librenms.poller.name | string | `""` | Poller name |
| librenms.poller.nodeSelector | object | `{}` | nodeSelector for poller pods |
| librenms.poller.podAnnotations | object | `{}` | podAnnotations for poller pods |
| librenms.poller.privileged | bool | `false` |  |
| librenms.poller.replicas | int | `2` | Poller replicas |
| librenms.poller.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.poller.serviceAccountName | string | `""` | Name of an existing ServiceAccount to run the pods under. The chart does not create ServiceAccounts; leave blank to use the namespace default. |
| librenms.privileged | bool | `false` |  |
| librenms.rrdcached | object | `{"enabled":true,"envs":[{"name":"WRITE_JITTER","value":"1800"},{"name":"WRITE_TIMEOUT","value":"1800"}],"extraEnvFrom":[],"extraEnvs":[],"extraVolumeMounts":[],"extraVolumes":[],"image":{"pullPolicy":"Always","repository":"crazymax/rrdcached","tag":"1.8.0"},"livenessProbe":{"initialDelaySeconds":15,"periodSeconds":20,"tcpSocket":{"port":42217}},"nodeSelector":{},"persistence":{"enabled":true,"journal":{"size":"1Gi","storageClassName":""},"rrdcached":{"size":"10Gi","storageClassName":""}},"podAnnotations":{},"readinessProbe":{"initialDelaySeconds":5,"periodSeconds":10,"tcpSocket":{"port":42217}},"resources":{},"serviceAccountName":""}` | RRD cached is the tool that allows for distributed polling and is mandatory in this LibreNMS helm chart. See the rrdcached documentation for more information: https://oss.oetiker.ch/rrdtool/doc/rrdcached.en.html |
| librenms.rrdcached.enabled | bool | `true` | RRDCached enabled |
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
| librenms.rrdcached.serviceAccountName | string | `""` | Name of an existing ServiceAccount to run the pods under. The chart does not create ServiceAccounts; leave blank to use the namespace default. |
| librenms.snmp_scanner | object | `{"concurrencyPolicy":"Forbid","cron":"15 * * * *","enabled":false,"extraEnvFrom":[],"extraEnvs":[],"failedJobsHistoryLimit":1,"nodeSelector":{},"podAnnotations":{},"resources":{},"securityContext":{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000},"successfulJobsHistoryLimit":3}` | SNMP network discovery scanner cron job. This job is optional and only use when having snmp network discovery enabled. For this to work either set the 'nets' configuration in the custom config on in the admin interface See the following link for more information: https://docs.librenms.org/Extensions/Auto-Discovery/ |
| librenms.snmp_scanner.concurrencyPolicy | string | `"Forbid"` | What to do when a scan is still running as the next one falls due. Forbid skips the new run, Allow lets the two overlap, Replace terminates the running scan. Overlapping scans duplicate discovery work and contend on the database. |
| librenms.snmp_scanner.cron | string | `"15 * * * *"` | SNMP scanner cronjob syntax interval |
| librenms.snmp_scanner.enabled | bool | `false` | SNMP scanner enabled |
| librenms.snmp_scanner.extraEnvFrom | list | `[]` | Extra envFrom sources for SNMP scanner containers |
| librenms.snmp_scanner.extraEnvs | list | `[]` | Extra environment variables for SNMP scanner containers |
| librenms.snmp_scanner.failedJobsHistoryLimit | int | `1` | Number of failed scan jobs to retain |
| librenms.snmp_scanner.nodeSelector | object | `{}` | nodeSelector for SNMP scanner pods |
| librenms.snmp_scanner.podAnnotations | object | `{}` | podAnnotations for SNMP scanner pods |
| librenms.snmp_scanner.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the containers running within the Pod. |
| librenms.snmp_scanner.securityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000}` | securityContext defines the security settings for the SNMP scanner pod. These settings are required for the SNMP scanner to run properly. See: https://github.com/librenms/docker/pull/530 |
| librenms.snmp_scanner.successfulJobsHistoryLimit | int | `3` | Number of completed scan jobs to retain |
| librenms.snmptrapd | object | `{"community":"librenmsdocker","disableAuthorization":"yes","enabled":false,"extraEnvFrom":[],"extraEnvs":[],"extraMibDirs":"","livenessProbe":{"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":20,"tcpSocket":{"port":162}},"nodeSelector":{},"podAnnotations":{},"processingType":"log,execute,net","replicas":1,"resources":{},"service":{"annotations":{},"externalTrafficPolicy":"","loadBalancerIP":"","type":"ClusterIP"},"snmpv3":{"authPassword":"","authProtocol":"SHA","engineId":"1234567890","existingSecret":{"authKey":"snmp-auth-password","name":"","privKey":"snmp-priv-password"},"privPassword":"","privProtocol":"AES","securityLevel":"priv","user":"librenms_user"}}` | snmptrapd sidecar for receiving SNMP traps from network devices on port 162. Traps are passed to LibreNMS' snmptrap.php handler, which matches them to a device by the source IP of the trap, so the sending device must already be monitored. See: https://docs.librenms.org/Extensions/SNMP-Trap-Handler/ |
| librenms.snmptrapd.community | string | `"librenmsdocker"` | SNMP v1/v2c community string devices must send their traps with. Change this from the image default before exposing the receiver. |
| librenms.snmptrapd.disableAuthorization | string | `"yes"` | Accept traps without checking them against the community string or the SNMPv3 user below. Set to "no" to enforce authorization. |
| librenms.snmptrapd.enabled | bool | `false` | Enable snmptrapd |
| librenms.snmptrapd.extraEnvFrom | list | `[]` | Extra envFrom sources for snmptrapd containers |
| librenms.snmptrapd.extraEnvs | list | `[]` | Extra environment variables for snmptrapd containers |
| librenms.snmptrapd.extraMibDirs | string | `""` | Additional colon-separated MIB directories to load (e.g. "/opt/librenms/mibs/veeam"). The standard and Cisco MIB directories are always loaded. |
| librenms.snmptrapd.livenessProbe | object | `{"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":20,"tcpSocket":{"port":162}}` | snmptrapd liveness probe. TCP 162 is a real listener in the image, and accepting a connection on it does not involve the database, so a failure means the receiver itself is gone. Set to null to disable. |
| librenms.snmptrapd.nodeSelector | object | `{}` | nodeSelector for snmptrapd pods |
| librenms.snmptrapd.podAnnotations | object | `{}` | podAnnotations for snmptrapd pods |
| librenms.snmptrapd.processingType | string | `"log,execute,net"` | Which snmptrapd processing types (log, execute and/or net) to apply to accepted traps. LibreNMS needs 'execute' for its trap handler to run. |
| librenms.snmptrapd.replicas | int | `1` | snmptrapd replicas |
| librenms.snmptrapd.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the snmptrapd container. |
| librenms.snmptrapd.service.annotations | object | `{}` | Annotations for the snmptrapd service |
| librenms.snmptrapd.service.externalTrafficPolicy | string | `""` | externalTrafficPolicy for the service. Set to "Local" to preserve the source IP of incoming traps, which LibreNMS needs to match a trap to a device. Only applies to LoadBalancer and NodePort services. |
| librenms.snmptrapd.service.loadBalancerIP | string | `""` | Static IP to request when type is LoadBalancer |
| librenms.snmptrapd.service.type | string | `"ClusterIP"` | Service type for the trap receiver. Devices outside the cluster need LoadBalancer or NodePort to reach it. |
| librenms.snmptrapd.snmpv3.authPassword | string | `""` | SNMPv3 authentication password. Left blank the image default ('auth_pass') applies, which should not be used in production. |
| librenms.snmptrapd.snmpv3.authProtocol | string | `"SHA"` | SNMPv3 authentication protocol (MD5 or SHA) |
| librenms.snmptrapd.snmpv3.engineId | string | `"1234567890"` | SNMPv3 engine ID |
| librenms.snmptrapd.snmpv3.existingSecret | object | `{"authKey":"snmp-auth-password","name":"","privKey":"snmp-priv-password"}` | Read the SNMPv3 passwords from an existing secret instead of the two values above. Takes precedence over authPassword and privPassword. |
| librenms.snmptrapd.snmpv3.existingSecret.authKey | string | `"snmp-auth-password"` | Key in the secret containing the authentication password |
| librenms.snmptrapd.snmpv3.existingSecret.name | string | `""` | Name of the secret holding the SNMPv3 passwords |
| librenms.snmptrapd.snmpv3.existingSecret.privKey | string | `"snmp-priv-password"` | Key in the secret containing the privacy password |
| librenms.snmptrapd.snmpv3.privPassword | string | `""` | SNMPv3 privacy password. Left blank the image default ('priv_pass') applies, which should not be used in production. |
| librenms.snmptrapd.snmpv3.privProtocol | string | `"AES"` | SNMPv3 privacy protocol (DES or AES) |
| librenms.snmptrapd.snmpv3.securityLevel | string | `"priv"` | SNMPv3 security level (noauth, auth or priv) |
| librenms.snmptrapd.snmpv3.user | string | `"librenms_user"` | SNMPv3 username |
| librenms.syslogng | object | `{"enabled":false,"extraEnvFrom":[],"extraEnvs":[],"livenessProbe":{"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":20,"tcpSocket":{"port":514}},"nodeSelector":{},"podAnnotations":{},"replicas":1,"resources":{},"service":{"annotations":{},"externalTrafficPolicy":"","loadBalancerIP":"","type":"ClusterIP"}}` | syslog-ng sidecar for receiving syslog messages from network devices on port 514. Requires $config['enable_syslog'] = true; in librenms.configuration to store messages. See: https://docs.librenms.org/Extensions/Syslog/ |
| librenms.syslogng.enabled | bool | `false` | Enable syslog-ng |
| librenms.syslogng.extraEnvFrom | list | `[]` | Extra envFrom sources for syslogng containers |
| librenms.syslogng.extraEnvs | list | `[]` | Extra environment variables for syslogng containers |
| librenms.syslogng.livenessProbe | object | `{"failureThreshold":3,"initialDelaySeconds":30,"periodSeconds":20,"tcpSocket":{"port":514}}` | syslog-ng liveness probe. TCP 514 is a real listener in the image, and accepting a connection on it does not involve the database, so a failure means the receiver itself is gone. Set to null to disable. |
| librenms.syslogng.nodeSelector | object | `{}` | nodeSelector for syslogng pods |
| librenms.syslogng.podAnnotations | object | `{}` | podAnnotations for syslogng pods |
| librenms.syslogng.replicas | int | `1` | syslogng replicas |
| librenms.syslogng.resources | object | `{}` | resources defines the computing resources (CPU and memory) that are allocated to the syslog-ng container. |
| librenms.syslogng.service.annotations | object | `{}` | Annotations for the syslogng service |
| librenms.syslogng.service.externalTrafficPolicy | string | `""` | externalTrafficPolicy for the service. Set to "Local" to preserve the source IP of incoming messages, which LibreNMS needs to match a message to a device. Only applies to LoadBalancer and NodePort services. |
| librenms.syslogng.service.loadBalancerIP | string | `""` | Static IP to request when type is LoadBalancer |
| librenms.syslogng.service.type | string | `"ClusterIP"` | Service type for the syslog receiver. Devices outside the cluster need LoadBalancer or NodePort to reach it. |
| librenms.timezone | string | `"UTC"` | Timezone used by librenms for communication with RRD cached |
| mysql | object | `{"architecture":"standalone","auth":{"database":"librenms","username":"librenms"},"config":{"myCnf":"[mysqld]\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\nskip-log-bin\n"},"enabled":true,"existingAuthSecret":{},"standalone":{"persistence":{"enabled":true,"size":"8Gi"}}}` | Configuration for MySQL dependency chart by HelmForge. See their chart for more information: https://github.com/helmforgedev/charts/tree/main/charts/mysql |
| mysql.config | object | `{"myCnf":"[mysqld]\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\nskip-log-bin\n"}` | Server configuration appended to the subchart's my.cnf. `character-set-server`/`collation-server` set the utf8mb4_unicode_ci collation required by LibreNMS. MySQL 8.4 defaults to utf8mb4_0900_ai_ci, which causes validation warnings. See: https://community.librenms.org/t/new-default-database-charset-collation/14956 `skip-log-bin` disables the binary log. MySQL 8+ enables it by default with 30 days of retention, and LibreNMS writes to the database on every poll, so the binlog can grow by tens of GB and fill the data PVC. It is only needed for replication or point-in-time recovery; the subchart re-enables it on the source pod when `architecture: replication`. |
| mysql.existingAuthSecret | object | `{}` | Use an existing secret for MySQL authentication instead of the auto-generated one. This is useful when migrating from the Bitnami MySQL subchart, which created a secret named "RELEASE-mysql" with key "mysql-password". Example for Bitnami migration:   existingAuthSecret:     name: my-release-mysql     key: mysql-password |
| redis | object | `{"architecture":"standalone","auth":{"enabled":false},"enabled":true}` | Configuration for redis dependency chart by HelmForge. See their chart for more information: https://github.com/helmforgedev/charts/tree/main/charts/redis |

## Uninstalling the Chart

To delete the chart:

```shell
$ helm delete my-release
```

## Requirements

Kubernetes: `>=1.26.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://repo.helmforge.dev | mysql | ~2.0.0 |
| https://repo.helmforge.dev | redis | 2.0.1 |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| jacobw |  | <https://github.com/jacobw> |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
