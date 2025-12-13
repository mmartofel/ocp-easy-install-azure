#!/usr/bin/env bash
set -euo pipefail

##############################################
# CONFIGURATION VARIABLES
# YOU CAN EDIT THESE IF NEEDED, OR 
# SET VIA ENVIRONMENT VARIABLES
##############################################
CLUSTER_DIR="${CLUSTER_DIR:-./config}"
CLUSTER_NAME="${CLUSTER_NAME:-zenek}"
BASE_DOMAIN="${BASE_DOMAIN:-example.com}"
PULL_SECRET_FILE="${PULL_SECRET_FILE:-./pull-secret.txt}"
SSH_KEY_FILE="${SSH_KEY_FILE:-./ssh/id_rsa.pub}"

# Azure-specific env (can be set externally)
export AZURE_PROFILE="${AZURE_PROFILE:-default}" # not used by az CLI but kept for parity
export AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
export AZURE_TENANT_ID="${AZURE_TENANT_ID:-}"
export AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"
export AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}"

MASTER_FILE="./instances/master"
WORKER_FILE="./instances/worker"

##############################################
# COLORS & ICONS
##############################################
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
RESET="\033[0m"

INFO="💡"
SUCCESS="✅"
WARN="⚠️"
ERROR="❌"

log_info() { echo -e "${CYAN}${INFO} $1${RESET}" >&2; }
log_success() { echo -e "${GREEN}${SUCCESS} $1${RESET}" >&2; }
log_warn() { echo -e "${YELLOW}${WARN} $1${RESET}" >&2; }
log_error() { echo -e "${RED}${ERROR} $1${RESET}" >&2; }

##############################################
# PRE-FLIGHT CHECKS
##############################################
preflight_checks() {
  log_info "Checking required commands and files..."

  command -v ./openshift-install >/dev/null 2>&1 || { log_error "openshift-install not found in PATH"; exit 1; }
  command -v az >/dev/null 2>&1 || { log_error "Azure CLI (az) not found in PATH"; exit 1; }
  command -v jq >/dev/null 2>&1 || { log_error "jq not found in PATH (required)"; exit 1; }

  [[ -f "$PULL_SECRET_FILE" ]] || { log_error "Pull secret not found: $PULL_SECRET_FILE"; exit 1; }
  [[ -f "$SSH_KEY_FILE" ]] || { log_error "SSH key not found: $SSH_KEY_FILE"; exit 1; }
  [[ -f "$MASTER_FILE" ]] || { log_error "Master instance list not found: $MASTER_FILE"; exit 1; }
  [[ -f "$WORKER_FILE" ]] || { log_error "Worker instance list not found: $WORKER_FILE"; exit 1; }

  # Check az login (try to read account)
  if ! az account show >/dev/null 2>&1; then
    log_warn "Not logged into Azure CLI. Attempting to proceed, but consider running 'az login' or setting a service principal env vars."
  fi

  # If environment SP vars are missing, warn (installer may still work with az login)
  if [[ -z "$AZURE_SUBSCRIPTION_ID" || -z "$AZURE_TENANT_ID" || -z "$AZURE_CLIENT_ID" || -z "$AZURE_CLIENT_SECRET" ]]; then
    log_warn "One or more Azure service principal env vars are missing. For fully automated installs, set AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID, AZURE_CLIENT_ID and AZURE_CLIENT_SECRET."
  fi

  log_success "Pre-flight checks passed (or warnings issued)."
}

##############################################
# AUTO-DETECT BASE DOMAIN FROM Azure DNS Zones
##############################################
detect_base_domain() {
  log_info "Detecting base domain from Azure DNS Zones..."

  # try to list DNS zones and pick the first public zone name
  ZONES_JSON=$(az network dns zone list --query "[].{name:name,resourceGroup:resourceGroup}" -o json 2>/dev/null || true)

  if [[ -z "$ZONES_JSON" || "$ZONES_JSON" == "[]" ]]; then
    log_warn "No Azure DNS zones found (az network dns zone list returned empty). Falling back to BASE_DOMAIN env/default: $BASE_DOMAIN"
    return
  fi

  # Pick first zone's name and resource group
  BASE_DOMAIN=$(echo "$ZONES_JSON" | jq -r '.[0].name')
  BASE_DOMAIN_RG=$(echo "$ZONES_JSON" | jq -r '.[0].resourceGroup')

  # strip trailing dot if any (unlikely in Azure)
  BASE_DOMAIN="${BASE_DOMAIN%\.}"

  log_success "Using base domain: $BASE_DOMAIN (resourceGroup: $BASE_DOMAIN_RG)"
}

##############################################
# AUTO-DETECT AZURE REGION (location) and subscription
##############################################
detect_azure_region_and_subscription() {
  log_info "Detecting Azure subscription and default location (region)..."

  # Try to get subscription & tenant from env or az account
  if [[ -z "$AZURE_SUBSCRIPTION_ID" ]]; then
    AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || true)
  fi
  if [[ -z "$AZURE_TENANT_ID" ]]; then
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || true)
  fi

  # Try to detect a default location (from az account or use default)
  AZURE_REGION="${AZURE_REGION:-}"
  if [[ -z "$AZURE_REGION" ]]; then
    # Try to get from az configure (cloud) or fallback to common regions
    AZURE_REGION=$(az account list-locations --query "[0].name" -o tsv 2>/dev/null || true)
  fi

  if [[ -z "$AZURE_SUBSCRIPTION_ID" ]]; then
    log_warn "AZURE_SUBSCRIPTION_ID not detected. You must set it via env or 'az login' before installing."
  else
    log_success "Azure subscription detected: $AZURE_SUBSCRIPTION_ID"
  fi

  if [[ -z "$AZURE_REGION" ]]; then
    log_warn "Could not auto-detect Azure region. Please set AZURE_REGION environment variable (e.g. eastus)."
    # do not exit; user might provide region later
  else
    log_success "Using Azure region (location): $AZURE_REGION"
  fi
}

##############################################
# SELECT INSTANCE TYPE (VM size)
##############################################
select_instance_type() {
  local file="$1"
  local role="$2"

  # Print messages to stderr
  echo >&2
  echo -e "${MAGENTA}${INFO} Available ${role} instance (VM) types:${RESET}" >&2
  echo "----------------------------------------" >&2

  local i=1
  while IFS= read -r line || [[ -n "$line" ]]; do
    echo "  [$i] $line" >&2
    ((i++))
  done < "$file"

  echo >&2
  read -rp "Choose ${role} instance type by number (default=1): " choice >&2
  [[ -z "$choice" ]] && choice=1

  local total
  total=$(grep -c '' "$file")
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > total)); then
    log_error "Invalid choice. Must be 1..$total"
    exit 1
  fi

  local selected
  selected=$(sed -n "${choice}p" "$file" | cut -d'|' -f1)

  # Print log to stderr
  echo >&2
  echo -e "${GREEN}${SUCCESS} Selected ${role} instance type: $selected${RESET}" >&2

  # Only return the instance type on stdout
  echo "$selected"
}

###############################################
# FETCH AVAILABLE OCP VERSIONS FOR GIVEN MINOR
###############################################
get_ocp_versions() {
    local channel="stable-4.20"

    echo "💡 Fetching OpenShift versions from channel: $channel ..." >&2

    ALL_VERSIONS=$(curl -s "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${channel}" \
        | jq -r '.nodes[].version')

    VERSIONS=$(echo "$ALL_VERSIONS" | grep '^4\.20\.' | sort -V)

    if [[ -z "$VERSIONS" ]]; then
        echo "❌ No OpenShift 4.20 versions found in $channel" >&2
        exit 1
    fi

    # IMPORTANT: print ONLY versions here, NOTHING ELSE
    echo "$VERSIONS"
}

###############################################
# SELECT OCP VERSION
###############################################
select_ocp_version() {
    # Read get_ocp_versions line by line into array
    versions=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && versions+=("$line")
    done < <(get_ocp_versions)

    if [[ ${#versions[@]} -eq 0 ]]; then
        echo "❌ No OpenShift versions found!" >&2
        exit 1
    fi

    echo "💡 Available OpenShift ${versions[0]%.*}.x versions:"
    echo "----------------------------------------"

    for i in "${!versions[@]}"; do
        printf "  [%d] %s\n" $((i+1)) "${versions[$i]}"
    done

    # default is last element
    default_choice=${#versions[@]}
    read -p "Choose OpenShift version (default=${versions[$((default_choice-1))]}): " choice

    if [[ -z "$choice" ]]; then
        SELECTED_VERSION="${versions[$((default_choice-1))]}"
    else
        # validate choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#versions[@]} )); then
            echo "❌ Invalid choice. Must be 1..${#versions[@]}" >&2
            exit 1
        fi
        SELECTED_VERSION="${versions[$((choice-1))]}"
    fi

    echo "✅ Selected OpenShift version: $SELECTED_VERSION"
}

##############################################
# SET RELEASE IMAGE
##############################################
set_release_image() {
    RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:${SELECTED_VERSION}-x86_64"

    echo "💡 Using release image:"
    echo "   $RELEASE_IMAGE"

    export OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE="$RELEASE_IMAGE"

    echo "✅ Release override set successfully."
}

##############################################
# GENERATE INSTALL CONFIG (Azure)
##############################################
generate_install_config() {
  mkdir -p "$CLUSTER_DIR"
  rm -f "$CLUSTER_DIR/install-config.yaml"

  log_info "Generating $CLUSTER_DIR/install-config.yaml ..."

  # include baseDomainResourceGroupName if discovered
  if [[ -n "${BASE_DOMAIN_RG:-}" ]]; then
    BASE_DOMAIN_RG_YAML="  baseDomainResourceGroupName: ${BASE_DOMAIN_RG}"
  else
    BASE_DOMAIN_RG_YAML=""
  fi

  cat > "$CLUSTER_DIR/install-config.yaml" <<EOF
apiVersion: v1
baseDomain: ${BASE_DOMAIN}
additionalTrustBundlePolicy: Proxyonly
metadata:
  name: ${CLUSTER_NAME}
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    azure:
      type: ${WORKER_INSTANCE_TYPE}
      osImage:
        publisher: redhat
        offer: rh-ocp-worker
        sku: rh-ocp-worker
        version: 4.18.2025112710
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    azure:
      type: ${MASTER_INSTANCE_TYPE}
  replicas: 3
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  azure:
    region: ${AZURE_REGION}
    cloudName: AzurePublicCloud
    outboundType: Loadbalancer
  ${BASE_DOMAIN_RG_YAML:+$(printf "%s\n" "$BASE_DOMAIN_RG_YAML")}
publish: External
fips: false
pullSecret: '$(cat ${PULL_SECRET_FILE} | tr -d '\n')'
sshKey: '$(cat ${SSH_KEY_FILE})'
EOF

  log_success "install-config.yaml generated successfully!"
}

##############################################
# MAIN
##############################################
main() {

  rm ${HOME}/.azure/osServicePrincipal.json 2>/dev/null || true
  preflight_checks
  detect_base_domain
  detect_azure_region_and_subscription

  MASTER_INSTANCE_TYPE=$(select_instance_type "$MASTER_FILE" "master")
  WORKER_INSTANCE_TYPE=$(select_instance_type "$WORKER_FILE" "worker")

  echo -e "$YELLOW${INFO} -------------------------------------------------${RESET}"

  generate_install_config
  # fetch and choose ocp version (optional)
  get_ocp_versions >/dev/null
  select_ocp_version
  set_release_image

  log_info "Release image set to:"
  log_info "  $RELEASE_IMAGE"
  log_info "Starting automated OpenShift installation..."

  # Provide Azure SP envs to installer if available (installer will also use az login if present)
  if [[ -n "$AZURE_SUBSCRIPTION_ID" ]]; then
    export AZURE_SUBSCRIPTION_ID
  fi
  if [[ -n "$AZURE_TENANT_ID" ]]; then
    export AZURE_TENANT_ID
  fi
  if [[ -n "$AZURE_CLIENT_ID" ]]; then
    export AZURE_CLIENT_ID
  fi
  if [[ -n "$AZURE_CLIENT_SECRET" ]]; then
    export AZURE_CLIENT_SECRET
  fi

  ./openshift-install create cluster --dir "$CLUSTER_DIR"
  # --log-level debug

  log_success "OpenShift cluster installation complete."
  echo -e "${CYAN}Kubeconfig: ${CLUSTER_DIR}/auth/kubeconfig${RESET}"
  echo -e "${CYAN}Kubeadmin password: ${CLUSTER_DIR}/auth/kubeadmin-password${RESET}"
}

main "$@"
