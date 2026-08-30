// ============================================================
// POWER FAN NETWORK
// CUSTOM BACKEND SERVER
// ============================================================
//
// Authentication:
//   Custom JWT + bcrypt
//
// Database:
//   Firestore ONLY
//
// Firebase Authentication:
//   NOT USED
//
// Firebase Realtime Database:
//   NOT USED
//
// Railway:
//   NOT REQUIRED BY CODE
//
// Render:
//   NOT REQUIRED BY CODE
// ============================================================

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit =
  require("express-rate-limit");

const {
  initializeFirebase,
} = require("./src/firebase");

const authRoutes =
  require("./src/routes/auth_routes");

const userRoutes =
  require("./src/routes/user_routes");

const miningRoutes =
  require("./src/routes/mining_routes");

// ============================================================
// APP
// ============================================================

const app =
  express();

// ============================================================
// CONFIG
// ============================================================

const PORT =
  Number(process.env.PORT) || 3000;

// ============================================================
// FIRESTORE
// ============================================================

initializeFirebase();

// ============================================================
// SECURITY
// ============================================================

app.use(
  helmet()
);

app.use(
  cors({
    origin: "*",

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
  })
);

app.use(
  express.json({
    limit: "2mb",
  })
);

app.use(
  express.urlencoded({
    extended: true,
    limit: "2mb",
  })
);

// ============================================================
// RATE LIMIT
// ============================================================

const authLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 30,

    standardHeaders:
      true,

    legacyHeaders:
      false,

    message: {
      success: false,

      message:
        "Too many authentication attempts. Please try again later.",
    },
  });

const apiLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 300,

    standardHeaders:
      true,

    legacyHeaders:
      false,

    message: {
      success: false,

      message:
        "Too many requests. Please try again later.",
    },
  });

// ============================================================
// HEALTH
// ============================================================

app.get(
  "/",
  (req, res) => {
    res.json({
      success: true,

      app:
        "POWER FAN NETWORK",

      backend:
        "Custom Backend",

      authentication:
        "JWT + bcrypt",

      firebaseAuthentication:
        false,

      realtimeDatabase:
        false,

      database:
        "Firestore",

      status:
        "online",

      version:
        "2.0.0",
    });
  }
);

app.get(
  "/health",
  (req, res) => {
    const db =
      require("./src/firebase")
        .getDb();

    res.json({
      success: true,

      status:
        "healthy",

      database:
        db
          ? "connected"
          : "disconnected",

      firebaseAuthentication:
        "disabled",

      realtimeDatabase:
        "disabled",

      time:
        new Date().toISOString(),
    });
  }
);

// ============================================================
// ROUTES
// ============================================================

app.use(
  "/api/auth",
  authLimiter,
  authRoutes
);

app.use(
  "/api/user",
  apiLimiter,
  userRoutes
);

app.use(
  "/api/mining",
  apiLimiter,
  miningRoutes
);

// ============================================================
// 404
// ============================================================

app.use(
  (req, res) => {
    res.status(404).json({
      success: false,

      message:
        "API endpoint not found.",

      path:
        req.path,
    });
  }
);

// ============================================================
// GLOBAL ERROR
// ============================================================

app.use(
  (
    error,
    req,
    res,
    next
  ) => {
    console.error(
      "GLOBAL ERROR:",
      error
    );

    if (
      res.headersSent
    ) {
      return next(error);
    }

    res.status(500).json({
      success: false,

      message:
        "Internal server error.",
    });
  }
);

// ============================================================
// START
// ============================================================

app.listen(
  PORT,
  "0.0.0.0",
  () => {
    console.log("");
    console.log(
      "=========================================="
    );
    console.log(
      "POWER FAN NETWORK BACKEND"
    );
    console.log(
      "=========================================="
    );
    console.log(
      `Server: http://0.0.0.0:${PORT}`
    );
    console.log(
      "Authentication: CUSTOM JWT"
    );
    console.log(
      "Password: bcrypt"
    );
    console.log(
      "Firestore: ENABLED"
    );
    console.log(
      "Firebase Authentication: DISABLED"
    );
    console.log(
      "Realtime Database: DISABLED"
    );
    console.log(
      "=========================================="
    );
    console.log("");
  }
);
