{-# OPTIONS_GHC -Wno-warnings-deprecations #-}
{-# LANGUAGE OverloadedStrings #-}
{-|
Module      : HsLua.Core.UnsafeTests
Copyright   : © 2021-2023 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <tarleb@hslua.org>
Stability   : beta

Tests for bindings to unsafe functions.
-}
module HsLua.Core.UnsafeTests (tests) where

import HsLua.Core
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HsLua ((=:), pushLuaExpr, shouldBeResultOf)
import qualified HsLua.Core.Unsafe as Unsafe

-- | Tests for unsafe methods.
tests :: TestTree
tests = testGroup "Unsafe"
  [ testGroup "next"
    [ "get next key from table" =:
      Just 43 `shouldBeResultOf` do
        pushLuaExpr "{43}"
        pushnil -- first key
        True <- Unsafe.next (nth 2)
        tonumber top

    , "returns FALSE if table is empty" =:
      False `shouldBeResultOf` do
        newtable
        pushnil
        Unsafe.next (nth 2)
    ]
  ]
