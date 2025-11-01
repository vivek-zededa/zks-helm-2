#!/bin/bash

# Debug and fix script for Helm chart deployment
# This script fixes all identified issues and redeploys

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

log_info "Starting debug and fix for namespace: $NAMESPACE"

# Step 1: Cleanup existing deployment
log_info "Step 1: Cleaning up existing deployment..."
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || log_warning "Helm uninstall failed"
fi

# Wait for resources to be deleted
sleep 5

# Step 2: Delete stuck PVCs
log_info "Step 2: Deleting stuck PVCs..."
kubectl delete pvc postgresql-pvc rabbitmq-pvc redis-pvc -n "$NAMESPACE" --ignore-not-found=true || log_warning "PVCs not found or already deleted"

# Wait for PVCs to be fully deleted
sleep 5

# Step 3: Deploy with fixed configuration
log_info "Step 3: Deploying with fixed configuration..."
helm install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --wait \
    --timeout 15m

# Step 4: Check status
log_info "Step 4: Checking deployment status..."
echo ""
echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=== Service Status ==="
kubectl get svc -n "$NAMESPACE"

echo ""
echo "=== PVC Status ==="
kubectl get pvc -n "$NAMESPACE" 2>/dev/null || echo "No PVCs found (expected when persistence is disabled)"

echo ""
log_success "Deployment completed! Check pod status above."

echo ""
echo "=== Debugging Commands ==="
echo "# Check pod events:"
echo "kubectl describe pod <pod-name> -n $NAMESPACE"
echo ""
echo "# Check pod logs:"
echo "kubectl logs <pod-name> -n $NAMESPACE"
echo ""
echo "# Port forwarding:"
echo "kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE &"
echo "kubectl port-forward svc/backend-api 3000:3000 -n $NAMESPACE &"
echo ""
