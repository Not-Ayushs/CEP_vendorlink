-- Server-based QR verification for the SWM app.
-- Run in Supabase Dashboard -> SQL Editor after supabase_setup.sql.

create extension if not exists pgcrypto with schema extensions;

alter table waste_records
  add column if not exists notes text,
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists qr_verified boolean not null default false,
  add column if not exists driver_lat double precision,
  add column if not exists driver_lng double precision,
  add column if not exists scan_time timestamptz,
  add column if not exists invalid_scan_count integer not null default 0,
  add column if not exists last_qr_error text;

create table if not exists qr_tokens (
  id bigserial primary key,
  token text not null unique,
  vendor_id integer not null references vendors(id) on delete cascade,
  record_id integer not null references waste_records(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '6 hours',
  is_used boolean not null default false,
  used_at timestamptz
);

create index if not exists idx_qr_tokens_record_unused
  on qr_tokens(record_id, is_used, created_at desc);

create table if not exists qr_scan_attempts (
  id bigserial primary key,
  token text,
  vendor_id integer,
  record_id integer,
  driver_id integer references drivers(id) on delete set null,
  driver_lat double precision,
  driver_lng double precision,
  scanned_at timestamptz not null default now(),
  success boolean not null default false,
  error text
);

alter table qr_tokens enable row level security;
alter table qr_scan_attempts enable row level security;

drop policy if exists "Authenticated users can read qr_tokens" on qr_tokens;
create policy "Authenticated users can read qr_tokens" on qr_tokens
  for select using (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can insert qr_scan_attempts" on qr_scan_attempts;
create policy "Authenticated users can insert qr_scan_attempts" on qr_scan_attempts
  for insert with check (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can read qr_scan_attempts" on qr_scan_attempts;
create policy "Authenticated users can read qr_scan_attempts" on qr_scan_attempts
  for select using (auth.role() = 'authenticated');

create or replace function create_qr_token(
  p_vendor_id integer,
  p_record_id integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_record waste_records%rowtype;
begin
  select *
    into v_record
    from waste_records
   where id = p_record_id
     and "vendorId" = p_vendor_id
     and status = 'Pending';

  if not found then
    raise exception 'Pending waste record not found for vendor.';
  end if;

  select token
    into v_token
    from qr_tokens
   where vendor_id = p_vendor_id
     and record_id = p_record_id
     and is_used = false
     and expires_at > now()
   order by created_at desc
   limit 1;

  if v_token is null then
    v_token := encode(extensions.gen_random_bytes(32), 'hex');

    insert into qr_tokens (token, vendor_id, record_id)
    values (v_token, p_vendor_id, p_record_id);
  end if;

  return jsonb_build_object(
    'vendor_id', p_vendor_id,
    'record_id', p_record_id,
    'timestamp', now(),
    'token', v_token
  );
end;
$$;

create or replace function verify_qr_pickup(
  p_token text,
  p_vendor_id integer,
  p_record_id integer,
  p_driver_id integer,
  p_driver_lat double precision,
  p_driver_lng double precision,
  p_scanned_at timestamptz default now()
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token qr_tokens%rowtype;
  v_record waste_records%rowtype;
  v_distance_m double precision;
  v_error text;
  v_threshold_m double precision := 250;
begin
  select * into v_record
    from waste_records
   where id = p_record_id
   for update;

  select * into v_token
    from qr_tokens
   where token = p_token
   for update;

  if not found then
    v_error := 'Invalid QR token.';
  elsif v_token.is_used then
    v_error := 'QR token already used.';
  elsif v_token.expires_at <= now() then
    v_error := 'QR token expired.';
  elsif v_token.vendor_id <> p_vendor_id or v_token.record_id <> p_record_id then
    v_error := 'QR token does not match this pickup.';
  elsif v_record.id is null then
    v_error := 'Waste record not found.';
  elsif v_record."vendorId" <> p_vendor_id then
    v_error := 'Vendor mismatch.';
  elsif v_record.status <> 'Pending' then
    v_error := 'Pickup is not pending.';
  end if;

  if v_error is null and v_record.lat is not null and v_record.lng is not null then
    v_distance_m :=
      6371000 * 2 * asin(sqrt(
        power(sin(radians((p_driver_lat - v_record.lat) / 2)), 2) +
        cos(radians(v_record.lat)) * cos(radians(p_driver_lat)) *
        power(sin(radians((p_driver_lng - v_record.lng) / 2)), 2)
      ));

    if v_distance_m > v_threshold_m then
      v_error := 'Driver is too far from vendor location.';
    end if;
  end if;

  if v_error is not null then
    insert into qr_scan_attempts (
      token, vendor_id, record_id, driver_id, driver_lat, driver_lng,
      scanned_at, success, error
    )
    values (
      p_token, p_vendor_id, p_record_id, p_driver_id, p_driver_lat,
      p_driver_lng, coalesce(p_scanned_at, now()), false, v_error
    );

    update waste_records
       set invalid_scan_count = invalid_scan_count + 1,
           last_qr_error = v_error
     where id = p_record_id;

    return jsonb_build_object('success', false, 'error', v_error);
  end if;

  update qr_tokens
     set is_used = true,
         used_at = coalesce(p_scanned_at, now())
   where id = v_token.id;

  update waste_records
     set qr_verified = true,
         "qrScanned" = true,
         "driverId" = p_driver_id,
         driver_lat = p_driver_lat,
         driver_lng = p_driver_lng,
         scan_time = coalesce(p_scanned_at, now()),
         last_qr_error = null
   where id = p_record_id;

  insert into qr_scan_attempts (
    token, vendor_id, record_id, driver_id, driver_lat, driver_lng,
    scanned_at, success, error
  )
  values (
    p_token, p_vendor_id, p_record_id, p_driver_id, p_driver_lat,
    p_driver_lng, coalesce(p_scanned_at, now()), true, null
  );

  return jsonb_build_object(
    'success', true,
    'message', 'Verification Successful',
    'record_id', p_record_id,
    'scan_time', coalesce(p_scanned_at, now()),
    'distance_m', v_distance_m
  );
end;
$$;

grant execute on function create_qr_token(integer, integer) to authenticated;
grant execute on function verify_qr_pickup(
  text, integer, integer, integer, double precision, double precision, timestamptz
) to authenticated;
