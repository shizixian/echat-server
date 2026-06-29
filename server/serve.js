const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '8730');
const API_PORT = PORT + 1;
const WEB_DIR = path.resolve(__dirname, '../build/web');

const mime = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
};

// Start API server on API_PORT
const apiProcess = require('child_process').spawn('node', [path.join(__dirname, 'index.js')], {
  env: { ...process.env, PORT: String(API_PORT) },
  stdio: 'inherit',
});

// Wait for API to be ready
function waitForAPI(attempts = 20) {
  return new Promise((resolve, reject) => {
    function check(n) {
      const req = http.get(`http://127.0.0.1:${API_PORT}/`, (res) => {
        resolve();
      });
      req.on('error', () => {
        if (n <= 0) reject(new Error('API server not ready'));
        else setTimeout(() => check(n - 1), 200);
      });
      req.end();
    }
    check(attempts);
  });
}

async function main() {
  await waitForAPI();
  console.log(`API server ready on port ${API_PORT}`);

  http.createServer((req, res) => {
    // Proxy API and WebSocket requests
    if (req.url.startsWith('/api')) {
      const opts = {
        hostname: '127.0.0.1',
        port: API_PORT,
        path: req.url,
        method: req.method,
        headers: { ...req.headers, host: `127.0.0.1:${API_PORT}` },
      };
      const proxy = http.request(opts, (pr) => {
        res.writeHead(pr.statusCode, pr.headers);
        pr.pipe(res);
      });
      proxy.on('error', () => {
        res.writeHead(502);
        res.end('Bad gateway');
      });
      req.pipe(proxy);
      return;
    }

    // Serve static files
    let filePath = path.join(WEB_DIR, req.url === '/' ? 'index.html' : req.url);

    fs.readFile(filePath, (err, data) => {
      if (err) {
        // SPA fallback: serve index.html for non-file routes
        fs.readFile(path.join(WEB_DIR, 'index.html'), (err2, data2) => {
          if (err2) {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('Not found');
            return;
          }
          res.writeHead(200, { 'Content-Type': 'text/html' });
          res.end(data2);
        });
        return;
      }
      res.writeHead(200, { 'Content-Type': mime[path.extname(filePath)] || 'application/octet-stream' });
      res.end(data);
    });
  }).listen(PORT, () => {
    console.log(`EChat unified server: http://localhost:${PORT}`);
    console.log(`  API:   http://localhost:${API_PORT}`);
    console.log(`  WebUI: http://localhost:${PORT}`);
  });
}

main().catch((e) => {
  console.error('Failed to start:', e.message);
  process.exit(1);
});
