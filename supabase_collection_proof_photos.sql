-- Collection proof-photo storage and metadata.
-- Run this in Supabase Dashboard -> SQL Editor after the base setup scripts.

alter table waste_records
  add column if not exists "photoAdded" boolean not null default false;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'collection-proof-photos',
  'collection-proof-photos',
  false,
  2097152,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table if not exists collection_proof_photos (
  id bigserial primary key,
  record_id integer not null references waste_records(id) on delete cascade,
  vendor_id integer not null references vendors(id) on delete cascade,
  driver_id integer references drivers(id) on delete set null,
  storage_bucket text not null default 'collection-proof-photos',
  storage_path text not null unique,
  image_url text,
  mime_type text not null,
  file_size integer not null,
  width integer,
  height integer,
  uploaded_at timestamptz not null default now(),
  captured_at timestamptz,
  review_status text not null default 'available'
    check (review_status in ('available', 'flagged', 'deleted', 'expired')),
  admin_viewed_at timestamptz,
  admin_viewed_by uuid references profiles(id) on delete set null
);

create index if not exists idx_collection_proof_photos_record
  on collection_proof_photos(record_id, uploaded_at desc);

alter table collection_proof_photos enable row level security;

drop policy if exists "Authenticated users can insert proof photos"
  on collection_proof_photos;
create policy "Authenticated users can insert proof photos"
  on collection_proof_photos
  for insert
  with check (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can read proof photos"
  on collection_proof_photos;
create policy "Authenticated users can read proof photos"
  on collection_proof_photos
  for select
  using (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can update proof review metadata"
  on collection_proof_photos;
create policy "Authenticated users can update proof review metadata"
  on collection_proof_photos
  for update
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "Authenticated users can upload proof photo files"
  on storage.objects;
create policy "Authenticated users can upload proof photo files"
  on storage.objects
  for insert
  with check (
    bucket_id = 'collection-proof-photos'
    and auth.role() = 'authenticated'
  );

drop policy if exists "Authenticated users can read proof photo files"
  on storage.objects;
create policy "Authenticated users can read proof photo files"
  on storage.objects
  for select
  using (
    bucket_id = 'collection-proof-photos'
    and auth.role() = 'authenticated'
  );
