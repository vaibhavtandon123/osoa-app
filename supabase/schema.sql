-- =====================================================================
-- OSOA Desk — Supabase schema (Phase 1)
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Safe to run once on a fresh project.
-- =====================================================================

create extension if not exists citext;

-- ---------------------------------------------------------------------
-- PEOPLE
-- ---------------------------------------------------------------------
-- Public-ish profile (name, photo, city) — any logged-in user can read.
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      citext unique not null check (username ~ '^[a-z0-9._]{3,30}$'),
  full_name     text not null,
  photo_path    text,
  state         text,
  city          text,
  account_type  text not null default 'volunteer' check (account_type in ('volunteer','artist')),
  category      text,
  bio           text,
  instagram     text,
  is_super      boolean not null default false,
  is_disabled   boolean not null default false,
  created_at    timestamptz not null default now()
);

-- Private details — self, super admins, event admins, and the person's team heads.
create table public.profile_private (
  id                 uuid primary key references public.profiles(id) on delete cascade,
  mobile             text,
  email              text,
  dob                date,
  address            text,
  blood_group        text,
  tshirt_size        text,
  skills             text,
  emergency_name     text,
  emergency_relation text,
  emergency_mobile   text,
  terms_accepted_at  timestamptz,
  updated_at         timestamptz not null default now()
);

-- Aadhaar — self, super admins and event admins only. Every view is logged.
create table public.profile_secret (
  id               uuid primary key references public.profiles(id) on delete cascade,
  aadhaar_number   text,
  aadhaar_path     text,
  consent_at       timestamptz,
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- PROGRAMS & EVENTS
-- ---------------------------------------------------------------------
create table public.programs (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  short      text not null,
  desk_name  text not null,
  color      text not null default '#D4A017' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  logo_path  text,
  sort       int not null default 0
);

create table public.events (
  id             uuid primary key default gen_random_uuid(),
  program_id     uuid not null references public.programs(id),
  name           text not null,
  start_date     date not null,
  end_date       date,
  time_text      text,
  venue          text,
  city           text,
  state          text,
  map_url        text,
  contact_name   text,
  contact_phone  text,
  about          text,
  cover_path     text,
  status         text not null default 'Upcoming' check (status in ('Upcoming','Live','Completed')),
  is_public      boolean not null default true,
  reg_open       boolean not null default true,
  budget_total   numeric(14,2) not null default 0,
  approval_limit numeric(14,2) not null default 25000,
  created_by     uuid references public.profiles(id),
  created_at     timestamptz not null default now()
);

-- One row per person per event. Volunteers and artists start as 'pending'.
create table public.memberships (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  role          text not null check (role in ('admin','volunteer','artist')),
  status        text not null default 'pending' check (status in ('pending','approved','rejected')),
  category      text,
  bio           text,
  art_title     text,
  artworks      text[] not null default '{}',
  checked_in    boolean not null default false,
  checked_in_at timestamptz,
  checked_in_by uuid references public.profiles(id),
  note          text,
  decided_by    uuid references public.profiles(id),
  decided_at    timestamptz,
  created_at    timestamptz not null default now(),
  unique (event_id, user_id)
);

-- ---------------------------------------------------------------------
-- TEAMS & SECTION ACCESS
-- ---------------------------------------------------------------------
create table public.teams (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  name       text not null,
  head_id    uuid references public.profiles(id),
  sort       int not null default 0,
  created_at timestamptz not null default now(),
  unique (event_id, name)
);

create table public.team_members (
  team_id   uuid not null references public.teams(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  event_id  uuid not null references public.events(id) on delete cascade,
  added_by  uuid references public.profiles(id),
  added_at  timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- Sections a volunteer can be given: artists (artists + check-in), finance,
-- tasks (tasks + announcements + schedule), people (teams + people + profiles).
create table public.section_access (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  section     text not null check (section in ('artists','finance','tasks','people')),
  granted_by  uuid references public.profiles(id),
  expires_at  timestamptz,            -- null = until turned off
  revoked_at  timestamptz,
  created_at  timestamptz not null default now()
);

create table public.access_requests (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  section     text not null check (section in ('artists','finance','tasks','people')),
  reason      text,
  status      text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_by  uuid references public.profiles(id),
  decided_at  timestamptz,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- WORK
-- ---------------------------------------------------------------------
create table public.tasks (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  team_id     uuid references public.teams(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  title       text not null,
  detail      text,
  due         date,
  status      text not null default 'open' check (status in ('open','done')),
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now(),
  done_at     timestamptz
);

create table public.announcements (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  title       text not null,
  body        text,
  audience    text not null default 'all' check (audience in ('all','volunteer','artist')),
  created_by  uuid references public.profiles(id),
  created_at  timestamptz not null default now()
);

create table public.schedule_items (
  id        uuid primary key default gen_random_uuid(),
  event_id  uuid not null references public.events(id) on delete cascade,
  day       date,
  time_text text,
  title     text not null,
  detail    text
);

-- ---------------------------------------------------------------------
-- FINANCE
-- ---------------------------------------------------------------------
create table public.budget_heads (
  id        uuid primary key default gen_random_uuid(),
  event_id  uuid not null references public.events(id) on delete cascade,
  name      text not null,
  alloc     numeric(14,2) not null default 0,
  sort      int not null default 0,
  unique (event_id, name)
);

create table public.vendors (
  id              uuid primary key default gen_random_uuid(),
  event_id        uuid not null references public.events(id) on delete cascade,
  name            text not null,
  service         text,
  phone           text,
  contract_amount numeric(14,2) not null default 0,
  note            text,
  created_at      timestamptz not null default now()
);

-- Money in: sponsor, donation, registration, grant, adopt (Adopt an Artist).
create table public.income (
  id           uuid primary key default gen_random_uuid(),
  event_id     uuid not null references public.events(id) on delete cascade,
  kind         text not null check (kind in ('sponsor','donation','registration','grant','adopt')),
  source_name  text not null,
  source_phone text,
  source_email text,
  amount       numeric(14,2) not null check (amount > 0),
  account      text not null default 'bank' check (account in ('cash','bank')),
  mode         text not null default 'UPI' check (mode in ('Cash','UPI','Bank','Cheque')),
  received_on  date not null default current_date,
  artist_id    uuid references public.profiles(id),   -- for Adopt an Artist
  note         text,
  proof_path   text,
  created_by   uuid references public.profiles(id),
  created_at   timestamptz not null default now()
);

-- Money out: expense / reimbursement / advance.  requested -> approved -> paid (or rejected)
create table public.expenses (
  id             uuid primary key default gen_random_uuid(),
  event_id       uuid not null references public.events(id) on delete cascade,
  kind           text not null default 'expense' check (kind in ('expense','reimbursement','advance')),
  head           text not null,
  team_id        uuid references public.teams(id) on delete set null,
  vendor_id      uuid references public.vendors(id) on delete set null,
  payee          text,                                  -- who receives the money
  amount         numeric(14,2) not null check (amount > 0),
  description    text,
  spent_on       date not null default current_date,
  bill_path      text,
  status         text not null default 'requested' check (status in ('requested','approved','rejected','paid')),
  needs_admin    boolean not null default false,        -- above approval limit
  requested_by   uuid references public.profiles(id),
  approved_by    uuid references public.profiles(id),
  approved_at    timestamptz,
  reject_reason  text,
  paid_by        uuid references public.profiles(id),
  paid_at        timestamptz,
  account        text check (account in ('cash','bank')),
  mode           text check (mode in ('Cash','UPI','Bank','Cheque')),
  settled_amount numeric(14,2) not null default 0,      -- for advances: amount accounted for
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- SUPPORT + AUDIT
-- ---------------------------------------------------------------------
create table public.support_messages (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete set null,
  event_id   uuid references public.events(id) on delete set null,
  subject    text not null,
  message    text not null,
  meta       jsonb,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id         bigserial primary key,
  event_id   uuid,
  actor_id   uuid,
  action     text not null,
  entity     text,
  entity_id  text,
  detail     jsonb,
  at         timestamptz not null default now()
);

create index on public.memberships (event_id, role, status);
create index on public.memberships (user_id);
create index on public.team_members (user_id);
create index on public.tasks (event_id);
create index on public.expenses (event_id, status);
create index on public.income (event_id);
create index on public.audit_log (event_id, at desc);
create index on public.section_access (event_id, user_id);

-- =====================================================================
-- HELPER FUNCTIONS (used by the security rules)
-- =====================================================================
create or replace function public.is_super() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_super and not is_disabled from profiles where id = auth.uid()), false)
$$;

create or replace function public.event_role(ev uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when public.is_super() then 'admin'
    else (select role from memberships where event_id = ev and user_id = auth.uid() and status = 'approved') end
$$;

create or replace function public.is_event_admin(ev uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.event_role(ev) = 'admin'
$$;

create or replace function public.is_member(ev uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.event_role(ev) is not null
$$;

create or replace function public.is_team_head(tm uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from teams where id = tm and head_id = auth.uid())
$$;

create or replace function public.heads_event(ev uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from teams where event_id = ev and head_id = auth.uid())
$$;

-- Does the caller lead a team the given person belongs to?
create or replace function public.leads_person(person uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from team_members m join teams t on t.id = m.team_id
                where m.user_id = person and t.head_id = auth.uid())
$$;

-- Is the caller an admin of any event the given person is part of?
create or replace function public.admins_person(person uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_super() or exists(
    select 1 from memberships mine join memberships theirs on theirs.event_id = mine.event_id
    where mine.user_id = auth.uid() and mine.role = 'admin' and mine.status = 'approved'
      and theirs.user_id = person)
$$;

create or replace function public.in_finance_team(ev uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from teams t left join team_members m on m.team_id = t.id
    where t.event_id = ev and t.name ilike '%financ%' and (t.head_id = auth.uid() or m.user_id = auth.uid()))
$$;

-- Section access: admins always; finance team gets 'finance'; otherwise an active grant.
create or replace function public.has_section(ev uuid, sec text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_event_admin(ev)
    or (sec = 'finance' and public.in_finance_team(ev))
    or exists(select 1 from section_access a where a.event_id = ev and a.user_id = auth.uid() and a.section = sec
              and a.revoked_at is null and (a.expires_at is null or a.expires_at > now()))
$$;

create or replace function public.log_action(ev uuid, act text, ent text, ent_id text, det jsonb)
returns void language sql security definer set search_path = public as $$
  insert into audit_log(event_id, actor_id, action, entity, entity_id, detail) values (ev, auth.uid(), act, ent, ent_id, det)
$$;

-- Contact number of a head/admin, visible to anyone in the same event (for the Team Map).
create or replace function public.contact_of(person uuid, ev uuid) returns text
language sql stable security definer set search_path = public as $$
  select p.mobile from profile_private p
  where p.id = person and public.is_member(ev)
    and (exists(select 1 from teams where event_id = ev and head_id = person)
         or exists(select 1 from memberships where event_id = ev and user_id = person and role = 'admin')
         or public.is_event_admin(ev) or public.leads_person(person) or person = auth.uid())
$$;

-- Aadhaar read goes through this function so every view is logged.
create or replace function public.read_aadhaar(person uuid) returns table(aadhaar_number text, aadhaar_path text)
language plpgsql security definer set search_path = public as $$
begin
  if not (person = auth.uid() or public.admins_person(person)) then
    raise exception 'Not allowed';
  end if;
  if person <> auth.uid() then
    insert into audit_log(actor_id, action, entity, entity_id) values (auth.uid(), 'Viewed Aadhaar', 'profile', person::text);
  end if;
  return query select s.aadhaar_number, s.aadhaar_path from profile_secret s where s.id = person;
end $$;

-- =====================================================================
-- NEW USER: create profile rows from sign-up data
-- =====================================================================
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into profiles(id, username, full_name, state, city, account_type)
  values (new.id, lower(m->>'username'), coalesce(m->>'full_name',''), m->>'state', m->>'city',
          case when m->>'account_type' = 'artist' then 'artist' else 'volunteer' end);
  insert into profile_private(id, mobile, email, terms_accepted_at)
  values (new.id, m->>'mobile', new.email, now());
  insert into profile_secret(id) values (new.id);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Nobody can make themselves super admin or re-enable themselves.
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.is_super is distinct from old.is_super or new.is_disabled is distinct from old.is_disabled)
     and auth.uid() is not null and not public.is_super() then
    raise exception 'Only super admins can change this.';
  end if;
  if new.is_super is distinct from old.is_super and new.id = auth.uid() and not new.is_super then
    raise exception 'You cannot remove your own super admin access.';
  end if;
  return new;
end $$;
create trigger guard_profile before update on public.profiles
  for each row execute function public.guard_profile();

-- Username / mobile -> email lookup for login (used only by the server function).
create or replace function public.login_email(identifier text) returns text
language sql stable security definer set search_path = public as $$
  select pp.email from profiles p join profile_private pp on pp.id = p.id
  where (p.username = lower(trim(identifier)) or right(regexp_replace(pp.mobile,'\D','','g'),10) = right(regexp_replace(identifier,'\D','','g'),10))
    and not p.is_disabled
  limit 1
$$;
revoke all on function public.login_email(text) from public, anon, authenticated;

-- =====================================================================
-- AUDIT TRIGGERS (who added / approved / changed what)
-- =====================================================================
create or replace function public.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare ev uuid; rid text; det jsonb;
begin
  if tg_op = 'DELETE' then
    ev := (to_jsonb(old)->>'event_id')::uuid; rid := coalesce(to_jsonb(old)->>'id', to_jsonb(old)->>'user_id'); det := to_jsonb(old);
  else
    ev := (to_jsonb(new)->>'event_id')::uuid; rid := coalesce(to_jsonb(new)->>'id', to_jsonb(new)->>'user_id');
    det := case when tg_op = 'UPDATE' then jsonb_build_object('old', to_jsonb(old), 'new', to_jsonb(new)) else to_jsonb(new) end;
  end if;
  if tg_table_name = 'events' then ev := coalesce((to_jsonb(new)->>'id')::uuid, (to_jsonb(old)->>'id')::uuid); end if;
  insert into audit_log(event_id, actor_id, action, entity, entity_id, detail)
  values (ev, auth.uid(), lower(tg_op), tg_table_name, rid, det);
  return coalesce(new, old);
end $$;

do $$ declare t text; begin
  foreach t in array array['events','memberships','teams','team_members','section_access','access_requests',
                           'tasks','announcements','schedule_items','budget_heads','vendors','income','expenses'] loop
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$s for each row execute function public.audit_row()', t);
  end loop;
end $$;

-- =====================================================================
-- FINANCE RULES: approval limit + admin-only above it
-- =====================================================================
create or replace function public.guard_expense() returns trigger
language plpgsql security definer set search_path = public as $$
declare lim numeric;
begin
  select approval_limit into lim from events where id = new.event_id;
  new.needs_admin := new.amount > coalesce(lim, 25000);
  if tg_op = 'INSERT' then
    new.requested_by := auth.uid(); new.status := 'requested';
    new.approved_by := null; new.approved_at := null; new.paid_by := null; new.paid_at := null;
    return new;
  end if;
  if new.status is distinct from old.status then
    if new.status in ('approved','rejected') then
      if new.needs_admin and not public.is_event_admin(new.event_id) then
        raise exception 'Amount is above the approval limit. Only an admin can approve this.';
      end if;
      if not public.has_section(new.event_id, 'finance') then raise exception 'Not allowed'; end if;
      if new.status = 'rejected' and coalesce(trim(new.reject_reason),'') = '' then
        raise exception 'Please give a reason for rejecting.';
      end if;
      new.approved_by := auth.uid(); new.approved_at := now();
    elsif new.status = 'paid' then
      if old.status <> 'approved' then raise exception 'Only approved requests can be marked paid.'; end if;
      if new.account is null or new.mode is null then raise exception 'Choose cash/bank and payment mode.'; end if;
      new.paid_by := auth.uid(); new.paid_at := now();
    end if;
  end if;
  return new;
end $$;
create trigger guard_expense before insert or update on public.expenses
  for each row execute function public.guard_expense();

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles         enable row level security;
alter table public.profile_private  enable row level security;
alter table public.profile_secret   enable row level security;
alter table public.programs         enable row level security;
alter table public.events           enable row level security;
alter table public.memberships      enable row level security;
alter table public.teams            enable row level security;
alter table public.team_members     enable row level security;
alter table public.section_access   enable row level security;
alter table public.access_requests  enable row level security;
alter table public.tasks            enable row level security;
alter table public.announcements    enable row level security;
alter table public.schedule_items   enable row level security;
alter table public.budget_heads     enable row level security;
alter table public.vendors          enable row level security;
alter table public.income           enable row level security;
alter table public.expenses         enable row level security;
alter table public.support_messages enable row level security;
alter table public.audit_log        enable row level security;

-- profiles
create policy "profiles read"   on public.profiles for select to authenticated using (true);
create policy "profiles self"   on public.profiles for update to authenticated using (id = auth.uid() or public.is_super());

-- private details: self, admins of their events, their team heads
create policy "private read" on public.profile_private for select to authenticated
  using (id = auth.uid() or public.admins_person(id) or public.leads_person(id));
create policy "private self" on public.profile_private for update to authenticated using (id = auth.uid());

-- Aadhaar: only self can write; reading goes through read_aadhaar() (logged)
create policy "secret self read"  on public.profile_secret for select to authenticated using (id = auth.uid());
create policy "secret self write" on public.profile_secret for update to authenticated using (id = auth.uid());

-- programs: everyone reads (public pages), super admins write
create policy "programs read"  on public.programs for select using (true);
create policy "programs write" on public.programs for all to authenticated using (public.is_super()) with check (public.is_super());

-- events: public ones visible to everyone; members see theirs; only super admins create/delete
create policy "events read" on public.events for select using (is_public or public.is_member(id));
create policy "events create" on public.events for insert to authenticated with check (public.is_super());
create policy "events edit"   on public.events for update to authenticated using (public.is_event_admin(id));
create policy "events delete" on public.events for delete to authenticated using (public.is_super());

-- memberships
create policy "members read" on public.memberships for select to authenticated using (
  user_id = auth.uid() or public.is_event_admin(event_id)
  or (role = 'artist' and status = 'approved' and public.is_member(event_id))
  or (role <> 'artist' and public.is_member(event_id))
  or (role = 'artist' and public.has_section(event_id,'artists')));
-- join request: anyone can ask to join a public event as volunteer/artist (pending)
create policy "members join" on public.memberships for insert to authenticated with check (
  (user_id = auth.uid() and role in ('volunteer','artist') and status = 'pending'
     and exists(select 1 from events e where e.id = event_id and e.reg_open))
  or public.is_event_admin(event_id)
  or (role = 'volunteer' and public.heads_event(event_id)));
create policy "members update" on public.memberships for update to authenticated using (
  public.is_event_admin(event_id)
  or (role = 'volunteer' and public.heads_event(event_id))
  or (role = 'artist' and public.has_section(event_id,'artists'))
  or (user_id = auth.uid() and status <> 'approved'));
-- Only the right people can change role / approval status.
create or replace function public.guard_membership() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.is_event_admin(new.event_id) then return new; end if;
  if new.role is distinct from old.role then raise exception 'Only admins can change roles.'; end if;
  if new.status is distinct from old.status then
    if not ((new.role = 'volunteer' and public.heads_event(new.event_id))
         or (new.role = 'artist' and public.has_section(new.event_id,'artists'))) then
      raise exception 'You cannot approve this request.';
    end if;
    new.decided_by := auth.uid(); new.decided_at := now();
  end if;
  if new.checked_in is distinct from old.checked_in then
    if not public.has_section(new.event_id,'artists') then raise exception 'You do not have check-in access.'; end if;
    new.checked_in_by := auth.uid(); new.checked_in_at := case when new.checked_in then now() end;
  end if;
  return new;
end $$;
create trigger guard_membership before update on public.memberships
  for each row execute function public.guard_membership();
create policy "members delete" on public.memberships for delete to authenticated using (public.is_event_admin(event_id));

-- Public gallery of approved artists (no login) is served by a function:
create or replace function public.public_gallery(ev uuid)
returns table(name text, photo_path text, state text, city text, category text, bio text, instagram text, art_title text, artworks text[])
language sql stable security definer set search_path = public as $$
  select p.full_name, p.photo_path, p.state, p.city, coalesce(m.category,p.category), coalesce(m.bio,p.bio), p.instagram, m.art_title, m.artworks
  from memberships m join profiles p on p.id = m.user_id join events e on e.id = m.event_id
  where m.event_id = ev and m.role = 'artist' and m.status = 'approved' and e.is_public
$$;
grant execute on function public.public_gallery(uuid) to anon, authenticated;

-- teams
create policy "teams read"   on public.teams for select to authenticated using (public.is_member(event_id));
create policy "teams admin"  on public.teams for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "tm read"      on public.team_members for select to authenticated using (public.is_member(event_id));
create policy "tm write"     on public.team_members for insert to authenticated with check (public.is_event_admin(event_id) or public.is_team_head(team_id));
create policy "tm delete"    on public.team_members for delete to authenticated using (public.is_event_admin(event_id) or public.is_team_head(team_id));

-- section access: admins + team heads (for their own members) grant; person sees own
create policy "access read" on public.section_access for select to authenticated
  using (user_id = auth.uid() or public.is_event_admin(event_id) or public.leads_person(user_id));
create policy "access grant" on public.section_access for insert to authenticated
  with check (public.is_event_admin(event_id) or public.leads_person(user_id));
create policy "access revoke" on public.section_access for update to authenticated
  using (public.is_event_admin(event_id) or public.leads_person(user_id));
create policy "req read" on public.access_requests for select to authenticated
  using (user_id = auth.uid() or public.is_event_admin(event_id) or public.leads_person(user_id));
create policy "req create" on public.access_requests for insert to authenticated
  with check (user_id = auth.uid() and public.is_member(event_id) and status = 'pending');
create policy "req decide" on public.access_requests for update to authenticated
  using (public.is_event_admin(event_id) or public.leads_person(user_id));

-- tasks / announcements / schedule
create policy "tasks read" on public.tasks for select to authenticated using (
  public.has_section(event_id,'tasks') or assigned_to = auth.uid()
  or (team_id is not null and (public.is_team_head(team_id) or exists(select 1 from team_members m where m.team_id = tasks.team_id and m.user_id = auth.uid())))
  or (assigned_to is null and team_id is null and public.is_member(event_id)));
create policy "tasks write" on public.tasks for insert to authenticated with check (
  public.has_section(event_id,'tasks') or (team_id is not null and public.is_team_head(team_id)));
create policy "tasks update" on public.tasks for update to authenticated using (
  public.has_section(event_id,'tasks') or (team_id is not null and public.is_team_head(team_id))
  or assigned_to = auth.uid()
  or (team_id is not null and exists(select 1 from team_members m where m.team_id = tasks.team_id and m.user_id = auth.uid())));
create policy "tasks delete" on public.tasks for delete to authenticated using (
  public.has_section(event_id,'tasks') or (team_id is not null and public.is_team_head(team_id)));

create policy "ann read"  on public.announcements for select to authenticated using (
  public.has_section(event_id,'tasks') or (public.is_member(event_id) and (audience = 'all' or audience = public.event_role(event_id))));
create policy "ann write" on public.announcements for all to authenticated
  using (public.has_section(event_id,'tasks')) with check (public.has_section(event_id,'tasks'));
create policy "sched read"  on public.schedule_items for select using (
  exists(select 1 from events e where e.id = event_id and e.is_public) or public.is_member(event_id));
create policy "sched write" on public.schedule_items for all to authenticated
  using (public.has_section(event_id,'tasks')) with check (public.has_section(event_id,'tasks'));

-- finance
create policy "heads read"   on public.budget_heads for select to authenticated using (public.has_section(event_id,'finance'));
create policy "heads write"  on public.budget_heads for all to authenticated using (public.is_event_admin(event_id)) with check (public.is_event_admin(event_id));
create policy "vendors rw"   on public.vendors for all to authenticated using (public.has_section(event_id,'finance')) with check (public.has_section(event_id,'finance'));
create policy "income rw"    on public.income for all to authenticated using (public.has_section(event_id,'finance')) with check (public.has_section(event_id,'finance'));
create policy "exp read"     on public.expenses for select to authenticated using (public.has_section(event_id,'finance') or requested_by = auth.uid());
create policy "exp request"  on public.expenses for insert to authenticated with check (public.is_member(event_id));
create policy "exp update"   on public.expenses for update to authenticated using (public.has_section(event_id,'finance'));
create policy "exp delete"   on public.expenses for delete to authenticated using (public.is_event_admin(event_id));

-- support + audit
create policy "support send" on public.support_messages for insert to authenticated with check (user_id = auth.uid());
create policy "support read" on public.support_messages for select to authenticated using (public.is_super() or user_id = auth.uid());
create policy "audit read"   on public.audit_log for select to authenticated using (
  (event_id is not null and public.is_event_admin(event_id)) or public.is_super()
  or (event_id is not null and public.heads_event(event_id)));

-- =====================================================================
-- STORAGE (photos public-by-link; Aadhaar + bills private)
-- =====================================================================
insert into storage.buckets (id, name, public) values
  ('public-media', 'public-media', true),   -- profile photos, artworks, logos, covers
  ('private-docs', 'private-docs', false)   -- aadhaar/<user>/..., bills/<event>/..., proofs/<event>/...
on conflict (id) do nothing;

create policy "media upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'public-media');
create policy "media update own" on storage.objects for update to authenticated
  using (bucket_id = 'public-media' and owner = auth.uid());

create policy "aadhaar upload self" on storage.objects for insert to authenticated
  with check (bucket_id = 'private-docs' and (storage.foldername(name))[1] = 'aadhaar' and (storage.foldername(name))[2] = auth.uid()::text);
create policy "aadhaar read" on storage.objects for select to authenticated
  using (bucket_id = 'private-docs' and (storage.foldername(name))[1] = 'aadhaar'
         and ((storage.foldername(name))[2] = auth.uid()::text or public.admins_person(((storage.foldername(name))[2])::uuid)));
create policy "finance docs upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'private-docs' and (storage.foldername(name))[1] in ('bills','proofs')
              and public.is_member(((storage.foldername(name))[2])::uuid));
create policy "finance docs read" on storage.objects for select to authenticated
  using (bucket_id = 'private-docs' and (storage.foldername(name))[1] in ('bills','proofs')
         and (public.has_section(((storage.foldername(name))[2])::uuid, 'finance') or owner = auth.uid()));

-- =====================================================================
-- STARTING DATA
-- =====================================================================
insert into public.programs (name, short, desk_name, color, sort) values
  ('One State One Artist', 'OSOA', 'OSOA Desk', '#D4A017', 1),
  ('Paint with Prakash',   'PWP',  'PWP Desk',  '#D4A017', 2),
  ('Workshop',             'Workshop', 'Workshop Desk', '#D4A017', 3);

-- After you sign up in the app with username "vaibhavtandon", run this once:
--   update public.profiles set is_super = true where username = 'vaibhavtandon';
