# oci-mysql

This repository provides an OpenShift (oc) and OKD-compatible rootless MySQL container image and Helm deployment, designed to run securely under arbitrary user IDs (rootless UID/GID) while maintaining compatibility with standard MySQL entrypoints.

The repository also supports multi-version image builds using GitHub Actions matrix jobs driven by [`versions.json`](versions.json), as well as Helm chart packaging and local development workflows.

---

## Features

- **Rootless & OpenShift-Ready**: Runs as non-root user (`USER 1031`) with root group permissions (`GID 0`) across MySQL data, run, log, and initialization directories.
- **Multi-Version Build Matrix**: Automatically builds supported MySQL versions defined in [`versions.json`](versions.json) via GitHub Actions.
- **Schema Initialization**: Auto-mounts [`schema.sql`](schema.sql) into `/docker-entrypoint-initdb.d/` for automatic first-run database initialization.
- **Multiple Deployment Options**: Easily deployed via Docker Compose or Helm chart.
- **Automated CI/CD**: Centralized reusable workflows for linting, security scanning, dry-run PR testing, matrix builds, Helm publishing, and semantic releases.
- **Local Tooling with mise & hk**: Hermetic developer toolchains and git hooks configured out of the box.

---

## Local Development Setup

This project uses **[mise](https://mise.jdx.dev/)** for managing developer CLI tools and task execution, and **[hk](https://github.com/jdx/hk)** for managing and running git hooks.

### Prerequisites

Ensure you have `mise` and Podman (or Docker) installed on your machine.

### Tooling & Hook Installation

Install required CLI tools (`actionlint`, `hadolint`, `shellcheck`, `zizmor`, `helm`, `trivy`, `betterleaks`, `hk`, `pkl`, `tombi`, `yamllint`, `addlicense`) and set up git hooks with a single task:

```bash
mise run install
```

This runs `hk install --mise` to set up the Git hooks in `.git/hooks/pre-commit` and `.git/hooks/commit-msg`.

### Available mise Tasks

The following tasks are defined in [`mise.toml`](mise.toml):

| Task | Command | Description |
|------|---------|-------------|
| `mise run install` | `hk install --mise` | Install Git hooks (`pre-commit` and `commit-msg`). |
| `mise run hk` (alias `check`) | `hk check --all` | Run all checks across the repository. |
| `mise run compose` | `podman compose up -d --build` | Start local container environment using Podman Compose. |
| `mise run down` | `podman compose down` | Stop local Podman Compose stack. |
| `mise run logs` | `podman compose logs -f` | Follow Podman Compose logs. |
| `mise run play` | `podman play kube rendered.yaml` | Test Helm chart manifests locally with Podman Play Kube. |
| `mise run downplay` | `podman play kube rendered.yaml --down` | Stop and tear down Podman Play Kube pods. |
| `mise run helm-lint` | `helm lint chart/` | Lint the Helm chart. |
| `mise run helm-template` | `helm template test chart/ > rendered.yaml` | Render Helm chart templates to `rendered.yaml`. |
| `mise run helm-dep` | `helm dependency build chart/` | Build Helm chart dependencies. |
| `mise run build` | `podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/oci-modified:test . --load` | Build local test container image for `linux/amd64`. |
| `mise run trivy-fs` | `trivy fs .` | Scan local repository filesystem for security vulnerabilities. |
| `mise run trivy-image` | `trivy image ghcr.io/joeckr/oci-modified:test` | Build image and run Trivy vulnerability scan on container. |

---

## Git Hooks (hk)

Local checks and hooks are configured in [`hk.pkl`](hk.pkl) using [Pkl](https://pkl-lang.org/) to catch issues before committing and pushing code:

- **Formatting & Sanitation**:
  - Trailing whitespace removal (`trailing-whitespace`)
  - Newline normalization (`newlines`)
  - Syntax and format checks for JSON (`jq`), XML (`xmllint`), TOML (`tombi`, `tombi-format`), and YAML (`yamllint`)
  - Merge conflict and large file detection (`check-merge-conflict`, `check-added-large-files`)
  - Submodule prevention (`forbid-submodules`)
  - Branch protection (`no-commit-to-branch` blocks direct commits to `main` or `master`)
  - Pkl configuration evaluation (`pkl`)
- **Commit Standards**:
  - `commit-msg` hook enforces Conventional Commits (`check_conventional_commit`).
- **Security & Licensing**:
  - `betterleaks`: Detects leaked secrets, passwords, and tokens (supports `# betterleaks:allow` inline exclusions).
  - `addlicense`: Ensures proper license headers are present.
- **Linters**:
  - `hadolint`: Lints [`Dockerfile`](Dockerfile).
  - `shellcheck`: Lints shell scripts.
  - `actionlint`: Validates GitHub Actions workflow files.
  - `zizmor`: Audits GitHub Actions workflows for security flaws.
  - `yamllint`: Strict YAML linting across workflows, Docker Compose, and Helm values.
  - `helm-lint`: Validates Helm chart templates and values (`helm lint chart/`).

To run hooks and checks manually across all files:

```bash
mise run hk
# or
mise run check
```

---

## Continuous Integration & Delivery (CI/CD)

The repository uses automated GitHub Actions workflows in [`.github/workflows`](.github/workflows) leveraging reusable workflow templates from `joeckr/ci-templates`:

| Workflow | File | Trigger | Jobs / Description |
|----------|------|---------|---------------------|
| **Lint Scan** | [`lint.yml`](.github/workflows/lint.yml) | Push / PR (`main`) | Runs `actionlint`, `commitlint`, `hadolint` (Dockerfile), and `shellcheck`. |
| **Security Audit** | [`security.yml`](.github/workflows/security.yml) | Push / PR (`main`) | Runs `betterleaks` secret scanning and `zizmor` workflow security audit (with SARIF upload). |
| **TEST Release** | [`test_release.yml`](.github/workflows/test_release.yml) | PR (`main`) | Runs dry-run testing for matrix image builds across [`versions.json`](versions.json), Helm chart packaging, and semantic releases. |
| **Release** | [`release.yml`](.github/workflows/release.yml) | Push (`main`) / Dispatch | Generates semantic version release and changelog, builds & publishes multi-platform container images to GHCR across all supported versions, and publishes the Helm chart to GHCR. |

---

## Configuration & Usage

### Supported Versions

Supported MySQL versions are defined in [`versions.json`](versions.json):

```json
[
  {
    "major": "9",
    "upstream": "9.7",
    "latest": true
  },
  {
    "major": "8",
    "upstream": "8.4",
    "latest": false
  }
]
```

To add or update a supported MySQL version, modify [`versions.json`](versions.json). The CI matrix builder will automatically pick up the new configuration.

### Initial Schema

The repository includes [`schema.sql`](schema.sql), which initializes the database schema on first boot when mounted to `/docker-entrypoint-initdb.d/`. If you do not require an initial schema, you can omit the mount or empty the file.

## Local Environment & Podman Setup

To ensure containerized applications and Helm charts tested locally run cleanly when deployed to OpenShift or Kubernetes, this repository is designed to be used alongside the Podman configuration in [joeckr/dotfiles](https://github.com/joeckr/dotfiles).

The dotfiles repository provides a centralized [`containers.conf`](https://github.com/joeckr/dotfiles/blob/main/containers/containers.conf) (deployed to `~/.config/containers/containers.conf`) that configures Podman to simulate OpenShift's default **`restricted-v2` Security Context Constraints (SCC)**:

| OpenShift SCC Rule | Podman Configuration | Description |
|---|---|---|
| **Random UID (`MustRunAsRange`)** | `userns = "auto"` | Allocates dynamic subordinate UID/GID ranges from `/etc/subuid` and `/etc/subgid`. Containers run unprivileged without mapping host root. |
| **Drop Capabilities** | `default_capabilities = ["NET_BIND_SERVICE"]` | Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only `NET_BIND_SERVICE`. |
| **Disallow Privileged** | `privileged = false` | Disallows privileged container execution by default. |
| **Seccomp Profile** | `seccomp_profile = "/usr/share/containers/seccomp.json"` | Enforces the runtime default seccomp profile (`RuntimeDefault`). |
| **Namespace Isolation** | `cgroupns`, `ipcns`, `pidns`, `utsns = "private"` | Enforces private container namespaces (host namespaces are forbidden in restricted SCC). |

### macOS Podman Machine Integration

On macOS, the dotfiles installer script (`brew/podman.sh`) automates the machine lifecycle:

1. Deploys `containers/containers.conf` to `~/.config/containers/containers.conf` on the host.
2. Initializing `podman machine init` automatically mounts `~/.config/containers` into `/etc/containers` inside the Fedora CoreOS VM.
3. Automatically symlinks `/etc/containers/containers.conf` to the VM user's config (`~core/.config/containers/containers.conf`) and restarts the Podman API service so all container executions immediately enforce these constraints.

## Testing with Podman Compose

Two Compose configurations are provided to facilitate testing, benchmarking, and debugging:

### 1. Upstream Baseline (`compose.upstream.yml`)

The [`compose.upstream.yml`](compose.upstream.yml) file runs the original, unmodified upstream container image (`mysql:9-oracle`):

```sh
# Start upstream container
podman compose -f compose.upstream.yml up -d
```

**Why test upstream?**
Running the unmodified image against your SCC-compliant Podman setup simulates deploying standard public images directly into OpenShift. This will typically surface common failures:
- Processes attempting to run as `root` (UID 0) or user `mysql`.
- Inability to write to database or initialization directories without appropriate group 0 (`root` group) permissions.
- Inability to perform root operations like `chown` due to dropped capabilities.

### 2. Modified Image (`compose.yml`)

The [`compose.yml`](compose.yml) file builds and runs the customized `Dockerfile` containing the adaptations required for OpenShift and rootless environments:

```sh
# Build and start the modified compliant container
podman compose up -d --build

# Or via mise
mise run compose
```

This verified configuration applies:
- Non-root user execution (`USER 1031`).
- Root group ownership (`chgrp -R 0`) and group read/write permissions (`chmod -R g+rwX`) on `/var/lib/mysql`, `/var/run/mysql`, `/var/log/mysql`, `/etc/mysql`, and `/docker-entrypoint-initdb.d`.
- Persistent volume storage via `mysql_data`.
- Automatic schema initialization by mounting [`schema.sql`](schema.sql) into `/docker-entrypoint-initdb.d/schema.sql:z`.

**Default Credentials:**
- **Port:** `3306`
- **Database:** `mysql`
- **User:** `mysql`
- **Password:** `replaceme`
- **Root Password:** `really_replaceme`

### Stopping Containers

```sh
# Stop modified compose stack
podman compose down
# or: mise run down

# Stop upstream compose stack
podman compose -f compose.upstream.yml down

# View logs
podman compose logs -f
# or: mise run logs
```

### Local Helm Testing (Podman Play Kube)

Test rendered Helm chart manifests directly in Podman without needing a remote cluster:

```sh
# Render Helm template and run pods locally via podman play kube
mise run play

# Stop and tear down local pods
mise run downplay
```

### Deployment with Helm

The Helm chart is located in the [`chart/`](chart/) directory:

```bash
# Lint the chart
helm lint chart/

# Install chart locally
helm install my-mysql ./chart -f chart/values.yaml
```

---

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
