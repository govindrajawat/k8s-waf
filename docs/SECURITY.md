# Security Hardening Guide

This guide provides comprehensive security hardening recommendations for the Kubernetes WAF.

## Security Architecture

### Defense in Depth

The WAF implements multiple layers of security:

1. **Network Layer**: Network policies, TLS encryption
2. **Application Layer**: NGINX security headers, rate limiting
3. **WAF Layer**: ModSecurity with OWASP CRS
4. **Container Layer**: Security contexts, read-only filesystems
5. **Kubernetes Layer**: RBAC, service accounts, pod security

## Security Configuration

### 1. Network Security

#### Network Policies

```yaml
waf:
  networkPolicy:
    enabled: true
    ingressRules:
      - from:
          - namespaceSelector:
              matchLabels:
                name: ingress-nginx
        ports:
          - protocol: TCP
            port: 80
          - protocol: TCP
            port: 443
    egressRules:
      - to:
          - namespaceSelector:
              matchLabels:
                name: backend-services
        ports:
          - protocol: TCP
            port: 8080
      - to: []  # Deny all other egress
```

#### TLS Configuration

```yaml
waf:
  tls:
    enabled: true
    minTlsVersion: "1.3"  # Use TLS 1.3 for maximum security
    cipherSuites:
      - "TLS_AES_256_GCM_SHA384"
      - "TLS_CHACHA20_POLY1305_SHA256"
      - "TLS_AES_128_GCM_SHA256"
    ocspStapling: true
    hsts:
      enabled: true
      maxAge: 31536000
      includeSubDomains: true
      preload: true
```

### 2. Application Security

#### Security Headers

```yaml
waf:
  security:
    securityHeaders:
      enabled: true
      xFrameOptions: "DENY"  # Prevent clickjacking
      xContentTypeOptions: "nosniff"
      xXSSProtection: "1; mode=block"
      strictTransportSecurity: "max-age=31536000; includeSubDomains; preload"
      contentSecurityPolicy: "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';"
      referrerPolicy: "strict-origin-when-cross-origin"
      permissionsPolicy: "geolocation=(), microphone=(), camera=(), payment=(), usb=()"
      xPermittedCrossDomainPolicies: "none"
      xDNSPrefetchControl: "off"
```

#### Rate Limiting

```yaml
waf:
  rateLimit:
    enabled: true
    requests: 50  # Conservative rate limit
    burst: 100
    window: "1m"
    zones:
      api:
        requests: 10
        burst: 20
        window: "1m"
      login:
        requests: 3
        burst: 5
        window: "5m"
      admin:
        requests: 1
        burst: 2
        window: "10m"
```

### 3. WAF Security

#### OWASP CRS Configuration

```yaml
waf:
  security:
    owaspRules: true
    crsVersion: "3.3.4"
    crsConfig:
      paranoiaLevel: 2  # Higher security level
      anomalyThreshold: 5
      blockScore: 5
      # Exclude false positives
      excludeRules:
        - "941100"  # XSS rule if causing issues
        - "942100"  # SQL injection rule if causing issues
```

#### Custom Security Rules

```yaml
waf:
  security:
    customRules:
      # Block common attack patterns
      - |
        SecRule ARGS "@contains <script" \
            "id:1000,\
            phase:2,\
            block,\
            msg:'XSS attack detected',\
            logdata:'Matched Data: %{MATCHED_VAR}'"
      
      # Block SQL injection attempts
      - |
        SecRule ARGS "@contains UNION SELECT" \
            "id:1001,\
            phase:2,\
            block,\
            msg:'SQL injection detected',\
            logdata:'Matched Data: %{MATCHED_VAR}'"
      
      # Block directory traversal
      - |
        SecRule ARGS "@contains ../" \
            "id:1002,\
            phase:2,\
            block,\
            msg:'Directory traversal detected',\
            logdata:'Matched Data: %{MATCHED_VAR}'"
      
      # Block command injection
      - |
        SecRule ARGS "@contains ;" \
            "id:1003,\
            phase:2,\
            block,\
            msg:'Command injection detected',\
            logdata:'Matched Data: %{MATCHED_VAR}'"
```

### 4. Container Security

#### Pod Security Context

```yaml
waf:
  podSecurityContext:
    fsGroup: 101
    runAsNonRoot: true
    runAsUser: 101
    supplementalGroups: [101]
    seccompProfile:
      type: RuntimeDefault
    sysctls:
      - name: net.ipv4.ip_forward
        value: "0"
      - name: net.ipv4.conf.all.accept_redirects
        value: "0"
      - name: net.ipv4.conf.all.send_redirects
        value: "0"
```

#### Container Security Context

```yaml
waf:
  securityContext:
    allowPrivilegeEscalation: false
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile:
      type: RuntimeDefault
    allowPrivilegeEscalation: false
    privileged: false
```

### 5. Kubernetes Security

#### RBAC Configuration

```yaml
waf:
  rbac:
    create: true
    rules:
      - apiGroups: [""]
        resources: ["pods", "services", "endpoints"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["networking.k8s.io"]
        resources: ["networkpolicies"]
        verbs: ["get", "list", "watch"]
```

#### Service Account

```yaml
waf:
  serviceAccount:
    create: true
    name: "waf-service-account"
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::ACCOUNT:role/waf-role"
    automountServiceAccountToken: false
```

## Security Monitoring

### 1. Audit Logging

```yaml
waf:
  modsecurity:
    auditLog:
      enabled: true
      format: "JSON"
      parts: "ABIJDEFHZ"
      storageDir: "/var/log/modsecurity/audit/"
```

### 2. Security Alerts

```yaml
monitoring:
  prometheusRule:
    enabled: true
    groups:
      - name: waf.security.rules
        rules:
          - alert: WAFAttackDetected
            expr: rate(waf_requests_blocked[5m]) > 0.5
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "WAF attack detected"
              description: "High rate of blocked requests detected"
          
          - alert: WAFModSecurityErrors
            expr: rate(waf_modsecurity_errors[5m]) > 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "ModSecurity errors"
              description: "ModSecurity is encountering errors"
          
          - alert: WAFHighRequestVolume
            expr: rate(waf_requests_total[5m]) > 2000
            for: 2m
            labels:
              severity: warning
            annotations:
              summary: "High request volume"
              description: "Unusually high request volume detected"
```

### 3. Fail2Ban Integration

```yaml
waf:
  security:
    fail2ban:
      enabled: true
      maxRetry: 3
      bantime: 3600
      findtime: 600
      jails:
        nginx-http-auth:
          enabled: true
          maxRetry: 5
          bantime: 3600
        nginx-botsearch:
          enabled: true
          maxRetry: 2
          bantime: 7200
        nginx-req-limit:
          enabled: true
          maxRetry: 3
          bantime: 1800
```

## Security Best Practices

### 1. Regular Updates

- **OWASP CRS**: Update to latest version monthly
- **NGINX**: Keep updated to latest stable version
- **ModSecurity**: Update to latest version
- **Kubernetes**: Keep cluster updated

### 2. Configuration Management

- **Version Control**: Store all configurations in Git
- **Secrets Management**: Use Kubernetes secrets or external secret managers
- **Configuration Validation**: Validate configurations before deployment
- **Backup**: Regular backup of configurations

### 3. Monitoring and Alerting

- **Real-time Monitoring**: Monitor WAF performance and security events
- **Alerting**: Set up alerts for security incidents
- **Log Analysis**: Regular analysis of security logs
- **Incident Response**: Have procedures for security incidents

### 4. Testing

- **Penetration Testing**: Regular security assessments
- **Load Testing**: Test WAF performance under load
- **Configuration Testing**: Test rule changes in staging
- **Vulnerability Scanning**: Regular vulnerability assessments

### 5. Compliance

- **PCI DSS**: If handling payment data
- **SOC 2**: For service organizations
- **ISO 27001**: Information security management
- **GDPR**: Data protection compliance

## Security Checklist

- [ ] Network policies configured
- [ ] TLS 1.3 enabled with secure ciphers
- [ ] Security headers configured
- [ ] Rate limiting enabled
- [ ] OWASP CRS enabled with appropriate paranoia level
- [ ] Custom security rules configured
- [ ] Container security contexts set
- [ ] RBAC configured
- [ ] Audit logging enabled
- [ ] Security alerts configured
- [ ] Fail2Ban enabled
- [ ] Regular updates scheduled
- [ ] Monitoring and alerting set up
- [ ] Incident response procedures documented
- [ ] Security testing scheduled
- [ ] Compliance requirements identified

## Incident Response

### 1. Detection

- Monitor WAF logs for suspicious activity
- Set up alerts for unusual patterns
- Use SIEM for correlation analysis

### 2. Analysis

- Investigate blocked requests
- Analyze attack patterns
- Identify affected systems

### 3. Response

- Block malicious IPs
- Update security rules
- Notify stakeholders
- Document incident

### 4. Recovery

- Restore normal operations
- Update security measures
- Conduct post-incident review
- Update procedures

## Security Resources

- [OWASP CRS Documentation](https://coreruleset.org/)
- [ModSecurity Reference Manual](https://github.com/SpiderLabs/ModSecurity/wiki)
- [NGINX Security Best Practices](https://nginx.org/en/docs/http/ngx_http_core_module.html)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes/) 