# LibreNMS

[LibreNMS](https://docs.librenms.org/) is an IP address management (IPAM) and
data center infrastructure management (DCIM) tool.

## TL;DR

```shell
$ helm repo add librenms https://www.librenms.org/helm-charts
$ helm install my-release librenms/librenms --set appkey=<LibreNMS Application key>
```

## Prerequisites

- This chart has only been tested on Kubernetes 1.18+, but should work on 1.14+
- Recent versions of Helm 3 are supported

## Installing the Chart

To install the chart with the release name `my-release` and default configuration:

```shell
$ helm repo add librenms https://www.librenms.org/helm-charts
$ helm install my-release librenms/librenms --set appkey=<LibreNMS Application key>
```

## Values
Check the [values.yaml](./values.yaml) file for the available settings for this chart and its
dependencies.

### Required values:
```
librenms:
  appkey:
```

This should be filled with a laravel appkey, this can be generated using the laravel artisan command:
```
php artisan key:generate
```
The value should look like:
```
librenms:
  appkey: base64:RTMmh+i10E2RMcDxookMu47BTzJQy87hOU+k/zcuPnA=
```

### Available values

The following table lists the main configurable parameters of the librenms chart v3.11.0 and their default values. Please, refer to [values.yaml](./values.yaml) for the full list of configurable parameters.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| librenms.appkey | string | `nil` |  |
| librenms.configuration | string | `"$config['distributed_poller_group']          = '0';\n$config['distributed_poller']                = true;"` |  |
| librenms.extraEnvs | object | `{}` |  |
| librenms.frontend.readinessProbe.httpGet.path | string | `"/login"` |  |
| librenms.frontend.readinessProbe.httpGet.port | int | `8000` |  |
| librenms.frontend.readinessProbe.initialDelaySeconds | int | `30` |  |
| librenms.frontend.readinessProbe.periodSeconds | int | `60` |  |
| librenms.frontend.readinessProbe.timeoutSeconds | int | `10` |  |
| librenms.frontend.replicas | int | `1` |  |
| librenms.frontend.resources | object | `{}` |  |
| librenms.image.repository | string | `"librenms/librenms"` |  |
| librenms.image.tag | string | `"24.5.0"` |  |
| librenms.poller.replicas | int | `2` |  |
| librenms.poller.resources | object | `{}` |  |
| librenms.rrdcached.envs[0].name | string | `"TZ"` |  |
| librenms.rrdcached.envs[0].value | string | `"Europe/Amsterdam"` |  |
| librenms.rrdcached.envs[1].name | string | `"WRITE_JITTER"` |  |
| librenms.rrdcached.envs[1].value | string | `"1800"` |  |
| librenms.rrdcached.envs[2].name | string | `"WRITE_TIMEOUT"` |  |
| librenms.rrdcached.envs[2].value | string | `"1800"` |  |
| librenms.rrdcached.extraEnvs | object | `{}` |  |
| librenms.rrdcached.image.repository | string | `"crazymax/rrdcached"` |  |
| librenms.rrdcached.image.tag | string | `"1.8.0"` |  |
| librenms.rrdcached.livenessProbe.initialDelaySeconds | int | `15` |  |
| librenms.rrdcached.livenessProbe.periodSeconds | int | `20` |  |
| librenms.rrdcached.livenessProbe.tcpSocket.port | int | `42217` |  |
| librenms.rrdcached.persistence.enabled | bool | `true` |  |
| librenms.rrdcached.persistence.journal.size | string | `"1Gi"` |  |
| librenms.rrdcached.persistence.rrdcached.size | string | `"10Gi"` |  |
| librenms.rrdcached.resources | object | `{}` |  |
| librenms.snmp_scanner.cron | string | `"15 * * * *"` |  |
| librenms.snmp_scanner.enabled | bool | `false` |  |
| librenms.snmp_scanner.extraEnvs | object | `{}` |  |
| librenms.snmp_scanner.resources | object | `{}` |  |
| librenms.timezone | string | `"UTC"` |  |
| mysql.auth.database | string | `"librenms"` |  |
| mysql.auth.username | string | `"librenms"` |  |
| mysql.enabled | bool | `true` |  |
| redis.architecture | string | `"standalone"` |  |
| redis.auth.enabled | bool | `false` |  |
| redis.auth.sentinel | bool | `false` |  |
| redis.enabled | bool | `true` |  |
| redis.master.disableCommands | list | `[]` |  |
| redis.sentinel.enabled | bool | `false` |  |

## Uninstalling the Chart

To delete the chart:

```shell
$ helm delete my-release
```

## License

> The following notice applies to all files contained within this Helm Chart and
> the Git repository which contains it:
>
> Copyright 2022 Jochem Bruijns
>
> Licensed under the Apache License, Version 2.0 (the "License");
> you may not use this file except in compliance with the License.
> You may obtain a copy of the License at
>
>     http://www.apache.org/licenses/LICENSE-2.0
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
> See the License for the specific language governing permissions and
> limitations under the License.
