;; TODO figure out how to do this by default, because this is pretty brittle
(add-to-list 'exec-path "/home/jrestivo/.opam/4.09.1/bin/")
(setenv "OCAML_TOPLEVEL_PATH" (concat "/home/jrestivo/.opam/4.09.1/lib/toplevel"))
(setenv "CAML_LD_LIBRARY_PATH" (concat "/home/jrestivo/.opam/4.09.1/lib/stublibs" ":" "/home/jrestivo/.opam/4.09.1/lib/ocaml/stublibs" ":" "/home/jrestivo/.opam/4.09.1/lib/ocaml"))

(global-visual-line-mode nil)
(winner-mode 1)

(require 'package)
(setq package-archives nil)
(setq package-enable-at-startup nil)
(package-initialize)

(require 'use-package)
(use-package direnv
  :hook (prog-mode . direnv-update-environment)
  ;; no summary of commands!
  :custom
  (direnv-always-show-summary nil)
  :config
  (direnv-mode))

(recentf-mode 1)
(setq recentf-max-menu-items 25)
(setq recentf-max-saved-items 25)


(use-package nix-mode
  :mode "\\.nix\\'")

(use-package company-lsp
  :hook (after-init . global-company-mode)
  :defer t)

(use-package lsp-mode
  :after (direnv evil)
  :hook (
         (rust-mode . lsp-deferred)
         (python-mode . lsp-deferred)
         (tuareg-mode . lsp-deferred)
         (c++-mode . lsp-deferred))
  :config
  ;; increase performance for lsp servers
  (setq gc-cons-threshold 100000000)
  (setq read-process-output-max (* 1024 1024))
  (setq lsp-enable-snippet nil)
  (setq lsp-file-watch-ignored
   '(
     "[/\\\\]\\.direnv$"
           ; SCM tools
     "[/\\\\]\\.git$"
     "[/\\\\]\\.hg$"
     "[/\\\\]\\.bzr$"
     "[/\\\\]_darcs$"
     "[/\\\\]\\.svn$"
     "[/\\\\]_FOSSIL_$"
           ; IDE tools
     "[/\\\\]\\.idea$"
     "[/\\\\]\\.ensime_cache$"
     "[/\\\\]\\.eunit$"
     "[/\\\\]node_modules$"
     "[/\\\\]\\.fslckout$"
     "[/\\\\]\\.tox$"
     "[/\\\\]\\.stack-work$"
     "[/\\\\]\\.bloop$"
     "[/\\\\]\\.metals$"
     "[/\\\\]target$"
           ; Autotools output
     "[/\\\\]\\.deps$"
     "[/\\\\]build-aux$"
     "[/\\\\]autom4te.cache$"
     "[/\\\\]\\.reference$")))



(use-package hydra)
;; remember that in evil mode, cntrl-z enters emacs mode
;; and cntrl-z again undoes this

;; for some reason this won't work when I put it in the :config section
(use-package evil
  :init (setq evil-respect-visual-line-mode t)
  :config (evil-mode)
  :bind
  ("<f5>" . evil-write)
  (:map evil-normal-state-map ("SPC" . hydra-space/body))
  (:map evil-visual-state-map ("SPC" . hydra-space/body))
  (:map evil-normal-state-map ("SPC" . hydra-space/body))
  ;; control z is annoying as hell normally
  ;; disable that so I don't keep on pressing it and crying
  (:map evil-visual-state-map ("C-z" . nil))
  (:map evil-motion-state-map ("C-z" . nil))
  (:map evil-insert-state-map ("C-z" . nil)))


(use-package counsel)
(use-package projectile
  :init (projectile-mode +1)
  :config
  (setq projectile-globally-ignored-file-suffixes '("^\#.*\#$" "_build")))

(hydra-set-property 'hydra-space :verbosity 1)
(hydra-set-property 'hydra-buffers :verbosity 0)
(hydra-set-property 'hydra-windows :verbosity 0)
(hydra-set-property 'hydra-gs :verbosity 0)
(hydra-set-property 'hydra-file :verbosity 0)
(hydra-set-property 'hydra-projectile :verbosity 0)
(hydra-set-property 'hydra-comments :verbosity 0)
(hydra-set-property 'hydra-ls :verbosity 1)
(hydra-set-property 'hydra-peek :verbosity 1)


;; spacebar bindings
(defhydra hydra-space
  (:hint nil)
  ("b" hydra-buffers/body :exit t)
  ("w" hydra-windows/body :exit t)
  ("<SPC>" counsel-M-x :exit t)
  ("g" hydra-gs/body :exit t)
  ("f" hydra-file/body :exit t)
  ("p" hydra-projectile/body :exit t)
  ("c" hydra-comments/body :exit t)
  ("s" hydra-ls/body :exit t)
  ;; jump to definition
  ("d" (jtd) :exit t)
  ;; jump to implementation
  ("i" lsp-find-implementation :exit t)
  ("l" hydra-peek/body  :exit t)
  ("r" lsp-find-references  :exit t)
  ;; jumping between syntax errors
  ("j" flycheck-next-error  :exit t)
  ("k" flycheck-previous-error  :exit t)
  ("z" counsel-yank-pop  :exit t)
  ;; reminder that for multiple shells, C-u <SPC> s
  ("t" shell  :exit t)
  ("m" toggle-frame-fullscreen :exit t))

;; jump to defn of symbol if lsp isn't running else use lsp
(defun jtd ()
  (if (eq 'emacs-lisp-mode major-mode) 
      (describe-symbol (intern-soft (thing-at-point 'symbol 1)))
    (if (bound-and-true-p lsp-mode) (lsp-find-definition)
     (dumb-jump-go))))
 

;; (lsp-command-map)
;; probably want top if I even want this on...
(use-package lsp-ui
  :ensure t
  :after lsp-mode
  :init
  (setq lsp-ui-doc-position 'top)
  (setq lsp-ui-doc-enable nil))


(defhydra hydra-peek
  (:color green)
  "lang-server peek"
  ("i" lsp-ui-peek-find-implementation "impl'n" :exit t)
  ("d" lsp-ui-peek-find-definitions "def'n" :exit t)
  ("r" lsp-ui-peek-find-references "refs" :exit t))

(defhydra hydra-ls
  (:color green)
  "lang-server cmds"
  ;; start lsp server
  ("s" lsp "start" :exit t)
  ;; restart lsp server
  ("r" lsp-server-restart "restart" :exit t)
  ;; shut off lsp server
  ("q" lsp-workspace-shutdown "shutdown" :exit t)
  ;; describe session for debugging information
  ("d" lsp-describe-session "info" :exit t)
  ;; format the buffer using langserver
  ("f" lsp-format-buffer "format" :exit t)
  ;; light symbol highlighting
  ("h" lsp-toggle-symbol-highlight "toggle highlight" :exit t)
  ;; logging in case things go wrong
  ("l" lsp-toggle-trace-io "debug log" :exit t)
  ("m" lsp-ui-sideline-mode "ui toggle" :exit t)
  ("d" lsp-ui-doc-mode "doc toggle" :exit t))


(defhydra hydra-comments
  ;; TODO do something a bit more fancy here
  ;; (so you can do this without having a region selected)
  (:hint nil :verbosity 0)
  ("<SPC>" comment-or-uncomment-region :exit t))

;; buffer bindings
(defhydra hydra-buffers
  (:hint nil)
  ("n" switch-to-next-buffer :exit t)
  ("N" evil-buffer-new :exit t)
  ("p" switch-to-prev-buffer :exit t)
  ("d" kill-buffer :exit t)
  ("b" ivy-switch-buffer :exit t))

;; window bindings
(defhydra hydra-windows
  (:hint nil)
  ("s" split-window-vertically :exit t)
  ("v" split-window-horizontally :exit t)
  ("d" delete-window :exit t)
  ("l" evil-window-right :exit t)
  ("h" evil-window-left :exit t)
  ("k" evil-window-up :exit t)
  ("j" evil-window-down :exit t)
  ("m" (toggle_max) :exit t))

(defun toggle_max ()
  "toggles/undoes max window"
  (
   if (eq (length (window-list)) 1)
   (winner-undo)
   (delete-other-windows)))

;; gs
(defhydra hydra-gs
  (:hint nil)
  ;; status for cherry picking/staging
  ("s" magit :exit t)
  ;; blame
  ("b" (magit-blame) :exit t)
  ("g" counsel-rg :exit t)
  ("d" counsel-cd :exit t))

(defhydra hydra-file
  (:hint nil)
  ("f" counsel-find-file :exit t)
  ("r" counsel-recentf :exit t))

(defhydra hydra-projectile
  (:hint nil)
  ("p" counsel-projectile-switch-project :exit t)
  ("f" counsel-projectile-find-file :exit t)
  ("a" projectile-add-known-project :exit t)
  ;;  for further customization
  ;; https://github.com/ericdanan/counsel-projectile/blob/master/counsel-projectile.el
  ("g" (counsel-projectile-switch-project 13) :exit t)
  ("r" (projectile-remove-current-project-from-known-projects) :exit t))

(setq initial-scratch-message "")

;; theming
(use-package spacemacs-common
  :config
  (deftheme spacemacs-dark "Spacemacs theme, the dark version")
  (create-spacemacs-theme 'dark 'spacemacs-dark)
  (provide-theme 'spacemacs-dark)
  (load-theme 'spacemacs-dark t))

(use-package magit)
(use-package evil-magit
  :after (evil magit)
  :config 
  ;; get fullscreen magit by default (instead of a split)
  (setq magit-display-buffer-function #'magit-display-buffer-fullframe-status-v1))


;; git magic markings
(use-package git-gutter
  :config
  (global-git-gutter-mode t))


;; sane, clean defaults for history
(setq undo-tree-auto-save-history t)
(setq savehist-file "~/.emacs.d/tmp/savehist")
(setq undo-tree-history-directory-alist '(("." . "~/.emacs.d/undo")))
(setq backup-directory-alist `(("." . "~/.emacs.d/tmp/")))
(global-undo-tree-mode)
(savehist-mode 1)
(menu-bar-mode -1)
(scroll-bar-mode 0)
(tool-bar-mode -1)
(global-display-line-numbers-mode)


;(use-package ivy
  ;:config
  ;(ivy-mode 1)
  ;;; don't show current directory
  ;(setq ivy-extra-directories  '("../"))
  ;(setq ivy-use-virtual-buffers t)
  ;(setq enable-recursive-minibuffers t)
  ;;; we really want to be able to browse with a tall boi
  ;(setq ivy-height 25)
  ;(push (cons #'swiper (cdr (assq t ivy-re-builders-alist))) ivy-re-builders-alist)
  ;(push (cons t #'ivy--regex-fuzzy) ivy-re-builders-alist))

;; TODOS 

;; figure out how to ignore _build directory with FZF

;; fzf *with preview of file*

;; setting up GUI options
;; customize bottom bar

;; | things


;; fix problems with fzf (ignoring shit)

;; get some nice mark mappings

(use-package origami
  :config
  (global-origami-mode))
;; (add-hook 'origami-mode-hook #'lsp-origami-mode)



;; (defun highlight-symbol-mode-on () (highlight-symbol-mode 1))
;; (define-globalized-minor-mode
;; global-highlight-symbol-mode highlight-symbol-mode highlight-symbol-mode-on)
;; (global-highlight-symbol-mode 1)

;; highlight globally
(setq highlight-symbol-disable '())
(add-hook 'after-change-major-mode-hook
    (lambda ()
      (if (null (memql major-mode highlight-symbol-disable))
          (highlight-symbol-mode))))
;; (highlight-symbol-mode nil)
;; (highlight-symbol-mode 1)
(use-package highlight-symbol
  ;; :bind (
  ;; 	 ([control f3] . highlight-symbol)
  ;; 	 ([f3] . highlight-symbol-next)
  ;; 	 ([(shift f3)] highlight-symbol-prev)
  ;; 	 ([(meta f3)] highlight-symbol-query-replace))
  :config
  (setq highlight-symbol-idle-delay 0.1)
  (set-face-background 'highlight-symbol-face "#D48B2C")
  (set-face-foreground 'highlight-symbol-face "#D44B2C"))


;; (directory-files "/")

;; (use-package swiper
;;   :bind ("`" . swiper))

;; (global-set-key "C-f4" 'highlight-symbol)
;; ;; low effort search
;; (global-set-key [f3] 'highlight-symbol-next)
;; (global-set-key [(shift f3)] 'highlight-symbol-prev)
;; (global-set-key [(meta f3)] 'highlight-symbol-query-replace)

(use-package evil-matchit)
(evilmi-load-plugin-rules '(mhtml-mode) '(template simple html))
(setq evilmi-quote-chars (string-to-list "'\"/"))

;; scroll like a normal person
(setq scroll-step 1 scroll-conservatively 10000)

;; (require smtlib)

;; (config_indent_stuff)

(use-package highlight-indent-guides
  :hook  (prog-mode . config_indent_stuff)
  :config
  (defun config_indent_stuff ()
    ; TODO fix
    ;(if (null (memql major-mode lisp-mode (highlight-indent-guides-mode))))
    (setq highlight-indent-guides-method 'character)
    (setq highlight-indent-guides-character ?\|)
    (set-face-background 'highlight-indent-guides-character-face nil)
    (set-face-foreground 'highlight-indent-guides-character-face "#ff00000")
    (set-face-background 'highlight-indent-guides-top-character-face nil)
    (set-face-foreground 'highlight-indent-guides-top-character-face "#00ff5f")
    (set-face-foreground 'highlight-indent-guides-stack-character-face "#3f00ff")
    (setq highlight-indent-guides-responsive 'stack)
    (setq highlight-indent-guides-delay 0)))

(setq show-paren-delay 0)
(show-paren-mode 1)
;; I keep on accidentally hitting these
;; they are very annoying
(global-unset-key (kbd "C-z"))
(global-unset-key (kbd "C-x C-z"))
(global-unset-key (kbd "<f5>"))
(global-set-key (kbd "<f5>") 'evil-write)

;; set up smtlib mode by adding it to the list of buffer filename-mode pairs
(setq auto-mode-alist (cons '("\\.smt$" . smtlib-mode) auto-mode-alist))
(blink-cursor-mode 0)
(autoload 'smtlib-mode "smtlib" "Major mode for SMTLIB" t)

(use-package parinfer-rust-mode
  :hook (
         ;(lisp-mode . parinfer-rust-mode)
	 ;(emacs-lisp-mode . parinfer-rust-mode)
	 (common-lisp-mode . parinfer-rust-mode))
  :init
  (module-load
   "/nix/store/xdbkvlm537iglj6rx8f0sjli9afbjyn1-parinfer-rust-mode-\
overlay-0.4.3/lib/libparinfer_rust.so")
  (setq parinfer-rust-library "/nix/store/xdbkvlm537iglj6rx8f0sjli9afbjyn1-parinfer-rust\
-mode-overlay-0.4.3/lib/libparinfer_rust.so"))

(set-fill-column 80)
(setq display-fill-column-indicator-character nil)
(add-hook 'find-file-hook
      (lambda () (display-fill-column-indicator-mode 1)))

;; TODO set cntrl-g to escape

(setq max-lisp-eval-depth 99999)
(setq max-specpdl-size 99999)

(use-package eros
  :hook (emacs-lisp-mode . eros-mode)
  :config
  (setq eros-eval-result-duration 600))



;; configure mode-line
(setq column-number-mode 1)

(use-package all-the-icons)
(use-package doom-modeline
  :ensure t
  :init (doom-modeline-mode 1)
  :config (setq doom-modeline-lsp t))
