# Contributing Guide

Thank you for your interest in contributing to the Kubernetes WAF project! This guide will help you get started with contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Contributing Guidelines](#contributing-guidelines)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Documentation](#documentation)
- [Security](#security)
- [Release Process](#release-process)
- [Community](#community)

## Code of Conduct

### Our Standards

We are committed to providing a welcoming and inspiring community for all. We expect all contributors to:

- **Be respectful**: Treat everyone with respect and dignity
- **Be inclusive**: Welcome people from all backgrounds and experience levels
- **Be collaborative**: Work together to achieve common goals
- **Be constructive**: Provide constructive feedback and suggestions
- **Be professional**: Maintain professional behavior in all interactions

### Unacceptable Behavior

The following behaviors are considered unacceptable:

- Harassment, discrimination, or bullying
- Offensive or inappropriate comments
- Personal attacks or insults
- Spam or unsolicited commercial content
- Violation of privacy or confidentiality

### Reporting Issues

If you experience or witness unacceptable behavior, please report it to the project maintainers at [security@example.com](mailto:security@example.com).

## Getting Started

### Prerequisites

Before contributing, ensure you have the following installed:

- **Docker**: Version 20.10 or later
- **Kubernetes**: kubectl and access to a cluster
- **Helm**: Version 3.8 or later
- **Go**: Version 1.19 or later (for custom components)
- **Python**: Version 3.8 or later (for scripts)
- **Git**: Latest version

### Fork and Clone

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/k8s-waf.git
   cd k8s-waf
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/original-owner/k8s-waf.git
   ```

### Development Setup

1. **Install dependencies**:
   ```bash
   # Install Helm dependencies
   helm dependency update charts/waf/
   
   # Install development tools
   make install-dev-tools
   ```

2. **Set up local development environment**:
   ```bash
   # Create development namespace
   kubectl create namespace waf-dev
   
   # Install development dependencies
   make setup-dev
   ```

## Development Environment

### Local Development

#### Using Docker Compose

```yaml
# docker-compose.dev.yml
version: '3.8'
services:
  waf-dev:
    build:
      context: .
      dockerfile: Dockerfile
      target: development
    ports:
      - "8080:80"
      - "8443:443"
    volumes:
      - ./config:/etc/nginx/conf.d
      - ./logs:/var/log/nginx
    environment:
      - NGINX_ENV=development
      - MODSECURITY_DEBUG=1
```

#### Using Minikube

```bash
# Start Minikube
minikube start --cpus 4 --memory 8192

# Enable addons
minikube addons enable ingress
minikube addons enable metrics-server

# Deploy WAF for development
helm install waf-dev charts/waf/ -n waf-dev -f values-dev.yaml
```

### Development Tools

#### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
  
  - repo: https://github.com/helm/chart-testing
    rev: v3.8.0
    hooks:
      - id: helm-docs
      - id: yamllint
      - id: helm-lint
  
  - repo: https://github.com/terraform-docs/terraform-docs
    rev: v0.16.0
    hooks:
      - id: terraform-docs-go
```

#### Development Scripts

```bash
#!/bin/bash
# scripts/dev-setup.sh

# Development environment setup
echo "Setting up development environment..."

# Install development tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest

# Install Helm plugins
helm plugin install https://github.com/helm/helm-secrets
helm plugin install https://github.com/helm/helm-diff

# Setup pre-commit hooks
pre-commit install

echo "Development environment setup complete!"
```

## Project Structure

### Directory Layout

```
k8s-waf/
├── charts/                    # Helm charts
│   └── waf/
│       ├── Chart.yaml         # Chart metadata
│       ├── values.yaml        # Default values
│       └── templates/         # Kubernetes manifests
├── config/                    # Configuration files
│   ├── nginx/                 # NGINX configuration
│   └── modsecurity/           # ModSecurity configuration
├── docs/                      # Documentation
│   ├── README.md
│   ├── QUICKSTART.md
│   ├── SECURITY.md
│   └── ...
├── scripts/                   # Utility scripts
│   ├── deploy.sh
│   ├── healthcheck.sh
│   └── ...
├── tests/                     # Test files
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── Dockerfile                 # Container image
├── .github/                   # GitHub configuration
├── Makefile                   # Build automation
└── README.md                  # Project overview
```

### Key Files

- **`Dockerfile`**: Multi-stage container build
- **`charts/waf/`**: Helm chart for Kubernetes deployment
- **`config/`**: NGINX and ModSecurity configurations
- **`scripts/`**: Deployment and utility scripts
- **`docs/`**: Comprehensive documentation
- **`tests/`**: Test suites and validation

## Contributing Guidelines

### Issue Reporting

#### Bug Reports

When reporting bugs, please include:

- **Clear description** of the problem
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Environment details** (OS, Kubernetes version, etc.)
- **Logs and error messages**
- **Screenshots** if applicable

#### Feature Requests

When requesting features, please include:

- **Clear description** of the feature
- **Use case** and benefits
- **Implementation suggestions** if possible
- **Priority** and urgency
- **Related issues** or discussions

### Pull Request Guidelines

#### Before Submitting

1. **Check existing issues** and pull requests
2. **Create an issue** for significant changes
3. **Update documentation** for new features
4. **Add tests** for new functionality
5. **Ensure all tests pass**
6. **Follow coding standards**

#### Pull Request Template

```markdown
## Description

Brief description of the changes made.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Documentation updated

## Checklist

- [ ] Code follows the style guidelines
- [ ] Self-review completed
- [ ] Code is commented, particularly in hard-to-understand areas
- [ ] Corresponding changes to documentation made
- [ ] No new warnings generated
- [ ] Tests added that prove fix is effective or feature works
- [ ] All dependent changes have been merged and published

## Related Issues

Closes #(issue number)
```

### Code Standards

#### General Guidelines

- **Follow existing patterns** and conventions
- **Write clear, readable code** with meaningful names
- **Add comments** for complex logic
- **Keep functions small** and focused
- **Use consistent formatting**

#### YAML Guidelines

```yaml
# Good YAML formatting
apiVersion: v1
kind: ConfigMap
metadata:
  name: waf-config
  labels:
    app: waf
    version: v1.0.0
data:
  nginx.conf: |
    server {
        listen 80;
        server_name example.com;
        
        location / {
            proxy_pass http://backend;
        }
    }
```

#### Shell Script Guidelines

```bash
#!/bin/bash
# Good shell script formatting

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/waf.log"

# Functions
log_info() {
    echo "[INFO] $(date): $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date): $*" | tee -a "$LOG_FILE" >&2
}

# Main function
main() {
    log_info "Starting WAF deployment"
    
    # Validate environment
    if [[ -z "${KUBECONFIG:-}" ]]; then
        log_error "KUBECONFIG environment variable not set"
        exit 1
    fi
    
    # Deploy WAF
    helm upgrade --install waf charts/waf/ \
        --namespace waf \
        --create-namespace \
        --values values.yaml
    
    log_info "WAF deployment completed"
}

# Run main function
main "$@"
```

## Development Workflow

### Branch Strategy

We use a simplified Git flow:

- **`main`**: Production-ready code
- **`develop`**: Integration branch for features
- **`feature/*`**: Feature development branches
- **`bugfix/*`**: Bug fix branches
- **`hotfix/*`**: Critical production fixes

### Workflow Steps

1. **Create feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes** and commit:
   ```bash
   git add .
   git commit -m "feat: add new security feature"
   ```

3. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create pull request** on GitHub

5. **Address review feedback** and update PR

6. **Merge after approval**

### Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Types

- **`feat`**: New feature
- **`fix`**: Bug fix
- **`docs`**: Documentation changes
- **`style`**: Code style changes
- **`refactor`**: Code refactoring
- **`test`**: Test changes
- **`chore`**: Maintenance tasks

#### Examples

```bash
feat(security): add advanced rate limiting

fix(nginx): resolve configuration parsing issue

docs(readme): update installation instructions

test(integration): add comprehensive test suite
```

## Testing

### Test Types

#### Unit Tests

```bash
# Run unit tests
make test-unit

# Run with coverage
make test-unit-coverage
```

#### Integration Tests

```bash
# Run integration tests
make test-integration

# Run against specific environment
make test-integration ENV=staging
```

#### End-to-End Tests

```bash
# Run E2E tests
make test-e2e

# Run with specific test suite
make test-e2e SUITE=security
```

### Test Structure

```
tests/
├── unit/                      # Unit tests
│   ├── nginx/
│   ├── modsecurity/
│   └── kubernetes/
├── integration/               # Integration tests
│   ├── api/
│   ├── security/
│   └── performance/
├── e2e/                       # End-to-end tests
│   ├── deployment/
│   ├── security/
│   └── monitoring/
└── fixtures/                  # Test data
    ├── configs/
    ├── logs/
    └── manifests/
```

### Test Guidelines

- **Write tests first** (TDD approach)
- **Test edge cases** and error conditions
- **Use descriptive test names**
- **Keep tests independent**
- **Mock external dependencies**
- **Maintain test data**

## Documentation

### Documentation Standards

#### Writing Guidelines

- **Clear and concise** language
- **Step-by-step instructions** for procedures
- **Examples** for complex concepts
- **Screenshots** for UI elements
- **Code examples** for technical content

#### Documentation Structure

```
docs/
├── README.md                  # Project overview
├── QUICKSTART.md             # Quick start guide
├── INSTALLATION.md           # Installation instructions
├── CONFIGURATION.md          # Configuration guide
├── SECURITY.md               # Security documentation
├── TROUBLESHOOTING.md        # Troubleshooting guide
├── API.md                    # API documentation
├── DEPLOYMENT.md             # Deployment guide
└── CONTRIBUTING.md           # This file
```

### Documentation Workflow

1. **Update documentation** with code changes
2. **Review for accuracy** and completeness
3. **Test documentation** examples
4. **Update table of contents**
5. **Check links** and references

## Security

### Security Guidelines

#### Code Security

- **Validate all inputs** and sanitize data
- **Use parameterized queries** to prevent injection
- **Implement proper authentication** and authorization
- **Follow security best practices**
- **Regular security audits**

#### Security Review Process

1. **Security review** for all changes
2. **Vulnerability scanning** in CI/CD
3. **Dependency updates** for security patches
4. **Security testing** for new features
5. **Incident response** procedures

### Security Reporting

#### Responsible Disclosure

- **Report security issues** privately to [security@example.com](mailto:security@example.com)
- **Provide detailed information** about the vulnerability
- **Allow reasonable time** for fixes
- **Coordinate disclosure** with maintainers

#### Security Issue Template

```markdown
## Security Issue Report

### Vulnerability Type
[Type of vulnerability]

### Description
[Detailed description of the vulnerability]

### Steps to Reproduce
[Step-by-step reproduction steps]

### Impact
[Potential impact of the vulnerability]

### Suggested Fix
[Optional: suggested fix or mitigation]

### Environment
[Affected versions and environments]
```

## Release Process

### Release Types

#### Patch Release (1.0.1)
- Bug fixes and security patches
- No new features
- Backward compatible

#### Minor Release (1.1.0)
- New features
- Backward compatible
- Deprecation notices

#### Major Release (2.0.0)
- Breaking changes
- Major new features
- Migration guide required

### Release Checklist

- [ ] **Feature freeze** implemented
- [ ] **All tests pass**
- [ ] **Documentation updated**
- [ ] **Security review completed**
- [ ] **Performance testing done**
- [ ] **Release notes prepared**
- [ ] **Version tags created**
- [ ] **Docker images built**
- [ ] **Helm charts published**
- [ ] **Announcement prepared**

### Release Automation

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Build and test
        run: |
          make build
          make test-all
      
      - name: Create release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          body: ${{ steps.changelog.outputs.clean_changelog }}
          draft: false
          prerelease: false
```

## Community

### Getting Help

#### Support Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and discussions
- **Documentation**: Comprehensive guides and examples
- **Community Forum**: Community support and discussions

#### Communication Guidelines

- **Be respectful** and professional
- **Search existing issues** before creating new ones
- **Provide context** and details
- **Follow up** on responses
- **Help others** when possible

### Recognition

#### Contributor Recognition

- **Contributor list** in README
- **Contributor badges** for significant contributions
- **Release notes** acknowledgment
- **Community spotlight** for outstanding contributions

#### Contribution Levels

- **Contributor**: Any contribution
- **Maintainer**: Regular contributions and reviews
- **Core Maintainer**: Project leadership and direction

### Events and Meetups

- **Community calls** (monthly)
- **Hackathons** and contribution events
- **Conference presentations**
- **Workshop sessions**

## Getting Started Checklist

### For New Contributors

- [ ] **Read the documentation** thoroughly
- [ ] **Set up development environment**
- [ ] **Run the test suite** successfully
- [ ] **Make a small contribution** (documentation, tests)
- [ ] **Join community discussions**
- [ ] **Review existing pull requests**
- [ ] **Submit your first pull request**

### For Experienced Contributors

- [ ] **Review project roadmap**
- [ ] **Identify areas for improvement**
- [ ] **Propose new features**
- [ ] **Mentor new contributors**
- [ ] **Participate in release process**
- [ ] **Contribute to architecture decisions**

## Resources

### Learning Resources

- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Helm Documentation**: https://helm.sh/docs/
- **NGINX Documentation**: https://nginx.org/en/docs/
- **ModSecurity Documentation**: https://github.com/SpiderLabs/ModSecurity/wiki
- **OWASP CRS Documentation**: https://coreruleset.org/

### Tools and Utilities

- **kubectl**: Kubernetes command-line tool
- **helm**: Kubernetes package manager
- **docker**: Container platform
- **minikube**: Local Kubernetes cluster
- **kind**: Kubernetes in Docker

### Community Resources

- **GitHub Repository**: https://github.com/your-org/k8s-waf
- **Issue Tracker**: https://github.com/your-org/k8s-waf/issues
- **Discussions**: https://github.com/your-org/k8s-waf/discussions
- **Documentation**: https://github.com/your-org/k8s-waf/docs

Thank you for contributing to the Kubernetes WAF project! Your contributions help make the project better for everyone. 