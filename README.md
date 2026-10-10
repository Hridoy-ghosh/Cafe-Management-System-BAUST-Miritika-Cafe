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
3. Apply the migration with `npx.cmd supabase db push`, or run
   `supabase/migrations/20261010000100_cafe_management.sql` in the project's
   SQL Editor.
4. Copy `.env.example` to `.env`, then set `CAFE_SUPABASE_URL` and
   `CAFE_SUPABASE_ANON_KEY` to this project's Project URL and publishable (or
   legacy anon) key. Never use a `service_role` or secret key in Flutter.
5. Create the cafe-admin account through Supabase Auth. In the SQL Editor,
   promote that account using its Auth user UUID:

   ```sql
   update public.user_profiles
   set role = 'cafe_admin', department = 'Cafe'
   where id = 'AUTH_USER_UUID';
   ```

   The SQL Editor runs with project-owner privileges; customers cannot promote
   their own accounts. Supabase email confirmation settings determine whether
   customers need to confirm their email before signing in.
6. Run `flutter pub get`, then `flutter run`.

Until the dedicated project is configured, the app shows a setup screen rather
than connecting to the unrelated BAUST Nexus database.

## Current modules

- Cafe customer sign-up and sign-in
- Menu browsing, cart, and order placement
- Cafe-admin order and menu screens
- Cafe-admin inventory, low-stock visibility, suppliers, purchases, and stock
  adjustments

Purchase recording and stock adjustments are database transactions implemented
as Supabase RPC functions and protected by row-level security.
