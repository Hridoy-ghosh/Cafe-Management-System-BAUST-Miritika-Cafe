-- Restore profiles for Auth accounts created before the cafe profile trigger
-- was installed. Existing profile decisions are never overwritten.

with missing_profiles as (
  select
    u.id,
    coalesce(nullif(u.raw_user_meta_data ->> 'full_name', ''), 'Cafe Customer')
      as full_name,
    u.email,
    nullif(u.raw_user_meta_data ->> 'phone_number', '') as phone_number,
    case
      when lower(coalesce(u.raw_app_meta_data ->> 'cafe_role', '')) = 'cafe_admin'
        and lower(u.email) = 'cafeadmin@gmail.com'
        then 'cafe_admin'
      when lower(coalesce(u.raw_user_meta_data ->> 'requested_role', 'customer'))
        in (
          'manager', 'cashier', 'chef', 'waiter', 'supplier',
          'university_authority'
        )
        then lower(u.raw_user_meta_data ->> 'requested_role')
      else 'customer'
    end as role
  from auth.users u
  where u.email is not null
    and not exists (
      select 1
      from public.user_profiles p
      where p.id = u.id
    )
    and (
      (
        lower(coalesce(u.raw_app_meta_data ->> 'cafe_role', '')) = 'cafe_admin'
        and lower(u.email) = 'cafeadmin@gmail.com'
      )
      or (
        lower(coalesce(u.raw_app_meta_data ->> 'cafe_role', '')) <> 'cafe_admin'
        and lower(u.email) <> 'cafeadmin@gmail.com'
      )
    )
)
insert into public.user_profiles (
  id,
  full_name,
  email,
  phone_number,
  role,
  department,
  status
)
select
  id,
  full_name,
  email,
  phone_number,
  role,
  case role
    when 'cafe_admin' then 'Cafe'
    when 'manager' then 'Management'
    when 'cashier' then 'Sales & Billing'
    when 'chef' then 'Kitchen'
    when 'waiter' then 'Service'
    when 'supplier' then 'Suppliers'
    when 'university_authority' then 'University Authority'
    else 'Customer'
  end,
  case
    when role in (
      'manager', 'cashier', 'chef', 'waiter', 'supplier',
      'university_authority'
    ) then 'pending'
    else 'approved'
  end
from missing_profiles
on conflict (id) do nothing;
