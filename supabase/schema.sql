-- ============================================================
-- POWER FAN NETWORK
-- SUPABASE FINAL MIGRATION-SAFE SCHEMA
-- ============================================================
--
-- RULE:
--   EXISTS  -> UPDATE / ALTER / CONTINUE
--   MISSING -> CREATE
--
-- Mining:
--   Base rate        = 0.20 FAN/H
--   Session          = 24 hours
--   Ad boost         = +0.10 FAN/H
--   Maximum ads      = 7
--   Referral boost   = +0.02 FAN/H
-- ============================================================


create extension if not exists pgcrypto;


-- ============================================================
-- 1. PROFILES
-- ============================================================

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade
);

alter table public.profiles add column if not exists name text;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists referral_code text;
alter table public.profiles add column if not exists referred_by uuid;

alter table public.profiles
    add column if not exists fan_balance numeric(24,8) default 0;

alter table public.profiles
    add column if not exists afam_balance numeric(24,8) default 0;

alter table public.profiles
    add column if not exists mining_rate numeric(12,4) default 0.20;

alter table public.profiles
    add column if not exists active_referrals integer default 0;

alter table public.profiles
    add column if not exists daily_ads_watched integer default 0;

alter table public.profiles
    add column if not exists ad_boost numeric(12,4) default 0;

alter table public.profiles
    add column if not exists mining_active boolean default false;

alter table public.profiles
    add column if not exists mining_started_at timestamptz;

alter table public.profiles
    add column if not exists mining_ends_at timestamptz;

alter table public.profiles
    add column if not exists consecutive_check_ins integer default 0;

alter table public.profiles
    add column if not exists kyc1_eligible boolean default false;

alter table public.profiles
    add column if not exists kyc1_verified boolean default false;

alter table public.profiles
    add column if not exists kyc2_eligible boolean default false;

alter table public.profiles
    add column if not exists kyc2_verified boolean default false;

alter table public.profiles
    add column if not exists kyc3_verified boolean default false;

alter table public.profiles
    add column if not exists last_social_claim_date date;

alter table public.profiles
    add column if not exists created_at timestamptz default now();

alter table public.profiles
    add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 2. MINING SESSIONS
-- ============================================================

create table if not exists public.mining_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade,
    started_at timestamptz default now(),
    ends_at timestamptz,
    mining_rate numeric(12,4) default 0.20,
    claimed boolean default false,
    claimed_at timestamptz,
    reward_amount numeric(24,8) default 0,
    created_at timestamptz default now()
);

alter table public.mining_sessions
    add column if not exists user_id uuid;

alter table public.mining_sessions
    add column if not exists started_at timestamptz default now();

alter table public.mining_sessions
    add column if not exists ends_at timestamptz;

alter table public.mining_sessions
    add column if not exists mining_rate numeric(12,4) default 0.20;

alter table public.mining_sessions
    add column if not exists claimed boolean default false;

alter table public.mining_sessions
    add column if not exists claimed_at timestamptz;

alter table public.mining_sessions
    add column if not exists reward_amount numeric(24,8) default 0;

alter table public.mining_sessions
    add column if not exists created_at timestamptz default now();


-- ============================================================
-- 3. AD REWARDS
-- ============================================================

create table if not exists public.ad_rewards (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade,
    session_id uuid,
    ad_number integer,
    watched_at timestamptz default now(),
    reward_amount numeric(12,4) default 0.10,
    created_at timestamptz default now()
);

alter table public.ad_rewards
    add column if not exists user_id uuid;

alter table public.ad_rewards
    add column if not exists session_id uuid;

alter table public.ad_rewards
    add column if not exists ad_number integer;

alter table public.ad_rewards
    add column if not exists watched_at timestamptz default now();

alter table public.ad_rewards
    add column if not exists reward_amount numeric(12,4) default 0.10;

alter table public.ad_rewards
    add column if not exists created_at timestamptz default now();


-- ============================================================
-- 4. NOTIFICATIONS
-- ============================================================

create table if not exists public.notifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade,
    title text default '',
    message text default '',
    type text default 'general',
    is_read boolean default false,
    created_at timestamptz default now()
);

alter table public.notifications add column if not exists user_id uuid;
alter table public.notifications add column if not exists title text;
alter table public.notifications add column if not exists message text;
alter table public.notifications add column if not exists type text default 'general';
alter table public.notifications add column if not exists is_read boolean default false;
alter table public.notifications add column if not exists created_at timestamptz default now();


-- ============================================================
-- 5. REFERRAL REWARDS
-- ============================================================

create table if not exists public.referral_rewards (
    id uuid primary key default gen_random_uuid(),
    inviter_id uuid,
    referred_user_id uuid,
    inviter_reward numeric(24,8) default 5,
    new_user_reward numeric(24,8) default 20,
    created_at timestamptz default now()
);

alter table public.referral_rewards add column if not exists inviter_id uuid;
alter table public.referral_rewards add column if not exists referred_user_id uuid;
alter table public.referral_rewards add column if not exists inviter_reward numeric(24,8) default 5;
alter table public.referral_rewards add column if not exists new_user_reward numeric(24,8) default 20;
alter table public.referral_rewards add column if not exists created_at timestamptz default now();


-- ============================================================
-- 6. DAILY CHECK-INS
-- ============================================================

create table if not exists public.daily_check_ins (
    id uuid primary key default gen_random_uuid(),
    user_id uuid,
    check_in_date date default current_date,
    streak_day integer default 1,
    reward_amount numeric(24,8) default 0,
    created_at timestamptz default now()
);

alter table public.daily_check_ins add column if not exists user_id uuid;
alter table public.daily_check_ins add column if not exists check_in_date date default current_date;
alter table public.daily_check_ins add column if not exists streak_day integer default 1;
alter table public.daily_check_ins add column if not exists reward_amount numeric(24,8) default 0;
alter table public.daily_check_ins add column if not exists created_at timestamptz default now();


-- ============================================================
-- 7. KYC VERIFICATIONS
-- ============================================================

create table if not exists public.kyc_verifications (
    id uuid primary key default gen_random_uuid(),
    user_id uuid,
    phase integer default 1,
    status text default 'pending',
    provider text,
    provider_reference text,
    verification_data jsonb,
    submitted_at timestamptz,
    verified_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

alter table public.kyc_verifications add column if not exists user_id uuid;
alter table public.kyc_verifications add column if not exists phase integer default 1;
alter table public.kyc_verifications add column if not exists status text default 'pending';
alter table public.kyc_verifications add column if not exists provider text;
alter table public.kyc_verifications add column if not exists provider_reference text;
alter table public.kyc_verifications add column if not exists verification_data jsonb;
alter table public.kyc_verifications add column if not exists submitted_at timestamptz;
alter table public.kyc_verifications add column if not exists verified_at timestamptz;
alter table public.kyc_verifications add column if not exists created_at timestamptz default now();
alter table public.kyc_verifications add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 8. SOCIAL TASKS
-- ============================================================

create table if not exists public.social_tasks (
    id uuid primary key default gen_random_uuid()
);

alter table public.social_tasks add column if not exists title text;
alter table public.social_tasks add column if not exists description text;
alter table public.social_tasks add column if not exists platform text;
alter table public.social_tasks add column if not exists url text;

alter table public.social_tasks
    add column if not exists reward_fan numeric(24,8) default 0;

alter table public.social_tasks
    add column if not exists requires_follow boolean default true;

alter table public.social_tasks
    add column if not exists requires_like boolean default true;

alter table public.social_tasks
    add column if not exists requires_comment boolean default true;

alter table public.social_tasks
    add column if not exists requires_share boolean default true;

alter table public.social_tasks
    add column if not exists is_active boolean default true;

alter table public.social_tasks
    add column if not exists post_external_id text;

alter table public.social_tasks
    add column if not exists post_published_at timestamptz;

alter table public.social_tasks
    add column if not exists starts_at timestamptz;

alter table public.social_tasks
    add column if not exists ends_at timestamptz;

alter table public.social_tasks
    add column if not exists created_at timestamptz default now();

alter table public.social_tasks
    add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 9. SOCIAL TASK CLAIMS
-- ============================================================

create table if not exists public.social_task_claims (
    id uuid primary key default gen_random_uuid()
);

alter table public.social_task_claims add column if not exists user_id uuid;
alter table public.social_task_claims add column if not exists task_id uuid;
alter table public.social_task_claims add column if not exists task_date date default current_date;

alter table public.social_task_claims
    add column if not exists follow_verified boolean default false;

alter table public.social_task_claims
    add column if not exists like_verified boolean default false;

alter table public.social_task_claims
    add column if not exists comment_verified boolean default false;

alter table public.social_task_claims
    add column if not exists share_verified boolean default false;

alter table public.social_task_claims
    add column if not exists reward_amount numeric(24,8) default 0;

alter table public.social_task_claims
    add column if not exists started_at timestamptz;

alter table public.social_task_claims
    add column if not exists verified_at timestamptz;

alter table public.social_task_claims
    add column if not exists claimed_at timestamptz;

alter table public.social_task_claims
    add column if not exists created_at timestamptz default now();


-- ============================================================
-- 10. USER SOCIAL FOLLOWS
-- ============================================================

create table if not exists public.user_social_follows (
    id uuid primary key default gen_random_uuid()
);

alter table public.user_social_follows add column if not exists user_id uuid;
alter table public.user_social_follows add column if not exists platform text;
alter table public.user_social_follows add column if not exists external_account_id text;
alter table public.user_social_follows add column if not exists verified boolean default false;
alter table public.user_social_follows add column if not exists verified_at timestamptz;
alter table public.user_social_follows add column if not exists created_at timestamptz default now();
alter table public.user_social_follows add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 11. LEGACY SOCIAL REWARDS
-- ============================================================

create table if not exists public.social_rewards (
    id uuid primary key default gen_random_uuid()
);

alter table public.social_rewards add column if not exists user_id uuid;
alter table public.social_rewards add column if not exists reward_date date default current_date;
alter table public.social_rewards add column if not exists reward_amount numeric(24,8) default 0;
alter table public.social_rewards add column if not exists created_at timestamptz default now();


-- ============================================================
-- 12. TRANSACTIONS
-- ============================================================

create table if not exists public.transactions (
    id uuid primary key default gen_random_uuid()
);

alter table public.transactions add column if not exists user_id uuid;
alter table public.transactions add column if not exists asset text;
alter table public.transactions add column if not exists transaction_type text;
alter table public.transactions add column if not exists amount numeric(24,8);
alter table public.transactions add column if not exists balance_before numeric(24,8);
alter table public.transactions add column if not exists balance_after numeric(24,8);
alter table public.transactions add column if not exists reference_id uuid;
alter table public.transactions add column if not exists description text;
alter table public.transactions add column if not exists created_at timestamptz default now();


-- ============================================================
-- 13. APP SETTINGS
-- ============================================================
--
-- IMPORTANT:
-- Current Flutter expects:
--
--   select('value')
--   eq('key', 'minimum_supported_version')
--
-- ============================================================

create table if not exists public.app_settings (
    key text,
    value text,
    updated_at timestamptz default now()
);


-- ============================================================
-- 14. APP SETTINGS JSONB -> TEXT FIX
-- ============================================================

do $$
declare
    v_type text;
begin

    select data_type
    into v_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_settings'
      and column_name = 'value';

    if v_type = 'jsonb' then

        alter table public.app_settings
        alter column value type text
        using (
            case
                when jsonb_typeof(value) = 'string'
                    then value #>> '{}'
                else
                    value::text
            end
        );

    elsif v_type = 'json' then

        alter table public.app_settings
        alter column value type text
        using value::text;

    end if;

end
$$;


alter table public.app_settings
    add column if not exists key text;

alter table public.app_settings
    add column if not exists value text;

alter table public.app_settings
    add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 15. APP SETTINGS DEFAULT
-- ============================================================

update public.app_settings
set
    key = 'minimum_supported_version',
    value = '1.0.0',
    updated_at = now()
where key is null
and not exists (
    select 1
    from public.app_settings
    where key = 'minimum_supported_version'
);


insert into public.app_settings (
    key,
    value
)
select
    'minimum_supported_version',
    '1.0.0'
where not exists (
    select 1
    from public.app_settings
    where key = 'minimum_supported_version'
);


-- ============================================================
-- 16. DEVICE REGISTRATIONS
-- ============================================================

create table if not exists public.device_registrations (
    id uuid primary key default gen_random_uuid()
);

alter table public.device_registrations add column if not exists user_id uuid;
alter table public.device_registrations add column if not exists device_id text;
alter table public.device_registrations add column if not exists platform text;
alter table public.device_registrations add column if not exists app_version text;
alter table public.device_registrations add column if not exists last_seen_at timestamptz default now();
alter table public.device_registrations add column if not exists created_at timestamptz default now();
alter table public.device_registrations add column if not exists updated_at timestamptz default now();


-- ============================================================
-- 17. INDEXES
-- ============================================================

-- Profiles

create index if not exists idx_profiles_referred_by
on public.profiles(referred_by);

create index if not exists idx_profiles_mining_active
on public.profiles(
    mining_active,
    mining_started_at,
    mining_ends_at
);


-- Mining

create index if not exists idx_mining_sessions_user
on public.mining_sessions(
    user_id,
    started_at desc
);

create index if not exists idx_mining_sessions_active
on public.mining_sessions(
    user_id,
    claimed,
    ends_at
);


-- Ads

create index if not exists idx_ad_rewards_user
on public.ad_rewards(
    user_id,
    watched_at desc
);

create index if not exists idx_ad_rewards_session
on public.ad_rewards(
    session_id,
    watched_at
);


-- Notifications

create index if not exists idx_notifications_user
on public.notifications(
    user_id,
    created_at desc
);


-- Referrals

create index if not exists idx_referral_rewards_inviter
on public.referral_rewards(
    inviter_id,
    created_at desc
);


-- Check-ins

create index if not exists idx_checkins_user
on public.daily_check_ins(
    user_id,
    check_in_date desc
);


-- KYC

create index if not exists idx_kyc_user
on public.kyc_verifications(
    user_id,
    phase
);


-- Social

create index if not exists idx_social_tasks_active
on public.social_tasks(
    is_active,
    starts_at,
    ends_at
);

create index if not exists idx_social_claims_user
on public.social_task_claims(
    user_id,
    task_date desc
);

create index if not exists idx_social_follows_user
on public.user_social_follows(
    user_id,
    platform
);


-- Transactions

create index if not exists idx_transactions_user
on public.transactions(
    user_id,
    created_at desc
);


-- ============================================================
-- 18. AD SESSION INDEX
-- ============================================================

create unique index if not exists
ux_ad_rewards_session_ad_number
on public.ad_rewards(
    session_id,
    ad_number
)
where session_id is not null
and ad_number is not null;


-- ============================================================
-- 19. REFERRAL CODE GENERATOR
-- ============================================================

create or replace function public.generate_referral_code(
    input_name text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    v_base text;
    v_code text;
begin

    v_base :=
        upper(
            regexp_replace(
                coalesce(input_name, 'FAN'),
                '[^A-Za-z0-9]',
                '',
                'g'
            )
        );

    if v_base = '' then
        v_base := 'FAN';
    end if;

    v_base := left(v_base, 8);

    loop

        v_code :=
            v_base ||
            upper(
                substr(
                    md5(random()::text),
                    1,
                    6
                )
            );

        exit when not exists (
            select 1
            from public.profiles
            where referral_code = v_code
        );

    end loop;

    return v_code;

end;
$$;


-- ============================================================
-- 20. NEW USER PROFILE
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_name text;
    v_email text;
    v_code text;
begin

    v_name :=
        coalesce(
            new.raw_user_meta_data ->> 'name',
            new.raw_user_meta_data ->> 'full_name',
            new.raw_user_meta_data ->> 'display_name',
            ''
        );

    v_email := new.email;

    v_code :=
        public.generate_referral_code(v_name);

    insert into public.profiles(
        id,
        name,
        email,
        referral_code
    )
    values(
        new.id,
        nullif(v_name, ''),
        v_email,
        v_code
    )
    on conflict (id)
    do nothing;

    return new;

end;
$$;


-- ============================================================
-- 21. AUTH TRIGGER
-- ============================================================

drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();


-- ============================================================
-- 22. UPDATED_AT FUNCTION
-- ============================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin

    new.updated_at := now();

    return new;

end;
$$;


-- ============================================================
-- 23. UPDATED_AT TRIGGERS
-- ============================================================

drop trigger if exists profiles_updated_at
on public.profiles;

create trigger profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();


drop trigger if exists kyc_verifications_updated_at
on public.kyc_verifications;

create trigger kyc_verifications_updated_at
before update on public.kyc_verifications
for each row
execute function public.set_updated_at();


drop trigger if exists social_tasks_updated_at
on public.social_tasks;

create trigger social_tasks_updated_at
before update on public.social_tasks
for each row
execute function public.set_updated_at();


drop trigger if exists user_social_follows_updated_at
on public.user_social_follows;

create trigger user_social_follows_updated_at
before update on public.user_social_follows
for each row
execute function public.set_updated_at();


drop trigger if exists app_settings_updated_at
on public.app_settings;

create trigger app_settings_updated_at
before update on public.app_settings
for each row
execute function public.set_updated_at();


drop trigger if exists device_registrations_updated_at
on public.device_registrations;

create trigger device_registrations_updated_at
before update on public.device_registrations
for each row
execute function public.set_updated_at();


-- ============================================================
-- 24. DEFAULT MINING VALUES
-- ============================================================

update public.profiles
set mining_rate = 0.20
where mining_rate is null;

update public.profiles
set fan_balance = 0
where fan_balance is null;

update public.profiles
set afam_balance = 0
where afam_balance is null;

update public.profiles
set active_referrals = 0
where active_referrals is null;

update public.profiles
set daily_ads_watched = 0
where daily_ads_watched is null;

update public.profiles
set ad_boost = 0
where ad_boost is null;

update public.profiles
set mining_active = false
where mining_active is null;

update public.profiles
set consecutive_check_ins = 0
where consecutive_check_ins is null;


-- ============================================================
-- 25. FINAL
-- ============================================================

-- Schema creation completed.
-- Mining RPC functions will be installed separately
-- in mining_engine.sql.


-- ============================================================
-- END
-- ============================================================
