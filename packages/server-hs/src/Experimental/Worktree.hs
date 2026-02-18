{-# LANGUAGE OverloadedStrings #-}

module Experimental.Worktree (
    getInfo,
    setInfo,
    resetInfo,
    remove,
)
where

import Control.Exception (catch)
import Data.Aeson (Value, object, (.=))
import Data.Text (Text)
import Storage.Storage qualified as Storage

worktreeKey :: [Text]
worktreeKey = ["experimental", "worktree"]

getInfo :: Storage.StorageConfig -> Text -> IO Value
getInfo storage root = do
    result <- (Just <$> Storage.read storage worktreeKey) `catch` \(Storage.NotFoundError _) -> pure Nothing
    case result of
        Just value -> pure value
        Nothing -> pure $ object ["root" .= root, "ready" .= True]

setInfo :: Storage.StorageConfig -> Value -> IO Value
setInfo storage value = do
    Storage.write storage worktreeKey value
    pure value

resetInfo :: Storage.StorageConfig -> Text -> IO Value
resetInfo storage root = do
    let value = object ["root" .= root, "reset" .= True]
    Storage.write storage worktreeKey value
    pure value

-- | Remove a worktree
remove :: Storage.StorageConfig -> Text -> Maybe Text -> IO (Either Text ())
remove storage _root _mDir = do
    -- Remove worktree info from storage
    _ <- (Storage.remove storage worktreeKey >> pure (Right ())) `catch` handler
    pure (Right ())
  where
    handler :: Storage.NotFoundError -> IO (Either Text ())
    handler _ = pure (Right ())
