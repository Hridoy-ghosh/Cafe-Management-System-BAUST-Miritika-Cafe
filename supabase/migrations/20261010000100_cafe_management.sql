-- Dedicated BAUST Miritika Cafe schema.
-- Apply this migration only to the separate cafe Supabase project.

create table if not exists public.user_profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text not null unique,
  role text not null default 'customer'
    check (role in ('customer', 'cafe_admin', 'manager', 'cashier', 'chef', 'waiter')),
  department text not null default 'Customer',
  phone_number text,
  created_at timestamptz not null default now()
);

create or replace function public.create_cafe_customer_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_profiles (id, full_name, email, phone_number)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), 'Cafe Customer'),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone_number', '')
  );
  return new;
end;
$$;

drop trigger if exists on_cafe_auth_user_created on auth.users;
create trigger on_cafe_auth_user_created
after insert on auth.users
for each row execute function public.create_cafe_customer_profile();

create or replace function public.is_cafe_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_profiles
    where id = (select auth.uid())
      and role = 'cafe_admin'
  );
$$;

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default 'Other',
  unit text not null default 'pcs',
  stock_quantity numeric(12, 3) not null default 0 check (stock_quantity >= 0),
  reorder_level numeric(12, 3) not null default 0 check (reorder_level >= 0),
  unit_cost numeric(12, 2) not null default 0 check (unit_cost >= 0),
  supplier_id uuid references public.suppliers (id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_purchases (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.suppliers (id),
  purchased_by uuid not null references public.user_profiles (id),
  total_amount numeric(12, 2) not null default 0 check (total_amount >= 0),
  notes text,
  purchased_at timestamptz not null default now()
);

create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.inventory_purchases (id) on delete cascade,
  item_id uuid not null references public.inventory_items (id),
  quantity numeric(12, 3) not null check (quantity > 0),
  unit_cost numeric(12, 2) not null check (unit_cost >= 0),
  line_total numeric(12, 2) generated always as (quantity * unit_cost) stored
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.inventory_items (id),
  changed_by uuid not null references public.user_profiles (id),
  movement_type text not null check (movement_type in ('purchase', 'adjustment')),
  quantity_delta numeric(12, 3) not null,
  unit_cost numeric(12, 2) not null default 0,
  purchase_id uuid references public.inventory_purchases (id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists inventory_items_name_idx on public.inventory_items (name);
create index if not exists inventory_items_supplier_idx on public.inventory_items (supplier_id);
create index if not exists inventory_purchases_date_idx on public.inventory_purchases (purchased_at desc);
create index if not exists inventory_movements_item_date_idx
  on public.inventory_movements (item_id, created_at desc);

alter table public.user_profiles enable row level security;
alter table public.suppliers enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.inventory_movements enable row level security;

drop policy if exists "Cafe users can view their own profile" on public.user_profiles;
create policy "Cafe users can view their own profile"
  on public.user_profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_cafe_admin()));

drop policy if exists "Cafe users can update their own customer profile" on public.user_profiles;
create policy "Cafe users can update their own customer profile"
  on public.user_profiles for update to authenticated
  using (id = (select auth.uid()) and role = 'customer')
  with check (id = (select auth.uid()) and role = 'customer');

grant usage on schema public to authenticated;
grant select, update (full_name, phone_number) on public.user_profiles to authenticated;

drop policy if exists "Cafe admins manage suppliers" on public.suppliers;
create policy "Cafe admins manage suppliers"
  on public.suppliers for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins manage inventory" on public.inventory_items;
create policy "Cafe admins manage inventory"
  on public.inventory_items for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins manage purchases" on public.inventory_purchases;
create policy "Cafe admins manage purchases"
  on public.inventory_purchases for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins manage purchase lines" on public.purchase_items;
create policy "Cafe admins manage purchase lines"
  on public.purchase_items for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins view stock movements" on public.inventory_movements;
create policy "Cafe admins view stock movements"
  on public.inventory_movements for select to authenticated
  using ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins record stock movements" on public.inventory_movements;
create policy "Cafe admins record stock movements"
  on public.inventory_movements for insert to authenticated
  with check ((select public.is_cafe_admin()));

grant select, insert, update, delete
  on public.suppliers, public.inventory_items, public.inventory_purchases,
     public.purchase_items, public.inventory_movements
  to authenticated;

create or replace function public.record_inventory_purchase(
  p_supplier_id uuid,
  p_items jsonb,
  p_notes text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_purchase_id uuid;
  v_line jsonb;
  v_item_id uuid;
  v_quantity numeric(12, 3);
  v_unit_cost numeric(12, 2);
  v_total numeric(12, 2) := 0;
begin
  if not (select public.is_cafe_admin()) then
    raise exception 'Only cafe admins can record inventory purchases';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one purchase item is required';
  end if;

  insert into public.inventory_purchases (supplier_id, purchased_by, notes)
  values (p_supplier_id, (select auth.uid()), p_notes)
  returning id into v_purchase_id;

  for v_line in select value from jsonb_array_elements(p_items)
  loop
    v_item_id := (v_line ->> 'item_id')::uuid;
    v_quantity := (v_line ->> 'quantity')::numeric;
    v_unit_cost := (v_line ->> 'unit_cost')::numeric;

    if v_quantity <= 0 or v_unit_cost < 0 then
      raise exception 'Purchase quantity must be positive and cost cannot be negative';
    end if;

    perform 1 from public.inventory_items where id = v_item_id for update;
    if not found then
      raise exception 'Inventory item not found';
    end if;

    insert into public.purchase_items (purchase_id, item_id, quantity, unit_cost)
    values (v_purchase_id, v_item_id, v_quantity, v_unit_cost);

    update public.inventory_items
    set stock_quantity = stock_quantity + v_quantity,
        unit_cost = v_unit_cost,
        supplier_id = p_supplier_id,
        updated_at = now()
    where id = v_item_id;

    insert into public.inventory_movements (
      item_id, changed_by, movement_type, quantity_delta, unit_cost, purchase_id
    )
    values (
      v_item_id, (select auth.uid()), 'purchase', v_quantity, v_unit_cost, v_purchase_id
    );

    v_total := v_total + v_quantity * v_unit_cost;
  end loop;

  update public.inventory_purchases
  set total_amount = v_total
  where id = v_purchase_id;

  return v_purchase_id;
end;
$$;

create or replace function public.adjust_inventory_stock(
  p_item_id uuid,
  p_quantity_delta numeric,
  p_reason text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not (select public.is_cafe_admin()) then
    raise exception 'Only cafe admins can adjust inventory';
  end if;
  if p_quantity_delta = 0 or nullif(trim(p_reason), '') is null then
    raise exception 'A non-zero adjustment and reason are required';
  end if;

  update public.inventory_items
  set stock_quantity = stock_quantity + p_quantity_delta,
      updated_at = now()
  where id = p_item_id
    and stock_quantity + p_quantity_delta >= 0;

  if not found then
    raise exception 'Inventory item not found or adjustment would make stock negative';
  end if;

  insert into public.inventory_movements (
    item_id, changed_by, movement_type, quantity_delta, reason
  )
  values (p_item_id, (select auth.uid()), 'adjustment', p_quantity_delta, p_reason);
end;
$$;

grant execute on function public.record_inventory_purchase(uuid, jsonb, text) to authenticated;
grant execute on function public.adjust_inventory_stock(uuid, numeric, text) to authenticated;

-- After a cafe admin signs up through Supabase Auth, promote only that user
-- from the Supabase SQL editor using their auth.users UUID:
-- update public.user_profiles set role = 'cafe_admin', department = 'Cafe'
-- where id = 'AUTH_USER_UUID';

notify pgrst, 'reload schema';
