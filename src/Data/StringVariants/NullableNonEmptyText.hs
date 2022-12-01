{-# LANGUAGE TemplateHaskell #-}

module Data.StringVariants.NullableNonEmptyText
  ( -- Safe to construct, so we can export the contents
    NullableNonEmptyText (..),

    -- * Constructing
    mkNonEmptyTextWithTruncate,
    compileNullableNonEmptyText,
    mkNullableNonEmptyText,
    parseNullableNonEmptyText,
    nullNonEmptyText,

    -- * Conversion
    maybeTextToTruncateNullableNonEmptyText,
    nonEmptyTextToNullable,
    maybeNonEmptyTextToNullable,
    nullableNonEmptyTextToMaybeText,
    nullableNonEmptyTextToMaybeNonEmptyText,
    fromMaybeNullableText,

    -- * Functions
    isNullNonEmptyText,
  )
where

import Control.Monad
import Data.Aeson
import Data.Aeson qualified as J
import Data.Aeson.Key qualified as J
import Data.Aeson.Types qualified as J
import Data.Data (Proxy (..))
import Data.Maybe (fromMaybe)
import Data.StringVariants.NonEmptyText
import Data.Text (Text)
import Data.Text qualified as T
import GHC.Generics (Generic)
import GHC.TypeLits (KnownNat, natVal)
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax (Lift (..))
import Prelude

-- | Newtype wrapper around Maybe NonEmptyText that converts empty string to 'Nothing'.
--
--   This is aimed primarily at JSON parsing: make it possible to parse empty
--   string and turn it into @Nothing@, in order to convert everything into
--   @Maybe NonEmptyText@ at the edge of the system.
--
--   While using this for JSON parsing, use @Maybe NullableNonEmptyText@. Aeson
--   special-cases @Maybe@ to allow nulls, so @Maybe@ catches the nulls and
--   @NullableNonEmptyText@ catches the empty strings.
--
--   To extract @Maybe NonEmptyText@ values from @Maybe NullableNonEmptyText@,
--   use 'nullableNonEmptyTextToMaybeNonEmptyText'.
newtype NullableNonEmptyText n = NullableNonEmptyText (Maybe (NonEmptyText n))
  deriving stock (Generic, Show, Read, Lift)
  deriving newtype (Eq, ToJSON)

mkNullableNonEmptyText :: forall n. KnownNat n => Text -> Maybe (NullableNonEmptyText n)
mkNullableNonEmptyText t
  | T.compareLength t (fromIntegral $ natVal (Proxy @n)) == GT = Nothing -- we can't store text that is too long
  | otherwise = Just $ NullableNonEmptyText $ mkNonEmptyText t

nullNonEmptyText :: NullableNonEmptyText n
nullNonEmptyText = NullableNonEmptyText Nothing

isNullNonEmptyText :: NullableNonEmptyText n -> Bool
isNullNonEmptyText = (== nullNonEmptyText)

instance KnownNat n => FromJSON (NullableNonEmptyText n) where
  parseJSON = \case
    J.String t -> case mkNullableNonEmptyText t of
      Just txt -> pure txt
      Nothing -> fail $ "Data/StringVariants/NullableNonEmptyText.hs: When trying to parse a NullableNonEmptyText, expected a String of length < " ++ show (natVal (Proxy @n)) ++ ", but received: " ++ T.unpack t
    J.Null -> pure $ NullableNonEmptyText Nothing
    x -> fail $ "Data/StringVariants/NullableNonEmptyText.hs: When trying to parse a NullableNonEmptyText, expected a String or Null, but received: " ++ show x

parseNullableNonEmptyText :: KnownNat n => Text -> J.Object -> J.Parser (NullableNonEmptyText n)
parseNullableNonEmptyText fieldName obj = obj .:? J.fromText fieldName .!= nullNonEmptyText

fromMaybeNullableText :: Maybe (NullableNonEmptyText n) -> NullableNonEmptyText n
fromMaybeNullableText = fromMaybe nullNonEmptyText

nonEmptyTextToNullable :: NonEmptyText n -> NullableNonEmptyText n
nonEmptyTextToNullable = NullableNonEmptyText . Just

maybeNonEmptyTextToNullable :: Maybe (NonEmptyText n) -> NullableNonEmptyText n
maybeNonEmptyTextToNullable Nothing = nullNonEmptyText
maybeNonEmptyTextToNullable jt = NullableNonEmptyText jt

maybeTextToTruncateNullableNonEmptyText :: forall n. KnownNat n => Maybe Text -> NullableNonEmptyText n
maybeTextToTruncateNullableNonEmptyText mText = NullableNonEmptyText $ mText >>= mkNonEmptyText . T.take (fromInteger (natVal (Proxy @n)))

nullableNonEmptyTextToMaybeNonEmptyText :: NullableNonEmptyText n -> Maybe (NonEmptyText n)
nullableNonEmptyTextToMaybeNonEmptyText (NullableNonEmptyText t) = t

nullableNonEmptyTextToMaybeText :: NullableNonEmptyText n -> Maybe Text
nullableNonEmptyTextToMaybeText (NullableNonEmptyText t) = nonEmptyTextToText <$> t

compileNullableNonEmptyText :: Integer -> QuasiQuoter
compileNullableNonEmptyText n =
  QuasiQuoter
    { quoteExp = compileNullableNonEmptyText'
    , quotePat = error "NullableNonEmptyText is not a pattern; use `nullableNonEmptyTextToMaybeText` instead"
    , quoteDec = error "NullableNonEmptyText is not supported at top-level"
    , quoteType = error "NullableNonEmptyText is not supported as a type"
    }
  where
    compileNullableNonEmptyText' :: String -> Q Exp
    compileNullableNonEmptyText' s = useNat n $ \p ->
      case natOfLength p $ mkNullableNonEmptyText (T.pack s) of
        Nothing -> fail $ "Invalid NullableNonEmptyText. Needs to be < " ++ show (n + 1) ++ " characters, and not entirely whitespace: " ++ s
        Just txt -> [|$(lift txt)|]
