# Helm Chart Fixes for Future Deployments

## Issues Fixed

### 1. RabbitMQ ConfigMap - Invalid Configuration Variables ✅
**Problem**: RabbitMQ was crashing with error `failed_to_prepare_configuration` due to invalid configuration variables.

**Fixed Variables Removed**:
- `connection_flow_control`
- `channel_flow_control`
- `global_qos_prefetch_count`
- `msg_store_file_size_limit`

**Fix**: Removed invalid variables from `templates/rabbitmq-configmap.yaml`

---

### 2. PostgreSQL Secret Missing ✅
**Problem**: Backend deployment was failing because it references a secret named `postgresql` with key `postgres-password`, but this secret was not being created by the chart.

**Fix**: Created `templates/postgresql-secret.yaml` that creates:
- Secret name: `postgresql`
- Keys: `postgres-password`, `postgres-user`, `postgres-db`

---

### 3. RabbitMQ Health Probes Timing Out ✅
**Problem**: RabbitMQ was starting successfully but health probes using `rabbitmq-diagnostics -q ping` were timing out, causing restarts.

**Fix**: Changed health probes in `templates/rabbitmq-deployment.yaml`:
- Switched from `exec` (rabbitmq-diagnostics) to `tcpSocket` probes
- Increased `initialDelaySeconds` to 60s for liveness, 30s for readiness
- Added proper `timeoutSeconds` and `failureThreshold` settings
- TCP probes check port 5672 (AMQP) directly

**Before**:
```yaml
livenessProbe:
  exec:
    command: ["rabbitmq-diagnostics", "-q", "ping"]
  initialDelaySeconds: 30
```

**After**:
```yaml
livenessProbe:
  tcpSocket:
    port: amqp
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

---

### 4. Init Container Wait Logic Improvements ✅
**Problem**: Init containers were waiting indefinitely with `until` loops that could hang if services never become available.

**Fix**: Updated init container wait commands in:
- `templates/backend-deployment.yaml`
- `templates/worker-deployment.yaml`

**Improvements**:
1. Added maximum retry limit (60 attempts = ~2 minutes max wait)
2. Added attempt counter for better logging
3. Added timeout error handling (exit 1 on failure)
4. Improved error suppression for Redis ping command

**Before**:
```yaml
command: ['sh', '-c', 'until pg_isready -h postgresql -p 5432; do echo waiting for postgresql; sleep 2; done;']
```

**After**:
```yaml
command: ['sh', '-c', 'for i in $(seq 1 60); do if pg_isready -h postgresql -p 5432 -U postgres; then exit 0; fi; echo "waiting for postgresql (attempt $i/60)..."; sleep 2; done; echo "timeout waiting for postgresql"; exit 1']
```

---

### 5. Backend Container Startup Command Missing ✅
**Problem**: Backend container was crashing because it had no command to install dependencies or start the Node.js application. The ConfigMap had `app.js` and `package.json`, but the container didn't know how to run them.

**Fix**: Added startup command in `templates/backend-deployment.yaml`:
- Copies files from ConfigMap to working directory
- Installs npm dependencies
- Starts the Node.js application

**Before**: No command specified (container would exit immediately)

**After**:
```yaml
workingDir: /app
command: ['sh', '-c', 'cp /app-config/app.js /app-config/package.json /app/ && cd /app && npm install && node app.js']
```

**Note**: Changed from glob patterns with `|| true` to explicit file copying to ensure copy failures are caught early.

Also fixed volume mounts:
- ConfigMap mounted at `/app-config` (read-only)
- EmptyDir mounted at `/app` (writable) for dependencies and runtime

---

### 6. Worker Container Startup Command Missing ✅
**Problem**: Worker container was erroring because it tried to run Python code without installing dependencies first. The ConfigMap had `worker.py` and `requirements.txt`, but dependencies weren't being installed.

**Fix**: Added startup command in `templates/worker-deployment.yaml`:
- Copies files from ConfigMap to working directory
- Installs Python dependencies from requirements.txt
- Starts the Python worker application

**Before**: `command: ["python", "/app/worker.py"]` (would fail - no dependencies installed)

**After**:
```yaml
workingDir: /app
command: ['sh', '-c', 'cp /app-config/worker.py /app-config/requirements.txt /app/ && cd /app && pip install --no-cache-dir -r requirements.txt && python worker.py']
```

**Note**: Changed from glob patterns with `|| true` to explicit file copying, and removed `asyncio` from requirements.txt (it's part of Python's standard library).

Also fixed volume mounts:
- ConfigMap mounted at `/app-config` (read-only)
- EmptyDir mounted at `/app` (writable) for dependencies and runtime

---

## Files Modified

1. ✅ `templates/rabbitmq-configmap.yaml` - Removed invalid configuration variables
2. ✅ `templates/postgresql-secret.yaml` - **NEW FILE** - Creates PostgreSQL secret
3. ✅ `templates/rabbitmq-deployment.yaml` - Fixed health probes (TCP instead of exec)
4. ✅ `templates/backend-deployment.yaml` - Improved init container wait logic + Added startup command (fixed command logic)
5. ✅ `templates/worker-deployment.yaml` - Improved init container wait logic + Added startup command (fixed command logic)
6. ✅ `templates/worker-configmap.yaml` - Removed `asyncio` from requirements.txt (standard library)
7. ✅ `templates/backend-configmap.yaml` - Fixed Redis client configuration (Redis v4.x API change)
8. ✅ `templates/worker-configmap.yaml` - Fixed Redis client configuration (Redis v4.x API change - use from_url)
9. ✅ `templates/rabbitmq-configmap.yaml` - Fixed RabbitMQ definitions.json authentication (removed user from definitions, use env vars instead)

---

### 7. Backend Redis Connection Failure ✅
**Problem**: Backend was crashing with `ECONNREFUSED ::1:6379` error. The Redis client v4.x library changed its API and was defaulting to IPv6 localhost instead of using the provided host/port.

**Fix**: Updated Redis client initialization in `templates/backend-configmap.yaml` to use the `socket` option required by Redis v4.x API.

**Before**:
```javascript
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
});
```

**After**:
```javascript
const redisClient = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'redis',
    port: parseInt(process.env.REDIS_PORT || '6379'),
  }
});
```

---

### 8. Worker Redis Connection Failure ✅
**Problem**: Worker pods were crashing after backend Redis fix. The Python redis.asyncio client v4.x might have connection issues when using host/port directly.

**Fix**: Updated Redis client initialization in `templates/worker-configmap.yaml` to use `from_url()` which is more reliable for redis.asyncio v4.x.

**Before**:
```python
self.redis_client = redis.Redis(
    host=os.getenv('REDIS_HOST', 'redis'),
    port=int(os.getenv('REDIS_PORT', 6379)),
    decode_responses=True
)
```

**After**:
```python
redis_host = os.getenv('REDIS_HOST', 'redis')
redis_port = int(os.getenv('REDIS_PORT', 6379))
redis_url = f"redis://{redis_host}:{redis_port}"
self.redis_client = redis.from_url(
    redis_url,
    decode_responses=True
)
```

---

### 9. Worker RabbitMQ Authentication Failure ✅
**Problem**: Worker pods were crashing with `ACCESS_REFUSED - Login was refused using authentication mechanism PLAIN`. The RabbitMQ `definitions.json` had a user with an incorrectly formatted password_hash (base64 encoded instead of SHA256 hashed), which conflicted with environment variable-based user creation.

**Fix**: Updated `templates/rabbitmq-configmap.yaml` to remove user creation from `definitions.json` and rely on environment variables (`RABBITMQ_DEFAULT_USER` and `RABBITMQ_DEFAULT_PASS`) for user creation.

**Before**:
```json
"users": [
  {
    "name": "user",
    "password_hash": "cGFzc3dvcmQ=",  // base64 encoded, not SHA256 hash!
    "hashing_algorithm": "rabbit_password_hashing_sha256",
    "tags": "administrator"
  }
],
"permissions": [...]
```

And in `rabbitmq.conf`:
```
management.load_definitions = /etc/rabbitmq/definitions.json
```

**After**:
```json
"users": [],
"permissions": []
```

Removed `management.load_definitions` since we're using environment variables for user creation.

**Note**: RabbitMQ deployment already sets `RABBITMQ_DEFAULT_USER` and `RABBITMQ_DEFAULT_PASS` environment variables, which creates the user automatically. The definitions.json file still contains queue and exchange definitions but no user definitions.

---

## Testing the Fixed Chart

After rebuilding and redeploying, all pods should start successfully:

```bash
# Rebuild Helm chart
helm package .

# Deploy fixed chart
helm install <release-name> complex-microservices-stack-0.1.0.tgz \
    --namespace <namespace> \
    --wait \
    --timeout 15m

# Verify deployment
kubectl get pods -n <namespace>
kubectl get deployments -n <namespace>
```

## Expected Results

After these fixes:
- ✅ **RabbitMQ**: Should start and become ready (TCP health checks)
- ✅ **PostgreSQL**: Secret will be available for backend
- ✅ **Backend API**: Init containers will complete, dependencies installed, app starts successfully
- ✅ **Worker**: Init containers will complete, dependencies installed, app starts successfully
- ✅ **All Services**: Proper startup sequence with retries, timeouts, and application execution

---

## Deployment Order

The chart now handles dependencies better:
1. **PostgreSQL** starts first (no dependencies)
2. **Redis** starts (no dependencies)
3. **RabbitMQ** starts (no dependencies, but needs ~30-60s for readiness)
4. **Backend** waits for PostgreSQL, Redis, and RabbitMQ
5. **Worker** waits for RabbitMQ and Redis
6. **Frontend** starts independently
7. **Prometheus** starts independently

