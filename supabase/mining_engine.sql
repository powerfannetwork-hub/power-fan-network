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
-- IMPORTANT:
-- Rewards are TIME-WEIGHTED.
-- An ad only affects mining from the moment it is watched.
-- There is NO retroactive ad reward.
-- ============================================================


-- ============================================================
-- 1. ACTIVE REFERRALS
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
    from public.profiles
    where referred_by = p_user_id
      and mining_active = true;
$$;


-- ============================================================
-- 2. AD BONUS REWARD
-- ============================================================

create or replace function public.calculate_ad_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        sum(
            (
                extract(
                    epoch from (
                        p_ends_at - ar.watched_at
                    )
                ) / 3600.0
            )
            *
            least(
                coalesce(ar.reward_amount, 0.10),
                0.10
            )
        ),
        0
    )
    from (
        select
            reward_amount,
            watched_at
        from public.ad_rewards
        where user_id = p_user_id
          and watched_at >= p_started_at
          and watched_at < p_ends_at
        order by watched_at
        limit 7
    ) ar;
$$;


-- ============================================================
-- 3. REFERRAL BONUS REWARD
-- ============================================================

create or replace function public.calculate_referral_bonus_reward(
    p_user_id uuid,
    p_started_at timestamptz,
    p_ends_at timestamptz
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
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
                            p_started_at
                        )
                    )
                ) / 3600.0
            ) * 0.02
        ),
        0
    )
    from public.profiles referred
    join public.mining_sessions rs
      on rs.user_id = referred.id
    where referred.referred_by = p_user_id
      and rs.started_at < p_ends_at
      and rs.ends_at > p_started_at;
$$;


-- ============================================================
-- 4. GET CURRENT MINING RATE
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
        public.calculate_active_referrals(v_user_id);


    if v_session.id is not null then

        select count(*)::integer
        into v_ads
        from public.ad_rewards
        where user_id = v_user_id
          and session_id = v_session.id;

    end if;


    v_ads := least(
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
        ad_boost = round(v_ads * 0.10, 4),
        updated_at = now()
    where id = v_user_id;


    return v_rate;

end;
$$;


-- ============================================================
-- 5. USER-ID MINING RATE WRAPPER
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
-- 6. START MINING
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;
    v_existing public.mining_sessions%rowtype;

    v_session_id uuid;
    v_started_at timestamptz;
    v_ends_at timestamptz;

    v_referrals integer;
    v_rate numeric(12,4);
begin

    v_user_id := auth.uid();

    if v_user_id is null then
        raise exception 'Authentication required';
    end if;


    -- Lock user profile.
    perform 1
    from public.profiles
    where id = v_user_id
    for update;


    if not found then
        raise exception 'Profile not found';
    end if;


    -- Check current active session.
    select *
    into v_existing
    from public.mining_sessions
    where user_id = v_user_id
      and claimed = false
      and ends_at > now()
    order by started_at desc
    limit 1
    for update;


    if found then

        return jsonb_build_object(
            'success', true,
            'already_active', true,
            'session_id', v_existing.id,
            'started_at', v_existing.started_at,
            'ends_at', v_existing.ends_at,
            'mining_rate',
                public.get_user_mining_rate(),
            'status', 'active'
        );

    end if;


    v_started_at := now();

    v_ends_at :=
        v_started_at + interval '24 hours';


    v_referrals :=
        public.calculate_active_referrals(v_user_id);


    v_rate :=
        round(
            0.20 + (v_referrals * 0.02),
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
        mining_started_at = v_started_at,
        mining_ends_at = v_ends_at,
        mining_rate = v_rate,
        active_referrals = v_referrals,
        daily_ads_watched = 0,
        ad_boost = 0,
        updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
        'success', true,
        'already_active', false,
        'session_id', v_session_id,
        'started_at', v_started_at,
        'ends_at', v_ends_at,
        'mining_rate', v_rate,
        'active_referrals', v_referrals,
        'status', 'active'
    );

end;
$$;


-- ============================================================
-- 7. USER-ID START MINING WRAPPER
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
-- 8. GET ACTIVE MINING
-- ============================================================

create or replace function public.get_active_mining()
returns jsonb
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
            'reward', 0,
            'mining_rate', 0.20
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
            'ends_at', v_session.ends_at
        );

    end if;


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
        public.calculate_active_referrals(v_user_id);


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


    -- Base mining.
    v_reward :=
        (
            greatest(v_elapsed, 0)
            / 3600.0
        ) * 0.20;


    -- Ad rewards.
    v_reward :=
        v_reward
        +
        public.calculate_ad_bonus_reward(
            v_user_id,
            v_session.started_at,
            v_until_now
        );


    -- Referral rewards.
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
        ad_boost = round(v_ads * 0.10, 4),
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
            round(v_ads * 0.10, 4),

        'active_referrals',
            v_referrals
    );

end;
$$;


-- ============================================================
-- 9. RECORD REWARDED AD
-- ============================================================

create or replace function public.record_rewarded_ad()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
        public.calculate_active_referrals(v_user_id);


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
        ad_boost = round(v_next_ad * 0.10, 4),
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
            round(v_next_ad * 0.10, 4),
        'mining_rate', v_rate,
        'message',
            'Rewarded ad recorded successfully'
    );

end;
$$;


-- ============================================================
-- 10. USER-ID REWARDED AD WRAPPER
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
-- 11. VERIFY REWARDED AD
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


    return jsonb_build_object(
        'success', true,
        'verified', true,
        'ad_id', v_ad.id,
        'ad_number', v_ad.ad_number,
        'reward_rate', v_ad.reward_amount,
        'watched_at', v_ad.watched_at,
        'session_id', v_session.id
    );

end;
$$;


-- ============================================================
-- 12. CLAIM MINING
-- ============================================================

create or replace function public.claim_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid;

    v_session public.mining_sessions%rowtype;

    v_old_balance numeric(24,8);
    v_new_balance numeric(24,8);

    v_base_reward numeric(30,8);
    v_ad_reward numeric(30,8);
    v_referral_reward numeric(30,8);

    v_reward numeric(30,8);
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


    -- Find the newest unclaimed session.
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
            coalesce(v_old_balance, 0)
            + v_reward,
            8
        );


    -- Credit FAN.
    update public.profiles
    set
        fan_balance = v_new_balance,
        mining_active = false,
        mining_started_at = null,
        mining_ends_at = null,
        daily_ads_watched = 0,
        ad_boost = 0,
        mining_rate = round(
            0.20
            +
            (
                public.calculate_active_referrals(
                    v_user_id
                ) * 0.02
            ),
            4
        ),
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
$$;


-- ============================================================
-- 13. USER-ID CLAIM WRAPPER
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
-- 14. COMPLETE CURRENT USER EXPIRED SESSION
-- ============================================================

create or replace function public.complete_expired_mining_session()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
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
$$;


-- ============================================================
-- 15. GRANTS
-- ============================================================

grant execute
on function public.calculate_active_referrals(uuid)
to authenticated;

grant execute
on function public.calculate_ad_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
to authenticated;

grant execute
on function public.calculate_referral_bonus_reward(
    uuid,
    timestamptz,
    timestamptz
)
to authenticated;

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
-- END OF FINAL MINING ENGINE
-- ============================================================
