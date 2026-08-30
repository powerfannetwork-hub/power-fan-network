// ============================================================
// POWER FAN NETWORK — AUTH ROUTES
// FILE: src/routes/auth_routes.js
// ============================================================

const express = require("express");
const router = express.Router();

const admin = require("firebase-admin");
const crypto = require("crypto");

const {
  createSession,
  publicSession,
} = require("../services/session_service");

const SessionStore = require("../services/session_store");

const db = admin.database();
const auth = admin.auth();

const sessionStore =
  new SessionStore(db);

const MAX_NAME_LENGTH = 80;
const MAX_EMAIL_LENGTH = 254;
const MIN_PASSWORD_LENGTH = 6;

const BASE_MINING_RATE = 0.2;

function now() {
  return Date.now();
}

function cleanString(value) {
  return String(value || "").trim();
}

function normalizeEmail(value) {
  return cleanString(value).toLowerCase();
}

function validEmail(email) {
  return (
    email.length > 3 &&
    email.length <= MAX_EMAIL_LENGTH &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  );
}

function generateReferralCode() {
  return crypto
    .randomBytes(5)
    .toString("hex")
    .toUpperCase();
}

async function generateUniqueReferralCode() {
  for (let attempt = 0; attempt < 20; attempt++) {
    const code =
      generateReferralCode();

    const snapshot =
      await db
        .ref(`referralCodes/${code}`)
        .once("value");

    if (!snapshot.exists()) {
      return code;
    }
  }

  throw new Error(
    "Unable to generate referral code.",
  );
}

function publicUser(user) {
  if (!user) {
    return null;
  }

  return {
    uid: user.uid || "",
    name: user.name || "",
    email: user.email || "",

    fanBalance:
      Number(user.fanBalance || 0),

    afamBalance:
      Number(user.afamBalance || 0),

    miningRate:
      Number(
        user.miningRate ||
          BASE_MINING_RATE,
      ),

    dailyAdCount:
      Number(user.dailyAdCount || 0),

    dailyAdBoost:
      Number(user.dailyAdBoost || 0),

    activeReferralCount:
      Number(
        user.activeReferralCount || 0,
      ),

    referralCode:
      user.referralCode || "",

    referrerUid:
      user.referrerUid || null,

    miningActive:
      user.miningActive === true,

    miningStartedAt:
      user.miningStartedAt || null,

    miningEndsAt:
      user.miningEndsAt || null,

    createdAt:
      user.createdAt || null,

    updatedAt:
      user.updatedAt || null,
  };
}

async function getUser(uid) {
  const snapshot =
    await db
      .ref(`users/${uid}`)
      .once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

async function saveUser(user) {
  await db
    .ref(`users/${user.uid}`)
    .set(user);

  await db
    .ref(
      `referralCodes/${user.referralCode}`,
    )
    .set(user.uid);
}

async function createDatabaseUser({
  uid,
  name,
  email,
}) {
  const referralCode =
    await generateUniqueReferralCode();

  const timestamp = now();

  const user = {
    uid,
    name,
    email,

    fanBalance: 0,
    afamBalance: 0,

    miningRate: BASE_MINING_RATE,

    dailyAdCount: 0,
    dailyAdBoost: 0,
    dailyAdDate:
      new Date(timestamp)
        .toISOString()
        .slice(0, 10),

    activeReferralCount: 0,

    referralCode,
    referrerUid: null,

    miningActive: false,
    miningStartedAt: null,
    miningEndsAt: null,

    createdAt: timestamp,
    updatedAt: timestamp,
  };

  await saveUser(user);

  return user;
}

// ============================================================
// REGISTER
// ============================================================

router.post(
  "/register",
  async (req, res) => {
    try {
      const name =
        cleanString(req.body.name);

      const email =
        normalizeEmail(req.body.email);

      const password =
        String(
          req.body.password || "",
        );

      if (!name) {
        return res.status(400).json({
          success: false,
          error: "name_required",
          message:
            "Name is required.",
        });
      }

      if (
        name.length >
        MAX_NAME_LENGTH
      ) {
        return res.status(400).json({
          success: false,
          error: "name_too_long",
        });
      }

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,
          error: "invalid_email",
        });
      }

      if (
        password.length <
        MIN_PASSWORD_LENGTH
      ) {
        return res.status(400).json({
          success: false,
          error: "weak_password",
          message:
            "Password must contain at least 6 characters.",
        });
      }

      // Backend-managed authentication account.
      // Firebase Authentication is not used.
      const existingEmailSnapshot =
        await db
          .ref("users")
          .orderByChild("email")
          .equalTo(email)
          .once("value");

      if (
        existingEmailSnapshot.exists()
      ) {
        return res.status(409).json({
          success: false,
          error:
            "email_already_in_use",
          message:
            "This email is already registered.",
        });
      }

      const uid =
        crypto.randomUUID();

      const passwordHash =
        crypto
          .createHash("sha256")
          .update(password)
          .digest("hex");

      const user =
        await createDatabaseUser({
          uid,
          name,
          email,
        });

      await db
        .ref(`credentials/${uid}`)
        .set({
          uid,
          email,
          passwordHash,
          createdAt: now(),
          updatedAt: now(),
        });

      const sessionData =
        createSession(uid);

      await sessionStore.create(
        sessionData.session,
      );

      return res.status(201).json({
        success: true,

        message:
          "Account created successfully.",

        token:
          sessionData.token,

        session:
          publicSession(
            sessionData.session,
          ),

        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Register error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "registration_failed",
        message:
          "Unable to create account.",
      });
    }
  },
);

// ============================================================
// LOGIN
// ============================================================

router.post(
  "/login",
  async (req, res) => {
    try {
      const email =
        normalizeEmail(req.body.email);

      const password =
        String(
          req.body.password || "",
        );

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,
          error: "invalid_email",
        });
      }

      if (!password) {
        return res.status(400).json({
          success: false,
          error: "password_required",
        });
      }

      const passwordHash =
        crypto
          .createHash("sha256")
          .update(password)
          .digest("hex");

      const credentialsSnapshot =
        await db
          .ref("credentials")
          .orderByChild("email")
          .equalTo(email)
          .once("value");

      if (
        !credentialsSnapshot.exists()
      ) {
        return res.status(401).json({
          success: false,
          error:
            "invalid_credentials",
          message:
            "Incorrect email or password.",
        });
      }

      const credentials =
        credentialsSnapshot.val();

      let credential = null;

      for (
        const item of
        Object.values(credentials)
      ) {
        if (
          item &&
          item.email === email
        ) {
          credential = item;
          break;
        }
      }

      if (
        !credential ||
        credential.passwordHash !==
          passwordHash
      ) {
        return res.status(401).json({
          success: false,
          error:
            "invalid_credentials",
          message:
            "Incorrect email or password.",
        });
      }

      const user =
        await getUser(
          credential.uid,
        );

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      const sessionData =
        createSession(
          credential.uid,
        );

      await sessionStore.create(
        sessionData.session,
      );

      await db
        .ref(
          `credentials/${credential.uid}/updatedAt`,
        )
        .set(now());

      return res.json({
        success: true,

        message:
          "Login successful.",

        token:
          sessionData.token,

        session:
          publicSession(
            sessionData.session,
          ),

        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Login error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "login_failed",
        message:
          "Unable to login.",
      });
    }
  },
);

// ============================================================
// CURRENT USER
// ============================================================

router.get(
  "/me",
  async (req, res) => {
    try {
      if (!req.user?.uid) {
        return res.status(401).json({
          success: false,
          error:
            "missing_authentication",
        });
      }

      const user =
        await getUser(
          req.user.uid,
        );

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      return res.json({
        success: true,
        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Current user error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// LOGOUT
// ============================================================

router.post(
  "/logout",
  async (req, res) => {
    try {
      if (!req.user?.uid) {
        return res.status(401).json({
          success: false,
          error:
            "missing_authentication",
        });
      }

      if (req.session?.tokenHash) {
        await sessionStore.delete(
          req.session.tokenHash,
        );
      }

      return res.json({
        success: true,
        message:
          "Logged out successfully.",
      });
    } catch (error) {
      console.error(
        "Logout error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "logout_failed",
      });
    }
  },
);

// ============================================================
// FORGOT PASSWORD
// ============================================================

router.post(
  "/forgot-password",
  async (req, res) => {
    try {
      const email =
        normalizeEmail(req.body.email);

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,
          error: "invalid_email",
        });
      }

      const credentialsSnapshot =
        await db
          .ref("credentials")
          .orderByChild("email")
          .equalTo(email)
          .once("value");

      if (
        !credentialsSnapshot.exists()
      ) {
        // Do not reveal whether the email exists.
        return res.json({
          success: true,
          message:
            "If the account exists, password recovery instructions will be sent.",
        });
      }

      const credentials =
        credentialsSnapshot.val();

      let credential = null;

      for (
        const item of
        Object.values(credentials)
      ) {
        if (
          item &&
          item.email === email
        ) {
          credential = item;
          break;
        }
      }

      if (!credential) {
        return res.json({
          success: true,
          message:
            "If the account exists, password recovery instructions will be sent.",
        });
      }

      // Password recovery delivery will be connected
      // to the production email service later.
      await db
        .ref(
          `passwordResetRequests/${credential.uid}`,
        )
        .set({
          uid: credential.uid,
          email,
          requestedAt: now(),
          status: "pending",
        });

      return res.json({
        success: true,
        message:
          "Password recovery request created.",
      });
    } catch (error) {
      console.error(
        "Forgot password error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

// ============================================================
// BOOTSTRAP
// ============================================================

router.post(
  "/bootstrap",
  async (req, res) => {
    try {
      if (!req.user?.uid) {
        return res.status(401).json({
          success: false,
          error:
            "missing_authentication",
        });
      }

      let user =
        await getUser(
          req.user.uid,
        );

      if (!user) {
        return res.status(404).json({
          success: false,
          error: "user_not_found",
        });
      }

      return res.json({
        success: true,
        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Bootstrap error:",
        error,
      );

      return res.status(500).json({
        success: false,
        error: "server_error",
      });
    }
  },
);

module.exports = router;
