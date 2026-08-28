-- Olympus Mont Systems LLC - ControlMiles
-- Security hardening pass (2026-08-28): the odometers Storage bucket had
-- correct ownership-scoped RLS on storage.objects (own-folder-only insert/
-- select/update/delete, confirmed via pg_policies) but NO server-side
-- file-type or size enforcement at the bucket level -- any authenticated
-- user could upload an arbitrarily large or non-image file into their own
-- folder, with zero gate. The app only ever uploads .jpg camera captures
-- (odometer_capture_service.dart) -- 10MB is generous headroom over a
-- real phone photo's typical size.

UPDATE storage.buckets
SET file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png']
WHERE id = 'odometers';
