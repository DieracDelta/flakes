{ lib, config, pkgs, ...}:
{

  programs.neovim.enable = true;
  programs.neovim.extraConfig = lib.readFile ./init.vim;
  programs.neovim.extraPython3Packages = (ps: with ps; [ jedi flake8 pep8 ]);
  programs.neovim.plugins = [
    pkgs.vimPlugins.fugitive
    pkgs.vimPlugins.vim-illuminate
    pkgs.vimPlugins.neodark-vim
    pkgs.vimPlugins.gitgutter
    pkgs.vimPlugins.rainbow
    pkgs.vimPlugins.fzf-vim
    pkgs.vimPlugins.fzfWrapper
    pkgs.vimPlugins.vim-better-whitespace
    pkgs.vimPlugins.vim-polyglot
    pkgs.vimPlugins.vim-surround
    pkgs.vimPlugins.vim-airline
    pkgs.vimPlugins.vim-gutentags
    pkgs.vimPlugins.bclose-vim
    pkgs.vimPlugins.indentLine
    pkgs.vimPlugins.nerdcommenter
    pkgs.vimPlugins.vim-speeddating
    pkgs.vimPlugins.vim-textobj-variable-segment
    pkgs.vimPlugins.vim-textobj-user
    pkgs.vimPlugins.vim-eunuch
    pkgs.vimPlugins.ultisnips
    pkgs.vimPlugins.vim-snippets
    pkgs.vimPlugins.vimtex
    pkgs.vimPlugins.delimitMate
    pkgs.vimPlugins.wal-vim
    pkgs.vimPlugins.coc-nvim
    pkgs.vimPlugins.coc-python
    pkgs.vimPlugins.coc-emmet
    pkgs.vimPlugins.vim-sandwich
    pkgs.vimPlugins.vim-addon-nix
  ];
  programs.neovim.viAlias = true;
  programs.neovim.vimAlias = true;
  programs.neovim.withNodeJs = true;
                #programs.neovim.withPython = true;
                programs.neovim.withPython3 = true;
                programs.neovim.withRuby = true;
}
