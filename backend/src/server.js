const express = require("express");
const cors = require("cors");

const app = express();

const PORT = process.env.PORT || 3000;

// ================================
// Middleware
// ================================

app.use(cors());
app.use(express.json());

// ================================
// Basic API information
// ================================

app.get("/", (req, res) => {
  res.json({
    success: true,
    app: "POWER FAN NETWORK",
    message: "Welcome to POWER FAN NETWORK API",
    version: "1.0.0",
    status: "running"
  });
});

// ================================
// Health check
// ================================

app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "ok",
    service: "POWER FAN NETWORK Backend",
    message: "Backend is running",
    time: new Date().toISOString()
  });
});

// ================================
// API status
// ================================

app.get("/api/status", (req, res) => {
  res.json({
    success: true,
    app: "POWER FAN NETWORK",
    backend: true,
    database: "Firebase",
    status: "online"
  });
});

// ================================
// Mining configuration
// ================================

app.get("/api/mining/config", (req, res) => {
  res.json({
    success: true,
    coin: "FAN",
    baseMiningRate: 0.2,
    adBoostPerAd: 0.1,
    maximumDailyAds: 7,
    maximumAdBoost: 0.7,
    maximumMiningRate: 0.9,
    miningSessionHours: 24
  });
});

// ================================
// Referral configuration
// ================================

app.get("/api/referral/config", (req, res) => {
  res.json({
    success: true,
    newUserReward: 20,
    inviterReward: 5,
    miningRatePerActiveReferral: 0.02
  });
});

// ================================
// Daily social reward
// ================================

app.get("/api/social/config", (req, res) => {
  res.json({
    success: true,
    dailyReward: 10,
    coin: "FAN"
  });
});

// ================================
// 404 handler
// ================================

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: "not_found",
    message: "API endpoint not found"
  });
});

// ================================
// Start server
// ================================

app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `POWER FAN NETWORK API running on port ${PORT}`
  );
});
