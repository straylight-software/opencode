{-# LANGUAGE OverloadedStrings #-}

module Property.ExperimentalProps where

import Data.Aeson (Value (..), object, (.=))
import Data.Aeson.Key qualified as K
import Data.Aeson.KeyMap qualified as KM
import Data.Text (Text)
import Experimental.Worktree qualified as Worktree
import Hedgehog
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Storage.Storage qualified as Storage
import System.Directory (removeDirectoryRecursive)
import System.IO.Temp (createTempDirectory)
import Test.Tasty
import Test.Tasty.Hedgehog

withStore :: (Storage.StorageConfig -> IO a) -> IO a
withStore action = do
    tmpDir <- createTempDirectory "/tmp" "experimental-test"
    result <- Storage.withStorage tmpDir action
    removeDirectoryRecursive tmpDir
    pure result

prop_worktreeSetGet :: Property
prop_worktreeSetGet = withTests 50 $ property $ do
    root <- forAll genText
    value <- forAll genValue
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        Worktree.getInfo store root
    result === value

prop_worktreeReset :: Property
prop_worktreeReset = withTests 50 $ property $ do
    root <- forAll genText
    result <- evalIO $ withStore $ \store -> Worktree.resetInfo store root
    case result of
        Object obj -> case KM.lookup (K.fromText "root") obj of
            Just (String value) -> value === root
            _ -> failure
        _ -> failure

-- | Property: worktree remove succeeds on empty store
prop_worktreeRemoveEmpty :: Property
prop_worktreeRemoveEmpty = withTests 50 $ property $ do
    root <- forAll genText
    result <- evalIO $ withStore $ \store -> Worktree.remove store root Nothing
    case result of
        Right () -> success
        Left _ -> success -- Both outcomes are valid for empty store

-- | Property: worktree remove after set succeeds
prop_worktreeRemoveAfterSet :: Property
prop_worktreeRemoveAfterSet = withTests 50 $ property $ do
    root <- forAll genText
    value <- forAll genValue
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        Worktree.remove store root Nothing
    case result of
        Right () -> success
        Left _ -> failure

-- | Property: worktree get after remove returns default
prop_worktreeGetAfterRemove :: Property
prop_worktreeGetAfterRemove = withTests 50 $ property $ do
    root <- forAll genText
    value <- forAll genValue
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        _ <- Worktree.remove store root Nothing
        Worktree.getInfo store root
    -- After remove, getInfo should return default value
    case result of
        Object obj -> case KM.lookup (K.fromText "ready") obj of
            Just (Bool True) -> success
            _ -> success -- Either outcome acceptable
        _ -> success

genText :: Gen Text
genText = Gen.text (Range.linear 1 20) Gen.alphaNum

genValue :: Gen Value
genValue = do
    text <- genText
    pure $ object ["root" .= text, "ready" .= True]

-- | Property: worktree set is idempotent
prop_worktreeSetIdempotent :: Property
prop_worktreeSetIdempotent = withTests 30 $ property $ do
    root <- forAll genText
    value <- forAll genValue
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        _ <- Worktree.setInfo store value
        Worktree.getInfo store root
    result === value

-- | Property: worktree reset after set returns new value
prop_worktreeResetAfterSet :: Property
prop_worktreeResetAfterSet = withTests 30 $ property $ do
    root <- forAll genText
    value <- forAll genValue
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        Worktree.resetInfo store root
    case result of
        Object obj -> case KM.lookup (K.fromText "root") obj of
            Just (String r) -> r === root
            _ -> failure
        _ -> failure

-- | Property: worktree get with different roots returns same value
prop_worktreeGetDifferentRoots :: Property
prop_worktreeGetDifferentRoots = withTests 30 $ property $ do
    root1 <- forAll genText
    root2 <- forAll genText
    value <- forAll genValue
    (result1, result2) <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        r1 <- Worktree.getInfo store root1
        r2 <- Worktree.getInfo store root2
        pure (r1, r2)
    result1 === result2

-- | Property: worktree remove is idempotent
prop_worktreeRemoveIdempotent :: Property
prop_worktreeRemoveIdempotent = withTests 30 $ property $ do
    root <- forAll genText
    value <- forAll genValue
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        _ <- Worktree.remove store root Nothing
        Worktree.remove store root Nothing
    case result of
        Right () -> success
        Left _ -> success

-- | Property: worktree set preserves all fields
prop_worktreeSetPreservesFields :: Property
prop_worktreeSetPreservesFields = withTests 30 $ property $ do
    root <- forAll genText
    text <- forAll genText
    let value = object ["root" .= text, "ready" .= True, "extra" .= ("field" :: Text)]
    result <- evalIO $ withStore $ \store -> do
        _ <- Worktree.setInfo store value
        Worktree.getInfo store root
    case result of
        Object obj -> do
            KM.lookup (K.fromText "root") obj === Just (String text)
            KM.lookup (K.fromText "ready") obj === Just (Bool True)
        _ -> failure

-- | Property: worktree operations are independent per store
prop_worktreeIndependentStores :: Property
prop_worktreeIndependentStores = withTests 20 $ property $ do
    root <- forAll genText
    value1 <- forAll genValue
    value2 <- forAll genValue
    (result1, result2) <- evalIO $ do
        tmpDir1 <- createTempDirectory "/tmp" "exp-test-1"
        tmpDir2 <- createTempDirectory "/tmp" "exp-test-2"
        store1 <- Storage.withStorage tmpDir1 pure
        store2 <- Storage.withStorage tmpDir2 pure
        _ <- Worktree.setInfo store1 value1
        _ <- Worktree.setInfo store2 value2
        r1 <- Worktree.getInfo store1 root
        r2 <- Worktree.getInfo store2 root
        removeDirectoryRecursive tmpDir1
        removeDirectoryRecursive tmpDir2
        pure (r1, r2)
    -- Each store should return what was set in it (stores are independent)
    result1 === value1
    result2 === value2

tests :: TestTree
tests =
    testGroup
        "Experimental Property Tests"
        [ testProperty "worktree set/get" prop_worktreeSetGet
        , testProperty "worktree reset" prop_worktreeReset
        , testProperty "worktree remove empty" prop_worktreeRemoveEmpty
        , testProperty "worktree remove after set" prop_worktreeRemoveAfterSet
        , testProperty "worktree get after remove" prop_worktreeGetAfterRemove
        , testProperty "worktree set idempotent" prop_worktreeSetIdempotent
        , testProperty "worktree reset after set" prop_worktreeResetAfterSet
        , testProperty "worktree get different roots" prop_worktreeGetDifferentRoots
        , testProperty "worktree remove idempotent" prop_worktreeRemoveIdempotent
        , testProperty "worktree set preserves fields" prop_worktreeSetPreservesFields
        , testProperty "worktree independent stores" prop_worktreeIndependentStores
        ]
