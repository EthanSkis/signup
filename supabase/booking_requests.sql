-- Booking intake for signup.clearbot.io/book
-- Stores requests submitted by visitors who don't yet have an access code.
-- Paste into the Supabase SQL editor. Idempotent.

create extension if not exists "pgcrypto";

create table if not exists public.booking_requests (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  email                text not null,
  company              text,
  need                 text not null,
  preferred_slot       timestamptz,
  preferred_slot_label text,
  timezone             text,
  notes                text,
  consent_email        boolean not null default true,
  status               text not null default 'new' check (status in ('new','contacted','booked','closed')),
  created_at           timestamptz not null default now()
);

create index if not exists booking_requests_created_at_idx on public.booking_requests(created_at desc);
create index if not exists booking_requests_status_idx     on public.booking_requests(status);

-- Anonymous submissions from the public /book page — inserts only.
alter table public.booking_requests enable row level security;

drop policy if exists booking_requests_insert_public on public.booking_requests;
create policy booking_requests_insert_public
  on public.booking_requests
  for insert
  to anon, authenticated
  with check (true);

-- Only team members (profiles.role in 'admin','team') can read.
drop policy if exists booking_requests_read_team on public.booking_requests;
create policy booking_requests_read_team
  on public.booking_requests
  for select
  to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin','team')
  ));

drop policy if exists booking_requests_update_team on public.booking_requests;
create policy booking_requests_update_team
  on public.booking_requests
  for update
  to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.user_id = auth.uid()
      and p.role in ('admin','team')
  ))
  with check (true);

-- Email notification: wire a Supabase Database Webhook on INSERT to
-- trigger an Edge Function (or Zapier/Make/Resend) that emails
-- ethan@clearbot.io. Kept out-of-repo on purpose — the table is the
-- durable source of truth either way.
