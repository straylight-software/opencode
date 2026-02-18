{ mkDerivation, aeson, base, base64-bytestring, bytestring
, case-insensitive, containers, directory, fetchgit, hedgehog
, hspec, hspec-hedgehog, http-client, http-client-tls, http-media
, http-types, insert-ordered-containers, lib, openapi3
, optparse-applicative, regex-tdfa, scientific, tasty
, tasty-hedgehog, temporary, text, time, transformers, vector, wai
, wai-extra, yaml
}:
mkDerivation {
  pname = "haskemathesis";
  version = "0.1.0.0";
  src = fetchgit {
    url = "https://github.com/weyl-ai/haskemathesis";
    sha256 = "0jq621wgnbbw503lz1ibsl8qiqrrfmxhhip4kjdi2w9f7kbrslh9";
    rev = "6d37bbcd23a45026f383d24f6d38c5f7cc2752e3";
    fetchSubmodules = true;
  };
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson base base64-bytestring bytestring case-insensitive containers
    directory hedgehog hspec hspec-hedgehog http-client http-client-tls
    http-media http-types insert-ordered-containers openapi3
    optparse-applicative regex-tdfa scientific tasty tasty-hedgehog
    temporary text time vector wai wai-extra yaml
  ];
  executableHaskellDepends = [
    base bytestring hedgehog hspec http-client http-client-tls
    http-types openapi3 optparse-applicative tasty text time
    transformers wai
  ];
  testHaskellDepends = [
    aeson base base64-bytestring bytestring case-insensitive containers
    hedgehog hspec hspec-hedgehog http-types insert-ordered-containers
    openapi3 optparse-applicative regex-tdfa scientific text vector wai
  ];
  license = "unknown";
}
