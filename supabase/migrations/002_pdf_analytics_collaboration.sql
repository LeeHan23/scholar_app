-- Migration: Add PDF storage, reading analytics, and collaboration support

-- 1. PDF storage: add pdf_url to papers
alter table papers add column if not exists pdf_url text;

-- 2. Analytics: track when a paper was marked as read
alter table papers add column if not exists read_at timestamptz;

-- 3. Collaboration: project members junction table
create table if not exists project_members (
  id bigint generated always as identity primary key,
  project_id bigint references projects(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role text not null default 'viewer' check (role in ('owner', 'editor', 'viewer')),
  invited_email text,
  accepted boolean not null default false,
  created_at timestamptz default now(),
  unique (project_id, user_id)
);

-- RLS for project_members
alter table project_members enable row level security;

-- Project owners can manage members
create policy "Project owners can view members"
  on project_members for select
  using (
    user_id = auth.uid()
    or project_id in (
      select project_id from project_members where user_id = auth.uid()
    )
  );

create policy "Project owners can insert members"
  on project_members for insert
  with check (
    project_id in (
      select id from projects where user_id = auth.uid()
    )
  );

create policy "Project owners can update members"
  on project_members for update
  using (
    project_id in (
      select id from projects where user_id = auth.uid()
    )
  );

create policy "Project owners can delete members"
  on project_members for delete
  using (
    project_id in (
      select id from projects where user_id = auth.uid()
    )
  );

-- 4. Allow collaborators to view papers in shared projects
create policy "Collaborators can view shared papers"
  on papers for select
  using (
    auth.uid() = user_id
    or project_id in (
      select project_id from project_members
      where user_id = auth.uid() and accepted = true
    )
  );

-- 5. Supabase Storage bucket for PDFs
-- Run in Supabase dashboard SQL editor or via CLI:
-- insert into storage.buckets (id, name, public) values ('papers', 'papers', false);
--
-- Storage RLS policies:
-- create policy "Users can upload PDFs"
--   on storage.objects for insert
--   with check (bucket_id = 'papers' and auth.uid()::text = (storage.foldername(name))[1]);
--
-- create policy "Users can view own PDFs"
--   on storage.objects for select
--   using (bucket_id = 'papers' and auth.uid()::text = (storage.foldername(name))[1]);
--
-- create policy "Users can delete own PDFs"
--   on storage.objects for delete
--   using (bucket_id = 'papers' and auth.uid()::text = (storage.foldername(name))[1]);
