;(custom-set-variables
 ;;; custom-set-variables was added by Custom.
 ;;; If you edit it by hand, you could mess it up, so be careful.
 ;;; Your init file should contain only one such instance.
 ;;; If there is more than one, they won't work right.
 ;'(ansi-color-faces-vector
   ;[default default default italic underline success warning error])
 ;'(ansi-color-names-vector
   ;["#242424" "#e5786d" "#95e454" "#cae682" "#8ac6f2" "#333366" "#ccaa8f" "#f6f3e8"])
 ;'(custom-safe-themes
   ;'("bffa9739ce0752a37d9b1eee78fc00ba159748f50dc328af4be661484848e476" default)))
;(custom-set-faces
 ;;; custom-set-faces was added by Custom.
 ;;; If you edit it by hand, you could mess it up, so be careful.
 ;;; Your init file should contain only one such instance.
 ;;; If there is more than one, they won't work right.
 ;)
(require 'package)
(setq package-archives nil)
(setq package-enable-at-startup nil)
(package-initialize)


(require 'use-package)
(use-package direnv
         :init
         (add-hook 'prog-mode-hook #'direnv-update-environment)
         :config
         (direnv-mode))

(use-package company-lsp
             :defer t)

(use-package lsp-mode
             :after (direnv evil)
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
    "[/\\\\]\\.reference$")))


(use-package hydra)
(use-package evil
             :init (evil-mode )
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


;; spacebar bindings
(defhydra hydra-space
  (:hint nil)
  ;("b" (if (minibufferp) ('self-insert-command) (hydra-buffers/body)) :exit t)
  ("b" hydra-buffers/body :exit t)
  ("w" hydra-windows/body :exit t)
  ("<SPC>" execute-extended-command :exit t)
  ("g" hydra-gs/body :exit t)
  ("f" hydra-file/body :exit t)
  ("p" hydra-projectile/body :exit t)
  ("c" hydra-comments/body :exit t)
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
  )

(defhydra hydra-projectile
   (:hint nil)
   ("p" projectile-switch-project :exit t)
   ("f" projectile-find-file :exit t)
   ("a" projectile-add-known-project :exit t)
 )

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

(savehist-mode 1)
(setq savehist-file "~/.emacs.d/tmp/savehist")

(use-package ivy)
(ivy-mode 1)
(setq ivy-use-virtual-buffers t)
(setq enable-recursive-minibuffers t)




;; setting up GUI options
(menu-bar-mode -1)
(scroll-bar-mode 0)
(tool-bar-mode -1)
(global-display-line-numbers-mode)

