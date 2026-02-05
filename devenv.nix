{ pkgs, ... }:

{
  # https://devenv.sh/packages/
  packages = with pkgs; [
    convos
    air
    gopls
    pnpm
    rlwrap
    sqlite-interactive
    sqlx-cli
  ];
  languages.go = {
    enable = true;
  };
  processes = {
    dev.exec = "task dev";
  };
  services.postgres = {
    enable = true;
    initialDatabases = [ { name = "tabdog"; } ];
  };

}
