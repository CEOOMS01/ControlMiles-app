-- The new web is live (2026-10-21): the old portal booking call with an
-- instructor is no longer used.
drop function if exists public.ds_portal_book(text, uuid, date, time without time zone);
