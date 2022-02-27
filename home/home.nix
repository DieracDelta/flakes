{ config, pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;

  home.sessionVariables = { EDITOR = "nvim"; };

  home.stateVersion = "20.09";

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.git = {
    enable = true;
    userName = "Justin Restivo";
    userEmail = "justin@restivo.me";
    extraConfig = {
      #url = { "ssh://git@github.com" = { insteadOf = "https://github.com"; }; };
      #url = {
        #"ssh://git@bitbucket.org" = { insteadOf = "https://bitbucket.org"; };
      #};
      github.user = "DieracDelta";
      tag.gpgSign = true;
    };
    # TODO turn this on
    signing.signByDefault = true;
    signing.key = "E68281EB2ABCE9B8";
  };

  programs.zellij = {
    enable = true;
    settings = pkgs.lib.literalExpression ''
      keybinds:
      unbind: true
      normal:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g',]
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's',]
          - action: [SwitchToMode: Session,]
            key: [Ctrl: 'o',]
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tmux,]
            key: [Ctrl: 'b',]
          - action: [Quit,]
            key: [Ctrl: 'q',]
          - action: [NewPane: ]
            key: [ Alt: 'n',]
          - action: [MoveFocusOrTab: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocusOrTab: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      locked:
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 'g',]
      resize:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g']
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 'n', Char: "\n", Char: ' ', Esc]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's']
          - action: [SwitchToMode: Session,]
            key: [Ctrl: 'o',]
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tmux,]
            key: [Ctrl: 'b',]
          - action: [Quit]
            key: [Ctrl: 'q']
          - action: [Resize: Left,]
            key: [Char: 'h', Left,]
          - action: [Resize: Down,]
            key: [Char: 'j', Down,]
          - action: [Resize: Up,]
            key: [Char: 'k', Up, ]
          - action: [Resize: Right,]
            key: [Char: 'l', Right,]
          - action: [Resize: Increase,]
            key: [Char: '=']
          - action: [Resize: Increase,]
            key: [ Char: '+']
          - action: [Resize: Decrease,]
            key: [Char: '-']
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      pane:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g']
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 'p', Char: "\n", Char: ' ', Esc]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's']
          - action: [SwitchToMode: Session,]
            key: [Ctrl: 'o',]
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tmux,]
            key: [Ctrl: 'b',]
          - action: [Quit,]
            key: [Ctrl: 'q',]
          - action: [MoveFocus: Left,]
            key: [ Char: 'h', Left,]
          - action: [MoveFocus: Right,]
            key: [ Char: 'l', Right,]
          - action: [MoveFocus: Down,]
            key: [ Char: 'j', Down,]
          - action: [MoveFocus: Up,]
            key: [ Char: 'k', Up,]
          - action: [SwitchFocus,]
            key: [Char: 'p']
          - action: [NewPane: , SwitchToMode: Normal,]
            key: [Char: 'n',]
          - action: [NewPane: Down, SwitchToMode: Normal,]
            key: [Char: 'd',]
          - action: [NewPane: Right, SwitchToMode: Normal,]
            key: [Char: 'r',]
          - action: [CloseFocus, SwitchToMode: Normal,]
            key: [Char: 'x',]
          - action: [ToggleFocusFullscreen, SwitchToMode: Normal,]
            key: [Char: 'f',]
          - action: [TogglePaneFrames, SwitchToMode: Normal,]
            key: [Char: 'z',]
          - action: [ToggleFloatingPanes, SwitchToMode: Normal,]
            key: [Char: 'w']
          - action: [TogglePaneEmbedOrFloating, SwitchToMode: Normal,]
            key: [Char: 'e']
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
          - action: [SwitchToMode: RenamePane, PaneNameInput: [0],]
            key: [Char: 'c']
      move:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g']
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 'h', Char: "\n", Char: ' ', Esc]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's']
          - action: [SwitchToMode: Session,]
            key: [Ctrl: 'o',]
          - action: [Quit]
            key: [Ctrl: 'q']
          - action: [MovePane: ,]
            key: [Char: 'n', Char: "\t",]
          - action: [MovePane: Left,]
            key: [Char: 'h', Left,]
          - action: [MovePane: Down,]
            key: [Char: 'j', Down,]
          - action: [MovePane: Up,]
            key: [Char: 'k', Up, ]
          - action: [MovePane: Right,]
            key: [Char: 'l', Right,]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      tab:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g']
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 't', Char: "\n", Char: ' ', Esc]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's']
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tmux,]
            key: [Ctrl: 'b',]
          - action: [SwitchToMode: Session,]
            key: [Ctrl: 'o',]
          - action: [SwitchToMode: RenameTab, TabNameInput: [0],]
            key: [Char: 'r']
          - action: [Quit,]
            key: [Ctrl: 'q',]
          - action: [GoToPreviousTab,]
            key: [ Char: 'h', Left, Up, Char: 'k',]
          - action: [GoToNextTab,]
            key: [ Char: 'l', Right,Down, Char: 'j']
          - action: [NewTab: , SwitchToMode: Normal,]
            key: [ Char: 'n',]
          - action: [CloseTab, SwitchToMode: Normal,]
            key: [ Char: 'x',]
          - action: [ToggleActiveSyncTab, SwitchToMode: Normal,]
            key: [Char: 's']
          - action: [GoToTab: 1, SwitchToMode: Normal,]
            key: [ Char: '1',]
          - action: [GoToTab: 2, SwitchToMode: Normal,]
            key: [ Char: '2',]
          - action: [GoToTab: 3, SwitchToMode: Normal,]
            key: [ Char: '3',]
          - action: [GoToTab: 4, SwitchToMode: Normal,]
            key: [ Char: '4',]
          - action: [GoToTab: 5, SwitchToMode: Normal,]
            key: [ Char: '5',]
          - action: [GoToTab: 6, SwitchToMode: Normal,]
            key: [ Char: '6',]
          - action: [GoToTab: 7, SwitchToMode: Normal,]
            key: [ Char: '7',]
          - action: [GoToTab: 8, SwitchToMode: Normal,]
            key: [ Char: '8',]
          - action: [GoToTab: 9, SwitchToMode: Normal,]
            key: [ Char: '9',]
          - action: [ToggleTab]
            key: [ Char: "\t" ]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      scroll:
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 's', Char: ' ', Char: "\n", Esc]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g',]
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tmux,]
            key: [Ctrl: 'b',]
          - action: [SwitchToMode: Session,]
            key: [Ctrl: 'o',]
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [ScrollToBottom, SwitchToMode: Normal,]
            key: [Ctrl: 'c',]
          - action: [Quit,]
            key: [Ctrl: 'q',]
          - action: [ScrollDown,]
            key: [Char: 'j', Down,]
          - action: [ScrollUp,]
            key: [Char: 'k', Up,]
          - action: [PageScrollDown,]
            key: [Ctrl: 'f', PageDown, Right, Char: 'l',]
          - action: [PageScrollUp,]
            key: [Ctrl: 'b', PageUp, Left, Char: 'h',]
          - action: [HalfPageScrollDown,]
            key: [Char: 'd',]
          - action: [HalfPageScrollUp,]
            key: [Char: 'u',]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      renametab:
          - action: [SwitchToMode: Normal,]
            key: [Char: "\n", Ctrl: 'c', Esc]
          - action: [TabNameInput: [27] , SwitchToMode: Tab,]
            key: [Esc,]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      renamepane:
          - action: [SwitchToMode: Normal,]
            key: [Char: "\n", Ctrl: 'c', Esc]
          - action: [PaneNameInput: [27] , SwitchToMode: Pane,]
            key: [Esc,]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      session:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g']
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tmux,]
            key: [Ctrl: 'b',]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 'o', Char: "\n", Char: ' ', Esc]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's']
          - action: [Quit,]
            key: [Ctrl: 'q',]
          - action: [Detach,]
            key: [Char: 'd',]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      tmux:
          - action: [SwitchToMode: Locked,]
            key: [Ctrl: 'g']
          - action: [SwitchToMode: Resize,]
            key: [Ctrl: 'n',]
          - action: [SwitchToMode: Pane,]
            key: [Ctrl: 'p',]
          - action: [SwitchToMode: Move,]
            key: [Ctrl: 'h',]
          - action: [SwitchToMode: Tab,]
            key: [Ctrl: 't',]
          - action: [SwitchToMode: Normal,]
            key: [Ctrl: 'o', Char: "\n", Char: ' ', Esc]
          - action: [SwitchToMode: Scroll,]
            key: [Ctrl: 's']
          - action: [Quit,]
            key: [Ctrl: 'q',]
          - action: [NewPane: Down, SwitchToMode: Normal,]
            key: [Char: "\"",]
          - action: [NewPane: Right, SwitchToMode: Normal,]
            key: [Char: '%',]
          - action: [ToggleFocusFullscreen, SwitchToMode: Normal,]
            key: [Char: 'z',]
          - action: [NewTab: , SwitchToMode: Normal,]
            key: [ Char: 'c',]
          - action: [SwitchToMode: RenameTab, TabNameInput: [0],]
            key: [Char: ',']
          - action: [GoToPreviousTab, SwitchToMode: Normal,]
            key: [ Char: 'p']
          - action: [GoToNextTab, SwitchToMode: Normal,]
            key: [ Char: 'n']
          - action: [MoveFocus: Left, SwitchToMode: Normal,]
            key: [ Left,]
          - action: [MoveFocus: Right, SwitchToMode: Normal,]
            key: [ Right,]
          - action: [MoveFocus: Down, SwitchToMode: Normal,]
            key: [ Down,]
          - action: [MoveFocus: Up, SwitchToMode: Normal,]
            key: [ Up,]
          - action: [NewPane: ,]
            key: [ Alt: 'n',]
          - action: [MoveFocus: Left,]
            key: [ Alt: 'h',]
          - action: [MoveFocus: Right,]
            key: [ Alt: 'l',]
          - action: [MoveFocus: Down,]
            key: [ Alt: 'j',]
          - action: [MoveFocus: Up,]
            key: [ Alt: 'k',]
          - action: [FocusPreviousPane,]
            key: [ Alt: '[',]
          - action: [FocusNextPane,]
            key: [ Alt: ']',]
          - action: [Resize: Increase,]
            key: [ Alt: '=']
          - action: [Resize: Increase,]
            key: [ Alt: '+']
          - action: [Resize: Decrease,]
            key: [ Alt: '-']
      plugins:
          - path: tab-bar
            tag: tab-bar
          - path: status-bar
            tag: status-bar
          - path: strider
            tag: strider

    '';
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
    sshKeys = [
      "0FD8067624129B09D68529E2D7AAC887A8247838"
    ];
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
      #mailcap_path = "./mailcap"
#   # text/html; ~/.config/mutt/bin/openfile %s ; nametemplate=%s.html
#   text/html; lynx -assume_charset=%{charset} -display_charset=utf-8 -dump %s; nametemplate=%s.html; copiousoutput;
#   text/plain; $EDITOR %s ;
#   image/*; ~/.config/mutt/bin/openfile %s ; copiousoutput
#   video/*; setsid mpv --quiet %s &; copiousoutput
#   application/pgp-encrypted; gpg -d '%s'; copiousoutput;
#   # application/vnd.openxmlformats-officedocument.spreadsheetml.sheet; sc-im %s;
#   application/*; ~/.config/mutt/bin/openfile %s ;
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
      #pager = "lynx";
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
