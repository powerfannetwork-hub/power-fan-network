-- ============================================================
-- POWER FAN NETWORK
-- MINING ENGINE
-- ============================================================
--
-- Rules:
-- Base mining rate       = 0.20 FAN/H
-- Mining duration        = 24 hours
-- Referral bonus         = +0.02 FAN/H per active referral
-- Rewarded ad boost      = +0.10 FAN/H per verified ad
-- Maximum ads/session    = 7
--
-- IMPORTANT:
-- Ad boosts are NOT retroactive.
-- Referral boosts are NOT retroactive.
--
-- Example:
-- Mining starts 00:00
-- Referral becomes active 04:00
-- Referral bonus applies only 04:00 -> 24:00
--
-- Ad watched 06:00
-- +0.10 FAN/H applies only 06:00 -> 24:00
--
-- PostgreSQL server time is the source of truth.
-- ============================================================


-- ============================================================
-- 1. CONSTANTS
-- ============================================================

create or replace function public.pf_base_mining_rate()
returns numeric
language sql
immutable
as $$
    select 0.20::numeric;
$$;


create or replace function public.pf_referral_bonus_rate()
returns numeric
language sql
immutable
as $$
    select 0.02::numeric;
$$;


create or replace function public.pf_ad_bonus_rate()
returns numeric
language sql
immutable
as $$
    select 0.10::numeric;
$$;


create or replace function public.pf_mining_duration()
returns interval
language sql
immutable
as $$
    select interval '24 hours';
$$;


create or replace function public.pf_max_ads()
returns integer
language sql
immutable
as $$
    select 7;
$$;


-- ============================================================
-- 2. ACTIVE REFERRALS
-- ============================================================
--
-- A referral is considered active while the referred user's
-- mining session is active.
--
-- We intentionally calculate the count from mining_sessions
-- instead of trusting profiles.active_referrals.
-- ============================================================

create or replace function public.calculate_active_referrals(
    p_user_id uuid
)
returns integer
language sql
security definer
set search_path = public
stable
as $$
    select count(*)::integer
    from public.profiles referred
    where referred.referred_by = p_user_id
      and referred.mining_active = true;
$$;


-- ============================================================
-- 3. CURRENT USER MINING RATE
-- ============================================================
--
-- This is a DISPLAY/CURRENT-RATE function.
--
-- It does NOT determine historical claim reward.
-- Historical reward is calculated by claim_mining().
-- ============================================================

create or replace function public.get_user_mining_rate()
returns numeric
language plpgsql
security definer
set search_path = public
stable
as $$
declare
    v_user_id uuid;
    v_active_referrals integer;
    v_ads integer;
    v_rate numeric;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    v_active_referrals :=
        public.calculate_active_referrals(v_user_id);

    select count(*)::integer
    into v_ads
    from public.ad_rewards ar
    where ar.user_id = v_user_id
      and ar.watched_at >= (
          select ms.started_at
          from public.mining_sessions ms
          where ms.user_id = v_user_id
            and ms.claimed = false
            and ms.started_at <= now()
            and ms.ends_at > now()
          order by ms.started_at desc
          limit 1
      );

    v_ads := least(
        greatest(coalesce(v_ads, 0), 0),
        public.pf_max_ads()
    );

    v_rate :=
        public.pf_base_mining_rate()
        + (
            coalesce(v_active_referrals, 0)
            * public.pf_referral_bonus_rate()
        )
        + (
            coalesce(v_ads, 0)
            * public.pf_ad_bonus_rate()
        );

    return round(v_rate, 4);
end;
$$;


-- ============================================================
-- 4. START MINING
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
    v_user_id uuid;
    v_now timestamptz;
    v_existing public.mining_sessions%rowtype;
    v_session_id uuid;
    v_start timestamptz;
    v_end timestamptz;
    v_referrals integer;
    v_rate numeric;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    v_now := now();

    -- Lock profile so two simultaneous start requests
    -- cannot create two sessions.
    perform 1
    from public.profiles
    where id = v_user_id
    for update;

    -- Check for an existing unclaimed active session.
    select *
    into v_existing
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and ends_at > v_now
    order by started_at desc
    limit 1
    for update;

    if found then
        return jsonb_build_object(
            'success', true,
            'active', true,
            'is_mining', true,
            'mining_active', true,
            'session_id', v_existing.id,
            'started_at', v_existing.started_at,
            'ends_at', v_existing.ends_at,
            'remaining_seconds',
                greatest(
                    0,
                    floor(
                        extract(
                            epoch from
                            (v_existing.ends_at - v_now)
                        )
                    )::integer
                ),
            'elapsed_seconds',
                greatest(
                    0,
                    floor(
                        extract(
                            epoch from
                            (v_now - v_existing.started_at)
                        )
                    )::integer
                ),
            'mining_rate', v_existing.mining_rate,
            'active_referrals',
                public.calculate_active_referrals(v_user_id)
        );
    end if;

    -- Check if an unclaimed session has expired.
    -- It must be claimable before a new one can start.
    select *
    into v_existing
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
    order by started_at desc
    limit 1
    for update;

    if found then
        if v_existing.ends_at <= v_now then
            return jsonb_build_object(
                'success', false,
                'active', false,
                'claimable', true,
                'session_finished', true,
                'message', 'Mining session is complete. Claim your reward first.'
            );
        end if;
    end if;

    v_start := v_now;
    v_end := v_now + public.pf_mining_duration();

    -- Referral count at session start is stored only as a
    -- snapshot/display value.
    --
    -- IMPORTANT:
    -- claim_mining() does NOT use this value to retroactively
    -- calculate referral rewards.
    v_referrals :=
        public.calculate_active_referrals(v_user_id);

    v_rate :=
        public.pf_base_mining_rate()
        + (
            v_referrals
            * public.pf_referral_bonus_rate()
        );

    insert into public.mining_sessions (
        user_id,
        started_at,
        ends_at,
        mining_rate,
        claimed,
        created_at
    )
    values (
        v_user_id,
        v_start,
        v_end,
        round(v_rate, 4),
        false,
        v_now
    )
    returning id into v_session_id;

    update public.profiles
    set
        mining_active = true,
        mining_started_at = v_start,
        mining_ends_at = v_end,
        mining_rate = round(v_rate, 4),
        ad_boost = 0,
        daily_ads_watched = 0,
        updated_at = v_now
    where id = v_user_id;

    return jsonb_build_object(
        'success', true,
        'active', true,
        'is_mining', true,
        'mining_active', true,
        'session_id', v_session_id,
        'started_at', v_start,
        'ends_at', v_end,
        'remaining_seconds', 86400,
        'elapsed_seconds', 0,
        'mining_rate', round(v_rate, 4),
        'active_referrals', v_referrals,
        'ads_watched', 0,
        'ad_boost', 0
    );
end;
$$;


-- ============================================================
-- 5. GET ACTIVE MINING
-- ============================================================

create or replace function public.get_active_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;
    v_now timestamptz;
    v_ads integer;
    v_referrals integer;
    v_ad_boost numeric;
    v_current_rate numeric;
    v_elapsed integer;
    v_remaining integer;
    v_claimable boolean;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    v_now := now();

    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
    order by started_at desc
    limit 1;

    if not found then
        return jsonb_build_object(
            'success', true,
            'active', false,
            'is_mining', false,
            'mining_active', false,
            'expired', false,
            'claimable', false,
            'session_finished', false,
            'remaining_seconds', 0,
            'elapsed_seconds', 0,
            'ads_watched', 0,
            'ad_boost', 0,
            'active_referrals', 0,
            'mining_rate', public.pf_base_mining_rate(),
            'reward', 0
        );
    end if;

    v_elapsed := greatest(
        0,
        least(
            86400,
            floor(
                extract(
                    epoch from
                    least(v_now, v_session.ends_at)
                    - v_session.started_at
                )
            )::integer
        )
    );

    v_remaining := greatest(
        0,
        floor(
            extract(
                epoch from
                (v_session.ends_at - v_now)
        )
        )::integer
    );

    v_claimable := v_now >= v_session.ends_at;

    select count(*)::integer
    into v_ads
    from public.ad_rewards
    where user_id = v_user_id
      and watched_at >= v_session.started_at
      and watched_at <= v_session.ends_at;

    v_ads := least(
        greatest(coalesce(v_ads, 0), 0),
        public.pf_max_ads()
    );

    v_ad_boost :=
        v_ads * public.pf_ad_bonus_rate();

    v_referrals :=
        public.calculate_active_referrals(v_user_id);

    v_current_rate :=
        public.pf_base_mining_rate()
        + (
            v_referrals
            * public.pf_referral_bonus_rate()
        )
        + v_ad_boost;

    return jsonb_build_object(
        'success', true,
        'active', not v_claimable,
        'is_mining', not v_claimable,
        'mining_active', not v_claimable,
        'expired', v_claimable,
        'claimable', v_claimable,
        'session_finished', v_claimable,
        'session_id', v_session.id,
        'started_at', v_session.started_at,
        'start_time', v_session.started_at,
        'ends_at', v_session.ends_at,
        'end_time', v_session.ends_at,
        'remaining_seconds', v_remaining,
        'elapsed_seconds', v_elapsed,
        'ads_watched', v_ads,
        'ad_count', v_ads,
        'ads_count', v_ads,
        'ad_boost', round(v_ad_boost, 4),
        'active_referrals', v_referrals,
        'referrals', v_referrals,
        'mining_rate', round(v_current_rate, 4),
        'rate', round(v_current_rate, 4),
        'reward', 0
    );
end;
$$;


-- ============================================================
-- 6. RECORD REWARDED AD
-- ============================================================
--
-- Called by Flutter after LevelPlay reports a reward.
--
-- NOTE:
-- This records the rewarded event.
-- Real production anti-fraud should additionally use
-- ad-network/server-to-server verification.
--
-- The function itself never credits FAN balance.
-- ============================================================

create or replace function public.record_rewarded_ad()
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;
    v_now timestamptz;
    v_count integer;
    v_ad_id uuid;
    v_ad_number integer;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    v_now := now();

    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and started_at <= v_now
      and ends_at > v_now
    order by started_at desc
    limit 1
    for update;

    if not found then
        return jsonb_build_object(
            'success', false,
            'message', 'No active mining session.'
        );
    end if;

    select count(*)::integer
    into v_count
    from public.ad_rewards
    where user_id = v_user_id
      and watched_at >= v_session.started_at
      and watched_at <= v_session.ends_at;

    if v_count >= public.pf_max_ads() then
        return jsonb_build_object(
            'success', false,
            'message', 'Maximum 7 ads reached for this mining session.',
            'ads_watched', public.pf_max_ads()
        );
    end if;

    v_ad_number := v_count + 1;

    insert into public.ad_rewards (
        user_id,
        session_id,
        ad_number,
        watched_at,
        reward_amount
    )
    values (
        v_user_id,
        v_session.id,
        v_ad_number,
        v_now,
        public.pf_ad_bonus_rate()
    )
    returning id into v_ad_id;

    -- Update profile only for current/display state.
    update public.profiles
    set
        daily_ads_watched = v_ad_number,
        ad_boost =
            v_ad_number * public.pf_ad_bonus_rate(),
        updated_at = v_now
    where id = v_user_id;

    return jsonb_build_object(
        'success', true,
        'ad_id', v_ad_id,
        'ad_number', v_ad_number,
        'ad_boost',
            round(
                v_ad_number * public.pf_ad_bonus_rate(),
                4
            ),
        'reward_rate',
            public.pf_ad_bonus_rate(),
        'ads_watched', v_ad_number
    );
end;
$$;


-- ============================================================
-- 7. VERIFY REWARDED AD
-- ============================================================
--
-- Compatible with Flutter:
--
-- verify_rewarded_ad(
--     p_ad_id => adId
-- )
--
-- This verifies that the recorded ad belongs to the
-- authenticated user and to a valid mining session.
-- ============================================================

create or replace function public.verify_rewarded_ad(
    p_ad_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
    v_user_id uuid;
    v_ad public.ad_rewards%rowtype;
    v_session public.mining_sessions%rowtype;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    select *
    into v_ad
    from public.ad_rewards
    where id = p_ad_id
      and user_id = v_user_id
    limit 1;

    if not found then
        return jsonb_build_object(
            'success', false,
            'verified', false,
            'message', 'Rewarded ad was not found.'
        );
    end if;

    select *
    into v_session
    from public.mining_sessions
    where id = v_ad.session_id
      and user_id = v_user_id
    limit 1;

    if not found then
        return jsonb_build_object(
            'success', false,
            'verified', false,
            'message', 'Mining session was not found.'
        );
    end if;

    if v_ad.watched_at < v_session.started_at
       or v_ad.watched_at > v_session.ends_at then
        return jsonb_build_object(
            'success', false,
            'verified', false,
            'message', 'Ad is outside the mining session.'
        );
    end if;

    return jsonb_build_object(
        'success', true,
        'verified', true,
        'ad_id', v_ad.id,
        'ad_number', v_ad.ad_number,
        'reward_rate', v_ad.reward_amount,
        'watched_at', v_ad.watched_at
    );
end;
$$;


-- ============================================================
-- 8. CLAIM MINING
-- ============================================================
--
-- THIS IS THE IMPORTANT PART.
--
-- Reward is calculated by time segments:
--
-- Base:
--   0.20 FAN/H for all mining time
--
-- Referral:
--   +0.02 FAN/H only during the period in which each
--   referred user's mining session overlaps this session.
--
-- Ads:
--   +0.10 FAN/H from each ad's watched_at until session end.
--
-- Therefore no bonus is paid retroactively.
-- ============================================================

create or replace function public.claim_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
    v_user_id uuid;
    v_now timestamptz;

    v_session public.mining_sessions%rowtype;

    v_base_reward numeric := 0;
    v_referral_reward numeric := 0;
    v_ad_reward numeric := 0;
    v_total_reward numeric := 0;

    v_base_seconds bigint := 0;
    v_referral_seconds bigint := 0;
    v_ad_seconds bigint := 0;

    v_referral_count integer := 0;
    v_ad_count integer := 0;

    v_old_balance numeric := 0;
    v_new_balance numeric := 0;

    v_session_end timestamptz;
    v_claim_end timestamptz;

    r record;
begin
    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Not authenticated';
    end if;

    v_now := now();

    -- Lock profile.
    select fan_balance
    into v_old_balance
    from public.profiles
    where id = v_user_id
    for update;

    if not found then
        raise exception 'Profile not found.';
    end if;

    -- Lock the latest unclaimed session.
    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
    order by started_at desc
    limit 1
    for update;

    if not found then
        return jsonb_build_object(
            'success', false,
            'claimed', false,
            'message', 'No mining session to claim.'
        );
    end if;

    -- A mining session must complete before claiming.
    if v_now < v_session.ends_at then
        return jsonb_build_object(
            'success', false,
            'claimed', false,
            'claimable', false,
            'remaining_seconds',
                floor(
                    extract(
                        epoch from
                        (v_session.ends_at - v_now)
                    )
                )::integer,
            'message', 'Mining session is still active.'
        );
    end if;

    v_session_end := v_session.ends_at;
    v_claim_end := v_session.ends_at;

    -- ========================================================
    -- BASE REWARD
    -- ========================================================

    v_base_seconds := greatest(
        0,
        floor(
            extract(
                epoch from
                (v_session_end - v_session.started_at)
            )
        )::bigint
    );

    v_base_reward :=
        public.pf_base_mining_rate()
        * (
            v_base_seconds::numeric / 3600.0
        );

    -- ========================================================
    -- REFERRAL REWARD
    -- ========================================================
    --
    -- For every referred user:
    --
    -- referred mining start
    --       ->
    -- referred mining end
    --
    -- is intersected with:
    --
    -- inviter session start
    --       ->
    -- inviter session end
    --
    -- Only the overlapping seconds receive +0.02 FAN/H.
    -- ========================================================

    for r in
        select
            referred.id,
            greatest(
                v_session.started_at,
                referred.mining_started_at
            ) as overlap_start,
            least(
                v_session_end,
                referred.mining_ends_at
            ) as overlap_end
        from public.profiles referred
        where referred.referred_by = v_user_id
          and referred.mining_started_at is not null
          and referred.mining_ends_at is not null
          and referred.mining_ends_at >
              v_session.started_at
          and referred.mining_started_at <
              v_session_end
    loop
        if r.overlap_end > r.overlap_start then

            v_referral_seconds :=
                v_referral_seconds
                + floor(
                    extract(
                        epoch from
                        (
                            r.overlap_end
                            - r.overlap_start
                        )
                    )
                )::bigint;

        end if;
    end loop;

    v_referral_count :=
        case
            when v_referral_seconds > 0 then
                (
                    select count(*)::integer
                    from public.profiles referred
                    where referred.referred_by = v_user_id
                      and referred.mining_started_at is not null
                      and referred.mining_ends_at is not null
                      and referred.mining_ends_at >
                          v_session.started_at
                      and referred.mining_started_at <
                          v_session_end
                )
            else 0
        end;

    v_referral_reward :=
        public.pf_referral_bonus_rate()
        * (
            v_referral_seconds::numeric / 3600.0
        );

    -- ========================================================
    -- AD REWARD
    -- ========================================================
    --
    -- Every verified/recorded ad creates a +0.10 FAN/H
    -- boost starting at watched_at.
    --
    -- For each ad:
    --
    -- watched_at -> session_end
    --
    -- receives the +0.10 rate.
    --
    -- Therefore:
    --
    -- Ad at hour 4:
    -- +0.10 for hours 4 -> 24
    --
    -- NOT:
    -- +0.10 for hours 0 -> 24
    -- ========================================================

    for r in
        select
            ar.id,
            ar.watched_at
        from public.ad_rewards ar
        where ar.user_id = v_user_id
          and ar.session_id = v_session.id
          and ar.watched_at >= v_session.started_at
          and ar.watched_at < v_session_end
        order by ar.watched_at asc
        limit 7
    loop
        v_ad_seconds :=
            v_ad_seconds
            + floor(
                extract(
                    epoch from
                    (
                        v_session_end
                        - r.watched_at
                    )
                )
            )::bigint;
    end loop;

    select count(*)::integer
    into v_ad_count
    from public.ad_rewards ar
    where ar.user_id = v_user_id
      and ar.session_id = v_session.id
      and ar.watched_at >= v_session.started_at
      and ar.watched_at < v_session_end;

    v_ad_count := least(
        greatest(coalesce(v_ad_count, 0), 0),
        public.pf_max_ads()
    );

    v_ad_reward :=
        public.pf_ad_bonus_rate()
        * (
            v_ad_seconds::numeric / 3600.0
        );

    -- ========================================================
    -- TOTAL
    -- ========================================================

    v_total_reward :=
        round(
            v_base_reward
            + v_referral_reward
            + v_ad_reward,
            8
        );

    -- Never allow negative rewards.
    if v_total_reward < 0 then
        v_total_reward := 0;
    end if;

    v_new_balance :=
        round(
            coalesce(v_old_balance, 0)
            + v_total_reward,
            8
        );

    -- ========================================================
    -- CREDIT BALANCE
    -- ========================================================

    update public.profiles
    set
        fan_balance = v_new_balance,
        mining_active = false,
        mining_started_at = null,
        mining_ends_at = null,
        mining_rate = public.pf_base_mining_rate(),
        ad_boost = 0,
        daily_ads_watched = 0,
        updated_at = v_now
    where id = v_user_id;

    -- ========================================================
    -- MARK SESSION CLAIMED
    -- ========================================================

    update public.mining_sessions
    set
        claimed = true,
        claimed_at = v_now,
        reward_amount = v_total_reward
    where id = v_session.id;

    -- ========================================================
    -- RESULT
    -- ========================================================

    return jsonb_build_object(
        'success', true,
        'claimed', true,
        'claimable', true,

        'session_id', v_session.id,

        'started_at', v_session.started_at,
        'ends_at', v_session.ends_at,
        'claimed_at', v_now,

        'base_rate',
            public.pf_base_mining_rate(),

        'base_reward',
            round(v_base_reward, 8),

        'referral_bonus_rate',
            public.pf_referral_bonus_rate(),

        'referral_reward',
            round(v_referral_reward, 8),

        'active_referrals',
            v_referral_count,

        'referral_seconds',
            v_referral_seconds,

        'ad_bonus_rate',
            public.pf_ad_bonus_rate(),

        'ads_watched',
            v_ad_count,

        'ad_reward',
            round(v_ad_reward, 8),

        'ad_seconds',
            v_ad_seconds,

        'reward',
            v_total_reward,

        'fan_balance_before',
            round(coalesce(v_old_balance, 0), 8),

        'fan_balance_after',
            v_new_balance
    );
end;
$$;


-- ============================================================
-- 9. SESSION AD COUNT
-- ============================================================

create or replace function public.get_session_ad_count(
    p_started_at timestamptz
)
returns integer
language sql
security definer
set search_path = public
stable
as $$
    select least(
        count(*)::integer,
        public.pf_max_ads()
    )
    from public.ad_rewards
    where user_id = auth.uid()
      and watched_at >= p_started_at
      and watched_at < p_started_at + public.pf_mining_duration();
$$;


-- ============================================================
-- 10. COMPLETE EXPIRED SESSIONS
-- ============================================================
--
-- Trusted/backend maintenance function.
-- It DOES NOT credit FAN.
-- User must claim to receive reward.
-- ============================================================

create or replace function public.complete_expired_mining_sessions()
returns integer
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
    v_count integer;
begin

    update public.profiles p
    set
        mining_active = false,
        updated_at = now()
    where p.mining_active = true
      and p.mining_ends_at is not null
      and p.mining_ends_at <= now()
      and exists (
          select 1
          from public.mining_sessions ms
          where ms.user_id = p.id
            and ms.claimed = false
            and ms.ends_at <= now()
      );

    get diagnostics v_count = row_count;

    return v_count;
end;
$$;


-- ============================================================
-- 11. REQUIRED COLUMNS FOR THE AD SESSION LINK
-- ============================================================
--
-- These statements make the engine compatible with the old
-- ad_rewards table while adding the missing session relation.
-- ============================================================

alter table public.ad_rewards
    add column if not exists session_id uuid;

alter table public.ad_rewards
    add column if not exists ad_number integer;

alter table public.ad_rewards
    add column if not exists reward_amount numeric(18,8);


-- ============================================================
-- 12. BACKFILL session_id / ad_number FOR EXISTING DATA
-- ============================================================
--
-- Only rows that can safely be matched to a user's unclaimed
-- session are linked.
--
-- Existing old rows that cannot be safely matched are left
-- untouched instead of guessing.
-- ============================================================

with ranked_ads as (
    select
        ar.id,
        ms.id as matched_session_id,
        row_number() over (
            partition by ms.id
            order by ar.watched_at asc, ar.id asc
        )::integer as calculated_ad_number
    from public.ad_rewards ar
    join public.mining_sessions ms
      on ms.user_id = ar.user_id
     and ar.watched_at >= ms.started_at
     and ar.watched_at < ms.ends_at
    where ar.session_id is null
)
update public.ad_rewards ar
set
    session_id = ranked_ads.matched_session_id,
    ad_number = ranked_ads.calculated_ad_number,
    reward_amount = coalesce(
        ar.reward_amount,
        public.pf_ad_bonus_rate()
    )
from ranked_ads
where ar.id = ranked_ads.id
  and ranked_ads.calculated_ad_number <= public.pf_max_ads();


-- ============================================================
-- 13. DEFAULTS / CONSTRAINTS
-- ============================================================

alter table public.ad_rewards
    alter column reward_amount
    set default 0.10;

alter table public.ad_rewards
    alter column ad_number
    set default 1;


-- ============================================================
-- 14. INDEXES
-- ============================================================

create index if not exists idx_mining_sessions_user_active
on public.mining_sessions (
    user_id,
    claimed,
    started_at,
    ends_at
);

create index if not exists idx_ad_rewards_user_session
on public.ad_rewards (
    user_id,
    session_id,
    watched_at
);

create index if not exists idx_profiles_referred_by
on public.profiles (
    referred_by
);

create index if not exists idx_profiles_mining_window
on public.profiles (
    mining_started_at,
    mining_ends_at
);


-- ============================================================
-- 15. UNIQUE AD NUMBER PER SESSION
-- ============================================================

create unique index if not exists
ux_ad_rewards_session_ad_number
on public.ad_rewards (
    session_id,
    ad_number
)
where session_id is not null
  and ad_number is not null;


-- ============================================================
-- 16. FUNCTION PERMISSIONS
-- ============================================================

revoke all on function public.start_mining() from public;
revoke all on function public.start_mining() from anon;
grant execute on function public.start_mining()
to authenticated;


revoke all on function public.get_active_mining() from public;
revoke all on function public.get_active_mining() from anon;
grant execute on function public.get_active_mining()
to authenticated;


revoke all on function public.get_user_mining_rate() from public;
revoke all on function public.get_user_mining_rate() from anon;
grant execute on function public.get_user_mining_rate()
to authenticated;


revoke all on function public.record_rewarded_ad() from public;
revoke all on function public.record_rewarded_ad() from anon;
grant execute on function public.record_rewarded_ad()
to authenticated;


revoke all on function public.verify_rewarded_ad(uuid) from public;
revoke all on function public.verify_rewarded_ad(uuid) from anon;
grant execute on function public.verify_rewarded_ad(uuid)
to authenticated;


revoke all on function public.claim_mining() from public;
revoke all on function public.claim_mining() from anon;
grant execute on function public.claim_mining()
to authenticated;


revoke all on function public.get_session_ad_count(timestamptz)
from public;

revoke all on function public.get_session_ad_count(timestamptz)
from anon;

grant execute on function public.get_session_ad_count(timestamptz)
to authenticated;


-- This is a trusted maintenance function.
-- Do NOT expose it to normal authenticated users.
revoke all on function public.complete_expired_mining_sessions()
from public;

revoke all on function public.complete_expired_mining_sessions()
from anon;

revoke all on function public.complete_expired_mining_sessions()
from authenticated;


-- calculate_active_referrals() is only needed internally.
-- Flutter currently calls it directly from ReferralService,
-- so authenticated execution is retained for compatibility.
revoke all on function public.calculate_active_referrals(uuid)
from public;

revoke all on function public.calculate_active_referrals(uuid)
from anon;

grant execute on function public.calculate_active_referrals(uuid)
to authenticated;


-- ============================================================
-- END OF MINING ENGINE
-- ============================================================
