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

---

Thank you for using LibreNMS Helm charts! For any issues or questions, please refer to the documentation of the respective chart or open an issue in this repository.