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

20250331

