// ============================================================
// POWER FAN NETWORK — PRODUCTION BACKEND
// FILE: src/server.js
//
// IMPORTANT ARCHITECTURE
// ------------------------------------------------------------
// Firebase Authentication is NOT used.
//
// Authentication:
//   Flutter -> POWER FAN NETWORK Backend -> Session Token
//
// Database:
//   POWER FAN NETWORK Backend -> Firebase Realtime Database
//
// Mining / balances / rewards:
//   Backend is the source of truth.
//
// Flutter is NOT trusted to calculate FAN rewards.
// ============================================================

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const admin = require("firebase-admin");
const crypto = require("crypto");

const app = express();

const PORT = Number(process.env.PORT || 3000);

// ============================================================
// FIREBASE DATABASE CONFIG
// ============================================================

const projectId = process.env.FIREBASE_PROJECT_ID;
const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
const privateKey = process.env.FIREBASE_PRIVATE_KEY;

if (!projectId || !clientEmail || !privateKey) {
  console.error(
    "Missing Firebase environment variables: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY",
  );

  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert({
    projectId,
    clientEmail,
    privateKey: privateKey.replace(/\\n/g, "\n"),
  }),

  databaseURL:
    process.env.FIREBASE_DATABASE_URL ||
    `https://${projectId}-default-rtdb.firebaseio.com`,
});

const db = admin.database();

// ============================================================
// CONFIGURATION
// ============================================================

const CONFIG = {
  appName: "POWER FAN NETWORK",
  version: "1.0.0",

  miningCoin: "FAN",
  originalCoin: "AFAM",

  // ----------------------------------------------------------
  // MINING
  // ----------------------------------------------------------

  baseMiningRate: 0.2,

  miningSessionHours: 24,

  // ----------------------------------------------------------
  // ADS
  // ----------------------------------------------------------

  adBoostPerAd: 0.1,

  maximumDailyAds: 7,

  maximumAdBoost: 0.7,

  // IMPORTANT:
  // There is NO maximum mining rate.
  // Referral bonuses can continue indefinitely.
  // ----------------------------------------------------------

  // ----------------------------------------------------------
  // REFERRALS
  // ----------------------------------------------------------

  newUserReferralReward: 20,

  inviterReferralReward: 5,

  activeReferralMiningBonus: 0.02,

  // NO maximum referral count.
  // NO maximum referral mining bonus.
  // ----------------------------------------------------------

  // ----------------------------------------------------------
  // SOCIAL TASK
  // ----------------------------------------------------------

  dailySocialReward: 10,

  // ----------------------------------------------------------
  // SECURITY
  // ----------------------------------------------------------

  maximumNameLength: 80,

  maximumEmailLength: 254,

  minimumPasswordLength: 8,

  accessTokenDays: 30,

  refreshTokenDays: 90,

  passwordResetTokenMinutes: 30,

  // ----------------------------------------------------------
  // RATE LIMITS
  // ----------------------------------------------------------

  loginWindowMs: 15 * 60 * 1000,

  loginMaxAttempts: 10,

  registerWindowMs: 15 * 60 * 1000,

  registerMaxAttempts: 10,

  generalWindowMs: 60 * 1000,

  generalMaxRequests: 120,
};

// ============================================================
// MIDDLEWARE
// ============================================================

app.disable("x-powered-by");

app.use(
  helmet({
    crossOriginResourcePolicy: false,
  }),
);

app.use(
  cors({
    origin: true,

    methods: [
      "GET",
      "POST",
      "PUT",
      "PATCH",
      "DELETE",
      "OPTIONS",
    ],

    allowedHeaders: [
      "Content-Type",
      "Authorization",
    ],
  }),
);

app.use(
  express.json({
    limit: "1mb",
  }),
);

app.use(
  rateLimit({
    windowMs: CONFIG.generalWindowMs,
    limit: CONFIG.generalMaxRequests,

    standardHeaders: "draft-7",

    legacyHeaders: false,

    message: {
      success: false,
      error: "too_many_requests",
      message:
        "Too many requests. Please try again later.",
    },
  }),
);

// ============================================================
// AUTH RATE LIMITERS
// ============================================================

const loginLimiter = rateLimit({
  windowMs: CONFIG.loginWindowMs,

  limit: CONFIG.loginMaxAttempts,

  standardHeaders: "draft-7",

  legacyHeaders: false,

  message: {
    success: false,
    error: "too_many_login_attempts",
    message:
      "Too many login attempts. Please try again later.",
  },
});

const registerLimiter = rateLimit({
  windowMs: CONFIG.registerWindowMs,

  limit: CONFIG.registerMaxAttempts,

  standardHeaders: "draft-7",

  legacyHeaders: false,

  message: {
    success: false,
    error: "too_many_registration_attempts",
    message:
      "Too many registration attempts. Please try again later.",
  },
});

// ============================================================
// HELPERS
// ============================================================

function now() {
  return Date.now();
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function cleanString(value) {
  return String(value ?? "").trim();
}

function normalizeEmail(value) {
  return cleanString(value).toLowerCase();
}

function validEmail(email) {
  return (
    email.length > 3 &&
    email.length <= CONFIG.maximumEmailLength &&
    /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  );
}

function safeNumber(value, fallback = 0) {
  const number = Number(value);

  return Number.isFinite(number)
    ? number
    : fallback;
}

function safeInteger(value, fallback = 0) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return fallback;
  }

  return Math.floor(number);
}

function generateReferralCode() {
  return crypto
    .randomBytes(5)
    .toString("hex")
    .toUpperCase();
}

function generateToken(bytes = 32) {
  return crypto
    .randomBytes(bytes)
    .toString("hex");
}

function hashToken(token) {
  return crypto
    .createHash("sha256")
    .update(token)
    .digest("hex");
}

function timingSafeEqualStrings(a, b) {
  const first = Buffer.from(String(a));
  const second = Buffer.from(String(b));

  if (first.length !== second.length) {
    return false;
  }

  return crypto.timingSafeEqual(
    first,
    second,
  );
}

// ============================================================
// PASSWORD HASHING
// ============================================================

function hashPassword(password) {
  const salt = crypto
    .randomBytes(16)
    .toString("hex");

  const derivedKey =
    crypto.scryptSync(
      password,
      salt,
      64,
    );

  return `scrypt:${salt}:${derivedKey.toString(
    "hex",
  )}`;
}

function verifyPassword(
  password,
  storedHash,
) {
  try {
    const parts =
      String(storedHash).split(":");

    if (
      parts.length !== 3 ||
      parts[0] !== "scrypt"
    ) {
      return false;
    }

    const salt = parts[1];

    const storedKey =
      Buffer.from(parts[2], "hex");

    const derivedKey =
      crypto.scryptSync(
        password,
        salt,
        64,
      );

    if (
      storedKey.length !==
      derivedKey.length
    ) {
      return false;
    }

    return crypto.timingSafeEqual(
      storedKey,
      derivedKey,
    );
  } catch (error) {
    console.error(
      "Password verification error:",
      error.message,
    );

    return false;
  }
}

// ============================================================
// MINING CALCULATION
// ============================================================
//
// IMPORTANT:
// Referral bonus has NO LIMIT.
//
// Example:
//
// 0 referrals
// 0.20 FAN/H
//
// 1 referral
// 0.22 FAN/H
//
// 100 referrals
// 2.20 FAN/H
//
// 1000 referrals
// 20.20 FAN/H
//
// Ads add up to +0.70 FAN/H.
//
// There is NO maximumMiningRate.
// ============================================================

function calculateMiningRate(user) {
  const referrals = Math.max(
    0,
    safeInteger(
      user.activeReferralCount,
    ),
  );

  const adBoost = Math.min(
    CONFIG.maximumAdBoost,
    Math.max(
      0,
      safeNumber(
        user.dailyAdBoost,
      ),
    ),
  );

  const referralBoost =
    referrals *
    CONFIG.activeReferralMiningBonus;

  const total =
    CONFIG.baseMiningRate +
    referralBoost +
    adBoost;

  return Number(
    total.toFixed(8),
  );
}

// ============================================================
// PUBLIC USER
// ============================================================

function publicUser(user) {
  if (!user) {
    return null;
  }

  return {
    uid: user.uid,

    name:
      user.name || "",

    email:
      user.email || "",

    fanBalance:
      safeNumber(
        user.fanBalance,
      ),

    afamBalance:
      safeNumber(
        user.afamBalance,
      ),

    miningRate:
      calculateMiningRate(user),

    dailyAdCount:
      safeNumber(
        user.dailyAdCount,
      ),

    dailyAdBoost:
      safeNumber(
        user.dailyAdBoost,
      ),

    activeReferralCount:
      safeNumber(
        user.activeReferralCount,
      ),

    referralCode:
      user.referralCode || "",

    referrerUid:
      user.referrerUid || null,

    miningActive:
      user.miningActive === true,

    miningStartedAt:
      user.miningStartedAt ||
      null,

    miningEndsAt:
      user.miningEndsAt ||
      null,

    createdAt:
      user.createdAt ||
      null,

    updatedAt:
      user.updatedAt ||
      null,
  };
}

// ============================================================
// DATABASE HELPERS
// ============================================================

async function getUser(uid) {
  const snapshot =
    await db
      .ref(`users/${uid}`)
      .once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

async function createUniqueReferralCode() {
  for (
    let attempt = 0;
    attempt < 20;
    attempt++
  ) {
    const candidate =
      generateReferralCode();

    const snapshot =
      await db
        .ref(
          `referralCodes/${candidate}`,
        )
        .once("value");

    if (!snapshot.exists()) {
      return candidate;
    }
  }

  throw new Error(
    "Unable to generate unique referral code.",
  );
}

// ============================================================
// SESSION AUTHENTICATION
// ============================================================
//
// Backend authentication:
//
// Flutter sends:
//
// Authorization: Bearer <session-token>
//
// We hash the token before storing it in Firebase.
// ============================================================

async function createSession(
  uid,
  type,
  durationMs,
) {
  const rawToken =
    generateToken(48);

  const tokenHash =
    hashToken(rawToken);

  const createdAt =
    now();

  const expiresAt =
    createdAt +
    durationMs;

  await db
    .ref(`sessions/${tokenHash}`)
    .set({
      uid,
      type,
      createdAt,
      expiresAt,
      lastUsedAt: createdAt,
    });

  return {
    token: rawToken,
    expiresAt,
  };
}

async function getSessionFromToken(
  token,
) {
  const tokenHash =
    hashToken(token);

  const snapshot =
    await db
      .ref(`sessions/${tokenHash}`)
      .once("value");

  if (!snapshot.exists()) {
    return null;
  }

  const session =
    snapshot.val();

  if (
    safeNumber(
      session.expiresAt,
    ) <= now()
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

async function revokeSession(token) {
  if (!token) {
    return;
  }

  const tokenHash =
    hashToken(token);

  await db
    .ref(`sessions/${tokenHash}`)
    .remove();
}

// ============================================================
// AUTHENTICATION MIDDLEWARE
// ============================================================

async function authenticate(
  req,
  res,
  next,
) {
  try {
    const header =
      req.headers.authorization;

    if (
      !header ||
      !header.startsWith("Bearer ")
    ) {
      return res.status(401).json({
        success: false,
        error:
          "missing_authentication",
        message:
          "Backend session token is required.",
      });
    }

    const token =
      header.substring(7).trim();

    if (!token) {
      return res.status(401).json({
        success: false,
        error:
          "missing_token",
      });
    }

    const session =
      await getSessionFromToken(
        token,
      );

    if (!session) {
      return res.status(401).json({
        success: false,
        error:
          "invalid_or_expired_session",
        message:
          "Your session is invalid or expired. Please login again.",
      });
    }

    const user =
      await getUser(
        session.uid,
      );

    if (!user) {
      await db
        .ref(
          `sessions/${session.tokenHash}`,
        )
        .remove();

      return res.status(401).json({
        success: false,
        error:
          "user_not_found",
      });
    }

    await db
      .ref(
        `sessions/${session.tokenHash}/lastUsedAt`,
      )
      .set(now());

    req.user = user;

    req.session = {
      ...session,
      rawToken: token,
    };

    next();
  } catch (error) {
    console.error(
      "Authentication error:",
      error,
    );

    return res.status(401).json({
      success: false,
      error:
        "authentication_failed",
    });
  }
}

// ============================================================
// ROOT
// ============================================================

app.get(
  "/",
  (req, res) => {
    res.json({
      success: true,

      app:
        CONFIG.appName,

      version:
        CONFIG.version,

      status:
        "running",
    });
  },
);

// ============================================================
// HEALTH
// ============================================================

app.get(
  "/health",
  async (req, res) => {
    try {
      await db
        .ref(".info/connected")
        .once("value");

      return res.json({
        success: true,

        status:
          "ok",

        service:
          "POWER FAN NETWORK Backend",

        database:
          "Firebase Realtime Database",

        authentication:
          "POWER FAN NETWORK Backend",

        firebaseAuthentication:
          false,

        time:
          new Date().toISOString(),
      });
    } catch (error) {
      return res.status(503).json({
        success: false,

        status:
          "degraded",

        database:
          "unavailable",

        error:
          "database_connection_failed",
      });
    }
  },
);

// ============================================================
// API STATUS
// ============================================================

app.get(
  "/api/status",
  (req, res) => {
    res.json({
      success: true,

      app:
        CONFIG.appName,

      backend:
        true,

      database:
        "Firebase Realtime Database",

      authentication:
        "POWER FAN NETWORK Backend",

      firebaseAuthentication:
        false,

      status:
        "online",

      time:
        new Date().toISOString(),
    });
  },
);

// ============================================================
// AUTH — REGISTER
// ============================================================

app.post(
  "/api/auth/register",
  registerLimiter,

  async (req, res) => {
    try {
      const name =
        cleanString(
          req.body.name,
        );

      const email =
        normalizeEmail(
          req.body.email,
        );

      const password =
        String(
          req.body.password || "",
        );

      // --------------------------------------------------------
      // VALIDATION
      // --------------------------------------------------------

      if (!name) {
        return res.status(400).json({
          success: false,
          error:
            "name_required",

          message:
            "Name is required.",
        });
      }

      if (
        name.length >
        CONFIG.maximumNameLength
      ) {
        return res.status(400).json({
          success: false,

          error:
            "name_too_long",
        });
      }

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,

          error:
            "invalid_email",
        });
      }

      if (
        password.length <
        CONFIG.minimumPasswordLength
      ) {
        return res.status(400).json({
          success: false,

          error:
            "weak_password",

          message:
            `Password must contain at least ${CONFIG.minimumPasswordLength} characters.`,
        });
      }

      // --------------------------------------------------------
      // CHECK EXISTING EMAIL
      // --------------------------------------------------------

      const emailIndexSnapshot =
        await db
          .ref(
            `emailIndex/${encodeURIComponent(
              email,
            )}`,
          )
          .once("value");

      if (
        emailIndexSnapshot.exists()
      ) {
        return res.status(409).json({
          success: false,

          error:
            "email_already_in_use",

          message:
            "This email is already registered.",
        });
      }

      // --------------------------------------------------------
      // UID
      // --------------------------------------------------------

      const uid =
        crypto
          .randomBytes(16)
          .toString("hex");

      // --------------------------------------------------------
      // REFERRAL CODE
      // --------------------------------------------------------

      const referralCode =
        await createUniqueReferralCode();

      const timestamp =
        now();

      // --------------------------------------------------------
      // PASSWORD HASH
      // --------------------------------------------------------

      const passwordHash =
        hashPassword(password);

      // --------------------------------------------------------
      // USER
      // --------------------------------------------------------

      const user = {
        uid,

        name,

        email,

        passwordHash,

        fanBalance: 0,

        afamBalance: 0,

        miningRate:
          CONFIG.baseMiningRate,

        dailyAdCount: 0,

        dailyAdBoost: 0,

        dailyAdDate:
          todayKey(),

        activeReferralCount: 0,

        referralCode,

        referrerUid:
          null,

        miningActive:
          false,

        miningStartedAt:
          null,

        miningEndsAt:
          null,

        miningSessionRate:
          null,

        miningSessionStartedAt:
          null,

        miningSessionEndsAt:
          null,

        createdAt:
          timestamp,

        updatedAt:
          timestamp,
      };

      // --------------------------------------------------------
      // DATABASE WRITE
      // --------------------------------------------------------

      const updates = {};

      updates[
        `users/${uid}`
      ] = user;

      updates[
        `referralCodes/${referralCode}`
      ] = uid;

      updates[
        `emailIndex/${encodeURIComponent(
          email,
        )}`
      ] = uid;

      await db
        .ref()
        .update(updates);

      // --------------------------------------------------------
      // SESSION
      // --------------------------------------------------------

      const accessSession =
        await createSession(
          uid,

          "access",

          CONFIG.accessTokenDays *
            24 *
            60 *
            60 *
            1000,
        );

      const refreshSession =
        await createSession(
          uid,

          "refresh",

          CONFIG.refreshTokenDays *
            24 *
            60 *
            60 *
            1000,
        );

      // --------------------------------------------------------
      // RESPONSE
      // --------------------------------------------------------

      return res.status(201).json({
        success: true,

        message:
          "Account created successfully.",

        token:
          accessSession.token,

        refreshToken:
          refreshSession.token,

        expiresAt:
          accessSession.expiresAt,

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

        error:
          "registration_failed",

        message:
          "Registration failed.",
      });
    }
  },
);

// ============================================================
// AUTH — LOGIN
// ============================================================

app.post(
  "/api/auth/login",
  loginLimiter,

  async (req, res) => {
    try {
      const email =
        normalizeEmail(
          req.body.email,
        );

      const password =
        String(
          req.body.password || "",
        );

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,

          error:
            "invalid_email",
        });
      }

      if (!password) {
        return res.status(400).json({
          success: false,

          error:
            "password_required",
        });
      }

      const emailIndexSnapshot =
        await db
          .ref(
            `emailIndex/${encodeURIComponent(
              email,
            )}`,
          )
          .once("value");

      if (
        !emailIndexSnapshot.exists()
      ) {
        return res.status(401).json({
          success: false,

          error:
            "invalid_credentials",

          message:
            "Incorrect email or password.",
        });
      }

      const uid =
        emailIndexSnapshot.val();

      const user =
        await getUser(uid);

      if (!user) {
        return res.status(401).json({
          success: false,

          error:
            "invalid_credentials",
        });
      }

      const passwordValid =
        verifyPassword(
          password,

          user.passwordHash,
        );

      if (!passwordValid) {
        return res.status(401).json({
          success: false,

          error:
            "invalid_credentials",

          message:
            "Incorrect email or password.",
        });
      }

      // --------------------------------------------------------
      // RESET DAILY AD COUNTER IF NECESSARY
      // --------------------------------------------------------

      const currentDate =
        todayKey();

      if (
        user.dailyAdDate !==
        currentDate
      ) {
        user.dailyAdDate =
          currentDate;

        user.dailyAdCount =
          0;

        user.dailyAdBoost =
          0;

        user.miningRate =
          calculateMiningRate(
            user,
          );

        user.updatedAt =
          now();

        await db
          .ref(`users/${uid}`)
          .update({
            dailyAdDate:
              currentDate,

            dailyAdCount:
              0,

            dailyAdBoost:
              0,

            miningRate:
              user.miningRate,

            updatedAt:
              user.updatedAt,
          });
      }

      const accessSession =
        await createSession(
          uid,

          "access",

          CONFIG.accessTokenDays *
            24 *
            60 *
            60 *
            1000,
        );

      const refreshSession =
        await createSession(
          uid,

          "refresh",

          CONFIG.refreshTokenDays *
            24 *
            60 *
            60 *
            1000,
        );

      return res.json({
        success: true,

        message:
          "Login successful.",

        token:
          accessSession.token,

        refreshToken:
          refreshSession.token,

        expiresAt:
          accessSession.expiresAt,

        expiresIn:
          Math.floor(
            CONFIG.accessTokenDays *
              24 *
              60 *
              60,
          ).toString(),

        user:
          publicUser(
            user,
          ),
      });
    } catch (error) {
      console.error(
        "Login error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "login_failed",
      });
    }
  },
);

// ============================================================
// AUTH — REFRESH SESSION
// ============================================================

app.post(
  "/api/auth/refresh",
  async (req, res) => {
    try {
      const refreshToken =
        cleanString(
          req.body.refreshToken,
        );

      if (!refreshToken) {
        return res.status(401).json({
          success: false,

          error:
            "refresh_token_required",
        });
      }

      const session =
        await getSessionFromToken(
          refreshToken,
        );

      if (
        !session ||
        session.type !==
          "refresh"
      ) {
        return res.status(401).json({
          success: false,

          error:
            "invalid_refresh_token",
        });
      }

      const user =
        await getUser(
          session.uid,
        );

      if (!user) {
        await revokeSession(
          refreshToken,
        );

        return res.status(401).json({
          success: false,

          error:
            "user_not_found",
        });
      }

      const accessSession =
        await createSession(
          user.uid,

          "access",

          CONFIG.accessTokenDays *
            24 *
            60 *
            60 *
            1000,
        );

      return res.json({
        success: true,

        token:
          accessSession.token,

        expiresAt:
          accessSession.expiresAt,

        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Refresh error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "refresh_failed",
      });
    }
  },
);

// ============================================================
// AUTH — FORGOT PASSWORD
// ============================================================
//
// This endpoint creates a secure password-reset request.
//
// IMPORTANT:
// An email delivery provider is intentionally NOT hard-coded
// into this backend. The actual delivery system can later be
// connected without changing the account/database architecture.
//
// For security, the API does not reveal whether an email exists.
// ============================================================

app.post(
  "/api/auth/forgot-password",

  async (req, res) => {
    try {
      const email =
        normalizeEmail(
          req.body.email,
        );

      if (!validEmail(email)) {
        return res.status(400).json({
          success: false,

          error:
            "invalid_email",
        });
      }

      const emailIndexSnapshot =
        await db
          .ref(
            `emailIndex/${encodeURIComponent(
              email,
            )}`,
          )
          .once("value");

      // Always return the same public response.
      if (
        !emailIndexSnapshot.exists()
      ) {
        return res.json({
          success: true,

          message:
            "If the account exists, password reset instructions will be sent.",
        });
      }

      const uid =
        emailIndexSnapshot.val();

      const resetToken =
        generateToken(48);

      const resetTokenHash =
        hashToken(resetToken);

      const createdAt =
        now();

      const expiresAt =
        createdAt +
        CONFIG.passwordResetTokenMinutes *
          60 *
          1000;

      await db
        .ref(
          `passwordResetTokens/${resetTokenHash}`,
        )
        .set({
          uid,

          createdAt,

          expiresAt,

          used: false,
        });

      // Do not expose the reset token in a production
      // response. A future email/SMS delivery provider
      // should send it to the user.
      //
      // We intentionally return only a generic response.
      return res.json({
        success: true,

        message:
          "If the account exists, password reset instructions will be sent.",
      });
    } catch (error) {
      console.error(
        "Forgot password error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "password_reset_request_failed",
      });
    }
  },
);

// ============================================================
// AUTH — RESET PASSWORD
// ============================================================

app.post(
  "/api/auth/reset-password",

  async (req, res) => {
    try {
      const token =
        cleanString(
          req.body.token,
        );

      const newPassword =
        String(
          req.body.password || "",
        );

      if (!token) {
        return res.status(400).json({
          success: false,

          error:
            "reset_token_required",
        });
      }

      if (
        newPassword.length <
        CONFIG.minimumPasswordLength
      ) {
        return res.status(400).json({
          success: false,

          error:
            "weak_password",

          message:
            `Password must contain at least ${CONFIG.minimumPasswordLength} characters.`,
        });
      }

      const tokenHash =
        hashToken(token);

      const resetRef =
        db.ref(
          `passwordResetTokens/${tokenHash}`,
        );

      const snapshot =
        await resetRef.once(
          "value",
        );

      if (!snapshot.exists()) {
        return res.status(400).json({
          success: false,

          error:
            "invalid_reset_token",
        });
      }

      const reset =
        snapshot.val();

      if (
        reset.used === true
      ) {
        return res.status(400).json({
          success: false,

          error:
            "reset_token_already_used",
        });
      }

      if (
        safeNumber(
          reset.expiresAt,
        ) <= now()
      ) {
        await resetRef.remove();

        return res.status(400).json({
          success: false,

          error:
            "reset_token_expired",
        });
      }

      const passwordHash =
        hashPassword(
          newPassword,
        );

      await db
        .ref(
          `users/${reset.uid}/passwordHash`,
        )
        .set(passwordHash);

      await db
        .ref(
          `users/${reset.uid}/updatedAt`,
        )
        .set(now());

      await resetRef.update({
        used: true,

        usedAt:
          now(),
      });

      // Revoke all sessions for this user.
      const sessionsSnapshot =
        await db
          .ref("sessions")
          .orderByChild("uid")
          .equalTo(reset.uid)
          .once("value");

      const sessions =
        sessionsSnapshot.val() ||
        {};

      const sessionDeletes = {};

      Object.keys(
        sessions,
      ).forEach((sessionHash) => {
        sessionDeletes[
          `sessions/${sessionHash}`
        ] = null;
      });

      if (
        Object.keys(
          sessionDeletes,
        ).length >
        0
      ) {
        await db
          .ref()
          .update(
            sessionDeletes,
          );
      }

      return res.json({
        success: true,

        message:
          "Password reset successfully. Please login again.",
      });
    } catch (error) {
      console.error(
        "Reset password error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "password_reset_failed",
      });
    }
  },
);

// ============================================================
// AUTH — CURRENT USER
// ============================================================

app.get(
  "/api/auth/me",

  authenticate,

  async (req, res) => {
    try {
      return res.json({
        success: true,

        user:
          publicUser(
            req.user,
          ),
      });
    } catch (error) {
      console.error(
        "Auth me error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// USER BOOTSTRAP
// ============================================================

app.post(
  "/api/user/bootstrap",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      let user =
        await getUser(uid);

      if (!user) {
        const referralCode =
          await createUniqueReferralCode();

        const timestamp =
          now();

        user = {
          uid,

          name:
            req.user.name ||
            "",

          email:
            req.user.email ||
            "",

          passwordHash:
            null,

          fanBalance:
            0,

          afamBalance:
            0,

          miningRate:
            CONFIG.baseMiningRate,

          dailyAdCount:
            0,

          dailyAdBoost:
            0,

          dailyAdDate:
            todayKey(),

          activeReferralCount:
            0,

          referralCode,

          referrerUid:
            null,

          miningActive:
            false,

          miningStartedAt:
            null,

          miningEndsAt:
            null,

          miningSessionRate:
            null,

          miningSessionStartedAt:
            null,

          miningSessionEndsAt:
            null,

          createdAt:
            timestamp,

          updatedAt:
            timestamp,
        };

        const updates = {};

        updates[
          `users/${uid}`
        ] = user;

        updates[
          `referralCodes/${referralCode}`
        ] = uid;

        if (user.email) {
          updates[
            `emailIndex/${encodeURIComponent(
              user.email,
            )}`
          ] = uid;
        }

        await db
          .ref()
          .update(updates);
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

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// USER PROFILE
// ============================================================

app.get(
  "/api/user/profile",

  authenticate,

  async (req, res) => {
    try {
      const user =
        await getUser(
          req.user.uid,
        );

      if (!user) {
        return res.status(404).json({
          success: false,

          error:
            "user_not_found",
        });
      }

      return res.json({
        success: true,

        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Profile error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// MINING CONFIG
// ============================================================

app.get(
  "/api/mining/config",

  (req, res) => {
    res.json({
      success: true,

      coin:
        CONFIG.miningCoin,

      baseMiningRate:
        CONFIG.baseMiningRate,

      adBoostPerAd:
        CONFIG.adBoostPerAd,

      maximumDailyAds:
        CONFIG.maximumDailyAds,

      maximumAdBoost:
        CONFIG.maximumAdBoost,

      activeReferralMiningBonus:
        CONFIG.activeReferralMiningBonus,

      maximumMiningRate:
        null,

      miningSessionHours:
        CONFIG.miningSessionHours,

      referralMiningRateIsUnlimited:
        true,
    });
  },
);

// ============================================================
// REFERRAL CONFIG
// ============================================================

app.get(
  "/api/referral/config",

  (req, res) => {
    res.json({
      success: true,

      newUserReward:
        CONFIG.newUserReferralReward,

      inviterReward:
        CONFIG.inviterReferralReward,

      miningRatePerActiveReferral:
        CONFIG.activeReferralMiningBonus,

      maximumActiveReferrals:
        null,

      referralMiningBonusLimit:
        null,
    });
  },
);

// ============================================================
// SOCIAL CONFIG
// ============================================================

app.get(
  "/api/social/config",

  (req, res) => {
    res.json({
      success: true,

      dailyReward:
        CONFIG.dailySocialReward,

      coin:
        CONFIG.miningCoin,
    });
  },
);

// ============================================================
// ADS — CLAIM
// ============================================================
//
// IMPORTANT:
// This endpoint records an ad reward request.
//
// For production AdMob usage, Flutter should NOT be trusted
// merely because it says "ad watched".
//
// A future AdMob Server-Side Verification endpoint can call
// the same reward/accounting logic after Google verifies the
// rewarded ad.
//
// The backend still enforces the 7/day limit.
// ============================================================

app.post(
  "/api/ads/claim",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(
          `users/${uid}`,
        );

      let newCount =
        0;

      let newBoost =
        0;

      let newRate =
        CONFIG.baseMiningRate;

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) {
              return user;
            }

            const date =
              todayKey();

            if (
              user.dailyAdDate !==
              date
            ) {
              user.dailyAdDate =
                date;

              user.dailyAdCount =
                0;

              user.dailyAdBoost =
                0;
            }

            const count =
              Math.max(
                0,
                safeInteger(
                  user.dailyAdCount,
                ),
              );

            if (
              count >=
              CONFIG.maximumDailyAds
            ) {
              return;
            }

            const nextCount =
              count + 1;

            const nextBoost =
              Math.min(
                CONFIG.maximumAdBoost,

                nextCount *
                  CONFIG.adBoostPerAd,
              );

            user.dailyAdCount =
              nextCount;

            user.dailyAdBoost =
              Number(
                nextBoost.toFixed(
                  8,
                ),
              );

            user.miningRate =
              calculateMiningRate(
                user,
              );

            user.updatedAt =
              now();

            newCount =
              nextCount;

            newBoost =
              user.dailyAdBoost;

            newRate =
              user.miningRate;

            return user;
          },
        );

      if (!result.committed) {
        const currentUser =
          await getUser(uid);

        if (
          currentUser &&
          safeInteger(
            currentUser.dailyAdCount,
          ) >=
            CONFIG.maximumDailyAds
        ) {
          return res.status(400).json({
            success: false,

            error:
              "daily_ad_limit_reached",

            dailyAdCount:
              currentUser.dailyAdCount,

            dailyAdBoost:
              currentUser.dailyAdBoost,

            miningRate:
              calculateMiningRate(
                currentUser,
              ),
          });
        }

        return res.status(400).json({
          success: false,

          error:
            "ad_claim_failed",
        });
      }

      return res.json({
        success: true,

        message:
          "Mining boost added.",

        dailyAdCount:
          newCount,

        dailyAdBoost:
          Number(
            newBoost.toFixed(
              8,
            ),
          ),

        miningRate:
          newRate,
      });
    } catch (error) {
      console.error(
        "Ad claim error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// MINING — START
// ============================================================
//
// The rate is SNAPSHOTTED at session start.
//
// This means the 24-hour session has a fixed accounting rate.
// This prevents the final reward from changing unexpectedly
// while the session is already running.
//
// User can start another session after claiming the current
// session.
// ============================================================

app.post(
  "/api/mining/start",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(
          `users/${uid}`,
        );

      let startedAt =
        0;

      let endsAt =
        0;

      let sessionRate =
        0;

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) {
              return user;
            }

            const currentTime =
              now();

            // --------------------------------------------------
            // If an old session exists and has already ended,
            // do not automatically pay it here.
            // User must claim it.
            // --------------------------------------------------

            if (
              user.miningActive ===
              true
            ) {
              return;
            }

            const rate =
              calculateMiningRate(
                user,
              );

            const endTime =
              currentTime +
              CONFIG.miningSessionHours *
                60 *
                60 *
                1000;

            user.miningActive =
              true;

            user.miningStartedAt =
              currentTime;

            user.miningEndsAt =
              endTime;

            user.miningSessionStartedAt =
              currentTime;

            user.miningSessionEndsAt =
              endTime;

            user.miningSessionRate =
              rate;

            user.miningRate =
              rate;

            user.updatedAt =
              currentTime;

            startedAt =
              currentTime;

            endsAt =
              endTime;

            sessionRate =
              rate;

            return user;
          },
        );

      if (!result.committed) {
        const user =
          await getUser(uid);

        if (
          user &&
          user.miningActive ===
            true
        ) {
          return res.status(400).json({
            success: false,

            error:
              "mining_already_active",

            miningEndsAt:
              user.miningEndsAt,

            miningRate:
              safeNumber(
                user.miningSessionRate,
              ),
          });
        }

        return res.status(400).json({
          success: false,

          error:
            "mining_start_failed",
        });
      }

      return res.json({
        success: true,

        message:
          "Mining session started.",

        coin:
          CONFIG.miningCoin,

        miningRate:
          sessionRate,

        miningStartedAt:
          startedAt,

        miningEndsAt:
          endsAt,

        sessionHours:
          CONFIG.miningSessionHours,
      });
    } catch (error) {
      console.error(
        "Mining start error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// MINING — STATUS
// ============================================================

app.get(
  "/api/mining/status",

  authenticate,

  async (req, res) => {
    try {
      const user =
        await getUser(
          req.user.uid,
        );

      if (!user) {
        return res.status(404).json({
          success: false,

          error:
            "user_not_found",
        });
      }

      const active =
        user.miningActive ===
        true;

      const endsAt =
        safeNumber(
          user.miningEndsAt,
        );

      const remaining =
        active
          ? Math.max(
              0,
              endsAt - now(),
            )
          : 0;

      const sessionRate =
        safeNumber(
          user.miningSessionRate,
          calculateMiningRate(
            user,
          ),
        );

      const completed =
        active &&
        endsAt > 0 &&
        now() >= endsAt;

      const estimatedEarned =
        active
          ? Number(
              (
                sessionRate *
                Math.min(
                  CONFIG.miningSessionHours,
                  Math.max(
                    0,
                    (
                      Math.min(
                        now(),
                        endsAt,
                      ) -
                        safeNumber(
                          user.miningStartedAt,
                          now(),
                        )
                    ) /
                      (
                        60 *
                        60 *
                        1000
                      ),
                  ),
                )
              ).toFixed(8),
            )
          : 0;

      return res.json({
        success: true,

        miningActive:
          active,

        miningCompleted:
          completed,

        miningRate:
          sessionRate,

        currentMiningRate:
          calculateMiningRate(
            user,
          ),

        sessionMiningRate:
          sessionRate,

        miningStartedAt:
          user.miningStartedAt ||
          null,

        miningEndsAt:
          user.miningEndsAt ||
          null,

        remainingMilliseconds:
          remaining,

        estimatedEarned:
          estimatedEarned,

        fanBalance:
          safeNumber(
            user.fanBalance,
          ),
      });
    } catch (error) {
      console.error(
        "Mining status error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// MINING — CLAIM
// ============================================================
//
// THIS IS THE IMPORTANT PART.
//
// Backend checks:
//   1. Mining exists.
//   2. Mining is active.
//   3. Server time >= miningEndsAt.
//   4. Session rate is taken from backend.
//   5. Reward is calculated on backend.
//   6. FAN balance is updated inside a transaction.
//   7. Mining session is closed in the same transaction.
//
// Flutter cannot send:
//   earned = 100000
//
// The backend completely ignores any client-supplied reward.
// ============================================================

app.post(
  "/api/mining/claim",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(
          `users/${uid}`,
        );

      let earnedAmount =
        0;

      let finalBalance =
        0;

      let claimedRate =
        0;

      let sessionStartedAt =
        0;

      let sessionEndedAt =
        0;

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) {
              return user;
            }

            if (
              user.miningActive !==
              true
            ) {
              return;
            }

            const currentTime =
              now();

            const startedAt =
              safeNumber(
                user.miningSessionStartedAt ||
                  user.miningStartedAt,
              );

            const endsAt =
              safeNumber(
                user.miningSessionEndsAt ||
                  user.miningEndsAt,
              );

            if (
              !startedAt ||
              !endsAt
            ) {
              return;
            }

            if (
              currentTime <
              endsAt
            ) {
              return;
            }

            // --------------------------------------------------
            // IMPORTANT:
            // Use session snapshot rate.
            // --------------------------------------------------

            const rate =
              Math.max(
                0,
                safeNumber(
                  user.miningSessionRate,
                  calculateMiningRate(
                    user,
                  ),
                ),
              );

            const elapsedHours =
              Math.min(
                CONFIG.miningSessionHours,

                Math.max(
                  0,

                  (
                    endsAt -
                      startedAt
                  ) /
                    (
                      60 *
                      60 *
                      1000
                    ),
                ),
              );

            const reward =
              Number(
                (
                  rate *
                  elapsedHours
                ).toFixed(8),
              );

            const currentBalance =
              safeNumber(
                user.fanBalance,
              );

            const nextBalance =
              Number(
                (
                  currentBalance +
                  reward
                ).toFixed(8),
              );

            user.fanBalance =
              nextBalance;

            user.miningActive =
              false;

            user.miningStartedAt =
              null;

            user.miningEndsAt =
              null;

            user.miningSessionStartedAt =
              null;

            user.miningSessionEndsAt =
              null;

            user.miningSessionRate =
              null;

            // Current rate after session.
            user.miningRate =
              calculateMiningRate(
                user,
              );

            user.updatedAt =
              currentTime;

            earnedAmount =
              reward;

            finalBalance =
              nextBalance;

            claimedRate =
              rate;

            sessionStartedAt =
              startedAt;

            sessionEndedAt =
              endsAt;

            return user;
          },
        );

      if (!result.committed) {
        const user =
          await getUser(uid);

        if (!user) {
          return res.status(404).json({
            success: false,

            error:
              "user_not_found",
          });
        }

        if (
          user.miningActive ===
          true
        ) {
          return res.status(400).json({
            success: false,

            error:
              "mining_not_finished",

            miningEndsAt:
              user.miningEndsAt,

            remainingMilliseconds:
              Math.max(
                0,

                safeNumber(
                  user.miningEndsAt,
                ) - now(),
              ),
          });
        }

        return res.status(400).json({
          success: false,

          error:
            "nothing_to_claim",
        });
      }

      // --------------------------------------------------------
      // AUDIT RECORD
      // --------------------------------------------------------

      const claimId =
        crypto
          .randomBytes(16)
          .toString("hex");

      await db
        .ref(
          `miningClaims/${uid}/${claimId}`,
        )
        .set({
          uid,

          type:
            "mining",

          coin:
            CONFIG.miningCoin,

          amount:
            earnedAmount,

          rate:
            claimedRate,

          startedAt:
            sessionStartedAt,

          endedAt:
            sessionEndedAt,

          claimedAt:
            now(),
        });

      return res.json({
        success: true,

        earned:
          earnedAmount,

        coin:
          CONFIG.miningCoin,

        miningRate:
          claimedRate,

        fanBalance:
          finalBalance,

        miningActive:
          false,
      });
    } catch (error) {
      console.error(
        "Mining claim error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// REFERRAL — APPLY
// ============================================================
//
// Rewards:
//
// New user:
//   +20 FAN
//
// Inviter:
//   +5 FAN
//
// Inviter mining:
//   +0.02 FAN/H
//
// NO referral limit.
// ============================================================

app.post(
  "/api/referral/apply",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const code =
        cleanString(
          req.body.referralCode,
        ).toUpperCase();

      if (!code) {
        return res.status(400).json({
          success: false,

          error:
            "referral_code_required",
        });
      }

      const userRef =
        db.ref(
          `users/${uid}`,
        );

      const userSnapshot =
        await userRef.once(
          "value",
        );

      if (
        !userSnapshot.exists()
      ) {
        return res.status(404).json({
          success: false,

          error:
            "user_not_found",
        });
      }

      const user =
        userSnapshot.val();

      if (
        user.referrerUid
      ) {
        return res.status(400).json({
          success: false,

          error:
            "referral_already_used",
        });
      }

      const inviterSnapshot =
        await db
          .ref(
            `referralCodes/${code}`,
          )
          .once("value");

      if (
        !inviterSnapshot.exists()
      ) {
        return res.status(400).json({
          success: false,

          error:
            "invalid_referral_code",
        });
      }

      const inviterUid =
        inviterSnapshot.val();

      if (
        inviterUid === uid
      ) {
        return res.status(400).json({
          success: false,

          error:
            "cannot_refer_yourself",
        });
      }

      const inviterRef =
        db.ref(
          `users/${inviterUid}`,
        );

      const inviterSnapshotUser =
        await inviterRef.once(
          "value",
        );

      if (
        !inviterSnapshotUser.exists()
      ) {
        return res.status(400).json({
          success: false,

          error:
            "inviter_not_found",
        });
      }

      const inviter =
        inviterSnapshotUser.val();

      // --------------------------------------------------------
      // ATOMIC LOCK ON THE NEW USER
      //
      // This prevents two simultaneous referral requests from
      // rewarding the same new user twice.
      // --------------------------------------------------------

      const referralLockResult =
        await userRef
          .child(
            "referrerUid",
          )
          .transaction(
            (existing) => {
              if (existing) {
                return;
              }

              return inviterUid;
            },
          );

      if (
        !referralLockResult.committed
      ) {
        return res.status(400).json({
          success: false,

          error:
            "referral_already_used",
        });
      }

      const timestamp =
        now();

      // --------------------------------------------------------
      // UPDATE NEW USER
      // --------------------------------------------------------

      const newUserBalance =
        safeNumber(
          user.fanBalance,
        ) +
        CONFIG.newUserReferralReward;

      // --------------------------------------------------------
      // UPDATE INVITER
      // --------------------------------------------------------

      const nextReferralCount =
        safeInteger(
          inviter.activeReferralCount,
        ) + 1;

      const inviterNewBalance =
        safeNumber(
          inviter.fanBalance,
        ) +
        CONFIG.inviterReferralReward;

      const inviterNewRate =
        calculateMiningRate({
          ...inviter,

          activeReferralCount:
            nextReferralCount,
        });

      const updates = {};

      updates[
        `users/${uid}/fanBalance`
      ] =
        Number(
          newUserBalance.toFixed(
            8,
          ),
        );

      updates[
        `users/${uid}/updatedAt`
      ] =
        timestamp;

      updates[
        `users/${inviterUid}/fanBalance`
      ] =
        Number(
          inviterNewBalance.toFixed(
            8,
          ),
        );

      updates[
        `users/${inviterUid}/activeReferralCount`
      ] =
        nextReferralCount;

      updates[
        `users/${inviterUid}/miningRate`
      ] =
        inviterNewRate;

      updates[
        `users/${inviterUid}/updatedAt`
      ] =
        timestamp;

      updates[
        `referrals/${inviterUid}/${uid}`
      ] = {
        uid,

        active:
          true,

        createdAt:
          timestamp,
      };

      // --------------------------------------------------------
      // AUDIT RECORDS
      // --------------------------------------------------------

      const referralId =
        crypto
          .randomBytes(16)
          .toString("hex");

      updates[
        `referralTransactions/${referralId}`
      ] = {
        referralId,

        newUserUid:
          uid,

        inviterUid,

        newUserReward:
          CONFIG.newUserReferralReward,

        inviterReward:
          CONFIG.inviterReferralReward,

        miningBonus:
          CONFIG.activeReferralMiningBonus,

        createdAt:
          timestamp,
      };

      try {
        await db
          .ref()
          .update(updates);
      } catch (updateError) {
        // ------------------------------------------------------
        // COMPENSATION:
        // If the reward update fails, remove the referral lock
        // so the user can safely retry.
        // ------------------------------------------------------

        await userRef
          .child(
            "referrerUid",
          )
          .remove();

        throw updateError;
      }

      return res.json({
        success: true,

        message:
          "Referral successfully applied.",

        newUserReward:
          CONFIG.newUserReferralReward,

        inviterReward:
          CONFIG.inviterReferralReward,

        activeReferralMiningBonus:
          CONFIG.activeReferralMiningBonus,

        activeReferralCount:
          nextReferralCount,

        miningRate:
          inviterNewRate,
      });
    } catch (error) {
      console.error(
        "Referral error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// REFERRAL — LIST
// ============================================================

app.get(
  "/api/referral/list",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const snapshot =
        await db
          .ref(
            `referrals/${uid}`,
          )
          .once("value");

      const data =
        snapshot.val() || {};

      const referrals =
        Object.values(
          data,
        );

      const activeReferralCount =
        referrals.filter(
          (item) =>
            item &&
            item.active ===
              true,
        ).length;

      return res.json({
        success: true,

        activeReferralCount,

        referrals,
      });
    } catch (error) {
      console.error(
        "Referral list error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// SOCIAL — DAILY CLAIM
// ============================================================
//
// Backend guarantees:
//   One claim per user per UTC day.
//
// Reward:
//   +10 FAN
// ============================================================

app.post(
  "/api/social/claim",

  authenticate,

  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const date =
        todayKey();

      const claimRef =
        db.ref(
          `socialClaims/${uid}/${date}`,
        );

      const claimResult =
        await claimRef.transaction(
          (existing) => {
            if (existing) {
              return;
            }

            return {
              reward:
                CONFIG.dailySocialReward,

              coin:
                CONFIG.miningCoin,

              claimedAt:
                now(),
            };
          },
        );

      if (
        !claimResult.committed
      ) {
        return res.status(400).json({
          success: false,

          error:
            "social_reward_already_claimed",
        });
      }

      const userRef =
        db.ref(
          `users/${uid}`,
        );

      let finalBalance =
        0;

      const balanceResult =
        await userRef.transaction(
          (user) => {
            if (!user) {
              return user;
            }

            const currentBalance =
              safeNumber(
                user.fanBalance,
              );

            const nextBalance =
              Number(
                (
                  currentBalance +
                  CONFIG.dailySocialReward
                ).toFixed(8),
              );

            user.fanBalance =
              nextBalance;

            user.updatedAt =
              now();

            finalBalance =
              nextBalance;

            return user;
          },
        );

      if (
        !balanceResult.committed
      ) {
        await claimRef.remove();

        return res.status(500).json({
          success: false,

          error:
            "social_reward_failed",
        });
      }

      // --------------------------------------------------------
      // AUDIT
      // --------------------------------------------------------

      const transactionId =
        crypto
          .randomBytes(16)
          .toString("hex");

      await db
        .ref(
          `rewardTransactions/${uid}/${transactionId}`,
        )
        .set({
          transactionId,

          type:
            "daily_social",

          amount:
            CONFIG.dailySocialReward,

          coin:
            CONFIG.miningCoin,

          date,

          createdAt:
            now(),
        });

      return res.json({
        success: true,

        reward:
          CONFIG.dailySocialReward,

        coin:
          CONFIG.miningCoin,

        fanBalance:
          finalBalance,
      });
    } catch (error) {
      console.error(
        "Social claim error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// WALLET
// ============================================================

app.get(
  "/api/wallet",

  authenticate,

  async (req, res) => {
    try {
      const user =
        await getUser(
          req.user.uid,
        );

      if (!user) {
        return res.status(404).json({
          success: false,

          error:
            "user_not_found",
        });
      }

      return res.json({
        success: true,

        fanBalance:
          safeNumber(
            user.fanBalance,
          ),

        afamBalance:
          safeNumber(
            user.afamBalance,
          ),

        walletStatus:
          "COMING SOON",
      });
    } catch (error) {
      console.error(
        "Wallet error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// AUTH — LOGOUT
// ============================================================

app.post(
  "/api/auth/logout",

  authenticate,

  async (req, res) => {
    try {
      await revokeSession(
        req.session.rawToken,
      );

      return res.json({
        success: true,

        message:
          "Session revoked.",
      });
    } catch (error) {
      console.error(
        "Logout error:",
        error,
      );

      return res.status(500).json({
        success: false,

        error:
          "logout_failed",
      });
    }
  },
);

// ============================================================
// 404
// ============================================================

app.use(
  (req, res) => {
    res.status(404).json({
      success: false,

      error:
        "not_found",

      message:
        "API endpoint not found.",
    });
  },
);

// ============================================================
// GLOBAL ERROR HANDLER
// ============================================================

app.use(
  (
    error,
    req,
    res,
    next,
  ) => {
    console.error(
      "Unhandled server error:",
      error,
    );

    if (
      res.headersSent
    ) {
      return next(error);
    }

    return res.status(500).json({
      success: false,

      error:
        "internal_server_error",
    });
  },
);

// ============================================================
// START SERVER
// ============================================================

app.listen(
  PORT,

  "0.0.0.0",

  () => {
    console.log(
      "============================================================",
    );

    console.log(
      `POWER FAN NETWORK API running on port ${PORT}`,
    );

    console.log(
      `Version: ${CONFIG.version}`,
    );

    console.log(
      "Authentication: POWER FAN NETWORK Backend",
    );

    console.log(
      "Firebase Authentication: DISABLED",
    );

    console.log(
      "Database: Firebase Realtime Database",
    );

    console.log(
      `Base mining rate: ${CONFIG.baseMiningRate} FAN/H`,
    );

    console.log(
      `Mining session: ${CONFIG.miningSessionHours} hours`,
    );

    console.log(
      `Ad boost: +${CONFIG.adBoostPerAd} FAN/H per ad`,
    );

    console.log(
      `Maximum ads/day: ${CONFIG.maximumDailyAds}`,
    );

    console.log(
      `Referral bonus: +${CONFIG.activeReferralMiningBonus} FAN/H per active referral`,
    );

    console.log(
      "Referral count limit: NONE",
    );

    console.log(
      "Maximum mining rate: NONE",
    );

    console.log(
      "============================================================",
    );
  },
);
