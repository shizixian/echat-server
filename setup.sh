#!/bin/bash
# EChat Project Setup Script
# Run this on your development machine with Flutter installed.

set -e

echo "=== EChat Setup ==="
echo ""

# 1. Install server dependencies
echo "[1/3] Installing server dependencies..."
cd "$(dirname "$0")/server"
npm install
echo "  Server dependencies installed."
echo ""

# 2. Install Flutter dependencies
echo "[2/3] Installing Flutter dependencies..."
cd ..
flutter pub get
echo "  Flutter dependencies installed."
echo ""

# 3. Regenerate platform projects if needed
echo "[3/3] Verifying platform projects..."
if [ ! -f "android/gradle/wrapper/gradle-wrapper.properties" ]; then
  flutter create --platforms android,ios .
  echo "  Platform projects regenerated."
else
  echo "  Platform projects exist."
fi
echo ""

echo "=== Setup Complete ==="
echo ""
echo "To start the server:  cd server && npm start"
echo "To build Flutter app: flutter run"
echo ""
echo "Make sure to set the server URL in lib/config/constants.dart"
echo "before building for deployment."
