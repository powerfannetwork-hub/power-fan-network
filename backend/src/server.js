require("dotenv").config();

const express = require("express");
const cors = require("cors");

const app = express();

const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Test route
app.get("/health", (req, res) => {
  res.json({
    success: true,
    service: "POWER FAN NETWORK API",
    status: "ok",
    message: "POWER FAN backend is running",
    time: new Date().toISOString()
  });
});

// Root route
app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Welcome to POWER FAN NETWORK API"
  });
});

// 404
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: "not_found",
    message: "API endpoint not found"
  });
});

// Start server
app.listen(PORT, "0.0.0.0", () => {
  console.log(
    `POWER FAN NETWORK API running on port ${PORT}`
  );
});
