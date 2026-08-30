// ============================================================
// POWER FAN NETWORK — SESSION SERVICE
// FILE: src/services/session_service.js
// ============================================================

const crypto = require("crypto");

const SESSION_DURATION_MS =
  30 * 24 * 60 * 60 * 1000;

function generateSessionToken() {
  return crypto.randomBytes(48).toString("hex");
}

function hashSessionToken(token) {
  return crypto
    .createHash("sha256")
    .update(token)
    .digest("hex");
}

function createSession(uid) {
  if (!uid || typeof uid !== "string") {
    throw new Error("Invalid user ID.");
  }

  const token =
    generateSessionToken();

  const tokenHash =
    hashSessionToken(token);

  const createdAt =
    Date.now();

  const expiresAt =
    createdAt + SESSION_DURATION_MS;

  return {
    token,

    session: {
      uid,
      tokenHash,
      createdAt,
      expiresAt,
    },
  };
}

function isSessionExpired(session) {
  if (!session) {
    return true;
  }

  const expiresAt =
    Number(session.expiresAt || 0);

  return (
    !Number.isFinite(expiresAt) ||
    expiresAt <= Date.now()
  );
}

function sanitizeSession(session) {
  if (!session) {
    return null;
  }

  return {
    uid: session.uid,
    createdAt: session.createdAt || null,
    expiresAt: session.expiresAt || null,
  };
}

function publicSession(session) {
  if (!session) {
    return null;
  }

  return {
    createdAt: session.createdAt || null,
    expiresAt: session.expiresAt || null,
  };
}

module.exports = {
  SESSION_DURATION_MS,
  generateSessionToken,
  hashSessionToken,
  createSession,
  isSessionExpired,
  sanitizeSession,
  publicSession,
};
