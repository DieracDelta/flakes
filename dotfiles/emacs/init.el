;(require 'evil-leader)
(require 'hydra)
;(defhydra hydra-zoom (global-map "<f2>")
  ;"zoom"
  ;("g" text-scale-increase "in")
  ;("l" text-scale-decrease "out"))

(require 'evil)
;(global-evil-leader-mode)
;(evil-leader/set-leader "<SPC>")
;(evil-leader/set-key
  ;"e"  'find-file
  ;"b"  'switch-to-buffer
  ;"k"  'kill-buffer
  ;"bn" 'switch-to-next-buffer
  ;)
(evil-mode 1)

(require 'spacemacs-common)
(deftheme spacemacs-dark "Spacemacs theme, the dark version")
(create-spacemacs-theme 'dark 'spacemacs-dark)
(provide-theme 'spacemacs-dark)

(menu-bar-mode -1)
(toggle-scroll-bar -1)
(tool-bar-mode -1)
