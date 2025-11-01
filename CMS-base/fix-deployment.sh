#!/bin/bash

# Quick fix script for current deployment issues

set -e

NAMESPACE="default"
RELEASE_NAME="microservices-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Clean up current deployment
log_info "Step 1: Cleaning up current deployment..."
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || log_warning "Release not found"
kubectl delete pvc --all -n "$NAMESPACE" || log_warning "No PVCs to delete"
kubectl delete pods --all -n "$NAMESPACE" || log_warning "No pods to delete"

# Step 2: Wait for cleanup
log_info "Step 2: Waiting for cleanup..."
sleep 10

# Step 3: Deploy with no-storage configuration
log_info "Step 3: Deploying with no-storage configuration..."
helm install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --values values-no-storage.yaml \
    --wait \
    --timeout 15m

# Step 4: Check deployment status
log_info "Step 4: Checking deployment status..."
kubectl get pods -n "$NAMESPACE"

# Step 5: Show access information
log_info "Step 5: Deployment completed!"
echo ""
echo "=== Access Information ==="
echo ""
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo ""
echo "=== Port Forward Commands ==="
echo ""
echo "# Frontend (Nginx)"
echo "kubectl port-forward svc/frontend 8080:80 -n $NAMESPACE"
echo "Access at: http://localhost:8080"
echo ""
echo "# Backend API"
echo "kubectl port-forward svc/backend-api 3000:3000 -n $NAMESPACE"
echo "Access at: http://localhost:3000"
echo ""
echo "# Monitoring (Prometheus)"
echo "kubectl port-forward svc/prometheus 9090:9090 -n $NAMESPACE"
echo "Access at: http://localhost:9090"
echo ""
echo "# RabbitMQ Management"
echo "kubectl port-forward svc/rabbitmq 15672:15672 -n $NAMESPACE"
echo "Access at: http://localhost:15672 (user: user, password: password)"
echo ""
echo "=== NodePort Access ==="
echo ""
echo "# Get node IP:"
echo "kubectl get nodes -o wide"
echo ""
echo "# Access services:"
echo "# Frontend: http://<NODE_IP>:30080"
echo "# Backend API: http://<NODE_IP>:30081"
echo "# Monitoring: http://<NODE_IP>:30082"
echo "# PostgreSQL: <NODE_IP>:30083"
echo "# Redis: <NODE_IP>:30084"
echo "# RabbitMQ Management: http://<NODE_IP>:30086"
echo ""

log_success "Fix deployment completed!"
