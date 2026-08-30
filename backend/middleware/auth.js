// ============================================================
// POWER FAN NETWORK
// CUSTOM JWT AUTHENTICATION MIDDLEWARE
// ============================================================
//
// Firebase Authentication: NOT USED
// Realtime Database: NOT USED
// Firestore: USED
// JWT: USED
// ============================================================

const jwt = require("jsonwebtoken");

const { getDb } = require("../src/firebase");

const JWT_SECRET =
  process.env.JWT_SECRET ||
  "CHANGE_THIS_SECRET_IN_PRODUCTION";

async function authenticate(req, res, next) {
  try {
    const authorization =
      req.headers.authorization || "";

    if (!authorization.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message:
          "Authentication token is required.",
      });
    }

    const token =
      authorization.substring(7).trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message:
          "Authentication token is required.",
      });
    }

    let decoded;

    try {
      decoded = jwt.verify(
        token,
        JWT_SECRET
      );
    } catch (error) {
      return res.status(401).json({
        success: false,
        error: "invalid_token",
        message:
          "Invalid or expired authentication token.",
      });
    }

    if (!decoded.userId) {
      return res.status(401).json({
        success: false,
        error: "invalid_token",
        message:
          "Invalid authentication token.",
      });
    }

    const db = getDb();

    if (!db) {
      return res.status(503).json({
        success: false,
        error: "database_unavailable",
        message:
          "Database is not connected.",
      });
    }

    const userRef = db
      .collection("users")
      .doc(decoded.userId);

    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        error: "user_not_found",
        message:
          "User account no longer exists.",
      });
    }

    const user = {
      id: userDoc.id,
      ...userDoc.data(),
    };

    req.user = user;
    req.userId = user.id;

    next();
  } catch (error) {
    console.error(
      "AUTHENTICATION ERROR:",
      error
    );

    return res.status(500).json({
      success: false,
      error: "authentication_server_error",
      message:
        "Authentication server error.",
    });
  }
}

function requireUser(req, res, next) {
  if (!req.user || !req.userId) {
    return res.status(401).json({
      success: false,
      error: "unauthorized",
      message:
        "Authenticated user is required.",
    });
  }

  next();
}

module.exports = {
  authenticate,
  requireUser,
};
