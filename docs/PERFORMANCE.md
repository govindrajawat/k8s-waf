# Performance Optimization Guide

This guide provides comprehensive performance tuning recommendations for the Kubernetes WAF.

## Performance Architecture

### WAF Performance Components

1. **NGINX Worker Processes**: Handle concurrent connections
2. **ModSecurity Engine**: Process security rules
3. **Rate Limiting**: Control request flow
4. **TLS Processing**: Cryptographic operations
5. **Logging**: I/O operations
6. **Network**: Connection handling

## Performance Tuning

### 1. NGINX Optimization

#### Worker Configuration

```yaml
waf:
  nginx:
    # Optimize for CPU cores
    workerProcesses: "auto"  # Automatically set to CPU cores
    
    # Connection handling
    workerConnections: 2048
    workerRlimitNofile: 131072
    
    # Performance settings
    keepaliveTimeout: 120
    keepaliveRequests: 1000
    
    # Buffer optimization
    clientMaxBodySize: "50m"
    clientBodyBufferSize: "128k"
    clientHeaderBufferSize: "1k"
    largeClientHeaderBuffers: "4 8k"
    
    # Output buffering
    outputBuffers: "2 32k"
    postponeOutput: 1460
```

#### Event-Driven Architecture

```yaml
waf:
  nginx:
    events:
      use: "epoll"  # Linux epoll for high concurrency
      multiAccept: true
      acceptMutex: false  # Disable for high load
      workerConnections: 2048
```

#### Gzip Compression

```yaml
waf:
  nginx:
    gzip:
      enabled: true
      level: 6  # Balance between CPU and compression
      minLength: 1024
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
        - application/x-font-ttf
        - font/opentype
        - application/vnd.ms-fontobject
        - image/x-icon
```

### 2. ModSecurity Optimization

#### Rule Engine Tuning

```yaml
waf:
  security:
    modsecurity:
      # Performance mode
      performanceMode: true
      
      # Rule engine optimization
      ruleEngine: "On"
      requestBodyLimit: "10m"
      requestBodyNoFilesLimit: "1m"
      requestBodyInMemoryLimit: "1m"
      
      # Processing optimization
      pcreMatchLimit: 1000
      pcreMatchLimitRecursion: 1000
      
      # Audit logging optimization
      auditLog:
        enabled: true
        format: "JSON"
        parts: "ABIJDEFHZ"  # Minimal parts for performance
        storageDir: "/var/log/modsecurity/audit/"
        concurrentRequests: 10
```

#### OWASP CRS Optimization

```yaml
waf:
  security:
    crsConfig:
      # Performance-focused settings
      paranoiaLevel: 1  # Start with lower level
      anomalyThreshold: 10
      blockScore: 5
      
      # Disable resource-intensive rules
      excludeRules:
        - "941100"  # XSS rules if causing performance issues
        - "942100"  # SQL injection rules if causing performance issues
        - "949110"  # Blocking evaluation rules
      
      # Optimize rule processing
      ruleProcessing:
        batchSize: 100
        maxRulesPerRequest: 1000
```

### 3. Rate Limiting Optimization

#### Efficient Rate Limiting

```yaml
waf:
  rateLimit:
    # Memory-efficient zones
    zones:
      general:
        size: "10m"
        rate: "100r/s"
        burst: 200
      api:
        size: "5m"
        rate: "50r/s"
        burst: 100
      login:
        size: "2m"
        rate: "10r/s"
        burst: 20
    
    # Shared memory optimization
    sharedMemory:
      enabled: true
      size: "50m"
```

### 4. TLS Optimization

#### TLS Performance

```yaml
waf:
  security:
    tls:
      # Session caching
      sessionCache: "shared:SSL:50m"
      sessionTimeout: "10m"
      sessionTickets: false  # Disable for security
      
      # OCSP stapling
      ocspStapling: true
      ocspCache: "shared:OCSP:10m"
      
      # Cipher optimization
      cipherSuites:
        - "TLS_AES_256_GCM_SHA384"
        - "TLS_CHACHA20_POLY1305_SHA256"
        - "TLS_AES_128_GCM_SHA256"
      
      # HTTP/2 optimization
      http2:
        enabled: true
        maxConcurrentStreams: 128
        maxFieldSize: "4k"
        maxHeaderSize: "16k"
```

### 5. Logging Optimization

#### Efficient Logging

```yaml
waf:
  logging:
    # Buffer optimization
    accessLog:
      enabled: true
      format: "combined"
      buffer: "512k"
      flush: "1m"
    
    # Error log optimization
    errorLog:
      enabled: true
      level: "warn"  # Reduce log level for performance
    
    # ModSecurity audit log
    modsecurity:
      auditLog:
        enabled: true
        format: "JSON"
        parts: "ABIJDEFHZ"
        concurrentRequests: 10
        storageDir: "/var/log/modsecurity/audit/"
```

## Resource Allocation

### CPU Optimization

```yaml
waf:
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m"
      memory: "2Gi"
  
  # CPU affinity for better performance
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
              - key: node-role.kubernetes.io/worker
                operator: In
                values:
                  - "true"
```

### Memory Optimization

```yaml
waf:
  # Memory optimization
  nginx:
    # Shared memory zones
    sharedMemory:
      rateLimit: "50m"
      sessionCache: "10m"
      upstream: "10m"
    
    # Buffer optimization
    buffers:
      clientBodyBufferSize: "128k"
      clientHeaderBufferSize: "1k"
      largeClientHeaderBuffers: "4 8k"
      outputBuffers: "2 32k"
```

### Network Optimization

```yaml
waf:
  # Network optimization
  nginx:
    # TCP optimization
    tcp:
      nodelay: true
      nopush: true
      keepalive: 32
    
    # Connection optimization
    connections:
      keepaliveTimeout: 120
      keepaliveRequests: 1000
      clientMaxBodySize: "50m"
```

## Horizontal Pod Autoscaling

### HPA Configuration

```yaml
waf:
  hpa:
    enabled: true
    minReplicas: 3
    maxReplicas: 20
    
    # CPU-based scaling
    targetCPUUtilizationPercentage: 70
    
    # Memory-based scaling
    targetMemoryUtilizationPercentage: 80
    
    # Custom metrics
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 70
      - type: Resource
        resource:
          name: memory
          target:
            type: Utilization
            averageUtilization: 80
      - type: Object
        object:
          metric:
            name: requests-per-second
          describedObject:
            apiVersion: networking.k8s.io/v1
            kind: Ingress
            name: waf-ingress
          target:
            type: Value
            value: 1000
```

## Performance Monitoring

### Metrics Collection

```yaml
waf:
  monitoring:
    enabled: true
    
    # NGINX metrics
    nginx:
      enabled: true
      metrics:
        - "connections"
        - "requests"
        - "response_time"
        - "upstream_response_time"
    
    # ModSecurity metrics
    modsecurity:
      enabled: true
      metrics:
        - "rules_processed"
        - "rules_matched"
        - "requests_blocked"
        - "processing_time"
    
    # Custom metrics
    custom:
      enabled: true
      metrics:
        - name: "waf_requests_total"
          help: "Total number of requests"
          type: "counter"
        - name: "waf_requests_blocked"
          help: "Number of blocked requests"
          type: "counter"
        - name: "waf_response_time_seconds"
          help: "Response time in seconds"
          type: "histogram"
```

### Performance Alerts

```yaml
waf:
  monitoring:
    alerts:
      enabled: true
      rules:
        - alert: WAFHighResponseTime
          expr: histogram_quantile(0.95, rate(waf_response_time_seconds_bucket[5m])) > 0.5
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "High WAF response time"
            description: "95th percentile response time is {{ $value }}s"
        
        - alert: WAFHighCPUUsage
          expr: rate(container_cpu_usage_seconds_total{container="waf"}[5m]) > 0.8
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "High WAF CPU usage"
            description: "CPU usage is {{ $value }}"
        
        - alert: WAFHighMemoryUsage
          expr: container_memory_usage_bytes{container="waf"} / container_spec_memory_limit_bytes{container="waf"} > 0.8
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "High WAF memory usage"
            description: "Memory usage is {{ $value }}"
```

## Performance Benchmarks

### Benchmark Configuration

```yaml
# Benchmark test configuration
benchmark:
  enabled: true
  tools:
    - name: "wrk"
      version: "4.2.0"
    - name: "ab"
      version: "2.3"
    - name: "hey"
      version: "0.1.4"
  
  tests:
    - name: "baseline"
      description: "Baseline performance test"
      duration: "60s"
      connections: 100
      threads: 10
      requests: 10000
    
    - name: "high_load"
      description: "High load test"
      duration: "300s"
      connections: 1000
      threads: 50
      requests: 100000
    
    - name: "stress_test"
      description: "Stress test"
      duration: "600s"
      connections: 5000
      threads: 100
      requests: 500000
```

### Expected Performance Metrics

| Metric | Target | Good | Excellent |
|--------|--------|------|-----------|
| **Requests/sec** | 1000 | 5000 | 10000+ |
| **Response Time (95th %)** | 500ms | 200ms | 100ms |
| **Concurrent Connections** | 1000 | 5000 | 10000+ |
| **CPU Usage** | 80% | 60% | 40% |
| **Memory Usage** | 80% | 60% | 40% |
| **Error Rate** | 1% | 0.1% | 0.01% |

## Performance Testing

### Load Testing Script

```bash
#!/bin/bash
# Performance testing script

# Test parameters
DURATION=60
CONNECTIONS=100
THREADS=10
URL="https://waf.example.com/"

echo "Starting WAF performance test..."

# Baseline test
echo "Running baseline test..."
wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s $URL > baseline_results.txt

# High load test
echo "Running high load test..."
wrk -t50 -c1000 -d${DURATION}s $URL > highload_results.txt

# Stress test
echo "Running stress test..."
wrk -t100 -c5000 -d${DURATION}s $URL > stress_results.txt

# Parse results
echo "Parsing results..."
grep "Requests/sec" *_results.txt
grep "Latency" *_results.txt
grep "Transfer/sec" *_results.txt
```

### Performance Monitoring Dashboard

```yaml
# Grafana dashboard configuration
dashboard:
  enabled: true
  title: "WAF Performance Dashboard"
  panels:
    - title: "Request Rate"
      type: "graph"
      targets:
        - expr: "rate(waf_requests_total[5m])"
          legendFormat: "requests/sec"
    
    - title: "Response Time"
      type: "graph"
      targets:
        - expr: "histogram_quantile(0.95, rate(waf_response_time_seconds_bucket[5m]))"
          legendFormat: "95th percentile"
    
    - title: "CPU Usage"
      type: "graph"
      targets:
        - expr: "rate(container_cpu_usage_seconds_total{container='waf'}[5m])"
          legendFormat: "CPU usage"
    
    - title: "Memory Usage"
      type: "graph"
      targets:
        - expr: "container_memory_usage_bytes{container='waf'}"
          legendFormat: "Memory usage"
    
    - title: "Blocked Requests"
      type: "graph"
      targets:
        - expr: "rate(waf_requests_blocked[5m])"
          legendFormat: "blocked/sec"
```

## Performance Optimization Checklist

### Configuration Optimization
- [ ] Worker processes optimized for CPU cores
- [ ] Connection limits configured appropriately
- [ ] Buffer sizes optimized
- [ ] Gzip compression enabled
- [ ] TLS session caching configured
- [ ] Rate limiting zones optimized
- [ ] ModSecurity rules optimized

### Resource Optimization
- [ ] CPU requests and limits set
- [ ] Memory requests and limits set
- [ ] HPA configured for auto-scaling
- [ ] Resource quotas defined
- [ ] Node affinity configured

### Monitoring Optimization
- [ ] Performance metrics collected
- [ ] Alerts configured for performance issues
- [ ] Dashboards created for monitoring
- [ ] Logging optimized for performance
- [ ] Audit logging configured efficiently

### Network Optimization
- [ ] Network policies optimized
- [ ] TLS configuration optimized
- [ ] Connection pooling configured
- [ ] Load balancing optimized
- [ ] CDN integration considered

## Performance Troubleshooting

### Common Performance Issues

1. **High CPU Usage**
   - Reduce ModSecurity paranoia level
   - Optimize NGINX worker processes
   - Enable gzip compression

2. **High Memory Usage**
   - Optimize buffer sizes
   - Reduce connection limits
   - Enable memory-based HPA

3. **High Response Time**
   - Optimize upstream connections
   - Enable keepalive connections
   - Reduce ModSecurity rule processing

4. **Low Throughput**
   - Increase worker processes
   - Optimize rate limiting
   - Enable HTTP/2

### Performance Debugging

```bash
# Check NGINX performance
kubectl exec -n waf <pod-name> -- nginx -T | grep worker

# Check ModSecurity performance
kubectl exec -n waf <pod-name> -- cat /var/log/modsecurity/audit.log | tail -100

# Check resource usage
kubectl top pods -n waf

# Check network performance
kubectl exec -n waf <pod-name> -- ss -tuln
```

## Best Practices

1. **Start with Conservative Settings**: Begin with lower limits and increase gradually
2. **Monitor Continuously**: Use comprehensive monitoring and alerting
3. **Test Regularly**: Perform load testing before production changes
4. **Optimize Incrementally**: Make small changes and measure impact
5. **Document Performance**: Keep performance baselines and improvement records
6. **Plan for Scale**: Design for expected growth and peak loads
7. **Use Caching**: Implement appropriate caching strategies
8. **Optimize Logging**: Balance logging detail with performance impact 