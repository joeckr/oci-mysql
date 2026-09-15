# oci-mysql

This repository provides an OpenShift (oc) and OKD-compatible rootless MySQL container image and Helm deployment, designed to run securely under arbitrary user IDs (rootless UID/GID) while maintaining compatibility with standard MySQL entrypoints.

The repository also supports multi-version image builds using GitHub Actions matrix jobs driven by [`versions.json`](file:///Users/josephking/Code/oci/oci-mysql/versions.json), as well as Helm chart packaging and local development workflows.

---

## Features

- **Rootless & OpenShift-Ready**: Runs as non-root user (`USER 1031`) with root group permissions (`GID 0`) across MySQL data, run, log, and initialization directories.
- **Multi-Version Build Matrix**: Automatically builds supported MySQL versions defined in [`versions.json`](file:///Users/josephking/Code/oci/oci-mysql/versions.json) via GitHub Actions.
- **Schema Initialization**: Auto-mounts [`schema.sql`](file:///Users/josephking/Code/oci/oci-mysql/schema.sql) into `/docker-entrypoint-initdb.d/` for automatic first-run database initialization.
- **Multiple Deployment Options**: Easily deployed via Docker Compose or Helm chart.
- **Automated CI/CD**: Centralized reusable workflows for linting, security scanning, dry-run PR testing, matrix builds, Helm publishing, and semantic releases.
- **Local Tooling with mise & prek**: Hermetic developer toolchains and git hooks configured out of the box.

---

## Local Development Setup

This project uses **[mise](https://mise.jdx.dev/)** for managing developer CLI tools and task execution, and **[prek](https://github.com/jdx/prek)** for running pre-commit hooks.

### Prerequisites

Ensure you have `mise` and Docker installed on your machine.

### Tooling & Hook Installation

Install required CLI tools (`actionlint`, `hadolint`, `shellcheck`, `zizmor`, `helm`, `trivy`, `gitleaks`) and set up git hooks with a single task:

```bash
mise run install
```

This runs `prek install` to set up the Git hook in `.git/hooks/pre-commit`.

### Available mise Tasks

The following tasks are defined in [`mise.toml`](file:///Users/josephking/Code/oci/oci-mysql/mise.toml):

| Task | Command | Description |
|------|---------|-------------|
| `mise run install` | `prek install` | Install Git pre-commit hooks. |
| `mise run prek` | `prek run --all-files` | Run all pre-commit hooks across the repository. |
| `mise run build` | `docker buildx build ...` | Build the local test container image for `linux/amd64`. |
| `mise run compose` | `docker compose up -d --build` | Start the local container environment using Docker Compose. |
| `mise run trivy-fs` | `trivy fs .` | Scan local repository filesystem for security vulnerabilities. |
| `mise run trivy-image` | `trivy image ...` | Build image and run Trivy vulnerability scan on container. |

---

## Pre-Commit Hooks (prek)

Local checks are configured in [`prek.toml`](file:///Users/josephking/Code/oci/oci-mysql/prek.toml) to catch issues before pushing code:

- **Formatting & Sanitation**:
  - Trailing whitespace removal
  - End-of-file fixing
  - Syntax checks for YAML, TOML, JSON, and XML
  - Merge conflict and large file detection
  - Branch protection (blocks accidental direct commits to `main` or `master`)
- **Commit Standards**:
  - `commitlint`: Enforces Conventional Commits on commit messages (`feat:`, `fix:`, `ci:`, etc.).
- **Security & Licensing**:
  - `gitleaks`: Prevents secrets, keys, and tokens from being committed.
  - `addlicense`: Ensures proper license headers are present.
- **Linters**:
  - `hadolint`: Lints [`Dockerfile`](file:///Users/josephking/Code/oci/oci-mysql/Dockerfile).
  - `shellcheck`: Lints shell scripts.
  - `actionlint`: Validates GitHub Actions workflow files.
  - `zizmor`: Audits GitHub Actions workflows for security flaws.
  - `helm-lint`: Validates the Helm chart templates and values.

To run hooks manually across all files:

```bash
mise run prek
```

---

## Continuous Integration & Delivery (CI/CD)

The repository uses automated GitHub Actions workflows in [`.github/workflows`](file:///Users/josephking/Code/oci/oci-mysql/.github/workflows) leveraging reusable workflow templates from `joeckr/ci-templates`:

### Quality & Linting Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Hadolint** (`hadolint.yml`) | Push / PR | Lints [`Dockerfile`](file:///Users/josephking/Code/oci/oci-mysql/Dockerfile) using Hadolint. |
| **ShellCheck** (`shellcheck.yml`) | Push / PR | Analyzes shell scripts for syntax and POSIX compliance. |
| **Actionlint** (`actionlint.yml`) | Push / PR | Validates GitHub Actions workflows syntax and best practices. |
| **Zizmor** (`zizmor.yml`) | Push / PR | Scans workflows for security risks and uploads SARIF reports. |

### Security & Compliance Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Gitleaks** (`gitleaks.yml`) | Push / PR | Scans commits and repository contents for leaked secrets. |
| **Commitlint** (`commitlint.yml`) | Push / PR | Enforces Conventional Commit specifications on pull requests and commits. |

### Build, Package & Release Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| **Matrix Build Test** (`test_build.yml`) | PR | Tests building container images across all versions in [`versions.json`](file:///Users/josephking/Code/oci/oci-mysql/versions.json) with `dry-run: true`. |
| **Matrix Build & Publish** (`build.yml`) | Push `main` / tags | Builds multi-platform images for all versions in [`versions.json`](file:///Users/josephking/Code/oci/oci-mysql/versions.json) and publishes to GHCR. |
| **Test Helm Chart** (`test_helm.yml`) | PR | Validates and dry-run packages the Helm chart located in [`chart/`](file:///Users/josephking/Code/oci/oci-mysql/chart). |
| **Publish Helm Chart** (`helm.yml`) | Push `main` / tags | Packages and publishes the Helm chart to GitHub Container Registry (GHCR). |
| **Test Semantic Release** (`test_semantic.yml`) | PR | Dry-run verification of semantic versioning and release notes. |
| **Semantic Release** (`semantic.yml`) | Push `main` | Creates GitHub releases, changelog updates, and version tags automatically. |

---

## Configuration & Usage

### Supported Versions

Supported MySQL versions are defined in [`versions.json`](file:///Users/josephking/Code/oci/oci-mysql/versions.json):

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

To add or update a supported MySQL version, modify [`versions.json`](file:///Users/josephking/Code/oci/oci-mysql/versions.json). The CI matrix builder will automatically pick up the new configuration.

### Initial Schema

The repository includes [`schema.sql`](file:///Users/josephking/Code/oci/oci-mysql/schema.sql), which initializes the database schema on first boot when mounted to `/docker-entrypoint-initdb.d/`. If you do not require an initial schema, you can omit the mount or empty the file.

### Deployment with Docker Compose

To test locally with Docker Compose:

```bash
mise run compose
```

Or directly:

```bash
docker compose up -d --build
```

### Deployment with Helm

The Helm chart is located in the [`chart/`](file:///Users/josephking/Code/oci/oci-mysql/chart) directory:

```bash
# Lint the chart
helm lint chart/

# Install chart locally
helm install my-mysql ./chart -f chart/values.yaml
```
