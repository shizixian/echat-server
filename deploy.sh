#!/bin/bash
# EChat Server Deployment Script
# Run this script locally to deploy the server to Render

echo "=== EChat Server Deployment ==="
echo ""
echo "Step 1: Initializing Git repo..."
cd "$(dirname "$0")"
git init
git add -A
git commit -m "Initial commit - EChat server"

echo ""
echo "==========================================="
echo "Done! Now:"
echo ""
echo "1. Create a GitHub repo called 'echat-server'"
echo "   git remote add origin https://github.com/YOUR_USERNAME/echat-server.git"
echo "   git push -u origin main"
echo ""
echo "2. Go to https://render.com → New Web Service"
echo "   Connect your GitHub repo"
echo "   Set:"
echo "     - Build Command: cd server && npm install"
echo "     - Start Command: cd server && node index.js"
echo ""
echo "3. Once deployed, copy the URL (e.g. https://echat-server.onrender.com)"
echo ""
echo "4. Open the EChat app, enter that URL, register and chat!"
echo "==========================================="
