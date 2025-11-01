# Complex Microservices Helm Chart

A comprehensive Helm chart designed for testing orchestrator products with interdependent applications, network policies, ingress, and egress configurations.

## Overview

This Helm chart deploys a complex microservices stack consisting of:

- **Frontend**: Nginx-based web application with React/Node.js
- **Backend API**: Node.js Express API with database and cache dependencies
- **Database**: PostgreSQL with persistent storage
- **Cache**: Redis for caching and session storage
- **Message Queue**: RabbitMQ for asynchronous processing
- **Worker**: Python-based background worker processing messages
- **Monitoring**: Prometheus for metrics collection
- **Network Policies**: Comprehensive network security rules
- **Ingress**: Multiple ingress configurations for external access

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Frontend     │    │   Backend API   │    │     Worker     │
│   (Nginx)       │◄──►│   (Node.js)     │◄──►│   (Python)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Ingress      │    │   PostgreSQL    │    │    RabbitMQ     │
│   (External)    │    │   (Database)    │    │  (Message Q)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │     Redis       │    │   Prometheus   │
                       │    (Cache)      │    │  (Monitoring)  │
                       └─────────────────┘    └─────────────────┘
```

## Features

### Interdependent Applications
- Frontend depends on Backend API
- Backend API depends on PostgreSQL, Redis, and RabbitMQ
- Worker depends on RabbitMQ and Redis
- All services have health checks and readiness probes

### Network Policies
- Default deny all ingress/egress traffic
- Granular allow rules for inter-service communication
- DNS resolution allowed for all pods
- Monitoring service can scrape all other services

### Ingress Configuration
- Multiple ingress resources for different services
- API endpoints with CORS support
- Monitoring with basic authentication
- SSL/TLS configuration support

### Security
- Service accounts with RBAC policies
- Secrets management for sensitive data
- Network policies for traffic control
- Resource limits and requests

### Monitoring
- Prometheus metrics collection
- Service discovery for all components
- Custom metrics endpoints
- Health check endpoints

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.x
- Ingress controller (nginx recommended)
- Storage class for persistent volumes (optional if using `values-no-storage.yaml`)

## Installation

### Basic Installation

```bash
# Add the chart repository (if using a repository)
helm repo add my-repo https://charts.example.com
helm repo update

# Install the chart
helm install microservices-test ./custom-helm-chart \
  --namespace microservices-test \
  --create-namespace
```

### Custom Configuration

```bash
# Install with custom values
helm install microservices-test ./custom-helm-chart \
  --namespace microservices-test \
  --create-namespace \
  --values custom-values.yaml
```

### Development Installation

```bash
# Install with development settings
helm install microservices-test ./custom-helm-chart \
  --namespace microservices-test \
  --create-namespace \
  --set app.environment=development \
  --set frontend.replicas=1 \
  --set backend.replicas=1 \
  --set worker.replicas=1
```

### Installation Without Persistent Storage

For testing environments where persistent storage is not available:

```bash
# Install without persistent storage
helm install microservices-test ./custom-helm-chart \
  --namespace microservices-test \
  --create-namespace \
  --values values-no-storage.yaml
```

**Note**: Data will be lost when pods restart when using `values-no-storage.yaml`.

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.name` | Application name | `complex-microservices` |
| `app.environment` | Environment | `testing` |
| `frontend.enabled` | Enable frontend | `true` |
| `backend.enabled` | Enable backend | `true` |
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `redis.enabled` | Enable Redis | `true` |
| `rabbitmq.enabled` | Enable RabbitMQ | `true` |
| `worker.enabled` | Enable worker | `true` |
| `monitoring.enabled` | Enable monitoring | `true` |
| `networkPolicies.enabled` | Enable network policies | `true` |
| `ingress.enabled` | Enable ingress | `true` |
| `nodePort.enabled` | Enable NodePort services | `true` |

### Resource Configuration

```yaml
frontend:
  replicas: 2
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

backend:
  replicas: 3
  resources:
    requests:
      memory: "256Mi"
      cpu: "200m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

### Storage Configuration

```yaml
postgresql:
  primary:
    persistence:
      enabled: true
      size: 8Gi

redis:
  master:
    persistence:
      enabled: true
      size: 2Gi

rabbitmq:
  persistence:
    enabled: true
    size: 4Gi
```

### NodePort Configuration

```yaml
nodePort:
  enabled: true
  frontend:
    port: 30080
  backend:
    port: 30081
  monitoring:
    port: 30082
  postgresql:
    port: 30083
  redis:
    port: 30084
  rabbitmq:
    amqpPort: 30085
    managementPort: 30086
    metricsPort: 30087
```

## Testing the Deployment

### Health Checks

```bash
# Check all pods are running
kubectl get pods -n microservices-test

# Check services
kubectl get svc -n microservices-test

# Check ingress
kubectl get ingress -n microservices-test
```

### Accessing Services

#### Port Forwarding (Recommended for Development)
```bash
# Frontend
kubectl port-forward svc/frontend 8080:80 -n microservices-test
# Access at http://localhost:8080

# Backend API
kubectl port-forward svc/backend-api 3000:3000 -n microservices-test
# Access at http://localhost:3000

# Monitoring
kubectl port-forward svc/prometheus 9090:9090 -n microservices-test
# Access at http://localhost:9090
```

#### NodePort Access (Direct Node Access)
```bash
# Get node IP
kubectl get nodes -o wide

# Access services directly via NodePort:
# Frontend: http://<NODE_IP>:30080
# Backend API: http://<NODE_IP>:30081
# Monitoring: http://<NODE_IP>:30082
# PostgreSQL: <NODE_IP>:30083
# Redis: <NODE_IP>:30084
# RabbitMQ AMQP: <NODE_IP>:30085
# RabbitMQ Management: http://<NODE_IP>:30086 (user: user, password: password)
# RabbitMQ Metrics: http://<NODE_IP>:30087
```

### Testing Inter-Service Communication

```bash
# Test backend API
curl http://localhost:3000/health
curl http://localhost:3000/ready

# Test database connection
curl http://localhost:3000/api/users

# Test cache
curl http://localhost:3000/api/cache/test-key
```

## Network Policies Testing

### Verify Network Isolation

```bash
# Test that pods can only communicate as defined by network policies
kubectl exec -it deployment/frontend -n microservices-test -- wget -qO- http://backend-api:3000/health

# Test that external access is blocked (should fail)
kubectl exec -it deployment/backend-api -n microservices-test -- wget -qO- http://google.com
```

### Test Ingress Rules

```bash
# Test ingress routing
curl -H "Host: api.local" http://localhost/api/health
curl -H "Host: monitoring.local" http://localhost/
```

## Monitoring and Observability

### Prometheus Metrics

The deployment includes comprehensive monitoring:

- **Application Metrics**: Custom metrics from each service
- **Infrastructure Metrics**: CPU, memory, disk usage
- **Network Metrics**: Traffic patterns and latency
- **Database Metrics**: Connection pools, query performance
- **Message Queue Metrics**: Queue depth, processing rates

### Service Discovery

Prometheus automatically discovers all services using Kubernetes service discovery.

### Alerting Rules

Custom alerting rules are included for:
- High CPU/Memory usage
- Database connection failures
- Message queue backlog
- Service unavailability

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and storage availability
2. **Network connectivity**: Verify network policies and service selectors
3. **Database connection**: Check PostgreSQL readiness and credentials
4. **Ingress not working**: Verify ingress controller and DNS configuration
5. **Backend/Worker Redis connection failures**: Ensure Redis client uses proper v4.x API (see Known Issues below)
6. **RabbitMQ startup failures**: Check for invalid configuration variables in ConfigMap
7. **Init containers timing out**: Verify dependent services (PostgreSQL, Redis, RabbitMQ) are running and accessible

### Debug Commands

```bash
# Check pod logs
kubectl logs deployment/frontend -n microservices-test
kubectl logs deployment/backend-api -n microservices-test
kubectl logs deployment/worker -n microservices-test

# Check pod status and events
kubectl get pods -n microservices-test
kubectl describe pod <pod-name> -n microservices-test

# Check init container logs
kubectl logs <pod-name> -c wait-for-db -n microservices-test
kubectl logs <pod-name> -c wait-for-redis -n microservices-test
kubectl logs <pod-name> -c wait-for-rabbitmq -n microservices-test

# Check network policies
kubectl get networkpolicies -n microservices-test

# Check ingress
kubectl describe ingress -n microservices-test

# Check persistent volumes
kubectl get pvc -n microservices-test

# Check secrets and configmaps
kubectl get secrets -n microservices-test
kubectl get configmaps -n microservices-test
```

## Uninstallation

```bash
# Remove the release
helm uninstall microservices-test -n microservices-test

# Remove the namespace (optional)
kubectl delete namespace microservices-test
```

## Customization

### Adding New Services

1. Create new deployment and service templates
2. Update network policies
3. Add ingress rules if needed
4. Update monitoring configuration

### Modifying Dependencies

1. Update init containers in deployments
2. Modify network policies for new communication patterns
3. Update health checks and readiness probes

## Security Considerations

- All secrets are base64 encoded (not encrypted)
- Network policies provide defense in depth
- Service accounts have minimal required permissions
- Resource limits prevent resource exhaustion attacks

## Performance Testing

This chart is designed for orchestrator testing and includes:

- **Load Testing**: Multiple replicas with resource limits
- **Network Testing**: Complex network policies and ingress rules
- **Storage Testing**: Persistent volumes with different access modes
- **Monitoring Testing**: Comprehensive metrics collection
- **Security Testing**: RBAC, network policies, and secrets management

## Known Issues and Fixes

This Helm chart has been tested and fixed for common deployment issues. For a complete list of fixes applied, see `HELM_CHART_FIXES.md`.

### Key Fixes Applied

1. **RabbitMQ Configuration**: Removed invalid configuration variables that caused startup failures
2. **PostgreSQL Secret**: Added required secret for backend database connections
3. **RabbitMQ Health Probes**: Changed to TCP socket probes for better reliability
4. **Init Containers**: Added timeout handling and retry logic for dependency waiting
5. **Backend/Worker Startup**: Added dependency installation and application startup commands
6. **Redis Client Configuration**: Updated to use Redis v4.x compatible APIs
   - Backend (Node.js): Uses `socket` option
   - Worker (Python): Uses `from_url()` method

### Redis v4.x Compatibility

This chart uses Redis client libraries v4.x which have API changes:
- **Node.js redis v4.x**: Requires `socket` option instead of direct `host`/`port`
- **Python redis.asyncio v4.x**: Prefers `from_url()` for connection initialization

### Application Dependencies

- **Backend**: Automatically installs npm packages and starts Node.js application
- **Worker**: Automatically installs Python packages and starts worker process
- All applications wait for dependencies (PostgreSQL, Redis, RabbitMQ) before starting

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review `HELM_CHART_FIXES.md` for detailed fix information
3. Review Kubernetes and Helm documentation
4. Check service logs and events
5. Verify network policies and ingress configuration
