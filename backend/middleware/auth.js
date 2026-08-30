// ============================================================
// POWER FAN NETWORK — BACKEND AUTH MIDDLEWARE
// FILE: backend/middleware/auth.js
// ============================================================

const crypto = require("crypto");
const admin = require("firebase-admin");

const db = admin.database();

// ============================================================
// CONFIGURATION
// ============================================================

const SESSION_DURATION_MS =
  30 * 24 * 60 * 60 * 1000;

// ============================================================
// HELPERS
// ============================================================

function createSessionToken() {
  return crypto.randomBytes(48).toString("hex");
}

function hashToken(token) {
  return crypto
    .createHash("sha256")
    .update(token)
    .digest("hex");
}

// ============================================================
// CREATE SESSION
// ============================================================

async function createSession(uid) {
  if (!uid) {
    throw new Error("User UID is required.");
  }

  const token = createSessionToken();
  const tokenHash = hashToken(token);

  const createdAt = Date.now();
  const expiresAt =
    createdAt + SESSION_DURATION_MS;

  await db.ref(`sessions/${tokenHash}`).set({
    uid,
    createdAt,
    expiresAt,
    revoked: false,
  });

  return {
    token,
    expiresAt,
  };
}

// ============================================================
// GET SESSION
// ============================================================

async function getSession(token) {
  if (!token) {
    return null;
  }

  const tokenHash = hashToken(token);

  const snapshot =
    await db
      .ref(`sessions/${tokenHash}`)
      .once("value");

  if (!snapshot.exists()) {
    return null;
  }

  const session = snapshot.val();

  if (session.revoked === true) {
    return null;
  }

  if (
    Number(session.expiresAt || 0) <=
    Date.now()
  ) {
    await db
      .ref(`sessions/${tokenHash}`)
      .remove();

    return null;
  }

  return {
    ...session,
    tokenHash,
  };
}

// ============================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================

async function authenticate(req, res, next) {
  try {
    const authorization =
      req.headers.authorization || "";

    if (
      !authorization.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
        message:
          "Backend authentication token is required.",
      });
    }

    const token =
      authorization
        .substring(7)
        .trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message:
          "Authentication token is required.",
      });
    }

    const session =
      await getSession(token);

    if (!session) {
      return res.status(401).json({
        success: false,
        error: "invalid_session",
        message:
          "Invalid, expired, or revoked session.",
      });
    }

    const userSnapshot =
      await db
        .ref(`users/${session.uid}`)
        .once("value");

    if (!userSnapshot.exists()) {
      return res.status(401).json({
        success: false,
        error: "user_not_found",
      });
    }

    const user =
      userSnapshot.val();

    req.user = {
      uid: session.uid,
      name: user.name || "",
      email: user.email || "",
    };

    req.session = {
      tokenHash: session.tokenHash,
      createdAt: session.createdAt,
      expiresAt: session.expiresAt,
    };

    req.userData = user;

    next();
  } catch (error) {
    console.error(
      "Backend authentication error:",
      error,
    );

    return res.status(500).json({
      success: false,
      error:
        "authentication_server_error",
    });
  }
}

// ============================================================
// REQUIRE USER
// ============================================================

function requireUser(req, res, next) {
  if (
    !req.user ||
    !req.user.uid
  ) {
    return res.status(401).json({
      success: false,
      error: "unauthorized",
      message:
        "Authenticated user is required.",
    });
  }

  next();
}

// ============================================================
// REVOKE CURRENT SESSION
// ============================================================

async function revokeSession(token) {
  if (!token) {
    return false;
  }

  const tokenHash =
    hashToken(token);

  const sessionRef =
    db.ref(`sessions/${tokenHash}`);

  const snapshot =
    await sessionRef.once("value");

  if (!snapshot.exists()) {
    return false;
  }

  await sessionRef.update({
    revoked: true,
    revokedAt: Date.now(),
  });

  return true;
}

// ============================================================
// REVOKE ALL USER SESSIONS
// ============================================================

async function revokeAllUserSessions(uid) {
  if (!uid) {
    return;
  }

  const snapshot =
    await db
      .ref("sessions")
      .once("value");

  if (!snapshot.exists()) {
    return;
  }

  const sessions =
    snapshot.val();

  const updates = {};

  for (const [tokenHash, session] of
    Object.entries(sessions)) {
    if (
      session &&
      session.uid === uid
    ) {
      updates[
        `sessions/${tokenHash}/revoked`
      ] = true;

      updates[
        `sessions/${tokenHash}/revokedAt`
      ] = Date.now();
    }
  }

  if (Object.keys(updates).length > 0) {
    await db.ref().update(updates);
  }
}

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  authenticate,
  requireUser,
  createSession,
  getSession,
  revokeSession,
  revokeAllUserSessions,
};
