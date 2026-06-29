const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
const Database = require('better-sqlite3');
const { v4: uuidv4 } = require('uuid');
const cors = require('cors');
const path = require('path');

const PORT = process.env.PORT || 8730;
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'echat.db');

// === Database Setup ===
const db = new Database(DB_PATH);
db.pragma('journal_mode=WAL');
db.pragma('foreign_keys=ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    displayName TEXT NOT NULL DEFAULT '',
    passwordHash TEXT NOT NULL,
    publicKey TEXT NOT NULL,
    createdAt TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS conversations (
    id TEXT PRIMARY KEY,
    createdAt TEXT NOT NULL DEFAULT (datetime('now')),
    lastMessage TEXT,
    lastMessageTime TEXT
  );

  CREATE TABLE IF NOT EXISTS conversation_participants (
    conversationId TEXT NOT NULL,
    userId TEXT NOT NULL,
    PRIMARY KEY (conversationId, userId),
    FOREIGN KEY (conversationId) REFERENCES conversations(id),
    FOREIGN KEY (userId) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    conversationId TEXT NOT NULL,
    senderId TEXT NOT NULL,
    senderName TEXT NOT NULL DEFAULT '',
    encryptedContent TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    isRead INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (conversationId) REFERENCES conversations(id),
    FOREIGN KEY (senderId) REFERENCES users(id)
  );

  CREATE TABLE IF NOT EXISTS user_sessions (
    userId TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    createdAt TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (userId) REFERENCES users(id)
  );
`);

const insertUser = db.prepare('INSERT INTO users (id, username, displayName, passwordHash, publicKey) VALUES (?, ?, ?, ?, ?)');
const getUserByUsername = db.prepare('SELECT * FROM users WHERE username = ?');
const getUserById = db.prepare('SELECT * FROM users WHERE id = ?');
const getAllUsers = db.prepare('SELECT * FROM users ORDER BY username');
const createSession = db.prepare('INSERT INTO user_sessions (userId, token) VALUES (?, ?)');
const getSession = db.prepare('SELECT * FROM user_sessions WHERE token = ?');
const deleteSession = db.prepare('DELETE FROM user_sessions WHERE token = ?');
const createConversation = db.prepare('INSERT INTO conversations (id) VALUES (?)');
const addParticipant = db.prepare('INSERT INTO conversation_participants (conversationId, userId) VALUES (?, ?)');
const insertMessage = db.prepare('INSERT INTO messages (id, conversationId, senderId, senderName, encryptedContent, timestamp) VALUES (?, ?, ?, ?, ?, ?)');
const getConversationMessages = db.prepare('SELECT * FROM messages WHERE conversationId = ? ORDER BY timestamp ASC');
const getUserConversations = db.prepare(`
  SELECT c.id, c.lastMessage, c.lastMessageTime,
         u.id as userId, u.displayName as otherUserName
  FROM conversations c
  JOIN conversation_participants cp ON c.id = cp.conversationId
  JOIN conversation_participants cp2 ON c.id = cp2.conversationId AND cp2.userId != cp.userId
  JOIN users u ON cp2.userId = u.id
  WHERE cp.userId = ?
  ORDER BY c.lastMessageTime DESC
`);
const updateConversationLastMessage = db.prepare('UPDATE conversations SET lastMessage = ?, lastMessageTime = ? WHERE id = ?');

// Simple password hashing (for demo - use bcrypt in production)
function simpleHash(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0;
  }
  return 'hash_' + Math.abs(hash).toString(36);
}

// === Express App ===
const app = express();
app.use(cors());
app.use(express.json());

// Auth middleware
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  const session = getSession.get(token);
  if (!session) return res.status(401).json({ error: 'Invalid token' });
  req.userId = session.userId;
  next();
}

// === REST API Routes ===

// Register
app.post('/api/register', (req, res) => {
  const { username, password, displayName, publicKey } = req.body;
  if (!username || !password || !publicKey) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  const existing = getUserByUsername.get(username);
  if (existing) return res.status(409).json({ error: 'Username taken' });

  const id = uuidv4();
  const passwordHash = simpleHash(password);
  insertUser.run(id, username, displayName || username, passwordHash, publicKey);
  const token = uuidv4();
  createSession.run(id, token);
  res.json({ token, userId: id, username, displayName: displayName || username });
});

// Login
app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'Missing credentials' });

  const user = getUserByUsername.get(username);
  if (!user || user.passwordHash !== simpleHash(password)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  const token = uuidv4();
  createSession.run(user.id, token);
  res.json({ token, userId: user.id, username: user.username, displayName: user.displayName, publicKey: user.publicKey });
});

// Get current user
app.get('/api/me', authMiddleware, (req, res) => {
  const user = getUserById.get(req.userId);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ id: user.id, username: user.username, displayName: user.displayName, publicKey: user.publicKey });
});

// Get users (search)
app.get('/api/users', authMiddleware, (req, res) => {
  const search = req.query.search?.toLowerCase() || '';
  const users = getAllUsers.all().filter(u => u.id !== req.userId && (u.username.toLowerCase().includes(search) || u.displayName.toLowerCase().includes(search)));
  res.json(users.map(u => ({ id: u.id, username: u.username, displayName: u.displayName, publicKey: u.publicKey })));
});

// Start or get conversation
app.post('/api/conversations', authMiddleware, (req, res) => {
  const { userId: otherUserId } = req.body;
  if (!otherUserId) return res.status(400).json({ error: 'Missing userId' });

  // Check if conversation already exists
  const existing = db.prepare(`
    SELECT c.id FROM conversations c
    JOIN conversation_participants cp1 ON c.id = cp1.conversationId AND cp1.userId = ?
    JOIN conversation_participants cp2 ON c.id = cp2.conversationId AND cp2.userId = ?
  `).get(req.userId, otherUserId);

  if (existing) return res.json({ conversationId: existing.id });

  const convId = uuidv4();
  createConversation.run(convId);
  addParticipant.run(convId, req.userId);
  addParticipant.run(convId, otherUserId);
  res.json({ conversationId: convId });
});

// Get conversations
app.get('/api/conversations', authMiddleware, (req, res) => {
  const rows = getUserConversations.all(req.userId);
  const convs = rows.map(r => ({
    id: r.id,
    participantIds: [req.userId, r.userId],
    lastMessage: r.lastMessage,
    lastMessageTime: r.lastMessageTime,
    otherUserName: r.otherUserName,
  }));
  res.json(convs);
});

// Get messages
app.get('/api/conversations/:id/messages', authMiddleware, (req, res) => {
  const messages = getConversationMessages.all(req.params.id);
  res.json(messages.map(m => ({
    id: m.id,
    conversationId: m.conversationId,
    senderId: m.senderId,
    senderName: m.senderName,
    encryptedContent: m.encryptedContent,
    timestamp: m.timestamp,
    isRead: !!m.isRead,
  })));
});

// Get user's public key
app.get('/api/users/:id/public-key', authMiddleware, (req, res) => {
  const user = getUserById.get(req.params.id);
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ userId: user.id, publicKey: user.publicKey });
});

// Health check
app.get('/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

// === WebSocket Server ===
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

// Track connected users: userId -> { ws, username }
const connectedUsers = new Map();

wss.on('connection', (ws) => {
  let userId = null;
  let username = '';

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());

      switch (msg.type) {
        case 'auth': {
          const session = getSession.get(msg.token);
          if (!session) {
            ws.send(JSON.stringify({ type: 'error', message: 'Invalid token' }));
            return;
          }
          userId = session.userId;
          const user = getUserById.get(userId);
          if (!user) return;
          username = user.displayName || user.username;
          connectedUsers.set(userId, { ws, username, userId });
          ws.send(JSON.stringify({ type: 'auth_ok', userId, username }));
          // Broadcast user online
          broadcastOnlineUsers();
          break;
        }

        case 'send_message': {
          if (!userId) return;
          const { conversationId, encryptedContent, senderName } = msg;
          const messageId = uuidv4();
          const timestamp = new Date().toISOString();
          insertMessage.run(messageId, conversationId, userId, senderName || username, encryptedContent, timestamp);
          updateConversationLastMessage.run(encryptedContent.substring(0, 100), timestamp, conversationId);

          // Send to other participants
          const participants = db.prepare('SELECT userId FROM conversation_participants WHERE conversationId = ?').all(conversationId);
          for (const p of participants) {
            if (p.userId === userId) continue;
            const conn = connectedUsers.get(p.userId);
            if (conn) {
              conn.ws.send(JSON.stringify({
                type: 'new_message',
                message: {
                  id: messageId,
                  conversationId,
                  senderId: userId,
                  senderName: senderName || username,
                  encryptedContent,
                  timestamp,
                  isRead: false,
                }
              }));
            }
          }

          ws.send(JSON.stringify({
            type: 'message_sent',
            message: {
              id: messageId,
              conversationId,
              senderId: userId,
              senderName: senderName || username,
              encryptedContent,
              timestamp,
              isRead: false,
            }
          }));
          break;
        }

        case 'typing': {
          if (!userId) return;
          const { conversationId, isTyping } = msg;
          const participants = db.prepare('SELECT userId FROM conversation_participants WHERE conversationId = ?').all(conversationId);
          for (const p of participants) {
            if (p.userId === userId) continue;
            const conn = connectedUsers.get(p.userId);
            if (conn) {
              conn.ws.send(JSON.stringify({
                type: 'typing',
                conversationId,
                userId: userId,
                username: username,
                isTyping,
              }));
            }
          }
          break;
        }
      }
    } catch (e) {
      console.error('WS message error:', e);
    }
  });

  ws.on('close', () => {
    if (userId) {
      connectedUsers.delete(userId);
      broadcastOnlineUsers();
    }
  });

  ws.on('error', () => {
    if (userId) {
      connectedUsers.delete(userId);
      broadcastOnlineUsers();
    }
  });
});

function broadcastOnlineUsers() {
  const online = Array.from(connectedUsers.entries()).map(([id, conn]) => ({
    userId: id,
    username: conn.username,
  }));
  const data = JSON.stringify({ type: 'online_users', users: online });
  for (const [, conn] of connectedUsers) {
    conn.ws.send(data);
  }
}

// === Start Server ===
server.listen(PORT, '0.0.0.0', () => {
  console.log(`EChat server running on port ${PORT}`);
  console.log(`WebSocket: ws://0.0.0.0:${PORT}`);
  console.log(`REST API: http://0.0.0.0:${PORT}`);
});
 // Update public key
 app.put('/api/users/public-key', authMiddleware, (req, res) => {
   const { publicKey } = req.body;
   if (!publicKey) return res.status(400).json({ error: 'Missing publicKey' });
   try {
     const stmt = db.prepare('UPDATE users SET publicKey = ? WHERE id = ?');
     stmt.run(publicKey, req.userId);
     res.json({ success: true });
   } catch (e) {
     res.status(500).json({ error: 'Failed to update public key' });
   }
 });
 
 // Update user's public key on login
