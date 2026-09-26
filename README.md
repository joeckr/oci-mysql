# oci-mysql

This repository provides an OpenShift (oc) and OKD-compatible rootless MySQL container image and Helm deployment, designed to run securely under arbitrary user IDs (rootless UID/GID) while maintaining compatibility with standard MySQL entrypoints.

The repository also supports multi-version image builds using GitHub Actions matrix jobs driven by [`versions.json`](versions.json), as well as Helm chart packaging and local development workflows.

---

## Features

- **Rootless Image Builds**: Engineered to build cleanly in unprivileged, rootless container builders without requiring host root or privileged daemon sockets.
- **Rootless & OpenShift-Ready**: Runs as non-root user (`USER 1031`) with root group permissions (`GID 0`) across MySQL data, run, log, and initialization directories.
- **Talos Linux Compatibility**: Fully compliant with upstream Kubernetes Pod Security Standards (`restricted` PSS/PSA level) suited for Talos Linux's immutable, hardened architecture.
- **Multi-Version Build Matrix**: Automatically builds supported MySQL versions defined in [`versions.json`](versions.json) via GitHub Actions.
- **Schema Initialization**: Auto-mounts [`schema.sql`](schema.sql) into `/docker-entrypoint-initdb.d/` for automatic first-run database initialization.
- **Multiple Deployment Options**: Easily deployed via Docker Compose or Helm chart.
- **Automated CI/CD**: Centralized reusable workflows for linting, security scanning, dry-run PR testing, matrix builds, Helm publishing, and semantic releases.
- **Local Tooling with mise & hk**: Hermetic developer toolchains and git hooks configured out of the box with a multi-tier testing pipeline.

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

| Task | Description | Command |
|---|---|---|
| `install` | Install Git hooks (`pre-commit` and `commit-msg`). | `hk install --mise` |
| `hk` (or `check`) | Run all checks across the repository. | `hk check --all` |
| `compose` | Start local container environment using Podman Compose. | `podman compose up -d --build` |
| `down` | Stop local Podman Compose stack. | `podman compose down` |
| `logs` | Follow Podman Compose logs. | `podman compose logs -f` |
| `play` | Test Helm chart manifests locally with Podman Play Kube. | `podman play kube rendered.yaml --publish-all` |
| `play-d` | Stop and tear down Podman Play Kube pods. | `podman play kube rendered.yaml --down` |
| `helm-d` | Build Helm chart dependencies. | `helm dependency build chart/` |
| `helm-l` | Lint the Helm chart. | `helm lint chart/` |
| `helm-t` | Render Helm chart templates to `rendered.yaml`. | `helm template test chart/ > rendered.yaml` |
| `helm-i` | Install the Helm chart to the current Kubernetes cluster. | `helm install test chart/` |
| `helm-u` | Uninstall the Helm chart release from the cluster. | `helm uninstall test` |
| `build` | Build local test container image for `linux/amd64`. | `podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/mysql:test . --load` |
| `trivy-fs` | Scan local repository filesystem for security vulnerabilities. | `trivy fs .` |
| `trivy-i` | Build image and run Trivy vulnerability scan on container. | `trivy image ghcr.io/joeckr/mysql:test` |

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

## Security & Compliance Architecture

Both OpenShift and Talos Linux prioritize workload security and least privilege, but they enforce and evaluate constraints through different mechanisms. This repository is architected to satisfy both environments without code changes.

### OpenShift Compliance (`restricted-v2` SCC)

OpenShift uses **Security Context Constraints (SCC)** to control pod permissions. Under the default `restricted-v2` SCC:
- **Arbitrary Dynamic UIDs**: OpenShift assigns a random UID from a dedicated per-namespace range (e.g., `1000670000`). Containers cannot assume a fixed UID like `1000`.
- **Root Group (GID 0)**: Files and directories required at runtime (`/var/lib/mysql`, `/var/run/mysql`, `/var/log/mysql`, `/etc/mysql`, `/docker-entrypoint-initdb.d`) are owned by group 0 (`chgrp -R 0`) with group read/write permissions (`chmod -R g+rwX`) so the dynamically assigned UID can access them.
- **Dropped Capabilities**: Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only unprivileged operations (and `NET_BIND_SERVICE` when needed).
- **Unprivileged Ports**: Listens on standard port `3306` without requiring elevated privileges.

### Talos Linux Compliance (Kubernetes PSS `restricted`)

Talos Linux is an immutable, minimal, secure-by-default Kubernetes operating system with no SSH, no interactive shell, and an immutable root filesystem. In Talos clusters:
- **Pod Security Standards (PSS)**: Workload namespaces enforce the Kubernetes **Pod Security Admission (PSA)** `restricted` profile.
- **Must Run As Non-Root**: The pod specification must set `securityContext.runAsNonRoot: true`. Containers cannot execute as UID 0.
- **Drop All Capabilities**: The container specification explicitly drops all Linux capabilities (`capabilities: drop: ["ALL"]`).
- **Disallow Privilege Escalation**: Sets `securityContext.allowPrivilegeEscalation: false` to prevent child processes from acquiring more privileges than the parent.
- **Seccomp Profile**: Pods enforce `seccompProfile: { type: RuntimeDefault }`.
- **Credential Protection**: Best practice sets `automountServiceAccountToken: false` to avoid leaking Kubernetes API tokens to database containers.
- **Persistent Storage**: Integrates with CSI storage providers (e.g., Local Path Provisioner, OpenEBS Mayastor, Rook-Ceph) via configurable PVC StorageClass.

### Rootless Build Environment Compliance

Building container images inside secure or unprivileged environments (such as rootless Podman/Buildah on developer workstations, or unprivileged Kubernetes CI runners like Tekton or Kaniko) requires that the build process itself does not rely on host `root` privileges or the legacy root-owned Docker daemon socket (`/var/run/docker.sock`).

This repository's `Dockerfile` is engineered for complete rootless build support:
- **No Host Root Required**: Builds execute and succeed cleanly under unprivileged user namespaces without needing `sudo` or privileged container builders.
- **User Namespace Friendly Permissions**: Layer modifications rely on `chgrp -R 0` and group-based permissions (`g+rwX`), which map cleanly into subordinate UID/GID allocations (`/etc/subuid` and `/etc/subgid`) without failing on host-restricted `chown` operations.
- **Unprivileged Local Build**: Run `mise run build` (`podman buildx build --platform linux/amd64 -t ghcr.io/joeckr/mysql:test . --load`) or `mise run compose` to build locally without root escalation.

### Compliance Matrix

| Security Dimension | OpenShift (`restricted-v2` SCC) | Talos Linux (Kubernetes PSS `restricted`) | Implementation in This Repo |
|---|---|---|---|
| **Build Execution** | Rootless builder compatible | Rootless builder compatible | Builds unprivileged via rootless Podman/Buildah (`mise run build`) |
| **User ID** | Dynamic arbitrary UID (`MustRunAsRange`) | Non-root UID (`runAsNonRoot: true`) | `USER 1031` in Dockerfile + `runAsNonRoot: true` in Helm |
| **Group Permissions** | Requires GID 0 (`root`) with `g+rwX` | Compatible with GID 0 / unprivileged groups | `chgrp -R 0` & `chmod -R g+rwX` on runtime paths |
| **Capabilities** | Drops root caps; allows `NET_BIND_SERVICE` | Must drop `ALL` capabilities | `capabilities.drop: ["ALL"]` in Helm chart |
| **Privilege Escalation** | Prohibited | `allowPrivilegeEscalation: false` | Configured in Helm `securityContext` |
| **Seccomp Profile** | `RuntimeDefault` | `RuntimeDefault` or `Localhost` | `seccompProfile: { type: RuntimeDefault }` |
| **Service Account Token** | Optional | Recommended disabled | Hardened in pod configuration |
| **Port Binding** | Unprivileged (> 1024) | Unprivileged (> 1024) | Listens on port `3306` |
| **Storage Layer** | OpenShift StorageClass | Talos CSI StorageClass | Standard PVC template with configurable `storageClass` |

---

## Local Environment & Podman Setup

To ensure containerized applications and Helm charts tested locally run cleanly when deployed to OpenShift or Talos Linux, this repository is designed to be used alongside the Podman configuration in [joeckr/dotfiles](https://github.com/joeckr/dotfiles).

The dotfiles repository provides a centralized [`containers.conf`](https://github.com/joeckr/dotfiles/blob/main/containers/containers.conf) (deployed to `~/.config/containers/containers.conf`) that configures Podman to simulate OpenShift and Talos Linux runtime restrictions:

| Security Rule | Podman Configuration | Description |
|---|---|---|
| **Random UID (`MustRunAsRange`)** | `userns = "auto"` | Allocates dynamic subordinate UID/GID ranges from `/etc/subuid` and `/etc/subgid`. Containers run unprivileged without mapping host root. |
| **Drop Capabilities** | `default_capabilities = ["NET_BIND_SERVICE"]` | Drops standard root capabilities (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID`, `SETGID`, `SYS_CHROOT`, etc.) and permits only `NET_BIND_SERVICE`. |
| **Disallow Privileged** | `privileged = false` | Disallows privileged container execution by default. |
| **Seccomp Profile** | `seccomp_profile = "/usr/share/containers/seccomp.json"` | Enforces the runtime default seccomp profile (`RuntimeDefault`). |
| **Namespace Isolation** | `cgroupns`, `ipcns`, `pidns`, `utsns = "private"` | Enforces private container namespaces (host namespaces are forbidden in restricted profiles). |

### macOS Podman Machine Integration

On macOS, the dotfiles installer script (`brew/podman.sh`) automates the machine lifecycle:

1. Deploys `containers/containers.conf` to `~/.config/containers/containers.conf` on the host.
2. Initializing `podman machine init` automatically mounts `~/.config/containers` into `/etc/containers` inside the Fedora CoreOS VM.
3. Automatically symlinks `/etc/containers/containers.conf` to the VM user's config (`~core/.config/containers/containers.conf`) and restarts the Podman API service so all container executions immediately enforce these constraints.

---

## Testing & Validation Process

This repository defines a 4-tier testing process to validate container security, manifest generation, and runtime compatibility from local development through to production cluster deployment.

```
┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐     ┌─────────────────────────┐
│ Tier 1: Upstream Test   │ ──> │ Tier 2: Modified Test   │ ──> │ Tier 3: Podman Play     │ ──> │ Tier 4: Talos Cluster   │
│ Surface root & cap gaps │     │ Verify non-root & fixes │     │ Validate K8s manifests  │     │ Live Helm verification  │
│ (compose.upstream.yml)  │     │ (compose.yml)           │     │ (podman play kube)      │     │ (helm install)          │
└─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘     └─────────────────────────┘
```

### Tier 1: Upstream Baseline Comparison (`compose.upstream.yml`)

The [`compose.upstream.yml`](compose.upstream.yml) configuration runs the original, unmodified upstream container image (`mysql:9-oracle`):

```sh
# Start upstream container
podman compose -f compose.upstream.yml up -d

# Stop upstream container
podman compose -f compose.upstream.yml down
```

**Why test upstream?**
Running the unmodified image against your restricted Podman environment simulates deploying standard public images directly into OpenShift or Talos Linux. This will typically surface common failures:
- Processes attempting to run as `root` (UID 0) or user `mysql`.
- Inability to write to database or initialization directories without appropriate group 0 (`root` group) permissions.
- Inability to perform root operations like `chown` due to dropped capabilities.

---

### Tier 2: Modified Image Local Validation (`compose.yml`)

The [`compose.yml`](compose.yml) configuration builds and runs the customized `Dockerfile` containing the adaptations required for OpenShift and Talos Linux:

```sh
# Build and start the modified compliant container
mise run compose
# or: podman compose up -d --build

# View container logs
mise run logs
# or: podman compose logs -f

# Stop modified stack
mise run down
# or: podman compose down
```

**What this verifies:**
- Rootless image build and layer assembly without host root privileges.
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

---

### Tier 3: Local Kubernetes Manifest Testing (`mise run play`)

Before deploying to an actual Kubernetes cluster, you can test the rendered Kubernetes manifests locally using Podman's built-in `play kube` feature.

```sh
# Render templates and play Kubernetes manifests locally
mise run play

# Teardown the played pod and resources
mise run play-d
```

**How `mise run play` works:**
1. Triggers the dependent task `mise run helm-t`, which executes:
   ```sh
   helm dependency build chart/
   helm template test chart/ > rendered.yaml
   ```
2. Executes `podman play kube rendered.yaml --publish-all`, which:
   - Reads the multi-document Kubernetes YAML (`ConfigMap`, `PersistentVolumeClaim`, `Service`, `Deployment`).
   - Creates a local Podman pod matching the Kubernetes `Deployment` specification.
   - Applies the pod's `securityContext` (`runAsNonRoot: true`, capabilities drop, seccomp profile).
   - Mounts the persistent volume and ConfigMap into the container at `/var/lib/mysql` and `/docker-entrypoint-initdb.d/`.
   - Exposes container port `3306`.

**Inspecting the local play deployment:**
```sh
# View running pods created by play kube
podman pod ps

# View container status within the pod
podman ps --filter "pod=mysql"

# Check container logs within the pod
podman logs -f mysql-pod-mysql
```

**Teardown:**
```sh
mise run play-d
# or: podman play kube rendered.yaml --down
```

---

### Tier 4: Cluster Deployment & Testing on Talos Linux (`mise run helm-i`)

The final phase validates the workload on a live **Talos Linux** Kubernetes cluster. This tests real-world Pod Security Admission (PSA) enforcement, CSI storage provisioning, network policies, and database startup.

#### 1. Cluster Prerequisites & Configuration

Ensure your `kubectl` context points to your Talos cluster:
```sh
kubectl config current-context
# Example: admin@my-talos-cluster
```

Ensure the container image is accessible to your Talos nodes (e.g., built and pushed to GitHub Container Registry `ghcr.io` or your local registry):
```sh
# Build image locally with target tag
mise run build
```

Configure `chart/values.yaml` for Talos Linux:
- **StorageClass**: If your Talos cluster uses a specific CSI storage provisioner (e.g., `local-path`, `mayastor`, `ceph-block`), configure `mysql.storageClass` in `values.yaml` or leave it empty `""` to use the cluster's default StorageClass.
- **Security Context & fsGroup**: Under `mysql.podSecurityContext`, `fsGroup: 1031` ensures mounted storage has permissions accessible by the container user in vanilla Kubernetes / Talos Linux. If deploying to OpenShift, remove or comment out `fsGroup` as OpenShift's SCC allocates fsGroup dynamically.

#### 2. Linting & Template Validation

```sh
# Lint the chart for syntax and formatting errors
mise run helm-l

# Inspect the rendered manifests before installation
mise run helm-t
cat rendered.yaml
```

#### 3. Deploying to the Talos Cluster

Install the Helm chart release:
```sh
mise run helm-i
# or: helm install test chart/
```

#### 4. Verifying Talos PSS Compliance & Health

Check the pod status and verify that Talos Linux Pod Security Admission (PSA) allowed the pod to run:

```sh
# Check pod deployment status
kubectl get pods -l app=mysql

# Inspect pod details and events for security policy rejections
kubectl describe pod -l app=mysql
```

> [!TIP]
> If your namespace enforces the `restricted` Pod Security Standard and there are non-compliant settings (such as missing `runAsNonRoot` or un-dropped capabilities), `kubectl describe pod` will show warning events from the `pod-security` admission controller.

Check the application logs:
```sh
kubectl logs -l app=mysql -f
```

Verify persistent storage and schema initialization inside the pod:
```sh
kubectl exec -it deployment/mysql -- ls -la /var/lib/mysql
kubectl exec -it deployment/mysql -- mysql -u mysql -p -e "SHOW DATABASES;"
```

Verify network access via port-forwarding:
```sh
kubectl port-forward svc/mysql 3306:3306
```

#### 5. Uninstalling from the Talos Cluster

When testing is complete, clean up the release:
```sh
mise run helm-u
# or: helm uninstall test
```

---

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
