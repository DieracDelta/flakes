;;; ~/.doom.d/+bindings.el -*- lexical-binding: t; -*-
(defun toggle_max ()
  "toggles/undoes max window"
  (interactive)
  (if (eq (length (window-list)) 1)
      (winner-undo)
    (delete-other-windows)))

(map!
 :nvieomrg "C-z" nil
 :nvieomrg "C-z C-x" nil
 :nvieomrg "<f5>" 'evil-write)

;; a reminder that
;; spc-s-p means search project
;; spc-s-d means search cwd
;; spc-s-b means search buffer
(map!
 :leader
 :desc "M-x" "SPC" #'execute-extended-command
 :desc "comment region" "c SPC" #'evilnc-comment-or-uncomment-lines
 :desc "yank and comment region" "y c" #'evilnc-copy-and-comment-lines
 :desc "magit status" "g s" #'magit-status
 :desc "nil" "g g" nil
 :desc "toggle maximize window" "w m" #'toggle_max
 :desc "jump to defn" "d" #'+lookup/definition
 :desc "toggle preview" "l p" #'latex-preview-pane-mode)





;; :desc "jump to defn" #')
;; TODO doom logo



;; some global keymaps
;;(global-unset-key (kbd "C-z"))
;;(global-unset-key (kbd "C-x C-z"))
;;(global-unset-key (kbd "<f5>"))
;;(global-set-key (kbd "<f5>") 'evil-write)
