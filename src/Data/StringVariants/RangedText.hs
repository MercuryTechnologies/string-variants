{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

-- | RangedText: Text that is known not to be either the empty string, or pure
--   whitespace.

module Data.StringVariants.RangedText
  ( -- * Non empty text
    RangedText,
    type (<=),

    -- * Construction
    mkRangedText,
    mkRangedTextWithTruncate,
    literalRangedText,
    unsafeMkRangedText,
    compileRangedText,
    compileRangedTextKnownLength,
    convertEmptyTextToNothing,

    -- * Conversion
    widen,
    rangedTextToText,

    -- * Functions
    takeRangedText,
    takeRangedTextEnd,
    chunksOfRangedText,
    filterRangedText,
    (<>|),
    concatWithSpace,

    -- * Conversions between 'Refined' and 'RangedText'.
    ContainsNonWhitespaceCharacters (..),
    exactLengthRefinedToRange,
    rangedTextFromRefined,
    refinedFromRangedText,
  )
where

import Control.Monad
import Data.Data (Proxy (..), typeRep)
import Data.List.NonEmpty qualified as NE
import Data.Maybe (mapMaybe)
import Data.StringVariants.RangedText.Internal
import Data.StringVariants.Util
import Data.Text (Text)
import Data.Text qualified as T
import GHC.Generics (Generic)
import GHC.TypeLits (KnownNat, KnownSymbol, Symbol, Nat, natVal, symbolVal, type (+), type (<=))
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax (Lift (..))
import Refined
import Refined.Unsafe (reallyUnsafeRefine)
import Prelude

compileRangedText :: Integer -> QuasiQuoter
compileRangedText n =
  QuasiQuoter
    { quoteExp = compileRangedText'
    , quotePat = error "RangedText is not a pattern; use rangedTextToText instead"
    , quoteDec = error "RangedText is not supported at top-level"
    , quoteType = error "RangedText is not supported as a type"
    }
  where
    compileRangedText' :: String -> Q Exp
    compileRangedText' s = usePositiveNat n errorMessage $ \(_ :: proxy n) ->
      case mkRangedText @n (T.pack s) of
        Just txt -> [|$(lift txt) :: RangedText $(pure $ LitT $ NumTyLit n)|]
        Nothing -> errorMessage
      where
        errorMessage = fail $ "Invalid RangedText. Needs to be < " ++ show (n + 1) ++ " characters, and not entirely whitespace: " ++ s

literalRangedText :: forall (s :: Symbol) (n :: Nat). (KnownSymbol s, KnownNat n, SymbolNonEmpty s, SymbolWithNoSpaceAround s, SymbolNoLongerThan s n) => RangedText n
literalRangedText = RangedText (T.pack (symbolVal (Proxy @s)))

convertEmptyTextToNothing :: Text -> Maybe Text
convertEmptyTextToNothing t
  | textIsWhitespace t = Nothing
  | otherwise = Just t

rangedTextToText :: RangedText n -> Text
rangedTextToText (RangedText t) = t

-- | Identical to the normal text filter function, but maintains the type-level invariant
-- that the text length is <= n, unlike unwrapping the text, filtering, then
-- rewrapping the text.
--
-- Will return Nothing if the resulting length is zero.
filterRangedText :: (KnownNat n, 1 <= n) => (Char -> Bool) -> RangedText n -> Maybe (RangedText n)
filterRangedText f (RangedText t) = mkRangedText (T.filter f t)

-- | Narrows the maximum length, dropping any remaining trailing characters.
takeRangedText :: forall m n. (KnownNat m, KnownNat n, 1 <= n, n <= m) => RangedText m -> RangedText n
takeRangedText (RangedText t) =
  if m == n
    then RangedText t
    -- when the input is stripped, taking from it is guaranteed to be not empty
    else RangedText $ T.stripEnd $ T.take n t
  where
    m = fromIntegral $ natVal (Proxy @m)
    n = fromIntegral $ natVal (Proxy @n)

-- | Narrows the maximum length, dropping any prefix remaining characters.
takeRangedTextEnd :: forall m n. (KnownNat m, KnownNat n, 1 <= n, n <= m) => RangedText m -> RangedText n
takeRangedTextEnd (RangedText t) =
  if m == n
    then RangedText t
    -- when the input is stripped, taking from it is guaranteed to be not empty
    else RangedText $ T.stripStart $ T.takeEnd n t
  where
    m = fromIntegral $ natVal (Proxy @m)
    n = fromIntegral $ natVal (Proxy @n)

-- | /O(n)/ Splits a 'RangedText' into components of length @chunkSize@. The
-- chunks may be shorter than the chunkSize depending on the length
-- of the input and spacing. Each chunk is stripped of whitespace.
chunksOfRangedText ::
  forall chunkSize totalSize.
  (KnownNat chunkSize, KnownNat totalSize, chunkSize <= totalSize, 1 <= chunkSize) =>
  RangedText totalSize ->
  NE.NonEmpty (RangedText chunkSize)
chunksOfRangedText (RangedText t) =
  case mRangedChunks of
    Nothing -> error $ "chunksOfRangedText: invalid input: " <> show t
    Just chunks -> chunks
  where
    -- The function NE.ranged is safer than partial NE.fromList.
    -- If the input RangedText is invalid, we want to return a detailed error message.
    mRangedChunks = NE.nonEmpty $ mapMaybe mkRangedText (T.chunksOf chunkSize t)
    chunkSize = fromIntegral $ natVal (Proxy @chunkSize)

-- | Concat two RangedText values, with the new maximum length being the sum of the two
-- maximum lengths of the inputs.
--
-- Mnemonic: @<>@ for monoid, @|@ from Ranged's ':|' operator
(<>|) :: RangedText n -> RangedText m -> RangedText (n + m)
(RangedText l) <>| (RangedText r) = RangedText (l <> r)

-- | Concat two 'RangedText' values with a space in between them. The new
-- maximum length is the sum of the two maximum lengths of the inputs + 1 for
-- the space.
--
-- Useful for 'unwords'like operations, or combining first and last names.
concatWithSpace :: RangedText n -> RangedText m -> RangedText (n + m + 1)
concatWithSpace (RangedText l)  (RangedText r) = RangedText (l <> " " <> r)

-- Refinery

data ContainsNonWhitespaceCharacters = ContainsNonWhitespaceCharacters
  deriving stock (Generic)

instance Predicate ContainsNonWhitespaceCharacters Text where
  validate p txt
    | textHasNoMeaningfulContent txt = throwRefineOtherException (typeRep p) "All characters in Text input are whitespace or control characters"
    | otherwise = Nothing

exactLengthRefinedToRange :: Refined (ContainsNonWhitespaceCharacters && SizeEqualTo n) Text -> RangedText n
exactLengthRefinedToRange = RangedText . unrefine

rangedTextFromRefined :: Refined (ContainsNonWhitespaceCharacters && (SizeLessThan n || SizeEqualTo n)) Text -> RangedText n
rangedTextFromRefined = RangedText . unrefine

refinedFromRangedText :: RangedText n -> Refined (ContainsNonWhitespaceCharacters && (SizeLessThan n || SizeEqualTo n)) Text
refinedFromRangedText = reallyUnsafeRefine . rangedTextToText
