

**Complete nginx zero-downtime setup:**

**Step 1: Create nginx config on EC2 (one time):**
```bash
mkdir -p /home/ec2-user/nginx
cat > /home/ec2-user/nginx/default.conf << 'EOF'
upstream app {
    server 127.0.0.1:5000;
}
server {
    listen 80;
    location / {
        proxy_pass http://app;
    }
}
EOF
```

**Step 2: Run nginx container (one time):**
```bash
docker run -d --name nginx \
  --network host \
  -v /home/ec2-user/nginx/default.conf:/etc/nginx/conf.d/default.conf \
  --restart always \
  nginx:alpine
```

**Step 3: Pipeline deploy script changes to:**
```bash
# 1. Start new on 5001
docker run -d --name healthcare-new -p 5001:5000 $IMAGE
sleep 15

# 2. Health check new
HTTP_CODE=$(curl -so /dev/null -w "%{http_code}" http://localhost:5001/health)

if [ "$HTTP_CODE" = "200" ]; then
  # 3. Switch nginx to new (zero downtime — instant)
  sed -i 's/server 127.0.0.1:.*/server 127.0.0.1:5001;/' /home/ec2-user/nginx/default.conf
  docker exec nginx nginx -s reload

  # 4. Stop old
  docker stop healthcare-website 2>/dev/null || true
  docker rm healthcare-website 2>/dev/null || true

  # 5. Rename new → standard name on port 5000
  docker stop healthcare-new
  docker rm healthcare-new
  docker run -d --name healthcare-website -p 5000:5000 --restart unless-stopped $IMAGE

  # 6. Switch nginx back to 5000
  sed -i 's/server 127.0.0.1:.*/server 127.0.0.1:5000;/' /home/ec2-user/nginx/default.conf
  docker exec nginx nginx -s reload
else
  docker rm -f healthcare-new
  exit 1
fi
```

**User accesses:** `http://EC2-IP:80` (nginx) — never sees downtime.

But this is complex. Don't add to Episode 6. Record the video with current setup.