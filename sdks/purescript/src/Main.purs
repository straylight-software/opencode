-- | Weapon PureScript SDK Demo CLI
-- |
-- | A simple CLI to demonstrate the SDK capabilities.
module Main where

import Prelude

import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.String as String
import Effect (Effect)
import Control.Monad.Rec.Class (forever)
import Effect.Aff (Aff, launchAff_, delay, Milliseconds(..))
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import Effect.Ref as Ref
import Weapon (Config, Event(..), Session, SessionId(..), defaultConfig, configUrl)
import Weapon.Client as Client
import Weapon.WebSocket as WS

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

main :: Effect Unit
main = launchAff_ do
  Console.log ""
  Console.log "  ╔═══════════════════════════════════════════════════════════╗"
  Console.log "  ║              Weapon PureScript SDK Demo                   ║"
  Console.log "  ╚═══════════════════════════════════════════════════════════╝"
  Console.log ""
  
  -- Try to connect to the server
  Console.log $ "Connecting to " <> configUrl defaultConfig <> "..."
  Console.log ""
  
  healthResult <- Client.healthCheck defaultConfig
  case healthResult of
    Left err -> do
      Console.log $ "  Error: Could not connect to Weapon server"
      Console.log $ "  " <> show err
      Console.log ""
      Console.log "  Make sure the Weapon server is running:"
      Console.log "    nix run .#serve"
      Console.log ""
    Right health -> do
      Console.log $ "  Connected to Weapon server v" <> health.version
      Console.log ""
      runDemo defaultConfig

--------------------------------------------------------------------------------
-- Demo
--------------------------------------------------------------------------------

runDemo :: Config -> Aff Unit
runDemo cfg = do
  -- List sessions
  Console.log "  Fetching sessions..."
  sessionsResult <- Client.listSessions cfg
  case sessionsResult of
    Left err -> Console.log $ "  Error fetching sessions: " <> show err
    Right sessions -> do
      Console.log $ "  Found " <> show (Array.length sessions) <> " sessions:"
      Console.log ""
      printSessions sessions
  
  Console.log ""
  Console.log "  Subscribing to events (press Ctrl+C to exit)..."
  Console.log ""
  
  -- Subscribe to events
  es <- WS.connect cfg Nothing
  
  eventCount <- liftEffect $ Ref.new 0
  
  liftEffect $ WS.subscribe es
    { onEvent: \evt -> do
        count <- Ref.modify (_ + 1) eventCount
        Console.log $ "  [Event #" <> show count <> "] " <> eventSummary evt
    , onError: \err -> do
        Console.log $ "  [Error] " <> err
    , onOpen: do
        Console.log "  [Connected] Event stream opened"
    }
  
  -- Keep the connection alive
  forever $ delay (Milliseconds 1000.0)

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

printSessions :: Array Session -> Aff Unit
printSessions sessions = do
  let sorted = Array.sortBy (comparing (_.time.updated)) sessions
  for_ (Array.reverse sorted) \session -> do
    Console.log $ "    • " <> truncate 50 session.title
    Console.log $ "      ID: " <> unwrapSessionId session.id
    Console.log ""
  where
    for_ arr f = Array.foldRecM (\_ x -> f x) unit arr

unwrapSessionId :: SessionId -> String
unwrapSessionId (SessionId s) = s

truncate :: Int -> String -> String
truncate n s =
  if String.length s > n
    then String.take (n - 3) s <> "..."
    else s

eventSummary :: Event -> String
eventSummary = case _ of
  SessionCreated { session } -> "Session created: " <> session.title
  SessionUpdated { session } -> "Session updated: " <> session.title
  SessionDeleted { sessionID } -> "Session deleted: " <> unwrapSessionId sessionID
  SessionStatus { sessionID, status } -> "Session " <> unwrapSessionId sessionID <> " status: " <> status
  SessionIdle { sessionID } -> "Session idle: " <> unwrapSessionId sessionID
  SessionError { sessionID, error } -> "Session error: " <> error
  MessageUpdated { sessionID } -> "Message updated in " <> unwrapSessionId sessionID
  MessageRemoved { sessionID, messageID } -> "Message removed"
  MessagePartUpdated {} -> "Message part updated"
  PermissionAsked { tool } -> "Permission requested for: " <> tool
  PermissionReplied { allowed } -> "Permission " <> if allowed then "granted" else "denied"
  QuestionAsked { question } -> "Question: " <> truncate 40 question
  QuestionReplied { answer } -> "Answer received"
  TodoUpdated { todos } -> "Todos updated (" <> show (Array.length todos) <> " items)"
  ServerConnected -> "Server connected"
  UnknownEvent { type_ } -> "Unknown event: " <> type_

comparing :: forall a b. Ord b => (a -> b) -> a -> a -> Ordering
comparing f x y = compare (f x) (f y)
