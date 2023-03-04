{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-|
Module      : Test.Tasty.Lua
Copyright   : © 2019-2023 Albert Krewinkel
License     : MIT
Maintainer  : Albert Krewinkel <albert@hslua.org>
Stability   : alpha
Portability : Requires TemplateHaskell

Convert Lua test results into a tasty test trees.
-}
module Test.Tasty.Lua
  ( -- * Lua module
    pushModule
    -- * Running tests
  , testLuaFile
  , translateResultsFromFile
    -- * Helpers
  , pathFailure
  , registerArbitrary
  )
where

import Control.Exception (SomeException, try)
import Data.Bifunctor (first)
import Data.List (intercalate)
import HsLua.Core (LuaE, LuaError)
import Test.Tasty (TestName, TestTree)
import Test.Tasty.Providers (IsTest (..), singleTest, testFailed, testPassed)
import Test.Tasty.Lua.Arbitrary (registerArbitrary)
import Test.Tasty.Lua.Module (pushModule)
import Test.Tasty.Lua.Core (Outcome (..), ResultTree (..), UnnamedTree (..),
                            runTastyFile)
import Test.Tasty.Lua.Translate (pathFailure, translateResultsFromFile)

-- | Run the given file as a single test. It is possible to use
-- `tasty.lua` in the script. This test collects and summarizes all
-- errors, but shows generally no information on the successful tests.
testLuaFile :: forall e. LuaError e
            => (forall a. LuaE e a -> IO a)
            -> TestName
            -> FilePath
            -> TestTree
testLuaFile runLua name fp =
  let testAction = TestCase $ do
        eitherResult <- runLua (runTastyFile @e fp)
        return $ case eitherResult of
          Left errMsg  -> FailureSummary [([name], errMsg)]
          Right result -> summarize result
  in singleTest name testAction

-- | Lua test case action
newtype TestCase = TestCase (IO ResultSummary)

instance IsTest TestCase where
  run _ (TestCase action) _ = do
    result <- try action
    return $ case result of
      Left e        -> testFailed (show (e :: SomeException))
      Right summary -> case summary of
        SuccessSummary n ->
          testPassed $ "+++ Success: " ++ show n ++ " Lua tests passed"
        FailureSummary fails ->
          testFailed $ concatMap stringifyFailureGist fails

  testOptions = return []

summarize :: [ResultTree] -> ResultSummary
summarize = foldr ((<>) . collectSummary) (SuccessSummary 0)

-- | Failure message generated by tasty.lua
type LuaErrorMessage = String
-- | Info about a single failure
type FailureInfo = ([TestName], LuaErrorMessage)

-- | Summary about a test result
data ResultSummary
  = SuccessSummary Int -- ^ Number of successful tests
  | FailureSummary [FailureInfo]
  -- ^ Failure messages, together with the test paths

-- | Convert a test failure, given as the pair of the test's path and
-- its error message, into an error string.
stringifyFailureGist :: FailureInfo -> String
stringifyFailureGist (names, msg) =
  intercalate " // " names ++ ":\n" ++ msg ++ "\n\n"

-- | Combine all failures (or successes) from a test result tree into a
-- @'ResultSummary'@. If the tree contains only successes, the result
-- will be @'SuccessSummary'@ with the number of successful tests; if
-- there was at least one failure, the result will be
-- @'FailureSummary'@, with a @'FailureInfo'@ for each failure.
collectSummary :: ResultTree -> ResultSummary
collectSummary (ResultTree name tree) =
  case tree of
    SingleTest Success       -> SuccessSummary 1
    SingleTest (Failure msg) -> FailureSummary [([name], msg)]
    TestGroup subtree        -> foldMap (addGroup name . collectSummary)
                                        subtree

-- | Add the name of the current test group to all failure summaries.
addGroup :: TestName -> ResultSummary -> ResultSummary
addGroup name  (FailureSummary fs) = FailureSummary (map (first (name:)) fs)
addGroup _name summary             = summary

instance Semigroup ResultSummary where
  (SuccessSummary n)  <> (SuccessSummary m)  = SuccessSummary (n + m)
  (SuccessSummary _)  <> (FailureSummary fs) = FailureSummary fs
  (FailureSummary fs) <> (SuccessSummary _)  = FailureSummary fs
  (FailureSummary fs) <> (FailureSummary gs) = FailureSummary (fs ++ gs)

instance Monoid ResultSummary where
  mempty = SuccessSummary 0
  mappend = (<>)             -- GHC 8.2 compatibility
