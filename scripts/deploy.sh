#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="waf-system"
RELEASE_NAME="waf"
CHART_DIR="./charts/waf"
VALUES_FILE="${CHART_DIR}/values.yaml"
TLS_ENABLED=true
CERT_MANAGER_ENABLED=true
DRY_RUN=false

# Function to display help
usage() {
  echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
  echo
  echo "Deploy the WAF Helm chart to Kubernetes"
  echo
  echo "Options:"
  echo "  -n, --namespace string      Kubernetes namespace (default: ${NAMESPACE})"
  echo "  -r, --release string       Helm release name (default: ${RELEASE_NAME})"
  echo "  -c, --chart string         Path to Helm chart directory (default: ${CHART_DIR})"
  echo "  -f, --values string        Path to values file (default: ${VALUES_FILE})"
  echo "  --no-tls                   Disable TLS (default: TLS enabled)"
  echo "  --no-cert-manager          Disable cert-manager (default: cert-manager enabled)"
  echo "  --dry-run                  Simulate deployment without applying changes"
  echo "  -h, --help                 Show this help message"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -r|--release)
      RELEASE_NAME="$2"
      shift
      shift
      ;;
    -c|--chart)
      CHART_DIR="$2"
      shift
      shift
      ;;
    -f|--values)
      VALUES_FILE="$2"
      shift
      shift
      ;;
    --no-tls)
      TLS_ENABLED=false
      shift
      ;;
    --no-cert-manager)
      CERT_MANAGER_ENABLED=false
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      usage
      ;;
  esac
done

# Verify kubectl is installed and configured
verify_kubectl() {
  if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl could not be found. Please install kubectl.${NC}"
    exit 1
  fi

  if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured properly. Please check your kubeconfig.${NC}"
    exit 1
  fi
}

# Verify helm is installed
verify_helm() {
  if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm could not be found. Please install helm.${NC}"
    exit 1
  fi
}

# Create namespace if it doesn't exist
create_namespace() {
  if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    echo -e "${YELLOW}Creating namespace ${NAMESPACE}...${NC}"
    kubectl create namespace "${NAMESPACE}"
    kubectl label namespace "${NAMESPACE}" istio-injection=enabled --overwrite
  else
    echo -e "${GREEN}Namespace ${NAMESPACE} already exists${NC}"
  fi
}

# Install cert-manager if enabled
install_cert_manager() {
  if [ "${CERT_MANAGER_ENABLED}" = true ]; then
    echo -e "${YELLOW}Checking cert-manager installation...${NC}"
    
    if ! helm repo list | grep -q jetstack; then
      echo -e "${YELLOW}Adding jetstack Helm repository...${NC}"
      helm repo add jetstack https://charts.jetstack.io
      helm repo update
    fi

    if ! helm status cert-manager -n cert-manager &> /dev/null; then
      echo -e "${YELLOW}Installing cert-manager...${NC}"
      kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
      helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --version v1.13.0 \
        --set installCRDs=true \
        --wait
    else
      echo -e "${GREEN}cert-manager is already installed${NC}"
    fi
  fi
}

# Deploy the WAF
deploy_waf() {
  local extra_args=()

  if [ "${DRY_RUN}" = true ]; then
    extra_args+=("--dry-run")
    echo -e "${YELLOW}Running dry-run deployment...${NC}"
  fi

  if [ "${TLS_ENABLED}" = false ]; then
    extra_args+=("--set" "ingress.tls.enabled=false")
  fi

  if [ "${CERT_MANAGER_ENABLED}" = false ]; then
    extra_args+=("--set" "cert-manager.enabled=false")
  fi

  echo -e "${YELLOW}Deploying WAF Helm chart...${NC}"
  helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --values "${VALUES_FILE}" \
    --set fullnameOverride="${RELEASE_NAME}" \
    --wait \
    "${extra_args[@]}"

  if [ "${DRY_RUN}" = false ]; then
    echo -e "${YELLOW}Waiting for deployment to complete...${NC}"
    kubectl rollout status deployment "${RELEASE_NAME}" -n "${NAMESPACE}" --timeout=300s
  fi
}

# Main execution
main() {
  verify_kubectl
  verify_helm
  create_namespace
  install_cert_manager
  deploy_waf

  if [ "${DRY_RUN}" = false ]; then
    echo -e "${GREEN}Deployment completed successfully!${NC}"
    echo
    echo -e "${YELLOW}To check the status of your deployment, run:${NC}"
    echo "  kubectl get all -n ${NAMESPACE}"
    echo
    echo -e "${YELLOW}To view the WAF logs, run:${NC}"
    echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME} --tail=50"
  fi
}

main