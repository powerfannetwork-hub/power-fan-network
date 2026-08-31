// ============================================================
// POWER FAN NETWORK
// CUSTOM BACKEND SERVER
// ============================================================
// Authentication: Custom JWT + bcrypt
// Database: Firestore
// Firebase Authentication: NOT USED
// ============================================================

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const admin = require("firebase-admin");

const authRoutes = require("./src/routes/auth_routes");

const app = express();

// ============================================================
// CONFIG
// ============================================================

const PORT = Number(process.env.PORT || 3000);

// ============================================================
// FIRESTORE
// ============================================================

let db = null;

try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const serviceAccount = JSON.parse(
      process.env.FIREBASE_SERVICE_ACCOUNT
    );

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } else {
    console.error(
      "WARNING: FIREBASE_SERVICE_ACCOUNT and GOOGLE_APPLICATION_CREDENTIALS are not set."
    );

    // Allows server to start, but database requests will return 503.
  }

  if (admin.apps.length > 0) {
    db = admin.firestore();

    console.log("Firestore initialized.");
  }
} catch (error) {
  console.error(
    "Firestore initialization failed:",
    error.message
  );
}

// ============================================================
// MIDDLEWARE
// ============================================================

app.disable("x-powered-by");

app.use(
  helmet({
    crossOriginResourcePolicy: false,
  })
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

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,

  standardHeaders: true,
  legacyHeaders: false,

  message: {
    success: false,
    message:
      "Too many authentication attempts. Please try again later.",
  },
});

app.use(
  "/api/auth/login",
  authLimiter
);

app.use(
  "/api/auth/register",
  authLimiter
);

// ============================================================
// DATABASE HELPER
// ============================================================

function getDatabase() {
  return db;
}

// ============================================================
// HEALTH
// ============================================================

app.get("/", (req, res) => {
  res.json({
    success: true,

    app: "POWER FAN NETWORK",

    backend: "Custom Backend",

    authentication: "Custom JWT + bcrypt",

    firebaseAuthentication: false,

    database: db
      ? "Firestore"
      : "Firestore not connected",

    status: "online",

    version: "1.0.0",
  });
});

app.get("/health", (req, res) => {
  res.json({
    success: true,

    status: "healthy",

    database: db
      ? "connected"
      : "disconnected",

    firebaseAuthentication: false,

    time: new Date().toISOString(),
  });
});

// ============================================================
// API ROUTES
// ============================================================

app.use(
  "/api/auth",
  authRoutes
);

// ============================================================
// SIMPLE USER INFO
// ============================================================

app.get(
  "/api/status",
  (req, res) => {
    res.json({
      success: true,
      app: "POWER FAN NETWORK",
      backend: "online",
      authentication: "JWT",
      database: db
        ? "connected"
        : "disconnected",
    });
  }
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

      path: req.path,
    });
  }
);

// ============================================================
// GLOBAL ERROR
// ============================================================

app.use(
  (error, req, res, next) => {
    console.error(
      "GLOBAL SERVER ERROR:",
      error
    );

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
      "================================================"
    );
    console.log(
      " POWER FAN NETWORK BACKEND"
    );
    console.log(
      "================================================"
    );

    console.log(
      `Server: http://0.0.0.0:${PORT}`
    );

    console.log(
      "Authentication: Custom JWT + bcrypt"
    );

    console.log(
      "Firebase Authentication: DISABLED"
    );

    console.log(
      `Firestore: ${
        db ? "CONNECTED" : "NOT CONNECTED"
      }`
    );

    console.log(
      "================================================"
    );
    console.log("");
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = {
  app,
  getDatabase,
};
