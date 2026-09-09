-- ============================================================
-- POWER FAN NETWORK
-- FINAL MINING ENGINE
-- ============================================================
--
-- BASE MINING RATE:        0.20 FAN/H
-- SESSION:                 24 HOURS
-- AD BOOST:                +0.10 FAN/H
-- MAX ADS:                 7 PER SESSION
-- REFERRAL BOOST:          +0.02 FAN/H PER ACTIVE REFERRAL
--
-- INACTIVITY PENALTY:
--   0-72h       = 0 FAN penalty
--   72-96h      = 0 FAN penalty
--   96-120h     = -20 FAN
--   Every 24h   = additional -20 FAN
--   Minimum     = 0 FAN
--
-- REWARD MODEL:
--   Base mining      = 0.20 FAN/H for full session
--   Ads              = +0.10 FAN/H from watched_at onward
--   Referrals        = +0.02 FAN/H while referred user's
--                      mining session is active
--
-- SERVER TIMESTAMPS ARE THE SOURCE OF TRUTH.
-- ============================================================


-- ============================================================
-- 1. INACTIVITY TRACKING COLUMNS
-- ============================================================

alter table public.profiles
add column if not exists last_mining_at timestamptz;

alter table public.profiles
add column if not exists inactivity_penalty_at timestamptz;


-- ============================================================
-- 2. ACTIVE REFERRALS
-- ============================================================

create or replace function public.calculate_active_referrals(
    p_user_id uuid
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
    select count(*)::integer
    from public.profiles referred
    where referred.referred_by = p_user_id
      and exists (
          select 1
          from public.mining_sessions rs
          where rs.user_id = referred.id
            and rs.claimed = false
            and rs.started_at < now()
            and rs.ends_at > now()
      );
$$;


-- ============================================================
-- 3. TIME-WEIGHTED AD REWARD
-- ============================================================

create or replace function public.calculate_ad_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
    v_reward numeric := 0;
begin

    select coalesce(
        sum(
            (
                extract(
                    epoch from (
                        p_ends_at
                        - greatest(
                            ar.watched_at,
                            p_started_at
                        )
                    )
                ) / 3600.0
            )
            *
            greatest(
                least(
                    coalesce(ar.reward_amount, 0.10),
                    0.10
                ),
                0
            )
        ),
        0
    )
    into v_reward
    from (
        select
            reward_amount,
            watched_at
        from public.ad_rewards
        where user_id = p_user_id
          and watched_at >= p_started_at
          and watched_at < p_ends_at
        order by watched_at asc, reward_amount desc
        limit 7
    ) ar
    where ar.watched_at < p_ends_at;

    return round(
        greatest(v_reward, 0),
        8
    );

end;
$function$;


-- ============================================================
-- 4. TIME-WEIGHTED REFERRAL REWARD
-- ============================================================

create or replace function public.calculate_referral_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
    v_reward numeric := 0;
begin

    select coalesce(
        sum(
            (
                extract(
                    epoch from (
                        least(
                            rs.ends_at,
                            p_ends_at
                        )
                        -
                        greatest(
                            rs.started_at,
                            p_started_at,
                            r.activated_at
                        )
                    )
                ) / 3600.0
            ) * 0.02
        ),
        0
    )
    into v_reward
    from public.profiles referred
    join public.mining_sessions rs
      on rs.user_id = referred.id
    join public.referrals r
      on r.referred_id = referred.id
     and r.referrer_id = p_user_id
    where referred.referred_by = p_user_id
      and r.activated_at is not null
      and rs.started_at < p_ends_at
      and rs.ends_at > p_started_at
      and greatest(
          rs.started_at,
          p_started_at,
          r.activated_at
      )
      <
      least(
          rs.ends_at,
          p_ends_at
      );

    return round(
        greatest(v_reward, 0),
        8
    );

end;
$function$;


-- ============================================================
-- 5. APPLY INACTIVITY PENALTY
-- ============================================================
--
-- 0-72 hours:
--     no penalty
--
-- 72-96 hours:
--     still no penalty
--
-- 96-120 hours:
--     -20 FAN
--
-- 120-144 hours:
--     another -20 FAN
--
-- Every additional 24 hours:
--     -20 FAN
--
-- Balance can never go below 0.
-- ============================================================

create or replace function public.apply_inactivity_penalty(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
    v_last_mining timestamptz;
    v_penalty_at timestamptz;

    v_now timestamptz := now();

    v_elapsed_hours numeric;
    v_due_periods integer;

    v_penalty numeric;
    v_old_balance numeric;
    v_new_balance numeric;
begin

    select
        last_mining_at,
        inactivity_penalty_at,
        coalesce(fan_balance, 0)
    into
        v_last_mining,
        v_penalty_at,
        v_old_balance
    from public.profiles
    where id = p_user_id
    for update;


    if not found then

        return jsonb_build_object(
            'success', false,
            'message', 'Profile not found'
        );

    end if;


    -- No mining history yet.
    if v_last_mining is null then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance
        );

    end if;


    v_elapsed_hours :=
        extract(
            epoch from (
                v_now - v_last_mining
            )
        ) / 3600.0;


    -- First 72 hours are penalty-free.
    if v_elapsed_hours <= 72 then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance,
            'inactive_hours',
                round(v_elapsed_hours, 2)
        );

    end if;


    -- First penalty becomes due at 96 hours.
    v_due_periods :=
        floor(
            (v_elapsed_hours - 72) / 24
        )::integer;


    if v_due_periods <= 0 then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance,
            'inactive_hours',
                round(v_elapsed_hours, 2)
        );

    end if;


    -- Prevent duplicate deductions.
    if v_penalty_at is not null then

        v_due_periods :=
            greatest(
                floor(
                    extract(
                        epoch from (
                            v_now - v_penalty_at
                        )
                    ) / 86400.0
                )::integer,
                0
            );

    end if;


    if v_due_periods <= 0 then

        return jsonb_build_object(
            'success', true,
            'penalty_applied', false,
            'penalty', 0,
            'fan_balance', v_old_balance,
            'inactive_hours',
                round(v_elapsed_hours, 2)
        );

    end if;


    v_penalty :=
        v_due_periods * 20.0;


    -- Never allow negative FAN balance.
    v_new_balance :=
        greatest(
            v_old_balance - v_penalty,
            0
        );


    update public.profiles
    set
        fan_balance = v_new_balance,

        inactivity_penalty_at =
            coalesce(
                inactivity_penalty_at,
                last_mining_at
                    + interval '72 hours'
            )
            +
            (
                v_due_periods
                * interval '24 hours'
            ),

        updated_at = v_now

    where id = p_user_id;


    return jsonb_build_object(
        'success', true,
        'penalty_applied', true,
        'penalty_periods', v_due_periods,
        'penalty', v_penalty,
        'old_balance', v_old_balance,
        'fan_balance', v_new_balance,
        'inactive_hours',
            round(v_elapsed_hours, 2)
    );

end;
$function$;


-- ============================================================
-- 6. CURRENT USER MINING RATE
-- ============================================================

create or replace function public.get_user_mining_rate()
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_session public.mining_sessions%rowtype;

    v_ads integer := 0;
    v_referrals integer := 0;

    v_rate numeric(12,4);
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and ends_at > now()
    order by started_at desc
    limit 1;


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    if v_session.id is not null then

        select count(*)::integer
        into v_ads
        from public.ad_rewards
        where user_id = v_user_id
          and session_id = v_session.id;

    end if;


    v_ads :=
        least(
            coalesce(v_ads, 0),
            7
        );


    v_rate :=
        round(
            0.20
            + (v_ads * 0.10)
            + (v_referrals * 0.02),
            4
        );


    update public.profiles
    set
        mining_rate = v_rate,
        active_referrals = v_referrals,
        daily_ads_watched = v_ads,
        ad_boost = round(
            v_ads * 0.10,
            4
        ),
        updated_at = now()
    where id = v_user_id;


    return v_rate;

end;
$$;


-- ============================================================
-- 7. USER-ID MINING RATE WRAPPER
-- ============================================================

create or replace function public.get_user_mining_rate(
    p_user_id uuid
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.get_user_mining_rate();

end;
$$;


-- ============================================================
-- 8. START MINING
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
    v_user_id uuid;

    v_existing public.mining_sessions%rowtype;

    v_session_id uuid;
    v_started_at timestamptz;
    v_ends_at timestamptz;

    v_referrals integer;
    v_rate numeric(12,4);

    v_penalty_result jsonb;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    -- Lock profile.
    perform 1
    from public.profiles
    where id = v_user_id
    for update;


    if not found then
        raise exception 'Profile not found';
    end if;


    -- Apply any inactivity penalty before starting.
    v_penalty_result :=
        public.apply_inactivity_penalty(
            v_user_id
        );


    -- Prevent concurrent/new sessions.
    select *
    into v_existing
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
    order by started_at desc
    limit 1
    for update;


    if found then

        -- Existing session is still active.
        if now() < v_existing.ends_at then

            return jsonb_build_object(
                'success', true,
                'already_active', true,
                'claim_required', false,
                'session_id', v_existing.id,
                'started_at', v_existing.started_at,
                'ends_at', v_existing.ends_at,
                'mining_rate',
                    public.get_user_mining_rate(),
                'status', 'active'
            );

        end if;


        -- Existing session expired and must be claimed.
        return jsonb_build_object(
            'success', false,
            'already_active', false,
            'claim_required', true,
            'expired', true,
            'session_id', v_existing.id,
            'started_at', v_existing.started_at,
            'ends_at', v_existing.ends_at,
            'status', 'claimable',
            'message',
                'Claim your completed mining session before starting a new one'
        );

    end if;


    -- New 24-hour session.
    v_started_at := now();

    v_ends_at :=
        v_started_at
        + interval '24 hours';


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    -- Base rate + active referral bonus.
    v_rate :=
        round(
            0.20
            + (v_referrals * 0.02),
            4
        );


    insert into public.mining_sessions (
        user_id,
        started_at,
        ends_at,
        mining_rate,
        claimed,
        reward_amount
    )
    values (
        v_user_id,
        v_started_at,
        v_ends_at,
        v_rate,
        false,
        0
    )
    returning id
    into v_session_id;


    update public.profiles
    set
        mining_active = true,

        mining_started_at =
            v_started_at,

        mining_ends_at =
            v_ends_at,

        mining_rate =
            v_rate,

        active_referrals =
            v_referrals,

        daily_ads_watched =
            0,

        ad_boost =
            0,

        -- RESET INACTIVITY CLOCK.
        last_mining_at =
            v_started_at,

        -- RESET PENALTY CLOCK.
        inactivity_penalty_at =
            null,

        updated_at =
            now()

    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'already_active', false,
        'claim_required', false,

        'session_id',
            v_session_id,

        'started_at',
            v_started_at,

        'ends_at',
            v_ends_at,

        'mining_rate',
            v_rate,

        'active_referrals',
            v_referrals,

        'ads_watched',
            0,

        'ad_boost',
            0,

        'status',
            'active',

        'inactivity_penalty',
            coalesce(
                v_penalty_result -> 'penalty',
                '0'::jsonb
            )
    );

end;
$function$;


-- ============================================================
-- 9. USER-ID START MINING WRAPPER
-- ============================================================

create or replace function public.start_mining(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.start_mining();

end;
$$;


-- ============================================================
-- 10. GET ACTIVE MINING
-- ============================================================

create or replace function public.get_active_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_ads integer := 0;
    v_referrals integer := 0;

    v_rate numeric(12,4);
    v_reward numeric(30,8);

    v_elapsed numeric;
    v_remaining numeric;

    v_until_now timestamptz;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


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
            'success', true,
            'active', false,
            'mining_active', false,
            'expired', false,
            'claimable', false,
            'reward', 0,
            'mining_rate', 0.20,
            'ads_watched', 0,
            'ad_boost', 0,
            'active_referrals', 0
        );

    end if;


    -- Session expired.
    if now() >= v_session.ends_at then

        update public.profiles
        set
            mining_active = false,
            mining_started_at = null,
            mining_ends_at = null,
            updated_at = now()
        where id = v_user_id;


        return jsonb_build_object(
            'success', true,
            'active', false,
            'mining_active', false,
            'expired', true,
            'claimable', true,
            'session_id', v_session.id,
            'started_at', v_session.started_at,
            'ends_at', v_session.ends_at,
            'message',
                'Mining session completed and ready to claim'
        );

    end if;


    -- Current active session.
    v_until_now :=
        least(
            now(),
            v_session.ends_at
        );


    select count(*)::integer
    into v_ads
    from public.ad_rewards
    where user_id = v_user_id
      and session_id = v_session.id;


    v_ads :=
        least(
            coalesce(v_ads, 0),
            7
        );


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_rate :=
        round(
            0.20
            + (v_ads * 0.10)
            + (v_referrals * 0.02),
            4
        );


    v_elapsed :=
        extract(
            epoch from (
                v_until_now
                - v_session.started_at
            )
        );


    v_remaining :=
        extract(
            epoch from (
                v_session.ends_at
                - now()
            )
        );


    -- Base mining reward.
    v_reward :=
        (
            greatest(
                v_elapsed,
                0
            )
            / 3600.0
        ) * 0.20;


    -- Time-weighted ad reward.
    v_reward :=
        v_reward
        +
        public.calculate_ad_bonus_reward(
            v_user_id,
            v_session.started_at,
            v_until_now
        );


    -- Time-weighted referral reward.
    v_reward :=
        v_reward
        +
        public.calculate_referral_bonus_reward(
            v_user_id,
            v_session.started_at,
            v_until_now
        );


    v_reward :=
        round(
            greatest(v_reward, 0),
            8
        );


    update public.profiles
    set
        mining_rate = v_rate,
        active_referrals = v_referrals,
        daily_ads_watched = v_ads,
        ad_boost = round(
            v_ads * 0.10,
            4
        ),
        updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'active', true,
        'mining_active', true,
        'expired', false,
        'claimable', false,

        'session_id',
            v_session.id,

        'started_at',
            v_session.started_at,

        'ends_at',
            v_session.ends_at,

        'elapsed_seconds',
            greatest(v_elapsed, 0),

        'remaining_seconds',
            greatest(v_remaining, 0),

        'reward',
            v_reward,

        'mining_rate',
            v_rate,

        'ads_watched',
            v_ads,

        'ad_boost',
            round(
                v_ads * 0.10,
                4
            ),

        'active_referrals',
            v_referrals
    );

end;
$function$;


-- ============================================================
-- 11. RECORD REWARDED AD
-- ============================================================

create or replace function public.record_rewarded_ad()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_ads integer;
    v_next_ad integer;

    v_ad_id uuid;

    v_referrals integer;
    v_rate numeric(12,4);
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and ends_at > now()
    order by started_at desc
    limit 1
    for update;


    if not found then
        raise exception
            'Start mining before watching a rewarded ad';
    end if;


    select count(*)::integer
    into v_ads
    from public.ad_rewards
    where user_id = v_user_id
      and session_id = v_session.id;


    v_ads :=
        least(
            coalesce(v_ads, 0),
            7
        );


    if v_ads >= 7 then
        raise exception
            'Maximum of 7 rewarded ads reached';
    end if;


    v_next_ad :=
        v_ads + 1;


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
        v_next_ad,
        now(),
        0.10
    )
    returning id
    into v_ad_id;


    v_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_rate :=
        round(
            0.20
            + (v_next_ad * 0.10)
            + (v_referrals * 0.02),
            4
        );


    update public.profiles
    set
        mining_rate = v_rate,
        daily_ads_watched = v_next_ad,
        ad_boost = round(
            v_next_ad * 0.10,
            4
        ),
        active_referrals = v_referrals,
        updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'ad_id', v_ad_id,
        'session_id', v_session.id,
        'ad_number', v_next_ad,
        'ads_watched', v_next_ad,
        'reward_rate', 0.10,
        'ad_boost',
            round(
                v_next_ad * 0.10,
                4
            ),
        'mining_rate', v_rate,
        'message',
            'Rewarded ad recorded successfully'
    );

end;
$function$;


-- ============================================================
-- 12. USER-ID REWARDED AD WRAPPER
-- ============================================================

create or replace function public.record_rewarded_ad(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.record_rewarded_ad();

end;
$$;


-- ============================================================
-- 13. VERIFY REWARDED AD
-- ============================================================

create or replace function public.verify_rewarded_ad(
    p_ad_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;

    v_ad public.ad_rewards%rowtype;
    v_session public.mining_sessions%rowtype;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select *
    into v_ad
    from public.ad_rewards
    where id = p_ad_id
      and user_id = v_user_id;


    if not found then
        raise exception
            'Rewarded ad record not found';
    end if;


    select *
    into v_session
    from public.mining_sessions
    where id = v_ad.session_id
      and user_id = v_user_id
    limit 1;


    if not found then
        raise exception
            'Advertisement is not linked to a valid mining session';
    end if;


    if v_ad.watched_at < v_session.started_at
       or v_ad.watched_at >= v_session.ends_at then

        raise exception
            'Rewarded ad is outside the mining session';

    end if;


    if v_ad.ad_number is null
       or v_ad.ad_number < 1
       or v_ad.ad_number > 7 then

        raise exception
            'Invalid rewarded ad number';

    end if;


    return jsonb_build_object(
        'success', true,
        'verified', true,
        'ad_id', v_ad.id,
        'ad_number', v_ad.ad_number,
        'reward_rate',
            greatest(
                least(
                    coalesce(
                        v_ad.reward_amount,
                        0.10
                    ),
                    0.10
                ),
                0
            ),
        'watched_at',
            v_ad.watched_at,
        'session_id',
            v_session.id
    );

end;
$$;


-- ============================================================
-- 14. CLAIM MINING
-- ============================================================

create or replace function public.claim_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_old_balance numeric(24,8);
    v_new_balance numeric(24,8);

    v_base_reward numeric(30,8);
    v_ad_reward numeric(30,8);
    v_referral_reward numeric(30,8);

    v_reward numeric(30,8);

    v_active_referrals integer;
    v_final_rate numeric(12,4);
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    -- Lock profile.
    select fan_balance
    into v_old_balance
    from public.profiles
    where id = v_user_id
    for update;


    if not found then
        raise exception 'Profile not found';
    end if;


    -- Find completed unclaimed session.
    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and ends_at <= now()
    order by ends_at desc
    limit 1
    for update;


    if not found then
        raise exception
            'No completed mining session is available to claim';
    end if;


    -- Base reward:
    -- 24 hours * 0.20 = 4.80 FAN.
    v_base_reward :=
        round(
            (
                extract(
                    epoch from (
                        v_session.ends_at
                        - v_session.started_at
                    )
                ) / 3600.0
            ) * 0.20,
            8
        );


    -- Time-weighted ad reward.
    v_ad_reward :=
        round(
            public.calculate_ad_bonus_reward(
                v_user_id,
                v_session.started_at,
                v_session.ends_at
            ),
            8
        );


    -- Time-weighted referral reward.
    v_referral_reward :=
        round(
            public.calculate_referral_bonus_reward(
                v_user_id,
                v_session.started_at,
                v_session.ends_at
            ),
            8
        );


    -- Total reward.
    v_reward :=
        greatest(
            round(
                v_base_reward
                + v_ad_reward
                + v_referral_reward,
                8
            ),
            0
        );


    v_new_balance :=
        round(
            coalesce(
                v_old_balance,
                0
            )
            + v_reward,
            8
        );


    -- Post-claim referral rate.
    v_active_referrals :=
        public.calculate_active_referrals(
            v_user_id
        );


    v_final_rate :=
        round(
            0.20
            + (v_active_referrals * 0.02),
            4
        );


    -- Credit FAN and reset active mining state.
    update public.profiles
    set
        fan_balance = v_new_balance,

        mining_active = false,

        mining_started_at = null,

        mining_ends_at = null,

        daily_ads_watched = 0,

        ad_boost = 0,

        mining_rate = v_final_rate,

        active_referrals =
            v_active_referrals,

        updated_at = now()

    where id = v_user_id;


    -- Mark session claimed.
    update public.mining_sessions
    set
        claimed = true,
        reward_amount = v_reward,
        claimed_at = now()
    where id = v_session.id
      and claimed = false;


    if not found then
        raise exception
            'Mining reward could not be claimed';
    end if;


    return jsonb_build_object(
        'success', true,
        'session_id', v_session.id,
        'reward', v_reward,
        'fan_reward', v_reward,
        'base_reward', v_base_reward,
        'ad_reward', v_ad_reward,
        'referral_reward', v_referral_reward,
        'fan_balance', v_new_balance,
        'started_at', v_session.started_at,
        'ends_at', v_session.ends_at,
        'message',
            'Mining reward claimed successfully'
    );

end;
$function$;


-- ============================================================
-- 15. USER-ID CLAIM WRAPPER
-- ============================================================

create or replace function public.claim_mining(
    p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin

    if auth.uid() is null
       or p_user_id <> auth.uid() then

        raise exception 'Not authorized';

    end if;


    return public.claim_mining();

end;
$$;


-- ============================================================
-- 16. COMPLETE CURRENT USER EXPIRED SESSION
-- ============================================================

create or replace function public.complete_expired_mining_session()
returns boolean
language plpgsql
security definer
set search_path = public
as $function$
declare
    v_user_id uuid;
    v_session_id uuid;
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    select id
    into v_session_id
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and ends_at <= now()
    order by ends_at desc
    limit 1
    for update;


    if v_session_id is null then
        return false;
    end if;


    update public.profiles
    set
        mining_active = false,
        mining_started_at = null,
        mining_ends_at = null,
        updated_at = now()
    where id = v_user_id;


    return true;

end;
$function$;


-- ============================================================
-- 17. AUTOMATIC INACTIVITY PENALTY RUNNER
-- ============================================================

drop function if exists public.run_inactivity_penalties();


create or replace function public.run_inactivity_penalties()
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
    r record;
begin

    for r in
        select id
        from public.profiles
        where last_mining_at is not null
          and last_mining_at
              <= now() - interval '72 hours'
    loop

        perform public.apply_inactivity_penalty(
            r.id
        );

    end loop;

end;
$function$;


-- ============================================================
-- 18. SECURITY REVOKES
-- ============================================================

revoke execute
on function public.calculate_active_referrals(uuid)
from public, anon, authenticated;


revoke execute
on function public.calculate_ad_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
from public, anon, authenticated;


revoke execute
on function public.calculate_referral_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
from public, anon, authenticated;


revoke execute
on function public.apply_inactivity_penalty(uuid)
from public, anon, authenticated;


revoke execute
on function public.run_inactivity_penalties()
from public, anon, authenticated;


-- ============================================================
-- 19. PUBLIC RPC FUNCTIONS USED BY THE APPLICATION
-- ============================================================

grant execute
on function public.get_user_mining_rate()
to authenticated;


grant execute
on function public.get_user_mining_rate(uuid)
to authenticated;


grant execute
on function public.start_mining()
to authenticated;


grant execute
on function public.start_mining(uuid)
to authenticated;


grant execute
on function public.get_active_mining()
to authenticated;


grant execute
on function public.record_rewarded_ad()
to authenticated;


grant execute
on function public.record_rewarded_ad(uuid)
to authenticated;


grant execute
on function public.verify_rewarded_ad(uuid)
to authenticated;


grant execute
on function public.claim_mining()
to authenticated;


grant execute
on function public.claim_mining(uuid)
to authenticated;


grant execute
on function public.complete_expired_mining_session()
to authenticated;


-- ============================================================
-- 20. AUTOMATIC INACTIVITY CRON
-- ============================================================
--
-- Supabase pg_cron is already enabled in the production
-- project and this job already exists.
--
-- Reusing the same job name safely updates/overwrites the
-- existing job instead of creating another duplicate job.
-- ============================================================

select cron.schedule(
    'pfn-inactivity-penalty-hourly',
    '0 * * * *',
    $$select public.run_inactivity_penalties();$$
);


-- ============================================================
-- END OF FINAL MINING ENGINE
-- ============================================================
