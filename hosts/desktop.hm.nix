{ ... }:
{
  imports = [ ../home/rmux.nix ];

  profiles = {
    emacs.enable = true;
    dev.enable = true;
    zsh.enable = true;
    vim.enable = true;
    xmonad.enable = true;
  };

  home.file.".config/baloofilerc".text = ''
    [Basic Settings]
    Indexing-Enabled=false
  '';
}
