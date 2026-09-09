# ControlMiles error code registry

Explicit user requirement (2026-09-09): no raw database/exception text ever
reaches the UI, on mobile or web. Every user-visible error carries a stable
numeric code from this registry, so a support ticket that says "error 720"
means the same thing regardless of which platform or environment it came
from.

**This file is the single source of truth.** It exists as a duplicate copy
in both repos (`ControlMiles-app/ERROR_CODES.md` and
`controlmiles-web/ERROR_CODES.md`) since they're separate git histories in
different languages and can't literally share one file — **when you add or
change a code, update both copies in the same sitting.**

Not every code needs an entry in both `AppError` classes — some actions only
exist on one platform (e.g. `create_organization` is web-only per the
standing "heavy fleet-admin config lives on web" rule, so `441` only needs
to exist in `errors.ts`, not `app_error.dart`). Add a code to a platform's
class only once something on that platform can actually throw it — this
table stays the complete list either way.

Implementations:
- Mobile: `lib/errors/app_error.dart` (`AppError` class)
- Web: `src/lib/errors.ts` (`AppError` class)

## Ranges

| Range | Meaning | What belongs here |
|---|---|---|
| 1xx–3xx | **LOCAL** | Client-side only — never touched the network. Permissions, form validation, connectivity, local storage. |
| 4xx–6xx | **BACKEND** | A real, named business-rule rejection from Supabase — a Postgres `RAISE EXCEPTION` we recognize, or a known Auth/Postgrest error. |
| 7xx–9xx | **PRODUCTION** | Catch-all for anything else — caught, but not one of the known cases above. Still shows a safe generic message + the code, never the raw exception. `720` is reserved for critical flows (payments, org deletion) so those are easy to find separately from routine `701`s. |

## Codes

| Code | Name | Meaning |
|---|---|---|
| 101 | Camera permission denied | |
| 102 | Location permission denied | |
| 110 | No internet connection | |
| 120 | Invalid form input | Generic client-side validation failure |
| 150 | Local storage failure | |
| 400 | Invalid credentials | Wrong email/password on sign-in |
| 401 | Email already exists | Sign-up with an email already registered |
| 402 | Session expired | JWT/session no longer valid |
| 410 | Vehicle limit reached | Tier's vehicle cap hit (1 for Started/Basic, 5 for Premium) |
| 411 | Free trial expired | 30-day Started trial ran out, no subscription |
| 412 | Org membership revoked | A fleet admin removed this driver's access |
| 420 | Rate limited | Too many attempts on a rate-limited action |
| 430 | Duplicate entry | Unique-constraint violation |
| 440 | Subscriptions not configured | Stripe not yet set up in this environment |
| 441 | Already own a fleet | A second org create attempt without the multi-fleet add-on |
| 450 | Business rule rejection | A hand-written RAISE EXCEPTION from one of our own RPCs that doesn't match a more specific code above -- the message text itself is safe to show (see `looksLikeRawDbError`/`_looksLikeRawDbError`), just not common enough to deserve its own named code |
| 700 | Unexpected (client) | Uncaught client-side exception, unclassified |
| 701 | Unexpected (server) | Uncaught server/Postgrest exception, unclassified |
| 720 | Unexpected (critical flow) | Same as 701, but in a payment/deletion/data-loss-adjacent flow |

## Adding a new code

1. Pick the right range for where the error actually originates.
2. Add it to both `AppError` classes (Dart and TS) with a matching name.
3. Add both messageKey/i18n entries — mobile needs all 11 `lib/i18n/*.dart`
   files, web needs whatever its own i18n setup requires.
4. Update this table in **both** copies of this file.
5. Never invent a code for something you haven't actually seen thrown —
   if nothing matches, let it fall through to 700/701/720. A fabricated
   specific code is worse than an honest generic one.
