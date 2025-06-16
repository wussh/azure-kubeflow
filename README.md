# Azure Kubeflow Deployment

This project provides Terraform configuration to deploy Kubeflow on Azure using a single Ubuntu VM. It automates the setup of MicroK8s, Juju, and Kubeflow, creating a complete machine learning platform on Azure.

## Architecture

The deployment creates the following resources:
- Resource Group (`rg-kubeflow`)
- Virtual Network and Subnet
- Network Security Group with SSH, HTTP, and HTTPS access
- Public IP address (Standard SKU, static)
- Network Interface
- Ubuntu 22.04 LTS Virtual Machine
- 100GB Data Disk for persistent storage
- Auto-generated SSH Key Pair

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) v1.0.0+
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) v2.30.0+
- An Azure subscription

## Setup Instructions

### 1. Configure Azure Authentication

```bash
# Login to Azure
az login

# Set subscription (if you have multiple)
az account set --subscription="SUBSCRIPTION_ID"
```

### 2. Configure Provider Settings

Create a `provider.tf` file based on the provided example:

```bash
cp provider.tf.example provider.tf
```

Edit `provider.tf` and update the following values:
- `subscription_id`: Your Azure subscription ID
- `tenant_id`: Your Azure tenant ID

### 3. Customize Deployment (Optional)

You can modify the default values in `terraform.tfvars`:

```hcl
location           = "southeastasia"    # Azure region
resource_group_name = "rg-kubeflow"     # Resource group name
vm_size           = "Standard_E4s_v5"   # VM size (min 4 cores, 16GB RAM recommended)
admin_username    = "azureuser"         # VM admin username
ssh_key_filename  = "vm_key.pem"        # SSH key filename
data_disk_size_gb = 100                 # Data disk size in GB
os_disk_type      = "Premium_LRS"       # OS disk type
data_disk_type    = "Premium_LRS"       # Data disk type
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### 5. Connect to VM

After the deployment is complete, use the SSH command from the output:

```bash
# Use the SSH connection command from the output
ssh -i vm_key.pem azureuser@<PUBLIC_IP_ADDRESS>
```

### 6. Setup Kubeflow

Once connected to the VM, run the setup script:

```bash
# Make the script executable
chmod +x setup-kubeflow.sh

# Run the setup script
./setup-kubeflow.sh
```

The script will:
1. Install and configure MicroK8s
2. Add the user to required groups
3. Enable necessary MicroK8s add-ons
4. Install Juju
5. Configure Juju with MicroK8s
6. Deploy Kubeflow
7. Format and mount the data disk

**Note:** You may need to run the script multiple times as it requires you to log out and back in to apply group membership changes.

## About the Setup Script

The `setup-kubeflow.sh` script has been designed with robustness in mind:

- **Progress Tracking**: The script saves its progress in `~/.kubeflow_setup_progress` and can resume from where it left off if interrupted.
- **Idempotent Operations**: All operations check if they've already been completed, preventing duplicate installations.
- **Group Membership Handling**: The script checks if the user is already in the microk8s group and provides clear instructions if a group membership change requires logging out.
- **Error Handling**: Comprehensive checks are performed at each step to ensure successful execution.

To use the script effectively:
1. Run it once to install MicroK8s and add yourself to the group
2. Run `newgrp microk8s` as suggested in the output
3. Run the script again to continue the setup process

## Accessing Kubeflow Dashboard

After the deployment is complete, you can access the Kubeflow dashboard by:

```bash
# Forward the Kubeflow dashboard port
microk8s kubectl port-forward -n kubeflow service/istio-ingressgateway 8080:80 --address 0.0.0.0
```

Then visit `http://<YOUR_VM_IP>:8080` in your browser.

Default credentials:
- Username: `admin@kubeflow.org`
- Password: `admin`

## Kubeflow Components

The deployment includes:
- MicroK8s - A lightweight Kubernetes distribution
- Juju - A software orchestration engine
- Kubeflow - Machine learning toolkit for Kubernetes
  - Jupyter Notebooks
  - TensorFlow Training
  - KFServing
  - Katib (AutoML)
  - Pipelines
  - And more

## Resource Requirements

The default VM size (`Standard_E4s_v5`) is recommended for a basic Kubeflow deployment. For production workloads, consider using a larger VM size with more CPU and memory.

Minimum requirements:
- 4 CPU cores
- 16GB RAM
- 100GB disk space

## Troubleshooting

### Common Issues

1. **Group Membership Changes**:
   If you see permission errors, make sure you've run `newgrp microk8s` or logged out and back in after the first run of the setup script.

2. **MicroK8s Status**:
   Check MicroK8s status with `microk8s status`.

3. **Juju Status**:
   Monitor Kubeflow deployment with `juju status --watch 5s`.

4. **Kubeflow Dashboard Access**:
   If you can't access the dashboard, check that port 8080 is allowed in the Network Security Group.

5. **Script Execution**:
   If the setup script fails, check the progress file at `~/.kubeflow_setup_progress` to see which step it reached.

## Cleanup

To destroy all resources created by Terraform:

```bash
terraform destroy
```

## Security Considerations

- The deployment creates a VM with a public IP address.
- SSH access is secured with a key pair.
- HTTP and HTTPS ports are open for web access.
- Consider using Azure Private Link for production deployments.
- Change the default Kubeflow credentials after first login.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.