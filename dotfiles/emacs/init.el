(require 'hydra)
(require 'evil)
(evil-mode 1)
;; must unbind normal minor mode keybind for space so can be used by hydra
;; in doing so, unbindings insert mode, so must rebind
(define-key evil-normal-state-map (kbd "SPC") 'hydra-space/body)
(define-key evil-motion-state-map (kbd "SPC") 'self-insert-command)
(define-key evil-insert-state-map (kbd "SPC") 'self-insert-command)
;; have to turn this off
(hydra-set-property 'hydra-space :verbosity 0)
(hydra-set-property 'hydra-buffers :verbosity 0)
(hydra-set-property 'hydra-windows :verbosity 0)
;; spacebar bindings
(defhydra hydra-space
  (:hint nil)
  ;("b" (if (minibufferp) ('self-insert-command) (hydra-buffers/body)) :exit t)
  ("b" hydra-buffers/body :exit t)
  ("w" hydra-windows/body :exit t)
  ("<SPC>" execute-extended-command :exit t)
  )

;; buffer bindings
(defhydra hydra-buffers
  (:hint nil)
  ("n" switch-to-next-buffer :exit t)
  ("p" switch-to-prev-buffer :exit t)
  ("d" kill-buffer :exit t)
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


(require 'spacemacs-common)
(deftheme spacemacs-dark "Spacemacs theme, the dark version")
(create-spacemacs-theme 'dark 'spacemacs-dark)
(provide-theme 'spacemacs-dark)

(menu-bar-mode -1)
(toggle-scroll-bar -1)
(tool-bar-mode -1)

