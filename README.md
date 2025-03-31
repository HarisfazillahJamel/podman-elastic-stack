# podman-elastic-stack
podman-elastic-stack from elastic docker documentation

# Elasticsearch 8.17.4 Setup with Podman on Wolfi Image

This bash script automates the setup of Elasticsearch version 8.17.4 using Podman and the hardened Wolfi Linux image. It follows the official Elastic documentation for Docker but adapts it for Podman.

## Description

The script performs the following actions:

1.  Installs Podman and Podman Compose if they are not already present.
2.  Pulls the official Elasticsearch Wolfi hardened Docker image for version 8.17.4.
3.  Optionally installs and verifies the image signature using Cosign.
4.  Starts an Elasticsearch container named `es01` using `podman-compose`.
5.  Retrieves and stores the initial Elasticsearch password and Kibana enrollment token.
6.  Copies the SSL certificate from the Elasticsearch container to a local directory.
7.  Makes a REST API call to the Elasticsearch instance to verify the setup.

## Prerequisites

* A Linux system with `sudo` privileges.
* `dnf` package manager (common on Red Hat-based distributions like the one shown in the initial prompt).

## Usage

1.  Save the bash script to a file (e.g., `setup_elasticsearch.sh`).
2.  Make the script executable: `chmod +x setup_elasticsearch.sh`.
3.  Run the script: `./setup_elasticsearch.sh`.

The script will create a directory named `elk-wolfi` in the same directory where the script is located to store configuration and temporary files.

## Bugs Encountered and Solutions

During the development of this script, we encountered and resolved the following issues:

* **`curl: option --user-file: is unknown`**: This error occurred when trying to use the `--user-file` option with `curl`. It was resolved by explicitly using the full path to the `curl` executable (`/usr/bin/curl`) to ensure the correct version was being used.

* **`401 Unauthorized` errors with `-H` and Base64 authentication**: Initially, the script attempted to authenticate with Elasticsearch using the `-H` option and a manually constructed `Authorization: Basic` header with Base64 encoded credentials. This resulted in `401 Unauthorized` errors. Multiple attempts were made with different quoting and variable expansion techniques, but the issue persisted.

* **`.netrc` authentication not working**: We tried using a `.netrc` file to provide credentials to `curl` using the `--netrc-file` option. This approach also did not resolve the authentication issue.

* **`curl: (6) Could not resolve host: Basic`**: After removing double quotes and curly braces from the `curl -H` command, `curl` started to misinterpret the `Authorization` header, leading to this "Could not resolve host" error. This was fixed by ensuring the entire header value passed to `-H` was enclosed in double quotes.

* **Final Solution**: The authentication was finally successful using the `-u` option of `curl`, which allows providing the username and password directly in the format `username:password`.

## Stopping and Pruning Podman Elasticsearch

To stop and clean up the Elasticsearch container and network created by the script, navigate to the `elk-wolfi` directory and run the following commands:

```bash
cd elk-wolfi
podman-compose down
