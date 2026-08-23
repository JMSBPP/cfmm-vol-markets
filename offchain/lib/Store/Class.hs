-- |
-- The store SEAM: a record of functions, not a typeclass.
--
-- This codebase defines zero typeclasses of its own across 26 library modules, and the record is
-- what a later check needs anyway -- "a store whose 'store_put' fails on the third call" is one
-- line of record update against 'Store.Memory.new_memory_store', and that deliberately-wrong
-- store is the instrument DB-03 leans on. A typeclass would need a whole new instance and a new
-- type for every such variation, which is how sentinel stores stop being written.
--
-- Three separate surfaces, and the separation is load-bearing rather than tidy:
--
--   * the KEYED store ('store_put' \/ 'store_lookup') -- identity is @(model, key_scheme, key)@,
--     all THREE;
--   * the BYTE-FIDELITY surface ('store_put_blob' \/ 'store_get_blob') -- separate because the
--     adversarial corpus is deliberately neither valid UTF-8 nor valid JSON, and @model_run.doc@
--     is a @NOT NULL jsonb@ derived from @raw@, so @0x00@ and @0xFF@ could not be carried by
--     'store_put' even in a perfectly correct implementation;
--   * the DERIVED-PROJECTION read ('store_doc_sha256') -- a DIGEST only, never bytes.
module Store.Class (Store (..)) where

import qualified Data.ByteString as BS

import Store.Types (Artifact, KeyScheme, ResetScope, StoredRun)

data Store = Store
  { store_label :: String
    -- ^ Which implementation this is, so a failure names the store it came from.

    -- * The keyed store
  , store_put :: StoredRun -> IO ()
    -- ^ Identity is @(model, key_scheme, key)@ -- all three. KEY-07.
  , store_lookup :: String -> KeyScheme -> BS.ByteString -> IO (Maybe StoredRun)
    -- ^ 'Nothing' when the TRIPLE is absent. Never a near-miss, never a fallback to another
    -- scheme: a lookup under a superseded @key_scheme@ must ORPHAN, not almost-match.

    -- * The byte-fidelity surface
  , store_put_blob :: String -> Artifact -> IO ()
  , store_get_blob :: String -> IO (Maybe Artifact)
    -- ^ Verbatim in, verbatim out. Any normalization anywhere in this path is the defect
    -- BYTE-05 exists to catch.

    -- * The derived projection, as a digest
  , store_doc_sha256 :: String -> KeyScheme -> BS.ByteString -> IO (Maybe String)
    -- ^ A DIGEST, deliberately. 'Store.Types' exports 'Store.Types.DerivedDoc' abstractly and
    -- there is no way to get bytes back out of one, so this cannot become the oracle by
    -- accident -- not even by a caller who wants it to.

    -- * The destructive operation, which is on this record and nowhere else
  , store_reset :: ResetScope -> IO ()
    -- ^ STORE-06. Empty what the 'ResetScope' names, and nothing else.
    --
    -- It is a FOURTH surface rather than a mode of one of the three above, because the other three
    -- are things a request does and this is a thing an operator does. The scope argument is what
    -- makes it unwritable by accident: there is no @store_reset store@ that type-checks.
    --
    -- The seam being a record is what leaves this reachable to a caller that imports @Store (..)@
    -- and does not call it. That is not a hole -- a typeclass would have exactly the same property,
    -- since the method would be in scope wherever the constraint was -- and the standing assertion
    -- that the solve path does not call it is a source scan over @Store.Cache@ in
    -- @offchain\/test\/Main.hs@, not anything in this type. What the type CAN do is refuse the
    -- unscoped call, and it does.
  }
