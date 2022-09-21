module Data.StringVariants.Util (natOfLength, useNat, textIsTooLong, textIsWhitespace, textHasNoMeaningfulContent) where
import GHC.TypeLits (KnownNat, Nat, SomeNat (..), someNatVal)
import Prelude
import Data.Text (Text)
import qualified Data.Text as T
import Data.Char (isSpace, isControl)

textIsTooLong :: Text -> Int -> Bool
-- why take? because of stream fusion,
-- length isn't O(1), it's O(n). which means
-- it's better to cut off the text at @n@
-- and then evaluate the resulting stream, than
-- to evaluate the entire stream. very unintuitive,
-- but that's just the way things are :(
textIsTooLong t n = T.length (T.take (n + 1) t) >= (n + 1)

textIsWhitespace :: Text -> Bool
textIsWhitespace = T.all isSpace

textHasNoMeaningfulContent :: Text -> Bool
textHasNoMeaningfulContent = T.all (\c -> isSpace c || isControl c)


natOfLength :: proxy (n :: Nat) -> f (other n) -> f (other n)
natOfLength _ = id

useNat :: Integer -> (forall n proxy. KnownNat n => proxy n -> x) -> x
useNat n f = case someNatVal n of
  Nothing -> error (show n ++ " isn't a valid Nat")
  Just (SomeNat p) -> f p

