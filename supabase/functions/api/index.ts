// supabase/functions/api/index.ts

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const admin = createClient(
  supabaseUrl,
  serviceRoleKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods":
    "GET, POST, PUT, PATCH, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function cleanEmail(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toLowerCase();
}

function cleanName(value: unknown): string {
  return String(value ?? "").trim();
}

function cleanReferralCode(value: unknown): string {
  return String(value ?? "")
    .trim()
    .toUpperCase();
}

function randomReferralCode(name: string): string {
  const prefix =
    name
      .replace(/[^a-zA-Z0-9]/g, "")
      .toUpperCase()
      .substring(0, 5) || "FAN";

  const random =
    Math.floor(
      100000 + Math.random() * 900000,
    );

  return `${prefix}${random}`;
}

function nowIso(): string {
  return new Date().toISOString();
}

async function getUserFromRequest(
  request: Request,
) {
  const authHeader =
    request.headers.get("Authorization") ?? "";

  if (!authHeader.startsWith("Bearer ")) {
    return null;
  }

  const token =
    authHeader.substring(7).trim();

  if (!token) {
    return null;
  }

  const {
    data,
    error,
  } = await admin.auth.getUser(token);

  if (error || !data.user) {
    return null;
  }

  return data.user;
}

async function getProfile(
  userId: string,
) {
  const { data, error } =
    await admin
      .from("profiles")
      .select("*")
      .eq("id", userId)
      .maybeSingle();

  if (error) {
    throw error;
  }

  return data;
}

function publicProfile(
  profile: Record<string, unknown>,
) {
  return {
    id: profile.id,
    name: profile.name ?? "",
    email: profile.email ?? "",
    referralCode:
      profile.referral_code ?? "",
    referredBy:
      profile.referred_by ?? null,

    fanBalance:
      Number(profile.fan_balance ?? 0),

    afamBalance:
      Number(profile.afam_balance ?? 0),

    miningRate:
      Number(profile.mining_rate ?? 0.2),

    activeReferrals:
      Number(profile.active_referrals ?? 0),

    dailyAdsWatched:
      Number(profile.daily_ads_watched ?? 0),

    adBoost:
      Number(profile.ad_boost ?? 0),

    miningActive:
      Boolean(profile.mining_active),

    miningStartedAt:
      profile.mining_started_at ?? null,

    miningEndsAt:
      profile.mining_ends_at ?? null,

    consecutiveCheckIns:
      Number(
        profile.consecutive_check_ins ?? 0,
      ),

    kyc1Eligible:
      Boolean(profile.kyc1_eligible),

    kyc1Verified:
      Boolean(profile.kyc1_verified),

    kyc2Eligible:
      Boolean(profile.kyc2_eligible),

    kyc2Verified:
      Boolean(profile.kyc2_verified),

    kyc3Verified:
      Boolean(profile.kyc3_verified),

    createdAt:
      profile.created_at ?? null,

    updatedAt:
      profile.updated_at ?? null,
  };
}

async function dashboard(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const profile =
    await getProfile(user.id);

  if (!profile) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  return json({
    success: true,

    user: publicProfile(profile),

    rules: {
      baseMiningRate: 0.2,
      adBoostPerAd: 0.1,
      maxDailyAds: 7,
      maxAdBoost: 0.7,
      referralMiningBoost: 0.02,
      newUserReferralReward: 20,
      inviterReferralReward: 5,
      dailySocialReward: 10,
      miningHours: 24,
    },
  });
}

async function startMining(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const profile =
    await getProfile(user.id);

  if (!profile) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  if (profile.mining_active) {
    return json(
      {
        success: false,
        message:
          "Mining is already active.",
      },
      400,
    );
  }

  const started =
    new Date();

  const ends =
    new Date(
      started.getTime() +
        24 * 60 * 60 * 1000,
    );

  const { error } =
    await admin
      .from("profiles")
      .update({
        mining_active: true,
        mining_started_at:
          started.toISOString(),
        mining_ends_at:
          ends.toISOString(),
        updated_at: nowIso(),
      })
      .eq("id", user.id);

  if (error) {
    return json(
      {
        success: false,
        message:
          "Could not start mining.",
      },
      500,
    );
  }

  return json({
    success: true,
    message: "Mining started.",
    mining: {
      active: true,
      startedAt:
        started.toISOString(),
      endsAt:
        ends.toISOString(),
      miningRate:
        Number(profile.mining_rate ?? 0.2),
    },
  });
}

async function claimMining(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const profile =
    await getProfile(user.id);

  if (!profile) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  if (!profile.mining_active) {
    return json(
      {
        success: false,
        message:
          "Mining session is not active.",
      },
      400,
    );
  }

  if (!profile.mining_ends_at) {
    return json(
      {
        success: false,
        message:
          "Mining end time is missing.",
      },
      400,
    );
  }

  const ends =
    new Date(
      profile.mining_ends_at,
    );

  if (new Date() < ends) {
    return json(
      {
        success: false,
        message:
          "Mining session has not ended yet.",
        endsAt:
          ends.toISOString(),
      },
      400,
    );
  }

  const rate =
    Number(profile.mining_rate ?? 0.2);

  const reward =
    rate * 24;

  const balance =
    Number(profile.fan_balance ?? 0);

  const newBalance =
    balance + reward;

  const referrals =
    Number(
      profile.active_referrals ?? 0,
    );

  const baseRate =
    0.2 + referrals * 0.02;

  const { error } =
    await admin
      .from("profiles")
      .update({
        fan_balance: newBalance,
        mining_active: false,
        mining_started_at: null,
        mining_ends_at: null,
        daily_ads_watched: 0,
        ad_boost: 0,
        mining_rate: baseRate,
        updated_at: nowIso(),
      })
      .eq("id", user.id);

  if (error) {
    return json(
      {
        success: false,
        message:
          "Could not claim mining reward.",
      },
      500,
    );
  }

  return json({
    success: true,
    message:
      "Mining reward claimed.",
    reward,
    fanBalance: newBalance,
    miningActive: false,
  });
}

async function watchAd(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const profile =
    await getProfile(user.id);

  if (!profile) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  const ads =
    Number(
      profile.daily_ads_watched ?? 0,
    );

  if (ads >= 7) {
    return json(
      {
        success: false,
        message:
          "You have reached the maximum of 7 rewarded ads today.",
      },
      400,
    );
  }

  const newAds = ads + 1;

  const adBoost =
    newAds * 0.1;

  const referralBoost =
    Number(
      profile.active_referrals ?? 0,
    ) * 0.02;

  const rate =
    0.2 +
    referralBoost +
    adBoost;

  const { error } =
    await admin
      .from("profiles")
      .update({
        daily_ads_watched: newAds,
        ad_boost: adBoost,
        mining_rate: rate,
        updated_at: nowIso(),
      })
      .eq("id", user.id);

  if (error) {
    return json(
      {
        success: false,
        message:
          "Could not apply ad reward.",
      },
      500,
    );
  }

  return json({
    success: true,
    message:
      "Ad reward applied.",
    adsWatched: newAds,
    adBoost,
    miningRate: rate,
  });
}

async function referrals(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const profile =
    await getProfile(user.id);

  if (!profile) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  const { data, error } =
    await admin
      .from("profiles")
      .select(
        "id,name,email,created_at,mining_active",
      )
      .eq(
        "referred_by",
        user.id,
      )
      .order(
        "created_at",
        { ascending: false },
      );

  if (error) {
    return json(
      {
        success: false,
        message:
          "Could not load referrals.",
      },
      500,
    );
  }

  return json({
    success: true,

    referralCode:
      profile.referral_code ?? "",

    activeReferrals:
      Number(
        profile.active_referrals ?? 0,
      ),

    miningRate:
      Number(
        profile.mining_rate ?? 0.2,
      ),

    referrals:
      (data ?? []).map(
        (item) => ({
          id: item.id,
          name: item.name ?? "",
          email: item.email ?? "",
          createdAt:
            item.created_at ?? null,
          miningActive:
            Boolean(item.mining_active),
        }),
      ),
  });
}

async function applyReferral(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const body =
    await request.json().catch(
      () => ({}),
    );

  const code =
    cleanReferralCode(
      body.referralCode,
    );

  if (!code) {
    return json(
      {
        success: false,
        message:
          "Referral code is required.",
      },
      400,
    );
  }

  const current =
    await getProfile(user.id);

  if (!current) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  if (current.referred_by) {
    return json(
      {
        success: false,
        message:
          "Referral has already been applied.",
      },
      400,
    );
  }

  if (
    current.referral_code === code
  ) {
    return json(
      {
        success: false,
        message:
          "You cannot use your own referral code.",
      },
      400,
    );
  }

  const {
    data: referrer,
    error: referrerError,
  } = await admin
    .from("profiles")
    .select("*")
    .eq("referral_code", code)
    .maybeSingle();

  if (referrerError) {
    return json(
      {
        success: false,
        message:
          "Could not verify referral code.",
      },
      500,
    );
  }

  if (!referrer) {
    return json(
      {
        success: false,
        message:
          "Invalid referral code.",
      },
      400,
    );
  }

  const referrals =
    Number(
      referrer.active_referrals ?? 0,
    ) + 1;

  const newRate =
    0.2 + referrals * 0.02;

  const newBalance =
    Number(
      referrer.fan_balance ?? 0,
    ) + 5;

  const userBalance =
    Number(
      current.fan_balance ?? 0,
    ) + 20;

  const { error: userError } =
    await admin
      .from("profiles")
      .update({
        referred_by: referrer.id,
        fan_balance: userBalance,
        updated_at: nowIso(),
      })
      .eq("id", user.id);

  if (userError) {
    return json(
      {
        success: false,
        message:
          "Could not apply referral.",
      },
      500,
    );
  }

  const { error: referrerUpdateError } =
    await admin
      .from("profiles")
      .update({
        fan_balance: newBalance,
        active_referrals: referrals,
        mining_rate: newRate,
        updated_at: nowIso(),
      })
      .eq("id", referrer.id);

  if (referrerUpdateError) {
    return json(
      {
        success: false,
        message:
          "Referral was not completed.",
      },
      500,
    );
  }

  return json({
    success: true,
    message:
      "Referral applied successfully.",
    reward: 20,
  });
}

async function socialClaim(
  request: Request,
) {
  const user =
    await getUserFromRequest(request);

  if (!user) {
    return json(
      {
        success: false,
        message:
          "Authentication required.",
      },
      401,
    );
  }

  const profile =
    await getProfile(user.id);

  if (!profile) {
    return json(
      {
        success: false,
        message:
          "User profile not found.",
      },
      404,
    );
  }

  const today =
    new Date()
      .toISOString()
      .slice(0, 10);

  const lastClaim =
    profile.last_social_claim_date
      ? String(
          profile.last_social_claim_date,
        ).slice(0, 10)
      : null;

  if (lastClaim === today) {
    return json(
      {
        success: false,
        message:
          "Today's social reward has already been claimed.",
      },
      400,
    );
  }

  const newBalance =
    Number(
      profile.fan_balance ?? 0,
    ) + 10;

  const { error } =
    await admin
      .from("profiles")
      .update({
        fan_balance: newBalance,
        last_social_claim_date:
          today,
        updated_at: nowIso(),
      })
      .eq("id", user.id);

  if (error) {
    return json(
      {
        success: false,
        message:
          "Could not claim social reward.",
      },
      500,
    );
  }

  return json({
    success: true,
    message:
      "Social reward claimed.",
    reward: 10,
    fanBalance: newBalance,
  });
}

async function health() {
  const {
    error,
  } = await admin
    .from("profiles")
    .select("id")
    .limit(1);

  return json({
    success: true,
    status: "healthy",
    database:
      error ? "error" : "connected",
    firebaseAuthentication: false,
    authentication:
      "Supabase Auth",
    time: nowIso(),
  });
}

async function handle(
  request: Request,
) {
  if (
    request.method === "OPTIONS"
  ) {
    return new Response(
      null,
      {
        status: 204,
        headers: corsHeaders,
      },
    );
  }

  const url =
    new URL(request.url);

  const path =
    url.pathname.replace(
      /^\/functions\/v1\/api/,
      "",
    );

  try {
    if (
      path === "/health" &&
      request.method === "GET"
    ) {
      return await health();
    }

    if (
      path === "/dashboard" &&
      request.method === "GET"
    ) {
      return await dashboard(
        request,
      );
    }

    if (
      path === "/mining/start" &&
      request.method === "POST"
    ) {
      return await startMining(
        request,
      );
    }

    if (
      path === "/mining/claim" &&
      request.method === "POST"
    ) {
      return await claimMining(
        request,
      );
    }

    if (
      path === "/mining/ad" &&
      request.method === "POST"
    ) {
      return await watchAd(
        request,
      );
    }

    if (
      path === "/referrals" &&
      request.method === "GET"
    ) {
      return await referrals(
        request,
      );
    }

    if (
      path === "/referral/apply" &&
      request.method === "POST"
    ) {
      return await applyReferral(
        request,
      );
    }

    if (
      path === "/social/claim" &&
      request.method === "POST"
    ) {
      return await socialClaim(
        request,
      );
    }

    return json(
      {
        success: false,
        message:
          "API endpoint not found.",
        path,
      },
      404,
    );
  } catch (error) {
    console.error(
      "API ERROR:",
      error,
    );

    return json(
      {
        success: false,
        message:
          "Internal server error.",
      },
      500,
    );
  }
}

Deno.serve(handle);
