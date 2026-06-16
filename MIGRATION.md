# This site is migrating to the unified ClearBot app

The `signup.clearbot.io` subdomain is moving into the single Next.js
project at [`EthanSkis/clearbot.io`](https://github.com/EthanSkis/clearbot.io),
which now serves every `*.clearbot.io` host from one Vercel project.

The signup flow and `/book` booking form were ported into that repo's
`app/(signup)` route group. Supabase access moved to server-side
Route Handlers (`/api/auth/signup`, `/api/bookings`, etc.) so the
service-role key and the `consume_access_code` RPC are no longer
exposed to the browser.

## Cutover

Don't delete this repo's `CNAME` until `signup.clearbot.io` is pointed
at `cname.vercel-dns.com`. Staged order: `signup` → `login` → `client`
→ `team` → apex. Keep this repo live as a rollback target during the
cutover window.

## After cutover

Once DNS is flipped and the new app is serving `signup.clearbot.io`,
this repo can be archived. The `booking_requests.sql` migration in the
root of this repo is still canonical for the table it defines.
