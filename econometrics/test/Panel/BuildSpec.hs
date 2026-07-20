{-# LANGUAGE OverloadedStrings #-}

-- | Fixture-driven tests for the panel assembler (CTX-PANEL, plan 09-04).
--
-- Exercises the three load-bearing behaviours against the frozen subgraph
-- response @test/fixtures/subgraph-sample.json@:
--
--   1. cumulative @premiaSettledInUsdTotal@ diffs to the correct per-epoch delta
--      (π_it is a FLOW, never the raw cumulative — RESEARCH Pitfall 2);
--   2. i_K = round(log strike / log 1.0001) on the λ=1.0001 grid (PosSpec.lam);
--   3. one panel row per (tokenId, epoch): N daily snapshots yield N−1 rows.
module Panel.BuildSpec (spec) where

import qualified Data.ByteString.Lazy as BL
import           Data.List            (sortOn)
import           Test.Hspec

import           Econ.Types           (obsPremium, obsStrikeTick, obsTokenId)
import           Panel.Build          (assemble, deltaPremia, strikeToTick)
import           Panel.Subgraph       (RawPosition (..), parsePositions)

fixturePath :: FilePath
fixturePath = "test/fixtures/subgraph-sample.json"

loadPositions :: IO [RawPosition]
loadPositions = do
  bytes <- BL.readFile fixturePath
  case parsePositions bytes of
    Left err -> error ("fixture parse failed: " ++ err)
    Right ps -> pure ps

byId :: String -> [RawPosition] -> RawPosition
byId tid ps =
  case filter ((== tid) . show . rpTokenId) ps of
    (p : _) -> p
    []      -> error ("tokenId not in fixture: " ++ tid)

spec :: Spec
spec = describe "Panel.Build (CTX-PANEL)" $ do

  it "diffs cumulative premia into per-epoch flows (not the raw cumulative)" $ do
    ps <- loadPositions
    let posA   = byId "\"0xa1\"" ps
        deltas = map snd (deltaPremia (rpSnapshots posA))
    -- cumulative 100 -> 130 -> 175  ==>  flows 30, 45  (NOT 130, 175)
    deltas `shouldBe` [30.0, 45.0]

  it "emits epochs in ascending order aligned to the ENDING snapshot" $ do
    ps <- loadPositions
    let posA    = byId "\"0xa1\"" ps
        epochs  = map fst (deltaPremia (rpSnapshots posA))
    epochs `shouldBe` sortOn id epochs
    length epochs `shouldBe` 2

  it "maps strike price to the λ=1.0001 tick (i_K = round(log K / log 1.0001))" $ do
    strikeToTick 1.05 `shouldBe` 488
    strikeToTick 0.97 `shouldBe` (-305)

  it "emits N−1 rows for a tokenId with N daily snapshots" $ do
    ps <- loadPositions
    let panel     = assemble ps
        rowsFor t = length (filter ((== t) . obsTokenId) panel)
    -- 0xa1 has 3 snapshots -> 2 rows ; 0xb2 has 2 snapshots -> 1 row
    rowsFor "0xa1" `shouldBe` 2
    rowsFor "0xb2" `shouldBe` 1
    length panel   `shouldBe` 3

  it "carries the strike tick onto assembled rows" $ do
    ps <- loadPositions
    let panel = assemble ps
        tickA = map obsStrikeTick (filter ((== "0xa1") . obsTokenId) panel)
    tickA `shouldBe` [488, 488]

  it "assembled premia are the per-epoch flows for 0xb2" $ do
    ps <- loadPositions
    let panel = assemble ps
        premB = map obsPremium (filter ((== "0xb2") . obsTokenId) panel)
    premB `shouldBe` [40.0]
