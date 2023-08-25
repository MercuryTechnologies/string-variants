{-# LANGUAGE CPP #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.StringVariants.NullableRangedText
  ( -- Safe to construct, so we can export the contents
    NullableRangedText (..),

    -- * Constructing
    mkRangedTextWithTruncate,
    compileNullableRangedText,
    literalNullableRangedText,
    mkNullableRangedText,
    parseNullableRangedText,
    nullRangedText,

    -- * Conversion
    maybeTextToTruncateNullableRangedText,
    rangedTextToNullable,
    maybeRangedTextToNullable,
    nullableRangedTextToMaybeText,
    nullableRangedTextToMaybeRangedText,
    fromMaybeNullableText,

    -- * Functions
    isNullRangedText,
  )
where

import Control.Monad
import Data.Aeson
import Data.Aeson qualified as J
import Data.Aeson.Key qualified as J
import Data.Aeson.Types qualified as J
import Data.Data (Proxy (..))
import Data.Maybe (fromMaybe)
import Data.StringVariants.RangedText
import Data.StringVariants.Util
import Data.Text (Text)
import Data.Text qualified as T
import GHC.Generics (Generic)
import GHC.TypeLits (KnownNat, KnownSymbol, Nat, Symbol, natVal)
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax (Lift (..))
import Prelude

-- | Newtype wrapper around Maybe RangedText that converts empty string to 'Nothing'.
--
--   This is aimed primarily at JSON parsing: make it possible to parse empty
--   string and turn it into @Nothing@, in order to convert everything into
--   @Maybe RangedText@ at the edge of the system.
--
--   While using this for JSON parsing, use @Maybe NullableRangedText@. Aeson
--   special-cases @Maybe@ to allow nulls, so @Maybe@ catches the nulls and
--   @NullableRangedText@ catches the empty strings.
--
--   To extract @Maybe RangedText@ values from @Maybe NullableRangedText@,
--   use 'nullableRangedTextToMaybeRangedText'.
newtype NullableRangedText n = NullableRangedText (Maybe (RangedText n))
  deriving stock (Generic, Show, Read, Lift)
  deriving newtype (Eq)

mkNullableRangedText :: forall n. (KnownNat n, 1 <= n) => Text -> Maybe (NullableRangedText n)
mkNullableRangedText t
  | T.compareLength t (fromIntegral $ natVal (Proxy @n)) == GT = Nothing -- we can't store text that is too long
  | otherwise = Just $ NullableRangedText $ mkRangedText t

nullRangedText :: NullableRangedText n
nullRangedText = NullableRangedText Nothing

isNullRangedText :: NullableRangedText n -> Bool
isNullRangedText = (== nullRangedText)

instance ToJSON (NullableRangedText n) where
  toJSON (NullableRangedText t) = toJSON t

  toEncoding (NullableRangedText t) = toEncoding t

#if MIN_VERSION_aeson(2,2,0)
  omitField (NullableRangedText Nothing) = True
  omitField _ = False
#endif

instance (KnownNat n, 1 <= n) => FromJSON (NullableRangedText n) where
  parseJSON = \case
    J.String t -> case mkNullableRangedText t of
      Just txt -> pure txt
      Nothing -> fail $ "Data/StringVariants/NullableRangedText.hs: When trying to parse a NullableRangedText, expected a String of length < " ++ show (natVal (Proxy @n)) ++ ", but received: " ++ T.unpack t
    J.Null -> pure $ NullableRangedText Nothing
    x -> fail $ "Data/StringVariants/NullableRangedText.hs: When trying to parse a NullableRangedText, expected a String or Null, but received: " ++ show x

#if MIN_VERSION_aeson(2,2,0)
  omittedField = Just (NullableRangedText Nothing)
#endif

parseNullableRangedText :: (KnownNat n, 1 <= n) => Text -> J.Object -> J.Parser (NullableRangedText n)
parseNullableRangedText fieldName obj = obj .:? J.fromText fieldName .!= nullRangedText

fromMaybeNullableText :: Maybe (NullableRangedText n) -> NullableRangedText n
fromMaybeNullableText = fromMaybe nullRangedText

rangedTextToNullable :: RangedText n -> NullableRangedText n
rangedTextToNullable = NullableRangedText . Just

maybeRangedTextToNullable :: Maybe (RangedText n) -> NullableRangedText n
maybeRangedTextToNullable Nothing = nullRangedText
maybeRangedTextToNullable jt = NullableRangedText jt

maybeTextToTruncateNullableRangedText :: forall n. (KnownNat n, 1 <= n) => Maybe Text -> NullableRangedText n
maybeTextToTruncateNullableRangedText mText = NullableRangedText $ mText >>= mkRangedText . T.take (fromInteger (natVal (Proxy @n)))

nullableRangedTextToMaybeRangedText :: NullableRangedText n -> Maybe (RangedText n)
nullableRangedTextToMaybeRangedText (NullableRangedText t) = t

nullableRangedTextToMaybeText :: NullableRangedText n -> Maybe Text
nullableRangedTextToMaybeText (NullableRangedText t) = rangedTextToText <$> t

compileNullableRangedText :: Integer -> QuasiQuoter
compileNullableRangedText n =
  QuasiQuoter
    { quoteExp = compileNullableRangedText'
    , quotePat = error "NullableRangedText is not a pattern; use `nullableRangedTextToMaybeText` instead"
    , quoteDec = error "NullableRangedText is not supported at top-level"
    , quoteType = error "NullableRangedText is not supported as a type"
    }
  where
    compileNullableRangedText' :: String -> Q Exp
    compileNullableRangedText' s = usePositiveNat n errorMessage $ \(_ :: proxy n) ->
      case mkNullableRangedText @n (T.pack s) of
        Just txt -> [|$(lift txt)|]
        Nothing -> errorMessage
      where
        errorMessage = fail $ "Invalid NullableRangedText. Needs to be < " ++ show (n + 1) ++ " characters, and not entirely whitespace: " ++ s

-- | This requires the text to be non-empty. For the empty text just use the constructor `NullableRangedText Nothing`
literalNullableRangedText :: forall (s :: Symbol) (n :: Nat). (KnownSymbol s, KnownNat n, SymbolNonEmpty s, SymbolWithNoSpaceAround s, SymbolNoLongerThan s n) => NullableRangedText n
literalNullableRangedText = NullableRangedText (Just (literalRangedText @s @n))
