# Kubernetes Web Application Firewall (WAF)

A production-grade, open-source Web Application Firewall for Kubernetes clusters with advanced security features, monitoring, and GitOps-ready deployment.

## 🛡️ Features

### Core Security
- **NGINX + ModSecurity**: Industry-standard WAF with OWASP CRS 3.3
- **OWASP Top 10 Protection**: Comprehensive protection against common web vulnerabilities
- **Rate Limiting**: Advanced rate limiting with burst protection
- **TLS/SSL Termination**: Full TLS 1.3 support with automatic certificate management
- **Reverse Proxy**: High-performance reverse proxy with load balancing
- **IP Whitelisting/Blacklisting**: Dynamic IP management
- **Request/Response Filtering**: Advanced content filtering capabilities

### Advanced Security
- **Fail2Ban Integration**: Automated IP blocking for malicious behavior
- **Wazuh Integration**: Extended security logging and SIEM integration
- **VAPT-Friendly**: Penetration testing ready with comprehensive logging
- **Security Headers**: Automatic security header injection
- **Bot Protection**: Advanced bot detection and mitigation
- **DDoS Protection**: Layer 7 DDoS mitigation

### Monitoring & Observability
- **Prometheus Metrics**: Comprehensive metrics collection
- **Grafana Dashboards**: Pre-built security monitoring dashboards
- **Alerting**: Prometheus AlertManager integration
- **Structured Logging**: JSON-formatted logs for easy parsing
- **Audit Trail**: Complete request/response audit logging

### DevOps & GitOps
- **Helm Charts**: Production-ready Helm deployment
- **ArgoCD Ready**: GitOps deployment configuration
- **CI/CD Pipeline**: GitHub Actions for automated deployment
- **Multi-Environment**: Dev, staging, production configurations
- **Secrets Management**: Kubernetes secrets integration

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ingress       │    │   WAF Service   │    │   Backend Apps  │
│   Controller    │───▶│   (NGINX +      │───▶│   (Your Apps)   │
│                 │    │   ModSecurity)  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   Monitoring    │
                       │   (Prometheus,  │
                       │   Grafana,      │
                       │   AlertManager) │
                       └─────────────────┘
```

## 📋 Prerequisites

- Kubernetes cluster 1.24+
- Helm 3.8+
- kubectl configured
- NGINX Ingress Controller
- Cert-Manager (for TLS)
- Prometheus Operator (optional, for monitoring)

## 🚀 Quick Start

### 1. Add Helm Repository
```bash
helm repo add k8s-waf https://your-github-username.github.io/k8s-waf
helm repo update
```

### 2. Install WAF
```bash
# Basic installation
helm install waf k8s-waf/waf

# With custom values
helm install waf k8s-waf/waf -f values-production.yaml
```

### 3. Configure Ingress
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
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

## ⚙️ Configuration

### Basic Configuration
```yaml
# values.yaml
waf:
  enabled: true
  mode: "block"  # block, detect, off
  
  # Rate Limiting
  rateLimit:
    enabled: true
    requests: 100
    burst: 200
    window: 1m
    
  # Security Rules
  security:
    owaspRules: true
    customRules: []
    whitelistIps: []
    blacklistIps: []
    
  # TLS Configuration
  tls:
    enabled: true
    certManager: true
    minTlsVersion: "1.2"
    
  # Monitoring
  monitoring:
    enabled: true
    prometheus: true
    grafana: true
```

### Advanced Configuration
```yaml
# values-production.yaml
waf:
  # High Availability
  replicaCount: 3
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "500m"
      
  # Security Hardening
  security:
    fail2ban:
      enabled: true
      maxRetry: 5
      bantime: 3600
    wazuh:
      enabled: true
      endpoint: "wazuh-manager:1514"
      
  # Performance Tuning
  nginx:
    workerProcesses: auto
    workerConnections: 1024
    keepaliveTimeout: 65
    clientMaxBodySize: 10m
```

## 🔧 Customization

### Custom ModSecurity Rules
```yaml
# config/modsecurity/custom-rules.conf
SecRule ARGS "@contains malicious" \
    "id:1000,\
    phase:2,\
    block,\
    msg:'Custom malicious content detected',\
    logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}'"
```

### Custom NGINX Configuration
```yaml
# config/nginx/custom.conf
location /api/ {
    proxy_pass http://backend-service;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## 📊 Monitoring

### Prometheus Metrics
The WAF exposes the following metrics:
- `waf_requests_total`: Total requests processed
- `waf_requests_blocked`: Requests blocked by WAF
- `waf_response_time_seconds`: Response time histogram
- `waf_rate_limit_exceeded`: Rate limit violations
- `waf_modsecurity_rules_triggered`: ModSecurity rule triggers

### Grafana Dashboard
Import the provided Grafana dashboard for comprehensive WAF monitoring:
- Request volume and patterns
- Security incidents and blocked requests
- Performance metrics
- Rate limiting statistics
- ModSecurity rule effectiveness

## 🚨 Alerting

### Pre-configured Alerts
- High request volume
- Excessive blocked requests
- Rate limit violations
- ModSecurity rule triggers
- Certificate expiration
- Service health issues

### Custom Alert Rules
```yaml
# monitoring/alerts/custom-alerts.yaml
- alert: HighBlockRate
  expr: rate(waf_requests_blocked[5m]) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High WAF block rate detected"
    description: "WAF is blocking {{ $value }} requests per second"
```

## 🔒 Security Best Practices

### Network Security
- Use Network Policies to restrict traffic
- Implement mTLS for service-to-service communication
- Regular security updates and patches
- Monitor for suspicious network activity

### Access Control
- Implement RBAC for Kubernetes resources
- Use service accounts with minimal privileges
- Regular access reviews and audits
- Secure secret management

### Monitoring & Logging
- Centralized logging with log aggregation
- Real-time security monitoring
- Regular security assessments
- Incident response procedures

## 🧪 Testing

### Security Testing
```bash
# Run security tests
make security-test

# Run penetration tests
make pentest

# Run compliance checks
make compliance-check
```

### Load Testing
```bash
# Run load tests
make load-test

# Run stress tests
make stress-test
```

## 📈 Performance Tuning

### NGINX Optimization
- Worker processes: Set to number of CPU cores
- Worker connections: Adjust based on memory
- Keep-alive settings: Optimize for your traffic patterns
- Buffer sizes: Tune for your application needs

### ModSecurity Optimization
- Rule set optimization
- Performance tuning
- Custom rule development
- Regular rule updates

## 🔄 Updates & Maintenance

### Regular Maintenance
- Monthly security updates
- Quarterly performance reviews
- Annual security assessments
- Continuous monitoring and alerting

### Backup & Recovery
- Configuration backups
- Disaster recovery procedures
- Incident response plans
- Business continuity planning

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/your-username/k8s-waf/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-username/k8s-waf/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/k8s-waf/discussions)
- **Security**: [Security Policy](SECURITY.md)

## 🙏 Acknowledgments

- [OWASP](https://owasp.org/) for security guidelines
- [ModSecurity](https://modsecurity.org/) for WAF engine
- [NGINX](https://nginx.org/) for web server
- [Kubernetes](https://kubernetes.io/) for orchestration platform