-- | WebSocket client for Weapon event stream
-- |
-- | The Weapon server exposes real-time events via Server-Sent Events (SSE).
-- | This module provides a WebSocket-style interface for subscribing to events.
module Weapon.WebSocket
  ( -- * Connection
    EventSource
  , connect
  , disconnect
  , subscribe
  -- * Event Handling
  , EventHandler
  , onEvent
  , onError
  , onClose
  ) where

import Prelude

import Data.Argonaut (decodeJson, jsonParser, printJsonDecodeError)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Effect (Effect)
import Effect.Aff (Aff, makeAff, nonCanceler)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Effect.Ref (Ref)
import Effect.Ref as Ref
import Weapon.Types (Config, Event, configUrl)

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

-- | Opaque handle to an event source connection
foreign import data EventSource :: Type

-- | Handler for incoming events
type EventHandler = Event -> Effect Unit

-- | Handler for errors
type ErrorHandler = String -> Effect Unit

-- | Handler for connection close
type CloseHandler = Effect Unit

--------------------------------------------------------------------------------
-- FFI for EventSource (SSE)
--------------------------------------------------------------------------------

foreign import createEventSource :: String -> Effect EventSource

foreign import closeEventSource :: EventSource -> Effect Unit

foreign import addMessageListener :: EventSource -> (String -> Effect Unit) -> Effect Unit

foreign import addErrorListener :: EventSource -> (Effect Unit) -> Effect Unit

foreign import addOpenListener :: EventSource -> (Effect Unit) -> Effect Unit

--------------------------------------------------------------------------------
-- Connection
--------------------------------------------------------------------------------

-- | Connect to the Weapon event stream
connect :: Config -> Maybe String -> Aff EventSource
connect cfg directory = liftEffect do
  let url = configUrl cfg <> "/event" <> case directory of
        Nothing -> ""
        Just dir -> "?directory=" <> dir
  Console.log $ "Connecting to event stream: " <> url
  createEventSource url

-- | Disconnect from the event stream
disconnect :: EventSource -> Effect Unit
disconnect = closeEventSource

-- | Subscribe to events with handlers
subscribe
  :: EventSource
  -> { onEvent :: EventHandler
     , onError :: ErrorHandler
     , onOpen :: Effect Unit
     }
  -> Effect Unit
subscribe es handlers = do
  addMessageListener es \msg -> do
    case parseEvent msg of
      Left err -> handlers.onError $ "Failed to parse event: " <> err
      Right evt -> handlers.onEvent evt
  addErrorListener es (handlers.onError "Connection error")
  addOpenListener es handlers.onOpen
  where
    parseEvent :: String -> Either String Event
    parseEvent str = case jsonParser str of
      Left err -> Left err
      Right json -> case decodeJson json of
        Left err -> Left (printJsonDecodeError err)
        Right evt -> Right evt

--------------------------------------------------------------------------------
-- Convenience Functions
--------------------------------------------------------------------------------

-- | Set up event handler only
onEvent :: EventSource -> EventHandler -> Effect Unit
onEvent es handler = addMessageListener es \msg -> do
  case parseEvent msg of
    Left _ -> pure unit
    Right evt -> handler evt
  where
    parseEvent str = case jsonParser str of
      Left _ -> Left "parse error"
      Right json -> case decodeJson json of
        Left err -> Left (printJsonDecodeError err)
        Right evt -> Right evt

-- | Set up error handler only
onError :: EventSource -> ErrorHandler -> Effect Unit
onError es handler = addErrorListener es (handler "Connection error")

-- | Set up close handler only
onClose :: EventSource -> CloseHandler -> Effect Unit
onClose _ _ = pure unit -- EventSource doesn't have close event in same way
