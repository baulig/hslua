{-
Copyright © 2017-2018 Albert Krewinkel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-deprecations #-}
{-|
Module      :  Foreign.Lua.CoreTest
Copyright   :  © 2017-2018 Albert Krewinkel
License     :  MIT

Maintainer  :  Albert Krewinkel <tarleb+hslua@zeitkraut.de>
Stability   :  stable
Portability :  portable

Tests for Lua C API-like functions.
-}
module Foreign.Lua.CoreTest (tests) where

import Prelude hiding (compare)

import Control.Monad (forM_)
import Data.Monoid ((<>))
import Foreign.Lua as Lua
import Test.HsLua.Arbitrary ()
import Test.HsLua.Util ((?:), (=:), shouldBeResultOf, pushLuaExpr)
import Test.QuickCheck (Property, (.&&.))
import Test.QuickCheck.Monadic (assert, monadicIO, run)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertEqual, testCase)
import Test.Tasty.QuickCheck (testProperty)

import qualified Prelude
import qualified Foreign.Lua.Core.RawBindings as LuaRaw


-- | Specifications for Attributes parsing functions.
tests :: TestTree
tests = testGroup "Haskell version of the C API"
  [ testGroup "copy"
    [ "copies stack elements using positive indices" ?: do
        pushLuaExpr "5, 4, 3, 2, 1"
        copy 4 3
        rawequal (nthFromBottom 4) (nthFromBottom 3)

    , "copies stack elements using negative indices" ?: do
        pushLuaExpr "5, 4, 3, 2, 1"
        copy (-1) (-3)
        rawequal (-1) (-3)
    ]

  , testGroup "insert"
    [ "inserts stack elements using negative indices" ?: do
        pushLuaExpr "1, 2, 3, 4, 5, 6, 7, 8, 9"
        insert (-6)
        movedEl <- peek (-6) :: Lua LuaInteger
        newTop <- peek (-1) :: Lua LuaInteger
        return (movedEl == 9 && newTop == 8)

    , "inserts stack elements using negative indices" ?: do
        pushLuaExpr "1, 2, 3, 4, 5, 6, 7, 8, 9"
        insert 4
        movedEl <- peek 4 :: Lua LuaInteger
        newTop <- peek (-1) :: Lua LuaInteger
        return (movedEl == 9 && newTop == 8)
    ]

  , testCase "absindex" . runLua $ do
      pushLuaExpr "1, 2, 3, 4"
      liftIO . assertEqual "index from bottom doesn't change" (nthFromBottom 3)
        =<< absindex (nthFromBottom 3)
      liftIO . assertEqual "index from top is made absolute" (nthFromBottom 2)
        =<< absindex (nthFromTop 3)
      liftIO . assertEqual "pseudo indices are left unchanged" registryindex
        =<< absindex registryindex

  , "gettable gets a table value" =:
    13.37 `shouldBeResultOf` do
      pushLuaExpr "{sum = 13.37}"
      pushstring "sum"
      gettable (nthFromTop 2)
      tonumber stackTop

  , "strlen, objlen, and rawlen all behave the same" =:
    (7, 7, 7) `shouldBeResultOf` do
      pushLuaExpr "{1, 1, 2, 3, 5, 8, 13}"
      rlen <- rawlen (-1)
      olen <- objlen (-1)
      slen <- strlen (-1)
      return (rlen, olen, slen)

  , testGroup "Type checking"
    [ "isfunction" ?: do
        pushLuaExpr "function () print \"hi!\" end"
        isfunction (-1)

    , "isnil" ?: pushLuaExpr "nil" *> isnil (-1)

    , "isnone" ?: isnone 500 -- stack index 500 does not exist

    , "isnoneornil" ?: do
        pushLuaExpr "nil"
        (&&) <$> isnoneornil 500 <*> isnoneornil (-1)
    ]

  , testCase "CFunction handling" . runLua $ do
      pushcfunction LuaRaw.lua_open_debug_ptr
      liftIO . assertBool "not recognized as CFunction" =<< iscfunction (-1)
      liftIO . assertEqual "CFunction changed after receiving it from the stack"
        LuaRaw.lua_open_debug_ptr =<< tocfunction (-1)

  , testGroup "getting values"
    [ "tointegerx returns numbers verbatim" =:
      Just 149 `shouldBeResultOf` do
        pushLuaExpr "149"
        tointegerx (-1)

    , "tointegerx accepts strings coercible to integers" =:
      Just 451 `shouldBeResultOf` do
        pushLuaExpr "'451'"
        tointegerx (-1)

    , "tointegerx returns Nothing when given a boolean" =:
      Nothing `shouldBeResultOf` do
        pushLuaExpr "true"
        tointegerx (-1)

    , "tonumberx returns numbers verbatim" =:
      Just 14.9 `shouldBeResultOf` do
        pushLuaExpr "14.9"
        tonumberx (-1)

    , "tonumberx accepts strings as numbers" =:
      Just 42.23 `shouldBeResultOf` do
        pushLuaExpr "'42.23'"
        tonumberx (-1)

    , "tonumberx returns Nothing when given a boolean" =:
      Nothing `shouldBeResultOf` do
        pushLuaExpr "true"
        tonumberx (-1)
    ]

  , "setting and getting a global works" =:
    "Moin" `shouldBeResultOf` do
      pushLuaExpr "{'Moin', Hello = 'World'}"
      setglobal "hamburg"

      -- get first field
      getglobal "hamburg"
      rawgeti stackTop 1 -- first field
      tostring stackTop

  , "can push and receive a thread" ?: do
      luaSt <- luaState
      isMain <- pushthread
      liftIO (assertBool "pushing the main thread should return True" isMain)
      luaSt' <- peek stackTop
      return (luaSt == luaSt')

  , "different threads are not equal in Haskell" ?: do
      luaSt1 <- liftIO newstate
      luaSt2 <- liftIO newstate
      return (luaSt1 /= luaSt2)

  , testCase "thread status" . runLua $ do
      status >>= liftIO . assertEqual "base status should be OK" OK
      openlibs
      getglobal' "coroutine.resume"
      pushLuaExpr "coroutine.create(function() coroutine.yield(9) end)"
      co <- tothread stackTop
      call 1 0
      liftIO . runLuaWith co $ do
        liftIO . assertEqual "yielding will put thread status to Yield" Yield
          =<< status

  , testGroup "loading"
    [ testGroup "loadstring"
      [ "loading a valid string should succeed" =:
        OK `shouldBeResultOf` loadstring "return 1"

      , "loading an invalid string should give a syntax error" =:
        ErrSyntax `shouldBeResultOf` loadstring "marzipan"
      ]

    , testGroup "dostring"
      [ "loading a string which fails should give a run error" =:
        ErrRun `shouldBeResultOf` dostring "error 'this fails'"

      , "loading an invalid string should return a syntax error" =:
        ErrSyntax `shouldBeResultOf` dostring "marzipan"

      , "loading a valid program should succeed" =:
        OK `shouldBeResultOf` dostring "return 1"

      , "top of the stack should be result of last computation" =:
        (5 :: LuaInteger) `shouldBeResultOf`
          (dostring "return (2+3)" *> peek (-1))
      ]

    , testGroup "loadbuffer"
      [ "loading a valid string should succeed" =:
        OK `shouldBeResultOf` loadbuffer "return '\NUL'" "test"

      , "loading a string containing NUL should be correct" =:
        "\NUL" `shouldBeResultOf` do
          _ <- loadbuffer "return '\NUL'" "test"
          call 0 1
          tostring stackTop
      ]

    , testGroup "loadfile"
      [ "file error should be returned when file does not exist" =:
        ErrFile `shouldBeResultOf` loadfile "./file-does-not-exist.lua"

      , "loading an invalid file should give a syntax error" =:
        ErrSyntax `shouldBeResultOf` loadfile "test/lua/syntax-error.lua"

      , "loading a valid program should succeed" =:
        OK `shouldBeResultOf` loadfile "./test/lua/example.lua"

      , "example fib program should be loaded correctly" =:
        (8 :: LuaInteger) `shouldBeResultOf` do
          loadfile "./test/lua/example.lua" *> call 0 0
          getglobal "fib"
          pushinteger 6
          call 1 1
          peek stackTop
      ]

    , testGroup "dofile"
      [ "file error should be returned when file does not exist" =:
        ErrFile `shouldBeResultOf` dofile "./file-does-not-exist.lua"

      , "loading an invalid file should give a syntax error" =:
        ErrSyntax `shouldBeResultOf` dofile "test/lua/syntax-error.lua"

      , "loading a failing program should give an run error" =:
        ErrRun `shouldBeResultOf` dofile "test/lua/error.lua"

      , "loading a valid program should succeed" =:
        OK `shouldBeResultOf` dofile "./test/lua/example.lua"

      , "example fib program should be loaded correctly" =:
        (21 :: LuaInteger) `shouldBeResultOf` do
          _ <- dofile "./test/lua/example.lua"
          getglobal "fib"
          pushinteger 8
          call 1 1
          peek stackTop
      ]
    ]

  , testGroup "pcall"
    [ "raising an error should lead to an error status" =:
      ErrRun `shouldBeResultOf` do
        _ <- loadstring "error \"this fails\""
        pcall 0 0 Nothing

    , "raising an error in the error handler should give a 'double error'" =:
      ErrErr `shouldBeResultOf` do
        pushLuaExpr "function () error 'error in error handler' end"
        _ <- loadstring "error \"this fails\""
        pcall 0 0 (Just (nthFromTop 2))
    ]

  , testCase "garbage collection" . runLua $
      -- test that gc can be called with all constructors of type GCCONTROL.
      forM_ [GCSTOP .. GCSETSTEPMUL] $ \what -> (gc what 23)

  , testGroup "compare"
    [ testProperty "identifies strictly smaller values" $ compareWith (<) Lua.LT
    , testProperty "identifies smaller or equal values" $ compareWith (<=) Lua.LE
    , testProperty "identifies equal values" $ compareWith (==) Lua.EQ
    ]

  , testProperty "lessthan works" $ \n1 n2 -> monadicIO $ do
      luaCmp <- run . runLua $ do
        push (n2 :: LuaNumber)
        push (n1 :: LuaNumber)
        lessthan (-1) (-2) <* pop 2
      assert $ luaCmp == (n1 < n2)

  , testProperty "order of Lua types is consistent" $ \ lt1 lt2 ->
      let n1 = fromType lt1
          n2 = fromType lt2
      in Prelude.compare n1 n2 == Prelude.compare lt1 lt2

  , testCase "boolean values are correct" $ do
      trueIsCorrect <- runLua $
        pushboolean True *> dostring "return true" *> rawequal (-1) (-2)
      falseIsCorrect <- runLua $
        pushboolean False *> dostring "return false" *> rawequal (-1) (-2)
      assertBool "LuaBool true is not equal to Lua's true" trueIsCorrect
      assertBool "LuaBool false is not equal to Lua's false" falseIsCorrect

  , testCase "functions can throw a table as error message" $ do
      let mt = "{__tostring = function (e) return e.error_code end}"
      let err = "error(setmetatable({error_code = 23}," <> mt <> "))"
      res <- runLua . tryLua $ openbase *> loadstring err *> call 0 0
      assertEqual "wrong error message" (Left (LuaException "23")) res

  , testCase "handling table errors won't leak" $ do
      let mt = "{__tostring = function (e) return e.code end}"
      let err = "error(setmetatable({code = 5}," <> mt <> "))"
      let luaOp = do
            openbase
            oldtop <- gettop
            _ <- tryLua $ loadstring err *> call 0 0
            newtop <- gettop
            return (newtop - oldtop)
      res <- runLua luaOp
      assertEqual "error handling leaks values to the stack" 0 res
  ]

compareWith :: (LuaInteger -> LuaInteger -> Bool)
            -> RelationalOperator -> LuaInteger -> Property
compareWith op luaOp n = compareLT .&&. compareEQ .&&. compareGT
 where
  compareLT :: Property
  compareLT = monadicIO  $ do
    luaCmp <- run . runLua $ do
      push $ n - 1
      push n
      compare (-2) (-1) luaOp
    assert $ luaCmp == op (n - 1) n

  compareEQ :: Property
  compareEQ = monadicIO  $ do
    luaCmp <- run . runLua $ do
      push n
      push n
      compare (-2) (-1) luaOp
    assert $ luaCmp == op n n

  compareGT :: Property
  compareGT = monadicIO $ do
    luaRes <- run . runLua $ do
      push $ n + 1
      push n
      compare (-2) (-1) luaOp
    assert $ luaRes == op (n + 1) n