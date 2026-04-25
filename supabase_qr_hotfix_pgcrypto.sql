-- Fix for: function gen_random_bytes(integer) does not exist
-- Run this in Supabase SQL Editor if QR creation fails on declare waste.

create extension if not exists pgcrypto with schema extensions;

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

grant execute on function create_qr_token(integer, integer) to authenticated;
