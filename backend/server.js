// ============================================================
// POWER FAN NETWORK - CUSTOM BACKEND
// ============================================================
// Firebase Authentication: NOT USED
// Firestore: USED ONLY AS DATABASE
// Authentication: CUSTOM JWT + bcrypt
// ============================================================

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const admin = require("firebase-admin");

const app = express();

// ============================================================
// CONFIG
// ============================================================

const PORT = process.env.PORT || 3000;

const JWT_SECRET =
  process.env.JWT_SECRET || "CHANGE_THIS_SECRET_IN_PRODUCTION";

const JWT_EXPIRES_IN = "30d";

// ============================================================
// FIRESTORE INITIALIZATION
// ============================================================

let db;

try {
  /*
   * IMPORTANT:
   * Firebase Authentication ba a amfani da shi.
   *
   * Firebase Admin SDK a nan domin Firestore database kawai.
   */

  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(
      process.env.FIREBASE_SERVICE_ACCOUNT
    );

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else {
    /*
     * Wannan yana aiki idan environment yana bada
     * GOOGLE_APPLICATION_CREDENTIALS.
     */
    admin.initializeApp();
  }

  db = admin.firestore();

  console.log("Firestore connected.");
} catch (error) {
  console.error("Firestore initialization failed:");
  console.error(error.message);
}

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(express.json({ limit: "2mb" }));

app.use(express.urlencoded({ extended: true }));

// ============================================================
// HELPERS
// ============================================================

function cleanEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function cleanName(name) {
  return String(name || "").trim();
}

function generateReferralCode(name) {
  const clean = cleanName(name)
    .replace(/[^a-zA-Z0-9]/g, "")
    .toUpperCase()
    .substring(0, 5);

  const random = Math.floor(100000 + Math.random() * 900000);

  return `${clean || "FAN"}${random}`;
}

function generateUserId() {
  return `user_${Date.now()}_${Math.random()
    .toString(36)
    .substring(2, 10)}`;
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
  if (!user) return null;

  return {
    id: user.id,
    name: user.name || "",
    email: user.email || "",
    referralCode: user.referralCode || "",
    referredBy: user.referredBy || null,

    fanBalance: Number(user.fanBalance || 0),
    afamBalance: Number(user.afamBalance || 0),

    miningRate: Number(user.miningRate || 0.2),

    activeReferrals: Number(user.activeReferrals || 0),

    dailyAdsWatched: Number(user.dailyAdsWatched || 0),
    adBoost: Number(user.adBoost || 0),

    miningActive: Boolean(user.miningActive),

    createdAt: user.createdAt || null,
    updatedAt: user.updatedAt || null,
  };
}

function requireDatabase(res) {
  if (!db) {
    res.status(503).json({
      success: false,
      message: "Database is not connected.",
    });

    return false;
  }

  return true;
}

// ============================================================
// AUTH MIDDLEWARE
// ============================================================

async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization || "";

    if (!header.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authentication token is required.",
      });
    }

    const token = header.substring(7);

    const decoded = jwt.verify(token, JWT_SECRET);

    if (!decoded.userId) {
      return res.status(401).json({
        success: false,
        message: "Invalid authentication token.",
      });
    }

    if (!db) {
      return res.status(503).json({
        success: false,
        message: "Database is not connected.",
      });
    }

    const userDoc = await db
      .collection("users")
      .doc(decoded.userId)
      .get();

    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        message: "User account no longer exists.",
      });
    }

    req.user = {
      id: userDoc.id,
      ...userDoc.data(),
    };

    next();
  } catch (error) {
    console.error("Authentication error:", error.message);

    return res.status(401).json({
      success: false,
      message: "Invalid or expired authentication token.",
    });
  }
}

// ============================================================
// HEALTH CHECK
// ============================================================

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: "POWER FAN NETWORK",
    backend: "Custom Backend",
    authentication: "JWT",
    database: "Firestore",
    firebaseAuthentication: false,
    status: "online",
  });
});

app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "healthy",
    database: db ? "connected" : "disconnected",
    time: new Date().toISOString(),
  });
});

// ============================================================
// REGISTER
// ============================================================

app.post("/api/auth/register", async (req, res) => {
  try {
    if (!requireDatabase(res)) return;

    const name = cleanName(req.body.name);
    const email = cleanEmail(req.body.email);
    const password = String(req.body.password || "");
    const referralCode = String(
      req.body.referralCode || ""
    )
      .trim()
      .toUpperCase();

    // --------------------------------------------------------
    // VALIDATION
    // --------------------------------------------------------

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Name, email and password are required.",
      });
    }

    if (name.length < 2) {
      return res.status(400).json({
        success: false,
        message: "Name must contain at least 2 characters.",
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must contain at least 6 characters.",
      });
    }

    if (!email.includes("@")) {
      return res.status(400).json({
        success: false,
        message: "Invalid email address.",
      });
    }

    // --------------------------------------------------------
    // CHECK EXISTING EMAIL
    // --------------------------------------------------------

    const existing = await db
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

    if (!existing.empty) {
      return res.status(409).json({
        success: false,
        message: "This email is already registered.",
      });
    }

    // --------------------------------------------------------
    // REFERRER
    // --------------------------------------------------------

    let referrerDoc = null;

    if (referralCode) {
      const referrerQuery = await db
        .collection("users")
        .where("referralCode", "==", referralCode)
        .limit(1)
        .get();

      if (referrerQuery.empty) {
        return res.status(400).json({
          success: false,
          message: "Invalid referral code.",
        });
      }

      referrerDoc = referrerQuery.docs[0];
    }

    // --------------------------------------------------------
    // PASSWORD HASH
    // --------------------------------------------------------

    const passwordHash = await bcrypt.hash(password, 12);

    // --------------------------------------------------------
    // USER
    // --------------------------------------------------------

    const userId = generateUserId();

    const newReferralCode = generateReferralCode(name);

    const now = new Date().toISOString();

    const newUser = {
      id: userId,

      name,
      email,

      passwordHash,

      referralCode: newReferralCode,

      referredBy: referrerDoc
        ? referrerDoc.id
        : null,

      // New user referral reward
      fanBalance: referrerDoc ? 20 : 0,

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
    // FIRESTORE TRANSACTION
    // --------------------------------------------------------

    await db.runTransaction(async (transaction) => {
      const userRef = db
        .collection("users")
        .doc(userId);

      transaction.set(userRef, newUser);

      // ------------------------------------------------------
      // REFERRER REWARD
      // ------------------------------------------------------

      if (referrerDoc) {
        const referrerData = referrerDoc.data();

        const currentBalance = Number(
          referrerData.fanBalance || 0
        );

        const currentActiveReferrals = Number(
          referrerData.activeReferrals || 0
        );

        const newActiveReferrals =
          currentActiveReferrals + 1;

        const newMiningRate =
          0.2 + newActiveReferrals * 0.02;

        transaction.update(
          referrerDoc.ref,
          {
            fanBalance: currentBalance + 5,

            activeReferrals: newActiveReferrals,

            miningRate: newMiningRate,

            updatedAt: now,
          }
        );
      }
    });

    // --------------------------------------------------------
    // TOKEN
    // --------------------------------------------------------

    const token = createToken(newUser);

    return res.status(201).json({
      success: true,
      message: "Account created successfully.",
      token,
      user: publicUser(newUser),
    });
  } catch (error) {
    console.error("REGISTER ERROR:", error);

    return res.status(500).json({
      success: false,
      message: "Registration failed.",
      error:
        process.env.NODE_ENV === "development"
          ? error.message
          : undefined,
    });
  }
});

// ============================================================
// LOGIN
// ============================================================

app.post("/api/auth/login", async (req, res) => {
  try {
    if (!requireDatabase(res)) return;

    const email = cleanEmail(req.body.email);
    const password = String(req.body.password || "");

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required.",
      });
    }

    // --------------------------------------------------------
    // FIND USER
    // --------------------------------------------------------

    const query = await db
      .collection("users")
      .where("email", "==", email)
      .limit(1)
      .get();

    if (query.empty) {
      return res.status(401).json({
        success: false,
        message: "Incorrect email or password.",
      });
    }

    const doc = query.docs[0];

    const user = {
      id: doc.id,
      ...doc.data(),
    };

    // --------------------------------------------------------
    // PASSWORD
    // --------------------------------------------------------

    const validPassword = await bcrypt.compare(
      password,
      user.passwordHash || ""
    );

    if (!validPassword) {
      return res.status(401).json({
        success: false,
        message: "Incorrect email or password.",
      });
    }

    // --------------------------------------------------------
    // TOKEN
    // --------------------------------------------------------

    const token = createToken(user);

    return res.json({
      success: true,
      message: "Login successful.",
      token,
      user: publicUser(user),
    });
  } catch (error) {
    console.error("LOGIN ERROR:", error);

    return res.status(500).json({
      success: false,
      message: "Login failed.",
    });
  }
});

// ============================================================
// GET CURRENT USER
// ============================================================

app.get("/api/auth/me", authenticate, async (req, res) => {
  return res.json({
    success: true,
    user: publicUser(req.user),
  });
});

// ============================================================
// LOGOUT
// ============================================================
// JWT logout is handled by deleting the token on the app.
// No Firebase Auth signOut is needed.
// ============================================================

app.post("/api/auth/logout", authenticate, async (req, res) => {
  return res.json({
    success: true,
    message: "Logged out successfully.",
  });
});

// ============================================================
// CHANGE PASSWORD
// ============================================================

app.post(
  "/api/auth/change-password",
  authenticate,
  async (req, res) => {
    try {
      if (!requireDatabase(res)) return;

      const currentPassword = String(
        req.body.currentPassword || ""
      );

      const newPassword = String(
        req.body.newPassword || ""
      );

      if (!currentPassword || !newPassword) {
        return res.status(400).json({
          success: false,
          message:
            "Current password and new password are required.",
        });
      }

      if (newPassword.length < 6) {
        return res.status(400).json({
          success: false,
          message:
            "New password must contain at least 6 characters.",
        });
      }

      const valid = await bcrypt.compare(
        currentPassword,
        req.user.passwordHash || ""
      );

      if (!valid) {
        return res.status(401).json({
          success: false,
          message: "Current password is incorrect.",
        });
      }

      const passwordHash = await bcrypt.hash(
        newPassword,
        12
      );

      await db
        .collection("users")
        .doc(req.user.id)
        .update({
          passwordHash,
          updatedAt: new Date().toISOString(),
        });

      return res.json({
        success: true,
        message: "Password changed successfully.",
      });
    } catch (error) {
      console.error("CHANGE PASSWORD ERROR:", error);

      return res.status(500).json({
        success: false,
        message: "Could not change password.",
      });
    }
  }
);

// ============================================================
// UPDATE PROFILE
// ============================================================

app.put("/api/user/profile", authenticate, async (req, res) => {
  try {
    if (!requireDatabase(res)) return;

    const updates = {};

    if (req.body.name !== undefined) {
      const name = cleanName(req.body.name);

      if (name.length < 2) {
        return res.status(400).json({
          success: false,
          message: "Name is too short.",
        });
      }

      updates.name = name;
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false,
        message: "No profile changes provided.",
      });
    }

    updates.updatedAt = new Date().toISOString();

    await db
      .collection("users")
      .doc(req.user.id)
      .update(updates);

    const updatedDoc = await db
      .collection("users")
      .doc(req.user.id)
      .get();

    const updatedUser = {
      id: updatedDoc.id,
      ...updatedDoc.data(),
    };

    return res.json({
      success: true,
      message: "Profile updated successfully.",
      user: publicUser(updatedUser),
    });
  } catch (error) {
    console.error("PROFILE UPDATE ERROR:", error);

    return res.status(500).json({
      success: false,
      message: "Could not update profile.",
    });
  }
});

// ============================================================
// USER DASHBOARD
// ============================================================

app.get("/api/dashboard", authenticate, async (req, res) => {
  return res.json({
    success: true,
    user: publicUser(req.user),

    rules: {
      baseMiningRate: 0.2,

      adBoostPerAd: 0.1,

      maxDailyAds: 7,

      maxAdBoost: 0.7,

      referralMiningBoost: 0.02,

      newUserReferralReward: 20,

      inviterReferralReward: 5,

      dailySocialReward: 10,
    },
  });
});

// ============================================================
// START MINING
// ============================================================

app.post("/api/mining/start", authenticate, async (req, res) => {
  try {
    if (!requireDatabase(res)) return;

    const userRef = db
      .collection("users")
      .doc(req.user.id);

    const userDoc = await userRef.get();

    const user = userDoc.data();

    const now = new Date();

    if (user.miningActive) {
      return res.status(400).json({
        success: false,
        message: "Mining is already active.",
      });
    }

    const miningEndsAt = new Date(
      now.getTime() + 24 * 60 * 60 * 1000
    );

    await userRef.update({
      miningActive: true,

      miningStartedAt: now.toISOString(),

      miningEndsAt: miningEndsAt.toISOString(),

      updatedAt: now.toISOString(),
    });

    return res.json({
      success: true,
      message: "Mining started.",

      mining: {
        active: true,

        startedAt: now.toISOString(),

        endsAt: miningEndsAt.toISOString(),

        miningRate: Number(
          user.miningRate || 0.2
        ),
      },
    });
  } catch (error) {
    console.error("START MINING ERROR:", error);

    return res.status(500).json({
      success: false,
      message: "Could not start mining.",
    });
  }
});

// ============================================================
// CLAIM MINING
// ============================================================

app.post("/api/mining/claim", authenticate, async (req, res) => {
  try {
    if (!requireDatabase(res)) return;

    const userRef = db
      .collection("users")
      .doc(req.user.id);

    const userDoc = await userRef.get();

    const user = userDoc.data();

    if (!user.miningActive) {
      return res.status(400).json({
        success: false,
        message: "Mining session is not active.",
      });
    }

    const now = new Date();

    const endsAt = new Date(
      user.miningEndsAt
    );

    if (now < endsAt) {
      return res.status(400).json({
        success: false,
        message: "Mining session has not ended yet.",
        endsAt: endsAt.toISOString(),
      });
    }

    const miningRate = Number(
      user.miningRate || 0.2
    );

    const reward = miningRate * 24;

    const currentBalance = Number(
      user.fanBalance || 0
    );

    const newBalance =
      currentBalance + reward;

    await userRef.update({
      fanBalance: newBalance,

      miningActive: false,

      miningStartedAt: null,

      miningEndsAt: null,

      dailyAdsWatched: 0,

      adBoost: 0,

      updatedAt: now.toISOString(),
    });

    return res.json({
      success: true,

      message: "Mining reward claimed.",

      reward,

      fanBalance: newBalance,

      miningActive: false,
    });
  } catch (error) {
    console.error("CLAIM MINING ERROR:", error);

    return res.status(500).json({
      success: false,
      message: "Could not claim mining reward.",
    });
  }
});

// ============================================================
// WATCH REWARDED AD
// ============================================================

app.post("/api/mining/ad", authenticate, async (req, res) => {
  try {
    if (!requireDatabase(res)) return;

    const userRef = db
      .collection("users")
      .doc(req.user.id);

    const userDoc = await userRef.get();

    const user = userDoc.data();

    const adsWatched = Number(
      user.dailyAdsWatched || 0
    );

    if (adsWatched >= 7) {
      return res.status(400).json({
        success: false,
        message:
          "You have reached the maximum of 7 rewarded ads today.",
      });
    }

    const newAdsWatched =
      adsWatched + 1;

    const newAdBoost =
      newAdsWatched * 0.1;

    await userRef.update({
      dailyAdsWatched: newAdsWatched,

      adBoost: newAdBoost,

      miningRate:
        0.2 +
        Number(user.activeReferrals || 0) *
          0.02 +
        newAdBoost,

      updatedAt: new Date().toISOString(),
    });

    return res.json({
      success: true,

      message: "Ad reward applied.",

      adsWatched: newAdsWatched,

      adBoost: newAdBoost,

      miningRate:
        0.2 +
        Number(user.activeReferrals || 0) *
          0.02 +
        newAdBoost,
    });
  } catch (error) {
    console.error("AD ERROR:", error);

    return res.status(500).json({
      success: false,
      message: "Could not apply ad reward.",
    });
  }
});

// ============================================================
// REFERRAL INFO
// ============================================================

app.get(
  "/api/referrals",
  authenticate,
  async (req, res) => {
    try {
      if (!requireDatabase(res)) return;

      const referrals = await db
        .collection("users")
        .where("referredBy", "==", req.user.id)
        .get();

      const list = referrals.docs.map((doc) => {
        const data = doc.data();

        return {
          id: doc.id,

          name: data.name || "",

          email: data.email || "",

          createdAt: data.createdAt || null,

          miningActive:
            Boolean(data.miningActive),
        };
      });

      return res.json({
        success: true,

        referralCode:
          req.user.referralCode || "",

        activeReferrals:
          Number(req.user.activeReferrals || 0),

        miningRate:
          Number(req.user.miningRate || 0.2),

        referrals: list,
      });
    } catch (error) {
      console.error("REFERRALS ERROR:", error);

      return res.status(500).json({
        success: false,
        message: "Could not load referrals.",
      });
    }
  }
);

// ============================================================
// 404
// ============================================================

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "API endpoint not found.",
    path: req.path,
  });
});

// ============================================================
// GLOBAL ERROR HANDLER
// ============================================================

app.use((error, req, res, next) => {
  console.error("GLOBAL ERROR:", error);

  res.status(500).json({
    success: false,
    message: "Internal server error.",
  });
});

// ============================================================
// START SERVER
// ============================================================

app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `POWER FAN NETWORK backend running on port ${PORT}`
  );

  console.log(
    `Authentication: Custom JWT`
  );

  console.log(
    `Firebase Authentication: DISABLED / NOT USED`
  );

  console.log(
    `Database: Firestore`
  );
});
