-- Persistent cafe menu, customer orders, billing, and sales records.

create table if not exists public.cafe_menu_items (
  id text primary key,
  name text not null,
  category text not null,
  price numeric(12, 2) not null check (price >= 0),
  image text not null default '🍽️',
  available boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.cafe_menu_items (id, name, category, price, image)
values
  ('1', 'Milk Tea', 'Beverages', 10, '🫖'),
  ('2', 'Coffee', 'Beverages', 20, '☕'),
  ('10', 'Cold Drink', 'Beverages', 25, '🥤'),
  ('11', 'Fresh Juice', 'Beverages', 30, '🧃'),
  ('28', 'Cold Coffee', 'Beverages', 35, '🥤'),
  ('4', 'Biscuits', 'Snacks', 10, '🍪'),
  ('5', 'Samosa', 'Snacks', 10, '🥟'),
  ('7', 'Vegetable Roll', 'Snacks', 20, '🥖'),
  ('24', 'Chicken Roll', 'Snacks', 50, '🌯'),
  ('25', 'French Fries', 'Snacks', 40, '🍟'),
  ('27', 'Momos', 'Snacks', 60, '🥟'),
  ('6', 'Puri', 'Breakfast', 15, '🥟'),
  ('12', 'Bread Toast', 'Breakfast', 20, '🍞'),
  ('13', 'Boiled Egg', 'Breakfast', 15, '🥚'),
  ('14', 'Omelette', 'Breakfast', 20, '🍳'),
  ('8', 'Burger', 'Fast Food', 55, '🍔'),
  ('9', 'Pizza Slice', 'Fast Food', 60, '🍕'),
  ('26', 'Shawarma', 'Fast Food', 70, '🥙'),
  ('3', 'Cake Slice', 'Desserts', 30, '🍰'),
  ('37', 'Ice Cream', 'Desserts', 40, '🍦'),
  ('30', 'Vegetable Salad', 'Healthy', 45, '🥗'),
  ('15', 'Special Biryani', 'Special', 120, '🍛'),
  ('16', 'Chicken Kabab', 'Special', 90, '🍗'),
  ('17', 'Mutton Rezala', 'Special', 150, '🍲'),
  ('19', 'Chowmein Combo', 'Special', 80, '🍜'),
  ('20', 'BBQ Chicken', 'Special', 130, '🍗'),
  ('23', 'Special Thali', 'Special', 200, '🍛')
on conflict (id) do nothing;

create table if not exists public.cafe_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.user_profiles (id),
  user_name text not null,
  user_department text not null default 'Customer',
  user_phone text,
  items jsonb not null check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) > 0),
  total_amount numeric(12, 2) not null check (total_amount > 0),
  order_type text not null check (order_type in ('dine-in', 'takeaway')),
  payment_method text not null check (payment_method in ('cash', 'bkash', 'nagad')),
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid', 'paid', 'refunded')),
  payment_number text,
  payment_reference text,
  status text not null default 'pending'
    check (status in ('pending', 'preparing', 'ready', 'delivered', 'cancelled')),
  token text not null unique,
  table_number text,
  floor text,
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  check ((order_type = 'dine-in' and table_number is not null and floor is not null)
    or order_type = 'takeaway')
);

create index if not exists cafe_orders_customer_date_idx
  on public.cafe_orders (user_id, created_at desc);
create index if not exists cafe_orders_status_date_idx
  on public.cafe_orders (status, created_at desc);

alter table public.cafe_menu_items enable row level security;
alter table public.cafe_orders enable row level security;

drop policy if exists "Authenticated users view available cafe menu" on public.cafe_menu_items;
create policy "Authenticated users view available cafe menu"
  on public.cafe_menu_items for select to authenticated
  using (available or (select public.is_cafe_admin()));

drop policy if exists "Cafe admins manage menu" on public.cafe_menu_items;
create policy "Cafe admins manage menu"
  on public.cafe_menu_items for all to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Customers and cafe admins view orders" on public.cafe_orders;
create policy "Customers and cafe admins view orders"
  on public.cafe_orders for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_cafe_admin()));

drop policy if exists "Cafe admins update orders" on public.cafe_orders;
create policy "Cafe admins update orders"
  on public.cafe_orders for update to authenticated
  using ((select public.is_cafe_admin()))
  with check ((select public.is_cafe_admin()));

drop policy if exists "Cafe admins delete orders" on public.cafe_orders;
create policy "Cafe admins delete orders"
  on public.cafe_orders for delete to authenticated
  using ((select public.is_cafe_admin()));

grant select on public.cafe_menu_items, public.cafe_orders to authenticated;
grant insert, update, delete on public.cafe_menu_items to authenticated;
grant update (status, payment_status, delivered_at) on public.cafe_orders to authenticated;
grant delete on public.cafe_orders to authenticated;

create or replace function public.place_cafe_order(
  p_items jsonb,
  p_order_type text,
  p_payment_method text,
  p_token text,
  p_table_number text default null,
  p_floor text default null,
  p_payment_reference text default null,
  p_payment_number text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user public.user_profiles%rowtype;
  v_item jsonb;
  v_menu_item public.cafe_menu_items%rowtype;
  v_quantity integer;
  v_total numeric(12, 2) := 0;
  v_items jsonb := '[]'::jsonb;
  v_order_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in before placing an order';
  end if;
  if p_order_type not in ('dine-in', 'takeaway')
    or p_payment_method not in ('cash', 'bkash', 'nagad') then
    raise exception 'Invalid order or payment method';
  end if;
  if nullif(trim(p_token), '') is null then
    raise exception 'Order token is required';
  end if;
  if p_order_type = 'dine-in'
    and (nullif(trim(p_table_number), '') is null or nullif(trim(p_floor), '') is null) then
    raise exception 'Choose a table and seating area for dine-in';
  end if;
  if p_payment_method in ('bkash', 'nagad')
    and (p_payment_number is null or p_payment_number !~ '^01[0-9]{9}$') then
    raise exception 'Enter a valid 11-digit mobile wallet number';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Add at least one item to your order';
  end if;

  select * into v_user
  from public.user_profiles
  where id = (select auth.uid()) and role = 'customer';
  if not found then
    raise exception 'Only customer accounts can place cafe orders';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_quantity := (v_item ->> 'quantity')::integer;
    if v_quantity < 1 or v_quantity > 99 then
      raise exception 'Order quantities must be between 1 and 99';
    end if;

    select * into v_menu_item
    from public.cafe_menu_items
    where id = v_item ->> 'id' and available;
    if not found then
      raise exception 'One or more menu items are unavailable';
    end if;

    v_total := v_total + v_menu_item.price * v_quantity;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'id', v_menu_item.id,
      'name', v_menu_item.name,
      'price', v_menu_item.price,
      'quantity', v_quantity,
      'subtotal', v_menu_item.price * v_quantity
    ));
  end loop;

  if p_order_type = 'dine-in' and exists (
    select 1 from public.cafe_orders
    where order_type = 'dine-in'
      and floor = p_floor
      and table_number = p_table_number
      and status in ('pending', 'preparing', 'ready')
  ) then
    raise exception 'This table already has an active order';
  end if;

  insert into public.cafe_orders (
    user_id, user_name, user_department, user_phone, items, total_amount,
    order_type, payment_method, payment_number, payment_reference, token,
    table_number, floor
  )
  values (
    v_user.id, v_user.full_name, v_user.department, v_user.phone_number,
    v_items, v_total, p_order_type, p_payment_method,
    case when p_payment_method in ('bkash', 'nagad')
      then nullif(trim(p_payment_number), '') end,
    nullif(trim(p_payment_reference), ''), p_token,
    case when p_order_type = 'dine-in' then p_table_number end,
    case when p_order_type = 'dine-in' then p_floor end
  )
  returning id into v_order_id;

  return v_order_id;
end;
$$;

grant execute on function public.place_cafe_order(jsonb, text, text, text, text, text, text, text)
  to authenticated;

notify pgrst, 'reload schema';
