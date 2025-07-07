# Notification Service GitOps Setup

This directory contains the GitOps configuration for the Notification Service deployment using ArgoCD.

## Repository Structure

```
notification-service-gitops/
├── README.md                           # This file
├── argocd/
│   └── notification-service-app.yaml   # ArgoCD Application manifest
├── manifests/
│   ├── deployment.yaml                 # Kubernetes Deployment
│   ├── service.yaml                    # Kubernetes Service
│   ├── hpa.yaml                        # Horizontal Pod Autoscaler
│   ├── ingress.yaml                    # Ingress configuration
│   └── loadbalancer.yaml               # LoadBalancer service
├── overlays/
│   ├── dev/
│   │   └── kustomization.yaml          # Development environment
│   ├── staging/
│   │   └── kustomization.yaml          # Staging environment
│   └── production/
│       └── kustomization.yaml          # Production environment
└── scripts/
    ├── setup-github-repo.sh            # GitHub repository setup
    ├── deploy-argocd-app.sh             # Deploy ArgoCD application
    └── sync-and-test.sh                 # Sync and test deployment
```

## Quick Setup

1. **Create GitHub Repository**:
   ```bash
   ./scripts/setup-github-repo.sh
   ```

2. **Deploy ArgoCD Application**:
   ```bash
   ./scripts/deploy-argocd-app.sh
   ```

3. **Sync and Test**:
   ```bash
   ./scripts/sync-and-test.sh
   ```

## GitOps Workflow

1. **Code Changes** → Push to GitHub
2. **ArgoCD Detects** → Changes in repository
3. **Auto Sync** → Deploys to Kubernetes
4. **Health Check** → Monitors application health
5. **Rollback** → Automatic rollback on failure

## Environments

- **Development**: `overlays/dev/` - Single replica, minimal resources
- **Staging**: `overlays/staging/` - 2 replicas, standard resources  
- **Production**: `overlays/production/` - 3+ replicas, full resources

## Monitoring

ArgoCD provides:
- Real-time sync status
- Application health monitoring
- Deployment history
- Rollback capabilities
- Resource visualization
