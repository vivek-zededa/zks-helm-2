#!/bin/bash

# Complex Microservices Helm Chart Deployment Script
# This script deploys the comprehensive microservices stack for orchestrator testing

set -e

# Configuration
NAMESPACE="microservices-test"
RELEASE_NAME="microservices-test"
CHART_PATH="."
VALUES_FILE="test-values.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to Kubernetes
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace $NAMESPACE created"
    fi
}

# Deploy the chart
deploy_chart() {
    log_info "Deploying Helm chart..."
    
    # Check if release already exists
    if helm list -n "$NAMESPACE" | grep -q "$RELEASE_NAME"; then
        log_warning "Release $RELEASE_NAME already exists. Upgrading..."
        helm upgrade "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --values "$VALUES_FILE" \
            --wait \
            --timeout 10m
    else
        log_info "Installing new release..."
        helm install "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --values "$VALUES_FILE" \
            --wait \
            --timeout 10m
    fi
    
    log_success "Helm chart deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check if all pods are running
    log_info "Checking pod status..."
    kubectl get pods -n "$NAMESPACE"
    
    # Wait for all pods to be ready
    log_info "Waiting for all pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=frontend -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=backend-api -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=worker -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=prometheus -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=postgresql -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=redis -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=rabbitmq -n "$NAMESPACE" --timeout=300s
    
    log_success "All pods are ready"
    
    # Check services
    log_info "Checking services..."
    kubectl get svc -n "$NAMESPACE"
    
    # Check ingress
    log_info "Checking ingress..."
    kubectl get ingress -n "$NAMESPACE"
    
    # Check network policies
    log_info "Checking network policies..."
    kubectl get networkpolicies -n "$NAMESPACE"
    
    # Check persistent volume claims
    log_info "Checking persistent volume claims..."
    kubectl get pvc -n "$NAMESPACE"
}

# Test connectivity
test_connectivity() {
    log_info "Testing connectivity..."
    
    # Test frontend health
    log_info "Testing frontend health..."
    kubectl exec -n "$NAMESPACE" deployment/frontend -- wget -qO- http://localhost/health || log_warning "Frontend health check failed"
    
    # Test backend health
    log_info "Testing backend health..."
    kubectl exec -n "$NAMESPACE" deployment/backend-api -- wget -qO- http://localhost:3000/health || log_warning "Backend health check failed"
    
    # Test database connectivity
    log_info "Testing database connectivity..."
    kubectl exec -n "$NAMESPACE" deployment/backend-api -- wget -qO- http://localhost:3000/ready || log_warning "Database connectivity test failed"
    
    log_success "Connectivity tests completed"
}

# Show access information
show_access_info() {
    log_info "Deployment completed successfully!"
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
    echo "=== NodePort Access (Direct Node Access) ==="
    echo ""
    echo "# Get node IP first:"
    echo "kubectl get nodes -o wide"
    echo ""
    echo "# Then access services directly via NodePort:"
    echo "# Frontend: http://<NODE_IP>:30080"
    echo "# Backend API: http://<NODE_IP>:30081"
    echo "# Monitoring: http://<NODE_IP>:30082"
    echo "# PostgreSQL: <NODE_IP>:30083"
    echo "# Redis: <NODE_IP>:30084"
    echo "# RabbitMQ AMQP: <NODE_IP>:30085"
    echo "# RabbitMQ Management: http://<NODE_IP>:30086 (user: user, password: password)"
    echo "# RabbitMQ Metrics: http://<NODE_IP>:30087"
    echo ""
    echo "=== Test Commands ==="
    echo ""
    echo "# Test backend API"
    echo "curl http://localhost:3000/health"
    echo "curl http://localhost:3000/ready"
    echo "curl http://localhost:3000/api/users"
    echo ""
    echo "# Test frontend"
    echo "curl http://localhost:8080/health"
    echo ""
    echo "=== Cleanup Commands ==="
    echo ""
    echo "# Remove the deployment"
    echo "helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo "kubectl delete namespace $NAMESPACE"
    echo ""
}

# Main execution
main() {
    log_info "Starting deployment of complex microservices stack..."
    echo ""
    
    check_prerequisites
    create_namespace
    deploy_chart
    verify_deployment
    test_connectivity
    show_access_info
    
    log_success "Deployment completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    "cleanup")
        log_info "Cleaning up deployment..."
        helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || log_warning "Release not found"
        kubectl delete namespace "$NAMESPACE" || log_warning "Namespace not found"
        log_success "Cleanup completed"
        ;;
    "status")
        log_info "Checking deployment status..."
        kubectl get all -n "$NAMESPACE"
        ;;
    "logs")
        log_info "Showing logs..."
        kubectl logs -l app=frontend -n "$NAMESPACE" --tail=50
        kubectl logs -l app=backend-api -n "$NAMESPACE" --tail=50
        kubectl logs -l app=worker -n "$NAMESPACE" --tail=50
        ;;
    *)
        main
        ;;
esac
