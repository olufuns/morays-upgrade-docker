(() => {
  'use strict';

  // Mobile navigation opens and closes without reloading the page.
  const menuButton = document.querySelector('.menu-toggle');
  const navLinks = document.querySelector('.nav-links');
  if (menuButton && navLinks) {
    menuButton.addEventListener('click', () => {
      const open = navLinks.classList.toggle('open');
      menuButton.setAttribute('aria-expanded', String(open));
    });
    navLinks.querySelectorAll('a').forEach(link => link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      menuButton.setAttribute('aria-expanded', 'false');
    }));
  }

  // Accessible information dialogs.
  document.querySelectorAll('[data-open-dialog]').forEach(button => {
    button.addEventListener('click', () => {
      const dialog = document.getElementById(button.dataset.openDialog);
      if (dialog && !dialog.open) dialog.showModal();
    });
  });
  document.querySelectorAll('[data-close-dialog]').forEach(button => {
    button.addEventListener('click', () => button.closest('dialog')?.close());
  });
  document.querySelectorAll('dialog').forEach(dialog => {
    dialog.addEventListener('click', event => {
      if (event.target === dialog) dialog.close();
    });
  });

  const details = {
    infrastructure: {
      title: 'Infrastructure with Terraform', icon: '⬡',
      text: 'Terraform declares and deploys the VPC, subnets in two Availability Zones, route tables, security groups, Application Load Balancer, ECS cluster, task definition, Fargate service and CloudWatch logging. It tracks these resources in Terraform state.'
    },
    automation: {
      title: 'Container automation', icon: '⚙',
      text: 'Docker packages the HTML, CSS and JavaScript into a versioned Apache HTTPD image. Deployment scripts build and tag the image, authenticate to Amazon ECR, push it, then apply Terraform to create or update the ECS service.'
    },
    security: {
      title: 'Secure networking and image access', icon: '♢',
      text: 'The Application Load Balancer accepts public HTTP traffic and forwards requests to ECS tasks. The task security group accepts incoming website traffic only from the ALB security group. The ECS task execution IAM role grants permissions to pull images from ECR and write logs. Use HTTPS and private task subnets for production.'
    },
    deployment: {
      title: 'Repeatable ECS releases', icon: '▱',
      text: 'Each deployment uses a unique image tag in an immutable ECR repository. Terraform updates the ECS task definition and ECS service to use the selected image. The ECS service maintains its configured number of tasks, and the load balancer routes traffic to healthy targets.'
    }
  };

  document.querySelectorAll('[data-detail]').forEach(card => {
    card.addEventListener('click', () => {
      const item = details[card.dataset.detail];
      const dialog = document.getElementById('detail-dialog');
      if (!item || !dialog) return;
      document.getElementById('detail-heading').textContent = item.title;
      document.getElementById('detail-icon').textContent = item.icon;
      document.getElementById('detail-content').textContent = item.text;
      if (!dialog.open) dialog.showModal();
    });
  });

  // Only tests the current website's /healthz endpoint; not the AWS control plane.
  const testButton = document.getElementById('run-health-check');
  if (testButton) testButton.addEventListener('click', async () => {
    const indicator = document.getElementById('status-light');
    const label = document.getElementById('status-label');
    const detail = document.getElementById('status-detail');
    indicator.className = 'status-indicator working';
    label.textContent = 'Checking web server…';
    detail.textContent = 'Requesting /healthz from this website';
    testButton.disabled = true;
    const start = performance.now();
    try {
      const response = await fetch('/healthz?check=' + Date.now(), { cache: 'no-store' });
      const body = (await response.text()).trim();
      if (!response.ok || body !== 'ok') {
        throw new Error('Unexpected response (HTTP ' + response.status + ')');
      }
      const ms = Math.round(performance.now() - start);
      indicator.className = 'status-indicator good';
      label.textContent = 'Website is responding';
      detail.textContent = 'HTTP ' + response.status + ' · /healthz returned ok · ' + ms + ' ms';
    } catch (error) {
      indicator.className = 'status-indicator bad';
      label.textContent = 'Website health check failed';
      detail.textContent = error.message + ' — confirm the /healthz file is deployed.';
    } finally {
      testButton.disabled = false;
    }
  });
})();