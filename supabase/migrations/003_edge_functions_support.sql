-- Migration: Add user_profiles table and helpers for edge function support

-- 1. User profiles table for subscription/pro status tracking
create table if not exists user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  is_pro boolean not null default false,
  pro_since timestamptz,
  email text,
  display_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Enable RLS
alter table user_profiles enable row level security;

-- Users can read their own profile
create policy "Users can view own profile"
  on user_profiles for select
  using (auth.uid() = id);

-- Users can update their own profile (but not is_pro — that should be
-- managed server-side via service role or webhook)
create policy "Users can update own profile"
  on user_profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Users can insert their own profile (on first sign-up)
create policy "Users can insert own profile"
  on user_profiles for insert
  with check (auth.uid() = id);

-- 2. Auto-create a user_profiles row on new user sign-up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.user_profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Drop trigger if it already exists to make migration idempotent
drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3. Helper function: count papers created by a user in the current calendar month
create or replace function public.monthly_capture_count(p_user_id uuid)
returns integer
language sql
stable
security definer
as $$
  select count(*)::integer
  from papers
  where user_id = p_user_id
    and created_at >= date_trunc('month', now())
    and created_at < date_trunc('month', now()) + interval '1 month';
$$;

-- 4. Update the updated_at column automatically
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger user_profiles_updated_at
  before update on user_profiles
  for each row execute function public.set_updated_at();
