(setq user-full-name "Justin Restivo"
      user-mail-address "justin.p.restivo@gmail.com")
(setq doom-font (font-spec :family "monospace" :size 14))
(setq doom-theme 'doom-one)
(setq org-directory "~/org/")
(setq display-line-numbers-type 'relative)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c g k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c g d') to jump to their definition and see how
;; they are implemented.

(use-package! smtlib-mode
  :mode "\\.smt$")

(+global-word-wrap-mode +1)


;; custom highlighting stuff
(after! highlight-indent-guides
  (setq highlight-indent-guides-character ?\|)
  (set-face-background 'highlight-indent-guides-character-face nil)
  (set-face-foreground 'highlight-indent-guides-character-face "#ff00000")
  (set-face-background 'highlight-indent-guides-top-character-face nil)
  (set-face-foreground 'highlight-indent-guides-top-character-face "#00ff5f")
  (set-face-foreground 'highlight-indent-guides-stack-character-face "#3f00ff")
  (setq highlight-indent-guides-responsive 'stack)
  (setq highlight-indent-guides-delay 0))

(after! ivy-posframe
  (setq ivy-posframe-display-functions-alist
        '((t . ivy-posframe-display-at-frame-top-center))))

(after! company
  (setq company-idle-delay 0))

;; configure fill column
;(global-display-fill-column-indicator-mode)

(after! magit
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1))

(after! direnv
  (setq direnv-always-show-summary nil))

(after! projectile
  (setq projectile-globally-ignored-directories '("target" "_build")))

;; some global keymaps
;;(global-unset-key (kbd "C-z"))
;;(global-unset-key (kbd "C-x C-z"))
;;(global-unset-key (kbd "<f5>"))
;;(global-set-key (kbd "<f5>") 'evil-write)

;; highlighting symbols
;; (use-package! highlight-symbol
;;   :hook (after-change-major-mode-hook . highlight-symbol-mode)
;;   :config
;;   (setq highlight-symbol-idle-delay 0.1)
;;   (set-face-background 'highlight-symbol-face "#D48B2C")
;;   (set-face-foreground 'highlight-symbol-face "#D44B2C"))
;;
;; (add-hook! 'text-mode-hook 'turn-on-auto-fill)
;; (add-hook! '(text-mode-hook markdown-mode-hook) (setq-local fill-column 110))

(after! rustic
  (setq lsp-rust-server 'rust-analyzer))
(setq lsp-rust-server 'rust-analyzer)
(setq rustic-lsp-server 'rust-analyzer)
(after! rustic
  (setq rustic-lsp-server 'rust-analyzer))

;; (setq +doom-dashboard-banner-file (expand-file-name "pelican.txt" doom-private-dir))
;;
(defun doom-dashboard-widget-banner ()
  (let ((point (point)))
    (mapc (lambda (line)
            (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                                'face 'doom-dashboard-banner) " ")
            (insert "\n"))
          '(
            "                            `.---...__                             "
            "                           /```.__    ``.                          "
            " truly the best bird       |```/  `'--.._`.                        "
            "                           |``|        (o).                        "
            "                           \`` \    _,-'   `.                      "
            "                            \```\  ( ( ` .   `.))                  "
            "                             `.```. `.` . `    `.                  "
            "                               `.``\  `.__   `.  `.                "
            "                              ___\``, \ `-.  `.  `.                "
            "                    __    _,-'   \,'  /  \   `-.  `. `.            "
            "                 ,-' '`,-'  '  ''| '   ' |      `-. `. `.          "
            "              ,-''_,-' '  ' '  ' |   '  '|         `-. `.`.        "
            "           ,-'_,-'   '   '  ''   | '  '  |            `-.`.`.      "
            "        ,-',-'  ''  ,'   |   |   |'   ' /                `-..`.    "
            "      ,' ,'  ' '     |  ,' | ,' /    ' '|                   `-.    "
            "     // /  '   |    ,'    ,'   /   '  '/                           "
            "     | || ,'  ,' |    ,' |   ,'   '   '|                           "
            "     ||||   |   ,' ,'   ,' ,' ' '     /                            "
            "     |  | |,'  '     |'  ,'  '   '  '/                             "
            "     | ||,'   ,' |  ,' ,' '    \   '/                              "
            "     ||||  |  , ,'  ,-'  /  ' '| ','                               "
            "     | /  ,' '   ,-' '   |'    |,'                                 "
            "     | | ' ,' ,-' '  ' ' |    '|                                   "
            "     |||,' ,-'  '  '   '_|'  '/                                    "
            "     |,|,-' /'___,..--''  \ ' |                                    "
            "     / // ,'-' |' |        \  |                                    "
            "    ///,-'      \ |         \'|                                    "
            "   '--'          \'\        | |                                    "
            "               __  \___  __| |_                                    "
            " ____,...----''   ||`-- <_.--._ -`--. __                           "
            "                  ''            `-`     `'''''''-----......_____   "
            "                                                                   "))))

;; https://stackoverflow.com/questions/8204316/cant-change-cursor-color-in-emacsclient/27724448
(add-to-list 'default-frame-alist '(mouse-color . "red"))
(load! "+bindings")

(setq evil-ex-substitute-global nil)

(after! circe
  (set-irc-server! "chat.freenode.net"
    `(:tls t
      :port 6697
      :nick "kroneckerdelta"
      :channels ("#next-browser" "nixos"))))

(setq +latex-viewers '(zathura))

(use-package! dockerfile-mode
  :mode "Dockerfile\\'"
  :config
  (put 'dockerfile-image-name 'safe-local-variable #'stringp))

(after! counsel
  (ivy-configure 'counsel-rg
    :update-fn 'auto))

(face-spec-set
   'tuareg-font-lock-constructor-face
   nil)
