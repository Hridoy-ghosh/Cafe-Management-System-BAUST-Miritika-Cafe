-- Employee scheduling, attendance, and customer feedback for the cafe.

create table if not exists public.cafe_shifts (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.user_profiles (id) on delete cascade,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  notes text,
  created_by uuid not null references public.user_profiles (id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists cafe_shifts_employee_start_idx
  on public.cafe_shifts (employee_id, starts_at desc);

create table if not exists public.cafe_attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.user_profiles (id) on delete cascade,
  shift_id uuid references public.cafe_shifts (id) on delete set null,
  work_date date not null default current_date,
  check_in timestamptz not null default now(),
  check_out timestamptz,
  notes text,
  recorded_by uuid not null references public.user_profiles (id),
  created_at timestamptz not null default now(),
  check (check_out is null or check_out >= check_in),
  unique (employee_id, work_date)
);

create index if not exists cafe_attendance_work_date_idx
  on public.cafe_attendance (work_date desc);

create table if not exists public.cafe_feedback (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.user_profiles (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  subject text not null,
  message text not null,
  status text not null default 'new'
    check (status in ('new', 'in_review', 'resolved')),
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists cafe_feedback_status_date_idx
  on public.cafe_feedback (status, created_at desc);

alter table public.cafe_shifts enable row level security;
alter table public.cafe_attendance enable row level security;
alter table public.cafe_feedback enable row level security;

drop policy if exists "Cafe admins manage staff roles" on public.user_profiles;
create policy "Cafe admins manage staff roles"
  on public.user_profiles for update to authenticated
  using ((select public.is_cafe_admin()))
  with check (
    (select public.is_cafe_admin())
    and (role <> 'cafe_admin' or id = (select auth.uid()))
  );

grant update (role, department) on public.user_profiles to authenticated;

drop policy if exists "Cafe admins manage shifts" on public.cafe_shifts;
create policy "Cafe admins manage shifts"
  on public.cafe_shifts for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins manage attendance" on public.cafe_attendance;
create policy "Cafe admins manage attendance"
  on public.cafe_attendance for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Customers submit cafe feedback" on public.cafe_feedback;
create policy "Customers submit cafe feedback"
  on public.cafe_feedback for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and exists (
      select 1 from public.user_profiles
      where id = (select auth.uid()) and role = 'customer'
    )
  );

drop policy if exists "Customers and cafe admins read feedback" on public.cafe_feedback;
create policy "Customers and cafe admins read feedback"
  on public.cafe_feedback for select to authenticated
  using (customer_id = (select auth.uid()) or (select public.is_cafe_admin()));

drop policy if exists "Cafe admins update feedback" on public.cafe_feedback;
create policy "Cafe admins update feedback"
  on public.cafe_feedback for update to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

grant select, insert, update, delete on public.cafe_shifts, public.cafe_attendance to authenticated;
grant select, insert, update on public.cafe_feedback to authenticated;

notify pgrst, 'reload schema';
