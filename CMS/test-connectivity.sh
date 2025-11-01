#!/bin/bash

# Connectivity Test Script for Complex Microservices Stack
# This script tests inter-service communication and network policies

set -e

# Configuration
NAMESPACE="microservices-test"
TIMEOUT=30

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

# Test function
test_connectivity() {
    local from_pod=$1
    local to_service=$2
    local port=$3
    local description=$4
    
    log_info "Testing: $description"
    log_info "From: $from_pod -> To: $to_service:$port"
    
    if kubectl exec -n "$NAMESPACE" deployment/"$from_pod" -- timeout 5 wget -qO- "http://$to_service:$port" &>/dev/null; then
        log_success "✓ $description - Connection successful"
        return 0
    else
        log_error "✗ $description - Connection failed"
        return 1
    fi
}

# Test network policies
test_network_policies() {
    log_info "Testing network policies..."
    
    # Test allowed connections
    log_info "Testing allowed connections..."
    
    # Frontend -> Backend (should work)
    test_connectivity "frontend" "backend-api" "3000" "Frontend to Backend API"
    
    # Backend -> PostgreSQL (should work)
    test_connectivity "backend-api" "postgresql" "5432" "Backend to PostgreSQL"
    
    # Backend -> Redis (should work)
    test_connectivity "backend-api" "redis" "6379" "Backend to Redis"
    
    # Backend -> RabbitMQ (should work)
    test_connectivity "backend-api" "rabbitmq" "5672" "Backend to RabbitMQ"
    
    # Worker -> RabbitMQ (should work)
    test_connectivity "worker" "rabbitmq" "5672" "Worker to RabbitMQ"
    
    # Worker -> Redis (should work)
    test_connectivity "worker" "redis" "6379" "Worker to Redis"
    
    # Prometheus -> All services (should work)
    test_connectivity "prometheus" "frontend" "80" "Prometheus to Frontend"
    test_connectivity "prometheus" "backend-api" "3000" "Prometheus to Backend"
    test_connectivity "prometheus" "postgresql" "5432" "Prometheus to PostgreSQL"
    test_connectivity "prometheus" "redis" "6379" "Prometheus to Redis"
    test_connectivity "prometheus" "rabbitmq" "15692" "Prometheus to RabbitMQ"
    
    log_info "Testing blocked connections..."
    
    # Test blocked connections (should fail)
    # Frontend -> PostgreSQL (should be blocked by network policy)
    if kubectl exec -n "$NAMESPACE" deployment/frontend -- timeout 5 wget -qO- "http://postgresql:5432" &>/dev/null; then
        log_warning "⚠ Frontend to PostgreSQL - Connection should be blocked but succeeded"
    else
        log_success "✓ Frontend to PostgreSQL - Correctly blocked by network policy"
    fi
    
    # Frontend -> Redis (should be blocked by network policy)
    if kubectl exec -n "$NAMESPACE" deployment/frontend -- timeout 5 wget -qO- "http://redis:6379" &>/dev/null; then
        log_warning "⚠ Frontend to Redis - Connection should be blocked but succeeded"
    else
        log_success "✓ Frontend to Redis - Correctly blocked by network policy"
    fi
    
    # Worker -> Backend (should be blocked by network policy)
    if kubectl exec -n "$NAMESPACE" deployment/worker -- timeout 5 wget -qO- "http://backend-api:3000" &>/dev/null; then
        log_warning "⚠ Worker to Backend - Connection should be blocked but succeeded"
    else
        log_success "✓ Worker to Backend - Correctly blocked by network policy"
    fi
}

# Test service health endpoints
test_health_endpoints() {
    log_info "Testing health endpoints..."
    
    # Test frontend health
    if kubectl exec -n "$NAMESPACE" deployment/frontend -- wget -qO- "http://localhost/health" &>/dev/null; then
        log_success "✓ Frontend health endpoint working"
    else
        log_error "✗ Frontend health endpoint failed"
    fi
    
    # Test backend health
    if kubectl exec -n "$NAMESPACE" deployment/backend-api -- wget -qO- "http://localhost:3000/health" &>/dev/null; then
        log_success "✓ Backend health endpoint working"
    else
        log_error "✗ Backend health endpoint failed"
    fi
    
    # Test backend readiness
    if kubectl exec -n "$NAMESPACE" deployment/backend-api -- wget -qO- "http://localhost:3000/ready" &>/dev/null; then
        log_success "✓ Backend readiness endpoint working"
    else
        log_error "✗ Backend readiness endpoint failed"
    fi
}

# Test database operations
test_database_operations() {
    log_info "Testing database operations..."
    
    # Test database connection through backend
    if kubectl exec -n "$NAMESPACE" deployment/backend-api -- wget -qO- "http://localhost:3000/api/users" &>/dev/null; then
        log_success "✓ Database operations working"
    else
        log_error "✗ Database operations failed"
    fi
}

# Test message queue operations
test_message_queue() {
    log_info "Testing message queue operations..."
    
    # Test RabbitMQ management interface
    if kubectl exec -n "$NAMESPACE" deployment/rabbitmq -- rabbitmq-diagnostics -q ping &>/dev/null; then
        log_success "✓ RabbitMQ is running"
    else
        log_error "✗ RabbitMQ is not responding"
    fi
}

# Test monitoring
test_monitoring() {
    log_info "Testing monitoring..."
    
    # Test Prometheus health
    if kubectl exec -n "$NAMESPACE" deployment/prometheus -- wget -qO- "http://localhost:9090/-/healthy" &>/dev/null; then
        log_success "✓ Prometheus is healthy"
    else
        log_error "✗ Prometheus health check failed"
    fi
    
    # Test Prometheus targets
    if kubectl exec -n "$NAMESPACE" deployment/prometheus -- wget -qO- "http://localhost:9090/api/v1/targets" &>/dev/null; then
        log_success "✓ Prometheus targets endpoint working"
    else
        log_error "✗ Prometheus targets endpoint failed"
    fi
}

# Test ingress (if available)
test_ingress() {
    log_info "Testing ingress configuration..."
    
    # Check if ingress exists
    if kubectl get ingress -n "$NAMESPACE" &>/dev/null; then
        log_success "✓ Ingress resources found"
        kubectl get ingress -n "$NAMESPACE"
    else
        log_warning "⚠ No ingress resources found"
    fi
}

# Test NodePort services
test_nodeport() {
    log_info "Testing NodePort services..."
    
    # Check if NodePort services exist
    if kubectl get svc -n "$NAMESPACE" | grep -q "NodePort"; then
        log_success "✓ NodePort services found"
        kubectl get svc -n "$NAMESPACE" | grep "NodePort"
        
        # Get node IP
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
        if [ -z "$NODE_IP" ]; then
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
        fi
        
        if [ -n "$NODE_IP" ]; then
            log_info "Node IP: $NODE_IP"
            echo ""
            echo "=== NodePort Access URLs ==="
            echo "Frontend: http://$NODE_IP:30080"
            echo "Backend API: http://$NODE_IP:30081"
            echo "Monitoring: http://$NODE_IP:30082"
            echo "PostgreSQL: $NODE_IP:30083"
            echo "Redis: $NODE_IP:30084"
            echo "RabbitMQ AMQP: $NODE_IP:30085"
            echo "RabbitMQ Management: http://$NODE_IP:30086"
            echo "RabbitMQ Metrics: http://$NODE_IP:30087"
            echo ""
        else
            log_warning "⚠ Could not determine node IP"
        fi
    else
        log_warning "⚠ No NodePort services found"
    fi
}

# Test persistent volumes
test_persistent_volumes() {
    log_info "Testing persistent volumes..."
    
    # Check PVCs
    if kubectl get pvc -n "$NAMESPACE" &>/dev/null; then
        log_success "✓ Persistent volume claims found"
        kubectl get pvc -n "$NAMESPACE"
    else
        log_warning "⚠ No persistent volume claims found"
    fi
}

# Test RBAC
test_rbac() {
    log_info "Testing RBAC..."
    
    # Check service accounts
    if kubectl get serviceaccount -n "$NAMESPACE" &>/dev/null; then
        log_success "✓ Service accounts found"
        kubectl get serviceaccount -n "$NAMESPACE"
    else
        log_warning "⚠ No service accounts found"
    fi
    
    # Check roles
    if kubectl get role -n "$NAMESPACE" &>/dev/null; then
        log_success "✓ Roles found"
        kubectl get role -n "$NAMESPACE"
    else
        log_warning "⚠ No roles found"
    fi
    
    # Check role bindings
    if kubectl get rolebinding -n "$NAMESPACE" &>/dev/null; then
        log_success "✓ Role bindings found"
        kubectl get rolebinding -n "$NAMESPACE"
    else
        log_warning "⚠ No role bindings found"
    fi
}

# Main execution
main() {
    log_info "Starting connectivity tests for microservices stack..."
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        log_error "Namespace $NAMESPACE does not exist. Please deploy the chart first."
        exit 1
    fi
    
    # Check if pods are running
    log_info "Checking pod status..."
    kubectl get pods -n "$NAMESPACE"
    echo ""
    
    # Run tests
    test_health_endpoints
    echo ""
    test_network_policies
    echo ""
    test_database_operations
    echo ""
    test_message_queue
    echo ""
    test_monitoring
    echo ""
    test_ingress
    echo ""
    test_nodeport
    echo ""
    test_persistent_volumes
    echo ""
    test_rbac
    echo ""
    
    log_success "All connectivity tests completed!"
}

# Handle script arguments
case "${1:-}" in
    "network")
        test_network_policies
        ;;
    "health")
        test_health_endpoints
        ;;
    "database")
        test_database_operations
        ;;
    "monitoring")
        test_monitoring
        ;;
    "nodeport")
        test_nodeport
        ;;
    "all")
        main
        ;;
    *)
        echo "Usage: $0 [network|health|database|monitoring|nodeport|all]"
        echo ""
        echo "Available tests:"
        echo "  network    - Test network policies and connectivity"
        echo "  health     - Test health endpoints"
        echo "  database   - Test database operations"
        echo "  monitoring - Test monitoring setup"
        echo "  nodeport   - Test NodePort services"
        echo "  all        - Run all tests (default)"
        exit 1
        ;;
esac
