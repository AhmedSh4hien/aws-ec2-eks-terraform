# AWS EC2 + EKS with Terraform

Infrastructure as code for provisioning an AWS EC2 instance and a production-style Amazon EKS (Kubernetes) cluster in `eu-central-1`, using Terraform. The EKS stack builds its own VPC, runs worker nodes in private subnets, and was verified end to end by serving an app through an AWS load balancer.

## Architecture

```
                    Internet
                       |
              [ Internet Gateway ]
                       |
   +-------------------+---------------------------------+
   |  VPC 10.0.0.0/16  (3 availability zones)            |
   |                                                     |
   |  Public subnets  (10.0.101-103.0/24)                |
   |    - NAT gateway (single, shared)                   |
   |    - AWS load balancers (created by Kubernetes)     |
   |                                                     |
   |  Private subnets (10.0.1-3.0/24)                    |
   |    - EKS managed node group (2 x t3.small)          |
   |    - Outbound traffic goes via the NAT gateway      |
   +-----------------------------------------------------+
        EKS control plane (managed by AWS)
```

## What it builds

### `eks/`

- VPC `10.0.0.0/16` across 3 availability zones, with 3 public and 3 private subnets
- One shared NAT gateway for outbound traffic from the private subnets
- EKS cluster `devops-demo-dev-eks` (Kubernetes 1.35) with a managed node group of 2 x `t3.small` nodes (scaling 1 to 3) on Amazon Linux 2023
- Cluster add-ons: CoreDNS, kube-proxy, VPC CNI, EKS Pod Identity Agent
- Secrets encryption with a customer-managed KMS key, and IMDSv2 required on nodes
- Subnet tags (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`) so Kubernetes can create AWS load balancers
- Consistent naming and tags (`Project`, `Environment`, `ManagedBy`) driven by a single `locals` block

Built with the community modules `terraform-aws-modules/vpc/aws` (~> 6.0) and `terraform-aws-modules/eks/aws` (~> 21.0). Total: 62 resources.

### `ec2/`

- Amazon Linux 2023 AMI looked up dynamically (no hardcoded AMI ID)
- `t3.micro` instance `devops-demo-dev-ec2` with IMDSv2 required
- SSH key pair registered from a local public key
- Security group allowing SSH (port 22) only from your own IP (`my_ip_cidr`, a /32)
- Output: the instance's public IP address
- Verified by connecting over SSH, then destroyed
  
## Usage

Prerequisites: Terraform, AWS CLI with credentials configured, and `kubectl`.

```bash
cd eks
terraform init
terraform plan
terraform apply          

aws eks update-kubeconfig --region eu-central-1 --name devops-demo-dev-eks
kubectl get nodes
```

Quick test: deploy nginx behind an AWS load balancer.

```bash
kubectl create deployment hello --image=nginx --replicas=2
kubectl expose deployment hello --type=LoadBalancer --port=80
kubectl get service hello      # open the EXTERNAL-IP hostname over http
```

Clean up. Delete the Kubernetes-created load balancer before destroying the VPC:

```bash
kubectl delete service hello
kubectl delete deployment hello
terraform destroy
```

EC2 instance (SSH test):

```bash
cd ec2
cp terraform.tfvars.example terraform.tfvars   # then set my_ip_cidr to <your public IP>/32
terraform init
terraform plan                                  # expect: 3 to add
terraform apply
ssh -i ~/.ssh/terraform-ec2-key ec2-user@$(terraform output -raw instance_public_ip)
terraform destroy
```
