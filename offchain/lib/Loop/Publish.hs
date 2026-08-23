-- |
-- LOOP-03: THE ATOMIC PUBLICATION, THE IDENTITY SPLICE, AND THE FLOOR THAT REFUSES.
--
-- What leaves this workstream is a file another repository parses. Two failures matter and they
-- are not the same failure. A HALF-WRITTEN fixture is a red test somebody else has to diagnose;
-- a WELL-FORMED fixture carrying re-rendered numbers is worse, because it is wrong and silent.
-- This module answers the first with a rename it does not own and the second with a splice that
-- never looks at a number.
--
-- WHY THE SPLICE IS TEXTUAL AND THE ARTIFACT IS NEVER RE-RENDERED
-- --------------------------------------------------------------
-- The stored bytes ARE the oracle. @Store.Types.Artifact@ holds what the prover wrote, byte for
-- byte, and Phase 25 stores THEM rather than a view of them. Publication therefore emits every
-- byte of the artifact after its own opening brace and puts three identity fields in front; it
-- does not decode the document into a value type and print it back out.
--
-- That is a MEASUREMENT and not a preference. The committed golden's @dQx[0]@ is
-- @-2613128317657530400@, above the 53-bit mantissa's exact ceiling, and BYTE-04 measured that
-- element moving by 32 wei through a carrier that re-renders it -- along with all sixteen elements
-- of @dQx ++ dQM@, @|delta|@ between 4 and 328. Those are swap amounts in wei. A publisher that
-- rebuilt the document would be a SECOND renderer of numbers this repository has already proven it
-- cannot afford to re-render, sitting at the exact point where the value leaves and becomes
-- somebody else's input.
--
-- The decode that DOES happen here is a gate and not a transcription: 'publish_bytes' asks
-- @Gams.Artifact.decode_artifact@ whether the bytes are an artifact at all, throws the decoded view
-- away, and splices the ORIGINAL bytes.
--
-- WHY THE SHAPE FLOOR IS TWO HALVES AND THE HARD HALF IS SOMEBODY ELSE'S
-- ---------------------------------------------------------------------
-- The consuming forge test asserts @assertEq(dQx.length, nEvents)@ and @require(nEvents > 0)@.
-- @Gams.Artifact.decode_artifact@'s post-conditions already refuse exactly those two, plus the
-- @dQM@ leg. Restating them here would be a second transcription of one contract, and the two
-- copies would be free to disagree. So the hard half of the floor is the DECODER'S, reached by
-- calling it, and what this module adds is the soft half a decoder cannot express: a byte count
-- below which a document is too small to be a real solve.
--
-- WHY THE RENAME IS NOT IN THIS FILE
-- ----------------------------------
-- It is @Driver.Capture.write_bytes_atomically@, and there is exactly one rename in this
-- repository. The temp file is a SIBLING of the destination for the reason that module records:
-- a rename that crossed a filesystem would silently degrade to a copy, and a copy is precisely the
-- torn read this requirement exists to prevent. A second writer here would be a second place for
-- that rule to be forgotten.
--
-- WHY THIS MODULE NEVER CREATES THE DIRECTORY
-- -------------------------------------------
-- LOOP-04. The publication directory belongs to the @mev_tax_model_one@ track (GitHub issues #24
-- and #25). A loop that created it would publish into a directory of its own invention and report
-- success. 'publish_fixture' refuses instead, naming the path, and 'publish_precondition' -- 28-04's
-- addition -- refuses the same directory BEFORE the first block, with the text an operator reads.
-- Nothing in this module makes a directory on any path, and the property is STRUCTURAL rather than
-- careful: the @System.Directory@ import list carries the two QUESTIONS -- @doesDirectoryExist@ and
-- @doesFileExist@ -- and no maker of any kind, so the branch that could do it does not typecheck.
-- The suite scans this file for the maker's name and expects to find it ZERO times, in code and in
-- prose alike, which is why neither is spelled anywhere below.
module Loop.Publish
  ( -- * Why a fixture was not published
    PublishRefusal (..)
    -- * Why a loop must not start
  , PublishPrecondition (..)
  , publish_precondition
  , publish_precondition_message
    -- * The floor
  , fixture_min_bytes
    -- * The pure core
  , identity_prefix
  , splice_identity
  , publish_bytes
    -- * The edge
  , publish_fixture
  ) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.List (intercalate)
import System.Directory (doesDirectoryExist, doesFileExist)
import System.FilePath ((</>))

import Chain.Read
  ( FixtureIdentity (..)
  , address_hex_digits
  , fixture_identity_entries
  , render_address_token
  , zero_address_token
  )
import Driver.Capture (write_bytes_atomically)
import Gams.Artifact (ArtifactError, decode_artifact)
import Loop.Config (fixture_dir_env_var, fixture_file_name)

-- ---------------------------------------------------------------------------------------------
-- Why a fixture was not published
-- ---------------------------------------------------------------------------------------------

-- | Every constructor names its subject, and every one of them means NOTHING WAS WRITTEN.
--
-- A refusal is not a fallback. There is no shape on which this module publishes a document it
-- could not vouch for, because the file it would write is read by a test in another repository
-- that has no way to tell a fixture from a rumour.
data PublishRefusal
  = ArtifactUnparseable ArtifactError
    -- ^ the bytes are not an artifact, carrying the DECODER'S OWN reason. This is the shape
    -- floor's hard half and it is deliberately not restated here: @post_conditions@ already
    -- refuses @nEvents <= 0@, @length dQx \/= nEvents@ and a @dQM@ of a different length, which is
    -- the same equality the consuming forge test asserts at @assertEq(dQx.length, nEvents)@.
  | BelowShapeFloor Int Int
    -- ^ observed bytes, then 'fixture_min_bytes'. Both numbers, because a floor reported without
    -- the observation is a failure an operator has to reproduce to understand.
  | PoolIsTheZeroAddress
    -- ^ the pool is the address that is not an address. SHAPE-VALID, which is why it has its own
    -- arm: 27-03 MEASURED that folding it into the arm below leaves it unreachable, and the zero
    -- word is exactly what an absent subject looks like once it is an @Integer@.
  | PoolIsNotAnAddressToken String
    -- ^ the rendered token, verbatim. @Chain.Read.render_address_token@ deliberately does NOT
    -- mask, so a value too large for twenty bytes renders LONGER and is visible here instead of
    -- being wrapped into a plausible pool nobody measured.
  | NotAJsonObject String
    -- ^ the leading bytes, so the failure says what was found instead of an opening brace. See
    -- 'splice_identity' for why the decoder makes this unreachable from 'publish_bytes' and why it
    -- is still a constructor.
  | PublicationDirectoryAbsent FilePath
    -- ^ the directory does not exist and this module does not create it -- LOOP-04. The path is
    -- named; the workstream that owns it is named by 28-04's startup precondition, which is where
    -- an operator meets this condition before any block is processed.
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- Why a loop must not start
-- ---------------------------------------------------------------------------------------------

-- | The two states of the publication directory that stop a loop BEFORE its first block.
--
-- Distinct from 'PublishRefusal' on purpose, and the distinction is not tidiness. A
-- 'PublishRefusal' is a fact about ONE document at ONE moment of a RUNNING loop; these two are
-- facts about the process's environment, discovered before any block was read, and they exit by
-- @Loop.Config.exit_code_for_precondition@ rather than being written into a report.
--
-- 'FixtureDirNotADirectory' is separate from 'FixtureDirAbsent' for the reason 27-03 recorded about
-- the zero address: an operator who typed a path that is a FILE has a different repair from one
-- whose directory has not landed yet, and one message covering both would name neither. The suite
-- asserts the two rendered messages DIFFER, so they cannot quietly become one message reused.
data PublishPrecondition
  = FixtureDirAbsent FilePath
    -- ^ nothing exists at the RESOLVED path. Today this is the live case in every clone of this
    -- branch: @test\/models\/mev_tax_model_one\/fixtures@ is on neither this worktree nor
    -- @origin\/develop@.
  | FixtureDirNotADirectory FilePath
    -- ^ something exists at the resolved path and it is a FILE. Not created over, not removed.
  deriving (Eq, Show)

-- | IS THE PUBLICATION DIRECTORY THERE? A question, never an action.
--
-- MAKES NOTHING on any path -- not in a fallback, not in an error branch, not \"just this once\".
-- See the module header for why that is structural rather than careful. The suite asserts the
-- filesystem is UNCHANGED after a refusal, which is the arm that would notice a repair made in the
-- wrong direction.
--
-- == WHY THE TEXT BELOW IS THIS SPECIFIC, AND IT IS TWO REASONS RATHER THAN ONE
--
-- 1. A loop that CREATED the directory turns a typo into a fixture published where nothing reads
--    it. The bytes reach a disk, the write succeeds, the report says @published@, and the file sits
--    in a directory this workstream invented. Nothing anywhere is red.
-- 2. The consuming forge test SKIPS while the file is absent --
--    @vm.skip(true, \"awaiting volume_path.json - off-chain rpc_api bridge (#25), delegated\")@.
--    So a wrong path produces a GREEN test on both sides of the boundary and no evidence anywhere
--    that the bridge is not working. The two failure modes compose into silence, and the only place
--    to break the silence is here, before anything has run.
--
-- == WHY THIS RUNS AT STARTUP AND 'publish_fixture' STILL KEEPS ITS OWN GUARD
--
-- At STARTUP because a loop that discovers this on its first EVENT has already advanced a watermark
-- past blocks it could not publish for -- LOOP-05's ordering, arriving from the publication side.
-- And 'publish_fixture' keeps its guard because the two are DIFFERENT EVENTS: a directory removed
-- while the loop runs is not a directory that was never there, and a startup check that was the
-- only one would make the running loop's behaviour depend on nothing having changed underneath it.
publish_precondition :: FilePath -> IO (Either PublishPrecondition ())
publish_precondition dir = do
  is_directory <- doesDirectoryExist dir
  is_file      <- doesFileExist dir
  pure $
    if is_directory
      then Right ()
      else Left (if is_file then FixtureDirNotADirectory dir else FixtureDirAbsent dir)

-- | THE REFUSAL, RENDERED: the resolved path, the workstream that owns it, the refusal to create
-- it, and the repair.
--
-- One message carries all four because an operator meets this once, on stderr, next to an exit
-- code. Splitting it across a @show@ and a runbook is how the owning workstream stops being named.
publish_precondition_message :: PublishPrecondition -> String
publish_precondition_message (FixtureDirAbsent dir) =
  "the publication directory " ++ show dir ++ " DOES NOT EXIST, and this process will not create"
    ++ " it. That directory belongs to the mev_tax_model_one workstream -- GitHub issues #24 and"
    ++ " #25 -- and a loop that created it would publish a fixture into a path of its own"
    ++ " invention, report success, and leave the consuming forge test skipping forever. Land the"
    ++ " directory on develop from the #24 track, or point " ++ fixture_dir_env_var
    ++ " at a directory that already exists."
publish_precondition_message (FixtureDirNotADirectory dir) =
  "the publication directory " ++ show dir ++ " EXISTS AND IS A FILE, not a directory. This process"
    ++ " will not remove it and will not create a directory over it. That path belongs to the"
    ++ " mev_tax_model_one workstream -- GitHub issues #24 and #25 -- so a file sitting there is"
    ++ " either their tree or a typo in this side's override. Repair the tree on develop, or point "
    ++ fixture_dir_env_var ++ " at a real directory."

-- ---------------------------------------------------------------------------------------------
-- The floor
-- ---------------------------------------------------------------------------------------------

-- | The smallest document this module is willing to call a solve, in bytes.
--
-- The soft half of the shape floor. It exists for the failure the decoder cannot see: a document
-- that is structurally a valid artifact -- ten fields, one event, arrays of matching length -- and
-- is far too small to be output of the production model, which solves eight events over two legs.
-- Such a document parses, satisfies the consuming test's own two assertions, and is still not the
-- thing anybody asked for.
--
-- 200 AND NOT MORE, and the bound is asserted rather than argued: the committed golden is
-- @Store.Types.volume_path_golden_bytes_len@ = 606 bytes, and
-- 'the_shape_floor_refuses_what_it_must_and_admits_the_golden' asserts
-- @fixture_min_bytes < volume_path_golden_bytes_len@ BEFORE it drives anything. A floor above
-- every real artifact refuses everything and passes its own refusal table, which is this
-- milestone's standing defect -- an assertion that holds because its subject is absent -- pointed
-- the other way.
fixture_min_bytes :: Int
fixture_min_bytes = 200

-- ---------------------------------------------------------------------------------------------
-- The pure core
-- ---------------------------------------------------------------------------------------------

-- | The three CHAIN-05 entries, rendered as the bytes that go in FRONT of the artifact's own.
--
-- Opening brace, the three @\"key\":value@ pairs joined by commas, then the comma that joins them
-- to whatever follows. The JSON TYPES are @Chain.Read.fixture_identity_entries@'s and not this
-- module's: @pool@ and @blockNumber@ arrive already quoted and @chainId@ does not, and that
-- asymmetry IS the contract issue #29 handed back across the workstream boundary.
--
-- @blockNumber@ is a STRING because a JSON number is carried by ordinary consumers through the
-- 53-bit binary64 mantissa. That is the same carrier BYTE-04 measured losing 32 wei on this
-- repository's own golden, and a fixture is a file parsed by decoders this workstream does not
-- control.
identity_prefix :: FixtureIdentity -> BS.ByteString
identity_prefix identity =
  C8.pack
    ("{" ++ intercalate "," [quoted name ++ ":" ++ value | (name, value) <- entries] ++ ",")
  where
    entries = fixture_identity_entries identity
    quoted s = "\"" ++ s ++ "\""

-- | The splice itself: the identity prefix, then EVERY BYTE of the artifact after its own opening
-- brace.
--
-- Not a merge of two documents and not a re-rendering of one. The artifact's bytes are copied
-- across a byte-range boundary and nothing between the first brace and the end of the file is
-- looked at, let alone parsed and printed back.
--
-- == WHY 'NotAJsonObject' IS HERE AND WHY 'publish_bytes' CANNOT REACH IT
--
-- This function is TOTAL, and the brace it drops is the one thing it needs to find. Rather than
-- index blindly it says so when the byte is missing. From 'publish_bytes' that branch is
-- unreachable, and the reason is worth writing down rather than discovering: @decode_artifact@
-- runs FIRST and refuses anything whose top level is not a JSON object, so by the time this
-- function is called the opening brace is guaranteed. The branch is therefore exercised DIRECTLY
-- by the suite, against this function, instead of being asserted through a caller that cannot
-- produce it -- because a defensive branch nothing ever runs is a branch that is wrong on the day
-- the guard in front of it moves.
splice_identity :: FixtureIdentity -> BS.ByteString -> Either PublishRefusal BS.ByteString
splice_identity identity bytes =
  case BS.uncons (BS.dropWhile is_space bytes) of
    Just (byte, rest) | byte == open_brace -> Right (identity_prefix identity <> rest)
    _ -> Left (NotAJsonObject (C8.unpack (BS.take 32 bytes)))
  where
    open_brace = 123
    is_space b = b == 32 || b == 9 || b == 10 || b == 13

-- | THE WHOLE DECISION, PURE: bytes in, the published document or the reason there is none.
--
-- The ORDER IS THE DESIGN and each step is here because the one before it would otherwise report
-- the wrong subject:
--
-- 1. @decode_artifact@. A @Left@ is 'ArtifactUnparseable', carrying the decoder's own words. This
--    is the shape floor's hard half, borrowed rather than copied.
-- 2. The byte floor. Asserted AFTER the decode, so a document that is not an artifact at all is
--    reported as that rather than as a small one.
-- 3. The pool token, on TWO arms. Shape first, then the zero address, because the zero address
--    passes every hex-shape guard ever written and folding the two leaves the second unreachable.
-- 4. The splice. Never a re-render -- see the module header, and see BYTE-04 for the 32 wei.
publish_bytes :: FixtureIdentity -> BS.ByteString -> Either PublishRefusal BS.ByteString
publish_bytes identity bytes = do
  _ <- case decode_artifact bytes of
         Left err -> Left (ArtifactUnparseable err)
         Right _  -> Right ()
  _ <- if BS.length bytes >= fixture_min_bytes
         then Right ()
         else Left (BelowShapeFloor (BS.length bytes) fixture_min_bytes)
  let token = render_address_token (fi_pool identity)
  _ <- if length token == 2 + address_hex_digits
         then Right ()
         else Left (PoolIsNotAnAddressToken token)
  _ <- if token /= zero_address_token
         then Right ()
         else Left PoolIsTheZeroAddress
  splice_identity identity bytes

-- ---------------------------------------------------------------------------------------------
-- The edge
-- ---------------------------------------------------------------------------------------------

-- | Decide, then write -- ATOMICALLY, into a directory this module did not create.
--
-- Returns the path that was written, or the reason nothing was. The write is
-- @Driver.Capture.write_bytes_atomically@: a sibling temp file in the SAME directory, then a
-- rename. On POSIX that rename is atomic, so a consumer racing this function reads either the old
-- complete document or the new complete document and never a prefix of either.
--
-- The directory is TESTED and never created. See the module header: LOOP-04 makes the missing
-- directory a stop rather than a publication into a path this workstream invented.
publish_fixture
  :: FilePath -> FixtureIdentity -> BS.ByteString -> IO (Either PublishRefusal FilePath)
publish_fixture dir identity bytes =
  case publish_bytes identity bytes of
    Left refusal -> pure (Left refusal)
    Right document -> do
      there <- doesDirectoryExist dir
      if not there
        then pure (Left (PublicationDirectoryAbsent dir))
        else do
          let path = dir </> fixture_file_name
          write_bytes_atomically path document
          pure (Right path)
