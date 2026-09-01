-- supabase/rls.sql

alter table public.profiles enable row level security;
alter table public.notifications enable row level security;
alter table public.mining_sessions enable row level security;
alter table public.ad_rewards enable row level security;
alter table public.social_rewards enable row level security;
alter table public.referral_rewards enable row level security;
alter table public.daily_check_ins enable row level security;
alter table public.kyc_verifications enable row level security;

drop policy if exists "Users can view own profile"
on public.profiles;

create policy "Users can view own profile"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Users can update own profile"
on public.profiles;

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Users can view own notifications"
on public.notifications;

create policy "Users can view own notifications"
on public.notifications
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can update own notifications"
on public.notifications;

create policy "Users can update own notifications"
on public.notifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can view own mining sessions"
on public.mining_sessions;

create policy "Users can view own mining sessions"
on public.mining_sessions
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can view own ad rewards"
on public.ad_rewards;

create policy "Users can view own ad rewards"
on public.ad_rewards
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can view own social rewards"
on public.social_rewards;

create policy "Users can view own social rewards"
on public.social_rewards
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can view own referral rewards"
on public.referral_rewards;

create policy "Users can view own referral rewards"
on public.referral_rewards
for select
to authenticated
using (
  auth.uid() = inviter_id
  or auth.uid() = referred_user_id
);

drop policy if exists "Users can view own check ins"
on public.daily_check_ins;

create policy "Users can view own check ins"
on public.daily_check_ins
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can view own kyc"
on public.kyc_verifications;

create policy "Users can view own kyc"
on public.kyc_verifications
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can update own kyc"
on public.kyc_verifications;

create policy "Users can update own kyc"
on public.kyc_verifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

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
