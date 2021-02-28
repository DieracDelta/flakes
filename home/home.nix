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


  programs.mbsync.enable = true;
  programs.notmuch = {
    enable = true;
  };
  programs.neomutt = {
    enable = true;
    sidebar.enable = true;
    sort = "threads";
    binds =
      let
        # Make a keybinding from the given values.
        mkBind = m: k: a: {
          action = a;
          key = k;
          map = m;
        };

        # Make bindings for each of the modes given.
        # This is needed since home-manager doesn't allow us to specify multiple
        # modes for a single binding like `index,pager` like (neo)mutt does.
        repBind = ms: k: a: map (m: mkBind m k a) ms;
      in
      /*(repBind [ "index" "pager" ] "I" "imap-fetch-mail")*/
      []
      ;

    macros = let
      # A convenience function to make a macro from the given arguments.
      mkMacro = m: k: a: {
        action = a;
        key = k;
        map = m;
      };

      # Make a macro for each of the given modes.
      # This is needed since home-manager doesn't allow us to specify multiple
      # modes for a single macro like `index,pager` like (neo)mutt does.
      repMacro = ms: k: a: map (m: mkMacro m k a) ms; in
      [(mkMacro "index" "I" "!mbsync -a^M")];

    vimKeys = true;
  };
  programs.msmtp.enable = true;
  /*programs.msmtp.enable = true;*/
  accounts.email.accounts.jrestivo = {
    imapnotify = {
      enable = true;
      boxes = [ "Inbox" ];
      onNotifyPost = {
        mail = ''
          ${pkgs.notmuch}/bin/notmuch new \*/
          && ${pkgs.libnotify}/bin/notify-send "New mail has arrived!"
          '';
      };
    };
    msmtp = {
      enable = true;
      extraConfig = {auth = "login"; };
    };

    smtp = {
      host = "mail.restivo.me";
      /*tls.enable = false;*/
    };
    imap = {
      host = "mail.restivo.me";
    };

    neomutt.enable = true;
    mbsync = {
      enable = true;
      create = "maildir";
    };
    notmuch.enable = true;
    /*offlineimap.enable = true;*/

    passwordCommand = "cat /var/run/secrets/email_password";
    address = "justin@restivo.me";
    folders = {
      inbox = "Inbox";
      sent = "Sent";
      drafts = "Drafts";
      trash = "Trash";
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
    userName = "justin@restivo.me";

  };



  manual.html.enable = true;
}
