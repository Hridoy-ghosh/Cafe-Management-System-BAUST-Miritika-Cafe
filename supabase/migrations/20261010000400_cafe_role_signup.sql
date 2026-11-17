-- Role requests are stored on profiles. Cafe admin access requires trusted
-- app metadata set by the project owner, never a public signup field or email.

alter table public.user_profiles
  add column if not exists status text not null default 'approved';

alter table public.user_profiles
  drop constraint if exists user_profiles_role_check;
alter table public.user_profiles
  add constraint user_profiles_role_check
  check (role in (
    'customer', 'cafe_admin', 'manager', 'cashier', 'chef', 'waiter',
    'supplier', 'university_authority'
  ));

alter table public.user_profiles
  drop constraint if exists user_profiles_status_check;
alter table public.user_profiles
  add constraint user_profiles_status_check
  check (status in ('pending', 'approved', 'rejected'));

create or replace function public.create_cafe_customer_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requested_role text := lower(coalesce(
    new.raw_user_meta_data ->> 'requested_role',
    'customer'
  ));
  v_cafe_role text := lower(coalesce(
    new.raw_app_meta_data ->> 'cafe_role',
    ''
  ));
  v_role text;
  v_status text;
  v_department text;
begin
  if v_cafe_role = 'cafe_admin'
    and lower(coalesce(new.email, '')) = 'cafeadmin@gmail.com' then
    v_role := 'cafe_admin';
    v_status := 'approved';
    v_department := 'Cafe';
  elsif lower(coalesce(new.email, '')) = 'cafeadmin@gmail.com'
    or v_cafe_role = 'cafe_admin' then
    raise exception 'Cafe owner accounts must be provisioned by the project owner';
  elsif v_requested_role in (
    'manager', 'cashier', 'chef', 'waiter', 'supplier',
    'university_authority'
  ) then
    v_role := v_requested_role;
    v_status := 'pending';
    v_department := case v_role
      when 'manager' then 'Management'
      when 'cashier' then 'Sales & Billing'
      when 'chef' then 'Kitchen'
      when 'waiter' then 'Service'
      when 'supplier' then 'Suppliers'
      when 'university_authority' then 'University Authority'
      else 'Customer'
    end;
  else
    v_role := 'customer';
    v_status := 'approved';
    v_department := 'Customer';
  end if;

  insert into public.user_profiles (
    id, full_name, email, phone_number, role, department, status
  )
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), 'Cafe Customer'),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone_number', ''),
    v_role,
    v_department,
    v_status
  );
  return new;
end;
$$;

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
      and status = 'approved'
  );
$$;

drop policy if exists "Cafe admins manage staff roles" on public.user_profiles;
create policy "Cafe admins manage staff roles"
  on public.user_profiles for update to authenticated
  using ((select public.is_cafe_admin()))
  with check (
    (select public.is_cafe_admin())
    and (role <> 'cafe_admin' or id = (select auth.uid()))
  );

grant update (role, department, status) on public.user_profiles to authenticated;

create or replace function public.can_manage_cafe_inventory()
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
      and status = 'approved'
      and role in ('cafe_admin', 'manager')
  );
$$;

drop policy if exists "Cafe admins manage suppliers" on public.suppliers;
create policy "Cafe management manage suppliers"
  on public.suppliers for all to authenticated
  using ((select public.can_manage_cafe_inventory()))
  with check ((select public.can_manage_cafe_inventory()));

drop policy if exists "Cafe admins manage inventory" on public.inventory_items;
create policy "Cafe management manage inventory"
  on public.inventory_items for all to authenticated
  using ((select public.can_manage_cafe_inventory()))
  with check ((select public.can_manage_cafe_inventory()));

drop policy if exists "Cafe admins manage purchases" on public.inventory_purchases;
create policy "Cafe management manage purchases"
  on public.inventory_purchases for all to authenticated
  using ((select public.can_manage_cafe_inventory()))
  with check ((select public.can_manage_cafe_inventory()));

drop policy if exists "Cafe admins manage purchase lines" on public.purchase_items;
create policy "Cafe management manage purchase lines"
  on public.purchase_items for all to authenticated
  using ((select public.can_manage_cafe_inventory()))
  with check ((select public.can_manage_cafe_inventory()));

drop policy if exists "Cafe admins view stock movements" on public.inventory_movements;
create policy "Cafe management view stock movements"
  on public.inventory_movements for select to authenticated
  using ((select public.can_manage_cafe_inventory()));

drop policy if exists "Cafe admins record stock movements" on public.inventory_movements;
create policy "Cafe management record stock movements"
  on public.inventory_movements for insert to authenticated
  with check ((select public.can_manage_cafe_inventory()));

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
  if not (select public.can_manage_cafe_inventory()) then
    raise exception 'Only cafe admins and managers can record inventory purchases';
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
  if not (select public.can_manage_cafe_inventory()) then
    raise exception 'Only cafe admins and managers can adjust inventory';
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

create or replace function public.can_manage_cafe_orders()
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
      and status = 'approved'
      and role in (
        'cafe_admin', 'manager', 'cashier', 'chef', 'waiter'
      )
  );
$$;

drop policy if exists "Customers and cafe admins view orders" on public.cafe_orders;
create policy "Customers and cafe admins view orders"
  on public.cafe_orders for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.can_manage_cafe_orders())
  );

drop policy if exists "Cafe admins update orders" on public.cafe_orders;
create policy "Cafe admins update orders"
  on public.cafe_orders for update to authenticated
  using ((select public.can_manage_cafe_orders()))
  with check ((select public.can_manage_cafe_orders()));

drop policy if exists "Cafe admins delete orders" on public.cafe_orders;
create policy "Cafe admins delete orders"
  on public.cafe_orders for delete to authenticated
  using ((select public.is_cafe_admin()));

grant execute on function public.can_manage_cafe_orders() to authenticated;
grant execute on function public.can_manage_cafe_inventory() to authenticated;
notify pgrst, 'reload schema';
