{-# LANGUAGE OverloadedStrings #-}

-- |
-- THE CHRONOLOGY, and the watermark that moves with it.
--
-- == TWO MECHANISMS, AND COLLAPSING THEM DESTROYS THE RUN LOG
--
-- 'ledger_seen' stops re-work on a REPLAYED EVENT. The content key stops re-solving an IDENTICAL
-- SHOCK. They are not two spellings of one idea and LOOP-02 asserts BOTH directions:
--
--   * the same @(tx_hash, log_index)@ seen twice must produce ONE row and NO second solve -- which
--     the content key cannot deliver, because it is a function of the shock and a shock does not
--     know which log it arrived on;
--   * two DISTINCT events carrying identical shock values must produce ONE store entry and TWO
--     rows -- which 'ledger_seen' cannot deliver either, because they are different events and it
--     has never seen the second one.
--
-- A ledger keyed on the content key would satisfy the first direction and quietly fail the second,
-- collapsing two events into one row. That is the chronology the run log exists to provide, and
-- once it is gone there is nothing to recover it from: the store holds ONE row for both events by
-- construction, and it is the right answer for the store.
--
-- == THE BLOCK COMMIT HAS NO ARITY THAT LETS A CALLER FORGET THE WATERMARK
--
-- 'ledger_commit_block' takes the block AND its rows and writes both in ONE transaction. There is
-- deliberately no @insert_row@ and no @advance_watermark@ on this record: LOOP-05's "watermark
-- unadvanced, no half-written row" is then a property of the SIGNATURE rather than a rule about
-- call order that a later caller can get wrong, and there is no ordering bug left to write.
--
-- == WHY THIS IS A RECORD OF FUNCTIONS
--
-- The same reason @Store.Class@ gives for the store: a deliberately-wrong ledger must be ONE LINE
-- of record update, so "the watermark advanced although the rows did not land" is a MEASUREMENT
-- rather than an argument about code. The memory implementation below is a real subject for that,
-- and it is what @cabal test@ drives -- the suite is server-free by construction (DB-03).
--
-- == THE REFERENCE IMPLEMENTATION REFUSES WHAT THE SERVER REFUSES
--
-- Migration @004@ carries three CHECK constraints, and a memory ledger that accepted rows the
-- server rejects would let a law pass in Tier B and fail in Tier C -- which defeats the whole
-- reason @cabal test@ is allowed to run without a database. @Store.Memory@ met this exact
-- question at 23-04 and the ruling was to TIGHTEN THE REFERENCE rather than loosen the real one.
-- So 'ledger_row_refusal' states the DDL's row rule once, in Haskell, and the memory commit
-- applies it to EVERY row BEFORE it mutates anything.
--
-- Validating first is not tidiness. It is what makes the memory ledger's commit indivisible: the
-- state lives in ONE 'IORef' holding both the rows and the watermark, so there is no interleaving
-- at which one has moved and the other has not, and a refusal happens strictly before the single
-- write. Two separate refs could not say that -- one of them would already have been updated.
module Loop.Ledger
  ( -- * The identity a row is keyed by
    EventId (..)
    -- * A row
  , LedgerRow (..)
  , ledger_row_refusal
    -- * The seam
  , Ledger (..)
  , new_memory_ledger
  , new_postgres_ledger
    -- * The outcome vocabulary, from the module that decides it
  , Outcome (..)
  , outcome_token
  , outcomes
  , outcome_from_token
  ) where

import Control.Exception (throwIO)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import qualified Data.ByteString as BS
import qualified Data.Map.Strict as M

import Database.PostgreSQL.Simple
  ( Binary (..)
  , Connection
  , Only (..)
  , Query
  , execute
  , query
  , withTransaction
  )

import Loop.Solve (Outcome (..), outcome_token, outcomes)
import Store.Types (KeyScheme (..))

-- ---------------------------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------------------------

-- | WHERE IN THE CHAIN, not what was in it.
--
-- @Ord@ is derived because this is a map key in the reference implementation. It is derived rather
-- than written for the usual reason: a hand-written comparison over two fields is a place a
-- transposition hides, and the ordering here is never semantic -- nothing reads it as "earlier".
data EventId = EventId
  { ev_tx_hash   :: !String
  , ev_log_index :: !Integer
  } deriving (Eq, Ord, Show)

-- | One decided event, as the row that will be read after the fact.
--
-- @lr_key@ is @Maybe@ because exactly one outcome legitimately has none: an inadmissible shock is
-- refused before an argument vector exists, so no content key was ever computed and a placeholder
-- would be an invented identity for a run that never happened. Every other outcome has a key, and
-- 'ledger_row_refusal' is where that is enforced on this side of the wire.
--
-- The two version fields are the identity that KEYED this event, not the identity the process was
-- started with. 28-CONTEXT rules that the loop adopts a new toolchain identity and continues, so
-- these columns are the only record of which toolchain answered which event -- which is exactly
-- why an empty one is refused rather than stored.
data LedgerRow = LedgerRow
  { lr_event      :: !EventId
  , lr_block      :: !Integer
  , lr_model      :: !String
  , lr_key_scheme :: !KeyScheme
  , lr_key        :: !(Maybe BS.ByteString)
  , lr_outcome    :: !Outcome
  , lr_reason     :: !String
  , lr_gams_ver   :: !String
  , lr_conopt_ver :: !String
  , lr_fee_source :: !String
    -- ^ Issue #41: 'Chain.Read.fee_source_token' of the read that supplied the splitter's fee.
    -- Migration @005@ adds the column with a CHECK over the two tokens, so the ledger cannot
    -- carry a fee whose origin nobody can name.
  } deriving (Eq, Show)

-- | Migration @004@'s two row-level CHECKs, stated ONCE in Haskell.
--
-- @Nothing@ means the server would take this row. @Just why@ means it would refuse it, and the
-- memory ledger raises with that sentence rather than storing a row Tier C could not hold.
ledger_row_refusal :: LedgerRow -> Maybe String
ledger_row_refusal row
  | lr_outcome row /= OutcomeInadmissible && lr_key row == Nothing =
      Just ("the row carries outcome " ++ outcome_token (lr_outcome row)
             ++ " and NO key. loop_event_keyed_unless_inadmissible refuses that: a keyed outcome"
             ++ " with no key is a run nothing can ever find again. Only an inadmissible shock"
             ++ " legitimately has none, because it was refused before a key could be computed.")
  | null (lr_fee_source row) =
      Just ("the row carries an EMPTY fee source. loop_event_fee_source_known refuses that (migration"
             ++ " 005): a key built from a fee nobody can say the origin of cannot be reconciled"
             ++ " against the chain that supplied it.")
  | null (lr_gams_ver row) || null (lr_conopt_ver row) =
      Just ("the row carries an EMPTY toolchain version (gams " ++ show (lr_gams_ver row)
             ++ ", conopt " ++ show (lr_conopt_ver row)
             ++ "). loop_event_versions_nonempty refuses that, restating migration 003's rule on"
             ++ " this table: not null does not forbid the empty string, and these two columns are"
             ++ " the only witness of which toolchain answered this event.")
  | otherwise = Nothing

-- | The token a row came back carrying, resolved through 'outcomes' rather than by a second
-- hand-written table.
--
-- Derived from the producer on purpose: a reader with its own list of four strings is a second
-- place the vocabulary can drift, and the drift would show up as an unreadable row rather than as
-- a failure.
outcome_from_token :: String -> Maybe Outcome
outcome_from_token token =
  case [o | o <- outcomes, outcome_token o == token] of
    (o : _) -> Just o
    []      -> Nothing

-- ---------------------------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------------------------

-- | The ledger, as a value.
data Ledger = Ledger
  { ledger_label        :: String
    -- ^ which ledger this is, so a failure names the one it came from.
  , ledger_commit_block :: Integer -> [LedgerRow] -> IO ()
    -- ^ THE BLOCK'S ROWS AND THAT BLOCK'S WATERMARK, INDIVISIBLY. One call, one transaction.
  , ledger_seen         :: EventId -> IO Bool
    -- ^ has this exact position in the chain already been recorded?
  , ledger_rows_for     :: EventId -> IO [LedgerRow]
    -- ^ every row under that identity. A LIST, although the unique constraint admits at most one:
    -- a check that could only ever receive one row could not OBSERVE the constraint failing.
  , ledger_watermark    :: IO (Maybe Integer)
    -- ^ the last block fully processed, or @Nothing@ before the first commit.
  }

-- ---------------------------------------------------------------------------------------------
-- The reference implementation
-- ---------------------------------------------------------------------------------------------

-- | Both halves of the commit, in ONE value, so a half-applied commit has no representation.
data LedgerState = LedgerState
  { ls_rows      :: !(M.Map EventId LedgerRow)
  , ls_watermark :: !(Maybe Integer)
  }

new_memory_ledger :: IO Ledger
new_memory_ledger = do
  ref <- newIORef (LedgerState M.empty Nothing)
  pure
    Ledger
      { ledger_label        = "Loop.Ledger (memory)"
      , ledger_commit_block = memory_commit ref
      , ledger_seen         = \eid -> not . null <$> memory_rows_for ref eid
      , ledger_rows_for     = memory_rows_for ref
      , ledger_watermark    = ls_watermark <$> readIORef ref
      }

-- | Every row whose OWN identity field is this event, found by SCANNING rather than by looking the
-- map key up.
--
-- The two are equivalent while the map is keyed on 'lr_event', and the scan is written anyway,
-- deliberately: a reader that looks up the key it assumes the writer used cannot OBSERVE the
-- writer keying on something else. A ledger keyed on the content key instead of the position is
-- the precise defect LOOP-02's second direction exists to catch -- two distinct events carrying an
-- identical shock collapsing into one row -- and with a lookup-based reader that mutation makes
-- BOTH events unfindable, which reddens for a reason nobody wrote down. With the scan it reddens
-- by returning ONE row where two were committed, which is the failure as stated.
memory_rows_for :: IORef LedgerState -> EventId -> IO [LedgerRow]
memory_rows_for ref eid =
  filter ((== eid) . lr_event) . M.elems . ls_rows <$> readIORef ref

-- | FIRST-WRITER-WINS on the event identity, and the same rule the server applies.
--
-- The refusals are checked over the WHOLE list before the single write, so a list whose second row
-- is unstorable leaves the first row unwritten and the watermark where it was -- which is what the
-- server's transaction does, and which is the whole of LOOP-05 on this side.
memory_commit :: IORef LedgerState -> Integer -> [LedgerRow] -> IO ()
memory_commit ref block rows =
  case [why | Just why <- map ledger_row_refusal rows] of
    (why : _) ->
      throwIO . userError $
        "Loop.Ledger (memory): this block's rows were REFUSED and nothing was committed -- "
          ++ why
          ++ " The block's rows and its watermark advance are one step, so the watermark did not"
          ++ " move either."
    [] ->
      atomicModifyIORef' ref $ \state ->
        ( LedgerState
            { ls_rows      = foldl keep_the_first (ls_rows state) rows
            , ls_watermark = Just block
            }
        , ()
        )
  where
    keep_the_first held row = M.insertWith (\_new old -> old) (lr_event row) row held

-- ---------------------------------------------------------------------------------------------
-- The real one
-- ---------------------------------------------------------------------------------------------

-- | The same five fields, backed by a live connection.
--
-- The row insert copies @Store.Postgres.put_run@'s conventions rather than inventing a second set:
-- @bytea@ goes through 'Binary', the conflict clause names the CONSTRAINT rather than the column
-- list, and the statement is a top-level 'Query' so it is written once.
new_postgres_ledger :: Connection -> Ledger
new_postgres_ledger con =
  Ledger
    { ledger_label        = "Loop.Ledger (postgres)"
    , ledger_commit_block = commit_block con
    , ledger_seen         = seen con
    , ledger_rows_for     = rows_for con
    , ledger_watermark    = watermark con
    }

-- | ONE TRANSACTION. Both statements, or neither.
--
-- @withTransaction@ wraps the whole block: a failure anywhere -- a CHECK refusing a row, the
-- connection dropping between the rows and the watermark -- rolls the entire block back, so a
-- restart re-processes that block from a watermark that never moved. That is LOOP-05, delivered by
-- the transaction boundary rather than by a compensating write nobody would ever run.
commit_block :: Connection -> Integer -> [LedgerRow] -> IO ()
commit_block con block rows =
  withTransaction con $ do
    mapM_ (insert_event con) rows
    _ <- execute con advance_watermark_sql (Only block)
    pure ()

insert_event :: Connection -> LedgerRow -> IO ()
insert_event con row = do
  let KeyScheme scheme = lr_key_scheme row
  _ <-
    execute
      con
      insert_event_sql
      ( ev_tx_hash (lr_event row)
      , ev_log_index (lr_event row)
      , lr_block row
      , lr_model row
      , scheme
      , fmap Binary (lr_key row)
      , outcome_token (lr_outcome row)
      , lr_reason row
      , lr_gams_ver row
      , lr_conopt_ver row
      , lr_fee_source row
      )
  pure ()

-- | FIRST-WRITER-WINS on the event identity, exactly as the reference implementation is.
--
-- @do nothing@ rather than an update: a replayed event must not be able to overwrite what the
-- first pass recorded, because the first pass is the one that happened.
insert_event_sql :: Query
insert_event_sql =
  "insert into loop_event \
  \ (tx_hash, log_index, block, model, key_scheme, key, outcome, reason, gams_ver, conopt_ver, \
  \  fee_source) \
  \ values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) \
  \ on conflict on constraint loop_event_identity do nothing"

-- | The single row, upserted on its own primary key.
advance_watermark_sql :: Query
advance_watermark_sql =
  "insert into loop_watermark (only_row, block) values (true, ?) \
  \ on conflict (only_row) do update set block = excluded.block, updated_at = now()"

seen :: Connection -> EventId -> IO Bool
seen con eid = do
  found <-
    query
      con
      "select 1 from loop_event where tx_hash = ? and log_index = ?"
      (ev_tx_hash eid, ev_log_index eid)
  pure (not (null (found :: [Only Int])))

rows_for :: Connection -> EventId -> IO [LedgerRow]
rows_for con eid = do
  found <-
    query
      con
      "select block, model, key_scheme, key, outcome, reason, gams_ver, conopt_ver, fee_source \
      \ from loop_event where tx_hash = ? and log_index = ?"
      (ev_tx_hash eid, ev_log_index eid)
  mapM rebuild found
  where
    -- An unrecognised token RAISES rather than defaulting. The DDL's outcome check makes it
    -- unreachable today, and a default here is what would keep it unreachable-looking on the day
    -- the check is dropped: a corrupt token silently read back as one of the four is a row whose
    -- post-mortem reads a verdict nobody wrote. Detection that finds nothing aborts.
    rebuild (block, model, scheme, key, token, reason, gams, conopt, fee_source) =
      case outcome_from_token token of
        Nothing ->
          throwIO . userError $
            "Loop.Ledger (postgres): loop_event row " ++ show (ev_tx_hash eid) ++ " / "
              ++ show (ev_log_index eid) ++ " carries the outcome token " ++ show token
              ++ ", which is none of " ++ show (map outcome_token outcomes)
              ++ ". loop_event_outcome_known is what forbids that, so either the constraint is"
              ++ " gone or this row was written by something that is not this module."
        Just decided ->
          pure
            LedgerRow
              { lr_event      = eid
              , lr_block      = block
              , lr_model      = model
              , lr_key_scheme = KeyScheme scheme
              , lr_key        = key
              , lr_outcome    = decided
              , lr_reason     = reason
              , lr_gams_ver   = gams
              , lr_conopt_ver = conopt
              , lr_fee_source = fee_source
              }

watermark :: Connection -> IO (Maybe Integer)
watermark con = do
  found <- query con "select block from loop_watermark where only_row" ()
  pure $ case found of
    (Only block : _) -> Just block
    []               -> Nothing
