#!/bin/bash

# Fixed deployment script for Helm chart
# This script cleans up and redeploys with the fixed configuration

set -e

NAMESPACE="${1:-default}"
RELEASE_NAME="${2:-microservices-test}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Starting fixed deployment for namespace: $NAMESPACE"

# Step 1: Cleanup existing deployment
log_info "Step 1: Cleaning up existing deployment..."
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || log_warning "Helm uninstall failed"
fi

# Delete PVCs
kubectl delete pvc postgresql-pvc rabbitmq-pvc redis-pvc -n "$NAMESPACE" 2>/dev/null || log_warning "PVCs not found"

# Wait for cleanup
sleep 5

# Step 2: Deploy with fixed configuration
log_info "Step 2: Deploying with fixed configuration (no persistence)..."
helm install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --wait \
    --timeout 15m

# Step 3: Check status
log_info "Step 3: Checking deployment status..."
kubectl get pods -n "$NAMESPACE"
kubectl get svc -n "$NAMESPACE" | grep NodePort || log_warning "No NodePort services"

log_success "Deployment completed! Check pod status above."

echo ""
echo "=== Access Information ==="
echo ""
echo "# Port forwarding:"
echo "kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE &"
echo "kubectl port-forward svc/backend-api 3000:3000 -n $NAMESPACE &"
echo ""
echo "# NodePort access (get node IP first):"
echo "kubectl get nodes -o wide"
echo "# Frontend: http://<NODE_IP>:30080"
echo "# Backend: http://<NODE_IP>:30081"
echo "# Monitoring: http://<NODE_IP>:30082"
echo ""
