{-# LANGUAGE OverloadedStrings #-}

module Lsp.Store (
    getDiagnostics,
    setDiagnostics,
) where

import Control.Exception (SomeException, try)
import Data.Aeson (Value (..))
import Data.Aeson qualified as Aeson
import Data.Foldable (toList)
import Data.Text (Text)
import Storage.Storage qualified as Storage
import System.Directory (canonicalizePath, doesFileExist)
import System.FilePath (takeDirectory, (</>))

diagKey :: [Text]
diagKey = ["lsp", "diagnostics"]

getDiagnostics :: Storage.StorageConfig -> IO [Value]
getDiagnostics storage = do
    -- First try to read from Storage
    result <- try @SomeException (Storage.read storage diagKey)
    case result of
        Right (Array xs) -> pure (toList xs)
        Right _ -> getDiagnosticsFile storage
        Left _ -> getDiagnosticsFile storage

setDiagnostics :: Storage.StorageConfig -> [Value] -> IO ()
setDiagnostics storage values =
    Storage.write storage diagKey (Aeson.toJSON values)

getDiagnosticsFile :: Storage.StorageConfig -> IO [Value]
getDiagnosticsFile storage = do
    -- Canonicalize to resolve symlinks (important in nix sandbox)
    dir <- canonicalizePath (Storage.storageDir storage)
    readFromPaths (diagnosticPaths dir)

diagnosticPaths :: FilePath -> [FilePath]
diagnosticPaths dir =
    [ dir </> "lsp" </> "diagnostics.json"
    , dir </> "diagnostics.json"
    , takeDirectory dir </> "lsp" </> "diagnostics.json"
    , takeDirectory dir </> "diagnostics.json"
    ]

readFromPaths :: [FilePath] -> IO [Value]
readFromPaths [] = pure []
readFromPaths (path : rest) = do
    exists <- doesFileExist path
    if not exists
        then readFromPaths rest
        else do
            result <- Aeson.eitherDecodeFileStrict path
            case result of
                Right (Array xs) -> pure (toList xs)
                _ -> readFromPaths rest
