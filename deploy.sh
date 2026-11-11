#!/usr/bin/env bash
# Usage: ./deploy.sh ecr | ./deploy.sh ecs | ./deploy.sh all
set -Eeuo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-eu-west-2}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-morays-devops-upgrade-docker}"
PROJECT_NAME="${PROJECT_NAME:-morays-upgrade-docker}"
STAGE="${1:-}"

usage() {
  echo "Usage: ./deploy.sh ecr | ./deploy.sh ecs | ./deploy.sh all"
  echo "  ecr = provision repository, build and push website image"
  echo "  ecs = deploy existing pushed image from .ecr-image-uri"
  echo "  all = do both, in order"
}
if [[ ! "$STAGE" =~ ^(ecr|ecs|all)$ ]]; then usage; exit 2; fi

fail() { echo "ERROR: $*" >&2; exit 1; }
for c in aws terraform; do command -v "$c" >/dev/null 2>&1 || fail "Missing: $c"; done
aws sts get-caller-identity --output table || fail "AWS credentials are unavailable"

choose_docker() {
  # In your WSL setup docker.exe connects to Docker Desktop; the Linux socket did not.
  if command -v docker.exe >/dev/null 2>&1 && docker.exe info >/dev/null 2>&1; then
    DOCKER=(docker.exe)
  elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    DOCKER=(docker)
  else
    fail "Docker Engine is unavailable. Start Docker Desktop and test: docker.exe run --rm hello-world"
  fi
  echo "Using Docker command: ${DOCKER[*]}"
}

run_ecr() {
  [[ -f "$PROJECT_ROOT/Dockerfile" ]] || fail "Dockerfile not found at project root"
  [[ -f "$PROJECT_ROOT/website/index.html" ]] || fail "website/index.html is missing"
  [[ -f "$PROJECT_ROOT/website/healthz" ]] || fail "website/healthz is missing"
  choose_docker
  echo "=== Stage 1: ECR and image upload ==="
  terraform -chdir="$PROJECT_ROOT/01-ecr" init -input=false
  terraform -chdir="$PROJECT_ROOT/01-ecr" validate
  terraform -chdir="$PROJECT_ROOT/01-ecr" plan -input=false \
    -var="aws_region=$AWS_REGION" -var="repository_name=$ECR_REPOSITORY_NAME" \
    -out="$PROJECT_ROOT/01-ecr/tfplan"
  read -r -p "Review the ECR plan above. Type APPLY-ECR to create/update ECR: " answer
  [[ "$answer" == "APPLY-ECR" ]] || fail "ECR apply cancelled"
  terraform -chdir="$PROJECT_ROOT/01-ecr" apply -input=false "$PROJECT_ROOT/01-ecr/tfplan"
  local ecr_uri registry tag image_uri
  ecr_uri="$(terraform -chdir="$PROJECT_ROOT/01-ecr" output -raw repository_url)"
  registry="${ecr_uri%%/*}"
  tag="v$(date -u +%Y%m%d%H%M%S)-$(printf '%04x' "$RANDOM")"
  image_uri="$ecr_uri:$tag"
  echo "Building the exact contents of website/ into Apache ..."
  ( cd "$PROJECT_ROOT" && "${DOCKER[@]}" build -t morays-upgrade:local . )
  echo "Logging in to ECR..."
  aws ecr get-login-password --region "$AWS_REGION" | \
    "${DOCKER[@]}" login --username AWS --password-stdin "$registry"
  "${DOCKER[@]}" tag morays-upgrade:local "$image_uri"
  "${DOCKER[@]}" push "$image_uri"
  printf '%s\n' "$image_uri" > "$PROJECT_ROOT/.ecr-image-uri"
  echo "ECR image pushed: $image_uri"
}

run_ecs() {
  echo "=== Stage 2: Terraform ECS Fargate deployment ==="
  [[ -s "$PROJECT_ROOT/.ecr-image-uri" ]] || fail "No saved image URI. Run ./deploy.sh ecr first."
  local image_uri
  image_uri="$(cat "$PROJECT_ROOT/.ecr-image-uri")"
  echo "Image to deploy: $image_uri"
  # Confirm this image exists in ECR, rather than deploying a missing tag.
  local repo tag
  repo="${image_uri#*/}"
  repo="${repo%:*}"
  tag="${image_uri##*:}"
  aws ecr describe-images --region "$AWS_REGION" --repository-name "$repo" \
    --image-ids "imageTag=$tag" --query 'imageDetails[0].imageDigest' --output text \
    >/dev/null || fail "ECR image does not exist: $image_uri"
  terraform -chdir="$PROJECT_ROOT/02-ecs" init -input=false
  terraform -chdir="$PROJECT_ROOT/02-ecs" validate
  terraform -chdir="$PROJECT_ROOT/02-ecs" plan -input=false \
    -var="aws_region=$AWS_REGION" -var="project_name=$PROJECT_NAME" \
    -var="image_uri=$image_uri" \
    -out="$PROJECT_ROOT/02-ecs/tfplan"
  read -r -p "Review the ECS/ALB plan above. Type APPLY-ECS to create/update chargeable infrastructure: " answer
  [[ "$answer" == "APPLY-ECS" ]] || fail "ECS apply cancelled"
  terraform -chdir="$PROJECT_ROOT/02-ecs" apply -input=false "$PROJECT_ROOT/02-ecs/tfplan"
  echo "Website address: $(terraform -chdir="$PROJECT_ROOT/02-ecs" output -raw website_url)"
  echo "Run ./verify.sh to check ECS service, target health, and website."
}

cat <<EOF
AWS region : $AWS_REGION
ECR repo   : $ECR_REPOSITORY_NAME
Project    : $PROJECT_NAME
Stage      : $STAGE

WARNING: ECS Fargate, ALB, ECR, public IPv4 addresses and logs can incur AWS charges.
EOF
case "$STAGE" in
  ecr) run_ecr ;;
  ecs) run_ecs ;;
  all) run_ecr; run_ecs ;;
esac