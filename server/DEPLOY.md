# Server Deployment Guide

## Deploy to Render (Free)

1. Push this repo to GitHub
2. Go to render.com → New Web Service
3. Connect your GitHub repo
4. Use these settings:
   - **Name**: echat-server
   - **Environment**: Node
   - **Build Command**: `cd server && npm install`
   - **Start Command**: `cd server && node index.js`
   - **Plan**: Free
5. After deployment, your URL will be: `https://echat-server.onrender.com`
6. Use this URL in the EChat app

## Deploy with Docker

```bash
cd server
docker build -t echat-server .
docker run -p 8730:8730 echat-server
```

## Environment Variables
- `PORT`: Server port (default: 8730)
- `DB_PATH`: Database file path (default: ./echat.db)

## Health Check
Visit `/health` to verify the server is running.
