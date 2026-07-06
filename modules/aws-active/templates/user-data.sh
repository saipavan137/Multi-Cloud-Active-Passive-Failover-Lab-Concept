#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx

cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Multi-Cloud Failover Lab</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 640px; margin: 4rem auto; padding: 0 1rem; }
    .badge { display: inline-block; background: #ff9900; color: #111; padding: 0.25rem 0.75rem; border-radius: 4px; font-weight: 600; }
    h1 { color: #232f3e; }
  </style>
</head>
<body>
  <p class="badge">ACTIVE — AWS</p>
  <h1>Hello World</h1>
  <p>Traffic is being served from the <strong>AWS</strong> environment (EC2 + Application Load Balancer).</p>
  <p>Stop nginx or block the security group to trigger failover to Azure.</p>
</body>
</html>
HTML

echo "OK" > /var/www/html/health

systemctl enable nginx
systemctl restart nginx
