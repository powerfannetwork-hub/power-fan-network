// ============================================================
// POWER FAN NETWORK
// FILE: backend/src/server.js
// ============================================================
//
// CURRENT STAGE:
//
// Supabase:
// - Authentication / Register
// - Login
// - Email verification
// - User sessions
//
// Backend:
// - Server foundation only
// - Mining will be added next
// - Referrals will be added next
// - FAN/AFAM balances will be added next
// - KYC will be added next
// - Ads/rewards will be added next
//
// IMPORTANT:
// Supabase publishable key is NOT used as a secret here.
// Never put a Supabase secret/service-role key in Flutter.
// ============================================================

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");

const app = express();

// ============================================================
// CONFIG
// ============================================================

const PORT =
  Number(process.env.PORT || 3000);

const NODE_ENV =
  process.env.NODE_ENV || "production";

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
// RATE LIMIT
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
        "POWER FAN NETWORK BACKEND",

      version:
        "1.0.0",

      status:
        "online",

      authentication:
        "Supabase Auth",

      database:
        "Supabase",

      mining:
        "not enabled yet",

      time:
        new Date().toISOString(),
    });
  }
);

// ============================================================
// HEALTH
// ============================================================

app.get(
  "/health",
  (req, res) => {
    res.status(200).json({
      success: true,

      status:
        "healthy",

      authentication:
        "supabase",

      environment:
        NODE_ENV,

      time:
        new Date().toISOString(),
    });
  }
);

// ============================================================
// API
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
        health:
          "/health",

        mining:
          "coming soon",

        referrals:
          "coming soon",

        users:
          "coming soon",

        rewards:
          "coming soon",

        kyc:
          "coming soon",
      },
    });
  }
);

// ============================================================
// TEMPORARY AUTH STATUS
// ============================================================
//
// Register/Login ana faruwa kai tsaye tsakanin Flutter
// da Supabase Auth a wannan matakin.
//
// Backend zai karɓi authenticated requests daga Flutter
// lokacin da muka fara mining API.
// ============================================================

app.get(
  "/api/auth/status",
  (req, res) => {
    res.status(200).json({
      success: true,

      authentication:
        "Supabase Auth",

      message:
        "Authentication is handled by Supabase.",
    });
  }
);

// ============================================================
// FUTURE MINING ROUTES
// ============================================================
//
// Za mu ƙara:
//
// POST /api/mining/start
// POST /api/mining/claim
// POST /api/mining/ad
// GET  /api/mining/status
//
// a mataki na gaba.
// ============================================================

// ============================================================
// FUTURE REFERRAL ROUTES
// ============================================================
//
// Za mu ƙara:
//
// GET  /api/referrals
// POST /api/referrals/activate
//
// a mataki na gaba.
// ============================================================

// ============================================================
// 404
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
      "GLOBAL SERVER ERROR:",
      error
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
    });
  }
);

// ============================================================
// START
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
        " POWER FAN NETWORK BACKEND"
      );

      console.log(
        "=========================================="
      );

      console.log(
        `Port: ${PORT}`
      );

      console.log(
        `Environment: ${NODE_ENV}`
      );

      console.log(
        "Authentication: SUPABASE AUTH"
      );

      console.log(
        "Custom JWT: DISABLED"
      );

      console.log(
        "Firebase Authentication: DISABLED"
      );

      console.log(
        "Firestore Authentication: DISABLED"
      );

      console.log(
        "Mining: NOT ENABLED YET"
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
    () => {
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
