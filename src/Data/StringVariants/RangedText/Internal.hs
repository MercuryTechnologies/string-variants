{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
-- We need redundant constraints in @widen@ to enforce invariants
{-# OPTIONS_GHC -fno-warn-redundant-constraints #-}

-- | Internal module of RangedText, allowing breaking the abstraction.
--
--   Prefer to use "Data.StringVariants.RangedText" instead.

module Data.StringVariants.RangedText.Internal where

import Control.Monad (when)
import Data.Aeson (FromJSON (..), ToJSON, withText)
import Data.ByteString
import Data.Coerce
import Data.MonoTraversable
import Data.OpenApi
import Data.OpenApi.Internal.Schema (plain)
import Data.Proxy
import Data.Sequences
import Data.String.Conversions (ConvertibleStrings (..), cs)
import Data.StringVariants.Util (textHasNoMeaningfulContent, textIsWhitespace)
import Data.Text (Text)
import Data.Text qualified as T
import GHC.Generics (Generic)
import GHC.TypeLits (KnownNat, Nat, natVal, type (<=))
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax (Lift (..), TyLit (..), Type (..))
import Test.QuickCheck
import Prelude

-- | Non Empty Text, requires the input is between 1 and @n@ chars and not just whitespace.
newtype RangedText (n :: Nat) = RangedText Text
  deriving stock (Generic, Show, Read, Lift)
  deriving newtype (Eq, Ord, ToJSON, Semigroup, MonoFoldable)

instance (KnownNat n, 1 <= n) => ToSchema (RangedText n) where
  declareNamedSchema = plain . paramSchemaToSchema

instance (KnownNat n, 1 <= n) => ToParamSchema (RangedText n) where
  toParamSchema _ =
    mempty
      { _schemaType = Just OpenApiString
      , _schemaMinLength = Just 1
      , _schemaMaxLength = Just (natVal (Proxy @n))
      }

type instance Element (RangedText _n) = Char

instance (KnownNat n, 1 <= n) => FromJSON (RangedText n) where
  parseJSON = withText "RangedText" $ \t -> do
    performInboundValidations t
    case mkRangedText t of
      Nothing -> fail $ "Data/StringVariants/RangedText.hs: invalid RangedText: " ++ T.unpack t
      Just rangedText -> pure rangedText
    where
      -- These validations are performed at the edge of the system rather than in
      -- mkRangedText because there may be cases where legacy RangedText is
      -- stored in the database that fits one of these situations.
      --
      -- However, we don't want new stuff to send junk data, so we use this FromJSON
      -- instance to validate at the edge.
      performInboundValidations t = do
        when (textHasNoMeaningfulContent t) $
          fail $
            "Data/StringVariants/RangedText.hs: RangedText has no meaningful content in the field: " ++ T.unpack t
        when (T.any (== '\NUL') t) $
          fail $
            "Data/StringVariants/RangedText.hs: RangedText has a \\NUL byte in its contents: " ++ T.unpack t

-- Could add more instances of this (for lazy text, bytestrings, etc) if we think we need them.
instance ConvertibleStrings (RangedText n) Text where
  convertString (RangedText t) = t

instance ConvertibleStrings (RangedText n) String where
  convertString (RangedText t) = cs t

instance ConvertibleStrings (RangedText n) ByteString where
  convertString (RangedText t) = cs t

instance (KnownNat n, 1 <= n) => Arbitrary (RangedText n) where
  arbitrary =
    RangedText @n <$> do
      size <- chooseInt (1, fromIntegral (natVal (Proxy :: Proxy n)) - 1)
      -- Mostly alphanumeric characters, all human readable
      str <- replicateM size $ elements ['0' .. 'z']
      pure $ T.pack str

mkRangedText :: forall n. (KnownNat n, 1 <= n) => Text -> Maybe (RangedText n)
mkRangedText t
  | T.compareLength stripped (fromIntegral $ natVal (Proxy @n)) == GT = Nothing
  | textIsWhitespace stripped = Nothing
  | otherwise = Just (RangedText stripped)
  where
    stripped = T.filter (/= '\NUL') $ T.strip t

mkRangedTextWithTruncate :: forall n. (KnownNat n, 1 <= n) => Text -> Maybe (RangedText n)
mkRangedTextWithTruncate t
  | textIsWhitespace stripped = Nothing
  | otherwise = Just (RangedText $ T.stripEnd $ T.take (fromIntegral $ natVal (Proxy @n)) stripped)
  where
    stripped = T.filter (/= '\NUL') $ T.stripStart t

-- | Make a RangedText when you can manually verify the length
unsafeMkRangedText :: forall n. (KnownNat n, 1 <= n) => Text -> RangedText n
unsafeMkRangedText = RangedText

-- | Converts a 'RangedText' to a wider RangedText
widen :: (1 <= n, n <= m) => RangedText n -> RangedText m
widen = coerce

compileRangedTextKnownLength :: QuasiQuoter
compileRangedTextKnownLength =
  QuasiQuoter
    { quoteExp = \s -> do
        let txt = T.pack s
        if textHasNoMeaningfulContent txt
          then fail "Invalid RangedText. Must have at least one non-whitespace, non-control character."
          else [|RangedText $(lift txt) :: RangedText $(pure $ LitT $ NumTyLit $ fromIntegral $ T.length txt)|]
    , quotePat = error "Known-length RangedText is not currently supported as a pattern"
    , quoteDec = error "RangedText is not supported at top-level"
    , quoteType = error "RangedText is not supported as a type"
    }
