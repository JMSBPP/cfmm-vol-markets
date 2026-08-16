-- |
-- The reference 'Store', backed by two 'IORef'-held 'M.Map's and no server.
--
-- This is where DB-03's "the store checks still discriminate" is actually delivered. The laws in
-- @Store.Laws@ run for REAL against this implementation inside @cabal test@ -- real executions of
-- the store contract, not assertions over a committed file -- so most of the discrimination never
-- needed a database at all.
--
-- Everything here is total. Nothing throws.
module Store.Memory (new_memory_store) where

import           Data.IORef            (IORef, modifyIORef', newIORef, readIORef)
import qualified Data.ByteString       as BS
import qualified Data.Map.Strict       as M
import qualified Data.Text.Encoding    as TE
import qualified Data.Text.Encoding.Error as TEE

import Store.Class (Store (..))
import Store.Types
  ( Artifact
  , KeyScheme
  , StoredRun (..)
  , artifact_bytes
  , derived_doc_from_text
  , derived_doc_sha256
  )

-- | The FULL triple. Keying on @(model, key)@ alone would make an insert under a new
-- 'KeyScheme' silently OVERWRITE the old row instead of creating a second one, which is precisely
-- the corruption KEY-07 exists to prevent -- and a Memory store that got this wrong would let the
-- KEY-07 law pass against it and fail only against Postgres, months later.
type RunKey = (String, KeyScheme, BS.ByteString)

run_key :: StoredRun -> RunKey
run_key sr = (sr_model sr, sr_key_scheme sr, sr_key sr)

new_memory_store :: IO Store
new_memory_store = do
  runs  <- newIORef M.empty
  blobs <- newIORef M.empty
  pure Store
    { store_label      = "Store.Memory"
    , store_put        = put_run runs
    , store_lookup     = \model scheme key -> M.lookup (model, scheme, key) <$> readIORef runs
    , store_put_blob   = put_blob blobs
    , store_get_blob   = \name -> M.lookup name <$> readIORef blobs
    , store_doc_sha256 = \model scheme key ->
        fmap doc_digest . M.lookup (model, scheme, key) <$> readIORef runs
    }

-- | FIRST-WRITER-WINS on the full triple. Re-putting an existing @(model, key_scheme, key)@ is a
-- no-op, so a second solve that disagrees cannot quietly replace the first one -- it has to be
-- READ BACK and compared, which is the whole point of keying on the shock.
--
-- Inserting the same @(model, key)@ under a DIFFERENT 'KeyScheme' SUCCEEDS and creates a second
-- entry. That is not an oversight in the first-writer rule; it is KEY-07.
put_run :: IORef (M.Map RunKey StoredRun) -> StoredRun -> IO ()
put_run ref sr = modifyIORef' ref (M.insertWith keep_the_first (run_key sr) sr)

-- | LAST-writer-wins, unlike 'put_run', and deliberately.
--
-- The blob surface is not an identity surface: it has no @key_scheme@, its names are corpus
-- member names, and re-putting one is a RE-MEASUREMENT rather than a conflicting second solve.
-- The bytes are stored and returned verbatim -- no normalization, no encoding, no 'Data.Text'
-- anywhere on this path.
put_blob :: IORef (M.Map String Artifact) -> String -> Artifact -> IO ()
put_blob ref name art = modifyIORef' ref (M.insert name art)

keep_the_first :: a -> a -> a
keep_the_first _new old = old

-- | The derived projection's digest, rendered the only way a server-free store honestly can.
--
-- This decodes the artifact's bytes as UTF-8 and digests that. It does NOT model @jsonb@
-- normalization, and it must not pretend to: the reordered-keys\/re-rendered-numbers exhibit is a
-- POSTGRES observation and belongs to the capture (plan 23-04). A Memory-side "exhibit" would be
-- comparing a value to itself through a function that changes nothing -- the tautology this repo
-- has already been bitten by, wearing an eighth costume.
--
-- 'TEE.lenientDecode' rather than a partial decoder because this module promises totality; the
-- substitution it performs is invisible to every caller, since the only thing that ever leaves
-- here is a digest of the result and the corpus that is not valid UTF-8 travels the blob path.
doc_digest :: StoredRun -> String
doc_digest =
  derived_doc_sha256
    . derived_doc_from_text
    . TE.decodeUtf8With TEE.lenientDecode
    . artifact_bytes
    . sr_raw
