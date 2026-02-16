-- | Weapon SDK for PureScript
-- |
-- | A PureScript client for the Weapon AI coding agent.
-- |
-- | ## Quick Start
-- |
-- | ```purescript
-- | import Weapon
-- | 
-- | main :: Effect Unit
-- | main = launchAff_ do
-- |   -- Check server health
-- |   result <- healthCheck defaultConfig
-- |   case result of
-- |     Left err -> log $ "Error: " <> show err
-- |     Right _ -> log "Server is healthy!"
-- |   
-- |   -- List sessions
-- |   sessions <- listSessions defaultConfig
-- |   traverse_ (log <<< _.title) sessions
-- | ```
module Weapon
  ( module Weapon.Types
  , module Weapon.Client
  , module Weapon.WebSocket
  ) where

import Weapon.Types
import Weapon.Client
import Weapon.WebSocket
