#!/bin/bash
# EChat Server Startup Script
# Usage: ./start.sh [port]

PORT=${1:-8730}
echo "Starting EChat server on port $PORT..."
PORT=$PORT node index.js
