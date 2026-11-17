# BAUST Miritika Cafe Management System

Flutter cafe ordering and cafe-admin application for BAUST Miritika Cafe.

## Dedicated Supabase setup

This app uses a separate Supabase project from BAUST Nexus. Creating that
project requires a Supabase account owner; the app does not reuse the old BAUST
Nexus project.

1. Create a Supabase project for BAUST Miritika Cafe.
2. Sign the Supabase CLI in locally and link this project:

   ```powershell
   npx.cmd supabase login
   npx.cmd supabase link --project-ref okpptouzgyloafmwdnay
   ```

   The CLI may request the database password. Enter it only in the local
   terminal prompt; do not send it in chat or commit it.
3. Apply **all** migrations to the dedicated project in timestamp order with
   `npx.cmd supabase db push`, or run every SQL file in
   `supabase/migrations/` in timestamp order in the project's SQL Editor.
   Running only the initial migration is insufficient: later migrations add
   the account status and role-request logic used by sign-up and sign-in.
4. Copy `.env.example` to `.env`, then set `CAFE_SUPABASE_URL` and
   `CAFE_SUPABASE_ANON_KEY` to this project's Project URL and publishable (or
   legacy anon) key. Never use a `service_role` or secret key in Flutter.
5. Provision the cafe-admin account using the Supabase Auth Admin API or
   Dashboard (never public sign-up). Use `cafeadmin@gmail.com` and set the
   trusted **app metadata** value `{"cafe_role":"cafe_admin"}` when creating
   the user. The Auth trigger grants the cafe-admin role only when this
   server-managed metadata is present; public user metadata and matching an
   email address alone cannot grant admin access. Set the password directly in
   Supabase Auth; never put it in Flutter source or `.env`.

   If the owner user already exists, promote it from the SQL Editor after
   verifying its Auth UUID:

   ```sql
   update public.user_profiles
   set role = 'cafe_admin', department = 'Cafe', status = 'approved'
   where id = 'AUTH_USER_UUID'
     and lower(email) = 'cafeadmin@gmail.com';
   ```
   The SQL Editor runs with project-owner privileges; customers cannot promote
   their own accounts. Public registration of the reserved owner email is
   rejected. Email confirmation is disabled in the linked Supabase project so
   regular customers can sign in immediately after account creation.
6. Run `flutter pub get`, then `flutter run`.

Until the dedicated project is configured, the app shows a setup screen rather
than connecting to the unrelated BAUST Nexus database.

## Current modules

- Cafe customer sign-up and sign-in
- Role requests for managers, cashiers, kitchen staff, waiters, suppliers, and
  university authority, pending owner approval
- Menu browsing, cart, persistent order placement, billing, order status, and
  sales records
- Cafe-admin menu, staff approval, shift scheduling, attendance, and feedback
  management
- Owner/manager inventory, low-stock visibility, suppliers, purchases, and
  stock adjustments
- Persistent light/dark theme preference

Purchase recording and stock adjustments are database transactions implemented
as Supabase RPC functions and protected by row-level security.
