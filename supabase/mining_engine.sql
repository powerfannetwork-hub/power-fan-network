-- ============================================================
-- POWER FAN NETWORK
-- REAL SERVER-SIDE MINING ENGINE
-- ============================================================
--
-- Rules:
--   Base mining rate        = 0.2 FAN/H
--   Mining session          = 24 hours
--   Active referral bonus   = +0.02 FAN/H per active referral
--   Rewarded ad bonus       = +0.10 FAN/H per verified ad
--   Maximum ads/session     = 7
--   Maximum ad boost        = +0.70 FAN/H
--
-- IMPORTANT:
--   FAN is calculated and credited by PostgreSQL/server time.
--   The Flutter client cannot choose the mining time or reward.
-- ============================================================


create extension if not exists "pgcrypto";


-- ============================================================
-- 1. ENSURE REQUIRED COLUMNS EXIST
-- ============================================================

alter table public.profiles
  add column if not exists fan_balance numeric(30,8)
    not null default 0;

alter table public.profiles
  add column if not exists afam_balance numeric(30,8)
    not null default 0;

alter table public.profiles
  add column if not exists mining_rate numeric(12,4)
    not null default 0.2;

alter table public.profiles
  add column if not exists active_referrals integer
    not null default 0;

alter table public.profiles
  add column if not exists daily_ads_watched integer
    not null default 0;

alter table public.profiles
  add column if not exists ad_boost numeric(12,4)
    not null default 0;

alter table public.profiles
  add column if not exists mining_active boolean
    not null default false;

alter table public.profiles
  add column if not exists mining_started_at timestamptz;

alter table public.profiles
  add column if not exists mining_ends_at timestamptz;


-- ============================================================
-- 2. ENSURE MINING SESSION TABLE EXISTS
-- ============================================================

create table if not exists public.mining_sessions (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  started_at timestamptz not null,

  ends_at timestamptz not null,

  mining_rate numeric(12,4)
    not null default 0.2,

  reward numeric(30,8)
    not null default 0,

  status text
    not null default 'active',

  claimed_at timestamptz,

  created_at timestamptz
    not null default now(),

  constraint mining_sessions_status_check
    check (
      status in (
        'active',
        'completed',
        'claimed',
        'cancelled'
      )
    )
);


create index if not exists
  mining_sessions_user_id_idx
on public.mining_sessions(user_id);


create index if not exists
  mining_sessions_status_idx
on public.mining_sessions(status);


create index if not exists
  mining_sessions_started_at_idx
on public.mining_sessions(started_at);


create index if not exists
  mining_sessions_ends_at_idx
on public.mining_sessions(ends_at);


-- ============================================================
-- 3. ONLY ONE ACTIVE SESSION PER USER
-- ============================================================

create unique index if not exists
  mining_sessions_one_active_per_user_idx
on public.mining_sessions(user_id)
where status = 'active';


-- ============================================================
-- 4. ENSURE AD REWARD TABLE EXISTS
-- ============================================================

create table if not exists public.ad_rewards (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  ad_number integer not null,

  reward_rate numeric(12,4)
    not null default 0.1,

  watched_at timestamptz
    not null default now()
);


create index if not exists
  ad_rewards_user_id_idx
on public.ad_rewards(user_id);


create index if not exists
  ad_rewards_watched_at_idx
on public.ad_rewards(watched_at);


-- ============================================================
-- 5. CALCULATE ACTIVE REFERRAL COUNT
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
-- 6. GET CURRENT SERVER-SIDE MINING RATE
-- ============================================================

create or replace function public.get_user_mining_rate()
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_active_referrals integer;
  v_ad_count integer;
  v_rate numeric(12,4);
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Refresh active referral count.
  v_active_referrals :=
    public.calculate_active_referrals(
      v_user_id
    );


  update public.profiles
  set
    active_referrals = v_active_referrals,
    updated_at = now()
  where id = v_user_id;


  -- Count ads from the user's current active session.
  select count(*)::integer
  into v_ad_count
  from public.ad_rewards ar
  join public.mining_sessions ms
    on ms.user_id = ar.user_id
   and ar.watched_at >= ms.started_at
   and ar.watched_at <= least(
     ms.ends_at,
     now()
   )
  where ar.user_id = v_user_id
    and ms.status = 'active';


  v_ad_count :=
    least(
      coalesce(v_ad_count, 0),
      7
    );


  v_rate :=
      0.2
    + (
        v_active_referrals * 0.02
      )
    + (
        v_ad_count * 0.10
      );


  return round(
    greatest(v_rate, 0.2),
    4
  );

end;
$$;


-- ============================================================
-- 7. START 24-HOUR MINING SESSION
-- ============================================================

create or replace function public.start_mining()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_profile public.profiles%rowtype;

  v_session_id uuid;

  v_started_at timestamptz;
  v_ends_at timestamptz;

  v_active_referrals integer;
  v_rate numeric(12,4);

  v_existing_session public.mining_sessions%rowtype;
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Lock profile row to prevent race conditions.
  select *
  into v_profile
  from public.profiles
  where id = v_user_id
  for update;


  if not found then
    raise exception 'Profile not found';
  end if;


  -- Check for an existing active session.
  select *
  into v_existing_session
  from public.mining_sessions
  where user_id = v_user_id
    and status = 'active'
  order by started_at desc
  limit 1
  for update;


  if found then

    -- If it is still active, return it.
    if now() < v_existing_session.ends_at then

      return jsonb_build_object(
        'success', true,
        'already_active', true,
        'session_id',
          v_existing_session.id,
        'started_at',
          v_existing_session.started_at,
        'ends_at',
          v_existing_session.ends_at,
        'mining_rate',
          v_existing_session.mining_rate,
        'status',
          'active'
      );

    end if;


    -- Session expired.
    update public.mining_sessions
    set
      status = 'completed',
      reward = round(
        extract(
          epoch from (
            ends_at - started_at
          )
        ) / 3600.0
        * mining_rate,
        8
      )
    where id = v_existing_session.id;


    update public.profiles
    set
      mining_active = false,
      mining_started_at = null,
      mining_ends_at = null,
      daily_ads_watched = 0,
      ad_boost = 0,
      updated_at = now()
    where id = v_user_id;

  end if;


  -- Server timestamp.
  v_started_at := now();

  v_ends_at :=
    v_started_at
    + interval '24 hours';


  -- Active referrals.
  v_active_referrals :=
    public.calculate_active_referrals(
      v_user_id
    );


  -- Base + referral rate.
  v_rate :=
      0.2
    + (
        v_active_referrals * 0.02
      );


  v_rate :=
    round(
      greatest(v_rate, 0.2),
      4
    );


  -- Create session.
  insert into public.mining_sessions (
    user_id,
    started_at,
    ends_at,
    mining_rate,
    reward,
    status
  )
  values (
    v_user_id,
    v_started_at,
    v_ends_at,
    v_rate,
    0,
    'active'
  )
  returning id
  into v_session_id;


  -- Synchronize profile.
  update public.profiles
  set
    mining_rate = v_rate,
    active_referrals =
      v_active_referrals,
    mining_active = true,
    mining_started_at =
      v_started_at,
    mining_ends_at =
      v_ends_at,
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
    'status', 'active'
  );

end;
$$;


-- ============================================================
-- 8. GET CURRENT MINING SESSION
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
  v_active_referrals integer;
  v_ad_count integer;
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
    and status = 'active'
  order by started_at desc
  limit 1
  for update;


  if not found then

    update public.profiles
    set
      mining_active = false,
      mining_started_at = null,
      mining_ends_at = null,
      daily_ads_watched = 0,
      ad_boost = 0,
      updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
      'success', true,
      'is_mining', false,
      'mining_active', false,
      'started_at', null,
      'ends_at', null,
      'reward', 0,
      'mining_rate', 0.2
    );

  end if;


  -- Expire completed session.
  if now() >= v_session.ends_at then

    v_rate :=
      v_session.mining_rate;


    update public.mining_sessions
    set
      status = 'completed',
      reward = round(
        extract(
          epoch from (
            ends_at - started_at
          )
        ) / 3600.0
        * mining_rate,
        8
      )
    where id = v_session.id;


    update public.profiles
    set
      mining_active = false,
      mining_started_at = null,
      mining_ends_at = null,
      updated_at = now()
    where id = v_user_id;


    return jsonb_build_object(
      'success', true,
      'is_mining', false,
      'mining_active', false,
      'session_finished', true,
      'started_at',
        v_session.started_at,
      'ends_at',
        v_session.ends_at,
      'reward',
        round(
          extract(
            epoch from (
              v_session.ends_at
              - v_session.started_at
            )
          ) / 3600.0
          * v_session.mining_rate,
          8
        ),
      'mining_rate',
        v_session.mining_rate,
      'session_id',
        v_session.id
    );

  end if;


  v_active_referrals :=
    public.calculate_active_referrals(
      v_user_id
    );


  select count(*)::integer
  into v_ad_count
  from public.ad_rewards
  where user_id = v_user_id
    and watched_at >= v_session.started_at
    and watched_at <= now();


  v_ad_count :=
    least(
      coalesce(v_ad_count, 0),
      7
    );


  v_rate :=
      0.2
    + (
        v_active_referrals * 0.02
      )
    + (
        v_ad_count * 0.10
      );


  v_rate :=
    round(
      greatest(v_rate, 0.2),
      4
    );


  -- Keep profile synchronized.
  update public.profiles
  set
    mining_rate = v_rate,
    active_referrals =
      v_active_referrals,
    daily_ads_watched =
      v_ad_count,
    ad_boost =
      round(v_ad_count * 0.10, 4),
    updated_at = now()
  where id = v_user_id;


  return jsonb_build_object(
    'success', true,
    'is_mining', true,
    'mining_active', true,
    'session_finished', false,
    'started_at',
      v_session.started_at,
    'ends_at',
      v_session.ends_at,
    'reward',
      round(
        extract(
          epoch from (
            least(
              now(),
              v_session.ends_at
            )
            - v_session.started_at
          )
        ) / 3600.0
        * v_rate,
        8
      ),
    'mining_rate',
      v_rate,
    'ads_watched',
      v_ad_count,
    'ad_boost',
      round(v_ad_count * 0.10, 4),
    'active_referrals',
      v_active_referrals,
    'session_id',
      v_session.id
  );

end;
$$;


-- ============================================================
-- 9. RECORD A COMPLETED REWARDED AD
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

  v_count integer;
  v_next_ad_number integer;

  v_rate numeric(12,4);

  v_ad_id uuid;
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Lock active session.
  select *
  into v_session
  from public.mining_sessions
  where user_id = v_user_id
    and status = 'active'
  order by started_at desc
  limit 1
  for update;


  if not found then
    raise exception
      'Start a mining session before watching rewarded ads';
  end if;


  if now() >= v_session.ends_at then
    raise exception
      'Your mining session has ended';
  end if;


  -- Count ads only inside this mining session.
  select count(*)::integer
  into v_count
  from public.ad_rewards
  where user_id = v_user_id
    and watched_at >= v_session.started_at
    and watched_at <= now();


  if v_count >= 7 then
    raise exception
      'Maximum of 7 rewarded ads per mining session reached';
  end if;


  v_next_ad_number :=
    v_count + 1;


  -- Insert one server timestamped ad reward.
  insert into public.ad_rewards (
    user_id,
    ad_number,
    reward_rate,
    watched_at
  )
  values (
    v_user_id,
    v_next_ad_number,
    0.1,
    now()
  )
  returning id
  into v_ad_id;


  -- Calculate new mining rate.
  v_rate :=
      0.2
    + (
        public.calculate_active_referrals(
          v_user_id
        ) * 0.02
      )
    + (
        v_next_ad_number * 0.10
      );


  v_rate :=
    round(
      greatest(v_rate, 0.2),
      4
    );


  update public.profiles
  set
    mining_rate = v_rate,
    daily_ads_watched =
      v_next_ad_number,
    ad_boost =
      round(
        v_next_ad_number * 0.10,
        4
      ),
    updated_at = now()
  where id = v_user_id;


  return jsonb_build_object(
    'success', true,
    'ad_id', v_ad_id,
    'ad_number', v_next_ad_number,
    'ads_watched', v_next_ad_number,
    'reward_rate', 0.1,
    'ad_boost',
      round(
        v_next_ad_number * 0.10,
        4
      ),
    'mining_rate', v_rate,
    'message',
      'Rewarded ad recorded successfully'
  );

end;
$$;


-- ============================================================
-- 10. VERIFY REWARDED AD
-- ============================================================
--
-- This RPC does NOT blindly create FAN.
-- It only verifies an ad record belonging to
-- the authenticated user and the current session.
--
-- Final production ad-network server-to-server
-- verification should be added before launch.
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
  where id is not null
    and user_id = v_user_id
    and v_ad.watched_at >= started_at
    and v_ad.watched_at <= ends_at
  order by started_at desc
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
    'reward_rate', v_ad.reward_rate,
    'watched_at', v_ad.watched_at,
    'session_id', v_session.id
  );

end;
$$;


-- ============================================================
-- 11. CLAIM COMPLETED MINING SESSION
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

  v_reward numeric(30,8);

  v_old_balance numeric(30,8);
  v_new_balance numeric(30,8);

  v_active_referrals integer;
  v_ad_count integer;
  v_final_rate numeric(12,4);
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  -- Lock profile.
  select *
  into v_old_balance
  from public.profiles
  where id = v_user_id
  for update;


  if not found then
    raise exception 'Profile not found';
  end if;


  -- Find completed session first.
  select *
  into v_session
  from public.mining_sessions
  where user_id = v_user_id
    and status = 'completed'
  order by ends_at desc
  limit 1
  for update;


  -- If an active session has expired, complete it now.
  if not found then

    select *
    into v_session
    from public.mining_sessions
    where user_id = v_user_id
      and status = 'active'
      and now() >= ends_at
    order by ends_at desc
    limit 1
    for update;


    if found then

      update public.mining_sessions
      set
        status = 'completed',
        reward = round(
          extract(
            epoch from (
              ends_at - started_at
            )
          ) / 3600.0
          * mining_rate,
          8
        )
      where id = v_session.id
      returning *
      into v_session;

    end if;

  end if;


  if v_session.id is null then
    raise exception
      'No completed mining session is available to claim';
  end if;


  if v_session.status <> 'completed' then
    raise exception
      'Mining session is not ready to claim';
  end if;


  if v_session.ends_at > now() then
    raise exception
      'Mining session has not finished yet';
  end if;


  -- Calculate exact session reward.
  --
  -- The session's stored rate is used for the
  -- completed session. It cannot be changed by
  -- the client.
  v_reward :=
    round(
      extract(
        epoch from (
          v_session.ends_at
          - v_session.started_at
        )
      ) / 3600.0
      * v_session.mining_rate,
      8
    );


  v_reward :=
    greatest(
      v_reward,
      0
    );


  -- Current balance.
  select fan_balance
  into v_old_balance
  from public.profiles
  where id = v_user_id
  for update;


  v_new_balance :=
    round(
      v_old_balance + v_reward,
      8
    );


  -- Credit FAN exactly once.
  update public.profiles
  set
    fan_balance = v_new_balance,
    mining_active = false,
    mining_started_at = null,
    mining_ends_at = null,
    daily_ads_watched = 0,
    ad_boost = 0,
    mining_rate = round(
      0.2
      + (
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
    status = 'claimed',
    reward = v_reward,
    claimed_at = now()
  where id = v_session.id
    and status = 'completed';


  -- Verify the update actually claimed it.
  if not found then

    -- Rollback is automatic because this
    -- function raises an exception.
    raise exception
      'Mining reward could not be claimed safely';

  end if;


  return jsonb_build_object(
    'success', true,
    'session_id', v_session.id,
    'reward', v_reward,
    'fan_reward', v_reward,
    'fan_balance', v_new_balance,
    'started_at',
      v_session.started_at,
    'ends_at',
      v_session.ends_at,
    'message',
      'Mining reward claimed successfully'
  );

end;
$$;


-- ============================================================
-- 12. SESSION AD COUNT FOR FLUTTER
-- ============================================================

create or replace function public.get_session_ad_count(
  p_started_at timestamptz
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_count integer;
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;


  select count(*)::integer
  into v_count
  from public.ad_rewards
  where user_id = v_user_id
    and watched_at >= p_started_at
    and watched_at <= now();


  return least(
    coalesce(v_count, 0),
    7
  );

end;
$$;


-- ============================================================
-- 13. COMPLETE EXPIRED SESSIONS
-- ============================================================
--
-- Can be called by trusted backend/cron.
-- It does NOT credit FAN.
-- It only changes active -> completed.
-- ============================================================

create or replace function public.complete_expired_mining_sessions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin

  with completed as (
    update public.mining_sessions
    set
      status = 'completed',
      reward = round(
        extract(
          epoch from (
            ends_at - started_at
          )
        ) / 3600.0
        * mining_rate,
        8
      )
    where status = 'active'
      and ends_at <= now()
    returning user_id
  )
  select count(*)
  into v_count
  from completed;


  update public.profiles p
  set
    mining_active = false,
    mining_started_at = null,
    mining_ends_at = null,
    updated_at = now()
  where p.mining_active = true
    and not exists (
      select 1
      from public.mining_sessions ms
      where ms.user_id = p.id
        and ms.status = 'active'
    );


  return coalesce(v_count, 0);

end;
$$;


-- ============================================================
-- 14. SECURITY
-- ============================================================

revoke all on function public.start_mining()
from public, anon, authenticated;

revoke all on function public.get_active_mining()
from public, anon, authenticated;

revoke all on function public.claim_mining()
from public, anon, authenticated;

revoke all on function public.get_user_mining_rate()
from public, anon, authenticated;

revoke all on function public.record_rewarded_ad()
from public, anon, authenticated;

revoke all on function public.verify_rewarded_ad(uuid)
from public, anon, authenticated;

revoke all on function public.get_session_ad_count(timestamptz)
from public, anon, authenticated;

revoke all on function public.calculate_active_referrals(uuid)
from public, anon, authenticated;

revoke all on function public.complete_expired_mining_sessions()
from public, anon, authenticated;


grant execute on function public.start_mining()
to authenticated;

grant execute on function public.get_active_mining()
to authenticated;

grant execute on function public.claim_mining()
to authenticated;

grant execute on function public.get_user_mining_rate()
to authenticated;

grant execute on function public.record_rewarded_ad()
to authenticated;

grant execute on function public.verify_rewarded_ad(uuid)
to authenticated;

grant execute on function public.get_session_ad_count(timestamptz)
to authenticated;

grant execute on function public.calculate_active_referrals(uuid)
to authenticated;


-- ============================================================
-- 15. RLS
-- ============================================================

alter table public.mining_sessions enable row level security;

alter table public.ad_rewards enable row level security;


drop policy if exists
  mining_sessions_select_own
on public.mining_sessions;

create policy
  mining_sessions_select_own
on public.mining_sessions
for select
to authenticated
using (
  user_id = auth.uid()
);


drop policy if exists
  ad_rewards_select_own
on public.ad_rewards;

create policy
  ad_rewards_select_own
on public.ad_rewards
for select
to authenticated
using (
  user_id = auth.uid()
);


-- No direct INSERT/UPDATE/DELETE policies are
-- intentionally provided for clients.
--
-- Mining and ad records must go through RPCs.


-- ============================================================
-- 16. FINAL NORMALIZATION
-- ============================================================

update public.profiles
set
  mining_rate = greatest(
    coalesce(mining_rate, 0.2),
    0.2
  ),
  active_referrals = greatest(
    coalesce(active_referrals, 0),
    0
  ),
  daily_ads_watched = least(
    greatest(
      coalesce(daily_ads_watched, 0),
      0
    ),
    7
  ),
  ad_boost = least(
    greatest(
      coalesce(ad_boost, 0),
      0
    ),
    0.7
  );


-- ============================================================
-- END OF REAL MINING ENGINE
-- ============================================================
