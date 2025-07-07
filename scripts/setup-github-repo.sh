#!/bin/bash

# Setup GitHub Repository for Notification Service GitOps
# This script creates a GitHub repository and pushes the GitOps configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_NAME="notification-service-gitops"
REPO_DESCRIPTION="GitOps configuration for Notification Service on AKS"
GITHUB_USERNAME=""

echo -e "${BLUE}=== GitHub Repository Setup for Notification Service GitOps ===${NC}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo -e "${YELLOW}Install it with: curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg${NC}"
    echo -e "${YELLOW}echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null${NC}"
    echo -e "${YELLOW}sudo apt update && sudo apt install gh${NC}"
    exit 1
fi

# Check if user is logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Please login to GitHub first:${NC}"
    echo -e "${YELLOW}gh auth login${NC}"
    exit 1
fi

# Get GitHub username
GITHUB_USERNAME=$(gh api user --jq '.login')
echo -e "${YELLOW}GitHub Username: ${GITHUB_USERNAME}${NC}"

# Step 1: Initialize git repository
echo -e "\n${BLUE}Step 1: Initializing Git repository...${NC}"
cd "$(dirname "$0")/.."
git init
git add .
git commit -m "Initial commit: Notification Service GitOps configuration

- ArgoCD application manifest
- Kubernetes manifests for all environments
- Kustomization overlays for dev/staging/production
- Automated deployment scripts
- Complete GitOps workflow setup"

# Step 2: Create GitHub repository
echo -e "\n${BLUE}Step 2: Creating GitHub repository...${NC}"
gh repo create ${REPO_NAME} \
    --description "${REPO_DESCRIPTION}" \
    --public \
    --source=. \
    --remote=origin \
    --push

# Step 3: Update ArgoCD application with correct repo URL
echo -e "\n${BLUE}Step 3: Updating ArgoCD application manifest...${NC}"
REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"
sed -i "s|https://github.com/YOUR_USERNAME/notification-service-gitops.git|${REPO_URL}|g" argocd/notification-service-app.yaml

# Commit the updated manifest
git add argocd/notification-service-app.yaml
git commit -m "Update ArgoCD application with correct repository URL"
git push origin main

# Step 4: Create branch protection rules
echo -e "\n${BLUE}Step 4: Setting up branch protection...${NC}"
gh api repos/${GITHUB_USERNAME}/${REPO_NAME}/branches/main/protection \
    --method PUT \
    --field required_status_checks='{"strict":true,"contexts":[]}' \
    --field enforce_admins=true \
    --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
    --field restrictions=null || echo -e "${YELLOW}Branch protection setup failed (may require admin privileges)${NC}"

# Step 5: Create GitHub Actions workflow
echo -e "\n${BLUE}Step 5: Creating GitHub Actions workflow...${NC}"
mkdir -p .github/workflows

cat > .github/workflows/validate-manifests.yml << 'EOF'
name: Validate Kubernetes Manifests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Kustomize
      run: |
        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
        sudo mv kustomize /usr/local/bin/
    
    - name: Validate Production Manifests
      run: |
        kustomize build overlays/production > /tmp/production.yaml
        echo "Production manifests are valid"
    
    - name: Validate Dev Manifests
      run: |
        kustomize build overlays/dev > /tmp/dev.yaml
        echo "Dev manifests are valid"
    
    - name: Check for secrets
      run: |
        if grep -r "password\|secret\|key" --include="*.yaml" --include="*.yml" .; then
          echo "Warning: Potential secrets found in manifests"
          exit 1
        fi
        echo "No secrets found in manifests"
EOF

git add .github/workflows/validate-manifests.yml
git commit -m "Add GitHub Actions workflow for manifest validation"
git push origin main

echo -e "\n${GREEN}=== GitHub Repository Setup Complete ===${NC}"
echo -e "\n${BLUE}Repository Details:${NC}"
echo -e "${GREEN}Repository URL: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"
echo -e "${GREEN}Clone URL: git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git${NC}"
echo -e "${GREEN}ArgoCD App: argocd/notification-service-app.yaml${NC}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "${YELLOW}1. Deploy ArgoCD application: ./scripts/deploy-argocd-app.sh${NC}"
echo -e "${YELLOW}2. Sync and test: ./scripts/sync-and-test.sh${NC}"
echo -e "${YELLOW}3. Access repository: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}${NC}"

echo -e "\n${GREEN}GitOps repository is ready for ArgoCD integration!${NC}"
