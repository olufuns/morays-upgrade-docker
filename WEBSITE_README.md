# Morays Upgrade — Docker / ECR / ECS Website

This package updates the original Ansible + EC2 portfolio website to reflect Docker, Amazon ECR, Terraform, ECS Fargate and an Application Load Balancer while retaining the colourful design.

## Install into your existing project

1. Download `morays-upgrade-website.zip` to your Windows Downloads folder.
2. In Ubuntu WSL, run:

```bash
cd ~/morays-project/morays-upgrade-docker
cp -a website "website-backup-$(date +%Y%m%d-%H%M%S)"
unzip -o "/mnt/c/Users/DELL HOME/Downloads/morays-upgrade-website.zip" -d .
```

If your Windows user directory differs from `DELL HOME`, adjust the path.

## Check your directory structure

```text
morays-upgrade-docker/
  website/
    index.html
    healthz
    assets/
      style.css
      app.js
  Dockerfile
  01-ecr/
  02-ecs/
  deploy.sh
  verify.sh
  destroy.sh
```

Your existing Dockerfile should use:

```dockerfile
FROM httpd:2.4
COPY website/ /usr/local/apache2/htdocs/
EXPOSE 80
```

This package only changes the website. It does **not** run a Docker build, push to ECR or apply Terraform. `/healthz` returns plain `ok`; the status dialog checks website HTTP availability, not ECS health or the status of every task.