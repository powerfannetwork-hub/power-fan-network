// ============================================================
// POWER FAN NETWORK — BACKEND AUTH MIDDLEWARE
// FILE: src/middleware/auth.js
// ============================================================

const crypto = require("crypto");

/**
 * POWER FAN NETWORK
 *
 * Backend-only authentication middleware.
 *
 * NOTE:
 * This middleware does NOT use Firebase Authentication.
 * It expects the backend to issue a secure session token.
 */

function hashToken(token) {
  return crypto
    .createHash("sha256")
    .update(token)
    .digest("hex");
}

/**
 * Extract Bearer token from Authorization header.
 */
function getBearerToken(req) {
  const header = req.headers.authorization;

  if (
    !header ||
    typeof header !== "string" ||
    !header.startsWith("Bearer ")
  ) {
    return null;
  }

  const token = header.substring(7).trim();

  return token || null;
}

/**
 * Backend authentication middleware.
 *
 * Expected:
 * Authorization: Bearer <session-token>
 *
 * The server.js application must provide:
 *
 * req.sessionStore = {
 *   get: async (tokenHash) => session
 * }
 *
 * Session format:
 * {
 *   uid: "...",
 *   tokenHash: "...",
 *   expiresAt: 1234567890000
 * }
 */
async function authenticate(req, res, next) {
  try {
    const token = getBearerToken(req);

    if (!token) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
        message: "Authentication token is required.",
      });
    }

    if (!req.sessionStore) {
      console.error(
        "Authentication error: sessionStore is not configured.",
      );

      return res.status(500).json({
        success: false,
        error: "authentication_service_unavailable",
      });
    }

    const tokenHash = hashToken(token);

    const session =
      await req.sessionStore.get(tokenHash);

    if (!session) {
      return res.status(401).json({
        success: false,
        error: "invalid_authentication",
        message: "Invalid authentication token.",
      });
    }

    if (
      !session.uid ||
      typeof session.uid !== "string"
    ) {
      return res.status(401).json({
        success: false,
        error: "invalid_session",
      });
    }

    const expiresAt =
      Number(session.expiresAt || 0);

    if (
      !Number.isFinite(expiresAt) ||
      expiresAt <= Date.now()
    ) {
      return res.status(401).json({
        success: false,
        error: "session_expired",
        message: "Your session has expired.",
      });
    }

    req.user = {
      uid: session.uid,
    };

    req.session = session;

    next();
  } catch (error) {
    console.error(
      "Authentication middleware error:",
      error,
    );

    return res.status(401).json({
      success: false,
      error: "invalid_authentication",
      message: "Authentication failed.",
    });
  }
}

module.exports = {
  authenticate,
  getBearerToken,
  hashToken,
};
