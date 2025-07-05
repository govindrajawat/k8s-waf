# Advanced Configuration Guide

This guide covers advanced configuration options for the Kubernetes WAF.

## Custom ModSecurity Rules

### Adding Custom Rules

Create custom ModSecurity rules in your values.yaml:

```yaml
waf:
  security:
    customRules:
      - |
        SecRule ARGS "@contains malicious" \
            "id:1000,\
            phase:2,\
            block,\
            msg:'Custom malicious content detected',\
            logdata:'Matched Data: %{MATCHED_VAR} found within %{MATCHED_VAR_NAME}'"
      
      - |
        SecRule REQUEST_HEADERS:User-Agent "@pm badbot evilbot" \
            "id:1001,\
            phase:1,\
            block,\
            msg:'Bad bot detected',\
            logdata:'User-Agent: %{MATCHED_VAR}'"
```

### Advanced CRS Configuration

Customize OWASP CRS behavior:

```yaml
waf:
  security:
    crsVersion: "3.3.4"
    crsConfig:
      paranoiaLevel: 2
      anomalyThreshold: 10
      blockScore: 5
      excludeRules:
        - "941100"  # XSS rule
        - "942100"  # SQL injection rule
```

## Performance Tuning

### NGINX Optimization

```yaml
waf:
  nginx:
    workerProcesses: 4
    workerConnections: 2048
    workerRlimitNofile: 131072
    keepaliveTimeout: 120
    clientMaxBodySize: "50m"
    gzip:
      enabled: true
      level: 9
      types:
        - text/plain
        - text/css
        - text/xml
        - text/javascript
        - application/javascript
        - application/xml+rss
        - application/json
        - application/xml
        - image/svg+xml
```

### Resource Allocation

```yaml
waf:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  
  hpa:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

## Security Hardening

### Network Policies

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
```

### Pod Security

```yaml
waf:
  podSecurityContext:
    fsGroup: 101
    runAsNonRoot: true
    runAsUser: 101
    supplementalGroups: [101]
  
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
```

## Monitoring and Alerting

### Custom Prometheus Rules

```yaml
monitoring:
  prometheusRule:
    enabled: true
    groups:
      - name: waf.rules
        rules:
          - alert: WAFHighBlockRate
            expr: rate(waf_requests_blocked[5m]) > 0.1
            for: 2m
            labels:
              severity: warning
            annotations:
              summary: "High WAF block rate detected"
              description: "WAF is blocking {{ $value }} requests per second"
              
          - alert: WAFHighRequestVolume
            expr: rate(waf_requests_total[5m]) > 1000
            for: 2m
            labels:
              severity: warning
            annotations:
              summary: "High request volume detected"
              description: "WAF is processing {{ $value }} requests per second"
              
          - alert: WAFCertificateExpiring
            expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "WAF certificate expiring soon"
              description: "Certificate will expire in {{ $value }} seconds"
              
          - alert: WAFModSecurityErrors
            expr: rate(waf_modsecurity_errors[5m]) > 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: "ModSecurity errors detected"
              description: "ModSecurity is encountering errors"
```

### Grafana Dashboard

```yaml
monitoring:
  grafana:
    enabled: true
    dashboard:
      enabled: true
      name: "WAF Security Dashboard"
      namespace: "monitoring"
      json: |
        {
          "dashboard": {
            "title": "WAF Security Dashboard",
            "panels": [
              {
                "title": "Request Rate",
                "type": "graph",
                "targets": [
                  {
                    "expr": "rate(waf_requests_total[5m])",
                    "legendFormat": "requests/sec"
                  }
                ]
              },
              {
                "title": "Blocked Requests",
                "type": "graph",
                "targets": [
                  {
                    "expr": "rate(waf_requests_blocked[5m])",
                    "legendFormat": "blocked/sec"
                  }
                ]
              }
            ]
          }
        }
```

## Fail2Ban Advanced Configuration

### Custom Jail Rules

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
          findtime: 600
        nginx-botsearch:
          enabled: true
          maxRetry: 2
          bantime: 7200
          findtime: 300
        nginx-req-limit:
          enabled: true
          maxRetry: 3
          bantime: 1800
          findtime: 300
```

## Wazuh Integration

### Advanced Wazuh Configuration

```yaml
waf:
  security:
    wazuh:
      enabled: true
      endpoint: "wazuh-manager:1514"
      protocol: "udp"
      agentName: "waf-agent"
      agentGroup: "waf-agents"
      logLevel: "info"
      customRules:
        - rule_id: "100001"
          level: "10"
          description: "WAF blocked request"
          regex: ".*WAF.*blocked.*"
```

## TLS Configuration

### Advanced SSL/TLS Settings

```yaml
waf:
  tls:
    enabled: true
    minTlsVersion: "1.2"
    cipherSuites:
      - "ECDHE-ECDSA-AES128-GCM-SHA256"
      - "ECDHE-RSA-AES128-GCM-SHA256"
      - "ECDHE-ECDSA-AES256-GCM-SHA384"
      - "ECDHE-RSA-AES256-GCM-SHA384"
      - "ECDHE-ECDSA-CHACHA20-POLY1305"
      - "ECDHE-RSA-CHACHA20-POLY1305"
    ocspStapling: true
    hsts:
      enabled: true
      maxAge: 31536000
      includeSubDomains: true
      preload: true
```

## Custom NGINX Configuration

### Advanced NGINX Settings

```yaml
waf:
  nginx:
    customConfig: |
      # Custom upstream configuration
      upstream backend {
          least_conn;
          server backend1:8080 max_fails=3 fail_timeout=30s;
          server backend2:8080 max_fails=3 fail_timeout=30s;
          keepalive 32;
      }
      
      # Custom rate limiting
      limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
      limit_req_zone $binary_remote_addr zone=admin:10m rate=1r/s;
      
      # Custom security headers
      add_header X-Custom-Header "WAF-Protected" always;
      add_header X-WAF-Version "1.0.0" always;
```

## Troubleshooting

### Debug Mode

Enable debug logging:

```yaml
waf:
  modsecurity:
    debugLog:
      enabled: true
      level: 9
    auditLog:
      enabled: true
      format: "JSON"
      parts: "ABIJDEFHZ"
```

### Performance Monitoring

```yaml
waf:
  nginx:
    status:
      enabled: true
      allow: ["127.0.0.1", "10.0.0.0/8"]
  
  monitoring:
    enabled: true
    metrics:
      nginx: true
      modsecurity: true
      custom: true
```

## Best Practices

1. **Start with Paranoia Level 1** and increase gradually
2. **Monitor false positives** and adjust rules accordingly
3. **Use rate limiting** to prevent abuse
4. **Regularly update** OWASP CRS rules
5. **Backup configurations** before major changes
6. **Test in staging** before production deployment
7. **Monitor resource usage** and adjust limits
8. **Use network policies** for additional security
9. **Enable audit logging** for compliance
10. **Regular security assessments** of the WAF configuration 