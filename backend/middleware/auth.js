// ============================================================
// POWER FAN NETWORK — BACKEND AUTH MIDDLEWARE
// FILE: backend/middleware/auth.js
// ============================================================

const admin = require("firebase-admin");

// ============================================================
// AUTHENTICATION
// ============================================================

async function authenticate(req, res, next) {
  try {
    const authorization =
      req.headers.authorization || "";

    if (
      !authorization ||
      !authorization.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        error: "missing_authentication",
        message: "Authentication token is required.",
      });
    }

    const token =
      authorization.substring(7).trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message: "Authentication token is required.",
      });
    }

    /*
     * Firebase Authentication is NOT being used
     * as the application's login/register system.
     *
     * This middleware only verifies a backend-issued
     * Firebase-compatible ID token when one is supplied.
     *
     * The actual application account/data remains
     * controlled by the POWER FAN NETWORK backend
     * and Firebase Realtime Database.
     */

    const decodedToken =
      await admin.auth().verifyIdToken(token);

    if (!decodedToken || !decodedToken.uid) {
      return res.status(401).json({
        success: false,
        error: "invalid_authentication",
      });
    }

    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email || "",
      name:
        decodedToken.name ||
        decodedToken.displayName ||
        "",
    };

    next();
  } catch (error) {
    console.error(
      "Authentication middleware error:",
      error.message,
    );

    return res.status(401).json({
      success: false,
      error: "invalid_authentication",
      message:
        "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// REQUIRE USER
// ============================================================

function requireUser(req, res, next) {
  if (!req.user || !req.user.uid) {
    return res.status(401).json({
      success: false,
      error: "unauthorized",
      message: "User authentication is required.",
    });
  }

  next();
}

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  authenticate,
  requireUser,
};
