// ============================================================
// POWER FAN NETWORK
// FILE: backend/src/server.js
// ============================================================
// CUSTOM BACKEND
//
// Authentication: Custom JWT
// Password Security: bcrypt
// Database: Firestore
// Firebase Authentication: NOT USED
//
// Routes:
// /api/auth
// /api/user
// /api/mining
// /api/referrals
// ============================================================

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const admin = require("firebase-admin");

// ============================================================
// ROUTES
// ============================================================

const authRoutes = require("./routes/auth_routes");
const userRoutes = require("./routes/user_routes");

// ============================================================
// APP
// ============================================================

const app = express();

// ============================================================
// CONFIG
// ============================================================

const PORT =
  Number(process.env.PORT) || 3000;

const NODE_ENV =
  process.env.NODE_ENV || "production";

// ============================================================
// FIREBASE ADMIN / FIRESTORE
// ============================================================
//
// Firebase Authentication ba a amfani da shi.
// Firebase Admin SDK ana amfani da shi ne domin Firestore.
// ============================================================

let db = null;

try {
  if (admin.apps.length === 0) {
    if (
      process.env.FIREBASE_SERVICE_ACCOUNT
    ) {
      const serviceAccount =
        JSON.parse(
          process.env.FIREBASE_SERVICE_ACCOUNT
        );

      admin.initializeApp({
        credential:
          admin.credential.cert(
            serviceAccount
          ),
        projectId:
          serviceAccount.project_id,
      });
    } else {
      admin.initializeApp();
    }
  }

  db = admin.firestore();

  console.log(
    "=========================================="
  );

  console.log(
    "POWER FAN NETWORK BACKEND"
  );

  console.log(
    "Firestore: CONNECTED"
  );

  console.log(
    "Firebase Authentication: NOT USED"
  );

  console.log(
    "Custom Authentication: ENABLED"
  );

  console.log(
    "=========================================="
  );
} catch (error) {
  console.error(
    "FIRESTORE INITIALIZATION ERROR:"
  );

  console.error(error.message);
}

// ============================================================
// SECURITY
// ============================================================

app.disable("x-powered-by");

app.use(
  helmet({
    crossOriginResourcePolicy: false,
  })
);

// ============================================================
// CORS
// ============================================================

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

// ============================================================
// BODY PARSER
// ============================================================

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
// RATE LIMITING
// ============================================================

const generalLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 300,

    standardHeaders: true,

    legacyHeaders: false,

    message: {
      success: false,

      error:
        "too_many_requests",

      message:
        "Too many requests. Please try again later.",
    },
  });

app.use(generalLimiter);

// ============================================================
// AUTH RATE LIMIT
// ============================================================

const authLimiter =
  rateLimit({
    windowMs:
      15 * 60 * 1000,

    max: 30,

    standardHeaders: true,

    legacyHeaders: false,

    message: {
      success: false,

      error:
        "too_many_auth_attempts",

      message:
        "Too many authentication attempts. Please try again later.",
    },
  });

// Apply stricter rate limit to auth endpoints
app.use(
  "/api/auth/login",
  authLimiter
);

app.use(
  "/api/auth/register",
  authLimiter
);

// ============================================================
// REQUEST LOG
// ============================================================

app.use(
  (req, res, next) => {
    const start =
      Date.now();

    res.on(
      "finish",
      () => {
        const duration =
          Date.now() - start;

        console.log(
          `${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`
        );
      }
    );

    next();
  }
);

// ============================================================
// ROOT
// ============================================================

app.get(
  "/",
  (req, res) => {
    res.status(200).json({
      success: true,

      app:
        "POWER FAN NETWORK",

      backend:
        "Custom Backend",

      version:
        "1.0.0",

      status:
        "online",

      authentication:
        "Custom JWT",

      firebaseAuthentication:
        false,

      database:
        db
          ? "Firestore"
          : "disconnected",

      time:
        new Date().toISOString(),
    });
  }
);

// ============================================================
// HEALTH CHECK
// ============================================================

app.get(
  "/health",
  (req, res) => {
    res.status(200).json({
      success: true,

      status:
        "healthy",

      database:
        db
          ? "connected"
          : "disconnected",

      firebaseAuthentication:
        "disabled",

      authentication:
        "custom-jwt",

      environment:
        NODE_ENV,

      time:
        new Date().toISOString(),
    });
  }
);

// ============================================================
// API STATUS
// ============================================================

app.get(
  "/api",
  (req, res) => {
    res.status(200).json({
      success: true,

      name:
        "POWER FAN NETWORK API",

      version:
        "1.0.0",

      status:
        "online",

      routes: {
        authentication:
          "/api/auth",

        user:
          "/api/user",

        mining:
          "/api/mining",

        referrals:
          "/api/referrals",
      },
    });
  }
);

// ============================================================
// AUTH ROUTES
// ============================================================

app.use(
  "/api/auth",
  authRoutes.router
);

// ============================================================
// USER ROUTES
// ============================================================

app.use(
  "/api/user",
  userRoutes.router
);

// ============================================================
// MINING ROUTES
// ============================================================
//
// Za mu ƙara mining_routes.js a mataki na gaba.
// A yanzu kada server ya kira file ɗin da bai wanzu ba.
// ============================================================

// ============================================================
// REFERRAL ROUTES
// ============================================================
//
// Za mu iya ƙara referral_routes.js daga baya.
// ============================================================

// ============================================================
// 404 HANDLER
// ============================================================

app.use(
  (req, res) => {
    res.status(404).json({
      success: false,

      error:
        "endpoint_not_found",

      message:
        "API endpoint not found.",

      path:
        req.originalUrl,
    });
  }
);

// ============================================================
// GLOBAL ERROR HANDLER
// ============================================================

app.use(
  (
    error,
    req,
    res,
    next
  ) => {
    console.error(
      "=========================================="
    );

    console.error(
      "GLOBAL SERVER ERROR"
    );

    console.error(error);

    console.error(
      "=========================================="
    );

    if (
      res.headersSent
    ) {
      return next(error);
    }

    res.status(500).json({
      success: false,

      error:
        "internal_server_error",

      message:
        "Internal server error.",

      ...(NODE_ENV ===
        "development"
        ? {
            details:
              error.message,
          }
        : {}),
    });
  }
);

// ============================================================
// START SERVER
// ============================================================

const server =
  app.listen(
    PORT,
    "0.0.0.0",
    () => {
      console.log(
        "=========================================="
      );

      console.log(
        "POWER FAN NETWORK BACKEND STARTED"
      );

      console.log(
        `Port: ${PORT}`
      );

      console.log(
        `Environment: ${NODE_ENV}`
      );

      console.log(
        "Authentication: CUSTOM JWT"
      );

      console.log(
        "Firebase Authentication: DISABLED"
      );

      console.log(
        `Firestore: ${
          db
            ? "CONNECTED"
            : "DISCONNECTED"
        }`
      );

      console.log(
        "=========================================="
      );
    }
  );

// ============================================================
// SERVER ERROR
// ============================================================

server.on(
  "error",
  (error) => {
    console.error(
      "SERVER ERROR:",
      error
    );

    if (
      error.code ===
      "EADDRINUSE"
    ) {
      console.error(
        `Port ${PORT} is already in use.`
      );
    }
  }
);

// ============================================================
// GRACEFUL SHUTDOWN
// ============================================================

async function shutdown(
  signal
) {
  console.log(
    `${signal} received. Shutting down...`
  );

  server.close(
    async () => {
      try {
        if (
          admin.apps.length > 0
        ) {
          await Promise.all(
            admin.apps.map(
              (firebaseApp) =>
                firebaseApp.delete()
            )
          );
        }
      } catch (error) {
        console.error(
          "Firebase shutdown error:",
          error.message
        );
      }

      console.log(
        "Server stopped."
      );

      process.exit(0);
    }
  );
}

process.on(
  "SIGTERM",
  () =>
    shutdown("SIGTERM")
);

process.on(
  "SIGINT",
  () =>
    shutdown("SIGINT")
);

// ============================================================
// UNHANDLED ERRORS
// ============================================================

process.on(
  "unhandledRejection",
  (reason) => {
    console.error(
      "UNHANDLED PROMISE REJECTION:",
      reason
    );
  }
);

process.on(
  "uncaughtException",
  (error) => {
    console.error(
      "UNCAUGHT EXCEPTION:",
      error
    );
  }
);

// ============================================================
// EXPORT
// ============================================================

module.exports = app;
