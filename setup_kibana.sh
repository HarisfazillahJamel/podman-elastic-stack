#!/bin/bash
# Script to set up Kibana using Podman with the hardened Wolfi image, based on the official Docker documentation.
# Note: Using Wolfi images might have specific kernel or dependency requirements.
# https://www.elastic.co/guide/en/kibana/current/docker.html
# GNU GENERAL PUBLIC LICENSE Version 3
# Harisfazillah Jamel and Google Gemini
# 2 Apr 2025

# Script to set up Kibana using Podman with its own custom kibana.yml.
# This script should be run after setup_elasticsearch.sh.

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

# ---  Check Elasticsearch Network ---
info " Step 2.1: Check Elasticsearch Network"

if ! podman network exists "${NETWORK_NAME}"; then # Check if the network exists.
  echo "Error: The Podman network '${NETWORK_NAME}' does not exist."
  echo "Please ensure that the setup_elasticsearch.sh script was run successfully and created this network."
  exit 1
fi
info "Podman network '${NETWORK_NAME}' exists."

# --- Step 3: Check Elasticsearch Status and Get Version ---
info "Step 3: Check Elasticsearch Status and Get Version"

# Attempt to retrieve the Elasticsearch password from the temporary file and clean it
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

# --- Step 4: Pull Kibana Docker Image ---
info "Step 4: Pull Kibana Docker Image"

KIBANA_IMAGE="${KIBANA_IMAGE_NAME}:${ELASTICSEARCH_VERSION}"
podman pull "${KIBANA_IMAGE}"

# --- Step 5: Get Default Kibana Configuration ---
info "Step 5: Get Default Kibana Configuration"
TEMP_KIBANA_CONTAINER="temp_kib01"

# --- Step 5.1: Create ELK Directory on Host ---
info "Step 5.1: Create ELK Directory on Host"
mkdir -p "${ELK_DIR}"

echo "Starting temporary Kibana container '${TEMP_KIBANA_CONTAINER}' to extract default config..."
podman run --name "${TEMP_KIBANA_CONTAINER}" --network "${NETWORK_NAME}" -d "${KIBANA_IMAGE}" sleep infinity
if [ $? -eq 0 ]; then
  echo "Copying default kibana.yml from container..."
  podman cp "${TEMP_KIBANA_CONTAINER}:/usr/share/kibana/config/kibana.yml" "${ELK_DIR}/kibana.yml"
  echo "Default kibana.yml copied to ${ELK_DIR}/kibana.yml. Please review and customize it."
  echo "Stopping and removing temporary container '${TEMP_KIBANA_CONTAINER}'..."
  podman stop "${TEMP_KIBANA_CONTAINER}"
  podman rm "${TEMP_KIBANA_CONTAINER}"
else
  echo "Error starting temporary Kibana container. Skipping default config copy."
  exit 1
fi

# --- Step 6: Start a Kibana container using podman-compose with volume and custom config ---
info "Step 6: Start a Kibana container using podman-compose with volume and custom config"

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
    volumes:
      - kibana_data:/data/kibana_data
      - ./kibana.yml:/usr/share/kibana/config/kibana.yml # Mount custom kibana.yml to standard config dir
volumes:
  kibana_data:
networks:
  ${NETWORK_NAME}:
    external: true
EOL

cd "${ELK_DIR}"
podman-compose -f podman-compose-kibana.yml up -d

# --- Step 7: Wait for Kibana Container to be Running ---
info "Step 7: Wait for Kibana Container to be Running"
MAX_WAIT_SECONDS=60

echo "Please wait for Kibana to start..."

for i in $(seq "$MAX_WAIT_SECONDS" -1 1); do
  echo "Waiting for Kibana to start... $i seconds remaining..."
  podman ps -a --filter name="${KIBANA_CONTAINER_NAME}"
  sleep 1
done

echo "Kibana start process waiting complete. You can check the status above."

# --- Step 8: Get Elasticsearch Container IP Address ---
info "Step 8: Get Elasticsearch Container IP Address"
ES01_IP=$(podman inspect es01 | grep "elk-wolfi_elastic" -A 10 | grep "IPAddress" | sed -e 's/.*: "//' -e 's/",//' -e 's/ //g')
echo "Elasticsearch (es01) IP Address: ${ES01_IP}"

# --- Step 9: Retrieve and Clean Kibana Enrollment Token ---
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
info "You can access the Kibana from your Internet Browser with this URL http://localhost:5601"
echo ""
info "Retrieve Kibana Verification Code:"
podman exec -it kib01 /usr/share/kibana/bin/kibana-verification-code

