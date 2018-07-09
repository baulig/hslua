{-
Copyright © 2018 Albert Krewinkel

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
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE OverloadedStrings #-}

import Control.DeepSeq
import Control.Monad (void)
import Criterion.Main
import Criterion.Types (Config(..))
import Data.ByteString (ByteString)
import Foreign.C (CString (..), CSize (..), CInt (..))
import Foreign.Lua (Lua, StackIndex, LuaState, runLua)

import qualified Foreign.Lua as Lua
import qualified Data.ByteString as B
import qualified Data.ByteString.Unsafe as B

#include "benchmark-functions.h"

luaBench :: NFData b
         => String
         -> Lua a    -- ^ Setup
         -> Lua b    -- ^ Operation to benchmark
         -> Benchmark
luaBench name setupOp benchOp = do
  bench name .
    perRunEnvWithCleanup (setupLua setupOp) teardownLua $ \l ->
      Lua.runLuaWith l benchOp

setupLua :: Lua a -> IO Lua.LuaState
setupLua setupOp = do
  l <- Lua.newstate
  _ <- Lua.runLuaWith l setupOp
  return l

teardownLua :: Lua.LuaState -> IO ()
teardownLua = Lua.close

setupTableWithFooField :: Lua ()
setupTableWithFooField = do
  Lua.newtable
  Lua.pushstring "foo"
  Lua.setfield (Lua.nthFromTop 2) "bar"

getfieldBench :: Benchmark
getfieldBench =
  let getFooField = Lua.getfield Lua.stackTop "foo"
  in luaBench "getfield" setupTableWithFooField getFooField

getlfieldBench :: Benchmark
getlfieldBench =
  let getlfieldFoo = getlfield Lua.stackTop "foo"
  in luaBench "getlfield" setupTableWithFooField getlfieldFoo


main :: IO ()
main = do
  defaultMain
    [ getfieldBench
    , getlfieldBench
    ]

instance NFData Lua.LuaState


-- Functions for comparison

-- | Getting a string field with lua_pushlstring and lua_gettable
foreign import ccall "safer-api.h hslua_getlfield"
  hslua_getlfield :: LuaState -> StackIndex -> CString -> CSize
                  -> IO CInt

getlfield :: StackIndex -> ByteString -> Lua CInt
getlfield i s = (\f -> Lua.luaState >>= Lua.liftIO . f)
  (\l -> B.unsafeUseAsCStringLen s $ \(strPtr, len) ->
      hslua_getlfield l i strPtr (fromIntegral len))
