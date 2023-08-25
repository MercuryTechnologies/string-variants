{-# LANGUAGE QuasiQuotes #-}

module Specs.RangedManipulationSpec (spec) where

import Data.Char
import Data.List.NonEmpty (NonEmpty (..))
import Data.StringVariants.RangedText
import Test.Hspec
import Prelude

spec :: Spec
spec = describe "Text manipulation" do
  describe "filterRangedText" $ do
    it "filterRangedText returns Nothing when filtered string is empty" do
      filterRangedText (const False) [compileRangedTextKnownLength|abc|] `shouldBe` Nothing

    it "filterRangedText returns Nothing when filtered string only has spaces" do
      filterRangedText isSpace [compileRangedTextKnownLength|a b|] `shouldBe` Nothing

    it "filterRangedText returns stripped text" do
      filterRangedText (/= 'a') [compileRangedTextKnownLength|a b a|] `shouldBe` Just (widen [compileRangedTextKnownLength|b|])

  describe "takeRangedText" $ do
    it "takeRangedText returns stripped text" do
      -- taking two characters results in a trailing space
      takeRangedText [compileRangedTextKnownLength|a b|] `shouldBe` (widen [compileRangedTextKnownLength|a|] :: RangedText 2)

  describe "takeRangedTextEnd" $ do
    it "takeRangedTextEnd returns stripped text" do
      -- taking two characters results in a leading space
      takeRangedTextEnd [compileRangedTextKnownLength|a b|] `shouldBe` (widen [compileRangedTextKnownLength|b|] :: RangedText 2)

  describe "chunksOfRangedText" $ do
    it "chunksOfRangedText drops empty chunks" $ do
      chunksOfRangedText [compileRangedTextKnownLength|a   b|]
        `shouldBe` ([compileRangedTextKnownLength|a|] :| [[compileRangedTextKnownLength|b|]] :: NonEmpty (RangedText 1))
    it "chunksOfRangedText strips chunks" $ do
      chunksOfRangedText [compileRangedTextKnownLength|a   b|]
        `shouldBe` (widen [compileRangedTextKnownLength|a|] :| [widen [compileRangedTextKnownLength|b|]] :: NonEmpty (RangedText 2))
