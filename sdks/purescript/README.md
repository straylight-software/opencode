# weapon-purescript

PureScript SDK for the Weapon AI coding agent.

## Overview

This SDK provides:

- **Type-safe API client** - Generated from OpenAPI spec via [zeitschrift](https://github.com/weyl-ai/zeitschrift)
- **WebSocket event stream** - Real-time events from the Weapon server (SSE)
- **CLI demo** - Simple example demonstrating SDK usage

## Quick Start

### With Nix (recommended)

```bash
# Enter development shell
nix develop

# Build the SDK
spago build

# Run the demo (requires a running Weapon server)
spago run
```

### Generate Types from OpenAPI

The SDK includes hand-written types for the core API. To regenerate types from the OpenAPI spec:

```bash
nix run .#generate
```

Or manually with zeitschrift:

```bash
zeitschrift codegen \
  --lang purescript \
  --input ../../packages/openapi/openapi.json \
  --output src/Weapon/Generated
```

## Usage

```purescript
import Prelude
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class.Console (log)
import Weapon

main :: Effect Unit
main = launchAff_ do
  -- Check server health
  result <- healthCheck defaultConfig
  case result of
    Left err -> log $ "Error: " <> show err
    Right _ -> log "Server is healthy!"

  -- List sessions
  sessionsResult <- listSessions defaultConfig
  case sessionsResult of
    Left err -> log $ "Error: " <> show err
    Right sessions -> do
      log $ "Found " <> show (length sessions) <> " sessions"
      for_ sessions \s -> log s.title

  -- Subscribe to events
  es <- connect defaultConfig Nothing
  subscribe es
    { onEvent: \evt -> log $ "Event: " <> show evt
    , onError: \err -> log $ "Error: " <> err
    , onOpen: log "Connected!"
    }
```

## API

### Client Functions

```purescript
-- Sessions
listSessions :: Config -> Aff (Either ApiError (Array Session))
getSession :: Config -> SessionId -> Aff (Either ApiError Session)
createSession :: Config -> String -> Aff (Either ApiError Session)
deleteSession :: Config -> SessionId -> Aff (Either ApiError Unit)

-- Messages
listMessages :: Config -> SessionId -> Aff (Either ApiError (Array Message))
getMessage :: Config -> SessionId -> MessageId -> Aff (Either ApiError Message)
sendPrompt :: Config -> SessionId -> PromptInput -> Aff (Either ApiError Unit)
abortSession :: Config -> SessionId -> Aff (Either ApiError Unit)

-- Health & Config
healthCheck :: Config -> Aff (Either ApiError { ok :: Boolean })
getConfig :: Config -> Aff (Either ApiError { directory :: String })
```

### WebSocket Functions

```purescript
-- Connection
connect :: Config -> Maybe String -> Aff EventSource
disconnect :: EventSource -> Effect Unit

-- Event handling
subscribe :: EventSource -> EventHandlers -> Effect Unit
onEvent :: EventSource -> (Event -> Effect Unit) -> Effect Unit
onError :: EventSource -> (String -> Effect Unit) -> Effect Unit
```

### Types

```purescript
type Config =
  { baseUrl :: String
  , port :: Int
  }

defaultConfig :: Config
defaultConfig = { baseUrl: "http://localhost", port: 4096 }

newtype SessionId = SessionId String
newtype MessageId = MessageId String

data Event
  = SessionCreated { session :: Session }
  | SessionUpdated { session :: Session }
  | SessionDeleted { sessionID :: SessionId }
  | MessageUpdated { sessionID :: SessionId, message :: Message }
  | PermissionAsked { requestID :: String, tool :: String }
  | QuestionAsked { requestID :: String, question :: String }
  | ...
```

## Development

```bash
# Build
spago build

# Test
spago test

# Run demo
spago run

# Format code
purs-tidy format-in-place src/**/*.purs

# Build for Node.js
spago bundle --platform node --outfile dist/weapon.js
```

## Dependencies

- `prelude` - Standard library
- `aff` - Async effects
- `affjax` / `affjax-node` - HTTP client
- `argonaut` - JSON encoding/decoding
- `web-socket` - WebSocket support

## License

MIT
