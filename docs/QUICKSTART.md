# Quick Start Guide

This guide will help you deploy the Kubernetes WAF in under 10 minutes.

## Prerequisites

- Kubernetes cluster (1.24+)
- Helm 3.8+
- kubectl configured
- NGINX Ingress Controller installed

## Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/k8s-waf.git
cd k8s-waf
```

## Step 2: Build the Docker Image

```bash
# Build the WAF image
docker build -t your-registry/k8s-waf:latest .

# Push to your registry (optional)
docker push your-registry/k8s-waf:latest
```

## Step 3: Install the WAF

```bash
# Add the Helm repository
helm repo add k8s-waf https://your-username.github.io/k8s-waf
helm repo update

# Install with basic configuration
helm install waf charts/waf/ \
  --namespace waf \
  --create-namespace \
  --set waf.image.repository=your-registry/k8s-waf \
  --set waf.image.tag=latest
```

## Step 4: Configure Your Application

Create an Ingress for your application that points to the WAF:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: your-app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: waf
            port:
              number: 443
```

## Step 5: Verify Installation

```bash
# Check WAF pods
kubectl get pods -n waf

# Check WAF logs
kubectl logs -n waf -l app.kubernetes.io/name=waf

# Test the WAF
curl -H "Host: your-app.example.com" https://your-cluster-ip/health
```

## Step 6: Add OWASP CRS Rules (Optional)

Download and add OWASP CRS rules for enhanced protection:

```bash
# Download CRS rules
wget https://github.com/coreruleset/coreruleset/archive/refs/tags/v3.3.4.tar.gz
tar -xzf v3.3.4.tar.gz

# Copy rules to the config directory
cp coreruleset-3.3.4/rules/*.conf config/modsecurity/rules/

# Redeploy the WAF
helm upgrade waf charts/waf/ \
  --namespace waf \
  --set waf.image.repository=your-registry/k8s-waf \
  --set waf.image.tag=latest
```

## Configuration Examples

### Production Configuration

```bash
helm install waf charts/waf/ \
  --namespace waf \
  --create-namespace \
  --set waf.replicaCount=3 \
  --set waf.resources.requests.memory=512Mi \
  --set waf.resources.requests.cpu=250m \
  --set waf.resources.limits.memory=1Gi \
  --set waf.resources.limits.cpu=500m \
  --set waf.security.fail2ban.enabled=true \
  --set waf.security.wazuh.enabled=true \
  --set monitoring.enabled=true
```

### Development Configuration

```bash
helm install waf charts/waf/ \
  --namespace waf \
  --create-namespace \
  --set waf.replicaCount=1 \
  --set waf.resources.requests.memory=256Mi \
  --set waf.resources.requests.cpu=100m \
  --set waf.mode=detect \
  --set monitoring.enabled=false
```

## Troubleshooting

### Common Issues

1. **WAF pods not starting**: Check resource limits and image availability
2. **ModSecurity errors**: Verify CRS rules are properly placed
3. **TLS issues**: Ensure certificates are properly configured
4. **Rate limiting too strict**: Adjust rate limit values in values.yaml

### Useful Commands

```bash
# Check WAF status
kubectl get pods,svc,ing -n waf

# View WAF logs
kubectl logs -n waf -l app.kubernetes.io/name=waf -f

# Check ModSecurity logs
kubectl logs -n waf -l app.kubernetes.io/name=waf -c waf | grep modsec

# Test WAF functionality
kubectl port-forward -n waf svc/waf 8080:80
curl http://localhost:8080/health
```

## Next Steps

- [Advanced Configuration](ADVANCED.md)
- [Security Hardening](SECURITY.md)
- [Monitoring Setup](MONITORING.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md) 