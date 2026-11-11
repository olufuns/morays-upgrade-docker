#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-eu-west-2}"
command -v terraform >/dev/null || { echo "Terraform missing"; exit 1; }
command -v aws >/dev/null || { echo "AWS CLI missing"; exit 1; }
command -v curl >/dev/null || { echo "curl missing"; exit 1; }

if ! url="$(terraform -chdir="$ROOT/02-ecs" output -raw website_url 2>/dev/null)"; then
  echo "ECS Terraform output not found. Run ./deploy.sh ecs first."; exit 1
fi
cluster="$(terraform -chdir="$ROOT/02-ecs" output -raw cluster_name)"
service="$(terraform -chdir="$ROOT/02-ecs" output -raw service_name)"
tg="$(terraform -chdir="$ROOT/02-ecs" output -raw target_group_arn)"
echo "Website: $url"
echo "ECS service status:"
aws ecs describe-services --cluster "$cluster" --services "$service" --region "$AWS_REGION" \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount}' --output table

echo "Load balancer target health:"
aws elbv2 describe-target-health --target-group-arn "$tg" --region "$AWS_REGION" \
  --query 'TargetHealthDescriptions[].{Target:Target.Id,Health:TargetHealth.State,Reason:TargetHealth.Reason}' --output table

# ALB target registration can take a little time after terraform apply.
for i in {1..12}; do
  body="$(curl --silent --show-error --max-time 8 --fail "$url/healthz" 2>/dev/null || true)"
  if [[ "$body" == "ok" ]]; then
    echo "PASS: GET $url/healthz -> ok"
    echo "Open your website: $url"
    exit 0
  fi
  echo "Health check attempt $i/12 not ready yet..."
  if [[ "$i" -lt 12 ]]; then sleep 10; fi
done
echo "FAIL: Site has not returned 'ok' from /healthz. Check ECS events, task logs and target health."
exit 1
