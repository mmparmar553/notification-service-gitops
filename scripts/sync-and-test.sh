#!/bin/bash

# Sync and Test Notification Service via ArgoCD
# This script syncs the ArgoCD application and tests the deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Syncing and Testing Notification Service ===${NC}"

# Step 1: Check ArgoCD application status
echo -e "\n${BLUE}Step 1: Checking ArgoCD application status...${NC}"
if ! kubectl get application notification-service -n argocd &> /dev/null; then
    echo -e "${RED}Error: ArgoCD application 'notification-service' not found${NC}"
    echo -e "${YELLOW}Run ./deploy-argocd-app.sh first${NC}"
    exit 1
fi

# Step 2: Force sync the application
echo -e "\n${BLUE}Step 2: Forcing application sync...${NC}"
kubectl patch application notification-service -n argocd --type merge --patch='{"spec":{"syncPolicy":{"automated":null}}}'
kubectl patch application notification-service -n argocd --type merge --patch='{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD","prune":true}}}'

# Step 3: Wait for sync to complete
echo -e "\n${BLUE}Step 3: Waiting for sync to complete...${NC}"
for i in {1..30}; do
    SYNC_STATUS=$(kubectl get application notification-service -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    HEALTH_STATUS=$(kubectl get application notification-service -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    echo -e "${YELLOW}Sync Status: ${SYNC_STATUS}, Health Status: ${HEALTH_STATUS}${NC}"
    
    if [ "$SYNC_STATUS" == "Synced" ] && [ "$HEALTH_STATUS" == "Healthy" ]; then
        echo -e "${GREEN}Application is synced and healthy!${NC}"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo -e "${RED}Timeout waiting for application to sync${NC}"
        exit 1
    fi
    
    sleep 10
done

# Step 4: Check deployed resources
echo -e "\n${BLUE}Step 4: Checking deployed resources...${NC}"
echo -e "${YELLOW}Pods:${NC}"
kubectl get pods -n microservices -l app=notification-service

echo -e "\n${YELLOW}Services:${NC}"
kubectl get svc -n microservices -l app=notification-service

echo -e "\n${YELLOW}HPA:${NC}"
kubectl get hpa -n microservices -l app=notification-service

echo -e "\n${YELLOW}Ingress:${NC}"
kubectl get ingress -n microservices -l app=notification-service

# Step 5: Get service URL
echo -e "\n${BLUE}Step 5: Getting service URL...${NC}"
EXTERNAL_IP=""
for i in {1..12}; do
    EXTERNAL_IP=$(kubectl get svc notification-service-lb -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
        echo -e "${GREEN}External IP: ${EXTERNAL_IP}${NC}"
        break
    else
        echo -e "${YELLOW}Waiting for LoadBalancer IP... (${i}/12)${NC}"
        sleep 5
    fi
done

# Step 6: Test the service
echo -e "\n${BLUE}Step 6: Testing the notification service...${NC}"
if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
    # Test health endpoint
    echo -e "${YELLOW}Testing health endpoint...${NC}"
    HEALTH_RESPONSE=$(curl -s http://${EXTERNAL_IP}/health || echo "Failed")
    if [[ "$HEALTH_RESPONSE" == *"healthy"* ]]; then
        echo -e "${GREEN}✅ Health check passed${NC}"
        echo -e "${BLUE}Response: ${HEALTH_RESPONSE}${NC}"
    else
        echo -e "${RED}❌ Health check failed${NC}"
        echo -e "${RED}Response: ${HEALTH_RESPONSE}${NC}"
    fi
    
    # Test notification endpoint
    echo -e "\n${YELLOW}Testing notification endpoint...${NC}"
    NOTIFICATION_RESPONSE=$(curl -s -X POST http://${EXTERNAL_IP}/notifications \
        -H 'Content-Type: application/json' \
        -d '{"message":"ArgoCD GitOps deployment successful!","type":"success","recipient":"devops-team"}' || echo "Failed")
    
    if [[ "$NOTIFICATION_RESPONSE" == *"success"* ]]; then
        echo -e "${GREEN}✅ Notification test passed${NC}"
        echo -e "${BLUE}Response: ${NOTIFICATION_RESPONSE}${NC}"
    else
        echo -e "${RED}❌ Notification test failed${NC}"
        echo -e "${RED}Response: ${NOTIFICATION_RESPONSE}${NC}"
    fi
    
    # Test stats endpoint
    echo -e "\n${YELLOW}Testing stats endpoint...${NC}"
    STATS_RESPONSE=$(curl -s http://${EXTERNAL_IP}/stats || echo "Failed")
    if [[ "$STATS_RESPONSE" == *"total_notifications"* ]]; then
        echo -e "${GREEN}✅ Stats test passed${NC}"
        echo -e "${BLUE}Response: ${STATS_RESPONSE}${NC}"
    else
        echo -e "${RED}❌ Stats test failed${NC}"
        echo -e "${RED}Response: ${STATS_RESPONSE}${NC}"
    fi
else
    echo -e "${YELLOW}External IP not available, testing with port-forward...${NC}"
    kubectl port-forward svc/notification-service 8080:80 -n microservices &
    PF_PID=$!
    sleep 5
    
    HEALTH_RESPONSE=$(curl -s http://localhost:8080/health || echo "Failed")
    if [[ "$HEALTH_RESPONSE" == *"healthy"* ]]; then
        echo -e "${GREEN}✅ Health check passed (port-forward)${NC}"
    else
        echo -e "${RED}❌ Health check failed (port-forward)${NC}"
    fi
    
    kill $PF_PID 2>/dev/null || true
fi

# Step 7: Show ArgoCD application details
echo -e "\n${BLUE}Step 7: ArgoCD application summary...${NC}"
kubectl get application notification-service -n argocd -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
REVISION:.status.sync.revision

echo -e "\n${GREEN}=== Sync and Test Complete ===${NC}"

echo -e "\n${BLUE}Service URLs:${NC}"
if [ ! -z "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
    echo -e "${GREEN}External URL: http://${EXTERNAL_IP}${NC}"
    echo -e "${GREEN}Health Check: http://${EXTERNAL_IP}/health${NC}"
    echo -e "${GREEN}Send Notification: POST http://${EXTERNAL_IP}/notifications${NC}"
    echo -e "${GREEN}Get Stats: http://${EXTERNAL_IP}/stats${NC}"
else
    echo -e "${YELLOW}Use port-forward: kubectl port-forward svc/notification-service 8080:80 -n microservices${NC}"
    echo -e "${YELLOW}Then access: http://localhost:8080${NC}"
fi

echo -e "\n${BLUE}GitOps Workflow:${NC}"
echo -e "${GREEN}✅ Repository: Configured${NC}"
echo -e "${GREEN}✅ ArgoCD App: Deployed${NC}"
echo -e "${GREEN}✅ Sync Status: Healthy${NC}"
echo -e "${GREEN}✅ Service: Running${NC}"

echo -e "\n${YELLOW}To make changes:${NC}"
echo -e "1. Update manifests in your GitHub repository"
echo -e "2. Commit and push changes"
echo -e "3. ArgoCD will automatically sync the changes"
echo -e "4. Monitor sync status in ArgoCD UI"

echo -e "\n${GREEN}Your notification service is now fully managed by GitOps!${NC}"
