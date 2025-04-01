# Setup Elasticsearch 8.17.4 with Podman (Wolfi Hardened Image)

This script automates the setup of Elasticsearch version 8.17.4 using Podman and the hardened Wolfi image, following the official Elastic Docker documentation.

## Prerequisites

* **Podman:** Ensure Podman is installed on your system. You can find installation instructions for various distributions on the [Podman Installation Guide](https://podman.io/getting-started/installation).
* **Podman Compose:** Podman Compose is required to manage the Elasticsearch container. Installation instructions can also be found on the Podman website or through your distribution's package manager (often in an `epel-release` repository for RPM-based systems).

## Usage

1.  **Save the Script:** Save the provided bash script as `setup-elasticsearch.sh` or any other name you prefer.
2.  **Make it Executable:** Open your terminal and navigate to the directory where you saved the script. Make the script executable using the command:
    ```bash
    chmod +x setup_elasticsearch.sh
    ```
3.  **Run the Script:** Execute the script using:
    ```bash
    ./setup_elasticsearch.sh
    ```
    You might need `sudo` if the script requires root privileges for installing Podman or Podman Compose, depending on your system configuration.

## What the Script Does

1.  **Installs Podman and Podman Compose:** If not already installed, the script attempts to install Podman and Podman Compose using `dnf` (for Fedora, CentOS, etc.).
2.  **Pulls Elasticsearch Image:** Downloads the official Elasticsearch 8.17.4 hardened Wolfi image from Docker Hub.
3.  **Optional Cosign Verification:** If `cosign` is installed, the script downloads the Elastic public key and verifies the signature of the Elasticsearch image.
4.  **Starts Elasticsearch Container:** Creates and starts an Elasticsearch container named `es01` using `podman-compose`. The container exposes port 9200.
5.  **Retrieves Elasticsearch Password:** After Elasticsearch starts, the script resets the password for the `elastic` user and retrieves the new password. This password is saved in a temporary file (`elk-wolfi/temp_credentials.txt`) and also printed to the console.
6.  **Retrieves Kibana Enrollment Token:** The script generates a Kibana enrollment token, which is also saved in the temporary credentials file and printed to the console.
7.  **Copies SSL Certificate:** The SSL certificate used by Elasticsearch for HTTPS is copied from the container to the `elk-wolfi/certs` directory.
8.  **Makes REST API Call:** The script uses `curl` to make a basic API call to Elasticsearch to verify that it's running.
9.  **Cleans Up Credentials:** The script removes any leading or trailing whitespace or newline characters from both the Elasticsearch password and the Kibana enrollment token.

## Important Information

* **Elasticsearch Password:** The newly generated password for the `elastic` user is stored in the `elk-wolfi/temp_credentials.txt` file in the same directory where you run the script. It is highly recommended to secure this password.
* **Kibana Enrollment Token:** The Kibana enrollment token is also located in the `elk-wolfi/temp_credentials.txt` file. You will need this token if you decide to set up Kibana to connect to this Elasticsearch instance.
* **Access Elasticsearch:** Once the script completes successfully, you can access Elasticsearch at `https://localhost:9200`. You will be prompted for credentials. Use the username `elastic` and the password found in the `temp_credentials.txt` file.
* **Wolfi Image:** This script uses the hardened Wolfi image for Elasticsearch, which might have specific system requirements. Ensure your system meets these requirements if you encounter any issues.

## Next Steps (Optional)

* **Set up Kibana:** You can use the Kibana enrollment token to set up a Kibana instance to visualize and manage your Elasticsearch data. Refer to the official Elastic documentation for instructions on setting up Kibana with Docker or Podman.
* **Configure Elasticsearch:** For production environments, you will likely want to configure Elasticsearch further, such as setting up a cluster, configuring data paths, and managing resources.

Enjoy using your new Elasticsearch setup!

Harisfazillah Jamel aka LinuxMalaysia
20250331


# Kibana Setup Script with Podman

## Description

This script automates the setup of Kibana 8.17.4 using Podman with the hardened Wolfi image. It follows the official Docker documentation from Elastic.  The script configures Kibana to run with its own custom `kibana.yml` and utilizes Podman for container management.

**Important Note:** Wolfi images might have specific kernel or dependency requirements.

## Prerequisites

Before running this script, ensure the following prerequisites are met:

* **Podman:** Podman must be installed on the system.
* **podman-compose:** Podman Compose must be installed.
* **Elasticsearch Setup:** The Elasticsearch setup script (`setup_elasticsearch.sh`) should be executed successfully *before* running this script, as this script relies on the Elasticsearch environment.
* **Elasticsearch Certificate:** The script requires the Elasticsearch certificate file (`http_ca.crt`), which is generated during the Elasticsearch setup.
* **Network:** The Podman network created by the Elasticsearch setup script must exist.
* **Elasticsearch Password:** The Elasticsearch password must be available in the temporary credentials file created by the Elasticsearch setup script.

## Features

* Automates Kibana setup using Podman.
* Uses a hardened Wolfi image for Kibana.
* Configures Kibana with a custom `kibana.yml` file.
* Sets up Kibana to communicate with Elasticsearch.
* Manages Kibana data using a Podman volume.
* Retrieves the Elasticsearch container IP address.
* Retrieves the Kibana enrollment token from Elasticsearch.
* Provides instructions for retrieving the Kibana verification code.

## How It Works

The script performs the following steps:

1.  **Checks Prerequisites:** Verifies that Podman and Podman Compose are installed and that the Elasticsearch setup has been completed.
2.  **Checks for Certificate File:** Ensures that the Elasticsearch certificate file exists.
3.  **Checks for Elasticsearch Network:** Ensures that the Podman network created by the Elasticsearch setup script exists.
4.  **Checks Elasticsearch Status and Version:**
    * Retrieves the Elasticsearch password from the temporary credentials file.
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

## Usage

1.  **Ensure Elasticsearch is Running:** Make sure Elasticsearch is set up and running *before* executing this script.
2.  **Run the Script:** Execute the script from your terminal:

    ```bash
    ./setup_kibana.sh
    ```

3.  **Review Configuration:** Review the `kibana.yml` file in the `elk-wolfi` directory and customize it as needed.
4.  **Access Kibana:** Once the script completes, access Kibana in your web browser at `http://localhost:5601`.
5.  **Retrieve Verification Code:** Run the command provided by the script to get the Kibana verification code and use it during the initial Kibana setup in your browser.

## Variables

The script uses the following variables:

* `ELK_BASE_DIR`: Base directory for ELK-related files (where the script is located).
* `ELK_DIR`: Directory for ELK-related files (`${ELK_BASE_DIR}/elk-wolfi`).
* `CERT_DIR`: Directory for SSL certificates (`${ELK_DIR}/certs`).
* `KIBANA_IMAGE_NAME`: Name of the Kibana Docker image (`docker.elastic.co/kibana/kibana-wolfi`).
* `KIBANA_CONTAINER_NAME`: Name for the Kibana container (`kib01`).
* `KIBANA_PORT`: Port on which Kibana will be accessible (`5601`).
* `NETWORK_NAME`: Name of the Podman network.
* `TEMP_CREDENTIALS_FILE`: File to store temporary credentials (like Elasticsearch password) (`${ELK_DIR}/temp_credentials.txt`).

## Helper Functions

The script defines the following helper functions:

* `info()`:  Prints informational messages with a separator.
* `command_exists()`: Checks if a command exists in the system's PATH.

## License

The script is licensed under the GNU GENERAL PUBLIC LICENSE Version 3.

Harisfazillah Jamel aka LinuxMalaysia
20250402
