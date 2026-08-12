# oc-mysql

This project exists for those who want to run mysql in a rootless environment, specifically OpenShift (oc) and OKD.

This repo also support building multiple versions with GitHub Actions. It does this from one Dockerfile and creates a matrix of builds based off the supported versions in the `versions.json` file. You can also take this Dockerfile and build it for any version of mysql you want (just keep in mind non UBI versions may require different commands). IF there is a version you want that is not supported, please open an issue or submit a PR.

For deployment be sure to reference the docker-compose.yml file or the helm chart.

We also mount a `schema.sql` file. This file is used to initialize the database schema on first run. If you have your own schema to initialize, you can mount it here OR if you do not need a schema at all please omit it.

Everything else should be straightforward if you are familiar with using mysql in a container.
