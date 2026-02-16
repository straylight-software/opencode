-- | HTTP Client for Weapon REST API
-- |
-- | Provides functions for interacting with the Weapon server via HTTP.
module Weapon.Client
  ( -- * Session Operations
    listSessions
  , getSession
  , createSession
  , deleteSession
  -- * Message Operations
  , listMessages
  , getMessage
  , sendPrompt
  , abortSession
  -- * Health & Config
  , healthCheck
  , getConfig
  -- * Low-level
  , request
  , ApiError(..)
  ) where

import Prelude

import Affjax (Error, printError)
import Affjax as Affjax
import Affjax.RequestBody as RequestBody
import Affjax.RequestHeader (RequestHeader(..))
import Affjax.ResponseFormat as ResponseFormat
import Affjax.StatusCode (StatusCode(..))
import Data.Argonaut (class DecodeJson, class EncodeJson, decodeJson, encodeJson, printJsonDecodeError)
import Data.Bifunctor (lmap)
import Data.Either (Either(..))
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Weapon.Types (Config, MessageId(..), PromptInput, Session, SessionId(..), Message, configUrl)

--------------------------------------------------------------------------------
-- Error Types
--------------------------------------------------------------------------------

data ApiError
  = NetworkError String
  | DecodeError String
  | HttpError Int String
  | ServerError String

instance Show ApiError where
  show (NetworkError e) = "NetworkError: " <> e
  show (DecodeError e) = "DecodeError: " <> e
  show (HttpError code msg) = "HttpError " <> show code <> ": " <> msg
  show (ServerError e) = "ServerError: " <> e

--------------------------------------------------------------------------------
-- Session Operations
--------------------------------------------------------------------------------

-- | List all sessions
listSessions :: Config -> Aff (Either ApiError (Array Session))
listSessions cfg = request cfg GET "/session" Nothing

-- | Get a specific session by ID
getSession :: Config -> SessionId -> Aff (Either ApiError Session)
getSession cfg (SessionId sid) = request cfg GET ("/session/" <> sid) Nothing

-- | Create a new session in the given directory
createSession :: Config -> String -> Aff (Either ApiError Session)
createSession cfg directory = 
  request cfg POST "/session" (Just $ encodeJson { directory })

-- | Delete a session
deleteSession :: Config -> SessionId -> Aff (Either ApiError Unit)
deleteSession cfg (SessionId sid) = 
  request cfg DELETE ("/session/" <> sid) Nothing

--------------------------------------------------------------------------------
-- Message Operations
--------------------------------------------------------------------------------

-- | List all messages in a session
listMessages :: Config -> SessionId -> Aff (Either ApiError (Array Message))
listMessages cfg (SessionId sid) = 
  request cfg GET ("/session/" <> sid <> "/message") Nothing

-- | Get a specific message
getMessage :: Config -> SessionId -> MessageId -> Aff (Either ApiError Message)
getMessage cfg (SessionId sid) (MessageId mid) =
  request cfg GET ("/session/" <> sid <> "/message/" <> mid) Nothing

-- | Send a prompt to a session (async - returns immediately)
sendPrompt :: Config -> SessionId -> PromptInput -> Aff (Either ApiError Unit)
sendPrompt cfg (SessionId sid) prompt =
  request cfg POST ("/session/" <> sid <> "/prompt_async") (Just $ encodeJson prompt)

-- | Abort the current operation in a session
abortSession :: Config -> SessionId -> Aff (Either ApiError Unit)
abortSession cfg (SessionId sid) =
  request cfg POST ("/session/" <> sid <> "/abort") Nothing

--------------------------------------------------------------------------------
-- Health & Config
--------------------------------------------------------------------------------

-- | Check server health
healthCheck :: Config -> Aff (Either ApiError { ok :: Boolean })
healthCheck cfg = request cfg GET "/global/health" Nothing

-- | Get server configuration
getConfig :: Config -> Aff (Either ApiError { directory :: String })
getConfig cfg = request cfg GET "/global/config" Nothing

--------------------------------------------------------------------------------
-- Low-level Request
--------------------------------------------------------------------------------

-- | Make an HTTP request to the Weapon server
request
  :: forall a
   . DecodeJson a
  => Config
  -> Method
  -> String
  -> Maybe Affjax.RequestBody.RequestBody
  -> Aff (Either ApiError a)
request cfg method path body = do
  result <- Affjax.request Affjax.defaultRequest
    { method = Left method
    , url = configUrl cfg <> path
    , responseFormat = ResponseFormat.json
    , content = body
    , headers = [ ContentType (Affjax.RequestHeader.MediaType "application/json") ]
    }
  pure $ case result of
    Left err -> Left (NetworkError $ printError err)
    Right response -> do
      let (StatusCode code) = response.status
      if code >= 200 && code < 300
        then lmap (DecodeError <<< printJsonDecodeError) $ decodeJson response.body
        else Left $ HttpError code ""
