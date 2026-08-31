// ============================================================
// POWER FAN NETWORK
// FILE: backend/src/routes/auth_routes.js
// ============================================================
// CUSTOM AUTHENTICATION
// Database: Firestore
// Firebase Authentication: NOT USED
//
// Features:
// - Register
// - Login
// - Current user (/me)
// - Logout
// - Logout from all sessions
// - Change password
// - JWT authentication
// - bcrypt password hashing
// - Referral registration rewards
// ============================================================

const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

const router = express.Router();

// ============================================================
// CONFIG
// ============================================================

const JWT_SECRET =
  process.env.JWT_SECRET ||
  "CHANGE_THIS_SECRET_IN_PRODUCTION";

const JWT_EXPIRES_IN =
  process.env.JWT_EXPIRES_IN || "30d";

// ============================================================
// FIRESTORE
// ============================================================

let db = null;

try {
  const admin = require("firebase-admin");

  if (admin.apps.length === 0) {
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const serviceAccount = JSON.parse(
        process.env.FIREBASE_SERVICE_ACCOUNT
      );

      admin.initializeApp({
        credential: admin.credential.cert(
          serviceAccount
        ),
      });
    } else {
      admin.initializeApp();
    }
  }

  db = admin.firestore();

  console.log(
    "AUTH ROUTES: Firestore initialized."
  );
} catch (error) {
  console.error(
    "AUTH ROUTES: Firestore initialization failed:",
    error.message
  );
}

// ============================================================
// HELPERS
// ============================================================

function databaseRequired(res) {
  if (!db) {
    res.status(503).json({
      success: false,
      error: "database_unavailable",
      message: "Database is not connected.",
    });

    return false;
  }

  return true;
}

function cleanName(value) {
  return String(value || "").trim();
}

function cleanEmail(value) {
  return String(value || "")
    .trim()
    .toLowerCase();
}

function cleanReferralCode(value) {
  return String(value || "")
    .trim()
    .toUpperCase();
}

function generateUserId() {
  return (
    "user_" +
    Date.now() +
    "_" +
    Math.random()
      .toString(36)
      .substring(2, 10)
  );
}

function generateReferralCode(name) {
  const prefix = cleanName(name)
    .replace(/[^a-zA-Z0-9]/g, "")
    .toUpperCase()
    .substring(0, 5);

  const random = Math.floor(
    100000 + Math.random() * 900000
  );

  return `${prefix || "FAN"}${random}`;
}

function createToken(user) {
  return jwt.sign(
    {
      userId: user.id,
      email: user.email,
    },
    JWT_SECRET,
    {
      expiresIn: JWT_EXPIRES_IN,
    }
  );
}

function publicUser(user) {
  if (!user) {
    return null;
  }

  return {
    id: user.id || "",
    name: user.name || "",
    email: user.email || "",

    referralCode:
      user.referralCode || "",

    referredBy:
      user.referredBy || null,

    fanBalance:
      Number(user.fanBalance || 0),

    afamBalance:
      Number(user.afamBalance || 0),

    miningRate:
      Number(user.miningRate || 0.2),

    activeReferrals:
      Number(user.activeReferrals || 0),

    dailyAdsWatched:
      Number(user.dailyAdsWatched || 0),

    adBoost:
      Number(user.adBoost || 0),

    miningActive:
      Boolean(user.miningActive),

    miningStartedAt:
      user.miningStartedAt || null,

    miningEndsAt:
      user.miningEndsAt || null,

    consecutiveCheckIns:
      Number(user.consecutiveCheckIns || 0),

    kyc1Eligible:
      Boolean(user.kyc1Eligible),

    kyc1Verified:
      Boolean(user.kyc1Verified),

    kyc2Eligible:
      Boolean(user.kyc2Eligible),

    kyc2Verified:
      Boolean(user.kyc2Verified),

    kyc3Verified:
      Boolean(user.kyc3Verified),

    createdAt:
      user.createdAt || null,

    updatedAt:
      user.updatedAt || null,
  };
}

// ============================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================

async function authenticate(req, res, next) {
  try {
    if (!databaseRequired(res)) {
      return;
    }

    const authorization =
      req.headers.authorization || "";

    if (
      !authorization.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        error: "missing_token",
        message:
          "Authentication token is required.",
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

    const decoded =
      jwt.verify(token, JWT_SECRET);

    if (!decoded.userId) {
      return res.status(401).json({
        success: false,
        error: "invalid_token",
        message:
          "Invalid authentication token.",
      });
    }

    const userDoc =
      await db
        .collection("users")
        .doc(decoded.userId)
        .get();

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
    req.token = token;
    req.tokenPayload = decoded;

    next();
  } catch (error) {
    if (
      error &&
      error.name === "TokenExpiredError"
    ) {
      return res.status(401).json({
        success: false,
        error: "token_expired",
        message:
          "Your session has expired. Please login again.",
      });
    }

    console.error(
      "AUTHENTICATION ERROR:",
      error.message
    );

    return res.status(401).json({
      success: false,
      error: "invalid_token",
      message:
        "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// REGISTER
// ============================================================

router.post(
  "/register",
  async (req, res) => {
    try {
      if (!databaseRequired(res)) {
        return;
      }

      const name =
        cleanName(req.body.name);

      const email =
        cleanEmail(req.body.email);

      const password =
        String(req.body.password || "");

      const referralCode =
        cleanReferralCode(
          req.body.referralCode
        );

      // --------------------------------------------------------
      // VALIDATION
      // --------------------------------------------------------

      if (
        !name ||
        !email ||
        !password
      ) {
        return res.status(400).json({
          success: false,
          error: "missing_fields",
          message:
            "Name, email and password are required.",
        });
      }

      if (name.length < 2) {
        return res.status(400).json({
          success: false,
          error: "invalid_name",
          message:
            "Name must contain at least 2 characters.",
        });
      }

      if (name.length > 100) {
        return res.status(400).json({
          success: false,
          error: "invalid_name",
          message:
            "Name is too long.",
        });
      }

      if (
        !email.includes("@") ||
        !email.includes(".")
      ) {
        return res.status(400).json({
          success: false,
          error: "invalid_email",
          message:
            "Please enter a valid email address.",
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          success: false,
          error: "weak_password",
          message:
            "Password must contain at least 6 characters.",
        });
      }

      // --------------------------------------------------------
      // CHECK EMAIL
      // --------------------------------------------------------

      const existingUser =
        await db
          .collection("users")
          .where(
            "email",
            "==",
            email
          )
          .limit(1)
          .get();

      if (!existingUser.empty) {
        return res.status(409).json({
          success: false,
          error: "email_exists",
          message:
            "This email is already registered.",
        });
      }

      // --------------------------------------------------------
      // FIND REFERRER
      // --------------------------------------------------------

      let referrerDoc = null;

      if (referralCode) {
        const referralQuery =
          await db
            .collection("users")
            .where(
              "referralCode",
              "==",
              referralCode
            )
            .limit(1)
            .get();

        if (referralQuery.empty) {
          return res.status(400).json({
            success: false,
            error: "invalid_referral",
            message:
              "Invalid referral code.",
          });
        }

        referrerDoc =
          referralQuery.docs[0];
      }

      // --------------------------------------------------------
      // PASSWORD HASH
      // --------------------------------------------------------

      const passwordHash =
        await bcrypt.hash(
          password,
          12
        );

      // --------------------------------------------------------
      // USER DATA
      // --------------------------------------------------------

      const userId =
        generateUserId();

      const newReferralCode =
        generateReferralCode(name);

      const now =
        new Date().toISOString();

      const newUser = {
        id: userId,

        name,
        email,

        passwordHash,

        referralCode:
          newReferralCode,

        referredBy:
          referrerDoc
            ? referrerDoc.id
            : null,

        // New user receives 20 FAN
        fanBalance:
          referrerDoc ? 20 : 0,

        afamBalance: 0,

        // Base mining rate
        miningRate: 0.2,

        activeReferrals: 0,

        dailyAdsWatched: 0,

        adBoost: 0,

        miningActive: false,

        miningStartedAt: null,

        miningEndsAt: null,

        consecutiveCheckIns: 0,

        kyc1Eligible: false,

        kyc1Verified: false,

        kyc2Eligible: false,

        kyc2Verified: false,

        kyc3Verified: false,

        createdAt: now,

        updatedAt: now,
      };

      // --------------------------------------------------------
      // TRANSACTION
      // --------------------------------------------------------

      await db.runTransaction(
        async (transaction) => {
          const userRef =
            db
              .collection("users")
              .doc(userId);

          transaction.set(
            userRef,
            newUser
          );

          // ----------------------------------------------------
          // REFERRER REWARD
          // ----------------------------------------------------

          if (referrerDoc) {
            const referrerData =
              referrerDoc.data();

            const currentBalance =
              Number(
                referrerData.fanBalance || 0
              );

            const currentReferrals =
              Number(
                referrerData.activeReferrals ||
                  0
              );

            const newReferrals =
              currentReferrals + 1;

            const newMiningRate =
              0.2 +
              newReferrals * 0.02;

            transaction.update(
              referrerDoc.ref,
              {
                fanBalance:
                  currentBalance + 5,

                activeReferrals:
                  newReferrals,

                miningRate:
                  newMiningRate,

                updatedAt: now,
              }
            );
          }
        }
      );

      // --------------------------------------------------------
      // TOKEN
      // --------------------------------------------------------

      const token =
        createToken(newUser);

      return res.status(201).json({
        success: true,

        message:
          "Account created successfully.",

        token,

        user:
          publicUser(newUser),
      });
    } catch (error) {
      console.error(
        "REGISTER ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "registration_failed",
        message:
          "Registration failed. Please try again.",
      });
    }
  }
);

// ============================================================
// LOGIN
// ============================================================

router.post(
  "/login",
  async (req, res) => {
    try {
      if (!databaseRequired(res)) {
        return;
      }

      const email =
        cleanEmail(req.body.email);

      const password =
        String(req.body.password || "");

      // --------------------------------------------------------
      // VALIDATION
      // --------------------------------------------------------

      if (!email || !password) {
        return res.status(400).json({
          success: false,
          error: "missing_fields",
          message:
            "Email and password are required.",
        });
      }

      // --------------------------------------------------------
      // FIND USER
      // --------------------------------------------------------

      const query =
        await db
          .collection("users")
          .where(
            "email",
            "==",
            email
          )
          .limit(1)
          .get();

      if (query.empty) {
        return res.status(401).json({
          success: false,
          error: "invalid_credentials",
          message:
            "Incorrect email or password.",
        });
      }

      const userDoc =
        query.docs[0];

      const user = {
        id: userDoc.id,
        ...userDoc.data(),
      };

      // --------------------------------------------------------
      // PASSWORD CHECK
      // --------------------------------------------------------

      const validPassword =
        await bcrypt.compare(
          password,
          user.passwordHash || ""
        );

      if (!validPassword) {
        return res.status(401).json({
          success: false,
          error: "invalid_credentials",
          message:
            "Incorrect email or password.",
        });
      }

      // --------------------------------------------------------
      // TOKEN
      // --------------------------------------------------------

      const token =
        createToken(user);

      return res.json({
        success: true,

        message:
          "Login successful.",

        token,

        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "LOGIN ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "login_failed",
        message:
          "Login failed. Please try again.",
      });
    }
  }
);

// ============================================================
// CURRENT USER
// ============================================================

router.get(
  "/me",
  authenticate,
  async (req, res) => {
    try {
      return res.json({
        success: true,

        user:
          publicUser(req.user),
      });
    } catch (error) {
      console.error(
        "GET ME ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not load account.",
      });
    }
  }
);

// ============================================================
// LOGOUT
// ============================================================
// JWT logout is handled client-side by deleting the token.
//
// Since JWT is stateless, this endpoint confirms logout,
// while the Flutter app must remove the saved token.
// ============================================================

router.post(
  "/logout",
  authenticate,
  async (req, res) => {
    return res.json({
      success: true,
      message:
        "Logged out successfully.",
    });
  }
);

// ============================================================
// CHANGE PASSWORD
// ============================================================

router.post(
  "/change-password",
  authenticate,
  async (req, res) => {
    try {
      if (!databaseRequired(res)) {
        return;
      }

      const currentPassword =
        String(
          req.body.currentPassword || ""
        );

      const newPassword =
        String(
          req.body.newPassword || ""
        );

      if (
        !currentPassword ||
        !newPassword
      ) {
        return res.status(400).json({
          success: false,
          error: "missing_fields",
          message:
            "Current password and new password are required.",
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          error: "weak_password",
          message:
            "New password must contain at least 6 characters.",
        });
      }

      // --------------------------------------------------------
      // CHECK CURRENT PASSWORD
      // --------------------------------------------------------

      const valid =
        await bcrypt.compare(
          currentPassword,
          req.user.passwordHash || ""
        );

      if (!valid) {
        return res.status(401).json({
          success: false,
          error: "wrong_password",
          message:
            "Current password is incorrect.",
        });
      }

      // --------------------------------------------------------
      // HASH NEW PASSWORD
      // --------------------------------------------------------

      const passwordHash =
        await bcrypt.hash(
          newPassword,
          12
        );

      await db
        .collection("users")
        .doc(req.user.id)
        .update({
          passwordHash,

          updatedAt:
            new Date().toISOString(),
        });

      return res.json({
        success: true,
        message:
          "Password changed successfully.",
      });
    } catch (error) {
      console.error(
        "CHANGE PASSWORD ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        error: "password_change_failed",
        message:
          "Could not change password.",
      });
    }
  }
);

// ============================================================
// LOGOUT ALL DEVICES
// ============================================================
// With pure JWT, already-issued tokens remain valid until
// expiration unless a server-side token blacklist/session
// system is added.
//
// This endpoint is therefore intentionally limited.
// ============================================================

router.post(
  "/logout-all",
  authenticate,
  async (req, res) => {
    try {
      if (!databaseRequired(res)) {
        return;
      }

      const now =
        new Date().toISOString();

      await db
        .collection("users")
        .doc(req.user.id)
        .update({
          sessionsRevokedAt: now,
          updatedAt: now,
        });

      return res.json({
        success: true,
        message:
          "All sessions have been marked for revocation.",
      });
    } catch (error) {
      console.error(
        "LOGOUT ALL ERROR:",
        error
      );

      return res.status(500).json({
        success: false,
        message:
          "Could not logout all sessions.",
      });
    }
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  router,
  authenticate,
  publicUser,
};
