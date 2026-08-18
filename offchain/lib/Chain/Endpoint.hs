-- | THE ONE PLACE THE CHAIN'S ADDRESS IS DECIDED.
--
-- CHAIN-06 says "nine sites, one rule". MEASURED at 27-01, by @git grep@ over @offchain\/@ for
-- the variable name or the default authority: __TEN__ files, not nine. The tenth is
-- @offchain\/spec\/types.md@, a pasted RPC transcript, and it is listed in 'endpoint_sites' as a
-- 'Transcript' rather than argued away -- see 'SiteKind' for the ruling and what it costs.
--
-- == WHAT WAS ACTUALLY WRONG BEFORE THIS MODULE
--
-- Not "the rule was implemented N times". MEASURED at 27-01: the rule was implemented __ZERO__
-- times. The only occurrence of the variable name anywhere under @offchain\/@ was a COMMENT in
-- @offchain\/rig\/deploy-rig.sh@ explaining that the deploy scripts scrub it. Every one of the
-- nine executable sites wrote the default authority out as a literal and read no environment at
-- all, so @ETH_RPC_URL=...:9545@ was accepted by the shell, ignored by every consumer, and the
-- run went to 8545. There was no drift between N copies to reconcile; there was one hardcoded
-- constant, nine times.
--
-- == WHY THE PRODUCER IS IN THE SAME MANIFEST AS THE CONSUMERS
--
-- CHAIN-07's own words: /a consumer-only resolver does NOT retire the requirement/. A resolver
-- that only the readers honour leaves @deploy-rig.sh@ free to start anvil on 8545 while the reads
-- attach to 9545 -- the endpoint is then agreed among everyone who cannot start a chain, which is
-- the precise divergence issue #29 was opened to prevent. So the script that OWNS anvil is a site
-- here, with its own 'SiteKind', and the census that reads this manifest asserts it derives the
-- host and the port it starts on from the same value the readers resolve.
--
-- == WHY THE SHELL HALF IS A SECOND FILE AND NOT A THIRD, FOURTH AND FIFTH COPY
--
-- Three of the ten sites are @bash@ and cannot import this module. The alternatives were: spell
-- @${ETH_RPC_URL:-...}@ inline in each of the three (four statements of the default, three of them
-- unchecked), or write the shell half ONCE in 'shell_resolver' and have the three source it. The
-- second is what shipped. It leaves the default authority written down in exactly TWO places, in
-- two languages, and the census asserts they are byte-equal -- the move this repository already
-- makes for the pip denominator, where @Fee.Split@ and @Store.Key@ each name it and a check
-- asserts the two agree. A duplication that a check compares is a checked agreement; a
-- duplication that nothing compares is the defect.
--
-- == WHY THE ALIAS COULD NOT BE THE MECHANISM
--
-- @deploy-rig.sh@ used to reach the chain through foundry's @--rpc-url local@, resolved by
-- @foundry.toml:59@ to @local = \"http:\/\/127.0.0.1:8545\"@. That is a THIRD statement of the
-- default -- and @foundry.toml@ is outside this workstream's territory, so it cannot be made to
-- honour the variable. Binding the producer through the alias would therefore have pinned it to
-- 8545 by construction no matter what the resolver returned. The producer now passes the resolved
-- URL to @forge@ and @cast@ directly and the alias is unused by the rig.
--
-- == WHAT THIS MODULE DOES NOT DO
--
-- It does not reach the chain, open a socket, or validate that anything is listening. It returns a
-- 'String'. Whether that authority answers is the caller's measurement, and every consumer already
-- reports its own RPC failure.
module Chain.Endpoint
  ( SiteKind (..)
  , EndpointSite (..)
  , endpoint_env_var
  , default_endpoint
  , resolve_endpoint
  , shell_resolver
  , endpoint_sites
  , site_paths
  ) where

import System.Environment (lookupEnv)

-- | The variable, written down ONCE.
--
-- Named here rather than spelled at each @lookupEnv@ for the reason @Store.Config@ and
-- @Gams.Config@ name theirs: the constant is what a census can compare against, and a variable
-- that is spelled at its use sites is a variable a rename can leave half-honoured.
endpoint_env_var :: String
endpoint_env_var = "ETH_RPC_URL"

-- | The authority every site falls back to, written down ONCE on the Haskell side.
--
-- This is the ONE place in the Haskell tree where this literal may appear, and the census asserts
-- exactly that: every other site names 'resolve_endpoint' instead. 'shell_resolver' holds the
-- other permitted copy, and the two are asserted byte-equal.
default_endpoint :: String
default_endpoint = "http://127.0.0.1:8545"

-- | @ETH_RPC_URL@ if it is set AND NON-EMPTY, else 'default_endpoint'.
--
-- == THE NON-EMPTY HALF IS NOT DEFENSIVE PROGRAMMING
--
-- @lookupEnv@ returns @Just ""@ for an exported-but-empty variable, and the obvious
-- @fromMaybe default_endpoint \<$\> lookupEnv ...@ therefore resolves an empty export to the
-- EMPTY STRING. This repository has measured what that costs six separate times, always in the
-- same shape: an empty value flows onward, is compared against another empty value, @\"\" == \"\"@
-- is true, and the run exits 0 having verified nothing. @deploy-rig.sh@ carries the narrative for
-- the closest instance -- an empty @import-ref.txt@ wrote an empty @generatedFrom@ into the
-- manifest and every downstream freshness check then compared one empty string to another.
--
-- Here the empty value would not even be silently wrong: @HttpProvider \"\"@ is a request to an
-- empty authority. But an operator who ran @export ETH_RPC_URL=@ and got a connection error would
-- be told the chain refused, when what happened is that this function agreed to an address nobody
-- asked for. An empty export means "I did not supply one", and this returns the default.
--
-- No trimming, and that is a decision rather than an omission: @\" \"@ is not empty, and a
-- resolver that silently repaired whitespace would be quietly interpreting an operator's input.
-- A value with a space in it reaches the provider and the provider says so.
resolve_endpoint :: IO String
resolve_endpoint = do
  supplied <- lookupEnv endpoint_env_var
  pure $ case supplied of
    Just value | not (null value) -> value
    _                             -> default_endpoint

-- | The shell half of the SAME resolver, sourced by every @bash@ site.
--
-- A path rather than a body, because @bash@ cannot import a Haskell module and a Haskell module
-- must not try to be a shell library. What binds the two is the census: that file states the
-- default once, and the check asserts the literal it states is byte-equal to 'default_endpoint'.
shell_resolver :: FilePath
shell_resolver = "offchain/rig/endpoint.sh"

-- | What kind of thing a site is, and therefore which half of the rule applies to it.
--
-- The kind is not decoration -- it is what stops the census from being either vacuous or wrong.
-- Applying "must name the resolver" to the transcript would fail a document that is evidence, and
-- applying "must not hold the literal" to the resolver itself would fail the one file that is
-- supposed to hold it. A single undifferentiated list has to be relaxed on its first run, and a
-- rule relaxed on its first run is a rule nobody enforces afterwards.
data SiteKind
  = HaskellResolver
    -- ^ This module. Holds the literal; must be the only Haskell file that does.
  | ShellResolver
    -- ^ 'shell_resolver'. Holds the literal too, and its copy is asserted equal to this one's.
  | HaskellConsumer
    -- ^ Builds a @Provider@. Must obtain the authority from 'resolve_endpoint' and hold no
    -- literal.
  | ShellConsumer
    -- ^ Reads the chain from @bash@. Must source 'shell_resolver' and hold no literal.
  | ShellProducer
    -- ^ STARTS the chain. Must source 'shell_resolver' and bind the host AND the port it starts
    -- anvil on from the resolved value -- the half CHAIN-07 says a consumer-only resolver leaves
    -- open.
  | Transcript
    -- ^ Prose or a recorded RPC session. Reads nothing and starts nothing.
    --
    -- @offchain\/spec\/types.md@ is the only member and it is here DELIBERATELY. It is not a
    -- consumer and the resolver rule does not apply to it, but it is inside the census grep's
    -- blast radius, and a file inside a grep's radius that the grep's list does not know about is
    -- how a scan gets narrowed on the day it first fires. Twenty-five instances of prose caught by
    -- a pattern are on record on this branch, and the answer every time was to move or declare the
    -- prose, never to relax the pattern. So it is DECLARED, and what is asserted about it is
    -- exactly what is true of it: it exists, and it is known.
    --
    -- @offchain\/rig\/README.md@ is NOT here, and that is a measurement rather than an oversight:
    -- it names neither the variable nor the authority today. If it ever does, the census's
    -- unlisted arm names it.
  deriving (Eq, Show)

-- | One site: where it is, what it is, and why it is that.
data EndpointSite = EndpointSite
  { site_path :: FilePath
  , site_kind :: SiteKind
  , site_note :: String
  }

-- | THE MANIFEST. Twelve entries: ten measured sites plus the two resolvers.
--
-- The ten were MEASURED at 27-01, not inherited from CHAIN-06's count of nine:
--
-- > git grep -l -e 'ETH_RPC_URL' -e '127\.0\.0\.1:8545' -- offchain | wc -l
-- > 10
--
-- and the same command over the whole tracked tree printed 34, the other 24 being planning
-- documents, historical @docs\/superpowers\/@ plans, @foundry.toml@, a workflow and a Solidity
-- test -- none of them under this workstream's territory and none of them a consumer. The census
-- is therefore scoped to @offchain\/@, and that scope is asserted rather than assumed: the check
-- that reads this list enumerates every file under @offchain\/@ with NO extension filter, so a
-- new site of any type is named on the day it lands.
--
-- BOTH DIRECTIONS, and the second one is the one that matters. A list compared only against what
-- the tree holds still passes when the tree grows past it; a list compared only against itself
-- passes when a file it names is deleted. 23-03 measured the cost of the first shape -- a storage
-- module sat unlisted for two commits with nothing red.
endpoint_sites :: [EndpointSite]
endpoint_sites =
  [ EndpointSite "offchain/lib/Chain/Endpoint.hs" HaskellResolver
      "This module. States the variable and the default once each, for the whole Haskell tree."
  , EndpointSite "offchain/rig/endpoint.sh" ShellResolver
      "The shell half. States the default once for the three bash sites, and splits the resolved\
      \ URL into the host and port the producer needs. Its copy of the default is asserted\
      \ byte-equal to this module's."
  , EndpointSite "offchain/lib/PriceSetter/Rpc.hs" HaskellConsumer
      "write_price_and_report builds the Provider it runs the slot0 cheat through."
  , EndpointSite "offchain/lib/VolOrder/Rpc.hs" HaskellConsumer
      "create_order_and_report builds the Provider the order transaction is sent through."
  , EndpointSite "offchain/lib/StochasticOrderGen/Rpc.hs" HaskellConsumer
      "run_order_gen_and_report builds the Provider the batched orders are sent through."
  , EndpointSite "offchain/lib/StochasticPriceGen/Rpc.hs" HaskellConsumer
      "run_price_gen_and_report builds the Provider the simulated path is written through."
  , EndpointSite "offchain/app/Main.hs" HaskellConsumer
      "The demo driver. One Provider for the whole run, resolved before the capture is armed so a\
      \ resolution failure cannot leave a half-written artifact."
  , EndpointSite "offchain/app/CheatSwapProof.hs" HaskellConsumer
      "The cheat-swap capture. Its provider was a top-level pure value; it is now an IO action,\
      \ because a resolver that runs before main does is a resolver the environment cannot reach."
  , EndpointSite "offchain/rig/capture-batch-return.sh" ShellConsumer
      "Captures the empty-batch return shape with cast against a standing rig."
  , EndpointSite "offchain/rig/capture-cheat-swap-proof.sh" ShellConsumer
      "Captures the cheat-swap proof with cast against a standing rig."
  , EndpointSite "offchain/rig/deploy-rig.sh" ShellProducer
      "The PRODUCER. Owns anvil: kills the stale listener on the resolved port, starts the chain\
      \ on the resolved host and port, and passes the resolved URL to every forge and cast\
      \ invocation. CHAIN-07 is the half that a consumer-only resolver leaves open."
  , EndpointSite "offchain/spec/types.md" Transcript
      "A pasted RPC transcript kept as evidence. Reads nothing, starts nothing, and is listed so\
      \ the census over offchain/ is CLOSED rather than quietly narrowed around it."
  ]

-- | The manifest's paths, in the order it declares them.
site_paths :: [FilePath]
site_paths = map site_path endpoint_sites
