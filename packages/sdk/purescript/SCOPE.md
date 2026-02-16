# PureScript SDK for OpenCode

## Overview

A PureScript client SDK for the OpenCode API, designed to complement the Haskell server implementation. The SDK will provide type-safe HTTP client bindings generated from the OpenAPI spec.

## Architecture

```
packages/sdk/purescript/
├── spago.yaml              # Package manifest
├── src/
│   ├── OpenCode/
│   │   ├── Client.purs     # Main client entry point
│   │   ├── Types.purs      # Core type definitions (generated)
│   │   ├── Api/
│   │   │   ├── Global.purs
│   │   │   ├── Auth.purs
│   │   │   ├── Project.purs
│   │   │   ├── Config.purs
│   │   │   ├── Session.purs
│   │   │   ├── Message.purs
│   │   │   ├── Permission.purs
│   │   │   ├── Question.purs
│   │   │   ├── Provider.purs
│   │   │   ├── File.purs
│   │   │   ├── Find.purs
│   │   │   ├── Pty.purs
│   │   │   ├── Tui.purs
│   │   │   ├── Tool.purs
│   │   │   └── Worktree.purs
│   │   ├── Events.purs     # SSE event types
│   │   └── Error.purs      # Error types
│   └── Gen/                # Generated code (if using codegen)
└── test/
    └── Main.purs
```

## Incremental Implementation Plan

### Phase 1: Foundation (Types + Basic Client)

**Goal:** Establish core infrastructure with minimal functionality

1. **Project Setup**
   - `spago.yaml` with dependencies: `aff`, `affjax`, `argonaut`, `maybe`, `either`
   - Basic module structure

2. **Core Types** (`Types.purs`)
   - Start with essential types that mirror the Haskell server:

   ```purescript
   -- Session types (matches server-hs/src/Session/Types.hs)
   type SessionTime = { created :: Number, updated :: Number, archived :: Maybe Number }
   type Session = { id :: String, slug :: String, projectID :: String, ... }

   -- Message types (matches server-hs/src/Message/Types.hs)
   type MessageInfo = { id :: String, sessionID :: String, role :: String, ... }
   ```

3. **Basic Client** (`Client.purs`)

   ```purescript
   type Config = { baseUrl :: String, directory :: Maybe String }

   createClient :: Config -> Client
   ```

4. **First Endpoints** (`Api/Global.purs`)
   - `GET /global/health` - simplest endpoint, good for testing
   - `GET /path` - returns path info

**Deliverable:** Can connect and call health check

### Phase 2: Session Management

**Goal:** Core session CRUD operations

1. **Session API** (`Api/Session.purs`)
   - `GET /session` - list sessions
   - `POST /session` - create session
   - `GET /session/{sessionID}` - get session
   - `DELETE /session/{sessionID}` - delete session
   - `PATCH /session/{sessionID}` - update session

2. **Message API** (`Api/Message.purs`)
   - `GET /session/{sessionID}/message` - list messages
   - `POST /session/{sessionID}/message` - send prompt (basic, no streaming yet)
   - `GET /session/{sessionID}/message/{messageID}` - get message

**Deliverable:** Can create sessions and send/receive messages

### Phase 3: Project & Config

1. **Project API** (`Api/Project.purs`)
   - `GET /project` - list projects
   - `GET /project/current` - get current project
   - `PATCH /project/{projectID}` - update project

2. **Config API** (`Api/Config.purs`)
   - `GET /config` - get config
   - `PATCH /config` - update config
   - `GET /config/providers` - list providers

### Phase 4: Interactive Features

1. **Permission API** (`Api/Permission.purs`)
   - `GET /permission` - list pending
   - `POST /permission/{requestID}/reply` - respond

2. **Question API** (`Api/Question.purs`)
   - `GET /question` - list pending
   - `POST /question/{requestID}/reply` - respond
   - `POST /question/{requestID}/reject` - reject

### Phase 5: Advanced Session Features

1. **Session Extensions**
   - `POST /session/{sessionID}/fork` - fork session
   - `POST /session/{sessionID}/abort` - abort
   - `POST /session/{sessionID}/share` - share
   - `DELETE /session/{sessionID}/share` - unshare
   - `POST /session/{sessionID}/revert` - revert
   - `POST /session/{sessionID}/unrevert` - unrevert
   - `GET /session/{sessionID}/diff` - get diff
   - `POST /session/{sessionID}/summarize` - summarize
   - `GET /session/{sessionID}/todo` - get todos

### Phase 6: File & Find

1. **File API** (`Api/File.purs`)
   - `GET /file` - list files
   - `GET /file/content` - read file content
   - `GET /file/status` - git status

2. **Find API** (`Api/Find.purs`)
   - `GET /find` - general find
   - `GET /find/file` - find files
   - `GET /find/symbol` - find symbols

### Phase 7: PTY (Terminal)

1. **Pty API** (`Api/Pty.purs`)
   - `GET /pty` - list
   - `POST /pty` - create
   - `GET /pty/{ptyID}` - get
   - `PUT /pty/{ptyID}` - update
   - `DELETE /pty/{ptyID}` - remove
   - `GET /pty/{ptyID}/connect` - WebSocket (requires separate handling)

### Phase 8: Events (SSE)

1. **Event Streaming** (`Events.purs`)
   - `GET /global/event` - SSE stream
   - `GET /event` - SSE stream
   - Event type discrimination (30+ event types)

### Phase 9: Remaining Endpoints

1. **Auth** - `PUT/DELETE /auth/{providerID}`
2. **Provider** - OAuth flows
3. **TUI** - Terminal UI control endpoints
4. **Tool** - Experimental tool endpoints
5. **Worktree** - Experimental git worktree

## Type Generation Strategy

### Option A: Manual Types (Recommended for Start)

Write types by hand, mirroring the Haskell types in `server-hs/src/`. This ensures:

- Type alignment with server
- Idiomatic PureScript patterns
- No codegen toolchain dependency

### Option B: OpenAPI Codegen (Future)

Use `purescript-openapi-generator` or similar to generate from `openapi.json`. Consider after manual types stabilize.

## Key Dependencies

```yaml
dependencies:
  - aff # Async effects
  - affjax # HTTP client
  - argonaut # JSON encoding/decoding
  - argonaut-codecs # Codec derivation
  - maybe
  - either
  - transformers # ReaderT for client context
  - web-events # For SSE (later)
```

## Design Patterns

### Client Pattern

```purescript
newtype Client = Client { baseUrl :: String, headers :: Object String }

runRequest :: forall a. Client -> Request a -> Aff (Either Error a)
```

### Endpoint Pattern

```purescript
-- Each endpoint module exports functions like:
module OpenCode.Api.Session where

list :: { directory :: Maybe String, limit :: Maybe Int } -> ClientM (Array Session)
create :: { title :: Maybe String } -> ClientM Session
get :: { sessionID :: String } -> ClientM Session
```

### Error Handling

```purescript
data OpenCodeError
  = BadRequest { message :: String }
  | NotFound { message :: String }
  | ApiError { statusCode :: Int, message :: String }
  | NetworkError AffjaxError
```

## Testing Strategy

1. **Unit tests** for JSON codecs (encode/decode roundtrip)
2. **Integration tests** against running server (optional, CI)
3. **Example scripts** demonstrating usage

## Milestones

| Phase                  | Endpoints | Est. Effort |
| ---------------------- | --------- | ----------- |
| 1. Foundation          | 2         | 1-2 days    |
| 2. Session             | 7         | 2-3 days    |
| 3. Project/Config      | 5         | 1-2 days    |
| 4. Permission/Question | 5         | 1 day       |
| 5. Advanced Session    | 9         | 2 days      |
| 6. File/Find           | 5         | 1 day       |
| 7. PTY                 | 6         | 2 days (WS) |
| 8. Events              | 2 (SSE)   | 2-3 days    |
| 9. Remaining           | ~15       | 2-3 days    |

**Total: ~15-20 days for full coverage**

## Open Questions

1. **Node vs Browser target?** Server-side (Node) most likely for CLI tooling
2. **Streaming responses?** `POST /session/{sessionID}/message` streams - need Aff streaming support
3. **WebSocket for PTY?** Requires separate WebSocket handling, not just HTTP
4. **SSE library choice?** May need custom implementation or `purescript-web-events`
5. **Share types with Haskell server?** Could generate both from shared schema

## Next Steps

1. Create `spago.yaml` and basic project structure
2. Implement Phase 1 (health check endpoint)
3. Validate against running server
4. Iterate through phases
