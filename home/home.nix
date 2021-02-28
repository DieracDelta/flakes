{ config, pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "20.09";

  programs.git = {
    enable = true;
    userName = "Justin Restivo";
    userEmail = "justin.p.restivo@gmail.com";
    extraConfig = {
      url = { "ssh://git@github.com" = { insteadOf = "https://github.com"; }; };
      url = { "ssh://git@gitlab.com" = { insteadOf = "https://gitlab.com"; }; };
      url = {
        "ssh://git@bitbucket.org" = { insteadOf = "https://bitbucket.org"; };
      };
    };
  };

  /*morally speaking should automate this in the same way im doing modules*/
  imports = [
    ./zsh.nix
    ./nvim.nix
    ./xmonad/default.nix
    ./emacs.nix
    ./home_apps.nix
  ];

  # hunter config file
  # yes... we always want hunter
  xdg.configFile."hunter/keys".source = ./hunter_config;

  programs.tmux = {
    enable = true;
    historyLimit = 1000000;
    extraConfig = builtins.readFile ./tmux.conf;
    plugins = with pkgs; [
      {
        plugin = tmuxPlugins.gruvbox;
        extraConfig = "set -g @tmux-gruvbox 'dark'";
      }
    ];
  };


  /*programs.mbsync.enable = true;*/
  programs.neomutt.enable = true;
  programs.msmtp.enable = true;
  accounts.email.accounts.jrestivo = {
    /*getmail.enable = true;*/
    neomutt.enable = true;
    /*offlineimap.enable = true;*/
    passwordCommand = "cat /var/run/secrets/email_password";

    address = "justin@restivo.me";
    maildir.path = "justinsMail";
    folders = {
      inbox = "Inbox";
      sent = "Sent";
      drafts = "Drafts";
      trash = "Trash";
    };
    imap.host = "restivo.me";
    mbsync = {
        enable = true;
        create = "maildir";
    };
    primary = true;
    realName = "Justin Restivo";
    signature = {
        text = ''
          Draper Research Staff
          MIT SB '19 Meng '20
          Justin Restivo
          justin.restivo.me
        '';
        showSignature = "append";
      };
    smtp = {
      host = "restivo.me";
    };
    userName = "justin@restivo.me";
    msmtp.enable = true;
    /*notmuch.enable = true;*/

  };



  manual.html.enable = true;
}
