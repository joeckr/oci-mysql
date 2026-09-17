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
- **Local Tooling with mise & hk**: Hermetic developer toolchains and git hooks configured out of the box.

---

## Local Development Setup

This project uses **[mise](https://mise.jdx.dev/)** for managing developer CLI tools and task execution, and **[hk](https://github.com/jdx/hk)** for managing and running git hooks.

### Prerequisites

Ensure you have `mise` and Docker installed on your machine.

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
| `mise run build` | `docker buildx build ...` | Build the local test container image for `linux/amd64`. |
| `mise run compose` | `docker compose up -d --build` | Start the local container environment using Docker Compose. |
| `mise run trivy-fs` | `trivy fs .` | Scan local repository filesystem for security vulnerabilities. |
| `mise run trivy-image` | `trivy image ...` | Build image and run Trivy vulnerability scan on container. |

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

## Support

If you find this project useful, consider supporting my work on [Ko-fi](https://ko-fi.com/joeckr):

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/joeckr)

## License

Please refer to the `LICENSE` file for details.
