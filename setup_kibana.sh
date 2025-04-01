#!/bin/bash
# Script to set up Kibana 8.17.4 using Podman with the hardened Wolfi image, based on the official Docker documentation.
# Note: Using Wolfi images might have specific kernel or dependency requirements.
# https://www.elastic.co/guide/en/kibana/current/docker.html
# GNU GENERAL PUBLIC LICENSE Version 3
# Harisfazillah Jamel and Google Gemini
# 1 Apr 2025

# Script to set up Kibana using Podman with the hardened Wolfi image, based on the official Docker documentation.
# This script should be run after setup-elasticsearch.sh.

set -e

# --- Determine Script's Directory ---
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# --- Variables ---
ELK_BASE_DIR="${SCRIPT_DIR}" # Base directory is where the script is located
ELK_DIR="${ELK_BASE_DIR}/elk-wolfi"
CERT_DIR="${ELK_DIR}/certs"
KIBANA_IMAGE_NAME="docker.elastic.co/kibana/kibana-wolfi"
KIBANA_CONTAINER_NAME="kib01"
KIBANA_PORT="5601"
NETWORK_NAME="elk-wolfi_elastic" # Updated network name
TEMP_CREDENTIALS_FILE="${ELK_DIR}/temp_credentials.txt"
# KIBANA_STARTUP_LINK_REGEX="http:\/\/(127\.0\.0\.1|localhost|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}):${KIBANA_PORT}\/\?code=[a-zA-Z0-9]+" # Removed

# --- Helper Functions ---
info() {
  echo "--- $1 ---"
}

command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# --- Step 1: Check Prerequisites ---
info "Step 1: Check Prerequisites"

if ! command_exists podman; then
  echo "Error: Podman is not installed. Please run the Elasticsearch setup script first or install Podman."
  exit 1
fi

if ! command_exists podman-compose; then
  echo "Error: podman-compose is not installed. Please run the Elasticsearch setup script first or install podman-compose."
  exit 1
fi

# --- Step 2: Check for Certificate File ---
info "Step 2: Check for Elasticsearch Certificate"

CERT_FILE="${CERT_DIR}/http_ca.crt"

if [ ! -f "${CERT_FILE}" ]; then
  echo "Error: Elasticsearch certificate file not found at '${CERT_FILE}'. Please ensure the Elasticsearch setup script was run successfully."
  exit 1
fi

# --- Step 3: Check Elasticsearch Status and Get Version ---
info "Step 3: Check Elasticsearch Status and Get Version"

# Attempt to retrieve the Elasticsearch password from the temporary file and clean it
if [ -f "${TEMP_CREDENTIALS_FILE}" ]; then
  ELASTIC_PASSWORD=$(grep "Elastic password set to:" "${TEMP_CREDENTIALS_FILE}" | sed 's/.*Elastic password set to: //' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
else
  echo "Error: Temporary credentials file '${TEMP_CREDENTIALS_FILE}' not found. Please ensure the Elasticsearch setup script was run successfully."
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

# --- Step 4: Pull Kibana Docker Image ---
info "Step 4: Pull Kibana Docker Image"

KIBANA_IMAGE="${KIBANA_IMAGE_NAME}:${ELASTICSEARCH_VERSION}"
podman pull "${KIBANA_IMAGE}"

# --- Step 5: Check if Elasticsearch Network Exists ---
info "Step 5: Check if Elasticsearch Network Exists"

if ! podman network exists "${NETWORK_NAME}"; then
  echo "Error: The Podman network '${NETWORK_NAME}' does not exist."
  echo "Please ensure that the Elasticsearch setup script was run successfully and created this network."
  exit 1
fi
info "Podman network '${NETWORK_NAME}' exists."

# --- Step 6: Start a Kibana container using podman-compose ---
info "Step 6: Start a Kibana container using podman-compose"

mkdir -p "${ELK_DIR}"
cat > "${ELK_DIR}/podman-compose-kibana.yml" <<EOL
version: '3.8'
services:
  kibana:
    image: ${KIBANA_IMAGE}
    container_name: ${KIBANA_CONTAINER_NAME}
    networks:
      - ${NETWORK_NAME}
    ports:
      - "${KIBANA_PORT}:${KIBANA_PORT}"
networks:
  ${NETWORK_NAME}:
    external: true
EOL

cd "${ELK_DIR}"
podman-compose -f podman-compose-kibana.yml up -d

# --- Step 6.1: Wait for Kibana Container to be Running ---
info "Step 6.1: Wait for Kibana Container to be Running"
MAX_WAIT_SECONDS=60

echo "Please wait for Kibana to start..."

for i in $(seq "$MAX_WAIT_SECONDS" -1 1); do
  echo "Waiting for Kibana to start... $i seconds remaining..."
  podman ps -a --filter name="${KIBANA_CONTAINER_NAME}"
  sleep 1
done

echo "Kibana start process waiting complete. You can check the status above."

# --- Step 7: Get Elasticsearch Container IP Address ---
info "Step 7: Get Elasticsearch Container IP Address"
ES01_IP=$(podman inspect es01 | grep "elk-wolfi_elastic" -A 10 | grep "IPAddress" | sed -e 's/.*: "//' -e 's/",//' -e 's/ //g')
echo "Elasticsearch (es01) IP Address: ${ES01_IP}"

# --- Step 8: Retrieve and Clean Kibana Enrollment Token ---
info "Retrieving Kibana enrollment token..."
KIBANA_ENROLLMENT_TOKEN=$(podman exec -it es01 /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana 2>>"${TEMP_CREDENTIALS_FILE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
if [ -n "${KIBANA_ENROLLMENT_TOKEN}" ]; then
  echo "Kibana enrollment token: ${KIBANA_ENROLLMENT_TOKEN}"
  if grep -q "^Kibana enrollment token:" "${TEMP_CREDENTIALS_FILE}"; then
    # Replace the existing line
    sed -i "s/^Kibana enrollment token:.*$/Kibana enrollment token: ${KIBANA_ENROLLMENT_TOKEN}/" "${TEMP_CREDENTIALS_FILE}"
  else
    # Append a new line
    echo "Kibana enrollment token: ${KIBANA_ENROLLMENT_TOKEN}" >> "${TEMP_CREDENTIALS_FILE}"
  fi
else
  echo "Error retrieving Kibana enrollment token. Check ${TEMP_CREDENTIALS_FILE}"
fi

echo ""
info "Kibana setup script complete!"
echo ""
info "Retrieve Kibana Verification Code:"
podman exec -it kib01 /usr/share/kibana/bin/kibana-verification-code

