{
  mkDerivation,
  aeson,
  base,
  base64-bytestring,
  bytestring,
  case-insensitive,
  containers,
  crypton-connection,
  data-default-class,
  directory,
  filepath,
  haskemathesis,
  hedgehog,
  hspec,
  hspec-core,
  hspec-hedgehog,
  http-client,
  http-client-tls,
  http-types,
  katip,
  lib,
  mtl,
  network,
  openapi3,
  posix-pty,
  process,
  random,
  regex-pcre,
  servant,
  servant-server,
  stm,
  tasty,
  tasty-hedgehog,
  tasty-hspec,
  temporary,
  text,
  time,
  tls,
  transformers,
  unix,
  unliftio-core,
  unordered-containers,
  wai,
  wai-extra,
  wai-websockets,
  warp,
  websockets,
}:
mkDerivation {
  pname = "opencode-server";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson
    base
    base64-bytestring
    bytestring
    case-insensitive
    containers
    crypton-connection
    data-default-class
    directory
    filepath
    http-client
    http-client-tls
    http-types
    katip
    mtl
    network
    posix-pty
    process
    random
    servant
    servant-server
    stm
    text
    time
    tls
    unix
    unliftio-core
    wai
    wai-websockets
    warp
    websockets
  ];
  executableHaskellDepends = [
    aeson
    base
    bytestring
    containers
    directory
    filepath
    http-types
    katip
    process
    servant-server
    stm
    text
    time
    wai
    wai-websockets
    warp
    websockets
  ];
  testHaskellDepends = [
    aeson
    base
    base64-bytestring
    bytestring
    containers
    directory
    filepath
    haskemathesis
    hedgehog
    hspec
    hspec-core
    hspec-hedgehog
    http-client
    http-client-tls
    http-types
    katip
    openapi3
    process
    regex-pcre
    servant
    servant-server
    stm
    tasty
    tasty-hedgehog
    tasty-hspec
    temporary
    text
    transformers
    unix
    unordered-containers
    wai
    wai-extra
  ];
  description = "OpenCode Haskell Server";
  license = lib.licenses.mit;
  mainProgram = "opencode-server";
  # Disable tests for now - some are environment-dependent
  doCheck = false;
}
