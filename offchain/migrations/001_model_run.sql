-- 001_model_run.sql -- the keyed model-output store.
--
-- raw is the ARTIFACT and the ORACLE: byte-exact, digested, compared. It is never derived from
-- doc and doc is never compared to doc. MEASURED three times independently: jsonb does not
-- preserve whitespace, key order or duplicate keys and re-renders numbers through numeric, so a
-- byte-identity claim read off doc tests Postgres's normalizer rather than the solver.
--
-- doc is a DERIVED PROJECTION for querying only. It is written in the SAME statement, from the
-- SAME bytea parameter as raw (see Store/Postgres.hs), so it cannot describe different bytes.
-- There is no second source it could have come from and no Haskell code constructs it.
--
-- key_scheme is inside the unique constraint (KEY-07) so a future key-formula change ORPHANS
-- rows -- they stop being found -- rather than colliding with and corrupting them.
--
-- The create below is UNCONDITIONAL: it carries no existence guard, deliberately. With the
-- advisory lock in Store/Postgres.hs that guard is unnecessary, and leaving it off is what makes
-- the concurrency lock OBSERVABLE -- without the lock the losing migrator crashes with
-- relation "model_run" already exists, which is both the failure the lock exists to prevent and
-- the evidence that it works. The guard's SQL spelling is described here rather than written out:
-- this file is scanned from this commit onward and an acceptance grep counts occurrences of it.
create table model_run (
  model       text        not null,
  key_scheme  smallint    not null,
  key         bytea       not null,
  raw         bytea       not null,
  doc         jsonb       not null,
  gams_ver    text        not null,
  conopt_ver  text        not null,
  pinned      boolean     not null default false,
  created_at  timestamptz not null default now(),
  constraint model_run_identity unique (model, key_scheme, key)
);

-- The path-ops GIN opclass, not the default one: smaller, faster for the containment operator,
-- and it sidesteps the postgresql-simple ? / ?? placeholder wart entirely, since neither the
-- containment operator nor the text-extraction operator contains a question mark. The opclass
-- name appears exactly once in this file, on the next line, for the same acceptance-grep reason
-- recorded above.
create index model_run_doc_gin on model_run using gin (doc jsonb_path_ops);
