// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/_shared/school_pricing.ts
//
// Driving school pricing (user decisions 2026-10-20; driving schools only --
// other services keep the fleet prices until their own pricing is set):
//   monthly base with 3 cars and the software, then per extra car:
//     Starter    $59  + $12.99 per car, up to 10 cars
//     Growth     $125 + $19.99 per car (cars 4-15), $16.99 from the 16th
//     Enterprise $175 + $27.99 per car (cars 4-15), $23.99 from the 16th
//   branches: Starter 1 included + up to 1 extra at $24.99 / month,
//             Growth 2 included + up to 2 extra at $19.99 / month each,
//             Enterprise unlimited.
// The same numbers live in fn_org_branch_allowance_internal (database limit)
// and src/lib/school-pricing.ts (web).
//
// Stripe Prices (recurring monthly), set as function secrets:
//   STRIPE_PRICE_ID_SCHOOL_STARTER / _GROWTH / _ENTERPRISE: graduated tiered
//     prices on the vehicle count -- tier 1 up to 3 with the base as its flat
//     amount and 0 per unit, tier 2 up to 15 at the extra-car price, tier 3
//     (inf) at the 16th-car price. The quantity stays the vehicle count, so
//     checkout and the renewal sync in stripe-webhook need no math.
//   STRIPE_PRICE_ID_SCHOOL_BRANCH_STARTER / _GROWTH: per unit, per extra branch.
//   STRIPE_PRICE_ID_SCHOOL_DOMAIN: $29 / month, the enrollment page on the
//     school's own address (Enterprise, user decision 2026-10-20), billed
//     while the address is live.

export type FleetTier = 'starter' | 'growth' | 'enterprise';

export const SCHOOL_PRICE_IDS: Record<FleetTier, string> = {
  starter: Deno.env.get('STRIPE_PRICE_ID_SCHOOL_STARTER') ?? '',
  growth: Deno.env.get('STRIPE_PRICE_ID_SCHOOL_GROWTH') ?? '',
  enterprise: Deno.env.get('STRIPE_PRICE_ID_SCHOOL_ENTERPRISE') ?? '',
};

export const SCHOOL_BRANCH_PRICE_IDS: Record<'starter' | 'growth', string> = {
  starter: Deno.env.get('STRIPE_PRICE_ID_SCHOOL_BRANCH_STARTER') ?? '',
  growth: Deno.env.get('STRIPE_PRICE_ID_SCHOOL_BRANCH_GROWTH') ?? '',
};

const BRANCHES: Record<FleetTier, { included: number; max: number } | null> = {
  starter: { included: 1, max: 2 },
  growth: { included: 2, max: 4 },
  enterprise: null,
};

/** Extra branches to bill on a plan, and whether the school has more than it allows. */
export function schoolBranchExtras(tier: FleetTier, activeBranches: number): { extras: number; overMax: boolean; max: number | null } {
  const rule = BRANCHES[tier];
  if (!rule) return { extras: 0, overMax: false, max: null };
  return {
    extras: Math.min(Math.max(activeBranches - rule.included, 0), rule.max - rule.included),
    overMax: activeBranches > rule.max,
    max: rule.max,
  };
}

/** Most cars a plan allows (Starter 10; fn_vehicles_school_limit enforces it). */
export const SCHOOL_MAX_CARS: Record<FleetTier, number | null> = { starter: 10, growth: null, enterprise: null };

export const SCHOOL_DOMAIN_PRICE_ID = Deno.env.get('STRIPE_PRICE_ID_SCHOOL_DOMAIN') ?? '';

export function isSchoolBranchPrice(priceId: string | undefined | null): boolean {
  return !!priceId && Object.values(SCHOOL_BRANCH_PRICE_IDS).includes(priceId);
}

/** An add-on item (extra branches, own address), never the vehicle item. */
export function isSchoolExtraPrice(priceId: string | undefined | null): boolean {
  return isSchoolBranchPrice(priceId) || (!!priceId && priceId === SCHOOL_DOMAIN_PRICE_ID);
}
