# Changelog

## [9.2.1](https://github.com/librenms/helm-charts/compare/librenms-9.2.0...librenms-9.2.1) (2026-08-28)


### Bug Fixes

* **configmap:** gate Redis and RRDCached settings on their toggles ([420603c](https://github.com/librenms/helm-charts/commit/420603c282ed57fa9e2f65d24f9e7df8d4d71ca4))
* **ingress:** stop mutating global values, refresh the annotations example ([eca257c](https://github.com/librenms/helm-charts/commit/eca257c195da6ce5b16a60a1161731dddda4944d))
* **secret:** preserve the generated APP_KEY across upgrades ([dcaa088](https://github.com/librenms/helm-charts/commit/dcaa0885876b4aa9e70ab724d36499c185152363))
* **serviceaccount:** make serviceAccountName settable, drop dead helpers ([8aefe00](https://github.com/librenms/helm-charts/commit/8aefe005a4c338170c47dace429ec15bd8205791))
