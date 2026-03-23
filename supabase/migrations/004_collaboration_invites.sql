-- Migration: Collaboration invites — allow pending invitations before user signs up

-- 1. Make user_id nullable so we can store invitations for users who don't have accounts yet
alter table project_members alter column user_id drop not null;

-- 2. Add invite_token for secure invite link generation
alter table project_members add column if not exists invite_token uuid default gen_random_uuid();

-- 3. Replace the unique constraint (project_id, user_id) with partial indexes
--    because user_id can now be null (pending invites)
alter table project_members drop constraint if exists project_members_project_id_user_id_key;

-- Accepted members: unique per (project, user)
create unique index if not exists project_members_project_user_unique
  on project_members (project_id, user_id)
  where user_id is not null;

-- Pending invites: unique per (project, email)
create unique index if not exists project_members_project_email_unique
  on project_members (project_id, invited_email)
  where user_id is null;

-- 4. Drop and recreate RLS policies on project_members
drop policy if exists "Project owners can view members" on project_members;
drop policy if exists "Project owners can insert members" on project_members;
drop policy if exists "Project owners can update members" on project_members;
drop policy if exists "Project owners can delete members" on project_members;

-- SELECT: own row, or invited by email, or owner of the project
create policy "Members can view project_members"
  on project_members for select
  using (
    user_id = auth.uid()
    or invited_email = (auth.jwt() ->> 'email')
    or project_id in (
      select id from projects where user_id = auth.uid()
    )
  );

-- INSERT: only project owner can add members (via edge function with service role, or directly)
create policy "Project owners can insert members"
  on project_members for insert
  with check (
    project_id in (
      select id from projects where user_id = auth.uid()
    )
  );

-- UPDATE: project owner can change roles; invitee can accept their own pending invite
create policy "Owners and invitees can update members"
  on project_members for update
  using (
    project_id in (
      select id from projects where user_id = auth.uid()
    )
    or (
      user_id is null
      and invited_email = (auth.jwt() ->> 'email')
    )
  );

-- DELETE: only project owner can remove members
create policy "Project owners can delete members"
  on project_members for delete
  using (
    project_id in (
      select id from projects where user_id = auth.uid()
    )
  );

-- 5. Auto-accept pending invitations when a matching user signs up
create or replace function auto_accept_invitations()
returns trigger as $$
begin
  update project_members
  set user_id = new.id, accepted = true
  where user_id is null
    and invited_email = new.email
    and accepted = false;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_user_created_accept_invitations on auth.users;
create trigger on_user_created_accept_invitations
  after insert on auth.users
  for each row execute function auto_accept_invitations();

-- 6. Drop old papers collaborator SELECT policy and replace to handle email-based pending invites
drop policy if exists "Collaborators can view shared papers" on papers;

create policy "Users and collaborators can view papers"
  on papers for select
  using (
    auth.uid() = user_id
    or project_id in (
      select project_id from project_members
      where (user_id = auth.uid() or invited_email = (auth.jwt() ->> 'email'))
        and accepted = true
    )
  );
