{ config, pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "20.09";

  programs.git = {
    enable = true;
    userName = "Justin Restivo";
    userEmail = "justin@restivo.me";
    extraConfig = {
      url = { "ssh://git@github.com" = { insteadOf = "https://github.com"; }; };
      url = { "ssh://git@gitlab.com" = { insteadOf = "https://gitlab.com"; }; };
      url = {
        "ssh://git@bitbucket.org" = { insteadOf = "https://bitbucket.org"; };
      };
      github.user = "DieracDelta";
      tag.gpgSign = true;
    };
    # TODO turn this on
    signing.signByDefault = true;
    signing.key = "E68281EB2ABCE9B8";
  };



  programs.gpg = {
    enable = true;
    settings = {
      #pinentry-program = "${pkgs.pinentry}/bin/pinentry";
      #pinentryFlavor = "qt";
    };
  };
  services.gpg-agent = {
    /*enableScDaemon = true;*/
    enable = true;
    pinentryFlavor = "qt";
    enableSshSupport = true;
    defaultCacheTtlSsh = 36000;
    defaultCacheTtl = 36000;
    maxCacheTtlSsh = 36000;
    maxCacheTtl = 36000;
    sshKeys = [ "47FE9F64C6AD1CD29A0142BD96CD77C03DBCB1D4" ];
    extraConfig = ''
    allow-loopback-pinentry
    '';
  };

  home.file.".gnupg/sshgrips" = {
    recursive = true;
    source = ./sshgrips;
  };

  # gpg-agent
  #programs.gnupg.agent = {
    #enable = true;
    #enableSSHSupport = true;
    #pinentryFlavor = "curses";
  #};

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
    sidebar = {
      enable = true;
      shortPath = false;
      format = "%D%?F? [%F]?%* %?N?%N/?%S";
      width = 56;
    };
    extraConfig =
    let
      colorFile =
        "${pkgs.mutt-colors-solarized}/mutt-colors-solarized-dark-16.muttrc";
      findAllMailboxes =
        let
          # A script to take the paths to mail directories and turn them into
          # mailbox-name mailbox-path pairs for mutt.
          mkMailboxDescription = pkgs.writeScript "mailbox-description.pl" ''
            #!${pkgs.perl}/bin/perl
            BEGIN {
              $basepath = q{${config.accounts.email.maildirBasePath}/}
            }
            while (<>) {
              chomp;
              $boxname = s/\Q$basepath\E//r;
              print "\"$boxname\" ";
              print "\"$_\" ";
            }
          '';
          in
        pkgs.writeScript "find-mailboxes.sh" ''
          #!${pkgs.stdenv.shell}
          ${pkgs.findutils}/bin/find \
                "${config.accounts.email.maildirBasePath}" \
                -type d \
                \( -name cur -o -name new \) \
                \( \! -empty \) \
                -printf '%h\n' \
            | ${pkgs.coreutils}/bin/sort \
            | ${pkgs.coreutils}/bin/uniq \
            | ${mkMailboxDescription}
        '';
        in
    ''
      # Mark anything marked by SpamAssassin as probably spam.
      spam "X-Spam-Score: ([0-9\\.]+).*" "SA: %1"
      # Only show the basic mail headers.
      ignore *
      unignore From To Cc Bcc Date Subject
      # Show headers in the following order.
      unhdr_order *
      hdr_order From: To: Cc: Bcc: Date: Subject:
      # Load solarized colors.
      source "${colorFile}"
      # Find all mailboxes dynamically.
      named-mailboxes `${findAllMailboxes}`
    '';
    settings = {
      assumed_charset = "iso-8859-1";
      forward_format = "\"Fwd: %s\"";
      edit_headers = "yes";
      history = "10000";
      history_file = "${config.xdg.configHome}/neomutt/history";
      imap_check_subscribed = "yes";
      imap_keepalive = "300";
      imap_pipeline_depth = "5";
      mail_check = "60";
      mbox_type = "Maildir";
      menu_scroll = "yes";
      pager_context = "5";
      pager_format = "\" %C - %[%H:%M] %.20v, %s%* %?H? [%H] ?\"";
      pager_index_lines = "10";
      pager_stop = "yes";
      reverse_name = "yes";
      send_charset = "utf-8";
      sidebar_sort_method = "path";
      sort_aux = "last-date-received";
      spam_separator = ", ";
      strict_threads = "yes";
      tilde = "yes";
      # https://chipsenkbeil.com/posts/applying-gpg-and-yubikey-part-4-signing/
      # Use GPGME backend instead of classic code
      crypt_use_gpgme = "yes";
      # Attempt to cryptographically sign outgoing messages
      crypt_autosign = "yes";
      # Always attempt to veryify email signatures
      # NOTE: Set by d"efault
      crypt_autopgp = "yes";
      crypt_verify_sig = "yes";
      # Automatically sign replies to signed emails
      crypt_replysign = "yes";
      # Automatically encrypt replies to encrypted emails
      # NOTE: Set by default
      crypt_replyencrypt = "yes";
      # Automatically sign replies to encrypted emails, gets
      # around issues with pure replysign
      crypt_replysignencrypted = "yes";
      # Only encrypt if all recipients are found in public key
      crypt_opportunistic_encrypt = "yes";
      # Use a gpg-agent for private key password prompts
      # NOTE: Set by default because GnuPG 2.1+ requires it
      pgp_use_gpg_agent = "yes";
      # Check status of gpg commands using file descriptor output from
      # decrypt and decode commands
      # NOTE: Set by default
      pgp_check_gpg_decrypt_status_fd = "yes";
      # When encrypting email, always include own key to be able to read sent mail
      pgp_self_encrypt = "yes";
      # Set the key to use for encryption/decryption of email
      pgp_default_key = "\"65AF3C834FD4070F\"";
      # Set the key to use for signing email
      pgp_sign_as = "\"747652E87F063539\"";
    };
    sort = "threads";
    binds =
      let
        mkBind = m: k: a: { action = a; key = k; map = m; };
        repBind = ms: k: a: map (m: mkBind m k a) ms;
      in
       # Ctrl-Shift-P - Previous Mailbox*/
      (repBind [ "index" "pager" ] "\\CP" "sidebar-prev") ++
      # Ctrl-Shift-N - Next Mailbox*/
      (repBind [ "index" "pager" ] "\\CN" "sidebar-next") ++
       # Ctrl-Shift-O - Open Highlighted Mailbox*/
      (repBind [ "index" "pager" ] "\\CO" "sidebar-open")
      ;

    macros = let
      mkMacro = m: k: a: { action = a; key = k; map = m; };
      repMacro = ms: k: a: map (m: mkMacro m k a) ms; in
      [(mkMacro "index" "I" "!mbsync -a^M")];

    vimKeys = true;
  };
  programs.msmtp.enable = true;
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
    offlineimap.enable = true;

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


  programs.go.enable = true;

  manual.html.enable = true;
}
