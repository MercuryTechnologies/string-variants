module Specs.ModuleWithLongTypeLiteralSpec (spec) where

import Data.StringVariants.NonEmptyText
import Test.Hspec

-- Literal of length 200
-- Renamer/typechecker [Specs.ModuleWithLongTypeLiteralSpec]: alloc=246795704 time=176.832
-- Simplifier [Specs.ModuleWithLongTypeLiteralSpec]: alloc=755813304 time=255.395

-- Literal of length 3

-- Renamer/typechecker [Specs.ModuleWithLongTypeLiteralSpec]: alloc=231978552 time=151.252
-- Simplifier [Specs.ModuleWithLongTypeLiteralSpec]: alloc=2236936 time=40.117

-- Fails to compile with longer text: Reduction stack overflow; size = 201
nonEmptyText :: NonEmptyText 2999
nonEmptyText = literalNonEmptyText @"It was a dog. It was a big dog. I'm Batman Hero can be anyone. Even a man knowing something as simple and reassuring as putting a coat around a young boy shoulders to let him know the world hadn't"

spec :: Spec
spec = describe "Compiles a long literal with literalNonEmptyText" $ do
  it "compiles" $ do
    Just nonEmptyText `shouldBe` mkNonEmptyText "It was a dog. It was a big dog. I'm Batman Hero can be anyone. Even a man knowing something as simple and reassuring as putting a coat around a young boy shoulders to let him know the world hadn't"