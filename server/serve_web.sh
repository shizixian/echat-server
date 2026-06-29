#!/bin/bash
# EChat Unified Server - serves API + Web UI on one port
# Usage: ./serve_web.sh [port]

PORT=${1:-8730}
WEB_DIR="../build/web"

if [ ! -d "$WEB_DIR" ]; then
  echo "Web build not found. Running 'flutter build web'..."
  cd ..
  flutter build web --release
  cd server
fi

echo "Starting EChat on http://localhost:$PORT"
echo ""

# Start the API server (internal, on port 8731)
PORT=8731 node index.js &
API_PID=$!
sleep 1

# Start the unified web server
node -e "
const http = require('http');
const fs = require('fs');
const path = require('path');
const { createProxy } = require('http-proxy');

const PORT = $PORT;
const WEB_DIR = path.resolve('$WEB_DIR');

const mime = {
  '.html': 'text/html','.js':'application/javascript','.css':'text/css',
  '.png':'image/png','.jpg':'image/jpeg','.svg':'image/svg+xml',
  '.ico':'image/x-icon','.json':'application/json','.wasm':'application/wasm',
};

http.createServer((req, res) => {
  if (req.url.startsWith('/api') || req.url.startsWith('/ws')) {
    // Redirect: 127.0.0.1:8731 -> same path
    const opts = { hostname:'127.0.0.1', port:8731, path:req.url, method:req.method, headers:req.headers };
    const proxy = http.request(opts, pr => { res.writeHead(pr.statusCode, pr.headers); pr.pipe(res); });
    req.pipe(proxy);
    return;
  }
  let fp = path.join(WEB_DIR, req.url === '/' ? 'index.html' : req.url);
  fs.readFile(fp, (e,d) => {
    if (e) {
      fs.readFile(path.join(WEB_DIR,'index.html'), (e2,d2) => {
        if (e2) { res.writeHead(404); res.end('Not found'); return; }
        res.writeHead(200,{'Content-Type':'text/html'}); res.end(d2);
      });
      return;
    }
    res.writeHead(200,{'Content-Type':mime[path.extname(fp)]||'application/octet-stream'});
    res.end(d);
  });
}).listen(PORT, () => console.log('EChat ready: http://localhost:'+PORT));
" 2>&1

# Cleanup
trap "kill $API_PID 2>/dev/null; exit" SIGINT SIGTERM
wait
