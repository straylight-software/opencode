-- | Core types for Weapon SDK
-- |
-- | These are the hand-written types for the SDK interface.
-- | Generated types from OpenAPI go in Weapon.Generated.
module Weapon.Types where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson, Json, decodeJson, encodeJson, jsonParser, printJsonDecodeError)
import Data.Argonaut.Decode.Generic (genericDecodeJson)
import Data.Argonaut.Encode.Generic (genericEncodeJson)
import Data.Either (Either(..))
import Data.Generic.Rep (class Generic)
import Data.Maybe (Maybe)
import Data.Newtype (class Newtype)


--------------------------------------------------------------------------------
-- Client Config
--------------------------------------------------------------------------------

-- | Configuration for connecting to a Weapon server
type Config =
  { baseUrl :: String
  , port :: Int
  }

defaultConfig :: Config
defaultConfig =
  { baseUrl: "http://localhost"
  , port: 4096
  }

configUrl :: Config -> String
configUrl cfg = cfg.baseUrl <> ":" <> show cfg.port

--------------------------------------------------------------------------------
-- Session Types
--------------------------------------------------------------------------------

newtype SessionId = SessionId String

derive instance Newtype SessionId _
derive instance Generic SessionId _
derive newtype instance Eq SessionId
derive newtype instance Ord SessionId
derive newtype instance Show SessionId
instance EncodeJson SessionId where encodeJson (SessionId s) = encodeJson s
instance DecodeJson SessionId where decodeJson j = SessionId <$> decodeJson j

newtype MessageId = MessageId String

derive instance Newtype MessageId _
derive instance Generic MessageId _
derive newtype instance Eq MessageId
derive newtype instance Ord MessageId
derive newtype instance Show MessageId
instance EncodeJson MessageId where encodeJson (MessageId s) = encodeJson s
instance DecodeJson MessageId where decodeJson j = MessageId <$> decodeJson j

-- | A session in Weapon
type Session =
  { id :: SessionId
  , slug :: String
  , projectID :: String
  , directory :: String
  , title :: String
  , version :: String
  , parentID :: Maybe String
  , time :: SessionTime
  }

type SessionTime =
  { created :: Number
  , updated :: Number
  , compacting :: Maybe Number
  , archived :: Maybe Number
  }

--------------------------------------------------------------------------------
-- Message Types
--------------------------------------------------------------------------------

-- | Role of message sender
data Role = User | Assistant

derive instance Generic Role _
derive instance Eq Role
instance Show Role where
  show User = "user"
  show Assistant = "assistant"
instance EncodeJson Role where encodeJson = genericEncodeJson
instance DecodeJson Role where decodeJson = genericDecodeJson

-- | A message in a session
type Message =
  { id :: MessageId
  , sessionID :: SessionId
  , role :: Role
  , time :: MessageTime
  , parts :: Array Part
  }

type MessageTime =
  { created :: Number
  , completed :: Maybe Number
  }

--------------------------------------------------------------------------------
-- Part Types (message content)
--------------------------------------------------------------------------------

-- | Parts that make up a message
data Part
  = TextPart { text :: String }
  | ToolPart
      { id :: String
      , tool :: String
      , state :: ToolState
      , input :: Json
      , output :: Maybe Json
      }
  | ReasoningPart { text :: String }
  | FilePart { path :: String, content :: Maybe String }

derive instance Generic Part _
instance EncodeJson Part where encodeJson = genericEncodeJson
instance DecodeJson Part where decodeJson = genericDecodeJson

data ToolState
  = Pending
  | Running
  | Completed
  | Error

derive instance Generic ToolState _
derive instance Eq ToolState
instance Show ToolState where
  show Pending = "pending"
  show Running = "running"
  show Completed = "completed"
  show Error = "error"
instance EncodeJson ToolState where encodeJson = genericEncodeJson
instance DecodeJson ToolState where decodeJson = genericDecodeJson

--------------------------------------------------------------------------------
-- Event Types (WebSocket)
--------------------------------------------------------------------------------

-- | Events received from the Weapon server via WebSocket/SSE
data Event
  = SessionCreated { session :: Session }
  | SessionUpdated { session :: Session }
  | SessionDeleted { sessionID :: SessionId }
  | SessionStatus { sessionID :: SessionId, status :: String }
  | SessionIdle { sessionID :: SessionId }
  | SessionError { sessionID :: SessionId, error :: String }
  | MessageUpdated { sessionID :: SessionId, message :: Message }
  | MessageRemoved { sessionID :: SessionId, messageID :: MessageId }
  | MessagePartUpdated { sessionID :: SessionId, messageID :: MessageId, partID :: String, part :: Part }
  | PermissionAsked { requestID :: String, sessionID :: SessionId, tool :: String }
  | PermissionReplied { requestID :: String, allowed :: Boolean }
  | QuestionAsked { requestID :: String, sessionID :: SessionId, question :: String }
  | QuestionReplied { requestID :: String, answer :: Array String }
  | TodoUpdated { sessionID :: SessionId, todos :: Array Todo }
  | ServerConnected
  | UnknownEvent { type_ :: String, payload :: Json }

derive instance Generic Event _
instance EncodeJson Event where encodeJson = genericEncodeJson
instance DecodeJson Event where decodeJson = genericDecodeJson

type Todo =
  { id :: String
  , content :: String
  , status :: String
  , priority :: String
  }

--------------------------------------------------------------------------------
-- Prompt Types
--------------------------------------------------------------------------------

-- | Input for sending a prompt
type PromptInput =
  { parts :: Array PartInput
  }

data PartInput
  = TextInput { text :: String }
  | FileInput { path :: String }

derive instance Generic PartInput _
instance EncodeJson PartInput where encodeJson = genericEncodeJson
instance DecodeJson PartInput where decodeJson = genericDecodeJson

-- | Create a simple text prompt
textPrompt :: String -> PromptInput
textPrompt text = { parts: [ TextInput { text } ] }

--------------------------------------------------------------------------------
-- JSON Helpers
--------------------------------------------------------------------------------

parseEvent :: String -> Either String Event
parseEvent str = case jsonParser str of
  Left err -> Left err
  Right json -> case decodeJson json of
    Left err -> Left (printJsonDecodeError err)
    Right evt -> Right evt
