# Contributing

The chart lives in `charts/librenms`. Paths below are from the repo root.

## Local development

Linting and doc generation run in Docker.

```bash
make lint                    # lint every chart
make lint-librenms           # lint this chart
make helm-deps-update        # refresh subchart dependencies
make docs                    # regenerate README.md from README.md.gotmpl
```

Render without a cluster:

```bash
helm template test ./charts/librenms -f ./charts/librenms/ci/test-values.yaml
```

## Generated files

Do not edit these. Changes are overwritten.

- `charts/librenms/README.md` — built from `README.md.gotmpl` and `-- ` comments in `values.yaml`.
- `charts/librenms/CHANGELOG.md` — built from commit messages.
- `version` in `charts/librenms/Chart.yaml` — see [Chart version](#chart-version).

Value descriptions go on the line above the key, or on the same line:

```yaml
librenms:
  # -- Number of frontend replicas
  replicaCount: 1
```

## CI test values

`charts/librenms/ci/test-values.yaml` is the only values file chart-testing uses.

Every field defaulting to `[]` or `{}` in `values.yaml` needs a non-empty value there —
`extraEnvs`, `extraEnvFrom`, `extraVolumeMounts`, `resources`. A block gated behind an
empty default never renders in CI, so it is never tested.

Add a gated block, add a matching example in the same change.

Do not repeat values that already have non-empty defaults.

## Values schema

`charts/librenms/values.schema.json` sets `additionalProperties: false`. A key a template
reads but the schema omits cannot be set, and fails silently. Add new values to both
files.

## Labels

Every resource carries the standard `app.kubernetes.io` labels. The helpers take a dict,
not the surrounding context:

```yaml
metadata:
  labels:
    {{- include "librenms.labels" (dict "root" . "component" "poller") | nindent 4 }}
```

Use `librenms.selectorLabels` for `spec.selector`, never `librenms.labels`. Selector labels
are immutable on Deployments and StatefulSets, and the chart and version labels change on
every release.

Omit `component` for resources that are not part of one, such as the ConfigMaps and the
Secret.

## Commit messages and pull requests

Pull requests are squash-merged. The PR title becomes the commit subject and must be a
[Conventional Commit](https://www.conventionalcommits.org/). The PR description becomes
the commit body.

```
fix(ingress): stop mutating global values
```

The type drives the changelog and the version bump:

| Type | Changelog section | Bump |
| --- | --- | --- |
| `feat` | Features | minor |
| `fix` | Bug Fixes | patch |
| `deps` | Dependencies | patch |
| `perf` | Performance Improvements | patch |
| `revert` | Reverts | patch |
| `docs` `chore` `ci` `build` `test` `refactor` `style` | omitted | none |

For a breaking change, append `!` to the type or add a `BREAKING CHANGE:` footer. Either
bumps major.

Scope is optional and free-form: the component or template touched, such as `ingress`,
`configmap`, `gateway`, `frontend` or `syslogng`. Renovate sets its own type and omits
the scope.

## Chart version

release-please owns `version` in `Chart.yaml`, plus `.release-please-manifest.json` and
`CHANGELOG.md`. Leave them alone.

Merging to `main` opens a release pull request carrying the bump and the changelog.
Merging that publishes the GitHub release, the tag, the `gh-pages` index entry and the
GHCR package.

CI does not require a version bump on your pull request.

`appVersion` mirrors `librenms.image.tag`. Renovate updates the tag; a workflow syncs
`appVersion` on `renovate/*` branches only. Change neither by hand.
