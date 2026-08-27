-- Olympus Mont Systems LLC - ControlMiles
-- Connects trip records to CGC Core's governance/PoD sealing pipeline
-- (see [[project_cgc_core]]): closing the flagged gap where the antifraud
-- engine and hash-chain audit log run entirely client-side, with nothing
-- server-side proving a trip record wasn't fabricated. When a trip's
-- antifraud verdict is sealed via CGC Core's /governance/decision, the
-- returned decision_id (and when it happened) are stored here -- the
-- durable link between a ControlMiles trip and its independent,
-- cryptographically-sealed proof.
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS cgc_decision_id text,
  ADD COLUMN IF NOT EXISTS cgc_sealed_at timestamptz;
