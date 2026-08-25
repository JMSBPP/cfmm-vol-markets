-- |
-- The store CONTRACT, as types rather than as checks.
--
-- Two of this module's guarantees are enforced by the TYPE CHECKER and not by anything in
-- @offchain\/test\/Main.hs@, deliberately. A check can be deleted, renamed, or scoped until it
-- reads nothing; a type cannot be compared away.
--
--   * 'Artifact' is the ORACLE -- the @raw@ @bytea@ column. It has 'Eq'. It is the only thing a
--     byte-identity claim may ever be read off.
--   * 'DerivedDoc' is the DERIVED PROJECTION -- the @doc@ @jsonb@ column. It has no 'Eq', no
--     'Ord', no 'Show', no exported constructor, and there is no @DerivedDoc -> Artifact@ and no
--     @DerivedDoc -> ByteString@ anywhere. So @doc == doc@ does not type-check and a doc can
--     never stand in for the oracle. That is BYTE-02, discharged at compile time.
--
-- MEASURED three times in prior research: @jsonb@ reorders object keys and re-renders numbers
-- through @numeric@, so a byte-identity claim read off the @doc@ column tests Postgres's
-- normalizer rather than GAMS.
--
-- This module also carries 'adversarial_corpus'. Every member is tagged with the behaviour it
-- was MEASURED to produce on the BROKEN (bare 'BS.ByteString') write path, because \"the guard
-- fired\" is evidence only if you know WHICH failure you observed -- and one of the three
-- behaviours is shaped exactly like a dead connection.
module Store.Types
  ( -- * The oracle
    Artifact (..)
  , artifact_bytes
  , artifact_sha256
    -- * The derived projection
  , DerivedDoc            -- ABSTRACT ON PURPOSE. Exporting its CONSTRUCTOR re-opens BYTE-02.
  , derived_doc_from_text
  , derived_doc_sha256
    -- * Keying
  , KeyScheme (..)
  , current_key_scheme
  , StoredRun (..)
    -- * Reset
  , ResetScope (..)
    -- * The adversarial corpus
  , CorpusBehaviour (..)
  , CorpusMember (..)
  , adversarial_corpus
    -- * The real artifact's pinned identity
  , volume_path_golden_sha256
  , volume_path_golden_bytes_len
    -- * Digest
  , sha256_hex
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE

import Crypto.Hash (SHA256 (..), hashWith)

-- ---------------------------------------------------------------------------------------------
-- Digest
-- ---------------------------------------------------------------------------------------------

-- | SHA256 as BARE lowercase hex -- no @0x@ prefix, ever.
--
-- @sc3_literal_purge@'s @purge_pattern@ (@offchain\/test\/Main.hs@) is @0x[0-9a-fA-F]{64}\\b@, so a
-- @0x@-prefixed digest anywhere under @offchain\/@ reddens the suite on sight. 'show' on crypton's
-- @Digest@ already renders bare lowercase hex, which is also why no @ByteArrayAccess@ conversion
-- appears here: that conversion is where the recorded 64-vs-32 length skew came from.
sha256_hex :: BS.ByteString -> String
sha256_hex bs = show (hashWith SHA256 bs)

-- ---------------------------------------------------------------------------------------------
-- The oracle
-- ---------------------------------------------------------------------------------------------

-- | THE ORACLE. The @raw@ @bytea@ column, byte-exact.
--
-- 'Eq' and 'Show' are deliberate: this is the column that gets compared. Its counterpart
-- 'DerivedDoc' deliberately has neither.
newtype Artifact = Artifact BS.ByteString
  deriving (Eq, Show)

artifact_bytes :: Artifact -> BS.ByteString
artifact_bytes (Artifact bs) = bs

-- | Bare lowercase hex, no @0x@. See 'sha256_hex'.
artifact_sha256 :: Artifact -> String
artifact_sha256 = sha256_hex . artifact_bytes

-- ---------------------------------------------------------------------------------------------
-- The derived projection
-- ---------------------------------------------------------------------------------------------

-- | THE DERIVED PROJECTION: the @doc@ @jsonb@ column, as Postgres rendered it back.
--
-- NO 'Eq'. NO 'Ord'. NO 'Show'. NO exported constructor. Adding any of them re-opens exactly the
-- hole BYTE-02 exists to close, and the compile failure that proves the absence of 'Eq' was
-- OBSERVED at 23-01 rather than assumed.
--
-- It wraps 'T.Text' -- the @doc::text@ RENDERING -- and NOT the aeson package's @Value@. Wrapping
-- @Value@ would force the aeson import onto the storage path and defeat BYTE-03's own source scan,
-- which plan 23-02 installs over that path. The column is still @jsonb@; only the Haskell-side
-- view of it changes, and the type-level guarantee is identical.
--
-- The two sentences above deliberately do NOT spell the aeson module path out. That scan reads
-- this file, so a comment SAYING the import is absent would be matched by the pattern that looks
-- for the import -- and this file would then be exempted from its own guard, which is how a
-- storage module gets a free pass. Prose is inside the grep's blast radius: 23-01 had to unpick
-- that shape three times, once substantively.
newtype DerivedDoc = DerivedDoc T.Text

derived_doc_from_text :: T.Text -> DerivedDoc
derived_doc_from_text = DerivedDoc

-- | The ONLY consumer of a 'DerivedDoc'. There is deliberately no way back to bytes.
derived_doc_sha256 :: DerivedDoc -> String
derived_doc_sha256 (DerivedDoc t) = sha256_hex (TE.encodeUtf8 t)

-- ---------------------------------------------------------------------------------------------
-- Keying
-- ---------------------------------------------------------------------------------------------

-- | KEY-07. The scheme a key was computed under, carried in the row and inside the unique
-- constraint, so a key-formula change ORPHANS the old rows rather than silently corrupting them.
newtype KeyScheme = KeyScheme Int
  deriving (Eq, Ord, Show)

-- Scheme 2 (issue #41, 2026-08-23): the fee inside the key may now come from the HOOK ROUTE
-- (DynamicFeeHook.getAverageVolatility at the pinned block fed into DynamicFeeMod.getCurrentFee)
-- when slot0's lpFee is zero, and not only from slot0. Two pools with equal pips from different
-- sources are different inputs, so scheme-1 rows are orphaned rather than matched -- KEY-07 is
-- exactly the mechanism that makes this a bump and not a silent reinterpretation.
current_key_scheme :: KeyScheme
current_key_scheme = KeyScheme 2

-- | One row of @model_run@, minus the derived projection.
--
-- NOTE the absent @doc@ field. The doc is NEVER carried in Haskell: it is computed by Postgres
-- from @raw@ and read back only as a digest, which is what keeps it structurally incapable of
-- becoming the oracle.
data StoredRun = StoredRun
  { sr_model      :: String
  , sr_key_scheme :: KeyScheme
  , sr_key        :: BS.ByteString
  , sr_raw        :: Artifact
  , sr_gams_ver   :: String
  , sr_conopt_ver :: String
  } deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- Reset
-- ---------------------------------------------------------------------------------------------

-- | STORE-06. WHAT an emptying is allowed to touch, as a REQUIRED argument.
--
-- One constructor today, and the type exists for the ARGUMENT rather than for the choice. A
-- function of type @IO ()@ can be written down accidentally -- a stray field, a partially applied
-- helper, a handler that discharges the wrong branch -- and it does the whole thing. A function
-- whose first argument is this type cannot be CALLED without a caller naming, at the call site and
-- in the source, which part of the store it means to empty. That is the difference between an
-- operation you have to ask for and an operation you can fall into, and it is the whole of
-- STORE-06's "separate, explicit".
--
-- 'ModelRunOnly' names the KEYED table and nothing else. The byte-fidelity surface is a separate
-- table holding the adversarial corpus below, which is a MEASUREMENT rather than a cache, and a
-- scope that quietly swept it would be destroying evidence while doing what it was asked. A second
-- constructor is added when something needs it -- not in advance, because a scope nothing selects
-- is a branch nothing tests.
--
-- STORE-05 (a run can be PINNED so retention never removes it) is deferred, so this carries no
-- @pinned@ predicate and the implementations carry no @where@ clause standing in for one. A
-- retention sweep with nothing to retain is dead code that reads like a guarantee.
data ResetScope = ModelRunOnly
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The adversarial corpus
-- ---------------------------------------------------------------------------------------------

-- | What a corpus member does on the BROKEN (bare 'BS.ByteString') write path.
--
-- Three behaviours, and only ONE of them is the failure BYTE-05 is actually about:
--
--   * 'ServerRejects'     -- a loud @SqlError@. Shaped EXACTLY like a dead connection, so a check
--                            that asserts only \"an exception was thrown\" cannot tell the guard
--                            firing from the database being down.
--   * 'RoundTripsAnyway'  -- absorbed silently by the broken path. Proves nothing at all.
--   * 'SilentlyCorrupted' -- a WRONG VALUE returned with no complaint. This is the one.
data CorpusBehaviour = ServerRejects | RoundTripsAnyway | SilentlyCorrupted
  deriving (Eq, Ord, Show)

data CorpusMember = CorpusMember
  { cm_name      :: String
  , cm_bytes     :: BS.ByteString
  , cm_behaviour :: CorpusBehaviour
  } deriving (Eq, Show)

-- | The corpus, each member carrying the behaviour it was MEASURED to produce on PG 18.4.
--
-- ROADMAP SC-1 states the corpus as @0x00@, @0xFF@, invalid UTF-8, a CRLF and a trailing newline.
-- Those five are the first five entries below, and only ONE of them produces a wrong value --
-- @0x00@, and for a reason nobody predicted (see the correction below the list). Two raise
-- @ERROR: invalid byte sequence for encoding \"UTF8\"@ and two round-trip correctly through the
-- broken path. A negative control built from SC-1's corpus alone would rest entirely on a member
-- whose behaviour every document describing it got wrong.
--
-- The backslash-plus-octal member is the one that makes the control real, and it is MEASURED,
-- not reasoned:
--
-- >  1|615c31303162|6|167235f74aa91cbaf0203d4d186f8a14   -- hex literal  (Binary / EscapeByteA)
-- >  2|614162      |3|9593f2df5265159c8d524f5603b222de   -- text literal (bare ByteString)
--
-- @61 5c 31 30 31 62@ (6 bytes) comes back as @61 41 62@ (3 bytes) with NO error and NO warning,
-- because @byteain@ still accepts the legacy escape format and re-reads @\\101@ as one octal byte.
-- DO NOT REMOVE IT. A corpus without a 'SilentlyCorrupted' member makes the whole negative control
-- vacuous, which is why the behaviour tag is asserted as a SET and never as a count.
-- MEASURED CORRECTION AT 23-04, against a real server through the real client. The @nul@ member
-- was tagged 'ServerRejects' on the strength of the research's transcript, which produced
-- @ERROR: invalid byte sequence for encoding \"UTF8\": 0x00@. Driven through
-- @postgresql-simple@'s bare-'BS.ByteString' path it does NOT raise: it goes in at ONE byte and
-- comes back at ZERO, with no error and no warning.
--
-- The mechanism is one layer below the server. @ToField ByteString@ is @Escape@, which hands the
-- value to libpq's C-string escaper, and a C string ENDS at its first NUL -- so the parameter that
-- reaches Postgres is the empty string and there is nothing left for the encoding check to reject.
-- Both readings are true of their own path; only this one is true of the path the corpus is a
-- corpus FOR. It is recorded in @store-conformance.json@ as @bare_outcome \"returned\"@ with
-- @bare_out_len 0@.
--
-- This STRENGTHENS BYTE-05 rather than weakening it. A total truncation at the first NUL is a
-- worse silent corruption than the backslash-octal member's 6-to-3, and it had been filed under
-- the loud behaviour -- the one that is shaped exactly like a dead connection and therefore proves
-- the least.
adversarial_corpus :: [CorpusMember]
adversarial_corpus =
  [ CorpusMember "nul"              (BS.pack [0x00])       SilentlyCorrupted
  , CorpusMember "high-byte"        (BS.pack [0xFF])       ServerRejects
  , CorpusMember "invalid-utf8"     (BS.pack [0xC3, 0x28]) ServerRejects
  , CorpusMember "crlf"             (C8.pack "a\r\nb")     RoundTripsAnyway
  , CorpusMember "trailing-newline" (C8.pack "a\n")        RoundTripsAnyway
  , CorpusMember "octal-escape"     (C8.pack "a\\101b")    SilentlyCorrupted
  , CorpusMember "double-backslash" (C8.pack "a\\\\b")     SilentlyCorrupted
  ]

-- ---------------------------------------------------------------------------------------------
-- The real artifact's pinned identity
-- ---------------------------------------------------------------------------------------------

-- | The real @volume_path.json@ produced by GAMS 54.1 \/ CONOPT 4.39.0.
--
-- MEASURED byte-identical at two independent paths on 2026-08-16, ending @5d 0a 7d 0a@.
--
-- The digest is pinned HERE, in Haskell source, and NOT beside the bytes in the artifact that
-- carries them: a digest recorded next to the thing it digests is the tautology defect this repo
-- has already been bitten by. And it is written BARE -- @sc3_literal_purge@ greps for
-- @0x@-prefixed 64-hex, so a prefixed literal here would redden the suite.
volume_path_golden_sha256 :: String
volume_path_golden_sha256 = "e7b14f384ab4c027be5450218a52040110d45dbaddbbfb0bb7bd5ab707d0d884"

volume_path_golden_bytes_len :: Int
volume_path_golden_bytes_len = 606
