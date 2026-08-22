{-# LANGUAGE OverloadedStrings #-}

-- |
-- CHAIN-02's OBSERVATIONAL half, executed against a live chain and recorded.
--
-- == WHY THIS EXISTS AS A PROGRAM RATHER THAN AS A CHECK
--
-- CHAIN-02's obvious test cannot fail. On a single-writer local anvil a pinned read and an unpinned
-- read return the same value in every recorded field, so a check that made both and compared them
-- would pass whether or not the pin existed at all. The defect is invisible unless the divergence
-- is CONSTRUCTED, and constructing it means changing the chain's state between the two reads --
-- which @cabal test@ is structurally forbidden from doing. So the divergence is constructed here,
-- out of band, and the artifact is what the suite asserts over.
--
-- == WHY THIS PROGRAM EXISTS AT ALL, WHICH IS A SEPARATE QUESTION
--
-- 'Chain.Read' is deliberately split: a PURE rule ('refuse_or_value', 'decode_word_token') that the
-- suite drives at arguments a local anvil will not produce on demand, and a WIRING half
-- ('read_pool_field', 'read_raw_word_token', 'block_param') that only a chain can run. Without this
-- program the wiring half is never executed by anything, which is this repository's
-- advertised-and-dead shape exactly -- three path constants were measured in that state at 22-03,
-- 22-04 and 22-07, and in each case the falsification aimed through the dead surface came back
-- green. Every read in the wiring half is called below.
--
-- == THE CONSTRUCTION, AND WHAT MAKES IT EVIDENCE
--
--   1. read the head height @b@ and read the pool's @Slot0@ word PINNED at @b@;
--   2. change the pool's state -- @anvil_setStorageAt@ writes a new @tick@ into that same word;
--   3. mine, so the change is in a block AFTER @b@;
--   4. read PINNED at @b@ again. It must return the step-1 value.
--   5. read with NO PIN, through the raw transport. It must return the step-2 value.
--
-- Step 5 is the one that stops the whole capture passing vacuously. If the unpinned read does NOT
-- move, the divergence was never constructed and steps 1-4 prove nothing -- a pinned read agreeing
-- with itself on a chain that did not change is not evidence about pinning. @unpinned_differs@ is
-- therefore recorded as a field and asserted by the suite, and this program refuses to write a
-- passing artifact without it.
--
-- == WHY THE UNPINNED PROBE IS SPELLED OUT HERE
--
-- Because 'Chain.Read' cannot express it. 'BlockRef' is a @newtype@ with one constructor, so there
-- is no value of that type meaning \"whatever height the node is at\", and no read in that module
-- accepts anything else. The control therefore has to be built from the raw transport, and it is
-- built HERE, in the capture's own source, where it reads as the control it is rather than as a
-- read the layer offers. This is the ONLY place in this package that names the moving-head
-- constructor outside the transport's own module.
--
-- == WHAT IS DELIBERATELY NOT RECORDED
--
-- The endpoint. 27-01 made the resolved URL the output of ONE rule stated once per language, and
-- an artifact carrying the authority would be a third statement of it -- inside @offchain/@, inside
-- the endpoint census's blast radius, and committed. The @chainId@ is recorded instead: it is the
-- identity that matters for provenance, it is asserted against the manifest's before any write is
-- attempted, and it says nothing about which socket answered.
module Main (main) where

import Control.Monad (unless, when)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (Value, object, (.=))
import Data.Bits (complement, shiftL, (.&.), (.|.))
import Data.Char (isSpace)
import Data.List (dropWhileEnd, isInfixOf)
import Data.String (fromString)

import Data.ByteArray.HexString (toBytes)
import Data.Solidity.Prim.Address (Address)

import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Ethereum.Api.Types (Call (..), DefaultBlock (Latest), Quantity, unQuantity)
import Network.JsonRpc.TinyClient (remote)
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')
import System.Exit (exitFailure)
import System.Process (readProcess)

import Chain.Endpoint (resolve_endpoint)
import Chain.Read
  ( BlockRef (AtBlock)
  , PoolField (..)
  , ReadAt (Pinned, Unpinned)
  , pool_field_name
  , pool_fields
  , read_pool_field
  , read_raw_word_token
  , readback_height
  , refusal_naming
  , render_word_token
  )
import CheatSwap.Encoding (encode_extsload, hex32)
import CheatSwap.Rpc (anvil_set_storage_at)
import CheatSwap.Types (pool_state_slot)
import Driver.Capture (write_json_atomically)
import Rig.Manifest
  ( Rig (..)
  , RigAddresses (..)
  , RigPool (..)
  , contract_address
  , hex_to_integer
  , load_rig
  , resolve_contract
  )

-- ---------------------------------------------------------------------------------------------
-- Constants of the measurement
-- ---------------------------------------------------------------------------------------------

output_path :: FilePath
output_path = "offchain/rig/chain-read-conformance.json"

import_ref_path :: FilePath
import_ref_path = "offchain/rig/import-ref.txt"

-- | The tick written into the pool's @Slot0@ to construct the divergence.
--
-- 5000 for the reason @CheatSwapProof@ picks it and it is not arbitrary: the rig initialises at
-- tick 0 and the probe swap leaves it at -1, so a word carrying tick 5000 cannot be the state any
-- deploy produces. Observing it in the UNPINNED read and not in the PINNED one therefore has
-- exactly one possible cause.
divergence_tick :: Integer
divergence_tick = 5000

-- | How many blocks are mined after the write, so the change is unambiguously AFTER @b@.
--
-- More than one, deliberately. With a single block the pinned height @b@ and the head differ by
-- one, and an off-by-one in the block parameter -- the exact defect a pin is supposed to prevent --
-- would still read the changed state and look like a working pin reading a moved head.
blocks_mined :: Integer
blocks_mined = 3

-- ---------------------------------------------------------------------------------------------
-- The transport edges this program owns
-- ---------------------------------------------------------------------------------------------

-- | The chain's own id, asserted against the manifest's BEFORE any write is attempted.
--
-- 27-01 put this assertion into @deploy-rig.sh@ above its first broadcast for the same reason it is
-- here above the first @anvil_setStorageAt@: a state-changing call aimed at the wrong chain is not
-- recoverable by noticing afterwards.
eth_chain_id :: Web3 Quantity
eth_chain_id = remote "eth_chainId"

-- | Mine one block. Not a cheat on the state -- it is how the write above becomes a block after @b@.
evm_mine :: Web3 Value
evm_mine = remote "evm_mine"

-- | THE CONTROL PROBE: the same word, read with NO PIN.
--
-- Written out here rather than obtained from 'Chain.Read' because that module cannot express it,
-- and that inexpressibility is the property CHAIN-02 asks for. The call is otherwise byte-identical
-- to 'read_raw_word_token' -- same calldata, same target, same rendering -- so the ONLY difference
-- between this and a pinned read is the block parameter, which is what the comparison must isolate.
unpinned_raw_word_token :: Address -> Integer -> Web3 String
unpinned_raw_word_token manager pool_id = do
  calldata <- liftIO (encode_extsload (pool_state_slot pool_id))
  returned <-
    GlobalState.call
      Call
        { callFrom     = Nothing
        , callTo       = Just manager
        , callGas      = Nothing
        , callGasPrice = Nothing
        , callValue    = Nothing
        , callData     = Just calldata
        , callNonce    = Nothing
        }
      Latest
  pure (render_word_token (toBytes returned))

-- ---------------------------------------------------------------------------------------------
-- The capture
-- ---------------------------------------------------------------------------------------------

-- | One field's reading at one place, as it is recorded.
data Reading = Reading
  { r_field    :: PoolField
  , r_at       :: ReadAt
  , r_outcome  :: Either String Integer
  }

reading_json :: Reading -> Value
reading_json r = object
  [ "field"           .= pool_field_name (r_field r)
  -- NULL for an unpinned read, never a plausible height. The sentinel a reader cannot tell from a
  -- real number is the whole reason 'readback_height' is a Maybe.
  , "readback_height" .= readback_height (r_at r)
  , "refused"         .= either (const True) (const False) (r_outcome r)
  , "value"           .= either (const Nothing) (Just . show) (r_outcome r)
  , "refusal"         .= either Just (const Nothing) (r_outcome r)
  ]

main :: IO ()
main = do
  rig <- load_rig
  generated_at <- iso8601_utc_now
  generated_from <- trim <$> readFile import_ref_path
  endpoint <- resolve_endpoint

  let addrs = rig_addrs rig
      pool  = rig_pool addrs
      must what = either (error . (("chain-read-conformance: " ++ what ++ ": ") ++)) id
      manager = must "PoolManager" (resolve_contract rig "PoolManager")
      pool_id = must "pool.poolId" (hex_to_integer "pool.poolId" (rig_pool_id pool))
      manifest_chain_id = rig_chain_id addrs

  outcome <- runWeb3' (HttpProvider endpoint) (capture rig manager pool_id manifest_chain_id)
  case outcome of
    Left err -> do
      putStrLn ("CAPTURE FAIL: the chain did not answer, or a call failed: " ++ show err)
      putStrLn "              Stand the rig up first: bash offchain/rig/deploy-rig.sh"
      exitFailure
    Right doc -> do
      write_json_atomically output_path
        (object
          [ "schemaVersion"  .= (1 :: Integer)
          , "generatedAt"    .= generated_at
          , "generatedFrom"  .= generated_from
          , "chainId"        .= manifest_chain_id
          , "poolManager"    .= must "PoolManager" (contract_address rig "PoolManager")
          , "poolId"         .= rig_pool_id pool
          , "note"           .= provenance_note
          , "measurements"   .= doc
          ])
      putStrLn ("wrote " ++ output_path)

capture :: Rig -> Address -> Integer -> Integer -> Web3 [Value]
capture _rig manager pool_id manifest_chain_id = do
  live_chain_id <- unQuantity <$> eth_chain_id
  when (live_chain_id /= manifest_chain_id) $
    fail ("chain-read-conformance: the chain answering is id " ++ show live_chain_id
           ++ " and the manifest describes id " ++ show manifest_chain_id
           ++ ". Refusing BEFORE the first state-changing call: a write aimed at the wrong chain is"
           ++ " not recoverable by noticing afterwards, and every address below comes from that"
           ++ " manifest.")

  b <- (toInteger . unQuantity) <$> GlobalState.blockNumber
  let ref_b = AtBlock b

  -- (1) The value at b, read BEFORE anything changes. This is the reading everything else is
  --     compared against, and it is taken through the layer under test.
  before <- read_pool_field manager pool_id PoolStateWord ref_b
  word_before <- case before of
    Left why -> fail ("chain-read-conformance: the pool's state word was REFUSED at the head"
                       ++ " before any change was made, so there is nothing to construct a"
                       ++ " divergence from: " ++ why)
    Right w -> pure w

  -- (2) MINE, BEFORE THE WRITE. This line is the whole correction of 27-02's first capture, and it
  --     is here because the first attempt WITHOUT it recorded pinned_equals_block_b = false and
  --     looked exactly like a broken pin.
  --
  --     MEASURED at 27-02 with cast, independently of this program:
  --
  --       b = 19, head = 19
  --       anvil_setStorageAt(slot, 0x..42) ; evm_mine x3
  --       cast storage --block 19  ->  0x..42          <-- THE WRITE LANDED IN BLOCK 19's STATE
  --       cast storage --block 18  ->  the old word    <-- and nowhere below it
  --
  --     anvil_setStorageAt does not create a block. It writes into the state OF THE CURRENT HEAD,
  --     so a read pinned at the head is not isolated from it -- not because the pin fails to reach
  --     the node, but because there is no earlier state for that height to return. The pin was
  --     never broken: the same program reads block 0 and gets the bare 0x marker back, which it
  --     could only do if the block parameter were being honoured.
  --
  --     Mining first makes b strictly BELOW the head the write lands on, and the same experiment
  --     re-run that way keeps b's word intact while the head's changes. CONFIRMED before this line
  --     was written, not after.
  _ <- evm_mine
  write_head <- (toInteger . unQuantity) <$> GlobalState.blockNumber

  -- (3) THE STATE CHANGE. The tick field of the pool's own Slot0 word, replaced.
  let new_word = with_tick word_before divergence_tick
      slot     = pool_state_slot pool_id
  when (new_word == word_before) $
    fail ("chain-read-conformance: the constructed word equals the current one, so the state"
           ++ " would not change and the capture would record a divergence that does not exist."
           ++ " The pool is already at tick " ++ show divergence_tick ++ ", which means this"
           ++ " capture has already run against this rig. It is NOT idempotent -- it writes"
           ++ " storage -- so stand a fresh rig up first: bash offchain/rig/deploy-rig.sh")
  when (write_head <= b) $
    fail ("chain-read-conformance: the head is " ++ show write_head ++ " and the pinned height is "
           ++ show b ++ ". The write must land STRICTLY ABOVE the pinned block or it lands IN it,"
           ++ " and the capture would record a broken pin that is really a broken construction.")
  _ <- anvil_set_storage_at manager (fromString (hex32 slot)) (fromString (hex32 new_word))

  -- (4) Mine again, so the changed state is several blocks above b rather than one.
  mapM_ (const evm_mine) [1 .. blocks_mined]
  after_height <- (toInteger . unQuantity) <$> GlobalState.blockNumber

  -- (5) The pinned read, made again, at the same height, AFTER the change.
  pinned_after <- read_pool_field manager pool_id PoolStateWord ref_b
  -- (6) The control: no pin, raw transport.
  unpinned_token <- unpinned_raw_word_token manager pool_id
  let unpinned_value = token_to_integer unpinned_token

  -- Every field, read pinned at b, so the artifact records the whole surface and not one word.
  per_field <- mapM (\f -> Reading f (Pinned ref_b) <$> read_pool_field manager pool_id f ref_b)
                    pool_fields

  -- (7) WHERE THE POOL APPEARS. The same read, made at every height from 0 up to b, so the artifact
  --     records the block at which it stops being refused rather than one hand-picked height.
  --
  --     This is the strongest available statement that the block parameter is honoured, and it is
  --     stronger than the divergence above on its own: the divergence needs a state change to
  --     exist, while this needs only the chain's own history, and a pin that were being ignored
  --     would return the live word at every one of these heights.
  scan <- mapM (\h -> (,) h <$> probe_at manager pool_id (AtBlock h)) [0 .. b]
  let refused_below = [(h, tok, out) | (h, (tok, out)) <- scan, is_left out]
      readable      = [h | (h, (_, out)) <- scan, not (is_left out)]
      first_ok      = case readable of
                        (h : _) -> Just h
                        []      -> Nothing
      names_field w = refusal_naming PoolStateWord `isInfixOf` w
      sample h = case [(t, o) | (h', (t, o)) <- scan, h' == h] of
        ((t, o) : _) -> object
          [ "block"           .= h
          , "token"           .= t
          , "refused"         .= is_left o
          , "refusal"         .= either Just (const Nothing) o
          , "names_the_field" .= either names_field (const False) o
          ]
        [] -> object ["block" .= h, "token" .= ("<not scanned>" :: String)]

  pure
    [ object
        [ "name"                  .= ("pinned_read_survives_a_state_change" :: String)
        , "block_b"               .= b
        , "write_head"            .= write_head
        , "block_after"           .= after_height
        , "blocks_mined"          .= blocks_mined
        , "state_change"          .= state_change_note
        , "value_at_b_before"     .= show word_before
        , "pinned_value"          .= either (const Nothing) (Just . show) pinned_after
        , "pinned_refusal"        .= either Just (const Nothing) pinned_after
        , "unpinned_value"        .= fmap show unpinned_value
        , "pinned_readback_height"   .= readback_height (Pinned ref_b)
        , "unpinned_readback_height" .= readback_height Unpinned
        , "pinned_equals_block_b" .= (pinned_after == Right word_before)
        -- TWO different claims, and neither implies the other. The first says the CHAIN moved --
        -- without it the capture proves nothing, because a pinned read agreeing with itself on a
        -- chain that did not change is not evidence about pinning. The second says the two READS
        -- disagree, which is the thing CHAIN-02 is actually about. A capture where the chain moved
        -- but both reads followed it would satisfy the first and fail the second, and that is
        -- exactly the defect.
        , "unpinned_differs"      .= (unpinned_value /= Just word_before)
        , "pinned_and_unpinned_disagree" .= (fmap Right unpinned_value /= Just pinned_after)
        , "write_landed_above_b"  .= (write_head > b)
        , "block_advanced"        .= (after_height > b)
        ]
    , object
        [ "name"            .= ("every_field_pinned_at_block_b" :: String)
        , "block_b"         .= b
        , "readings"        .= map reading_json per_field
        ]
    , object
        [ "name"                    .= ("the_pin_locates_the_block_the_pool_appeared" :: String)
        , "blocks_scanned"          .= (b + 1)
        , "first_readable_block"    .= first_ok
        , "refused_below_count"     .= length refused_below
        , "all_below_refused"       .= all (\h -> h `notElem` readable)
                                           [0 .. maybe b (subtract 1) first_ok]
        , "all_below_name_the_field" .= all (\(_, _, o) -> either names_field (const False) o)
                                            refused_below
        -- Two SAMPLES rather than the whole scan. The counts above are the claim; these two rows
        -- are so the refusal TEXT is in the artifact and readable by a person. Block 0 is the
        -- manager before it has code; the block just below the first readable one is the manager
        -- with code and no pool, and the two produce DIFFERENT diagnoses -- which is the point of
        -- keeping four failure shapes apart in decode_word_token.
        , "at_genesis"              .= sample 0
        , "just_below_first_readable" .= maybe (object []) (sample . subtract 1) first_ok
        ]
    ]
  where
    is_left = either (const True) (const False)
    probe_at manager' pool_id' ref = do
      tok <- read_raw_word_token manager' pool_id' PoolStateWord ref
      out <- read_pool_field manager' pool_id' PoolStateWord ref
      pure (tok, out)

-- | Replace the @tick@ field (bits [160,184)) of a @Slot0@ word.
--
-- The other three fields are preserved BY CONSTRUCTION rather than by remembering to, which is the
-- same argument @CheatSwap.Types.compose_slot0@'s mask at 184 makes: a capture that also moved the
-- price would leave @unpinned_differs@ true for two reasons at once and the artifact could not say
-- which read moved.
with_tick :: Integer -> Integer -> Integer
with_tick word tick =
  (word .&. complement mask) .|. ((tick .&. ((1 `shiftL` 24) - 1)) `shiftL` 160)
  where
    mask = ((1 `shiftL` 24) - 1) `shiftL` 160

-- | The token back to a number, or 'Nothing' if it is not one -- which is itself recordable.
token_to_integer :: String -> Maybe Integer
token_to_integer ('0' : 'x' : payload)
  | not (null payload), all (`elem` ("0123456789abcdefABCDEF" :: String)) payload =
      Just (foldl (\acc c -> acc * 16 + toInteger (hexval c)) 0 payload)
  where
    hexval c
      | c >= '0' && c <= '9' = fromEnum c - fromEnum '0'
      | c >= 'a' && c <= 'f' = fromEnum c - fromEnum 'a' + 10
      | otherwise            = fromEnum c - fromEnum 'A' + 10
token_to_integer _ = Nothing

state_change_note :: String
state_change_note =
  "anvil_setStorageAt on the pool's own Slot0 slot, tick field (bits [160,184)) set to "
    ++ show divergence_tick
    ++ ". The other three fields of the word are preserved by the mask, so the divergence has"
    ++ " exactly one cause."

provenance_note :: String
provenance_note =
  "Every value here was produced by offchain/app/ChainReadConformance.hs against the live rig stood"
    ++ " up by offchain/rig/deploy-rig.sh. Nothing was transcribed. The pinned readings are made"
    ++ " through Chain.Read, which cannot express an unpinned read; the unpinned control is made"
    ++ " from the raw transport in that program's own source, where it is visible as a control."
    ++ " The endpoint is deliberately NOT recorded: it is the output of one rule stated once per"
    ++ " language (Chain.Endpoint and offchain/rig/endpoint.sh), and an artifact carrying the"
    ++ " authority would be a third statement of it inside the endpoint census's blast radius."
    ++ " chainId is recorded instead and is asserted against the manifest's before any write."

iso8601_utc_now :: IO String
iso8601_utc_now = do
  raw <- trim <$> readProcess "date" ["-u", "+%Y-%m-%dT%H:%M:%SZ"] ""
  unless (length raw == 20) $
    error ("chain-read-conformance: date produced " ++ show raw ++ ", not an ISO-8601 UTC stamp")
  pure raw

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
