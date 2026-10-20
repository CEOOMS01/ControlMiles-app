// Olympus Mont Systems LLC - ControlMiles
// supabase/functions/_shared/school_pricing.ts
//
// Driving school pricing (user decision 2026-10-20; driving schools only --
// other services keep the fleet prices until their own pricing is set):
//   per vehicle / month: Starter $14.99, Growth $24.99, Enterprise $34.99
//   branches: Starter 1 included + up to 1 extra at $24.99 / month,
//             Growth 2 included + up to 2 extra at $19.99 / month each,
//             Enterprise unlimited.
// The same numbers live in fn_org_branch_allowance_internal (database limit)
// and src/lib/school-pricing.ts (web).
//
// Stripe Prices (recurring monthly, per unit), set as function secrets:
//   STRIPE_PRICE_ID_SCHOOL_STARTER / _GROWTH / _ENTERPRISE  (per vehicle)
//   STRIPE_PRICE_ID_SCHOOL_BRANCH_STARTER / _GROWTH         (per extra branch)

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

export function isSchoolBranchPrice(priceId: string | undefined | null): boolean {
  return !!priceId && Object.values(SCHOOL_BRANCH_PRICE_IDS).includes(priceId);
}
