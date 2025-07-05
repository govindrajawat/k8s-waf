# 🚀 Deployment Guide for Kubernetes WAF

**Repository**: [https://github.com/govindrajawat/k8s-waf](https://github.com/govindrajawat/k8s-waf)  
**Author**: [Govind Singh Rajawat](https://github.com/govindrajawat)  
**Email**: [govindrajawat260398@gmail.com](mailto:govindrajawat260398@gmail.com)

## 📋 Pre-Deployment Checklist

### ✅ Prerequisites
- [ ] Kubernetes cluster 1.24+
- [ ] Helm 3.8+
- [ ] kubectl configured
- [ ] NGINX Ingress Controller installed
- [ ] Cert-Manager installed (for TLS)
- [ ] Prometheus Operator (optional, for monitoring)

### ✅ Repository Setup
- [ ] Fork/clone the repository
- [ ] Download OWASP CRS rules
- [ ] Configure your environment

## 🔧 Step-by-Step Deployment

### 1. Clone and Setup Repository

```bash
# Clone the repository
git clone https://github.com/govindrajawat/k8s-waf.git
cd k8s-waf

# Download OWASP CRS rules
git clone https://github.com/coreruleset/coreruleset.git
cp -r coreruleset/rules/* config/modsecurity/rules/
rm -rf coreruleset
```

### 2. Build Docker Image

```bash
# Build the WAF image
docker build -t govindrajawat/k8s-waf:latest .

# Push to your registry (if using Docker Hub)
docker push govindrajawat/k8s-waf:latest

# Or use GitHub Container Registry
docker tag govindrajawat/k8s-waf:latest ghcr.io/govindrajawat/k8s-waf:latest
docker push ghcr.io/govindrajawat/k8s-waf:latest
```

### 3. Deploy to Kubernetes

#### Option A: Direct Helm Installation
```bash
# Create namespace
kubectl create namespace waf

# Install WAF
helm install waf charts/waf/ \
  --namespace waf \
  --set waf.image.repository=govindrajawat/k8s-waf \
  --set waf.image.tag=latest
```

#### Option B: Using Custom Values
```bash
# Create custom values file
cat > values-production.yaml << EOF
waf:
  enabled: true
  replicaCount: 3
  
  image:
    repository: govindrajawat/k8s-waf
    tag: latest
    pullPolicy: Always
  
  security:
    fail2ban:
      enabled: true
    wazuh:
      enabled: false
  
  monitoring:
    enabled: true
    prometheus: true
    grafana: true

  tls:
    enabled: true
    certManager: true
EOF

# Deploy with custom values
helm install waf charts/waf/ \
  --namespace waf \
  --values values-production.yaml
```

### 4. Verify Deployment

```bash
# Check pods
kubectl get pods -n waf

# Check services
kubectl get svc -n waf

# Check ingress
kubectl get ingress -n waf

# Check logs
kubectl logs -n waf -l app.kubernetes.io/name=waf
```

### 5. Configure Ingress

```yaml
# Create ingress for your application
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: waf
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/waf-enabled: "true"
    nginx.ingress.kubernetes.io/waf-mode: "block"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - your-domain.com
    secretName: your-tls-secret
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: waf-service
            port:
              number: 443
```

## 🔍 Testing the Deployment

### 1. Health Check
```bash
# Test health endpoint
kubectl port-forward -n waf svc/waf 8080:8080
curl http://localhost:8080/health
```

### 2. Security Testing
```bash
# Test WAF protection
curl -H "User-Agent: sqlmap" http://your-domain.com/
curl -H "X-Forwarded-For: 192.168.1.100" http://your-domain.com/
curl -d "payload=<script>alert('xss')</script>" http://your-domain.com/
```

### 3. Load Testing
```bash
# Install wrk
sudo apt-get install wrk

# Run load test
wrk -t12 -c400 -d30s http://your-domain.com/
```

## 📊 Monitoring Setup

### 1. Prometheus Metrics
```bash
# Check metrics endpoint
curl http://localhost:8080/metrics

# Verify Prometheus targets
kubectl get servicemonitor -n waf
```

### 2. Grafana Dashboard
```bash
# Access Grafana (if installed)
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Import dashboard from docs/grafana-dashboard.json
```

### 3. Alerting
```bash
# Check alert rules
kubectl get prometheusrule -n waf

# Test alerts
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

## 🔒 Security Configuration

### 1. Network Policies
```bash
# Apply network policies
kubectl apply -f charts/waf/templates/networkpolicy.yaml
```

### 2. RBAC
```bash
# Check RBAC
kubectl get clusterrole,clusterrolebinding -l app.kubernetes.io/name=waf
```

### 3. Secrets Management
```bash
# Create TLS secret
kubectl create secret tls waf-tls \
  --key tls.key \
  --cert tls.crt \
  -n waf
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Pod Not Starting
```bash
# Check pod events
kubectl describe pod -n waf <pod-name>

# Check logs
kubectl logs -n waf <pod-name>
```

#### 2. Configuration Issues
```bash
# Validate NGINX config
kubectl exec -n waf <pod-name> -- nginx -t

# Check ConfigMap
kubectl get configmap -n waf
kubectl describe configmap -n waf waf-nginx-config
```

#### 3. Security Issues
```bash
# Check ModSecurity logs
kubectl logs -n waf <pod-name> | grep modsec

# Check Fail2Ban status
kubectl exec -n waf <pod-name> -c fail2ban -- fail2ban-client status
```

## 🔄 Updates and Maintenance

### 1. Update WAF
```bash
# Pull latest changes
git pull origin main

# Update Helm chart
helm upgrade waf charts/waf/ \
  --namespace waf \
  --values values-production.yaml
```

### 2. Backup Configuration
```bash
# Backup current configuration
helm get values waf -n waf > waf-backup.yaml

# Backup ConfigMaps
kubectl get configmap -n waf -o yaml > configmaps-backup.yaml
```

### 3. Rollback
```bash
# Rollback to previous version
helm rollback waf -n waf

# Or restore from backup
helm upgrade waf charts/waf/ \
  --namespace waf \
  --values waf-backup.yaml
```

## 📈 Performance Optimization

### 1. Resource Tuning
```yaml
# Optimize resources in values.yaml
waf:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### 2. NGINX Optimization
```yaml
# Tune NGINX settings
waf:
  nginx:
    workerProcesses: "auto"
    workerConnections: 2048
    keepaliveTimeout: 120
```

### 3. Monitoring Optimization
```yaml
# Enable monitoring
waf:
  monitoring:
    enabled: true
    prometheus: true
    grafana: true
```

## 🎯 Production Checklist

### Security
- [ ] TLS certificates configured
- [ ] Network policies applied
- [ ] RBAC configured
- [ ] Security headers enabled
- [ ] Rate limiting configured
- [ ] Fail2Ban enabled

### Monitoring
- [ ] Prometheus metrics enabled
- [ ] Grafana dashboard imported
- [ ] Alerting rules configured
- [ ] Log aggregation setup
- [ ] Health checks working

### Performance
- [ ] Resource limits set
- [ ] HPA configured
- [ ] Load testing completed
- [ ] Performance baselines established

### Compliance
- [ ] Audit logging enabled
- [ ] Security policies documented
- [ ] Backup procedures tested
- [ ] Incident response plan ready

## 📞 Support

### Getting Help
- **Documentation**: [README.md](README.md)
- **Issues**: [GitHub Issues](https://github.com/govindrajawat/k8s-waf/issues)
- **Discussions**: [GitHub Discussions](https://github.com/govindrajawat/k8s-waf/discussions)
- **Email**: [govindrajawat260398@gmail.com](mailto:govindrajawat260398@gmail.com)

### Community
- **LinkedIn**: [Govind Singh Rajawat](https://linkedin.com/in/govindrajawat)
- **GitHub**: [@govindrajawat](https://github.com/govindrajawat)

---

**Happy Deploying! 🚀**

*This deployment guide is maintained by [Govind Singh Rajawat](https://github.com/govindrajawat) - DevOps Engineer specializing in cloud infrastructure, CI/CD, and Kubernetes security.* 