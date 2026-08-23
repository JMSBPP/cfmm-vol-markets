-- |
-- THE ONE MODULE IN THE LOOP LAYER THAT NAMES THE TRANSPORT.
--
-- It builds a 'Loop.Poll.ChainSource' out of a resolved endpoint and the three addresses the
-- filter needs. Everything else in @offchain\/lib\/Loop\/@ takes that record as an argument and is
-- therefore drivable with no node, which is what lets LOOP-01's restart proof exist at all: the
-- check controls what the chain did while the loop was down, because the check IS the chain.
--
-- It is imported by @offchain\/app\/LoopMain.hs@ and by nothing under @offchain\/test\/@, and it
-- is listed in 'Chain.Endpoint.endpoint_sites' as a consumer. That listing is not bookkeeping: the
-- census reads the manifest against the tree in BOTH directions, so a new file that reaches a
-- chain and is not listed is a failure naming it.
--
-- WHERE A TRANSPORT FAILURE GOES
-- ------------------------------
-- Every action below raises when the provider answers with an error, naming the endpoint and the
-- call. It does not return a 'Left', and that is a decision rather than an omission: the four
-- 'Loop.Poll.ChainSource' fields whose answers are the loop's INPUT have no truthful value to
-- return when the chain did not answer, and a source that handed back a zero head would be
-- reporting a chain with no blocks. 28-CONTEXT's bounded-retry-then-halt policy is the caller's,
-- and its exit code -- @halt_rpc_exhausted@ -- is already in 'Loop.Config.exit_table' with no
-- producer yet, for the reason that table's header gives.
--
-- The reads are the exception: 'Chain.Read' already answers @Either String Integer@ with a refusal
-- that names the field, and collapsing that into an exception would throw away the one diagnosis
-- 27-02 exists to produce.
module Loop.Chain
  ( web3_chain_source
  , resolved_chain_source
  ) where

import Control.Exception (throwIO)
import Data.Solidity.Prim.Address (Address)

import qualified Network.Ethereum.Api.Eth as GlobalState
import Network.Ethereum.Api.Types (Filter (..))
import Network.Web3.Provider (Provider (HttpProvider), Web3, runWeb3')

import Chain.Endpoint (resolve_endpoint)
import Chain.Read (BlockRef, read_liquidity, read_lp_fee, read_sqrt_price_x96)
import Loop.Poll (ChainSource (..), shock_filter_fields)

-- | A source over a live node.
--
-- The four arguments are the resolved endpoint, the pool manager the reads go through, the
-- contract the @Shock@ logs must be EMITTED by, and that event's topic0. The last two are separate
-- because an event topic is unauthenticated -- any contract can emit any topic0 with any word in
-- topic 1 -- and the emitter is the only thing that says the log came from the writer this loop
-- was pointed at.
web3_chain_source :: String -> Address -> Address -> Integer -> ChainSource
web3_chain_source endpoint pool_manager emitter topic0 =
  ChainSource
    { source_label = "Loop.Chain over " ++ endpoint
    , source_head =
        toInteger <$> run "eth_blockNumber" GlobalState.blockNumber
    , source_logs = \from to ->
        let (addresses, from_block, to_block, topics) =
              shock_filter_fields emitter topic0 from to
            request :: Filter ()
            request = Filter
              { filterAddress   = addresses
              , filterFromBlock = from_block
              , filterToBlock   = to_block
              , filterTopics    = topics
              }
        in run "eth_getLogs" (GlobalState.getLogs request)
    , source_reads = \pool_id ref -> run "the pinned pool reads" (pool_triple pool_id ref)
    , source_chain_id =
        toInteger <$> run "eth_chainId" GlobalState.chainId
    }
  where
    run :: String -> Web3 a -> IO a
    run label action = do
      answered <- runWeb3' (HttpProvider endpoint) action
      case answered of
        Right value -> pure value
        Left why ->
          throwIO . userError $
            "Loop.Chain: " ++ label ++ " was not answered by " ++ endpoint ++ " -- " ++ show why

    -- The three fields, every one of them PINNED at the same height, in one round trip through the
    -- provider. Read together rather than one call at a time because they describe ONE state: a
    -- triple assembled from three separately-opened sessions could straddle a re-org and produce a
    -- price from one block and a liquidity from another, with nothing in the result saying so.
    pool_triple :: Integer -> BlockRef -> Web3 (Either String (Integer, Integer, Integer))
    pool_triple pool_id ref = do
      price     <- read_sqrt_price_x96 pool_manager pool_id ref
      liquidity <- read_liquidity pool_manager pool_id ref
      fee       <- read_lp_fee pool_manager pool_id ref
      pure ((,,) <$> price <*> liquidity <*> fee)

-- | The endpoint, RESOLVED, and a source over it -- in that order and in one place.
--
-- The resolved authority is returned alongside the source rather than swallowed, so the caller can
-- report which chain it attached to without resolving a SECOND time. Two resolutions in one
-- process are two answers that can differ, and the one that gets reported would be the one nobody
-- used.
--
-- This is where the loop's endpoint comes from, and the reason it is here rather than in the
-- executable is the census's own rule: a Haskell site that builds a provider must obtain the
-- authority from the resolver and hold no literal. 'web3_chain_source' is kept separate and takes
-- the authority as an argument so the wiring stays a pure function of it.
resolved_chain_source :: Address -> Address -> Integer -> IO (String, ChainSource)
resolved_chain_source pool_manager emitter topic0 = do
  endpoint <- resolve_endpoint
  pure (endpoint, web3_chain_source endpoint pool_manager emitter topic0)
