#!/bin/bash
# Commands to run on server to setup SSL certificate

# Step 1: Create SSL certificate with Let's Encrypt
# Certbot will automatically configure Nginx
sudo certbot --nginx -d doantrang.online -d www.doantrang.online

# Step 2: Test Nginx configuration
sudo nginx -t

# Step 3: Reload Nginx
sudo systemctl reload nginx

# Step 4: Check certificate status
sudo certbot certificates

# Step 5: Test auto-renewal (certbot auto-renews, but you can test)
sudo certbot renew --dry-run

echo "✅ SSL certificate setup complete!"
echo "🌐 Your HTTPS URL: https://yourdomain.com/Hooks/transaction"

