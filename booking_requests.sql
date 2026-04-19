-- ============================================================================
-- booking_requests
-- ----------------------------------------------------------------------------
-- Backing table for https://signup.clearbot.io/book. The form previously used
-- a mailto: link (which broke for anyone without a configured mail client);
-- it now inserts here and fires a DB-level notification so nothing is lost.
--
-- Run this in the Supabase SQL editor. It is idempotent.
-- ============================================================================

create extension if not exists "pgcrypto";

create table if not exists public.booking_requests (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  email                text not null,
  company              text,
  focus                text,             -- brand / web / ads / content / video / other
  preferred_slot       timestamptz,      -- ISO datetime from the form
  preferred_slot_label text,             -- pre-rendered "Tue Mar 12 · 2:00 PM EST"
  timezone             text,             -- IANA tz from the browser
  notes                text,
  source               text,             -- e.g. 'signup.clearbot.io/book'
  status               text not null default 'new',  -- new / contacted / scheduled / dropped
  created_at           timestamptz not null default now()
);

create index if not exists booking_requests_created_at_idx
  on public.booking_requests (created_at desc);

alter table public.booking_requests enable row level security;

-- Anyone (including anon) can insert a booking request.
drop policy if exists booking_requests_anon_insert on public.booking_requests;
create policy booking_requests_anon_insert
  on public.booking_requests
  for insert
  to anon, authenticated
  with check (true);

-- Only team members (profiles.role in ('admin', 'team')) can read / update.
drop policy if exists booking_requests_team_read on public.booking_requests;
create policy booking_requests_team_read
  on public.booking_requests
  for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'team')
    )
  );

drop policy if exists booking_requests_team_update on public.booking_requests;
create policy booking_requests_team_update
  on public.booking_requests
  for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid()
        and p.role in ('admin', 'team')
    )
  );

-- ----------------------------------------------------------------------------
-- Notification hook
-- ----------------------------------------------------------------------------
-- When a new request arrives, emit a pg_notify event so an Edge Function
-- or external listener (e.g. a tiny Supabase function posting to Resend /
-- Postmark) can turn it into an email to ethan@clearbot.io.
-- ----------------------------------------------------------------------------
create or replace function public.booking_requests_notify()
returns trigger
language plpgsql
as $$
begin
  perform pg_notify(
    'booking_request',
    json_build_object(
      'id', new.id,
      'name', new.name,
      'email', new.email,
      'focus', new.focus,
      'preferred_slot_label', new.preferred_slot_label
    )::text
  );
  return new;
end;
$$;

drop trigger if exists booking_requests_notify_trg on public.booking_requests;
create trigger booking_requests_notify_trg
  after insert on public.booking_requests
  for each row execute function public.booking_requests_notify();
