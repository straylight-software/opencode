{-# LANGUAGE OverloadedStrings #-}

module Tui.Store (
    getPrompt,
    appendPrompt,
    clearPrompt,
    submitPrompt,
    setLast,
    getLast,
) where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, try)
import Data.Aeson (Value (..), object, (.=))
import Data.Text (Text)
import Storage.Storage qualified as Storage

promptKey :: [Text]
promptKey = ["tui", "prompt"]

lastKey :: [Text]
lastKey = ["tui", "last"]

getPrompt :: Storage.StorageConfig -> IO Text
getPrompt storage = getPromptRetry 3
  where
    getPromptRetry :: Int -> IO Text
    getPromptRetry 0 = pure ""
    getPromptRetry n = do
        result <- try @SomeException (Storage.read storage promptKey)
        case result of
            Right (String t) -> pure t
            Right _ -> pure ""
            Left _ -> do
                -- Retry after small delay in case of transient filesystem issue
                threadDelay 1000 -- 1ms
                getPromptRetry (n - 1)

appendPrompt :: Storage.StorageConfig -> Text -> IO Text
appendPrompt storage text = do
    current <- getPrompt storage
    let next = current <> text
    Storage.write storage promptKey (String next)
    pure next

clearPrompt :: Storage.StorageConfig -> IO ()
clearPrompt storage = Storage.write storage promptKey (String "")

submitPrompt :: Storage.StorageConfig -> IO Text
submitPrompt storage = do
    current <- getPrompt storage
    Storage.write storage promptKey (String "")
    Storage.write storage ["tui", "submitted"] (object ["prompt" .= current])
    pure current

setLast :: Storage.StorageConfig -> Value -> IO ()
setLast storage value = Storage.write storage lastKey value

getLast :: Storage.StorageConfig -> IO (Maybe Value)
getLast storage = getLastRetry 3
  where
    getLastRetry :: Int -> IO (Maybe Value)
    getLastRetry 0 = pure Nothing
    getLastRetry n = do
        result <- try @SomeException (Storage.read storage lastKey)
        case result of
            Right v -> pure (Just v)
            Left _ -> do
                threadDelay 1000
                getLastRetry (n - 1)
