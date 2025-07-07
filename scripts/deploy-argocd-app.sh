#!/bin/bash

# Deploy ArgoCD Application for Notification Service
# This script deploys the ArgoCD application to manage the notification service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Deploying ArgoCD Application for Notification Service ===${NC}"

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
    exit 1
fi

# Check if ArgoCD is running
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}Error: ArgoCD namespace not found. Is ArgoCD installed?${NC}"
    exit 1
fi

# Step 1: Apply the ArgoCD application
echo -e "\n${BLUE}Step 1: Deploying ArgoCD application...${NC}"
cd "$(dirname "$0")/.."
kubectl apply -f argocd/notification-service-app.yaml

# Step 2: Wait for application to be created
echo -e "\n${BLUE}Step 2: Waiting for application to be created...${NC}"
sleep 5

# Step 3: Check application status
echo -e "\n${BLUE}Step 3: Checking application status...${NC}"
kubectl get application notification-service -n argocd

# Step 4: Get ArgoCD server URL
echo -e "\n${BLUE}Step 4: Getting ArgoCD access information...${NC}"
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$ARGOCD_SERVER" ] || [ "$ARGOCD_SERVER" == "null" ]; then
    # Try to get NodePort or ClusterIP
    ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.clusterIP}')
    ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
    
    if [ ! -z "$ARGOCD_PORT" ]; then
        echo -e "${YELLOW}ArgoCD Server (NodePort): http://${ARGOCD_SERVER}:${ARGOCD_PORT}${NC}"
        echo -e "${YELLOW}Or use port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
    else
        echo -e "${YELLOW}ArgoCD Server (ClusterIP): ${ARGOCD_SERVER}${NC}"
        echo -e "${YELLOW}Use port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
    fi
else
    echo -e "${GREEN}ArgoCD Server (LoadBalancer): https://${ARGOCD_SERVER}${NC}"
fi

# Step 5: Get ArgoCD admin password
echo -e "\n${BLUE}Step 5: Getting ArgoCD admin credentials...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "")

if [ ! -z "$ARGOCD_PASSWORD" ]; then
    echo -e "${GREEN}ArgoCD Admin Username: admin${NC}"
    echo -e "${GREEN}ArgoCD Admin Password: ${ARGOCD_PASSWORD}${NC}"
else
    echo -e "${YELLOW}Could not retrieve ArgoCD password. It may have been changed.${NC}"
fi

# Step 6: Show sync status
echo -e "\n${BLUE}Step 6: Application sync status...${NC}"
kubectl get application notification-service -n argocd -o jsonpath='{.status.sync.status}' && echo
kubectl get application notification-service -n argocd -o jsonpath='{.status.health.status}' && echo

# Step 7: Trigger initial sync
echo -e "\n${BLUE}Step 7: Triggering initial sync...${NC}"
kubectl patch application notification-service -n argocd --type merge --patch='{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

echo -e "\n${GREEN}=== ArgoCD Application Deployment Complete ===${NC}"

echo -e "\n${BLUE}Application Information:${NC}"
echo -e "${GREEN}Name: notification-service${NC}"
echo -e "${GREEN}Namespace: argocd${NC}"
echo -e "${GREEN}Target Namespace: microservices${NC}"

echo -e "\n${BLUE}Monitoring Commands:${NC}"
echo -e "${YELLOW}Check application status:${NC}"
echo -e "  kubectl get application notification-service -n argocd"
echo -e "\n${YELLOW}Watch application sync:${NC}"
echo -e "  kubectl get application notification-service -n argocd -w"
echo -e "\n${YELLOW}View application details:${NC}"
echo -e "  kubectl describe application notification-service -n argocd"

echo -e "\n${BLUE}ArgoCD UI Access:${NC}"
if [ ! -z "$ARGOCD_SERVER" ] && [ "$ARGOCD_SERVER" != "null" ]; then
    echo -e "${GREEN}URL: https://${ARGOCD_SERVER}${NC}"
else
    echo -e "${YELLOW}Port Forward: kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
    echo -e "${YELLOW}Then access: https://localhost:8080${NC}"
fi

echo -e "\n${GREEN}Your notification service is now managed by ArgoCD!${NC}"
echo -e "${BLUE}Any changes to the GitHub repository will be automatically synced.${NC}"
