#!/bin/bash

# Script to set up Elasticsearch 8.17.4 using Podman with the hardened Wolfi image, based on the official Docker documentation.

# Note: Using Wolfi images might have specific kernel or dependency requirements.

# https://www.elastic.co/guide/en/elasticsearch/reference/8.17/docker.html

# GNU GENERAL PUBLIC LICENSE Version 3

# Harisfazillah Jamel and Google Gemini

# 31 Mac 2025

set -e

# --- Determine Script's Directory ---
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# --- Variables ---
ELK_VERSION="8.17.4"
ELK_BASE_DIR="${SCRIPT_DIR}" # Base directory is where the script is located
ELK_DIR="${ELK_BASE_DIR}/elk-wolfi"
CERT_DIR="${ELK_DIR}/certs"
# Using hardened Wolfi image
ELASTICSEARCH_IMAGE="docker.elastic.co/elasticsearch/elasticsearch-wolfi:${ELK_VERSION}"
KIBANA_IMAGE="docker.elastic.co/kibana/kibana:${ELK_VERSION}"
NETWORK_NAME="elastic"
TEMP_CREDENTIALS_FILE="${ELK_DIR}/temp_credentials.txt"

# --- Helper Functions ---
info() {
  echo "--- $1 ---"
}

command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# --- Step 1: Install Podman and Podman Compose ---
info "Step 1: Install Podman and Podman Compose"

if ! command_exists podman; then
  info "Podman not found. Installing..."
  sudo dnf update -y
  sudo dnf install epel-release -y
  sudo dnf install podman -y
else
  info "Podman is already installed."
fi

if ! command_exists podman-compose; then
  info "podman-compose not found. Installing from EPEL repository..."
  sudo dnf install epel-release -y # Ensure EPEL is enabled
  sudo dnf install podman-compose -y
else
  info "podman-compose is already installed."
fi

# --- Step 3: Pull Elasticsearch Docker Image (Wolfi hardened image) ---
info "Step 3: Pull Elasticsearch Docker Image (Wolfi hardened image)"
# Note: Using Wolfi images might require specific kernel or dependency requirements.
podman pull "${ELASTICSEARCH_IMAGE}"

# --- Step 4: Optional: Install and Verify Cosign ---
info "Step 4: Optional: Install and Verify Cosign"
if ! command_exists cosign; then
  info "Cosign not found. Please install it manually if you wish to verify the image signature."
else
  info "Cosign found. Verifying Elasticsearch image signature..."
  wget https://artifacts.elastic.co/cosign.pub -O cosign.pub
  cosign verify --key cosign.pub "${ELASTICSEARCH_IMAGE}"
  rm cosign.pub
fi

# --- Step 5: Start Elasticsearch Container using podman-compose ---
info "Step 5: Start Elasticsearch Container using podman-compose"
# We will create a podman-compose.yml file here

mkdir -p "${ELK_DIR}"
cat > "${ELK_DIR}/podman-compose.yml" <<EOL
version: '3.8'
services:
  elasticsearch:
    image: ${ELASTICSEARCH_IMAGE}
    container_name: es01
    networks:
      - ${NETWORK_NAME}
    ports:
      - "9200:9200"
    environment:
      - discovery.type=single-node
    mem_limit: 1GB
networks:
  ${NETWORK_NAME}:
    driver: bridge
EOL

cd "${ELK_DIR}"
podman-compose up -d

# --- Step 6: Retrieve and Store Elasticsearch Password ---
info "Step 6: Retrieve and Store Elasticsearch Password"
echo "Please wait for Elasticsearch to start..."

for i in $(seq 60 -1 1); do
  echo "Waiting for Elasticsearch to start... $i seconds remaining..."
  sleep 1
done

# Change to the base directory
cd "${ELK_BASE_DIR}"

# Check if ELK_DIR exists
if [ -d "${ELK_DIR}" ]; then
  info "Directory '${ELK_DIR}' already exists. Changing into it."
  cd "${ELK_DIR}"
else
  info "Directory '${ELK_DIR}' does not exist. Creating it."
  mkdir -p "${ELK_DIR}"
  cd "${ELK_DIR}"
fi

echo "--- Step 6: Retrieve and Store Elasticsearch Password ---" > "${TEMP_CREDENTIALS_FILE}"
date >> "${TEMP_CREDENTIALS_FILE}"

info "Resetting and retrieving elastic user password..."
PASSWORD_OUTPUT=$(podman exec -it es01 /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -a -f -b 2>>"${TEMP_CREDENTIALS_FILE}")
ELASTIC_PASSWORD=$(echo "$PASSWORD_OUTPUT" | grep -oP 'New value: \K.*')

if [ -n "${ELASTIC_PASSWORD}" ]; then
  echo "Elastic password set to: ${ELASTIC_PASSWORD}"
  echo "Elastic password set to: ${ELASTIC_PASSWORD}" >> "${TEMP_CREDENTIALS_FILE}"
  export ELASTIC_PASSWORD="${ELASTIC_PASSWORD}" # Optional: Set as environment variable
  echo "Recommendation: You can store this password as an environment variable in your shell using:"
  echo "export ELASTIC_PASSWORD=\"${ELASTIC_PASSWORD}\""
else
  echo "Error resetting elastic password. Check ${TEMP_CREDENTIALS_FILE}"
fi

info "Retrieving Kibana enrollment token..."
KIBANA_ENROLLMENT_TOKEN=$(podman exec -it es01 /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana 2>>"${TEMP_CREDENTIALS_FILE}")
if [ -n "${KIBANA_ENROLLMENT_TOKEN}" ]; then
  echo "Kibana enrollment token: ${KIBANA_ENROLLMENT_TOKEN}"
  echo "Kibana enrollment token: ${KIBANA_ENROLLMENT_TOKEN}" >> "${TEMP_CREDENTIALS_FILE}"
else
  echo "Error retrieving Kibana enrollment token. Check ${TEMP_CREDENTIALS_FILE}"
fi

# --- Step 7: Copy SSL Certificate ---
info "Step 7: Copy SSL Certificate"
if [ -d "${CERT_DIR}" ]; then
  info "Cleaning up existing certificate files in '${CERT_DIR}'..."
  find "${CERT_DIR}" -type f -delete
  info "Existing certificate files removed."
else
  info "Certificate directory '${CERT_DIR}' does not exist."
fi
mkdir -p "${CERT_DIR}"
podman cp es01:/usr/share/elasticsearch/config/certs/http_ca.crt "${CERT_DIR}/http_ca.crt"
info "SSL certificate copied to ${CERT_DIR}/http_ca.crt"

# --- Step 8: Make REST API Call ---
info "Step 8: Make REST API Call"

EXTRACTED_PASSWORD=$(grep "Elastic password set to:" "${TEMP_CREDENTIALS_FILE}" | sed 's/.*Elastic password set to: //')

sleep 20

if [ -f "${CERT_DIR}/http_ca.crt" ]; then
  CREDENTIALS="elastic:${EXTRACTED_PASSWORD}"
  BASE64_CREDENTIALS=$(echo -n "$CREDENTIALS" | base64)
  AUTHORIZATION_HEADER="Authorization: Basic ${BASE64_CREDENTIALS}"

  info "Making REST API call using -H"
  /usr/bin/curl --cacert $CERT_DIR/http_ca.crt -H "$AUTHORIZATION_HEADER" https://localhost:9200

  info "Waiting for 5 seconds..."
  sleep 5

  info "Making REST API call using -u"
  /usr/bin/curl --cacert $CERT_DIR/http_ca.crt -u "$CREDENTIALS" https://localhost:9200
else
  echo "Error: http_ca.crt not found. Skipping API calls."
fi

echo ""
info "Elasticsearch setup complete! You can access it at https://localhost:9200."
info "Remember to check the temporary file '${TEMP_CREDENTIALS_FILE}' for the Elasticsearch password and the Kibana enrollment token."
info "Recommendation: For easier interaction with Elasticsearch, consider exporting the password as an environment variable:"
info "export ELASTIC_PASSWORD=\"$(grep 'Elastic password set to:' '${TEMP_CREDENTIALS_FILE}' | sed 's/.*Elastic password set to: //')\""
