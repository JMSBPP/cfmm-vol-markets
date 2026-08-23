-- 004_loop_ledger.sql -- the chronology the content key cannot reconstruct, and the watermark
-- that is advanced in the same transaction as the rows it covers.
--
-- WHAT THIS ANSWERS. LOOP-02 is stated in two directions and neither implies the other. The same
-- event REPLAYED must produce one row and no second solve; two DISTINCT events carrying an
-- identical shock must produce one stored run and TWO rows. The content key already answers the
-- second half of the first direction -- an identical shock elides the solve, STORE-01 -- but it
-- answers it by being a function of the SHOCK, and a shock has no idea which log it arrived on.
-- Two events with identical values are one key and must still be two rows, because the run log is
-- a chronology and a chronology that de-duplicates is a set. Hence loop_event, keyed on the
-- POSITION in the chain rather than on the content: the pair (tx_hash, log_index), constrained
-- below as loop_event_identity.
--
-- WHAT THIS DELIBERATELY DOES NOT DO. STORE-07's append-only enforcement -- the trigger hardening
-- that would make an update or a delete on this table impossible rather than merely unwritten --
-- REMAINS DEFERRED, with STORE-02..05, under the 08-17 scope cut. This table is a partial STORE-07
-- BY CONSTRUCTION: nothing in this repository updates or deletes a loop_event row, and there is no
-- database-level guard that says so. REQUIREMENTS.md's traceability entry records it that way, and
-- this header exists so the gap is a recorded decision rather than something a later reader infers
-- from the absence of a trigger.
--
-- WHY key IS NULLABLE AND WHY EXACTLY ONE OUTCOME MAY USE THAT. An inadmissible shock is refused
-- by render_argv's ninth refusal before an argument vector exists, so content_key never computes
-- and there IS no key to record -- writing a placeholder would be inventing an identity for a run
-- that never happened. Every OTHER outcome has one: elided and stored both looked a key up, and
-- not_persisted computed a key and then failed to answer it. An unkeyed stored row would be a
-- run nothing can ever find again, which is why the nullability is constrained by outcome instead
-- of left open.
--
-- WHY THE VERSION COLUMNS REPEAT 003's RULE. 003_version_columns_nonempty.sql's header records the
-- hazard in full: NOT NULL does not forbid the empty string, KEY-01 folds both version strings
-- into the content key, and a row whose toolchain columns are empty is a row a post-mortem cannot
-- sort -- there is no second witness to recover the toolchain from. That reasoning is about the
-- COLUMNS, not about model_run, so it is restated here on this table rather than assumed to travel
-- with the name. It matters more here than there: 28-CONTEXT's drift ruling is that the loop
-- ADOPTS a new toolchain identity and continues, so these two columns are the only record of which
-- toolchain keyed which event, and an empty one destroys exactly the evidence the ruling relies on.
--
-- The constraints are NAMED, in the style of model_run_identity, for the reason 003 states: a
-- system-generated identifier still produces the right SQLSTATE, and a SQLSTATE alone says only
-- that some check refused. The create is unconditional, as 001's is, and for the same reason.
create table loop_event (
  tx_hash      text        not null,
  log_index    bigint      not null,
  block        bigint      not null,
  model        text        not null,
  key_scheme   smallint    not null,
  key          bytea,
  outcome      text        not null,
  reason       text        not null default '',
  gams_ver     text        not null,
  conopt_ver   text        not null,
  observed_at  timestamptz not null default now(),
  constraint loop_event_identity unique (tx_hash, log_index),
  constraint loop_event_outcome_known
    check (outcome in ('elided', 'stored', 'not_persisted', 'inadmissible')),
  constraint loop_event_keyed_unless_inadmissible
    check (outcome = 'inadmissible' or key is not null),
  constraint loop_event_versions_nonempty
    check (length(gams_ver) > 0 and length(conopt_ver) > 0)
);

-- THE WATERMARK IS ONE ROW, AND THE SCHEMA IS WHAT MAKES IT ONE. LOOP-05's "watermark unadvanced,
-- no half-written row" is delivered by advancing this table inside the same transaction as that
-- block's loop_event inserts. A watermark held as "the maximum block in loop_event" would look
-- equivalent and is not: it cannot advance through a block that carried no event, so a restart
-- would re-scan every quiet stretch since the last shock, and a quiet stretch is the normal case.
--
-- only_row is the primary key AND is checked true, which are two different guards and both are
-- load-bearing. The primary key makes a second row with only_row = true a conflict -- which is
-- what the upsert's on-conflict target names. The check is what forbids the second row from being
-- only_row = false, which the primary key alone would happily admit and which would give the table
-- two rows, one of them a watermark nothing reads and nothing advances.
create table loop_watermark (
  only_row    boolean     not null default true,
  block       bigint      not null,
  updated_at  timestamptz not null default now(),
  constraint loop_watermark_single_row primary key (only_row),
  constraint loop_watermark_is_the_only_row check (only_row)
);
