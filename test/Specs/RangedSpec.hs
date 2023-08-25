{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}

module Specs.RangedSpec (spec) where

import Data.Maybe
import Data.Text (Text)
import Data.Text qualified as T
import Data.StringVariants.RangedText
import Data.StringVariants.NullableRangedText
import Data.StringVariants.Util (usePositiveNat)
import GHC.TypeLits
import Hedgehog
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Language.Haskell.TH.Quote (QuasiQuoter (quoteExp))
import Prelude
import Test.Hspec
import Test.Hspec.Hedgehog (hedgehog)

mkRangedText299 :: Text -> Maybe (RangedText 299)
mkRangedText299 = mkRangedText

maybeTextToTruncateNullableRangedText299 :: Maybe Text -> NullableRangedText 299
maybeTextToTruncateNullableRangedText299 = maybeTextToTruncateNullableRangedText

mkRangedText299WithTruncate :: Text -> Maybe (RangedText 299)
mkRangedText299WithTruncate = mkRangedTextWithTruncate

matchLength :: proxy (n :: Nat) -> other n -> other n
matchLength _ = id

spec :: Spec
spec = describe "RangedText variants" $ do
  describe "RangedText299" $ do
    describe "compileRangedText" $ do
      it "should work" $ do
        mkRangedText299 "hi" `shouldBe` Just (widen [compileRangedTextKnownLength|hi|])
    describe "compileNullableRangedText" $ do
      it "should work" $ do
        $(quoteExp (compileNullableRangedText 2) "yo") `shouldBe` NullableRangedText (Just [compileRangedTextKnownLength|yo|])
    describe "rangedTextToText" $ do
      it "should work" $ do
        rangedTextToText [compileRangedTextKnownLength|yo|] `shouldBe` "yo"

  describe "Generalized RangedText" $ do
    describe "mkRangedText" $
      it "should work" $ do
        mkRangedText299 "" `shouldBe` Nothing
        mkRangedText299 " " `shouldBe` Nothing
        mkRangedText299 "\n" `shouldBe` Nothing
        mkRangedText299 "\t" `shouldBe` Nothing
        mkRangedText299 "\NUL" `shouldBe` Nothing
        mkRangedText299 "x" `shouldSatisfy` isJust

    describe "literalRangedText" $ do
      it "should work" $ do
        Just (literalRangedText @"abc def") `shouldBe` mkRangedText299 "abc def"

-- test cases for bad strings. Alas, the -fdefer-type-errors defers the errors but then happily creates invalid values in runtime. Is this a GHC bug?

      -- describe "rejects invalid strings" $ do
      --   it "rejects string too long" $ do
      --     print (literalRangedText @"abcdefghijkl" :: RangedText 10)
      --       `shouldThrow` (("Invalid RangedText. Needs to be <= 10 characters. Has 12 characters." `isInfixOf`) . show)
      --   it "rejects empty string" $ do
      --     print (literalRangedText @"" :: RangedText 10)
      --       `shouldThrow` (("Symbol is empty" `isInfixOf`) . show)
      --   it "rejects string with leading whitespace" $ do
      --     print (literalRangedText @" abc" :: RangedText 10)
      --       `shouldThrow` (("Symbol has leading whitespace" `isInfixOf`) . show)
      --   it "rejects string with trailing whitespace" $ do
      --     print (literalRangedText @"abc " :: RangedText 10)
      --       `shouldThrow` (("Symbol has leading whitespace" `isInfixOf`) . show)
      --   it "rejects string with leading unicode whitespace" $ do
      --     print (literalRangedText @"\x2000abc" :: RangedText 10)
      --       `shouldThrow` (("Symbol has leading whitespace" `isInfixOf`) . show)

    describe "maybeTextToTruncateNullableRangedText" $ do
      it "common behavior" $ do
        maybeTextToTruncateNullableRangedText299 Nothing `shouldBe` NullableRangedText Nothing
        maybeTextToTruncateNullableRangedText299 (Just "") `shouldBe` NullableRangedText Nothing
        maybeTextToTruncateNullableRangedText299 (Just " ") `shouldBe` NullableRangedText Nothing
      it "type-dependent behavior" $
        hedgehog $ do
          n <- forAll $ Gen.integral $ Range.constant 1 20000
          let n' = fromInteger n
          usePositiveNat n (pure ()) $ \p -> do
            let NullableRangedText mtext =
                  matchLength p $
                    maybeTextToTruncateNullableRangedText
                      (Just $ T.pack $ replicate (n' + 1) 'x')
            (T.length . rangedTextToText <$> mtext) === Just n'

    describe "mkRangedTextWithTruncate" $ do
      it "common behavior" $ do
        mkRangedText299WithTruncate "" `shouldBe` Nothing
        mkRangedText299WithTruncate " " `shouldBe` Nothing
      it "type-dependent behavior" $
        hedgehog $ do
          n <- forAll $ Gen.integral $ Range.constant 1 20000
          let n' = fromInteger n
          usePositiveNat n (pure ()) $ \(_ :: proxy n) -> do
            let mtext = mkRangedTextWithTruncate @n (T.pack $ replicate (n' + 1) 'x')
            (T.length . rangedTextToText <$> mtext) === Just n'
