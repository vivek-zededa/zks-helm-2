# Fixes Applied to Helm Chart

## Issues Found and Fixed

1. **PostgreSQL Deployment Bug**
   - Fixed: `POSTGRES_USER` was incorrectly set to password value instead of "postgres"
   - File: `templates/postgresql-deployment.yaml`

2. **Frontend Nginx DNS Resolution**
   - Fixed: Added resolver directive for dynamic DNS resolution of backend service
   - File: `templates/frontend-configmap.yaml`

3. **Backend Health Checks**
   - Fixed: Changed from HTTP health checks to TCP socket checks (endpoints don't exist in plain node image)
   - File: `templates/backend-deployment.yaml`

4. **Init Container Commands**
   - Fixed: RabbitMQ wait container now uses busybox with netcat instead of rabbitmq-diagnostics
   - Files: `templates/backend-deployment.yaml`, `templates/worker-deployment.yaml`

5. **Redis Password Handling**
   - Fixed: Redis password environment variable is now conditional based on auth.enabled
   - File: `templates/redis-deployment.yaml`

## Deployment Instructions

Since you deployed from a tgz file, you need to:

1. **Rebuild the Helm chart tgz:**
   ```bash
   helm package .
   ```

2. **Clean up the stuck PVCs and redeploy:**
   ```bash
   export KUBECONFIG=/path/to/your/kubeconfig
   
   # Delete stuck PVCs
   kubectl delete pvc postgresql-pvc rabbitmq-pvc redis-pvc --ignore-not-found=true
   
   # Uninstall existing release
   helm uninstall <release-name> -n default
   
   # Wait a few seconds
   sleep 5
   
   # Install with the fixed chart
   helm install <release-name> complex-microservices-stack-0.1.0.tgz \
       --namespace default \
       --wait \
       --timeout 15m
   ```

Or use the provided script:
```bash
./debug-and-fix.sh default <release-name>
```

Then rebuild your tgz and redeploy with the new fixed chart.
