# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Kubernetes WAF.

## Quick Diagnostics

### Check WAF Status

```bash
# Check if WAF pods are running
kubectl get pods -n waf

# Check WAF logs
kubectl logs -n waf -l app.kubernetes.io/name=waf

# Check WAF service
kubectl get svc -n waf

# Check WAF endpoints
kubectl get endpoints -n waf
```

### Health Check

```bash
# Test WAF health endpoint
kubectl port-forward -n waf svc/waf 8080:8080
curl http://localhost:8080/health

# Test WAF metrics
curl http://localhost:8080/metrics
```

## Common Issues

### 1. WAF Pods Not Starting

#### Symptoms
- Pods stuck in `Pending` or `CrashLoopBackOff` state
- Error messages in pod events

#### Diagnosis
```bash
# Check pod events
kubectl describe pod -n waf <pod-name>

# Check pod logs
kubectl logs -n waf <pod-name>

# Check resource usage
kubectl top pods -n waf
```

#### Solutions

**Resource Issues:**
```yaml
# Increase resource limits in values.yaml
waf:
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
```

**Image Pull Issues:**
```bash
# Check if image exists
docker pull your-registry/k8s-waf:latest

# Update image pull policy
waf:
  image:
    pullPolicy: Always
```

**ConfigMap Issues:**
```bash
# Check ConfigMap exists
kubectl get configmap -n waf

# Verify ConfigMap content
kubectl describe configmap -n waf waf-nginx-config
```

### 2. NGINX Configuration Errors

#### Symptoms
- NGINX fails to start
- Configuration syntax errors in logs

#### Diagnosis
```bash
# Check NGINX configuration
kubectl exec -n waf <pod-name> -- nginx -t

# Check NGINX logs
kubectl logs -n waf <pod-name> | grep nginx
```

#### Solutions

**Fix Configuration Syntax:**
```yaml
# Ensure proper YAML syntax in values.yaml
waf:
  nginx:
    customConfig: |
      # Valid NGINX configuration here
      upstream backend {
          server backend-service:8080;
      }
```

**Check ConfigMap Mounting:**
```bash
# Verify ConfigMap is mounted
kubectl exec -n waf <pod-name> -- ls -la /etc/nginx/
```

### 3. ModSecurity Issues

#### Symptoms
- ModSecurity errors in logs
- WAF not blocking expected requests
- High false positive rate

#### Diagnosis
```bash
# Check ModSecurity logs
kubectl logs -n waf <pod-name> | grep modsec

# Check ModSecurity configuration
kubectl exec -n waf <pod-name> -- cat /etc/nginx/modsecurity/modsecurity.conf
```

#### Solutions

**Enable Debug Logging:**
```yaml
waf:
  modsecurity:
    debugLog:
      enabled: true
      level: 9
```

**Adjust CRS Rules:**
```yaml
waf:
  security:
    crsConfig:
      paranoiaLevel: 1  # Start with lower level
      anomalyThreshold: 10
      excludeRules:
        - "941100"  # Exclude problematic rules
```

**Check CRS Files:**
```bash
# Verify CRS files are present
kubectl exec -n waf <pod-name> -- ls -la /etc/nginx/modsecurity/rules/
```

### 4. TLS/SSL Issues

#### Symptoms
- HTTPS not working
- Certificate errors
- TLS handshake failures

#### Diagnosis
```bash
# Check TLS secret
kubectl get secret -n waf

# Test TLS connection
openssl s_client -connect <waf-service>:443 -servername <domain>

# Check certificate
kubectl get secret -n waf waf-tls -o yaml
```

#### Solutions

**Generate Self-Signed Certificate:**
```bash
# Create self-signed certificate for testing
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=waf.example.com"

# Create Kubernetes secret
kubectl create secret tls waf-tls \
  --key tls.key --cert tls.crt -n waf
```

**Use Cert-Manager:**
```yaml
waf:
  tls:
    enabled: true
    certManager:
      enabled: true
      clusterIssuer: letsencrypt-prod
```

### 5. Rate Limiting Issues

#### Symptoms
- Legitimate requests being blocked
- Rate limiting not working
- High error rates

#### Diagnosis
```bash
# Check rate limiting logs
kubectl logs -n waf <pod-name> | grep "limiting requests"

# Check NGINX status
curl http://localhost:8080/metrics | grep rate_limit
```

#### Solutions

**Adjust Rate Limits:**
```yaml
waf:
  rateLimit:
    requests: 100  # Increase if too restrictive
    burst: 200
    window: "1m"
```

**Whitelist IPs:**
```yaml
waf:
  security:
    whitelistIps:
      - "10.0.0.0/8"
      - "192.168.0.0/16"
```

### 6. Monitoring Issues

#### Symptoms
- No metrics available
- Prometheus not scraping
- Grafana dashboards empty

#### Diagnosis
```bash
# Check metrics endpoint
curl http://localhost:8080/metrics

# Check ServiceMonitor
kubectl get servicemonitor -n waf

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-k8s 9090:9090
```

#### Solutions

**Enable Monitoring:**
```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: "30s"
```

**Check Prometheus Configuration:**
```bash
# Verify ServiceMonitor is created
kubectl get servicemonitor -n waf -o yaml
```

### 7. Fail2Ban Issues

#### Symptoms
- Fail2Ban not blocking IPs
- Fail2Ban container not starting
- No ban actions

#### Diagnosis
```bash
# Check Fail2Ban status
kubectl exec -n waf <pod-name> -c fail2ban -- fail2ban-client status

# Check Fail2Ban logs
kubectl logs -n waf <pod-name> -c fail2ban
```

#### Solutions

**Enable Fail2Ban:**
```yaml
waf:
  security:
    fail2ban:
      enabled: true
      maxRetry: 5
      bantime: 3600
```

**Check Jail Configuration:**
```bash
# Verify jail configuration
kubectl exec -n waf <pod-name> -c fail2ban -- cat /etc/fail2ban/jail.local
```

### 8. Performance Issues

#### Symptoms
- High latency
- Low throughput
- Resource exhaustion

#### Diagnosis
```bash
# Check resource usage
kubectl top pods -n waf

# Check NGINX worker processes
kubectl exec -n waf <pod-name> -- ps aux | grep nginx

# Check connection limits
kubectl exec -n waf <pod-name> -- cat /proc/sys/net/core/somaxconn
```

#### Solutions

**Optimize Resources:**
```yaml
waf:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  
  nginx:
    workerProcesses: 4
    workerConnections: 2048
```

**Enable HPA:**
```yaml
waf:
  hpa:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

## Debug Mode

### Enable Debug Logging

```yaml
waf:
  modsecurity:
    debugLog:
      enabled: true
      level: 9
  
  nginx:
    errorLogLevel: debug
```

### Debug Commands

```bash
# Check all WAF components
kubectl get all -n waf

# Check ConfigMaps
kubectl get configmap -n waf

# Check Secrets
kubectl get secret -n waf

# Check Events
kubectl get events -n waf --sort-by='.lastTimestamp'

# Check Network Policies
kubectl get networkpolicy -n waf
```

## Log Analysis

### Common Log Patterns

**ModSecurity Block:**
```
ModSecurity: Access denied with code 403 (phase 2). 
Matched "Operator `Contains' with parameter `script' against variable `ARGS:test' (value: `<script>alert(1)</script>')`
```

**Rate Limit Hit:**
```
limiting requests, excess:1.000 by zone "waf_zone" client: 192.168.1.100
```

**TLS Error:**
```
SSL_do_handshake() failed (SSL: error:1408A0C1:SSL routines:ssl3_get_client_hello:no shared cipher)
```

### Log Filtering

```bash
# Filter ModSecurity logs
kubectl logs -n waf <pod-name> | grep modsec

# Filter rate limiting logs
kubectl logs -n waf <pod-name> | grep "limiting requests"

# Filter error logs
kubectl logs -n waf <pod-name> | grep -i error

# Filter access logs
kubectl logs -n waf <pod-name> | grep "GET\|POST"
```

## Recovery Procedures

### 1. WAF Pod Crash

```bash
# Restart WAF deployment
kubectl rollout restart deployment/waf -n waf

# Check rollout status
kubectl rollout status deployment/waf -n waf
```

### 2. Configuration Issues

```bash
# Update ConfigMap
kubectl apply -f configmap.yaml

# Restart pods to pick up new config
kubectl rollout restart deployment/waf -n waf
```

### 3. Certificate Issues

```bash
# Update TLS secret
kubectl apply -f secret.yaml

# Restart WAF to pick up new certificate
kubectl rollout restart deployment/waf -n waf
```

## Support Resources

- [NGINX Documentation](https://nginx.org/en/docs/)
- [ModSecurity Reference](https://github.com/SpiderLabs/ModSecurity/wiki)
- [OWASP CRS Documentation](https://coreruleset.org/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [Helm Troubleshooting](https://helm.sh/docs/chart_template_guide/debugging/)

## Getting Help

1. **Check logs** for specific error messages
2. **Verify configuration** syntax and values
3. **Test components** individually
4. **Check resource limits** and availability
5. **Review network policies** and connectivity
6. **Consult documentation** for specific features
7. **Search existing issues** in the project repository
8. **Create detailed bug report** with logs and configuration 