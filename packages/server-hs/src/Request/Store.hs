{-# LANGUAGE OverloadedStrings #-}

module Request.Store (
    writeRequest,
    listRequests,
    generateId,
) where

import Control.Exception (SomeException, try)
import Data.Aeson (Value)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Word (Word64)
import Numeric (showHex)
import Storage.Storage qualified as Storage
import System.Random (randomIO)

writeRequest :: Storage.StorageConfig -> Text -> Text -> Value -> IO ()
writeRequest storage kind req value =
    Storage.write storage [kind, req] value

listRequests :: Storage.StorageConfig -> Text -> IO [Value]
listRequests storage kind = do
    keys <- Storage.list storage [kind]
    values <- mapM (safeRead storage) keys
    pure (catMaybes values)
  where
    safeRead :: Storage.StorageConfig -> [Text] -> IO (Maybe Value)
    safeRead s k = do
        result <- try @SomeException (Storage.read s k)
        case result of
            Right v -> pure (Just v)
            Left _ -> pure Nothing

generateId :: IO Text
generateId = do
    n <- randomIO :: IO Word64
    pure $ "req_" <> T.pack (showHex n "")
