#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Setting up Kubeflow on Ubuntu VM ===${NC}"

# Check if script was already run
PROGRESS_FILE="$HOME/.kubeflow_setup_progress"
if [ -f "$PROGRESS_FILE" ]; then
  LAST_STEP=$(cat "$PROGRESS_FILE")
  echo -e "${YELLOW}Resuming from step: $LAST_STEP${NC}"
else
  LAST_STEP="start"
  echo "$LAST_STEP" > "$PROGRESS_FILE"
fi

# Function to update progress
update_progress() {
  echo "$1" > "$PROGRESS_FILE"
  echo -e "${YELLOW}Progress saved: $1${NC}"
}

# Install MicroK8s if not already installed
if [ "$LAST_STEP" == "start" ]; then
  echo -e "${GREEN}Installing MicroK8s...${NC}"
  if ! snap list | grep -q microk8s; then
    sudo snap install microk8s --channel=1.32/stable --classic
    echo -e "${GREEN}MicroK8s installed successfully.${NC}"
  else
    echo -e "${YELLOW}MicroK8s is already installed.${NC}"
  fi
  update_progress "microk8s_installed"
fi

# Add user to microk8s group if not already added
if [ "$LAST_STEP" == "microk8s_installed" ] || [ "$LAST_STEP" == "start" ]; then
  echo -e "${GREEN}Configuring MicroK8s permissions...${NC}"
  if ! groups | grep -q microk8s; then
    sudo usermod -a -G microk8s $USER
    echo -e "${YELLOW}User added to microk8s group.${NC}"
    echo -e "${YELLOW}You need to log out and back in, or run 'newgrp microk8s' to apply the changes.${NC}"
    echo -e "${YELLOW}After that, please run this script again.${NC}"
    exit 0
  else
    echo -e "${GREEN}User is already in microk8s group.${NC}"
  fi
  
  # Create the .kube directory if it doesn't exist
  mkdir -p ~/.kube
  sudo chown -f -R $USER ~/.kube
  
  update_progress "user_configured"
fi

# Wait for MicroK8s to be ready
if [ "$LAST_STEP" == "user_configured" ] || [ "$LAST_STEP" == "microk8s_installed" ] || [ "$LAST_STEP" == "start" ]; then
  echo -e "${GREEN}Waiting for MicroK8s to be ready...${NC}"
  microk8s status --wait-ready
  update_progress "microk8s_ready"
fi

# Enable required add-ons
if [ "$LAST_STEP" == "microk8s_ready" ] || [ "$LAST_STEP" == "user_configured" ]; then
  echo -e "${GREEN}Enabling MicroK8s add-ons...${NC}"
  microk8s enable dns hostpath-storage metallb:10.64.140.43-10.64.140.49 rbac
  update_progress "addons_enabled"
fi

# Verify MicroK8s status
if [ "$LAST_STEP" == "addons_enabled" ] || [ "$LAST_STEP" == "microk8s_ready" ]; then
  echo -e "${GREEN}Verifying MicroK8s status...${NC}"
  microk8s status
  update_progress "microk8s_verified"
fi

# Install Juju if not already installed
if [ "$LAST_STEP" == "microk8s_verified" ] || [ "$LAST_STEP" == "addons_enabled" ]; then
  echo -e "${GREEN}Installing Juju...${NC}"
  if ! snap list | grep -q juju; then
    sudo snap install juju --channel=3.6/stable
    echo -e "${GREEN}Juju installed successfully.${NC}"
  else
    echo -e "${YELLOW}Juju is already installed.${NC}"
  fi
  
  # Create required directory for Juju
  mkdir -p ~/.local/share
  update_progress "juju_installed"
fi

# Configure Juju with MicroK8s
if [ "$LAST_STEP" == "juju_installed" ] || [ "$LAST_STEP" == "microk8s_verified" ]; then
  echo -e "${GREEN}Configuring Juju with MicroK8s...${NC}"
  # Check if k8s is already added to Juju
  if ! juju clouds | grep -q my-k8s; then
    microk8s config | juju add-k8s my-k8s --client
  else
    echo -e "${YELLOW}Kubernetes cloud 'my-k8s' already added to Juju.${NC}"
  fi
  update_progress "juju_configured"
fi

# Bootstrap Juju controller
if [ "$LAST_STEP" == "juju_configured" ] || [ "$LAST_STEP" == "juju_installed" ]; then
  echo -e "${GREEN}Bootstrapping Juju controller...${NC}"
  # Check if controller already exists
  if ! juju controllers | grep -q uk8sx; then
    juju bootstrap my-k8s uk8sx
  else
    echo -e "${YELLOW}Juju controller 'uk8sx' already exists.${NC}"
  fi
  update_progress "juju_bootstrapped"
fi

# Create Kubeflow model
if [ "$LAST_STEP" == "juju_bootstrapped" ] || [ "$LAST_STEP" == "juju_configured" ]; then
  echo -e "${GREEN}Creating Kubeflow model...${NC}"
  # Check if model already exists
  if ! juju models | grep -q kubeflow; then
    juju add-model kubeflow
  else
    echo -e "${YELLOW}Juju model 'kubeflow' already exists.${NC}"
  fi
  update_progress "model_created"
fi

# Configure system for Kubeflow
if [ "$LAST_STEP" == "model_created" ] || [ "$LAST_STEP" == "juju_bootstrapped" ]; then
  echo -e "${GREEN}Configuring system for Kubeflow...${NC}"
  sudo sysctl fs.inotify.max_user_instances=1280
  sudo sysctl fs.inotify.max_user_watches=655360

  # Add settings to sysctl.conf to persist across reboots if not already added
  if ! grep -q "fs.inotify.max_user_instances=1280" /etc/sysctl.conf; then
    echo "fs.inotify.max_user_instances=1280" | sudo tee -a /etc/sysctl.conf
  fi
  
  if ! grep -q "fs.inotify.max_user_watches=655360" /etc/sysctl.conf; then
    echo "fs.inotify.max_user_watches=655360" | sudo tee -a /etc/sysctl.conf
  fi
  
  update_progress "system_configured"
fi

# Deploy Kubeflow
if [ "$LAST_STEP" == "system_configured" ] || [ "$LAST_STEP" == "model_created" ]; then
  echo -e "${GREEN}Deploying Kubeflow (this may take some time)...${NC}"
  # Check if Kubeflow is already deployed
  if ! juju status | grep -q "kubeflow-dashboard"; then
    juju deploy kubeflow --trust --channel=1.10/stable
    echo -e "${GREEN}Kubeflow deployment initiated.${NC}"
    echo -e "${YELLOW}Note: The deployment may take up to 20 minutes to complete.${NC}"
    echo -e "${YELLOW}You can check the status with: juju status --watch 5s${NC}"
  else
    echo -e "${YELLOW}Kubeflow appears to be already deployed.${NC}"
  fi
  update_progress "kubeflow_deployed"
fi

# Format and mount the data disk
if [ "$LAST_STEP" == "kubeflow_deployed" ] || [ "$LAST_STEP" == "system_configured" ]; then
  echo -e "${GREEN}Checking for data disk...${NC}"
  if [ -b /dev/sdc ]; then
    # Check if disk is already mounted
    if ! mount | grep -q "/data"; then
      echo -e "${GREEN}Formatting and mounting data disk...${NC}"
      sudo parted /dev/sdc --script mklabel gpt mkpart primary ext4 0% 100%
      sudo mkfs.ext4 /dev/sdc1
      sudo mkdir -p /data
      sudo mount /dev/sdc1 /data
      
      # Add to fstab if not already there
      if ! grep -q "/dev/sdc1 /data" /etc/fstab; then
        echo "/dev/sdc1 /data ext4 defaults 0 2" | sudo tee -a /etc/fstab
      fi
      
      sudo chown -R $USER:$USER /data
      echo -e "${GREEN}Data disk mounted at /data${NC}"
    else
      echo -e "${YELLOW}Data disk is already mounted at /data.${NC}"
    fi
  else
    echo -e "${YELLOW}Data disk not found. Skipping disk setup.${NC}"
  fi
  update_progress "completed"
fi

if [ "$LAST_STEP" == "completed" ]; then
  echo -e "${GREEN}=== Kubeflow setup completed! ===${NC}"
  echo -e "${GREEN}You can access the Kubeflow dashboard by port-forwarding:${NC}"
  echo -e "${YELLOW}microk8s kubectl port-forward -n kubeflow service/istio-ingressgateway 8080:80 --address 0.0.0.0${NC}"
  echo -e "${GREEN}Then visit http://YOUR_VM_IP:8080${NC}"
fi 