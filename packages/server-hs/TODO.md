# Haskell Server TODO

## Proxy / MITM

- [ ] **HTTPS CONNECT tunneling** - Currently returns 200 but doesn't actually MITM TLS traffic. Need dynamic cert generation signed by a CA that's injected into sandbox trust store.
- [ ] **SSE stream parsing** - Token counting only works for non-streaming responses. Need to parse `text/event-stream` responses and extract token usage from final `message_stop` events.
- [ ] **OpenRouter support** - Token parsing only handles Anthropic/OpenAI formats. OpenRouter has its own response format.
- [ ] **Request body truncation** - Large request bodies are truncated at 1MB. May miss context for debugging.
- [ ] **Proxy error handling** - `parseRequest` can throw on malformed URLs. Need better error responses.

## Sandbox

- [ ] **Simplify to unshare + overlay** - Current bwrap approach is heavy. Could use lighter `unshare --user --mount` with overlayfs like nix-lsp.sh does.
- [x] **Overlay commit** - `POST /pty/:id/commit` rsyncs sandbox upper/ to workdir.
- [x] **Get changed files** - `GET /pty/:id/changes` lists modified files in sandbox overlay.
- [ ] **Overlay snapshot** - No fork/snapshot support. Could tar the `upper/` dir for session branching.
- [ ] **bwrap PATH dependency** - Server only creates sandboxed PTYs if `bwrap` is in PATH. Should bundle or error clearly.
- [ ] **Network namespace** - Currently shares host network. Consider optional `--unshare-net` with slirp4netns for tighter isolation.

## PTY

- [ ] **posix-pty resize test** - `resizePty` is called but not verified working. Need test with actual terminal client.
- [ ] **WebSocket reconnection** - Cursor-based replay implemented but not tested with dropped connections.
- [ ] **PTY cleanup on server shutdown** - PTY processes may orphan if server crashes.
- [x] **Session ID injection** - `OPENCODE_SESSION_ID` env var injected into PTY for proxy correlation.

## Session / Message

- [ ] **Session fork** - Not implemented. Need to copy messages up to a point.
- [ ] **Session revert** - Not implemented. With sandbox overlay, this is just "kill PTY + discard overlay".
- [ ] **Message persistence** - Messages stored but not tested for large conversations.
- [ ] **Compaction** - No conversation summarization when context gets long.

## Provider / LLM

- [x] **Actual LLM calls** - `POST /chat` endpoint calls Anthropic API via `ANTHROPIC_API_KEY` env var.
- [ ] **Streaming** - No SSE streaming to client implemented.
- [ ] **Tool execution** - Agent tool calls not wired up.
- [ ] **Cost tracking** - Token usage logged but not aggregated or exposed via API.

## API

- [ ] **Auth** - No authentication. Anyone can hit the API.
- [ ] **Rate limiting** - No rate limits on any endpoint.
- [ ] **CORS** - Wide open (`*`). Fine for local, bad for deployment.

## Testing

- [ ] **Unit tests** - Zero. Need HSpec or similar.
- [ ] **Integration tests** - Manual curl only. Need automated test suite.
- [ ] **Proxy MITM test** - Only tested HTTP, not HTTPS.
- [ ] **Sandbox isolation test** - Not verified that writes actually go to overlay and not real fs.
- [ ] **WebSocket test** - Tested with websocat manually, no automated test.
- [ ] **Token parsing test** - No test with real Anthropic/OpenAI responses.

## Build / Deploy

- [ ] **Nix flake devShell** - bubblewrap added but not tested in `nix develop`.
- [ ] **Binary size** - ~5.8MB, could strip or optimize.
- [ ] **Systemd service** - No service file for deployment.
- [ ] **Config file** - All config hardcoded (ports, paths). Need TOML/YAML config.

## Code Quality

- [ ] **GHC warnings** - Many unused import warnings. Clean up.
- [ ] **Error types** - Using `Either Text a` everywhere. Should have proper error ADT.
- [ ] **Logging** - Only proxy logs. No general request logging or debug output.
- [ ] **Documentation** - Haddock comments sparse.
