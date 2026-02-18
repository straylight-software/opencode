{-# LANGUAGE OverloadedStrings #-}

module Integration.WaiDebugTest (debugTest) where

import Api (api)
import Handlers (server)
import State (initialState)
import Log qualified
import Network.Wai
import Network.Wai.Test
import Network.HTTP.Types
import System.Directory (createDirectoryIfMissing, getCurrentDirectory)
import System.FilePath ((</>))
import Data.Text qualified as T
import Data.ByteString.Lazy qualified as LBS
import Servant (serve)

debugTest :: IO ()
debugTest = do
    cwd <- getCurrentDirectory
    let storageDir = cwd </> ".opencode-test" </> "wai-debug"
    createDirectoryIfMissing True storageDir
    logger <- Log.newLogger "debug"
    state <- initialState storageDir "test_project" (T.pack cwd) logger
    let app = serve api (server state)
    
    -- Test the health endpoint
    let req = SRequest defaultRequest { requestMethod = "GET", rawPathInfo = "/global/health" } ""
    response <- runSession (srequest req) app
    putStrLn $ "Status: " ++ show (simpleStatus response)
    putStrLn $ "Body: " ++ show (LBS.take 500 $ simpleBody response)
