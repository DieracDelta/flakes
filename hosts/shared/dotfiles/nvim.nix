{ config, pkgs, ... }:
{
  xdg.configFile."nvim/coc-settings.json".source = ./coc-settings.json;
  programs.neovim.enable = true;
  programs.neovim.package = pkgs.neovim-nightly;
  programs.neovim.extraConfig = builtins.readFile ./init.vim;
  programs.neovim.extraPython3Packages = (ps: with ps; [ jedi flake8 pep8 ]);
  programs.neovim.plugins = with pkgs.vimPlugins; [
    fugitive
    vim-illuminate
    neodark-vim
    gitgutter
    rainbow
    fzf-vim
    fzfWrapper
    vim-better-whitespace
    vim-polyglot
    vim-surround
    vim-airline
    vim-gutentags
    bclose-vim
    indentLine
    nerdcommenter
    vim-speeddating
    vim-textobj-variable-segment
    vim-textobj-user
    vim-eunuch
    ultisnips
    vim-snippets
    vimtex
    delimitMate
    wal-vim
    vim-sandwich
    vim-addon-nix
    coc-nvim
    coc-python
    coc-emmet
    /*pkgset.unstable-pkgs.*/
    /*vimPlugins.coc-diagnostic*/
  ];
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;
  programs.neovim.withNodeJs = true;
  programs.neovim.withPython3 = true;
  programs.neovim.withRuby = true;
}
