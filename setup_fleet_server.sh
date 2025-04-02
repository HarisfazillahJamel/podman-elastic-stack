#!/bin/bash
# Script to set up Fleet Server using Podman with the hardened Wolfi image.
# This script should be run after setup_kibana.sh and setup_elasticsearch.sh.
# GNU GENERAL PUBLIC LICENSE Version 3
# Harisfazillah Jamel and Google Gemini
# 2 Apr 2025
### STILL WORK IN PROGRESS

set -e

# --- Determine Script's Directory ---
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# --- Variables ---
ELK_BASE_DIR="${SCRIPT_DIR}"
ELK_DIR="${ELK_BASE_DIR}/elk-wolfi"
CERT_DIR="${ELK_DIR}/certs"
FLEET_SERVER_IMAGE_NAME="docker.elastic.co/elastic-agent/elastic-agent-complete-wolfi" # Use the complete image.
FLEET_SERVER_CONTAINER_NAME="fleet-server"
FLEET_SERVER_PORT="8220"
NETWORK_NAME="elk-wolfi_elastic" # Use the same network as Elasticsearch and Kibana
TEMP_CREDENTIALS_FILE="${ELK_DIR}/temp_credentials.txt"
# --- Helper Functions ---
info() {
  echo "--- $1 ---"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Step 1: Check Prerequisites ---
info "Step 1: Check Prerequisites"

if ! command_exists podman; then
  echo "Error: Podman is not installed. Please run the setup_elasticsearch.sh script first or install Podman."
  exit 1
fi

if ! command_exists podman-compose; then
  echo "Error: podman-compose is not installed. Please run the setup_elasticsearch.sh script first or install podman-compose."
  exit 1
fi

# --- Step 2: Check for Certificate File ---
info "Step 2: Check for Elasticsearch Certificate"
CERT_FILE="${CERT_DIR}/http_ca.crt"
if [ ! -f "${CERT_FILE}" ]; then
  echo "Error: Elasticsearch certificate file not found at '${CERT_FILE}'. Please ensure the setup_elasticsearch.sh script was run successfully."
  exit 1
fi

# --- Step 3: Check Elasticsearch Network ---
info "Step 3: Check Elasticsearch Network"
if ! podman network exists "${NETWORK_NAME}"; then
  echo "Error: The Podman network '${NETWORK_NAME}' does not exist."
  echo "Please ensure that the setup_elasticsearch.sh or setup_kibana.sh script was run successfully and created this network."
  exit 1
fi
info "Podman network '${NETWORK_NAME}' exists."

# --- Step 4: Check Elasticsearch Status and Get Version ---
info "Step 4: Check Elasticsearch Status and Get Version"

# Attempt to retrieve the Elasticsearch password from the temporary file
if [ -f "${TEMP_CREDENTIALS_FILE}" ]; then
  ELASTIC_PASSWORD=$(grep "Elastic password set to:" "${TEMP_CREDENTIALS_FILE}" | sed 's/.*Elastic password set to: //' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
else
  echo "Error: Temporary credentials file '${TEMP_CREDENTIALS_FILE}' not found. Please ensure the setup_elasticsearch.sh script was run successfully."
  exit 1
fi

if [ -z "${ELASTIC_PASSWORD}" ]; then
  echo "Error: Elasticsearch password not found in '${TEMP_CREDENTIALS_FILE}'. Please check the file."
  exit 1
fi

ES_STATUS=$(curl -s --cacert "${CERT_FILE}" -u "elastic:${ELASTIC_PASSWORD}" "https://localhost:9200")

if [[ "$ES_STATUS" == *"You Know, for Search"* ]]; then
  info "Elasticsearch is running."
  ELASTICSEARCH_VERSION=$(echo "$ES_STATUS" | jq -r '.version.number')
  info "Elasticsearch version found: ${ELASTICSEARCH_VERSION}"
else
  echo "Error: Elasticsearch is not running or the status check failed."
  echo "Status output: ${ES_STATUS}"
  exit 1
fi

# --- Step 5: Pull Fleet Server Docker Image (Wolfi hardened image) ---
info "Step 5: Pull Fleet Server Docker Image (Wolfi hardened image)"
# Use the complete image for Fleet Server
FLEET_SERVER_VERSION="${ELASTICSEARCH_VERSION}" # Set Fleet Server version to match Elasticsearch
FLEET_SERVER_IMAGE="${FLEET_SERVER_IMAGE_NAME}:${FLEET_SERVER_VERSION}"
podman pull "${FLEET_SERVER_IMAGE}"

# --- Step 6: Optional: Install and Verify Cosign ---
info "Step 6: Optional: Install and Verify Cosign"
if ! command_exists cosign; then
  info "Cosign not found. Please install it manually if you wish to verify the image signature."
else
  info "Cosign found. Verifying Fleet Server image signature..."
  wget https://artifacts.elastic.co/cosign.pub -O cosign.pub
  cosign verify --key cosign.pub "${FLEET_SERVER_IMAGE}"
  rm cosign.pub
fi

# --- Step 6.5: Get Elasticsearch Container Name ---
info "Step 6.5: Get Elasticsearch Container Name"
ES_CONTAINER_NAME=$(podman inspect es01 | jq -r '.[0].Name' | sed 's/\///')
echo "Elasticsearch container name: ${ES_CONTAINER_NAME}"

# --- Step 7: Prompt for Fleet Service Token and Policy ID ---
info "Step 7: Prompt for Fleet Service Token and Policy ID"
read -p "Enter the Fleet Service Token (generated from Fleet policy in Kibana): " FLEET_SERVER_SERVICE_TOKEN
if [ -z "${FLEET_SERVER_SERVICE_TOKEN}" ]; then
  echo "Error: Fleet Service Token is required.  Please provide the token."
  exit 1
fi
echo "Fleet Service Token provided."

read -p "Enter the Fleet Server Policy ID: " FLEET_SERVER_POLICY_ID
if [ -z "${FLEET_SERVER_POLICY_ID}" ]; then
  echo "Error: Fleet Server Policy ID is required.  Please provide the Policy ID."
  exit 1
fi
echo "Fleet Server Policy ID provided."


# --- Step 8: Start Fleet Server Container using podman-compose ---
info "Step 8: Start Fleet Server Container using podman-compose"
#  Create a podman-compose.yml file for Fleet Server.
cat > "${ELK_DIR}/podman-compose-fleet-server.yml" <<EOL
version: '3.8'
services:
  fleet-server:
    image: ${FLEET_SERVER_IMAGE}
    container_name: ${FLEET_SERVER_CONTAINER_NAME}
    ports:
      - "${FLEET_SERVER_PORT}:${FLEET_SERVER_PORT}"
    environment:
      - FLEET_SERVER_ENABLE=true # Set to true to bootstrap Fleet Server
      - FLEET_SERVER_ELASTICSEARCH_HOST=https://\${${ES_CONTAINER_NAME}}:9200 # Use https and the container name
      - FLEET_SERVER_SERVICE_TOKEN=\${FLEET_SERVER_SERVICE_TOKEN} # Fleet service token, from user input.
      - FLEET_SERVER_POLICY_ID=\${FLEET_SERVER_POLICY_ID} # Fleet Server policy ID.
    user: root # To run Synthetics Browser tests, this should be elastic-agent, but Fleet Server needs root.
    volumes:
      - fleet_server_data:/data/fleet_server
    networks:
      - ${NETWORK_NAME}
volumes:
  fleet_server_data:
networks:
  ${NETWORK_NAME}:
    external: true
EOL

cd "${ELK_DIR}"
podman-compose -f podman-compose-fleet-server.yml up -d

# --- Step 9: Wait for Fleet Server to Start ---
info "Step 9: Wait for Fleet Server to Start"
MAX_WAIT_SECONDS=60
echo "Waiting for Fleet Server to start..."
for i in $(seq "$MAX_WAIT_SECONDS" -1 1); do
  echo "Waiting for Fleet Server to start... $i seconds remaining..."
  podman ps -a --filter name="${FLEET_SERVER_CONTAINER_NAME}"
  sleep 1
done
echo "Fleet Server start process complete. You can check the status above."

echo ""
info "Fleet Server setup complete!  It is running on port ${FLEET_SERVER_PORT}."
echo ""
info "To enroll agents, you will need the enrollment token from Kibana."
info "Please refer to the Kibana documentation for instructions on how to create and use enrollment tokens."
echo ""
info "You can check the service status by running:"
echo "podman ps -a"
echo ""
info "Important: If you intend to run Synthetics Browser tests with this Fleet Server, after the setup is complete, edit the"
echo " 'user' parameter in the '${ELK_DIR}/podman-compose-fleet-server.yml' file and change it from 'root' to 'elastic-agent'."
echo "  Then, restart the Fleet Server container by running:"
echo "  podman-compose -f ${ELK_DIR}/podman-compose-fleet-server.yml down && podman-compose -f ${ELK_DIR}/podman-compose-fleet-server.yml up -d"
echo "  Note: Synthetic tests cannot run under the root user."
