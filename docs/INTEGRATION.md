# Integration Guide

This guide covers integrating the Kubernetes WAF with various monitoring, logging, and security tools.

## Monitoring Integrations

### 1. Prometheus Integration

#### Basic Prometheus Setup

```yaml
# Prometheus ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: waf-monitor
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: waf
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
      scrapeTimeout: 10s
```

#### Custom Metrics

```yaml
# Custom metrics configuration
waf:
  monitoring:
    prometheus:
      enabled: true
      metrics:
        # NGINX metrics
        nginx:
          - "nginx_http_requests_total"
          - "nginx_http_request_duration_seconds"
          - "nginx_http_connections"
        
        # ModSecurity metrics
        modsecurity:
          - "modsec_rules_processed_total"
          - "modsec_rules_matched_total"
          - "modsec_requests_blocked_total"
        
        # Custom WAF metrics
        custom:
          - name: "waf_requests_total"
            help: "Total number of requests processed"
            type: "counter"
          - name: "waf_requests_blocked"
            help: "Number of requests blocked"
            type: "counter"
          - name: "waf_response_time_seconds"
            help: "Response time in seconds"
            type: "histogram"
```

### 2. Grafana Integration

#### Grafana Dashboard

```yaml
# Grafana dashboard configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: waf-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  waf-dashboard.json: |
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
          },
          {
            "title": "Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(waf_response_time_seconds_bucket[5m]))",
                "legendFormat": "95th percentile"
              }
            ]
          },
          {
            "title": "Top Blocked IPs",
            "type": "table",
            "targets": [
              {
                "expr": "topk(10, sum by (client_ip) (rate(waf_requests_blocked[1h])))",
                "format": "table"
              }
            ]
          }
        ]
      }
    }
```

### 3. AlertManager Integration

#### Alert Rules

```yaml
# PrometheusRule for WAF alerts
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: waf-alerts
  namespace: monitoring
spec:
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
```

## Logging Integrations

### 1. ELK Stack Integration

#### Elasticsearch Configuration

```yaml
# Elasticsearch output configuration
waf:
  logging:
    elasticsearch:
      enabled: true
      hosts:
        - "elasticsearch-master:9200"
      index: "waf-logs-%{+YYYY.MM.dd}"
      template:
        name: "waf-logs"
        pattern: "waf-logs-*"
      ssl:
        enabled: true
        caFile: "/etc/ssl/certs/ca.crt"
```

#### Logstash Configuration

```yaml
# Logstash pipeline for WAF logs
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][service] == "waf" {
    grok {
      match => { "message" => "%{IPORHOST:clientip} - %{DATA:user} \[%{HTTPDATE:timestamp}\] \"%{WORD:method} %{DATA:request} HTTP/%{NUMBER:httpversion}\" %{NUMBER:response} %{NUMBER:bytes} \"%{DATA:referrer}\" \"%{DATA:useragent}\" \"%{DATA:xforwardedfor}\" modsec_status=\"%{DATA:modsec_status}\" modsec_rule_id=\"%{DATA:modsec_rule_id}\" modsec_rule_msg=\"%{DATA:modsec_rule_msg}\"" }
    }
    
    date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
    
    geoip {
      source => "clientip"
    }
    
    if [modsec_status] == "blocked" {
      mutate {
        add_tag => [ "blocked" ]
      }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch-master:9200"]
    index => "waf-logs-%{+YYYY.MM.dd}"
  }
}
```

### 2. Fluentd Integration

#### Fluentd Configuration

```yaml
# Fluentd configuration for WAF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-waf-config
  namespace: logging
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/nginx/access.log
      pos_file /var/log/nginx/access.log.pos
      tag waf.access
      <parse>
        @type nginx
      </parse>
    </source>
    
    <source>
      @type tail
      path /var/log/nginx/error.log
      pos_file /var/log/nginx/error.log.pos
      tag waf.error
      <parse>
        @type nginx
      </parse>
    </source>
    
    <source>
      @type tail
      path /var/log/modsecurity/audit.log
      pos_file /var/log/modsecurity/audit.log.pos
      tag waf.modsecurity
      <parse>
        @type json
      </parse>
    </source>
    
    <filter waf.**>
      @type record_transformer
      <record>
        service waf
        environment ${ENVIRONMENT}
        cluster ${CLUSTER_NAME}
      </record>
    </filter>
    
    <match waf.**>
      @type elasticsearch
      host elasticsearch-master
      port 9200
      index_name waf-logs
      type_name waf
      logstash_format true
      logstash_prefix waf-logs
    </match>
```

### 3. Splunk Integration

#### Splunk Configuration

```yaml
# Splunk integration configuration
waf:
  logging:
    splunk:
      enabled: true
      host: "splunk-indexer:8089"
      token: "${SPLUNK_TOKEN}"
      index: "waf"
      sourcetype: "waf:nginx"
      ssl:
        enabled: true
        caFile: "/etc/ssl/certs/ca.crt"
```

## Security Integrations

### 1. Wazuh Integration

#### Wazuh Agent Configuration

```yaml
# Wazuh agent configuration
waf:
  security:
    wazuh:
      enabled: true
      endpoint: "wazuh-manager:1514"
      protocol: "udp"
      agentName: "waf-agent"
      agentGroup: "waf-agents"
      logLevel: "info"
      
      # Custom rules for WAF
      customRules:
        - rule_id: "100001"
          level: "10"
          description: "WAF blocked request"
          regex: ".*WAF.*blocked.*"
        
        - rule_id: "100002"
          level: "12"
          description: "ModSecurity rule triggered"
          regex: ".*ModSecurity.*rule.*"
        
        - rule_id: "100003"
          level: "14"
          description: "High rate of blocked requests"
          regex: ".*high.*block.*rate.*"
```

#### Wazuh Manager Configuration

```yaml
# Wazuh manager configuration for WAF
<ossec_config>
  <client_buffer>
    <disabled>no</disabled>
    <queue_size>50000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>
  
  <cluster>
    <name>waf-cluster</name>
    <node_name>waf-manager</node_name>
    <node_type>master</node_type>
    <key>waf-cluster-key</key>
    <port>1516</port>
    <bind_addr>0.0.0.0</bind_addr>
    <nodes>
      <node>waf-manager</node>
    </nodes>
    <hidden>no</hidden>
    <disabled>no</disabled>
  </cluster>
</ossec_config>
```

### 2. CrowdSec Integration

#### CrowdSec Configuration

```yaml
# CrowdSec integration
waf:
  security:
    crowdsec:
      enabled: true
      endpoint: "crowdsec:8080"
      apiKey: "${CROWDSEC_API_KEY}"
      
      # Bouncer configuration
      bouncer:
        enabled: true
        mode: "stream"
        updateFrequency: "10s"
        
      # Decision configuration
      decisions:
        enabled: true
        type: "ban"
        duration: "1h"
        scope: "ip"
```

#### CrowdSec Bouncer

```yaml
# CrowdSec bouncer configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crowdsec-bouncer
  namespace: security
spec:
  replicas: 2
  selector:
    matchLabels:
      app: crowdsec-bouncer
  template:
    metadata:
      labels:
        app: crowdsec-bouncer
    spec:
      containers:
        - name: bouncer
          image: crowdsecurity/cs-nginx-bouncer:latest
          ports:
            - containerPort: 8080
          env:
            - name: CROWDSEC_API_URL
              value: "http://crowdsec:8080"
            - name: CROWDSEC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: crowdsec-secret
                  key: api-key
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/conf.d
      volumes:
        - name: nginx-config
          configMap:
            name: crowdsec-nginx-config
```

### 3. Falco Integration

#### Falco Rules for WAF

```yaml
# Falco rules for WAF monitoring
- rule: WAF Container Started
  desc: Detect when WAF container starts
  condition: container.name contains "waf" and evt.type=execve and proc.name=nginx
  output: WAF container started (user=%user.name command=%proc.cmdline container=%container.name)
  priority: INFO

- rule: WAF Configuration Modified
  desc: Detect WAF configuration changes
  condition: container.name contains "waf" and (fd.name contains "nginx.conf" or fd.name contains "modsecurity.conf") and evt.type=write
  output: WAF configuration modified (user=%user.name file=%fd.name container=%container.name)
  priority: WARNING

- rule: WAF High Block Rate
  desc: Detect high rate of WAF blocks
  condition: container.name contains "waf" and proc.name=nginx and evt.type=write and fd.name contains "access.log" and proc.args contains "blocked"
  output: High WAF block rate detected (container=%container.name)
  priority: WARNING
```

## CI/CD Integrations

### 1. GitHub Actions Integration

#### Security Scanning Workflow

```yaml
# GitHub Actions workflow for WAF security scanning
name: WAF Security Scan

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'k8s-waf:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

### 2. ArgoCD Integration

#### ArgoCD Application

```yaml
# ArgoCD application for WAF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: waf
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/k8s-waf
    targetRevision: HEAD
    path: charts/waf
  destination:
    server: https://kubernetes.default.svc
    namespace: waf
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### 3. Tekton Integration

#### Tekton Pipeline

```yaml
# Tekton pipeline for WAF deployment
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: waf-pipeline
spec:
  params:
    - name: git-url
    - name: git-revision
    - name: image-tag
  tasks:
    - name: fetch-repository
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)
    
    - name: build-image
      taskRef:
        name: kaniko
      params:
        - name: IMAGE
          value: $(params.image-tag)
      runAfter:
        - fetch-repository
    
    - name: security-scan
      taskRef:
        name: trivy-scanner
      params:
        - name: image
          value: $(params.image-tag)
      runAfter:
        - build-image
    
    - name: deploy-waf
      taskRef:
        name: helm-deploy
      params:
        - name: chart-path
          value: charts/waf
        - name: release-name
          value: waf
      runAfter:
        - security-scan
```

## API Integrations

### 1. REST API Integration

#### WAF API Configuration

```yaml
# WAF REST API configuration
waf:
  api:
    enabled: true
    port: 8081
    endpoints:
      - path: /api/v1/status
        method: GET
        description: "Get WAF status"
      - path: /api/v1/metrics
        method: GET
        description: "Get WAF metrics"
      - path: /api/v1/config
        method: GET
        description: "Get WAF configuration"
      - path: /api/v1/config
        method: PUT
        description: "Update WAF configuration"
      - path: /api/v1/whitelist
        method: POST
        description: "Add IP to whitelist"
      - path: /api/v1/blacklist
        method: POST
        description: "Add IP to blacklist"
    
    authentication:
      enabled: true
      type: "bearer"
      secretName: "waf-api-secret"
    
    rateLimit:
      enabled: true
      requests: 100
      window: "1m"
```

### 2. Webhook Integration

#### Webhook Configuration

```yaml
# Webhook integration configuration
waf:
  webhooks:
    enabled: true
    endpoints:
      - name: "security-alerts"
        url: "https://webhook.example.com/security"
        events:
          - "request_blocked"
          - "attack_detected"
          - "high_block_rate"
        
      - name: "monitoring"
        url: "https://webhook.example.com/monitoring"
        events:
          - "health_check_failed"
          - "certificate_expiring"
          - "high_cpu_usage"
    
    authentication:
      enabled: true
      type: "hmac"
      secretName: "webhook-secret"
    
    retry:
      enabled: true
      maxAttempts: 3
      backoffDelay: "5s"
```

## Integration Checklist

### Monitoring Integration
- [ ] Prometheus ServiceMonitor configured
- [ ] Custom metrics defined
- [ ] Grafana dashboard created
- [ ] AlertManager rules configured
- [ ] Performance monitoring enabled

### Logging Integration
- [ ] Log aggregation configured
- [ ] Log parsing rules defined
- [ ] Log retention policies set
- [ ] Log search and analysis tools configured
- [ ] Log backup procedures established

### Security Integration
- [ ] SIEM integration configured
- [ ] Threat intelligence feeds connected
- [ ] Security event correlation enabled
- [ ] Incident response procedures documented
- [ ] Security monitoring dashboards created

### CI/CD Integration
- [ ] Security scanning in pipeline
- [ ] Automated deployment configured
- [ ] Rollback procedures tested
- [ ] Configuration management automated
- [ ] Testing procedures established

### API Integration
- [ ] REST API endpoints defined
- [ ] Authentication configured
- [ ] Rate limiting enabled
- [ ] Documentation created
- [ ] API testing procedures established

## Best Practices

1. **Start Small**: Begin with basic monitoring and gradually add integrations
2. **Security First**: Ensure all integrations use secure communication
3. **Documentation**: Maintain comprehensive documentation for all integrations
4. **Testing**: Test integrations thoroughly before production deployment
5. **Monitoring**: Monitor the integrations themselves for health and performance
6. **Backup**: Have backup procedures for critical integrations
7. **Compliance**: Ensure integrations meet compliance requirements
8. **Scalability**: Design integrations to scale with your infrastructure 