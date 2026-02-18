{-# LANGUAGE OverloadedStrings #-}

-- | Event property tests for Global.Event module
module Property.EventProps where

import Data.Aeson (Value (..), object, (.=))
import Data.Text (Text)
import Global.Event (matchesDirectory)
import Hedgehog
import Hedgehog.Gen qualified as Gen
import Test.Tasty
import Test.Tasty.Hedgehog

-- | Property: matchesDirectory returns True when directory field matches
prop_matchesDirectoryExact :: Property
prop_matchesDirectoryExact = property $ do
    dir <- forAll genDirectory
    eventType <- forAll genEventType
    let event = object ["type" .= eventType, "directory" .= dir]
    assert $ matchesDirectory dir event

-- | Property: matchesDirectory returns False when directory field differs
prop_matchesDirectoryDifferent :: Property
prop_matchesDirectoryDifferent = property $ do
    dir1 <- forAll genDirectory
    dir2 <- forAll $ Gen.filter (/= dir1) genDirectory
    eventType <- forAll genEventType
    let event = object ["type" .= eventType, "directory" .= dir2]
    assert $ not (matchesDirectory dir1 event)

-- | Property: matchesDirectory returns True when no directory field (include by default)
prop_matchesDirectoryMissing :: Property
prop_matchesDirectoryMissing = property $ do
    dir <- forAll genDirectory
    eventType <- forAll genEventType
    let event = object ["type" .= eventType, "properties" .= object []]
    assert $ matchesDirectory dir event

-- | Property: matchesDirectory returns True for non-object values
prop_matchesDirectoryNonObject :: Property
prop_matchesDirectoryNonObject = property $ do
    dir <- forAll genDirectory
    assert $ matchesDirectory dir Null
    assert $ matchesDirectory dir (Bool True)
    assert $ matchesDirectory dir (Number 42)
    assert $ matchesDirectory dir (String "test")

-- | Property: matchesDirectory returns True when directory field is not a string
prop_matchesDirectoryWrongType :: Property
prop_matchesDirectoryWrongType = property $ do
    dir <- forAll genDirectory
    let event = object ["type" .= ("test" :: Text), "directory" .= (123 :: Int)]
    assert $ matchesDirectory dir event

-- Generators
genDirectory :: Gen Text
genDirectory =
    Gen.element
        [ "/home/user/project"
        , "/tmp/test"
        , "/var/data"
        , "/opt/app"
        , "/Users/dev/code"
        ]

genEventType :: Gen Text
genEventType =
    Gen.element
        [ "session.created"
        , "session.updated"
        , "message.updated"
        , "message.part.updated"
        ]

-- Test tree
tests :: TestTree
tests =
    testGroup
        "Event Property Tests"
        [ testProperty "matches exact directory" prop_matchesDirectoryExact
        , testProperty "rejects different directory" prop_matchesDirectoryDifferent
        , testProperty "includes events without directory" prop_matchesDirectoryMissing
        , testProperty "includes non-object values" prop_matchesDirectoryNonObject
        , testProperty "includes events with non-string directory" prop_matchesDirectoryWrongType
        ]
