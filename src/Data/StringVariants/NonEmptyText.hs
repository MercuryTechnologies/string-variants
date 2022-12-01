{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# OPTIONS_GHC -Wno-redundant-constraints #-}

-- | NonEmptyText: Text that is known not to be either the empty string, or pure
--   whitespace.

module Data.StringVariants.NonEmptyText
  ( -- * Non empty text
    NonEmptyText,
    type (<=),

    -- * Construction
    mkNonEmptyText,
    mkNonEmptyTextWithTruncate,
    unsafeMkNonEmptyText,
    nonEmptyTextToText,
    compileNonEmptyText,
    compileNonEmptyTextKnownLength,
    convertEmptyTextToNothing,

    -- * Conversion
    widen,

    -- * Functions
    takeNonEmptyText,
    takeNonEmptyTextEnd,
    chunksOfNonEmptyText,
    filterNonEmptyText,
    (<>|),

    -- * Conversions between 'Refined' and 'NonEmptyText'.
    ContainsNonWhitespaceCharacters (..),
    exactLengthRefinedToRange,
    nonEmptyTextFromRefined,
    refinedFromNonEmptyText,

    -- * Convenience util if you need a NonEmptyText of a dynamically determined lengths
    useNat,
    natOfLength,
  )
where

import Control.Monad
import Data.Data (Proxy (..), typeRep)
import Data.StringVariants.NonEmptyText.Internal
import Data.StringVariants.Util
import Data.Text (Text)
import Data.Text qualified as T
import GHC.Generics (Generic)
import GHC.TypeLits (KnownNat, natVal, type (+), type (<=))
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax (Lift (..))
import Refined
import Refined.Unsafe (reallyUnsafeRefine)
import Prelude

compileNonEmptyText :: Integer -> QuasiQuoter
compileNonEmptyText n =
  QuasiQuoter
    { quoteExp = compileNonEmptyText'
    , quotePat = error "NonEmptyText is not a pattern; use nonEmptyTextToText instead"
    , quoteDec = error "NonEmptyText is not supported at top-level"
    , quoteType = error "NonEmptyText is not supported as a type"
    }
  where
    compileNonEmptyText' :: String -> Q Exp
    compileNonEmptyText' s = useNat n $ \p ->
      case natOfLength p $ mkNonEmptyText (T.pack s) of
        Nothing -> fail $ "Invalid NonEmptyText. Needs to be < " ++ show (n + 1) ++ " characters, and not entirely whitespace: " ++ s
        Just txt -> [|$(lift txt) :: NonEmptyText $(pure $ LitT $ NumTyLit n)|]

convertEmptyTextToNothing :: Text -> Maybe Text
convertEmptyTextToNothing t
  | textIsWhitespace t = Nothing
  | otherwise = Just t

nonEmptyTextToText :: NonEmptyText n -> Text
nonEmptyTextToText (NonEmptyText t) = t

-- | Identical to the normal text filter function, but maintains the type-level invariant
-- that the text length is <= n, unlike unwrapping the text, filtering, then
-- rewrapping the text.
filterNonEmptyText :: (Char -> Bool) -> NonEmptyText n -> NonEmptyText n
filterNonEmptyText f (NonEmptyText t) = NonEmptyText (T.filter f t)

-- | Narrows the maximum length, dropping any remaining trailing characters.
takeNonEmptyText :: forall m n. (KnownNat m, KnownNat n, n <= m) => NonEmptyText m -> NonEmptyText n
takeNonEmptyText (NonEmptyText t) =
  if m == n
    then NonEmptyText t
    else NonEmptyText $ T.take n t
  where
    m = fromIntegral $ natVal (Proxy @m)
    n = fromIntegral $ natVal (Proxy @n)

-- | Narrows the maximum length, dropping any prefix remaining characters.
takeNonEmptyTextEnd :: forall m n. (KnownNat m, KnownNat n, n <= m) => NonEmptyText m -> NonEmptyText n
takeNonEmptyTextEnd (NonEmptyText t) =
  if m == n
    then NonEmptyText t
    else NonEmptyText $ T.takeEnd n t
  where
    m = fromIntegral $ natVal (Proxy @m)
    n = fromIntegral $ natVal (Proxy @n)

-- | /O(n)/ Splits a 'NonEmptyText' into components of length @chunkSize@. The
-- last element may be shorter than the other chunks, depending on the length
-- of the input.
chunksOfNonEmptyText ::
  forall chunkSize totalSize.
  (KnownNat chunkSize, KnownNat totalSize) =>
  NonEmptyText totalSize ->
  [NonEmptyText chunkSize]
chunksOfNonEmptyText (NonEmptyText t) =
  map NonEmptyText (T.chunksOf chunkSize t)
  where
    chunkSize = fromIntegral $ natVal (Proxy @chunkSize)

-- | Concat two NonEmptyText values, with the new maximum length being the sum of the two
-- maximum lengths of the inputs.
--
-- Mnemonic: @<>@ for monoid, @|@ from NonEmpty's ':|' operator
(<>|) :: NonEmptyText n -> NonEmptyText m -> NonEmptyText (n + m)
(NonEmptyText l) <>| (NonEmptyText r) = NonEmptyText (l <> r)

-- | Concat two 'NonEmptyText' values with a space in between them. The new
-- maximum length is the sum of the two maximum lengths of the inputs + 1 for
-- the space.
--
-- Useful for 'unwords'like operations, or combining first and last names.
concatWithSpace :: NonEmptyText n -> NonEmptyText m -> NonEmptyText (n + m + 1)
concatWithSpace (NonEmptyText l)  (NonEmptyText r) = NonEmptyText (l <> " " <> r)

-- Refinery

data ContainsNonWhitespaceCharacters = ContainsNonWhitespaceCharacters
  deriving stock (Generic)

instance Predicate ContainsNonWhitespaceCharacters Text where
  validate p txt
    | textHasNoMeaningfulContent txt = throwRefineOtherException (typeRep p) "All characters in Text input are whitespace or control characters"
    | otherwise = Nothing

exactLengthRefinedToRange :: Refined (ContainsNonWhitespaceCharacters && SizeEqualTo n) Text -> NonEmptyText n
exactLengthRefinedToRange = NonEmptyText . unrefine

nonEmptyTextFromRefined :: Refined (ContainsNonWhitespaceCharacters && (SizeLessThan n || SizeEqualTo n)) Text -> NonEmptyText n
nonEmptyTextFromRefined = NonEmptyText . unrefine

refinedFromNonEmptyText :: NonEmptyText n -> Refined (ContainsNonWhitespaceCharacters && (SizeLessThan n || SizeEqualTo n)) Text
refinedFromNonEmptyText = reallyUnsafeRefine . nonEmptyTextToText
