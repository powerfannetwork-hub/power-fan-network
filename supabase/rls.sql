-- ============================================================
-- POWER FAN NETWORK
-- ROW LEVEL SECURITY
-- ============================================================

-- ============================================================
-- 1. ENABLE RLS
-- ============================================================

alter table public.profiles
enable row level security;

alter table public.notifications
enable row level security;

alter table public.mining_sessions
enable row level security;

alter table public.ad_rewards
enable row level security;

alter table public.social_rewards
enable row level security;

alter table public.referral_rewards
enable row level security;

alter table public.daily_check_ins
enable row level security;

alter table public.kyc_verifications
enable row level security;


-- ============================================================
-- 2. PROTECTED PROFILE FIELDS
-- ============================================================
--
-- Users may update normal profile information such as:
-- name and email.
--
-- Mining/reward/security fields can ONLY be changed by
-- trusted SECURITY DEFINER database functions.
--
-- SECURITY DEFINER functions run as the database owner,
-- so current_user is different from the authenticated user.
-- ============================================================

create or replace function public.protect_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

    -- Trusted database functions are allowed.
    if current_user = 'postgres' then
        return new;
    end if;


    -- Authenticated users cannot modify reward/mining state.
    if new.id is distinct from old.id then
        raise exception 'Profile ID cannot be changed';
    end if;


    if new.fan_balance is distinct from old.fan_balance then
        raise exception 'FAN balance cannot be changed directly';
    end if;


    if new.afam_balance is distinct from old.afam_balance then
        raise exception 'AFAM balance cannot be changed directly';
    end if;


    if new.referral_code is distinct from old.referral_code then
        raise exception 'Referral code cannot be changed directly';
    end if;


    if new.referred_by is distinct from old.referred_by then
        raise exception 'Referral relationship cannot be changed directly';
    end if;


    if new.mining_rate is distinct from old.mining_rate then
        raise exception 'Mining rate cannot be changed directly';
    end if;


    if new.active_referrals is distinct from old.active_referrals then
        raise exception 'Active referrals cannot be changed directly';
    end if;


    if new.daily_ads_watched is distinct from old.daily_ads_watched then
        raise exception 'Daily ad count cannot be changed directly';
    end if;


    if new.ad_boost is distinct from old.ad_boost then
        raise exception 'Ad boost cannot be changed directly';
    end if;


    if new.mining_active is distinct from old.mining_active then
        raise exception 'Mining state cannot be changed directly';
    end if;


    if new.mining_started_at is distinct from old.mining_started_at then
        raise exception 'Mining start time cannot be changed directly';
    end if;


    if new.mining_ends_at is distinct from old.mining_ends_at then
        raise exception 'Mining end time cannot be changed directly';
    end if;


    if new.kyc1_eligible is distinct from old.kyc1_eligible then
        raise exception 'KYC eligibility cannot be changed directly';
    end if;


    if new.kyc1_verified is distinct from old.kyc1_verified then
        raise exception 'KYC verification cannot be changed directly';
    end if;


    if new.kyc2_eligible is distinct from old.kyc2_eligible then
        raise exception 'KYC eligibility cannot be changed directly';
    end if;


    if new.kyc2_verified is distinct from old.kyc2_verified then
        raise exception 'KYC verification cannot be changed directly';
    end if;


    if new.kyc3_verified is distinct from old.kyc3_verified then
        raise exception 'KYC verification cannot be changed directly';
    end if;


    if new.consecutive_check_ins is distinct from old.consecutive_check_ins then
        raise exception 'Check-in streak cannot be changed directly';
    end if;


    if new.last_social_claim_date is distinct from old.last_social_claim_date then
        raise exception 'Social claim state cannot be changed directly';
    end if;


    return new;

end;
$$;


drop trigger if exists protect_profile_fields_trigger
on public.profiles;


create trigger protect_profile_fields_trigger
before update on public.profiles
for each row
execute function public.protect_profile_fields();


-- ============================================================
-- 3. DROP OLD POLICIES
-- ============================================================

drop policy if exists "Users can view own profile"
on public.profiles;

drop policy if exists "Users can update own profile"
on public.profiles;

drop policy if exists "Users can view own notifications"
on public.notifications;

drop policy if exists "Users can update own notifications"
on public.notifications;

drop policy if exists "Users can view own mining sessions"
on public.mining_sessions;

drop policy if exists "Users can view own ad rewards"
on public.ad_rewards;

drop policy if exists "Users can view own social rewards"
on public.social_rewards;

drop policy if exists "Users can view own referral rewards"
on public.referral_rewards;

drop policy if exists "Users can view own check ins"
on public.daily_check_ins;

drop policy if exists "Users can view own kyc"
on public.kyc_verifications;

drop policy if exists "Users can update own kyc"
on public.kyc_verifications;


-- ============================================================
-- 4. PROFILES
-- ============================================================

create policy "Users can view own profile"
on public.profiles
for select
to authenticated
using (
    auth.uid() = id
);


create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (
    auth.uid() = id
)
with check (
    auth.uid() = id
);


-- ============================================================
-- 5. NOTIFICATIONS
-- ============================================================

create policy "Users can view own notifications"
on public.notifications
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "Users can update own notifications"
on public.notifications
for update
to authenticated
using (
    auth.uid() = user_id
)
with check (
    auth.uid() = user_id
);


-- ============================================================
-- 6. MINING SESSIONS
-- ============================================================

create policy "Users can view own mining sessions"
on public.mining_sessions
for select
to authenticated
using (
    auth.uid() = user_id
);


-- ============================================================
-- 7. AD REWARDS
-- ============================================================

create policy "Users can view own ad rewards"
on public.ad_rewards
for select
to authenticated
using (
    auth.uid() = user_id
);


-- ============================================================
-- 8. SOCIAL REWARDS
-- ============================================================

create policy "Users can view own social rewards"
on public.social_rewards
for select
to authenticated
using (
    auth.uid() = user_id
);


-- ============================================================
-- 9. REFERRAL REWARDS
-- ============================================================

create policy "Users can view own referral rewards"
on public.referral_rewards
for select
to authenticated
using (
    auth.uid() = inviter_id
    or auth.uid() = referred_user_id
);


-- ============================================================
-- 10. DAILY CHECK-INS
-- ============================================================

create policy "Users can view own check ins"
on public.daily_check_ins
for select
to authenticated
using (
    auth.uid() = user_id
);


-- ============================================================
-- 11. KYC
-- ============================================================

create policy "Users can view own kyc"
on public.kyc_verifications
for select
to authenticated
using (
    auth.uid() = user_id
);


create policy "Users can update own kyc"
on public.kyc_verifications
for update
to authenticated
using (
    auth.uid() = user_id
)
with check (
    auth.uid() = user_id
);


-- ============================================================
-- 12. REMOVE ANON ACCESS
-- ============================================================

revoke all
on public.profiles
from anon;

revoke all
on public.notifications
from anon;

revoke all
on public.mining_sessions
from anon;

revoke all
on public.ad_rewards
from anon;

revoke all
on public.social_rewards
from anon;

revoke all
on public.referral_rewards
from anon;

revoke all
on public.daily_check_ins
from anon;

revoke all
on public.kyc_verifications
from anon;


-- ============================================================
-- 13. AUTHENTICATED GRANTS
-- ============================================================

grant select
on public.profiles
to authenticated;

grant update
on public.profiles
to authenticated;


grant select
on public.notifications
to authenticated;

grant update
on public.notifications
to authenticated;


grant select
on public.mining_sessions
to authenticated;


grant select
on public.ad_rewards
to authenticated;


grant select
on public.social_rewards
to authenticated;


grant select
on public.referral_rewards
to authenticated;


grant select
on public.daily_check_ins
to authenticated;


grant select
on public.kyc_verifications
to authenticated;

grant update
on public.kyc_verifications
to authenticated;


-- ============================================================
-- END OF RLS
-- ============================================================
