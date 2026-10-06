-- Phase 1 / Migration 4 of 10: categories + default-category seeder
--
-- "General expenses", "Car expenses", "Fixed commitments" and "Income"
-- are CATEGORY GROUPS inside ONE table - never separate tables.

create table if not exists public.categories (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  "group"      text not null check ("group" in ('general', 'car', 'fixed', 'income')),
  name_ar      text not null check (length(trim(name_ar)) between 1 and 60),
  name_en      text not null check (length(trim(name_en)) between 1 and 60),
  icon         text not null default 'category',
  color        text not null default '#78909C' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  is_default   boolean not null default false,
  created_at   timestamptz not null default now()
);

create index if not exists idx_categories_household_id
  on public.categories (household_id);

-- Inserts the bilingual default categories for a household.
-- EXECUTE IS REVOKED FROM EVERYONE in migration 10: only definer functions
-- (create_household) may call it, so no client can seed another household.
create or replace function public.seed_default_categories(p_household_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.categories (household_id, "group", name_en, name_ar, icon, color, is_default)
  values
    -- general (13)
    (p_household_id, 'general', 'Food',        'طعام',          'restaurant',          '#EF5350', true),
    (p_household_id, 'general', 'Groceries',   'بقالة',         'shopping_basket',     '#66BB6A', true),
    (p_household_id, 'general', 'Electricity', 'كهرباء',        'bolt',                '#FDD835', true),
    (p_household_id, 'general', 'Water',       'مياه',          'water_drop',          '#42A5F5', true),
    (p_household_id, 'general', 'Gas',         'غاز',           'local_fire_department','#FF7043', true),
    (p_household_id, 'general', 'Internet',    'إنترنت',        'wifi',                '#26C6DA', true),
    (p_household_id, 'general', 'Mobile',      'هاتف',          'phone_iphone',        '#5C6BC0', true),
    (p_household_id, 'general', 'Health',      'صحة',           'health_and_safety',   '#EC407A', true),
    (p_household_id, 'general', 'Education',   'تعليم',         'school',              '#AB47BC', true),
    (p_household_id, 'general', 'Entertainment','ترفيه',        'movie',               '#29B6F6', true),
    (p_household_id, 'general', 'Clothes',     'ملابس',         'checkroom',           '#8D6E63', true),
    (p_household_id, 'general', 'Gifts',       'هدايا',         'gift',                '#FFA726', true),
    (p_household_id, 'general', 'Other',       'أخرى',          'more_horiz',          '#78909C', true),
    -- car (8)
    (p_household_id, 'car', 'Fuel',       'وقود',         'local_gas_station', '#FFA726', true),
    (p_household_id, 'car', 'Maintenance','صيانة',         'build',             '#5C6BC0', true),
    (p_household_id, 'car', 'Oil Change', 'تغيير الزيت',  'oil_barrel',        '#795548', true),
    (p_household_id, 'car', 'Insurance',  'تأمين',        'shield',            '#26A69A', true),
    (p_household_id, 'car', 'License',    'رخصة',          'card_membership',   '#42A5F5', true),
    (p_household_id, 'car', 'Car Wash',   'غسيل السيارة', 'local_car_wash',    '#29B6F6', true),
    (p_household_id, 'car', 'Fines',      'غرامات',       'gavel',             '#EF5350', true),
    (p_household_id, 'car', 'Installment','قسط السيارة',  'payments',          '#7E57C2', true),
    -- fixed (6)
    (p_household_id, 'fixed', 'Rent',           'إيجار',        'home',         '#EF5350', true),
    (p_household_id, 'fixed', 'Installments',   'أقساط',        'credit_card',  '#7E57C2', true),
    (p_household_id, 'fixed', 'Subscriptions',  'اشتراكات',     'subscriptions','#26C6DA', true),
    (p_household_id, 'fixed', 'School Fees',    'رسوم مدرسية',  'school',       '#AB47BC', true),
    (p_household_id, 'fixed', 'Savings Circle', 'جمعية',        'savings',      '#66BB6A', true),
    (p_household_id, 'fixed', 'Utilities',      'فواتير الخدمات','receipt_long', '#FDD835', true),
    -- income (4)
    (p_household_id, 'income', 'Salary',      'راتب',          'payments',   '#66BB6A', true),
    (p_household_id, 'income', 'Extra Income','دخل إضافي',     'add_circle', '#42A5F5', true),
    (p_household_id, 'income', 'Rent Income', 'دخل إيجار',     'home',       '#26A69A', true),
    (p_household_id, 'income', 'Other',       'أخرى',          'more_horiz', '#78909C', true);
$$;
