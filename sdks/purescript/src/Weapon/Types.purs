-- | Core types for Weapon SDK
-- |
-- | Types matching the Weapon server OpenAPI spec.
module Weapon.Types where

import Prelude

import Data.Argonaut (class DecodeJson, class EncodeJson, Json, JsonDecodeError(..), decodeJson, encodeJson, jsonParser, printJsonDecodeError, stringify)
import Data.Argonaut.Core (toObject)
import Data.Argonaut.Decode.Decoders (decodeString, decodeNumber, decodeArray, decodeBoolean, decodeMaybe)
import Data.Either (Either(..), note)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Foreign.Object as Object


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
derive newtype instance Eq SessionId
derive newtype instance Ord SessionId
derive newtype instance Show SessionId
instance EncodeJson SessionId where encodeJson (SessionId s) = encodeJson s
instance DecodeJson SessionId where decodeJson j = SessionId <$> decodeJson j

newtype MessageId = MessageId String

derive instance Newtype MessageId _
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

derive instance Eq Role
instance Show Role where
  show User = "user"
  show Assistant = "assistant"
instance EncodeJson Role where 
  encodeJson User = encodeJson "user"
  encodeJson Assistant = encodeJson "assistant"
instance DecodeJson Role where 
  decodeJson json = do
    str <- decodeJson json
    case str of
      "user" -> Right User
      "assistant" -> Right Assistant
      other -> Left (UnexpectedValue json)

-- | A message in a session
type Message =
  { id :: MessageId
  , sessionID :: SessionId
  , role :: Role
  , time :: MessageTime
  , modelID :: Maybe String
  , providerID :: Maybe String
  , cost :: Maybe Number
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

instance EncodeJson Part where
  encodeJson (TextPart r) = encodeJson { type: "text", text: r.text }
  encodeJson (ToolPart r) = encodeJson { type: "tool", id: r.id, tool: r.tool, state: r.state, input: r.input, output: r.output }
  encodeJson (ReasoningPart r) = encodeJson { type: "reasoning", text: r.text }
  encodeJson (FilePart r) = encodeJson { type: "file", path: r.path, content: r.content }

instance DecodeJson Part where
  decodeJson json = do
    obj <- note (TypeMismatch "Object") (toObject json)
    typeJson <- note (AtKey "type" MissingValue) (Object.lookup "type" obj)
    typ <- decodeString typeJson
    case typ of
      "text" -> do
        textJson <- note (AtKey "text" MissingValue) (Object.lookup "text" obj)
        text <- decodeString textJson
        Right (TextPart { text })
      "tool" -> do
        idJson <- note (AtKey "id" MissingValue) (Object.lookup "id" obj)
        id <- decodeString idJson
        toolJson <- note (AtKey "tool" MissingValue) (Object.lookup "tool" obj)
        tool <- decodeString toolJson
        stateJson <- note (AtKey "state" MissingValue) (Object.lookup "state" obj)
        state <- decodeJson stateJson
        let input = Object.lookup "input" obj # \m -> case m of
              Just i -> i
              Nothing -> encodeJson {}
        let output = Object.lookup "output" obj
        Right (ToolPart { id, tool, state, input, output })
      "reasoning" -> do
        textJson <- note (AtKey "text" MissingValue) (Object.lookup "text" obj)
        text <- decodeString textJson
        Right (ReasoningPart { text })
      "file" -> do
        pathJson <- note (AtKey "path" MissingValue) (Object.lookup "path" obj)
        path <- decodeString pathJson
        let content = case Object.lookup "content" obj of
              Just c -> case decodeString c of
                Right s -> Just s
                Left _ -> Nothing
              Nothing -> Nothing
        Right (FilePart { path, content })
      other -> Left (AtKey "type" (UnexpectedValue typeJson))

data ToolState
  = Pending
  | Running
  | Completed
  | Error

derive instance Eq ToolState
instance Show ToolState where
  show Pending = "pending"
  show Running = "running"
  show Completed = "completed"
  show Error = "error"
instance EncodeJson ToolState where 
  encodeJson s = encodeJson (show s)
instance DecodeJson ToolState where 
  decodeJson json = do
    str <- decodeJson json
    case str of
      "pending" -> Right Pending
      "running" -> Right Running
      "completed" -> Right Completed
      "error" -> Right Error
      _ -> Left (UnexpectedValue json)

--------------------------------------------------------------------------------
-- Event Types (SSE)
--------------------------------------------------------------------------------

-- | Events received from the Weapon server via SSE
-- | Format: { type: "event.type", properties: { ... } }
data Event
  = ServerConnected
  | SessionCreated { info :: Session }
  | SessionUpdated { info :: Session }
  | SessionDeleted { sessionID :: SessionId }
  | SessionStatus { sessionID :: SessionId, status :: String }
  | SessionIdle { sessionID :: SessionId }
  | SessionError { sessionID :: SessionId, error :: Json }
  | MessageUpdated { info :: Message }
  | MessageRemoved { sessionID :: SessionId, messageID :: MessageId }
  | MessagePartUpdated { sessionID :: SessionId, messageID :: MessageId, partIndex :: Int, part :: Part }
  | MessagePartRemoved { sessionID :: SessionId, messageID :: MessageId, partIndex :: Int }
  | PermissionAsked { sessionID :: SessionId, permissions :: Array PermissionRequest }
  | PermissionReplied { sessionID :: SessionId }
  | QuestionAsked { sessionID :: SessionId, question :: Question }
  | QuestionReplied { sessionID :: SessionId }
  | QuestionRejected { sessionID :: SessionId }
  | TodoUpdated { sessionID :: SessionId, todos :: Array Todo }
  | ProjectUpdated { projectID :: String }
  | UnknownEvent { eventType :: String, properties :: Json }

-- Note: Event equality only used for Show derivation, not runtime comparison
-- We skip Eq for Event since Part contains Json which has no Eq instance

instance Show Event where
  show ServerConnected = "ServerConnected"
  show (SessionCreated r) = "SessionCreated " <> show r.info.id
  show (SessionUpdated r) = "SessionUpdated " <> show r.info.id
  show (SessionDeleted r) = "SessionDeleted " <> show r.sessionID
  show (SessionStatus r) = "SessionStatus " <> show r.sessionID <> " " <> r.status
  show (SessionIdle r) = "SessionIdle " <> show r.sessionID
  show (SessionError r) = "SessionError " <> show r.sessionID
  show (MessageUpdated r) = "MessageUpdated " <> show r.info.id
  show (MessageRemoved r) = "MessageRemoved " <> show r.messageID
  show (MessagePartUpdated r) = "MessagePartUpdated " <> show r.messageID
  show (MessagePartRemoved r) = "MessagePartRemoved " <> show r.messageID
  show (PermissionAsked r) = "PermissionAsked " <> show r.sessionID
  show (PermissionReplied r) = "PermissionReplied " <> show r.sessionID
  show (QuestionAsked r) = "QuestionAsked " <> show r.sessionID
  show (QuestionReplied r) = "QuestionReplied " <> show r.sessionID
  show (QuestionRejected r) = "QuestionRejected " <> show r.sessionID
  show (TodoUpdated r) = "TodoUpdated " <> show r.sessionID
  show (ProjectUpdated r) = "ProjectUpdated " <> r.projectID
  show (UnknownEvent r) = "UnknownEvent " <> r.eventType

instance DecodeJson Event where
  decodeJson json = do
    obj <- note (TypeMismatch "Object") (toObject json)
    typeJson <- note (AtKey "type" MissingValue) (Object.lookup "type" obj)
    eventType <- decodeString typeJson
    propsJson <- note (AtKey "properties" MissingValue) (Object.lookup "properties" obj)
    props <- note (TypeMismatch "Object") (toObject propsJson)
    decodeEventByType eventType props propsJson

decodeEventByType :: String -> Object.Object Json -> Json -> Either JsonDecodeError Event
decodeEventByType eventType props propsJson = case eventType of
  "server.connected" -> Right ServerConnected
  
  "session.created" -> do
    infoJson <- note (AtKey "info" MissingValue) (Object.lookup "info" props)
    info <- decodeSession infoJson
    Right (SessionCreated { info })
  
  "session.updated" -> do
    infoJson <- note (AtKey "info" MissingValue) (Object.lookup "info" props)
    info <- decodeSession infoJson
    Right (SessionUpdated { info })
  
  "session.deleted" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    Right (SessionDeleted { sessionID })
  
  "session.status" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    statusJson <- note (AtKey "status" MissingValue) (Object.lookup "status" props)
    status <- decodeString statusJson
    Right (SessionStatus { sessionID, status })
  
  "session.idle" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    Right (SessionIdle { sessionID })
  
  "session.error" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    let error = case Object.lookup "error" props of
          Just e -> e
          Nothing -> encodeJson {}
    Right (SessionError { sessionID, error })
  
  "message.updated" -> do
    infoJson <- note (AtKey "info" MissingValue) (Object.lookup "info" props)
    info <- decodeMessage infoJson
    Right (MessageUpdated { info })
  
  "message.removed" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    midJson <- note (AtKey "messageID" MissingValue) (Object.lookup "messageID" props)
    messageID <- MessageId <$> decodeString midJson
    Right (MessageRemoved { sessionID, messageID })
  
  "message.part.updated" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    midJson <- note (AtKey "messageID" MissingValue) (Object.lookup "messageID" props)
    messageID <- MessageId <$> decodeString midJson
    idxJson <- note (AtKey "partIndex" MissingValue) (Object.lookup "partIndex" props)
    partIndex <- decodeInt idxJson
    partJson <- note (AtKey "part" MissingValue) (Object.lookup "part" props)
    part <- decodeJson partJson
    Right (MessagePartUpdated { sessionID, messageID, partIndex, part })
  
  "message.part.removed" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    midJson <- note (AtKey "messageID" MissingValue) (Object.lookup "messageID" props)
    messageID <- MessageId <$> decodeString midJson
    idxJson <- note (AtKey "partIndex" MissingValue) (Object.lookup "partIndex" props)
    partIndex <- decodeInt idxJson
    Right (MessagePartRemoved { sessionID, messageID, partIndex })
  
  "permission.asked" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    permsJson <- note (AtKey "permissions" MissingValue) (Object.lookup "permissions" props)
    permissions <- decodeArray decodePermissionRequest permsJson
    Right (PermissionAsked { sessionID, permissions })
  
  "permission.replied" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    Right (PermissionReplied { sessionID })
  
  "question.asked" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    qJson <- note (AtKey "question" MissingValue) (Object.lookup "question" props)
    question <- decodeQuestion qJson
    Right (QuestionAsked { sessionID, question })
  
  "question.replied" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    Right (QuestionReplied { sessionID })
  
  "question.rejected" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    Right (QuestionRejected { sessionID })
  
  "todo.updated" -> do
    sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" props)
    sessionID <- SessionId <$> decodeString sidJson
    todosJson <- note (AtKey "todos" MissingValue) (Object.lookup "todos" props)
    todos <- decodeArray decodeTodo todosJson
    Right (TodoUpdated { sessionID, todos })
  
  "project.updated" -> do
    pidJson <- note (AtKey "projectID" MissingValue) (Object.lookup "projectID" props)
    projectID <- decodeString pidJson
    Right (ProjectUpdated { projectID })
  
  _ -> Right (UnknownEvent { eventType, properties: propsJson })

instance EncodeJson Event where
  encodeJson evt = encodeJson { type: eventTypeStr evt, properties: eventProps evt }
    where
      eventTypeStr = case _ of
        ServerConnected -> "server.connected"
        SessionCreated _ -> "session.created"
        SessionUpdated _ -> "session.updated"
        SessionDeleted _ -> "session.deleted"
        SessionStatus _ -> "session.status"
        SessionIdle _ -> "session.idle"
        SessionError _ -> "session.error"
        MessageUpdated _ -> "message.updated"
        MessageRemoved _ -> "message.removed"
        MessagePartUpdated _ -> "message.part.updated"
        MessagePartRemoved _ -> "message.part.removed"
        PermissionAsked _ -> "permission.asked"
        PermissionReplied _ -> "permission.replied"
        QuestionAsked _ -> "question.asked"
        QuestionReplied _ -> "question.replied"
        QuestionRejected _ -> "question.rejected"
        TodoUpdated _ -> "todo.updated"
        ProjectUpdated _ -> "project.updated"
        UnknownEvent r -> r.eventType
      eventProps = case _ of
        ServerConnected -> encodeJson {}
        SessionCreated r -> encodeJson { info: r.info }
        SessionUpdated r -> encodeJson { info: r.info }
        SessionDeleted r -> encodeJson { sessionID: r.sessionID }
        SessionStatus r -> encodeJson { sessionID: r.sessionID, status: r.status }
        SessionIdle r -> encodeJson { sessionID: r.sessionID }
        SessionError r -> encodeJson { sessionID: r.sessionID, error: r.error }
        MessageUpdated r -> encodeJson { info: r.info }
        MessageRemoved r -> encodeJson { sessionID: r.sessionID, messageID: r.messageID }
        MessagePartUpdated r -> encodeJson { sessionID: r.sessionID, messageID: r.messageID, partIndex: r.partIndex, part: r.part }
        MessagePartRemoved r -> encodeJson { sessionID: r.sessionID, messageID: r.messageID, partIndex: r.partIndex }
        PermissionAsked r -> encodeJson { sessionID: r.sessionID, permissions: r.permissions }
        PermissionReplied r -> encodeJson { sessionID: r.sessionID }
        QuestionAsked r -> encodeJson { sessionID: r.sessionID, question: r.question }
        QuestionReplied r -> encodeJson { sessionID: r.sessionID }
        QuestionRejected r -> encodeJson { sessionID: r.sessionID }
        TodoUpdated r -> encodeJson { sessionID: r.sessionID, todos: r.todos }
        ProjectUpdated r -> encodeJson { projectID: r.projectID }
        UnknownEvent r -> r.properties

--------------------------------------------------------------------------------
-- Supporting Types
--------------------------------------------------------------------------------

type Todo =
  { id :: String
  , content :: String
  , status :: String
  , priority :: String
  }

decodeTodo :: Json -> Either JsonDecodeError Todo
decodeTodo json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  idJson <- note (AtKey "id" MissingValue) (Object.lookup "id" obj)
  id <- decodeString idJson
  contentJson <- note (AtKey "content" MissingValue) (Object.lookup "content" obj)
  content <- decodeString contentJson
  statusJson <- note (AtKey "status" MissingValue) (Object.lookup "status" obj)
  status <- decodeString statusJson
  priorityJson <- note (AtKey "priority" MissingValue) (Object.lookup "priority" obj)
  priority <- decodeString priorityJson
  Right { id, content, status, priority }

type PermissionRequest =
  { id :: String
  , tool :: String
  , input :: Json
  }

decodePermissionRequest :: Json -> Either JsonDecodeError PermissionRequest
decodePermissionRequest json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  idJson <- note (AtKey "id" MissingValue) (Object.lookup "id" obj)
  id <- decodeString idJson
  toolJson <- note (AtKey "tool" MissingValue) (Object.lookup "tool" obj)
  tool <- decodeString toolJson
  let input = case Object.lookup "input" obj of
        Just i -> i
        Nothing -> encodeJson {}
  Right { id, tool, input }

type Question =
  { id :: String
  , question :: String
  , options :: Array QuestionOption
  }

type QuestionOption =
  { label :: String
  , description :: Maybe String
  }

decodeQuestion :: Json -> Either JsonDecodeError Question
decodeQuestion json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  idJson <- note (AtKey "id" MissingValue) (Object.lookup "id" obj)
  id <- decodeString idJson
  qJson <- note (AtKey "question" MissingValue) (Object.lookup "question" obj)
  question <- decodeString qJson
  optsJson <- note (AtKey "options" MissingValue) (Object.lookup "options" obj)
  options <- decodeArray decodeQuestionOption optsJson
  Right { id, question, options }

decodeQuestionOption :: Json -> Either JsonDecodeError QuestionOption
decodeQuestionOption json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  labelJson <- note (AtKey "label" MissingValue) (Object.lookup "label" obj)
  label <- decodeString labelJson
  let description = case Object.lookup "description" obj of
        Just d -> case decodeString d of
          Right s -> Just s
          Left _ -> Nothing
        Nothing -> Nothing
  Right { label, description }

--------------------------------------------------------------------------------
-- Session/Message Decoders
--------------------------------------------------------------------------------

decodeSession :: Json -> Either JsonDecodeError Session
decodeSession json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  idJson <- note (AtKey "id" MissingValue) (Object.lookup "id" obj)
  id <- SessionId <$> decodeString idJson
  slugJson <- note (AtKey "slug" MissingValue) (Object.lookup "slug" obj)
  slug <- decodeString slugJson
  projJson <- note (AtKey "projectID" MissingValue) (Object.lookup "projectID" obj)
  projectID <- decodeString projJson
  dirJson <- note (AtKey "directory" MissingValue) (Object.lookup "directory" obj)
  directory <- decodeString dirJson
  titleJson <- note (AtKey "title" MissingValue) (Object.lookup "title" obj)
  title <- decodeString titleJson
  versionJson <- note (AtKey "version" MissingValue) (Object.lookup "version" obj)
  version <- decodeString versionJson
  let parentID = case Object.lookup "parentID" obj of
        Just p -> case decodeString p of
          Right s -> Just s
          Left _ -> Nothing
        Nothing -> Nothing
  timeJson <- note (AtKey "time" MissingValue) (Object.lookup "time" obj)
  time <- decodeSessionTime timeJson
  Right { id, slug, projectID, directory, title, version, parentID, time }

decodeSessionTime :: Json -> Either JsonDecodeError SessionTime
decodeSessionTime json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  createdJson <- note (AtKey "created" MissingValue) (Object.lookup "created" obj)
  created <- decodeNumber createdJson
  updatedJson <- note (AtKey "updated" MissingValue) (Object.lookup "updated" obj)
  updated <- decodeNumber updatedJson
  let compacting = case Object.lookup "compacting" obj of
        Just c -> case decodeNumber c of
          Right n -> Just n
          Left _ -> Nothing
        Nothing -> Nothing
  let archived = case Object.lookup "archived" obj of
        Just a -> case decodeNumber a of
          Right n -> Just n
          Left _ -> Nothing
        Nothing -> Nothing
  Right { created, updated, compacting, archived }

decodeMessage :: Json -> Either JsonDecodeError Message
decodeMessage json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  idJson <- note (AtKey "id" MissingValue) (Object.lookup "id" obj)
  id <- MessageId <$> decodeString idJson
  sidJson <- note (AtKey "sessionID" MissingValue) (Object.lookup "sessionID" obj)
  sessionID <- SessionId <$> decodeString sidJson
  roleJson <- note (AtKey "role" MissingValue) (Object.lookup "role" obj)
  role <- decodeJson roleJson
  timeJson <- note (AtKey "time" MissingValue) (Object.lookup "time" obj)
  time <- decodeMessageTime timeJson
  let modelID = case Object.lookup "modelID" obj of
        Just m -> case decodeString m of
          Right s -> Just s
          Left _ -> Nothing
        Nothing -> Nothing
  let providerID = case Object.lookup "providerID" obj of
        Just p -> case decodeString p of
          Right s -> Just s
          Left _ -> Nothing
        Nothing -> Nothing
  let cost = case Object.lookup "cost" obj of
        Just c -> case decodeNumber c of
          Right n -> Just n
          Left _ -> Nothing
        Nothing -> Nothing
  Right { id, sessionID, role, time, modelID, providerID, cost }

decodeMessageTime :: Json -> Either JsonDecodeError MessageTime
decodeMessageTime json = do
  obj <- note (TypeMismatch "Object") (toObject json)
  createdJson <- note (AtKey "created" MissingValue) (Object.lookup "created" obj)
  created <- decodeNumber createdJson
  let completed = case Object.lookup "completed" obj of
        Just c -> case decodeNumber c of
          Right n -> Just n
          Left _ -> Nothing
        Nothing -> Nothing
  Right { created, completed }

-- Helper to decode Int from Number
decodeInt :: Json -> Either JsonDecodeError Int
decodeInt json = do
  n <- decodeNumber json
  Right (floor n)
  where
    floor :: Number -> Int
    floor n = unsafeCoerce n

foreign import unsafeCoerce :: forall a b. a -> b

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

instance EncodeJson PartInput where 
  encodeJson (TextInput r) = encodeJson { type: "text", text: r.text }
  encodeJson (FileInput r) = encodeJson { type: "file", path: r.path }

instance DecodeJson PartInput where 
  decodeJson json = do
    obj <- note (TypeMismatch "Object") (toObject json)
    typeJson <- note (AtKey "type" MissingValue) (Object.lookup "type" obj)
    typ <- decodeString typeJson
    case typ of
      "text" -> do
        textJson <- note (AtKey "text" MissingValue) (Object.lookup "text" obj)
        text <- decodeString textJson
        Right (TextInput { text })
      "file" -> do
        pathJson <- note (AtKey "path" MissingValue) (Object.lookup "path" obj)
        path <- decodeString pathJson
        Right (FileInput { path })
      _ -> Left (AtKey "type" (UnexpectedValue typeJson))

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
