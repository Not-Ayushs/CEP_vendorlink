-- ════════════════════════════════════════════════════════════════════════
-- SWM (Solid Waste Management) — Supabase Database Setup
-- Run this in: Supabase Dashboard → SQL Editor → New query → RUN ALL
-- ════════════════════════════════════════════════════════════════════════

-- ─── STEP 1: Profiles (role store for every user) ───────────────────────
create table if not exists profiles (
  id   uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  role text not null check (role in ('vendor', 'driver', 'admin'))
);
alter table profiles enable row level security;

create policy "Users can read own profile" on profiles
  for select using (auth.uid() = id);

create policy "Users can insert own profile" on profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile" on profiles
  for update using (auth.uid() = id);

-- Allow admin reads from service-role (needed for RoleRouter lookup)
create policy "Service role can read all profiles" on profiles
  for select using (true);  -- simplify for prototype


-- ─── STEP 2: Vendors ────────────────────────────────────────────────────
create table if not exists vendors (
  id        serial primary key,
  user_id   uuid references auth.users(id) on delete cascade unique,
  name      text not null,
  "shopName" text not null default '',
  phone     text not null default '',
  address   text not null default ''
);
alter table vendors enable row level security;

create policy "Authenticated users can read vendors" on vendors
  for select using (auth.role() = 'authenticated');

create policy "Vendors can insert their own row" on vendors
  for insert with check (auth.uid() = user_id);

create policy "Vendors can update their own row" on vendors
  for update using (auth.uid() = user_id);


-- ─── STEP 3: Drivers ────────────────────────────────────────────────────
create table if not exists drivers (
  id      serial primary key,
  user_id uuid references auth.users(id) on delete cascade unique,
  name    text not null,
  phone   text not null default ''
);
alter table drivers enable row level security;

create policy "Authenticated users can read drivers" on drivers
  for select using (auth.role() = 'authenticated');

create policy "Drivers can insert their own row" on drivers
  for insert with check (auth.uid() = user_id);

create policy "Drivers can update their own row" on drivers
  for update using (auth.uid() = user_id);


-- ─── STEP 4: Waste Records ───────────────────────────────────────────────
create table if not exists waste_records (
  id             serial primary key,
  "vendorId"     integer references vendors(id) on delete cascade not null,
  "driverId"     integer references drivers(id) on delete set null,
  "declaredWaste" float not null default 0,
  "verifiedWaste" float not null default 0,
  status         text not null default 'Pending' check (status in ('Pending', 'Collected')),
  timestamp      text not null default '',
  "qrScanned"    boolean not null default false,
  "photoAdded"   boolean not null default false,
  "wasteType"    text not null default 'Mixed'
);
alter table waste_records enable row level security;

create policy "All authenticated can read waste_records" on waste_records
  for select using (auth.role() = 'authenticated');

create policy "All authenticated can insert waste_records" on waste_records
  for insert with check (auth.role() = 'authenticated');

create policy "All authenticated can update waste_records" on waste_records
  for update using (auth.role() = 'authenticated');


-- ════════════════════════════════════════════════════════════════════════
-- DEMO USERS SETUP
-- ════════════════════════════════════════════════════════════════════════
-- Run steps A-D AFTER running the above tables.
--
-- ⚠️  IMPORTANT: Before creating demo users, go to:
--     Supabase Dashboard → Authentication → Providers → Email
--     ✅ Disable "Confirm email" (so demo users can log in without confirming)
--     You can re-enable it later if needed.
--
-- STEP A: Create these 3 users in:
--     Supabase Dashboard → Authentication → Users → Add user
--
--     Email: vendor@test.com   Password: demo1234   (do NOT send email)
--     Email: driver@test.com   Password: demo1234
--     Email: admin@test.com    Password: demo1234
--
-- STEP B: After creating them, copy their UUIDs from the Auth → Users list.
--     Replace <VENDOR_UUID>, <DRIVER_UUID>, <ADMIN_UUID> below and run:

-- insert into profiles (id, name, role) values
--   ('<VENDOR_UUID>', 'Demo Vendor', 'vendor'),
--   ('<DRIVER_UUID>', 'Demo Driver', 'driver'),
--   ('<ADMIN_UUID>',  'Demo Admin',  'admin');

-- STEP C: Insert vendor/driver rows (replace UUIDs as above):

-- insert into vendors (user_id, name, "shopName", phone, address) values
--   ('<VENDOR_UUID>', 'Demo Vendor', 'Demo Shop', '+91 9000000001', 'Demo Area, North Zone');

-- insert into drivers (user_id, name, phone) values
--   ('<DRIVER_UUID>', 'Demo Driver', '+91 9000000002');

-- STEP D: (Optional) add some initial waste_records for demo to look populated.
-- Use the vendor/driver IDs from the serial columns (usually 1 and 1 if first rows).

-- insert into waste_records
--   ("vendorId", "driverId", "declaredWaste", "verifiedWaste", status, timestamp, "qrScanned", "photoAdded", "wasteType")
-- values
--   (1, null, 12.0, 0.0,  'Pending',   '',         false, false, 'Organic'),
--   (1, 1,    20.0, 18.0, 'Collected', '10:30 AM', true,  true,  'Plastic'),
--   (1, 1,    15.0, 8.0,  'Collected', '09:15 AM', true,  false, 'Mixed');
-- ════════════════════════════════════════════════════════════════════════
