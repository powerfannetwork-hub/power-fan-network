// ============================================================
// POWER FAN NETWORK — PRODUCTION BACKEND
// FILE: src/server.js
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
// FIREBASE
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

if (!admin.apps.length) {
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
}

const db = admin.database();

// ============================================================
// CONFIG
// ============================================================

const CONFIG = {
  appName: "POWER FAN NETWORK",
  version: "1.0.0",

  miningCoin: "FAN",
  originalCoin: "AFAM",

  baseMiningRate: 0.2,
  miningSessionHours: 24,

  adBoostPerAd: 0.1,
  maximumDailyAds: 7,
  maximumAdBoost: 0.7,

  newUserReferralReward: 20,
  inviterReferralReward: 5,

  // NO LIMIT
  activeReferralMiningBonus: 0.02,

  dailySocialReward: 10,

  maximumNameLength: 80,
  maximumEmailLength: 254,
  minimumPasswordLength: 8,

  accessTokenDays: 30,
  refreshTokenDays: 90,

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

// ============================================================
// PASSWORD
// ============================================================

function hashPassword(password) {
  const salt = crypto
    .randomBytes(16)
    .toString("hex");

  const derivedKey = crypto.scryptSync(
    password,
    salt,
    64,
  );

  return `scrypt:${salt}:${derivedKey.toString(
    "hex",
  )}`;
}

function verifyPassword(password, storedHash) {
  try {
    const parts = String(storedHash).split(":");

    if (
      parts.length !== 3 ||
      parts[0] !== "scrypt"
    ) {
      return false;
    }

    const salt = parts[1];
    const storedKey = Buffer.from(
      parts[2],
      "hex",
    );

    const derivedKey = crypto.scryptSync(
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
  } catch {
    return false;
  }
}

// ============================================================
// MINING RATE
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
      safeNumber(user.dailyAdBoost),
    ),
  );

  const referralBoost =
    referrals *
    CONFIG.activeReferralMiningBonus;

  return Number(
    (
      CONFIG.baseMiningRate +
      referralBoost +
      adBoost
    ).toFixed(8),
  );
}

// ============================================================
// PUBLIC USER
// ============================================================

function publicUser(user) {
  if (!user) return null;

  return {
    uid: user.uid,
    name: user.name || "",
    email: user.email || "",

    fanBalance: safeNumber(
      user.fanBalance,
    ),

    afamBalance: safeNumber(
      user.afamBalance,
    ),

    miningRate:
      calculateMiningRate(user),

    dailyAdCount: safeInteger(
      user.dailyAdCount,
    ),

    dailyAdBoost: safeNumber(
      user.dailyAdBoost,
    ),

    activeReferralCount:
      safeInteger(
        user.activeReferralCount,
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

// ============================================================
// DATABASE
// ============================================================

async function getUser(uid) {
  const snapshot = await db
    .ref(`users/${uid}`)
    .once("value");

  return snapshot.exists()
    ? snapshot.val()
    : null;
}

async function createUniqueReferralCode() {
  for (let i = 0; i < 20; i++) {
    const code =
      generateReferralCode();

    const snapshot = await db
      .ref(`referralCodes/${code}`)
      .once("value");

    if (!snapshot.exists()) {
      return code;
    }
  }

  throw new Error(
    "Unable to generate unique referral code.",
  );
}

// ============================================================
// SESSION
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

  const createdAt = now();
  const expiresAt =
    createdAt + durationMs;

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

  const snapshot = await db
    .ref(`sessions/${tokenHash}`)
    .once("value");

  if (!snapshot.exists()) {
    return null;
  }

  const session =
    snapshot.val();

  if (
    safeNumber(session.expiresAt) <=
    now()
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
  if (!token) return;

  await db
    .ref(
      `sessions/${hashToken(token)}`,
    )
    .remove();
}

// ============================================================
// AUTH MIDDLEWARE
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
        error: "missing_token",
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
          "Your session is invalid or expired.",
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
        error: "user_not_found",
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
      error.message,
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

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: CONFIG.appName,
    version: CONFIG.version,
    status: "running",
  });
});

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

      res.json({
        success: true,
        status: "ok",
        database:
          "Firebase Realtime Database",
        authentication:
          "POWER FAN NETWORK Backend",
        firebaseAuthentication:
          false,
      });
    } catch {
      res.status(503).json({
        success: false,
        status: "degraded",
        database: "unavailable",
      });
    }
  },
);

// ============================================================
// STATUS
// ============================================================

app.get(
  "/api/status",
  (req, res) => {
    res.json({
      success: true,
      app: CONFIG.appName,
      version: CONFIG.version,
      status: "online",
      authentication:
        "Backend Session",
      firebaseAuthentication:
        false,
      database:
        "Firebase Realtime Database",
    });
  },
);

// ============================================================
// REGISTER
// ============================================================

app.post(
  "/api/auth/register",
  registerLimiter,
  async (req, res) => {
    try {
      const name =
        cleanString(req.body.name);

      const email =
        normalizeEmail(
          req.body.email,
        );

      const password =
        String(
          req.body.password || "",
        );

      if (!name) {
        return res.status(400).json({
          success: false,
          error: "name_required",
        });
      }

      if (
        name.length >
        CONFIG.maximumNameLength
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
        CONFIG.minimumPasswordLength
      ) {
        return res.status(400).json({
          success: false,
          error: "weak_password",
        });
      }

      const emailKey =
        encodeURIComponent(email);

      const existing =
        await db
          .ref(
            `emailIndex/${emailKey}`,
          )
          .once("value");

      if (existing.exists()) {
        return res.status(409).json({
          success: false,
          error:
            "email_already_in_use",
        });
      }

      const uid =
        crypto
          .randomBytes(16)
          .toString("hex");

      const referralCode =
        await createUniqueReferralCode();

      const timestamp = now();

      const user = {
        uid,
        name,
        email,

        passwordHash:
          hashPassword(password),

        fanBalance: 0,
        afamBalance: 0,

        dailyAdCount: 0,
        dailyAdBoost: 0,
        dailyAdDate: todayKey(),

        activeReferralCount: 0,

        referralCode,
        referrerUid: null,

        miningActive: false,

        miningStartedAt: null,
        miningEndsAt: null,

        miningSessionRate: null,
        miningSessionStartedAt: null,
        miningSessionEndsAt: null,

        createdAt: timestamp,
        updatedAt: timestamp,
      };

      user.miningRate =
        calculateMiningRate(user);

      const updates = {};

      updates[`users/${uid}`] =
        user;

      updates[
        `referralCodes/${referralCode}`
      ] = uid;

      updates[
        `emailIndex/${emailKey}`
      ] = uid;

      await db
        .ref()
        .update(updates);

      const access =
        await createSession(
          uid,
          "access",
          CONFIG.accessTokenDays *
            86400000,
        );

      const refresh =
        await createSession(
          uid,
          "refresh",
          CONFIG.refreshTokenDays *
            86400000,
        );

      return res.status(201).json({
        success: true,
        message:
          "Account created successfully.",
        token: access.token,
        refreshToken:
          refresh.token,
        expiresAt:
          access.expiresAt,
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
      });
    }
  },
);

// ============================================================
// LOGIN
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

      if (
        !validEmail(email) ||
        !password
      ) {
        return res.status(401).json({
          success: false,
          error:
            "invalid_credentials",
        });
      }

      const emailSnapshot =
        await db
          .ref(
            `emailIndex/${encodeURIComponent(
              email,
            )}`,
          )
          .once("value");

      if (!emailSnapshot.exists()) {
        return res.status(401).json({
          success: false,
          error:
            "invalid_credentials",
        });
      }

      const uid =
        emailSnapshot.val();

      const user =
        await getUser(uid);

      if (
        !user ||
        !verifyPassword(
          password,
          user.passwordHash,
        )
      ) {
        return res.status(401).json({
          success: false,
          error:
            "invalid_credentials",
        });
      }

      const date = todayKey();

      if (
        user.dailyAdDate !== date
      ) {
        user.dailyAdDate = date;
        user.dailyAdCount = 0;
        user.dailyAdBoost = 0;
        user.miningRate =
          calculateMiningRate(user);
        user.updatedAt = now();

        await db
          .ref(`users/${uid}`)
          .update({
            dailyAdDate: date,
            dailyAdCount: 0,
            dailyAdBoost: 0,
            miningRate:
              user.miningRate,
            updatedAt:
              user.updatedAt,
          });
      }

      const access =
        await createSession(
          uid,
          "access",
          CONFIG.accessTokenDays *
            86400000,
        );

      const refresh =
        await createSession(
          uid,
          "refresh",
          CONFIG.refreshTokenDays *
            86400000,
        );

      res.json({
        success: true,
        message:
          "Login successful.",
        token: access.token,
        refreshToken:
          refresh.token,
        expiresAt:
          access.expiresAt,
        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Login error:",
        error,
      );

      res.status(500).json({
        success: false,
        error: "login_failed",
      });
    }
  },
);

// ============================================================
// REFRESH
// ============================================================

app.post(
  "/api/auth/refresh",
  async (req, res) => {
    try {
      const refreshToken =
        cleanString(
          req.body.refreshToken,
        );

      const session =
        await getSessionFromToken(
          refreshToken,
        );

      if (
        !session ||
        session.type !== "refresh"
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

      const access =
        await createSession(
          user.uid,
          "access",
          CONFIG.accessTokenDays *
            86400000,
        );

      res.json({
        success: true,
        token: access.token,
        expiresAt:
          access.expiresAt,
        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Refresh error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "refresh_failed",
      });
    }
  },
);

// ============================================================
// ME
// ============================================================

app.get(
  "/api/auth/me",
  authenticate,
  (req, res) => {
    res.json({
      success: true,
      user:
        publicUser(
          req.user,
        ),
    });
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

      res.json({
        success: true,
        user:
          publicUser(user),
      });
    } catch (error) {
      console.error(
        "Profile error:",
        error,
      );

      res.status(500).json({
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
      coin: CONFIG.miningCoin,

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

      maximumMiningRate: null,

      miningSessionHours:
        CONFIG.miningSessionHours,

      referralMiningRateIsUnlimited:
        true,
    });
  },
);

// ============================================================
// MINING START
// ============================================================

app.post(
  "/api/mining/start",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      let startedAt = 0;
      let endsAt = 0;
      let sessionRate = 0;

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) return user;

            if (
              user.miningActive === true
            ) {
              return;
            }

            const start = now();

            const end =
              start +
              CONFIG.miningSessionHours *
                3600000;

            const rate =
              calculateMiningRate(user);

            user.miningActive = true;
            user.miningStartedAt =
              start;
            user.miningEndsAt = end;

            user.miningSessionStartedAt =
              start;

            user.miningSessionEndsAt =
              end;

            user.miningSessionRate =
              rate;

            user.miningRate = rate;
            user.updatedAt = start;

            startedAt = start;
            endsAt = end;
            sessionRate = rate;

            return user;
          },
        );

      if (!result.committed) {
        const user =
          await getUser(uid);

        if (
          user?.miningActive === true
        ) {
          return res.status(400).json({
            success: false,
            error:
              "mining_already_active",
            miningEndsAt:
              user.miningEndsAt,
          });
        }

        return res.status(400).json({
          success: false,
          error:
            "mining_start_failed",
        });
      }

      res.json({
        success: true,
        message:
          "Mining session started.",
        coin: CONFIG.miningCoin,
        miningRate: sessionRate,
        miningStartedAt: startedAt,
        miningEndsAt: endsAt,
      });
    } catch (error) {
      console.error(
        "Mining start error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// MINING STATUS
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
        user.miningActive === true;

      const started =
        safeNumber(
          user.miningStartedAt,
        );

      const ends =
        safeNumber(
          user.miningEndsAt,
        );

      const rate =
        safeNumber(
          user.miningSessionRate,
          calculateMiningRate(user),
        );

      const completed =
        active &&
        ends > 0 &&
        now() >= ends;

      const remaining =
        active
          ? Math.max(
              0,
              ends - now(),
            )
          : 0;

      const estimated =
        active
          ? Number(
              (
                rate *
                Math.min(
                  CONFIG.miningSessionHours,
                  Math.max(
                    0,
                    (
                      Math.min(
                        now(),
                        ends,
                      ) - started
                    ) /
                      3600000,
                  ),
                )
              ).toFixed(8),
            )
          : 0;

      res.json({
        success: true,
        miningActive: active,
        miningCompleted:
          completed,

        miningRate: rate,

        currentMiningRate:
          calculateMiningRate(user),

        sessionMiningRate: rate,

        miningStartedAt:
          user.miningStartedAt ||
          null,

        miningEndsAt:
          user.miningEndsAt ||
          null,

        remainingMilliseconds:
          remaining,

        estimatedEarned:
          estimated,

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

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// MINING CLAIM
// ============================================================

app.post(
  "/api/mining/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      let earned = 0;
      let balance = 0;
      let rate = 0;
      let startedAt = 0;
      let endedAt = 0;

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) return user;

            if (
              user.miningActive !== true
            ) {
              return;
            }

            const start =
              safeNumber(
                user.miningSessionStartedAt ||
                  user.miningStartedAt,
              );

            const end =
              safeNumber(
                user.miningSessionEndsAt ||
                  user.miningEndsAt,
              );

            if (
              !start ||
              !end ||
              now() < end
            ) {
              return;
            }

            rate = Math.max(
              0,
              safeNumber(
                user.miningSessionRate,
                calculateMiningRate(user),
              ),
            );

            const hours =
              Math.min(
                CONFIG.miningSessionHours,
                Math.max(
                  0,
                  (end - start) /
                    3600000,
                ),
              );

            earned = Number(
              (
                rate * hours
              ).toFixed(8),
            );

            balance = Number(
              (
                safeNumber(
                  user.fanBalance,
                ) + earned
              ).toFixed(8),
            );

            user.fanBalance =
              balance;

            user.miningActive =
              false;

            user.miningStartedAt =
              null;

            user.miningEndsAt =
              null;

            user.miningSessionRate =
              null;

            user.miningSessionStartedAt =
              null;

            user.miningSessionEndsAt =
              null;

            user.miningRate =
              calculateMiningRate(user);

            user.updatedAt = now();

            startedAt = start;
            endedAt = end;

            return user;
          },
        );

      if (!result.committed) {
        const user =
          await getUser(uid);

        if (
          user?.miningActive === true
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

      const claimId =
        crypto
          .randomBytes(16)
          .toString("hex");

      await db
        .ref(
          `miningClaims/${uid}/${claimId}`,
        )
        .set({
          claimId,
          uid,
          type: "mining",
          coin: CONFIG.miningCoin,
          amount: earned,
          rate,
          startedAt,
          endedAt,
          claimedAt: now(),
        });

      res.json({
        success: true,
        earned,
        coin: CONFIG.miningCoin,
        miningRate: rate,
        fanBalance: balance,
        miningActive: false,
      });
    } catch (error) {
      console.error(
        "Mining claim error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// ADS CLAIM
// ============================================================

app.post(
  "/api/ads/claim",
  authenticate,
  async (req, res) => {
    try {
      const uid =
        req.user.uid;

      const userRef =
        db.ref(`users/${uid}`);

      let count = 0;
      let boost = 0;
      let rate = 0;

      const result =
        await userRef.transaction(
          (user) => {
            if (!user) return user;

            const date = todayKey();

            if (
              user.dailyAdDate !==
              date
            ) {
              user.dailyAdDate = date;
              user.dailyAdCount = 0;
              user.dailyAdBoost = 0;
            }

            const current =
              safeInteger(
                user.dailyAdCount,
              );

            if (
              current >=
              CONFIG.maximumDailyAds
            ) {
              return;
            }

            count = current + 1;

            boost = Number(
              Math.min(
                CONFIG.maximumAdBoost,
                count *
                  CONFIG.adBoostPerAd,
              ).toFixed(8),
            );

            user.dailyAdCount =
              count;

            user.dailyAdBoost =
              boost;

            user.miningRate =
              calculateMiningRate(user);

            user.updatedAt = now();

            rate =
              user.miningRate;

            return user;
          },
        );

      if (!result.committed) {
        return res.status(400).json({
          success: false,
          error:
            "daily_ad_limit_reached",
          dailyAdCount:
            safeInteger(
              (
                await getUser(uid)
              )?.dailyAdCount,
            ),
        });
      }

      res.json({
        success: true,
        dailyAdCount: count,
        dailyAdBoost: boost,
        miningRate: rate,
      });
    } catch (error) {
      console.error(
        "Ad claim error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
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

      maximumActiveReferrals: null,

      referralMiningBonusLimit: null,
    });
  },
);

// ============================================================
// REFERRAL APPLY
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

      const codeSnapshot =
        await db
          .ref(
            `referralCodes/${code}`,
          )
          .once("value");

      if (!codeSnapshot.exists()) {
        return res.status(400).json({
          success: false,
          error:
            "invalid_referral_code",
        });
      }

      const inviterUid =
        codeSnapshot.val();

      if (inviterUid === uid) {
        return res.status(400).json({
          success: false,
          error:
            "cannot_refer_yourself",
        });
      }

      const user =
        await getUser(uid);

      const inviter =
        await getUser(
          inviterUid,
        );

      if (!user || !inviter) {
        return res.status(404).json({
          success: false,
          error:
            "user_not_found",
        });
      }

      if (user.referrerUid) {
        return res.status(400).json({
          success: false,
          error:
            "referral_already_used",
        });
      }

      // --------------------------------------------------------
      // ATOMIC REFERRAL LOCK
      // --------------------------------------------------------

      const lock =
        await db
          .ref(
            `users/${uid}/referrerUid`,
          )
          .transaction(
            (existing) => {
              if (existing) {
                return;
              }

              return inviterUid;
            },
          );

      if (!lock.committed) {
        return res.status(400).json({
          success: false,
          error:
            "referral_already_used",
        });
      }

      // --------------------------------------------------------
      // READ LATEST INVITER
      // --------------------------------------------------------

      const latestInviter =
        await getUser(
          inviterUid,
        );

      if (!latestInviter) {
        await db
          .ref(
            `users/${uid}/referrerUid`,
          )
          .remove();

        return res.status(404).json({
          success: false,
          error:
            "inviter_not_found",
        });
      }

      const nextCount =
        safeInteger(
          latestInviter.activeReferralCount,
        ) + 1;

      const newUserBalance =
        Number(
          (
            safeNumber(
              user.fanBalance,
            ) +
            CONFIG.newUserReferralReward
          ).toFixed(8),
        );

      const inviterBalance =
        Number(
          (
            safeNumber(
              latestInviter.fanBalance,
            ) +
            CONFIG.inviterReferralReward
          ).toFixed(8),
        );

      const inviterRate =
        calculateMiningRate({
          ...latestInviter,
          activeReferralCount:
            nextCount,
        });

      const timestamp = now();

      const referralId =
        crypto
          .randomBytes(16)
          .toString("hex");

      // --------------------------------------------------------
      // ATOMIC MULTI-LOCATION UPDATE
      // --------------------------------------------------------

      const updates = {};

      updates[
        `users/${uid}/fanBalance`
      ] = newUserBalance;

      updates[
        `users/${uid}/updatedAt`
      ] = timestamp;

      updates[
        `users/${inviterUid}/fanBalance`
      ] = inviterBalance;

      updates[
        `users/${inviterUid}/activeReferralCount`
      ] = nextCount;

      updates[
        `users/${inviterUid}/miningRate`
      ] = inviterRate;

      updates[
        `users/${inviterUid}/updatedAt`
      ] = timestamp;

      updates[
        `referrals/${inviterUid}/${uid}`
      ] = {
        uid,
        active: true,
        createdAt: timestamp,
      };

      updates[
        `referralTransactions/${referralId}`
      ] = {
        referralId,
        newUserUid: uid,
        inviterUid,

        newUserReward:
          CONFIG.newUserReferralReward,

        inviterReward:
          CONFIG.inviterReferralReward,

        miningBonus:
          CONFIG.activeReferralMiningBonus,

        createdAt: timestamp,
      };

      try {
        await db
          .ref()
          .update(updates);
      } catch (error) {
        await db
          .ref(
            `users/${uid}/referrerUid`,
          )
          .remove();

        throw error;
      }

      res.json({
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
          nextCount,

        miningRate:
          inviterRate,
      });
    } catch (error) {
      console.error(
        "Referral error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// REFERRAL LIST
// ============================================================

app.get(
  "/api/referral/list",
  authenticate,
  async (req, res) => {
    try {
      const snapshot =
        await db
          .ref(
            `referrals/${req.user.uid}`,
          )
          .once("value");

      const data =
        snapshot.val() || {};

      const referrals =
        Object.values(data);

      const activeCount =
        referrals.filter(
          (item) =>
            item &&
            item.active === true,
        ).length;

      res.json({
        success: true,
        activeReferralCount:
          activeCount,
        referrals,
      });
    } catch (error) {
      console.error(
        "Referral list error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
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
// SOCIAL CLAIM
// ============================================================
//
// FIXED:
// Claim record + balance update are written together.
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

      const claimLock =
        await claimRef.transaction(
          (existing) => {
            if (existing) {
              return;
            }

            return {
              status: "processing",
              createdAt: now(),
            };
          },
        );

      if (!claimLock.committed) {
        return res.status(400).json({
          success: false,
          error:
            "social_reward_already_claimed",
        });
      }

      const user =
        await getUser(uid);

      if (!user) {
        await claimRef.remove();

        return res.status(404).json({
          success: false,
          error:
            "user_not_found",
        });
      }

      const oldBalance =
        safeNumber(
          user.fanBalance,
        );

      const newBalance =
        Number(
          (
            oldBalance +
            CONFIG.dailySocialReward
          ).toFixed(8),
        );

      const transactionId =
        crypto
          .randomBytes(16)
          .toString("hex");

      const timestamp = now();

      // --------------------------------------------------------
      // ATOMIC MULTI-LOCATION UPDATE
      // --------------------------------------------------------

      const updates = {};

      updates[
        `users/${uid}/fanBalance`
      ] = newBalance;

      updates[
        `users/${uid}/updatedAt`
      ] = timestamp;

      updates[
        `socialClaims/${uid}/${date}`
      ] = {
        status: "completed",
        reward:
          CONFIG.dailySocialReward,
        coin:
          CONFIG.miningCoin,
        claimedAt: timestamp,
      };

      updates[
        `rewardTransactions/${uid}/${transactionId}`
      ] = {
        transactionId,
        type: "daily_social",
        amount:
          CONFIG.dailySocialReward,
        coin:
          CONFIG.miningCoin,
        date,
        createdAt: timestamp,
      };

      try {
        await db
          .ref()
          .update(updates);
      } catch (error) {
        await claimRef.remove();
        throw error;
      }

      res.json({
        success: true,

        reward:
          CONFIG.dailySocialReward,

        coin:
          CONFIG.miningCoin,

        fanBalance:
          newBalance,
      });
    } catch (error) {
      console.error(
        "Social claim error:",
        error,
      );

      res.status(500).json({
        success: false,
        error:
          "social_reward_failed",
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

      res.json({
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

      res.status(500).json({
        success: false,
        error:
          "server_error",
      });
    }
  },
);

// ============================================================
// LOGOUT
// ============================================================

app.post(
  "/api/auth/logout",
  authenticate,
  async (req, res) => {
    try {
      await revokeSession(
        req.session.rawToken,
      );

      res.json({
        success: true,
        message:
          "Session revoked.",
      });
    } catch (error) {
      console.error(
        "Logout error:",
        error,
      );

      res.status(500).json({
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
      error: "not_found",
      message:
        "API endpoint not found.",
    });
  },
);

// ============================================================
// ERROR HANDLER
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

    if (res.headersSent) {
      return next(error);
    }

    res.status(500).json({
      success: false,
      error:
        "internal_server_error",
    });
  },
);

// ============================================================
// START
// ============================================================

app.listen(
  PORT,
  "0.0.0.0",
  () => {
    console.log(
      "============================================================",
    );

    console.log(
      "POWER FAN NETWORK BACKEND",
    );

    console.log(
      `Server running on port ${PORT}`,
    );

    console.log(
      `Version: ${CONFIG.version}`,
    );

    console.log(
      "Authentication: Backend Session",
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
      `Referral bonus: +${CONFIG.activeReferralMiningBonus} FAN/H per active referral`,
    );

    console.log(
      "Referral limit: NONE",
    );

    console.log(
      "Mining rate limit: NONE",
    );

    console.log(
      "============================================================",
    );
  },
);
