# LibreNMS

[LibreNMS](https://docs.librenms.org/) is an IP address management (IPAM) and
data center infrastructure management (DCIM) tool.

## TL;DR

```shell
$ helm repo add thechef23 https://thechef23.github.io/helm-librenms
$ helm install my-release thechef23-librenms/librenms
```

## Prerequisites

- This chart has only been tested on Kubernetes 1.18+, but should work on 1.14+
- Recent versions of Helm 3 are supported

## Installing the Chart

To install the chart with the release name `my-release` and default configuration:

```shell
$ helm repo add thechef23 https://thechef23.github.io/helm-librenms
$ helm install my-release thechef23-librenms/librenms
```

## Values
Check the [values.yml](/TheChef23/helm-librenms/blob/main/values.yaml) file for the available settings for this chart and its
dependencies.

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
