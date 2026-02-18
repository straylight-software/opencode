{-# LANGUAGE OverloadedStrings #-}

module Global.Event (
    globalEventHandler,
    eventHandler,
    matchesDirectory,
) where

import Control.Concurrent.STM
import Data.Aeson (Value (..), encode)
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString.Builder (lazyByteString, string8)
import Data.Text (Text)
import Data.Text.Encoding (decodeUtf8)
import Network.HTTP.Types (status200)
import Network.Wai (Application, queryString, responseStream)
import Servant (Handler, Tagged (..))
import State

-- | SSE Handler for /global/event - returns all events wrapped with directory
globalEventHandler :: AppState -> Tagged Handler Application
globalEventHandler state = Tagged $ \_ respond' -> do
    chan <- atomically $ dupTChan (stEventChan state)

    respond'
        $ responseStream
            status200
            [("Content-Type", "text/event-stream"), ("Cache-Control", "no-cache")]
        $ \send flush -> do
            send $ string8 "data: {\"type\":\"server.connected\",\"properties\":{}}\n\n"
            flush

            let loop = do
                    val <- atomically $ readTChan chan
                    send $ string8 "data: "
                    send $ lazyByteString (encode val)
                    send $ string8 "\n\n"
                    flush
                    loop
            loop

-- | SSE Handler for /event - accepts optional directory query param to filter events
eventHandler :: AppState -> Tagged Handler Application
eventHandler state = Tagged $ \req respond' -> do
    -- Parse directory query param
    let mDirectory = lookup "directory" (queryString req) >>= id >>= Just . decodeUtf8
    
    chan <- atomically $ dupTChan (stEventChan state)

    respond'
        $ responseStream
            status200
            [("Content-Type", "text/event-stream"), ("Cache-Control", "no-cache")]
        $ \send flush -> do
            send $ string8 "data: {\"type\":\"server.connected\",\"properties\":{}}\n\n"
            flush

            let loop = do
                    val <- atomically $ readTChan chan
                    -- Filter by directory if specified
                    let shouldSend = case mDirectory of
                            Nothing -> True
                            Just dir -> matchesDirectory dir val
                    if shouldSend
                        then do
                            send $ string8 "data: "
                            send $ lazyByteString (encode val)
                            send $ string8 "\n\n"
                            flush
                        else pure ()
                    loop
            loop

-- | Check if an event matches the specified directory
matchesDirectory :: Text -> Value -> Bool
matchesDirectory dir (Object obj) = case KM.lookup "directory" obj of
    Just (String d) -> d == dir
    _ -> True -- If no directory field, include the event
matchesDirectory _ _ = True
