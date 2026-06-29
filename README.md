# EChat - End-to-End Encrypted Chat App

A secure, private messaging app with end-to-end encryption, built with Flutter.

## Features
- End-to-End encryption (X25519 ECDH + AES-256-GCM)
- Real-time messaging via WebSocket
- Online/offline status
- Typing indicators
- Beautiful dark theme UI
- Cross-platform: Android, iOS, Web

## Quick Start

### 1. Deploy the Server (Cloud)

The server needs to be deployed to a cloud service so it's accessible over the internet.

#### Option A: Deploy to Render (Free)

1. Push this repo to GitHub
2. Go to [render.com](https://render.com) and sign up
3. Click "New +" > "Web Service"
4. Connect your GitHub repo
5. Set:
   - Name: `echat-server`
   - Root Directory: `server/` (or use the render.yaml at project root)
   - Build Command: `cd server && npm install`
   - Start Command: `cd server && node index.js`
6. Click "Create Web Service"
7. Once deployed, copy the URL (e.g., `https://echat-server.onrender.com`)

#### Option B: Deploy to Railway

1. Push to GitHub
2. Go to [railway.app](https://railway.app)
3. Create new project from your GitHub repo
4. Set start command: `cd server && node index.js`
5. Get the public URL

### 2. Install the App

#### Android
- Download `EChat.apk` from this folder
- Install on your Android device
- Open the app and enter your server URL (from step 1)

#### iOS
- Requires a Mac with Xcode
- Open `ios/` in Xcode
- Update signing team
- Run `flutter build ios --release`
- Or use TestFlight for distribution

#### Web
- Run `flutter build web --release` in the project directory
- Deploy the `build/web` folder to any static hosting (Vercel, Netlify, etc.)

### 3. Connect

1. Launch the app
2. Enter your deployed server URL
3. Register a new account
4. Search for other users by username
5. Start chatting - all messages are E2E encrypted!

## Architecture

```
┌─────────────────┐     WebSocket/REST     ┌──────────────┐
│  Flutter App     │ ◄─────────────────►   │  Node.js     │
│  (Android/iOS)   │                        │  Server      │
│                  │                        │  (Cloud)     │
│  X25519 + AES    │                        │  SQLite DB   │
└─────────────────┘                        └──────────────┘
```

## Encryption
- Key Exchange: X25519 (Curve25519)
- Message Encryption: AES-256-GCM
- Each message is encrypted with a unique shared secret derived from ECDH
- Server never sees plaintext messages
- Perfect forward secrecy

## Tech Stack
- **Frontend**: Flutter 3.x (Dart)
- **Backend**: Node.js, Express, WebSocket (ws)
- **Database**: SQLite (better-sqlite3)
- **Encryption**: cryptography package (X25519 + AES-256-GCM)
- **State Management**: Provider

## Project Structure
```
encrypted_chat/
├── lib/
│   ├── config/          # App configuration
│   ├── models/          # User, Message, Conversation
│   ├── services/        # API, Crypto, Storage, ChatProvider
│   ├── screens/         # Login, ChatList, Chat
│   └── main.dart        # App entry point
├── server/
│   ├── index.js         # Main server (WebSocket + REST API)
│   ├── package.json
│   ├── Dockerfile
│   └── Procfile
├── render.yaml          # Render deployment config
└── pubspec.yaml
```
