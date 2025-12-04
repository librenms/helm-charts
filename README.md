# LibreNMS Helm Charts

Welcome to the repository for the Helm charts of the LibreNMS community. This repository holds all the Helm charts you need to deploy LibreNMS and related components using Kubernetes.

## Main Chart

The primary chart in this repository is located at `charts/librenms`. This chart allows you to deploy LibreNMS, an open-source network monitoring system, on your Kubernetes cluster.

## Documentation

Each chart within this repository comes with its own set of documentation. To get started with a specific chart, please refer to the README.md file located in the respective chart's directory.

## Getting Started

To install a chart from this repository, you can use the following Helm commands:

```sh
helm repo add librenms https://www.librenms.org/helm-charts
helm repo update
helm install my-release librenms/<chart-name>
```

Replace `<chart-name>` with the name of the chart you wish to install (e.g., `librenms`).

## Contributing

We welcome contributions from the community. If you have improvements or fixes, please submit a pull request. Make sure to follow our contribution guidelines.

### CI Test Values and Template Coverage

To ensure our Helm templates are robust, we maintain a comprehensive test values file at `charts/librenms/ci/test-values.yaml`. This file intentionally provides non-empty values for fields that are often left empty by default (such as `extraEnvs`, `extraEnvFrom`, extra volume mounts, and resource sections). This approach helps catch YAML indentation and structure errors that only appear when these fields are populated.

**Best practices for contributors:**
- Keep default values in `values.yaml` minimal/empty for user-friendliness.
- Add new fields or blocks to `ci/test-values.yaml` with non-empty example values whenever you add or refactor templates.
- **Do not duplicate values in test-values.yaml that already have defaults in values.yaml** - only populate fields that are empty by default (like `[]` or `{}`).
- Our CI (see `.github/workflows/chart-testing.yml` and `ct.yaml`) always renders the chart with this file to catch issues early.
- If you add new nested or optional blocks, ensure they are exercised in the test values file so CI can validate their rendering.

This strategy helps prevent regressions and ensures all template paths are tested, not just the defaults.

---

Thank you for using LibreNMS Helm charts! For any issues or questions, please refer to the documentation of the respective chart or open an issue in this repository.