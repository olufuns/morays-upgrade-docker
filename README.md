# morays-upgrade-docker

# Morays Upgrade Docker: ECR + ECS Fargate (Terraform)

This package adds **Terraform configuration and scripts only** to your EXISTING project.
It does not contain or overwrite your `website/` directory or Dockerfile.

## What it creates

**01-ecr** (separate Terraform state):
- Private ECR repository `morays-devops-upgrade-docker`
- Immutable tags (new tag for every push), basic scan on push, lifecycle retains latest 15 tagged images

**02-ecs** (separate Terraform state):
- New VPC `10.42.0.0/16`, two public subnets in separate AZs, IGW and public routing
- Internet-facing HTTP Application Load Balancer + `/healthz` target group
- ECS Fargate cluster, task definition and service (`0.25 vCPU, 0.5 GB RAM, desired=1`)
- CloudWatch logs and an ECS task-execution IAM role
- ALB public security group and restricted task security group (only the ALB can connect to port 80)

No EC2 servers, no Ansible, no RDS, and no NAT gateway are required. This is a **learning/demo** architecture, not a production-ready secure private-subnet design. Public-IP Fargate task permits downloading ECR images and sending logs without NAT. The ALB forwards only healthy targets.

## Prerequisites

- Ubuntu (WSL) and Docker Desktop running; your installation works with `docker.exe` in Ubuntu
- `aws`, `terraform` and `curl` installed in Ubuntu
- AWS CLI authenticated to the intended account (`aws sts get-caller-identity`)
- Appropriate IAM permissions to manage ECR, VPC, ELBv2, ECS, IAM and CloudWatch
- Your project root contains `Dockerfile` and `website/index.html` and `website/healthz`
- Your Dockerfile must copy the WHOLE website folder:

```Dockerfile
FROM httpd:2.4
COPY website/ /usr/local/apache2/htdocs/
EXPOSE 80
```

## Install the files

Extract the ZIP **into** `~/morays-project/morays-upgrade-docker/`.
Back up any existing `deploy.sh`, `verify.sh`, `destroy.sh`, `01-ecr` and `02-ecs` first if you have customized them. Do not overwrite Terraform state files.

```bash
cd ~/morays-project/morays-upgrade-docker
chmod +x deploy.sh verify.sh destroy.sh
```

## Stage 1: provision ECR and push the website image

```bash
./deploy.sh ecr
```

Review the ECR Terraform plan and type `APPLY-ECR` when prompted. The script validates the Terraform ECR configuration, creates the repository (if this state doesn't already manage it), builds the current website, generates a unique immutable tag, logs in to ECR, pushes the image and saves the full URI to `.ecr-image-uri`.

Verify:

```bash
cat .ecr-image-uri
aws ecr list-images --repository-name morays-devops-upgrade-docker --region eu-west-2
```

## Stage 2: deploy to ECS Fargate

```bash
./deploy.sh ecs
```

Review the ECS Terraform plan and type `APPLY-ECS` when prompted. Terraform then creates the network, ALB, ECS and CloudWatch resources and outputs the website URL.

Verify:

```bash
./verify.sh
terraform -chdir=02-ecs output -raw website_url
```

You can also deploy both stages in one command (build, push and update ECS):

```bash
./deploy.sh all
```

Every run of `ecr` or `all` uses a new image tag, because ECR tags are immutable. Running `ecs` alone reuses the image URI saved in `.ecr-image-uri`.

## Costs and cleanup

Fargate, ALB, public IPv4, ECR and CloudWatch are **chargeable**. For a demonstration, destroy ECS resources soon after testing:

```bash
./destroy.sh
```

This **does not delete ECR**. To remove ECR completely, first remove ECR images from this project's repository (console or AWS CLI), then check `terraform -chdir=01-ecr plan -destroy` and run `terraform -chdir=01-ecr destroy` from the same project. The ECR resource deliberately has `force_delete=false` to prevent accidental removal of images.

**Do not delete `.tfstate` files**. Back up local Terraform state files securely; they define resource ownership. Do not run two Terraform states against the same already-managed resource. If an ECR repository already exists outside this Terraform state, `terraform apply` will not automatically adopt it; import only when you're sure it isn't managed by another state.

## Troubleshooting

- `RepositoryAlreadyExistsException`: you already have this repository; determine which Terraform state manages it, or select a new name using `ECR_REPOSITORY_NAME=new-name ./deploy.sh ecr`.
- `docker ... /var/run/docker.sock not found`: use working Docker Desktop Windows CLI from Ubuntu (`docker.exe`). This script detects it first.
- ECS task fails to start: check `aws ecs describe-services`, CloudWatch log group `/ecs/morays-upgrade-docker`, and task `stoppedReason`.
- ALB shows 503: check `/healthz` exists and returns exactly `ok`, image has been pushed, security group and target health.
- ECR immutable tag conflict: the script makes a new tag per run; don't push a different image under an existing tag.
- HTTP only: use HTTPS/ACM and private subnets/VPC endpoints for production deployments.

## Change the AWS region or project prefix

The scripts use `AWS_REGION=eu-west-2` and `PROJECT_NAME=morays-upgrade-docker` by default. To change:

```bash
AWS_REGION=eu-west-2 PROJECT_NAME=morays-upgrade-docker ./deploy.sh all
```

Keep the same values between deploy and destroy, or Terraform may propose creating different names. Changing the region after deployment can strand resources in the original region.

## How automation fits together

`./deploy.sh ecr` : `Dockerfile + website` -> local Docker image -> ECR repository/image

`./deploy.sh ecs` : Saved ECR image URI -> ECS task definition -> Fargate task -> ALB URL

`./verify.sh` : checks ECS running task counts, target-group health and `/healthz`

`./destroy.sh` : destroys Terraform state owned by `02-ecs` only (keeps ECR)