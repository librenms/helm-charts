# Changelog

## [10.1.0](https://github.com/librenms/helm-charts/compare/librenms-10.0.0...librenms-10.1.0) (2026-08-28)


### Features

* add liveness probes and SNMP scanner job policy ([#271](https://github.com/librenms/helm-charts/issues/271)) ([eb0a35e](https://github.com/librenms/helm-charts/commit/eb0a35e168077d254743efcdfc13335b0f24c803))
* **frontend:** gate readiness on the LibreNMS health endpoint ([#272](https://github.com/librenms/helm-charts/issues/272)) ([2cd87d5](https://github.com/librenms/helm-charts/commit/2cd87d556db57294d339763a7e6f12a0010523aa))

## [10.0.0](https://github.com/librenms/helm-charts/compare/librenms-9.2.1...librenms-10.0.0) (2026-08-28)


### ⚠ BREAKING CHANGES

* `spec.selector` is immutable on Deployments and StatefulSets, so upgrading an existing release fails with `field is immutable`. Delete the librenms Deployments and the poller StatefulSet before upgrading. The PersistentVolumeClaims are separate objects and are not affected.
* Helm refuses to install or upgrade the chart on Kubernetes older than 1.26.

### Features

* follow the standard Kubernetes label conventions ([#269](https://github.com/librenms/helm-charts/issues/269)) ([dc852b1](https://github.com/librenms/helm-charts/commit/dc852b1943f5fdc424faf186e0b5439fa6257a04))
* require Kubernetes 1.26 or newer ([#265](https://github.com/librenms/helm-charts/issues/265)) ([d82004d](https://github.com/librenms/helm-charts/commit/d82004d7981c156c16186a0d174b85c3dcde0d08))

## [9.2.1](https://github.com/librenms/helm-charts/compare/librenms-9.2.0...librenms-9.2.1) (2026-08-28)


### Bug Fixes

* **configmap:** gate Redis and RRDCached settings on their toggles ([420603c](https://github.com/librenms/helm-charts/commit/420603c282ed57fa9e2f65d24f9e7df8d4d71ca4))
* **ingress:** stop mutating global values, refresh the annotations example ([eca257c](https://github.com/librenms/helm-charts/commit/eca257c195da6ce5b16a60a1161731dddda4944d))
* **secret:** preserve the generated APP_KEY across upgrades ([dcaa088](https://github.com/librenms/helm-charts/commit/dcaa0885876b4aa9e70ab724d36499c185152363))
* **serviceaccount:** make serviceAccountName settable, drop dead helpers ([8aefe00](https://github.com/librenms/helm-charts/commit/8aefe005a4c338170c47dace429ec15bd8205791))
