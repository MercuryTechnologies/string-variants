{-# LANGUAGE QuasiQuotes #-}

module Specs.TextManipulationSpec (spec) where

import Data.Char
import Data.StringVariants.NonEmptyText
import Test.Hspec
import Prelude

spec :: Spec
spec = describe "Text manipulation" do
  describe "filterNonEmptyText" $ do
    it "filterNonEmptyText returns Nothing when filtered string is empty" do
      filterNonEmptyText (const False) [compileNonEmptyTextKnownLength|abc|] `shouldBe` Nothing

    it "filterNonEmptyText returns Nothing when filtered string only has spaces" do
      filterNonEmptyText isSpace [compileNonEmptyTextKnownLength|a b|] `shouldBe` Nothing

    it "filterNonEmptyText returns stripped text" do
      filterNonEmptyText (/= 'a') [compileNonEmptyTextKnownLength|a b a|] `shouldBe` Just (widen [compileNonEmptyTextKnownLength|b|])

  describe "takeNonEmptyText" $ do
    it "takeNonEmptyText returns stripped text" do
      -- taking two characters results in a trailing space
      takeNonEmptyText [compileNonEmptyTextKnownLength|a b|] `shouldBe` (widen [compileNonEmptyTextKnownLength|a|] :: NonEmptyText 2)

  describe "takeNonEmptyTextEnd" $ do
    it "takeNonEmptyTextEnd returns stripped text" do
      -- taking two characters results in a leading space
      takeNonEmptyTextEnd [compileNonEmptyTextKnownLength|a b|] `shouldBe` (widen [compileNonEmptyTextKnownLength|b|] :: NonEmptyText 2)

  describe "chunksOfNonEmptyText" $ do
    it "chunksOfNonEmptyText drops empty chunks" $ do
      chunksOfNonEmptyText [compileNonEmptyTextKnownLength|a   b|]
        `shouldBe` ([[compileNonEmptyTextKnownLength|a|], [compileNonEmptyTextKnownLength|b|]] :: [NonEmptyText 1])
    it "chunksOfNonEmptyText strips chunks" $ do
      chunksOfNonEmptyText [compileNonEmptyTextKnownLength|a   b|]
        `shouldBe` ([widen [compileNonEmptyTextKnownLength|a|], widen [compileNonEmptyTextKnownLength|b|]] :: [NonEmptyText 2])
