-- Issue #41. A dynamic-fee pool stores lpFee = 0 in slot0 (the hook supplies the fee per swap),
-- so the fee the loop hands the splitter may come from one of TWO reads at the pinned block:
-- slot0's lpFee when it is nonzero, or DynamicFeeHook.getAverageVolatility(tick, timestamp) fed
-- into DynamicFeeMod.getCurrentFee when it is zero. The origin is part of what a key MEANS --
-- key_scheme 2 -- and a ledger row that could not say which would be a run nothing can reconcile
-- against the chain that supplied it.
--
-- The CHECK names the two Chain.Read.fee_source_token values verbatim. text not null does NOT
-- forbid the empty string (migration 003's lesson, restated here), which is why the token set is
-- closed rather than merely non-empty.
alter table loop_event
  add column fee_source text not null default 'slot0.lpFee';

alter table loop_event
  add constraint loop_event_fee_source_known
    check (fee_source in ('slot0.lpFee',
                          'DynamicFeeHook.getAverageVolatility+DynamicFeeMod.getCurrentFee'));

-- The default exists only so rows written before this migration decode; every writer after it
-- sets the column explicitly (Loop.Ledger.insert_event_sql names it).
