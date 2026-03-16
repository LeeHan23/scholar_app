-- Papers table
create table papers (
  id bigint generated always as identity primary key,
  title text not null,
  authors text not null,
  journal text,
  year int,
  doi text,
  abstract text,
  status text not null default 'unread',
  user_id uuid references auth.users(id) on delete cascade not null,
  project_id bigint,
  tags text,
  location_name text,
  latitude double precision,
  longitude double precision,
  page_number int,
  created_at timestamptz default now()
);

-- Projects table
create table projects (
  id bigint generated always as identity primary key,
  name text not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  created_at timestamptz default now()
);

-- Foreign key from papers to projects
alter table papers
  add constraint papers_project_id_fkey
  foreign key (project_id) references projects(id) on delete set null;

-- Enable Row Level Security
alter table papers enable row level security;
alter table projects enable row level security;

-- RLS policies: users can only access their own data
create policy "Users can view own papers"
  on papers for select using (auth.uid() = user_id);

create policy "Users can insert own papers"
  on papers for insert with check (auth.uid() = user_id);

create policy "Users can update own papers"
  on papers for update using (auth.uid() = user_id);

create policy "Users can delete own papers"
  on papers for delete using (auth.uid() = user_id);

create policy "Users can view own projects"
  on projects for select using (auth.uid() = user_id);

create policy "Users can insert own projects"
  on projects for insert with check (auth.uid() = user_id);

create policy "Users can update own projects"
  on projects for update using (auth.uid() = user_id);

create policy "Users can delete own projects"
  on projects for delete using (auth.uid() = user_id);
