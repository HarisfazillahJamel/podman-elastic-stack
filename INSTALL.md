# Setup Elasticsearch and Kibana with Podman (Wolfi Hardened Images)

This document provides instructions for setting up Elasticsearch 8.17.4 and Kibana 8.17.4 using Podman with hardened Wolfi images.  The setup uses Podman for container management.

## Table of Contents

* [Description](#description)
* [Prerequisites](#prerequisites)
* [Usage](#usage)
* [Elasticsearch Setup Details](#elasticsearch-setup-details)
* [Kibana Setup Details](#kibana-setup-details)
* [How to Cleanup](#how-to-cleanup)
* [Variables](#variables)
* [Helper Functions](#helper-functions)
* [License](#license)
* [References](#references)

## Description

This setup involves two primary components:

* **Elasticsearch:** Elasticsearch is set up using a bash script (`setup_elasticsearch.sh`) which automates the process of installing and configuring Elasticsearch 8.17.4 with Podman and a hardened Wolfi image.
* **Kibana:** Kibana is set up using a separate bash script (`setup_kibana.sh`) and is configured to connect to the Elasticsearch instance.

Both scripts aim to simplify the deployment of Elasticsearch and Kibana, leveraging Podman for containerization and hardened Wolfi images for enhanced security.

**Important Note:** Wolfi images might have specific kernel or dependency requirements.

## Prerequisites

Before proceeding, ensure the following prerequisites are met:

* **Podman:** Podman must be installed on your system.  Refer to the [Podman Installation Guide](https://podman.io/getting-started/installation) for instructions.
* **Podman Compose:** Podman Compose is required to manage the Elasticsearch and Kibana containers. Installation instructions can be found on the Podman website or through your distribution's package manager.
* **Operating System:** This setup is primarily designed for Linux-based systems.  For Windows, it is expected to work within a WSL2 environment.
* **Network Connectivity:** Ensure that your system has network connectivity to download the required container images and packages.

## Usage

The setup involves running two separate scripts: first for Elasticsearch, and then for Kibana.

### 1. Elasticsearch Setup

1.  **Save the Script:** Save the Elasticsearch setup script as `setup_elasticsearch.sh`.
2.  **Make it Executable:** Open your terminal, navigate to the directory where you saved the script, and make it executable:

    ```bash
    chmod +x setup_elasticsearch.sh
    ```
3.  **Run the Script:** Execute the script:

    ```bash
    ./setup_elasticsearch.sh
    ```
    You might need `sudo` if the script requires elevated privileges.

### 2. Kibana Setup

1.  **Ensure Elasticsearch is Running:** The Kibana setup script assumes that Elasticsearch is already running.  Make sure the Elasticsearch setup script has been run successfully.
2.  **Save the Script:** Save the Kibana setup script as `setup_kibana.sh`.
3.  **Make it Executable:** Make the script executable:

    ```bash
    chmod +x setup_kibana.sh
    ```
4.  **Run the Script:** Execute the script:

    ```bash
    ./setup_kibana.sh
    ```

## Elasticsearch Setup Details

The `setup_elasticsearch.sh` script performs the following actions:

1.  **Installs Podman and Podman Compose (If Necessary):** The script attempts to install Podman and Podman Compose using `dnf` (for Fedora, CentOS, etc.) if they are not already installed.
2.  **Pulls Elasticsearch Image:** Downloads the official Elasticsearch 8.17.4 hardened Wolfi image from Docker Hub.
3.  **Optional Cosign Verification:** If `cosign` is installed, the script downloads the Elastic public key and verifies the signature of the Elasticsearch image for added security.
4.  **Starts Elasticsearch Container:** Creates and starts an Elasticsearch container named `es01` using `podman-compose`. The container exposes port 9200.
5.  **Retrieves Elasticsearch Password:** After Elasticsearch starts, the script resets the password for the `elastic` user and retrieves the new password. This password is saved in a temporary file (`elk-wolfi/temp_credentials.txt`) and also printed to the console.
6.  **Retrieves Kibana Enrollment Token:** The script generates a Kibana enrollment token, which is also saved in the temporary credentials file and printed to the console.
7.  **Copies SSL Certificate:** The SSL certificate used by Elasticsearch for HTTPS is copied from the container to the `elk-wolfi/certs` directory.
8.  **Verifies Installation:** The script uses `curl` to make a basic API call to Elasticsearch to verify that it is running correctly.
9.  **Cleans Up Credentials:** The script removes any leading or trailing whitespace or newline characters from both the Elasticsearch password and the Kibana enrollment token in the temporary credentials file.

#### Important Elasticsearch Information

* **Elasticsearch Password:** The generated password for the `elastic` user is stored in the `elk-wolfi/temp_credentials.txt` file.  It is crucial to secure this file.
* **Kibana Enrollment Token:** The Kibana enrollment token is also located in the `elk-wolfi/temp_credentials.txt` file. This token is required to connect Kibana to Elasticsearch.
* **Access Elasticsearch:** Elasticsearch can be accessed at `https://localhost:9200`.  Use the username `elastic` and the password from the `temp_credentials.txt` file when prompted.
* **Wolfi Image:** The script uses the hardened Wolfi image for Elasticsearch, which may have specific system requirements.

## Kibana Setup Details

The `setup_kibana.sh` script performs the following actions:

1.  **Checks Prerequisites:** Verifies that Podman and Podman Compose are installed and that the Elasticsearch setup has been completed.
2.  **Checks for Certificate File:** Ensures that the Elasticsearch certificate file exists.
3.  **Checks for Elasticsearch Network:** Ensures that the Podman network created by the Elasticsearch setup script exists.
4.  **Checks Elasticsearch Status and Version:**
    * Retrieves the Elasticsearch password from the temporary file.
    * Checks if Elasticsearch is running and retrieves its version.
5.  **Pulls Kibana Docker Image:** Pulls the Kibana Docker image from the Docker Hub, tagged with the Elasticsearch version.
6.  **Gets Default Kibana Configuration:**
    * Creates a temporary Kibana container.
    * Copies the default `kibana.yml` file from the container to the host.
    * Stops and removes the temporary container.  The user is expected to review and customize this file.
7.  **Starts Kibana Container:**
    * Creates a `podman-compose.yml` file to define the Kibana service.
    * Starts the Kibana container using `podman-compose up`.
8.  **Waits for Kibana to Start:** Waits for the Kibana container to start.
9.  **Gets Elasticsearch Container IP Address:** Retrieves the IP address of the Elasticsearch container.
10. **Retrieves Kibana Enrollment Token:** Retrieves the Kibana enrollment token from the Elasticsearch container and saves it to the temporary credentials file.
11.  **Provides Post-Installation Information:**
    * Displays a message indicating that the Kibana setup is complete.
    * Displays the URL to access Kibana in a web browser (http://localhost:5601).
    * Displays the command to retrieve the Kibana verification code.

#### Important Kibana Information

* **Kibana Access:** Kibana will be accessible at `http://localhost:5601` after the setup is complete.
* **Kibana Configuration:** The `kibana.yml` file should be reviewed and customized as needed.

## How to Cleanup

To remove the resources created by these scripts, follow these steps:

1.  **Stop and Remove Elasticsearch and Kibana Containers:**

    ```bash
    cd ${ELK_BASE_DIR}/elk-wolfi
    podman-compose -f podman-compose-kibana.yml down
    podman-compose -f podman-compose.yml down #if you have a separate podman-compose.yml for elasticsearch
    ```

2.  **Remove the Network:**

    ```bash
    podman network prune
    ```

3.  **Delete the ELK Directory:**

    ```bash
    rm -rf ${ELK_BASE_DIR}/elk-wolfi
    ```

    This will remove the configuration files and any other data created by the scripts.

4.  **Delete the /data directory:**

    ```bash
    rm -rf /data
    ```

    **Caution:** This will delete any data stored in the `/data` directory on your system.  Only proceed if you are sure you have backed up any important data and it is safe to delete.  This directory is used for the Elasticsearch and Kibana data volume.

## Variables

The scripts use the following variables:

* `ELK_BASE_DIR`: Base directory for ELK-related files (where the script is located).
* `ELK_DIR`: Directory for ELK-related files (`${ELK_BASE_DIR}/elk-wolfi`).
* `CERT_DIR`: Directory for SSL certificates (`${ELK_DIR}/certs`).
* `KIBANA_IMAGE_NAME`: Name of the Kibana Docker image (`docker.elastic.co/kibana/kibana-wolfi`).
* `KIBANA_CONTAINER_NAME`: Name for the Kibana container (`kib01`).
* `KIBANA_PORT`: Port on which Kibana will be accessible (`5601`).
* `NETWORK_NAME`: Name of the Podman network.
* `TEMP_CREDENTIALS_FILE`: File to store temporary credentials (like Elasticsearch password) (`${ELK_DIR}/temp_credentials.txt`).

## Helper Functions

The scripts define the following helper functions:

* `info()`: Prints informational messages with a separator.
* `command_exists()`: Checks if a command exists in the system's PATH.

## License

The scripts are licensed under the GNU GENERAL PUBLIC LICENSE Version 3.

## References

* Phase 1: Install Almalinux 9 Windows Subsystem for Linux version 2 (WSL2)
    * [https://www.linuxmalaysia.com/2025/04/howto-install-wsl2-and-move-almalinux-9.html](https://www.linuxmalaysia.com/2025/04/howto-install-wsl2-and-move-almalinux-9.html)
* HOWTO: Install Almalinux 9 WSL2 and Move AlmaLinux 9 to Another Drive
    * [https://gist.github.com/linuxmalaysia/491098eea7160aa184e85c19d6b68acc](https://gist.github.com/linuxmalaysia/491098eea7160aa184e85c19d6b68acc)
* Phase 2: Install WSL2 and Move AlmaLinux 9 to Another Drive
    * [https://medium.com/@linuxmalaysia/phase-2-install-wsl2-and-move-almalinux-9-to-another-drive-bb9f9649fc59](https://medium.com/@linuxmalaysia/phase-2-install-wsl2-and-move-almalinux-9-to-another-drive-bb9f9649fc59)
* `setup_elasticsearch.sh` explain
    * [https://gist.github.com/linuxmalaysia/3c79011ceeca38e434b7e51da3fa63b8](https://gist.github.com/linuxmalaysia/3c79011ceeca38e434b7e51da3fa63b8)
* `setup_kibana.sh` explain
    * [https://gist.github.com/linuxmalaysia/7782c879be1e22469d39bb1557505623](https://gist.github.com/linuxmalaysia/7782c879be1e22469d39bb1557505623)

