;; TODO figure out how to do this by default, because this is pretty brittle
(add-to-list 'exec-path "/home/jrestivo/.opam/4.09.1/bin/")
(setenv "OCAML_TOPLEVEL_PATH" (concat "/home/jrestivo/.opam/4.09.1/lib/toplevel"))
(setenv "CAML_LD_LIBRARY_PATH" (concat "/home/jrestivo/.opam/4.09.1/lib/stublibs" ":" "/home/jrestivo/.opam/4.09.1/lib/ocaml/stublibs" ":" "/home/jrestivo/.opam/4.09.1/lib/ocaml"))

(global-visual-line-mode nil)

(require 'package)
(setq package-archives nil)
(setq package-enable-at-startup nil)
(package-initialize)

(require 'use-package)
(use-package direnv
  :init
  (add-hook 'prog-mode-hook #'direnv-update-environment)
  :custom
  (direnv-always-show-summary nil)
  :config
  (direnv-mode))

(recentf-mode 1)
(setq recentf-max-menu-items 25)
(setq recentf-max-saved-items 25)


(use-package nix-mode
  :mode "\\.nix\\'")

(use-package merlin)

(use-package company-lsp
  :defer t)
(add-hook 'after-init-hook 'global-company-mode)


;; increase performance for lsp servers
(setq gc-cons-threshold 100000000)
(setq read-process-output-max (* 1024 1024))

(use-package lsp-mode
  :after (direnv evil)
  :hook (
	 (rust-mode . lsp-deferred)
	 (python-mode . lsp-deferred)
	 (tuareg-mode . lsp-deferred)
	 )
  :config
  (setq lsp-enable-snippet nil)
  (setq lsp-file-watch-ignored '(
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
				 "[/\\\\]\\.reference$"))
  )


(use-package hydra)
;; remember that in evil mode, cntrl-z enters emacs mode
;; and cntrl-z again undoes this

;; for some reason this won't work when I put it in the :config section
(setq evil-respect-visual-line-mode t)
(use-package evil
  :init (evil-mode)
  )
(use-package counsel)
(use-package projectile
  :init (projectile-mode +1)
  )

;;; must unbind normal minor mode keybind for space so can be used by hydra
;;; in doing so, unbindings insert mode, so must rebind
(define-key evil-normal-state-map (kbd "SPC") 'hydra-space/body)
(define-key evil-visual-state-map (kbd "SPC") 'hydra-space/body)
(define-key evil-motion-state-map (kbd "SPC") 'self-insert-command)
(define-key evil-insert-state-map (kbd "SPC") 'self-insert-command)

;;; have to turn this off
(hydra-set-property 'hydra-space :verbosity 0)
(hydra-set-property 'hydra-buffers :verbosity 0)
(hydra-set-property 'hydra-windows :verbosity 0)
(hydra-set-property 'hydra-magit :verbosity 0)
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
  ("<SPC>" execute-extended-command :exit t)
  ("g" hydra-gs/body :exit t)
  ("f" hydra-file/body :exit t)
  ("p" hydra-projectile/body :exit t)
  ("c" hydra-comments/body :exit t)
  ("s" hydra-ls/body :exit t)
  ;; jump to definition
  ("d" lsp-find-definition :exit t)
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
  ("m" toggle-frame-fullscreen :exit t)
  )

  ;; (lsp-command-map)
;; probably want top if I even want this on...
(use-package lsp-ui
  :ensure t
  :after lsp-mode
  :init
  (setq lsp-ui-doc-position 'top)
  (setq lsp-ui-doc-enable nil)
  )


(defhydra hydra-peek
  (:color green)
  "lang-server peek"
  ("i" lsp-ui-peek-find-implementation "impl'n" :exit t)
  ("d" lsp-ui-peek-find-definitions "def'n" :exit t)
  ("r" lsp-ui-peek-find-references "refs" :exit t)
  )

(defhydra hydra-ls
  (:color green)
  "lang-server cmds"
  ;; start lsp server
  ("s" lsp "start" :exit t)
  ;; restart lsp server
  ;("r" lsp-server-restart "restart" :exit t)
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
  ("d" lsp-ui-doc-mode "doc toggle" :exit t)
  )


(defhydra hydra-comments
  ;; TODO add for specific languages/toggles
  (:hint nil)
  ("<SPC>" comment-or-uncomment-region :exit t)
  )

;; buffer bindings
(defhydra hydra-buffers
  (:hint nil)
  ("n" switch-to-next-buffer :exit t)
  ("N" evil-buffer-new :exit t)
  ("p" switch-to-prev-buffer :exit t)
  ("d" kill-buffer :exit t)
  ("b" ivy-switch-buffer :exit t)
  )

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
  )

;; gs
(defhydra hydra-gs
  (:hint nil)
  ;; status for cherry picking/staging
  ("s" magit :exit t)
  ;; blame
  ("b" (magit-blame) :exit t)
  ("g" counsel-rg :exit t)
  ("d" counsel-cd :exit t)
  )

(defhydra hydra-file
  (:hint nil)
  ("f" counsel-find-file :exit t)
  ("r" counsel-recentf :exit t)
  )

(defhydra hydra-projectile
  (:hint nil)
  ("p" counsel-projectile-switch-project :exit t)
  ("f" counsel-projectile-find-file :exit t)
  ("a" projectile-add-known-project :exit t)
  ;;  for further customization https://github.com/ericdanan/counsel-projectile/blob/master/counsel-projectile.el
  ("g" (counsel-projectile-switch-project 13) :exit t)
)

(setq projectile-globally-ignored-file-suffixes '("^\#.*\#$"))
(setq ivy-extra-directories  '("../"))

;; theming
(use-package spacemacs-common)
(deftheme spacemacs-dark "Spacemacs theme, the dark version")
(create-spacemacs-theme 'dark 'spacemacs-dark)
(provide-theme 'spacemacs-dark)
(load-theme 'spacemacs-dark t)

(use-package magit)
(use-package evil-magit)

;; git magic markings
(use-package git-gutter)
(global-git-gutter-mode t)

(setq undo-tree-auto-save-history t)
(setq savehist-file "~/.emacs.d/tmp/savehist")
(setq undo-tree-history-directory-alist '(("." . "~/.emacs.d/undo")))
(setq backup-directory-alist `(("." . "~/.emacs.d/tmp/")))

(global-undo-tree-mode)
(savehist-mode 1)


(use-package ivy)
(ivy-mode 1)
(setq ivy-use-virtual-buffers t)
(setq enable-recursive-minibuffers t)
;; we really want to be able to browse
(setq ivy-height 80)

;; no need for direnv show project details



;; setting up GUI options
(menu-bar-mode -1)
(scroll-bar-mode 0)
(tool-bar-mode -1)
(global-display-line-numbers-mode)

(with-eval-after-load 'ivy
  (push (cons #'swiper (cdr (assq t ivy-re-builders-alist)))
        ivy-re-builders-alist)
  (push (cons t #'ivy--regex-fuzzy) ivy-re-builders-alist))
