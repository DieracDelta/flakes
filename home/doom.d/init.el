
(setq-default evil-respect-visual-line-mode t)

(doom! :input

       :completion
       company
       (ivy +prescient +childframe +icons) ; a search engine for love and life

       ;; :desktop exwm

       :ui
       doom            ; what makes DOOM look the way it does
       doom-dashboard  ; a nifty splash screen for Emacs
       doom-quit       ; DOOM quit-message prompts when you quit Emacs
       fill-column     ; a `fill-column' indicator
       hl-todo         ; highlight TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW
       ;;hydra
       indent-guides   ; highlighted indent columns
       minimap         ; show a map of the code on the side
       modeline        ; snazzy, Atom-inspired modeline, plus API
       ;;nav-flash         ; blink cursor line after big motions
       ;;neotree           ; a project drawer, like NERDTree for vim
       ophints                ; highlight the region an operation acts on
       (popup +defaults)      ; tame sudden yet inevitable temporary windows
       ligatures              ; ligatures or substitute text with pretty symbols
       ;; tabs              ; an tab bar for Emacs
       unicode                ; extended unicode support for various languages
       vc-gutter              ; vcs diff in the fringe
       vi-tilde-fringe        ; fringe tildes to mark beyond EOB
       ;;window-select     ; visually switch windows
       workspaces             ; tab emulation, persistence & separate workspaces

       :editor
       (evil +everywhere)               ; come to the dark side, we have cookies
       file-templates                   ; auto-snippets for empty files
       fold                             ; (nigh) universal code folding
       ;(format +onsave)                 ; automated prettiness
       lispy
       ;;god               ; run Emacs commands without modifier keys
       ;;multiple-cursors  ; editing in many places at once
       ;;objed             ; text object editing for the innocent
       ;;rotate-text       ; cycle region at point between text candidates
       snippets                       ; my elves. They type so I don't have to
       word-wrap                      ; soft wrapping with language-aware indent

       :emacs
       dired             ; making dired pretty [functional]
       electric          ; smarter, keyword-based electric-indent
       ;;ibuffer         ; interactive buffer management
       undo              ; persistent, smarter undo for your inevitable mistakes
       vc                ; version-control and Emacs, sitting in a tree

       :term
       ;;eshell            ; the elisp shell that works everywhere
       ;;shell             ; simple shell REPL for Emacs
       ;;term              ; basic terminal emulator for Emacs
       ;;vterm             ; the best terminal emulation in Emacs

       :checkers
       syntax        ; tasing you for every semicolon you forget
       ;;spell             ; tasing you for misspelling mispelling
       ;;grammar           ; tasing grammar mistake every you make

       :tools
       direnv
       editorconfig         ; let someone else argue about tabs vs spaces
       ;ein                  ; tame Jupyter notebooks with emacs
       (eval +overlay)      ; run code, run (also, repls)
       ;; gist              ; interacting with github gists
       lookup                         ; navigate your code and its documentation
       (lsp +lsp-mode +lsp-ui +peek)
       magit                     ; a git porcelain for Emacs
       ;;make              ; run make tasks from Emacs
       rgb                              ; creating color strings
       lsp

       :lang
       web
       ;cc                        ; C/C++/Obj-C madness
       common-lisp               ; if you've seen one lisp, you've seen them all
       data                      ; config/data formats
       coq
       ;elixir                     ; erlang done right
       ;elm                        ; care for a cup of TEA?
       emacs-lisp                 ; drown in parentheses
       ;erlang                     ; an elegant language for a more civilized age
       (go +lsp)                  ; the hipster dialect
       (haskell +dante +ghcide)   ; a language that's lazier than I am
       json                       ; At least it ain't XML
       (java +meghanada)          ; the poster child for carpal tunnel syndrome
       javascript                 ; all(hope(abandon(ye(who(enter(here))))))
       (latex +lsp +cdlatex +latexmk +fold) ; writing papers in Emacs has never been so fun
       lua                           ; one-based indices? one-based indices
       markdown                      ; writing docs for people to ignore
       nix                           ; I hereby declare "nix geht mehr!"
       ocaml                         ; an objective camel
       org                           ; organize your plain life in plain text
       ;perl                          ; write code no one else can comprehend
       ;php                           ; perl's insecure younger brother
       (python +lsp)                        ; beautiful is better than ugly
       (rust +lsp)                   ; Fe2O3.unwrap().unwrap().unwrap().unwrap()
       scala                         ; java, but good
       ;scheme                        ; a fully conniving family of lisps
       sh                            ; she sells {ba,z,fi}sh shells on the C xor
       yaml                          ; JSON, but readable

       :config
       (default +bindings )

       ;:app
       ;irc
       )
