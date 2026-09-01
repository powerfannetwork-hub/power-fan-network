-- supabase/schema.sql

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  name text not null default '',
  email text not null default '',

  referral_code text not null unique,
  referred_by uuid references public.profiles(id) on delete set null,

  fan_balance numeric(30,8) not null default 0,
  afam_balance numeric(30,8) not null default 0,

  mining_rate numeric(12,4) not null default 0.2,
  active_referrals integer not null default 0,

  daily_ads_watched integer not null default 0,
  ad_boost numeric(12,4) not null default 0,

  mining_active boolean not null default false,
  mining_started_at timestamptz,
  mining_ends_at timestamptz,

  consecutive_check_ins integer not null default 0,

  kyc1_eligible boolean not null default false,
  kyc1_verified boolean not null default false,

  kyc2_eligible boolean not null default false,
  kyc2_verified boolean not null default false,

  kyc3_verified boolean not null default false,

  last_social_claim_date date,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_referred_by_idx
on public.profiles(referred_by);

create index if not exists profiles_referral_code_idx
on public.profiles(referral_code);

create index if not exists profiles_created_at_idx
on public.profiles(created_at);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  title text not null,
  message text not null,

  type text not null default 'general',
  is_read boolean not null default false,

  created_at timestamptz not null default now()
);

create index if not exists notifications_user_id_idx
on public.notifications(user_id);

create index if not exists notifications_created_at_idx
on public.notifications(created_at desc);

create table if not exists public.mining_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  started_at timestamptz not null,
  ends_at timestamptz not null,

  mining_rate numeric(12,4) not null default 0.2,
  reward numeric(30,8) not null default 0,

  status text not null default 'active'
    check (status in ('active', 'completed', 'claimed', 'cancelled')),

  claimed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists mining_sessions_user_id_idx
on public.mining_sessions(user_id);

create index if not exists mining_sessions_status_idx
on public.mining_sessions(status);

create table if not exists public.ad_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  ad_number integer not null,
  reward_rate numeric(12,4) not null default 0.1,

  watched_at timestamptz not null default now()
);

create index if not exists ad_rewards_user_id_idx
on public.ad_rewards(user_id);

create index if not exists ad_rewards_watched_at_idx
on public.ad_rewards(watched_at);

create table if not exists public.social_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  reward numeric(30,8) not null default 10,
  claim_date date not null,

  created_at timestamptz not null default now(),

  unique(user_id, claim_date)
);

create index if not exists social_rewards_user_id_idx
on public.social_rewards(user_id);

create table if not exists public.referral_rewards (
  id uuid primary key default gen_random_uuid(),

  inviter_id uuid not null references public.profiles(id) on delete cascade,
  referred_user_id uuid not null references public.profiles(id) on delete cascade,

  inviter_reward numeric(30,8) not null default 5,
  new_user_reward numeric(30,8) not null default 20,

  created_at timestamptz not null default now(),

  unique(referred_user_id)
);

create index if not exists referral_rewards_inviter_idx
on public.referral_rewards(inviter_id);

create index if not exists referral_rewards_referred_idx
on public.referral_rewards(referred_user_id);

create table if not exists public.daily_check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  check_in_date date not null,
  reward numeric(30,8) not null default 0,

  created_at timestamptz not null default now(),

  unique(user_id, check_in_date)
);

create index if not exists daily_check_ins_user_id_idx
on public.daily_check_ins(user_id);

create index if not exists daily_check_ins_date_idx
on public.daily_check_ins(check_in_date);

create table if not exists public.kyc_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,

  kyc_level integer not null
    check (kyc_level in (1, 2, 3)),

  status text not null default 'pending'
    check (
      status in (
        'pending',
        'eligible',
        'submitted',
        'verified',
        'rejected'
      )
    ),

  submitted_at timestamptz,
  verified_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(user_id, kyc_level)
);

create index if not exists kyc_verifications_user_id_idx
on public.kyc_verifications(user_id);

create or replace function public.generate_referral_code(
  input_name text
)
returns text
language plpgsql
as $$
declare
  prefix text;
  generated text;
begin
  prefix := upper(
    regexp_replace(
      coalesce(input_name, 'FAN'),
      '[^A-Za-z0-9]',
      '',
      'g'
    )
  );

  prefix := substring(prefix from 1 for 5);

  if prefix = '' then
    prefix := 'FAN';
  end if;

  loop
    generated :=
      prefix ||
      floor(
        100000 + random() * 900000
      )::integer;

    exit when not exists (
      select 1
      from public.profiles
      where referral_code = generated
    );
  end loop;

  return generated;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  user_name text;
begin
  user_name := coalesce(
    new.raw_user_meta_data ->> 'name',
    new.raw_user_meta_data ->> 'full_name',
    ''
  );

  insert into public.profiles (
    id,
    name,
    email,
    referral_code,
    fan_balance,
    afam_balance,
    mining_rate
  )
  values (
    new.id,
    user_name,
    coalesce(new.email, ''),
    public.generate_referral_code(user_name),
    0,
    0,
    0.2
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

create or replace function public.update_profile_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at
on public.profiles;

create trigger profiles_updated_at
before update on public.profiles
for each row
execute function public.update_profile_timestamp();

drop trigger if exists kyc_updated_at
on public.kyc_verifications;

create trigger kyc_updated_at
before update on public.kyc_verifications
for each row
execute function public.update_profile_timestamp();
