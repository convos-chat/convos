{
  pkgs ? import <nixpkgs> { },
}:

let
  perlEnv = pkgs.perl.withPackages (
    p: with p; [
      CryptPassphraseArgon2
      CryptEksblowfish
      CryptPassphrase
      CryptPassphraseBcrypt
      ModuleInstall
      FutureAsyncAwait
      FileHomeDir
      FileReadBackwards
      HTTPAcceptLanguage
      IRCUtils
      JSONValidator
      LinkEmbedder
      Mojolicious
      MojoliciousPluginSyslog
      MojoliciousPluginOpenAPI
      MojoliciousPluginWebpack
      ParseIRC
      SyntaxKeywordTry
      TextMarkdownHoedown
      TimePiece
      UnicodeUTF8
      IOSocketSSL
      TestDeep
      TestMore
    ]
  );
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    go
    perlEnv
    gopls
  ];

  shellHook = ''
    export CONVOS_HOME=$(pwd)/local/convos-dev
    mkdir -p $CONVOS_HOME
  '';
}
