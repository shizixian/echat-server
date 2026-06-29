const Database = require('better-sqlite3');
const path = require('path');

const DB_PATH = path.join(__dirname, 'echat.db');
let db;

function initDB() {
  db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE NOT NULL,
      display_name TEXT,
      public_key TEXT NOT NULL,
      created_at INTEGER NOT NULL DEFAULT (unixepoch())
    );
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      sender_id TEXT NOT NULL,
      recipient_id TEXT NOT NULL,
      ciphertext TEXT NOT NULL,
      nonce TEXT NOT NULL,
      iv TEXT,
      ephemeral_key TEXT,
      mac TEXT,
      created_at INTEGER NOT NULL DEFAULT (unixepoch()),
      FOREIGN KEY (sender_id) REFERENCES users(id),
      FOREIGN KEY (recipient_id) REFERENCES users(id)
    );
    CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
    CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
  `);
  return db;
}

function registerUser(id, username, displayName, publicKey) {
  const stmt = db.prepare('INSERT OR IGNORE INTO users (id, username, display_name, public_key) VALUES (?, ?, ?, ?)');
  stmt.run(id, username, displayName, publicKey);
  return getUserById(id);
}

function getUserById(id) {
  return db.prepare('SELECT id, username, display_name, public_key, created_at FROM users WHERE id = ?').get(id);
}

function getUserByUsername(username) {
  return db.prepare('SELECT id, username, display_name, public_key, created_at FROM users WHERE username = ?').get(username);
}

function listUsers(excludeId) {
  return db.prepare('SELECT id, username, display_name, public_key, created_at FROM users WHERE id != ? ORDER BY username').all(excludeId);
}

function saveMessage(id, senderId, recipientId, ciphertext, nonce, iv, ephemeralKey, mac) {
  const stmt = db.prepare('INSERT INTO messages (id, sender_id, recipient_id, ciphertext, nonce, iv, ephemeral_key, mac) VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
  stmt.run(id, senderId, recipientId, ciphertext, nonce, iv, ephemeralKey, mac);
}

function getMessages(userId, limit = 50) {
  return db.prepare(`SELECT m.*, u.username as sender_username, u.display_name as sender_display_name FROM messages m JOIN users u ON m.sender_id = u.id WHERE m.recipient_id = ? ORDER BY m.created_at DESC LIMIT ?`).all(userId, limit);
}

function getConversation(userId1, userId2, limit = 50) {
  return db.prepare(`SELECT m.*, u.username as sender_username, u.display_name as sender_display_name FROM messages m JOIN users u ON m.sender_id = u.id WHERE (m.sender_id = ? AND m.recipient_id = ?) OR (m.sender_id = ? AND m.recipient_id = ?) ORDER BY m.created_at DESC LIMIT ?`).all(userId1, userId2, userId2, userId1, limit);
}

function closeDB() { if (db) db.close(); }

module.exports = { initDB, registerUser, getUserById, getUserByUsername, listUsers, saveMessage, getMessages, getConversation, closeDB };
