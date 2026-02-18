{-# LANGUAGE OverloadedStrings #-}

module Property.ProjectProps where

import Api (Project (Project), id)
import Data.Text qualified as T
import Hedgehog
import Hedgehog.Gen qualified as Gen
import Hedgehog.Range qualified as Range
import Project.Build qualified as ProjectBuild
import Test.Tasty
import Test.Tasty.Hedgehog
import Prelude hiding (id)

prop_projectFromDirUsesBase :: Property
prop_projectFromDirUsesBase = property $ do
    base <- forAll $ Gen.text (Range.linear 1 12) Gen.alphaNum
    let dir = "/tmp/" <> T.unpack base
    let project = ProjectBuild.projectFromDir dir
    case project of
        Project pid wt nm -> do
            pid === "proj_" <> base
            wt === T.pack dir
            nm === Just base

prop_projectFromDirDefault :: Property
prop_projectFromDirDefault = property $ do
    let dir = "/"
    let project = ProjectBuild.projectFromDir dir
    case project of
        Project pid _ nm -> do
            pid === "proj_default"
            nm === Nothing

-- | Property: project id is deterministic based on directory
prop_projectIdDeterministic :: Property
prop_projectIdDeterministic = property $ do
    base <- forAll $ Gen.text (Range.linear 1 12) Gen.alphaNum
    let dir = "/tmp/" <> T.unpack base
    let project1 = ProjectBuild.projectFromDir dir
    let project2 = ProjectBuild.projectFromDir dir
    id project1 === id project2

-- | Property: project id format is proj_{basename}
prop_projectIdFormat :: Property
prop_projectIdFormat = property $ do
    base <- forAll $ Gen.text (Range.linear 1 12) Gen.alphaNum
    let dir = "/some/path/" <> T.unpack base
    let project = ProjectBuild.projectFromDir dir
    T.isPrefixOf "proj_" (id project) === True

-- | Property: project worktree path is absolute
prop_projectWorktreeAbsolute :: Property
prop_projectWorktreeAbsolute = property $ do
    dir <- forAll $ Gen.text (Range.linear 1 20) Gen.alphaNum
    let project = ProjectBuild.projectFromDir ("/home/user/" <> T.unpack dir)
    case project of
        Project _ wt _ -> T.isPrefixOf "/" wt === True

-- | Property: project name can be extracted from path
prop_projectNameFromPath :: Property
prop_projectNameFromPath = property $ do
    name <- forAll $ Gen.text (Range.linear 1 15) Gen.alphaNum
    let path = "/home/user/projects/" <> T.unpack name
    let project = ProjectBuild.projectFromDir path
    case project of
        Project _ _ (Just nm) -> nm === name
        _ -> failure

-- | Property: project id contains only valid characters
prop_projectIdValidChars :: Property
prop_projectIdValidChars = property $ do
    dir <- forAll $ Gen.text (Range.linear 1 20) Gen.lower
    let project = ProjectBuild.projectFromDir ("/tmp/" <> T.unpack dir)
    let pid = id project
    assert $ T.all (\c -> c == '_' || c == '-' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9') pid

-- | Property: same directory produces same project
prop_projectSameDirSameProject :: Property
prop_projectSameDirSameProject = property $ do
    dir <- forAll $ Gen.text (Range.linear 1 20) Gen.alphaNum
    let path = "/tmp/" <> T.unpack dir
    let p1 = ProjectBuild.projectFromDir path
    let p2 = ProjectBuild.projectFromDir path
    p1 === p2

-- | Property: different directories produce different projects
prop_projectDifferentDirDifferentProject :: Property
prop_projectDifferentDirDifferentProject = property $ do
    dir1 <- forAll $ Gen.text (Range.linear 1 10) Gen.alphaNum
    dir2 <- forAll $ Gen.text (Range.linear 11 20) Gen.alphaNum
    if dir1 == dir2
        then success
        else do
            let p1 = ProjectBuild.projectFromDir ("/tmp/" <> T.unpack dir1)
            let p2 = ProjectBuild.projectFromDir ("/tmp/" <> T.unpack dir2)
            assert $ id p1 /= id p2

tests :: TestTree
tests =
    testGroup
        "Project Property Tests"
        [ testProperty "projectFromDir uses base name" prop_projectFromDirUsesBase
        , testProperty "projectFromDir default" prop_projectFromDirDefault
        , testProperty "project id deterministic" prop_projectIdDeterministic
        , testProperty "project id format" prop_projectIdFormat
        , testProperty "project worktree absolute" prop_projectWorktreeAbsolute
        , testProperty "project name from path" prop_projectNameFromPath
        , testProperty "project id valid chars" prop_projectIdValidChars
        , testProperty "project same dir same project" prop_projectSameDirSameProject
        , testProperty "project different dir different project" prop_projectDifferentDirDifferentProject
        ]
