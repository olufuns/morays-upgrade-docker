#!/usr/bin/env bash
# Remove ONLY this project's ECS infrastructure by default.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-eu-west-2}"
PROJECT_NAME="${PROJECT_NAME:-morays-upgrade-docker}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-morays-devops-upgrade-docker}"
command -v terraform >/dev/null || { echo "Terraform missing"; exit 1; }

cat <<EOF
WARNING: This destroys ECS, VPC, ALB and other resources managed by 02-ecs state.
It does NOT remove the ECR repository or its Docker images by default.
Make sure you are destroying only THIS project's state.
EOF
read -r -p "Type DESTROY-ECS to confirm: " answer
[[ "$answer" == "DESTROY-ECS" ]] || { echo "Cancelled"; exit 1; }

# A placeholder is sufficient for planning destruction when no saved URI exists.
image_uri="unused-for-destroy"
[[ -s "$ROOT/.ecr-image-uri" ]] && image_uri="$(cat "$ROOT/.ecr-image-uri")"
terraform -chdir="$ROOT/02-ecs" init -input=false
terraform -chdir="$ROOT/02-ecs" destroy \
  -var="aws_region=$AWS_REGION" -var="project_name=$PROJECT_NAME" \
  -var="image_uri=$image_uri"
cat <<EOF
ECS infrastructure destroy operation completed if Terraform reported success.
ECR repository retained: $ECR_REPOSITORY_NAME
To delete ECR later, empty the images and separately destroy Terraform's 01-ecr state.
Never delete .tfstate files to clean up AWS resources.
EOF