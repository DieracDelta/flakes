{ config, pkgs, ... }:

{
# Let Home Manager install and manage itself.
	programs.home-manager.enable = true;

# This value determines the Home Manager release that your
# configuration is compatible with. This helps avoid breakage
# when a new Home Manager release introduces backwards
# incompatible changes.
#
# You can update Home Manager without changing this value. See
# the Home Manager release notes for a list of state version
# changes in each release.
	home.stateVersion = "19.09";
	programs.git.enable = true;
	programs.git.userEmail = "justin.p.restivo@gmail.com";
	programs.git.userName = "Justin Restivo";

	programs.fzf.enableZshIntegration = true;
	programs.zsh.enable = true;
	programs.zsh.enableCompletion = true;
	programs.zsh.enableAutosuggestions = true;
	programs.zsh.autocd = true;
#programs.zsh.defaultKeymap = "vicmd";
	programs.zsh.history.extended = true;
	programs.zsh.history.ignoreDups = true;
	programs.zsh.history.path = ".zsh_history";
	programs.zsh.history.save = 10000000;
	programs.zsh.history.share = true;
	programs.zsh.history.size = 10000000;
	programs.zsh.oh-my-zsh.enable = true;
#programs.zsh.oh-my-zsh.plugins = [ "git" "sudo" "fast-syntax-highlighting" "fzf-z" "z" ];
	programs.zsh.oh-my-zsh.plugins = [ "git" "sudo" "z" ];

# aliases
	programs.zsh.shellAliases = {
		"ll" = "ls -l";
		".." = "cd ..";
		"query" = "nix-store --query --requisites /run/current-system | cut -d- -f2- | sort -u";
		"hb" = "home-builder switch";
		"build_root" = "sudo nixos-rebuild switch";
		"query_vim_pkgs" = "nix-env -f '<nixpkgs>' -qaP -A vimPlugins";
		"gen_wal" = "wal --backend wal --iterative -i $HOME/Downloads/wallpapers/Future/";
                "delete_gens" = "nix-env -p /nix/var/nix/profiles/system --delete-generations old";
                "list_gens" = "nix-env -p /nix/var/nix/profiles/system --list-generations";
                "spawn_docker" = "docker run --rm -it -m=\"12G\" --memory-swap=\"0G\" --mount type=bind,src=$HOME/work,dst=/work bap:latest /bin/bash";
                "start_nix_shell" = "nix-shell --pure -E 'with import<nixpkgs> {}; callPackage ./. {}";
                "alacritty" = "env WINIT_UNIX_BACKEND=x11 alacritty & disown && exit";
                "nu" = "sudo nixos-rebuild switch -I $HOME/.config/nixpkgs/configuration.nix";
              };
	programs.zsh.initExtra = ''
                export _JAVA_AWT_WM_NONREPARENTING=1
		cat $HOME/.cache/wal/sequences
		ENDPOINTKEY='IAMNOTABOTYEET'
		function post_code {
                  INPUT_UNESCAPED=$(cat)
                  INPUT=''${INPUT_UNESCAPED//\\/\\\\}
                  echo -n "https://endpoints.justinrestivo.me/"$(echo -n '{"key":"'$ENDPOINTKEY'","src":"' $(echo $INPUT | base64) '"}' | curl -X POST https://endpoints.justinrestivo.me/code -H 'Content-Type: application/json' --data @- | jq -r '.link') | wl-copy
                }
                function scp_mits_color {
        ssh -f -N -l $KERBEROS athena.dialup.mit.edu
        ssh $KERBEROS@athena.dialup.mit.edu "mkdir printer_files"
        cmd=""
        for var in "$@"
        do
                #cmd+="lpr -P mitprint -U graceyin -o sides=two-sided-long-edge ~/printer_files/"
                # add -# 20 to print 20 copies
                #cmd+="lpr -P mitprint-color -o sides=two-sided-long-edge ~/printer_files/"
                cmd+="lpr -P mitprint-color -o sides=two-sided-long-edge ~/printer_files/"
                #cmd+="lpr -P mitprint ~/printer_files/"
                #cmd+="lpr -P mitprint ~/printer_files/"
                cmd+=$(basename $var)
                cmd+="; "
        done
        echo $cmd
        scp $@ $KERBEROS@athena.dialup.mit.edu:/mit/$KERBEROS/printer_files/
        ssh $KERBEROS@athena.dialup.mit.edu $cmd " rm -dr printer_files"
}

# double sided
function scp_mit {
        ssh -f -N -l $KERBEROS athena.dialup.mit.edu
        ssh $KERBEROS@athena.dialup.mit.edu "mkdir printer_files"
        cmd=""
        for var in "$@"
        do
                #cmd+="lpr -P mitprint -U graceyin -o sides=two-sided-long-edge ~/printer_files/"
                # add -# 20 to print 20 copies
                cmd+="lpr -P mitprint-color -o sides=two-sided-long-edge ~/printer_files/"
                cmd+="lpr -P mitprint -o sides=two-sided-long-edge ~/printer_files/"
                #cmd+="lpr -P mitprint -o ~/printer_files/"
                #cmd+="lpr -P mitprint ~/printer_files/"
                #cmd+="lpr -P mitprint ~/printer_files/"
                cmd+=$(basename $var)
                cmd+="; "
        done
        echo $cmd
        scp $@ $KERBEROS@athena.dialup.mit.edu:/mit/$KERBEROS/printer_files/
        ssh $KERBEROS@athena.dialup.mit.edu $cmd " rm -dr printer_files"
}

MAIM_LOCATION="/tmp/maim_screenshoot.png"

function post_image {
        grim -g "$(slurp)" -t "png" $MAIM_LOCATION
        echo -n "https://endpoints.justinrestivo.me/"$(echo -n '{"key": "'$ENDPOINTKEY'", "doCasify" : false, "src":"data:image/jpg;base64,'$(base64 -i $MAIM_LOCATION)'"}' | curl -X POST https://endpoints.justinrestivo.me/image -H 'Content-Type: application/json' --data @- | jq -r '.link' )  | wl-copy
}

export FZF_COMPLETION_TRIGGER='~~'

# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

if [ -n "''${commands[fzf-share]}" ]; then
  source "$(fzf-share)/key-bindings.zsh"
fi

function cd() {
    if [[ "$#" != 0 ]]; then
        builtin cd "$@";
        return
    fi
    while true; do
        local lsd=$(echo ".." && ls -p | grep '/$' | sed 's;/$;;')
        local dir="$(printf '%s\n' "''${lsd[@]}" |
            fzf --reverse --preview '
                __cd_nxt="$(echo {})";
                __cd_path="$(echo $(pwd)/''${__cd_nxt} | sed "s;//;/;")";
                echo $__cd_path;
                echo;
                ls -p --color=always "''${__cd_path}";
        ')"
        [[ ''${#dir} != 0 ]] || return 0
        builtin cd "$dir" &> /dev/null
    done
}

# Select a docker container to start and attach to
#function da() {
  #local cid
  #cid=$(docker ps -a | sed 1d | fzf -1 -q "$1" | awk '{print $1}')

  #[ -n "$cid" ] && docker start "$cid" && docker attach "$cid"
#}
# Select a running docker container to stop
function ds() {
  local cid
  cid=$(docker ps | sed 1d | fzf -q "$1" | awk '{print $1}')

  [ -n "$cid" ] && docker stop "$cid"
}
# Select a docker container to remove
function drm() {
  local cid
  cid=$(docker ps -a | sed 1d | fzf -q "$1" | awk '{print $1}')

  [ -n "$cid" ] && docker rm "$cid"
}
# Select a container to attach onto with bash
function da() {
  local cid
  cid=$(docker ps -a | sed 1d | fzf -q "$1" | awk '{print $1}')

  [ -n "$cid" ] && docker container exec -it "$cid" /bin/bash
}


		'';
	programs.zsh.oh-my-zsh.theme = "robbyrussell";
	programs.zsh.plugins =
		[
		{
			name = "fast-syntax-highlighting";
			src = pkgs.fetchFromGitHub {
				owner = "zdharma";
				repo = "fast-syntax-highlighting";
				rev = "303eeee81859094385605f7c978801748d71056c";
				sha256 = "0y0jgkj9va8ns479x3dhzk8bwd58a1kcvm4s2mk6x3n19w7ynmnv";
			};
		}
	{
		name = "fzf-z";
		src = pkgs.fetchFromGitHub {
			owner = "andrewferrier";
			repo = "fzf-z";
			rev = "2db04c704360b5b303fb5708686cbfd198c6bf4f";
			sha256 = "1ib98j7v6hy3x43dcli59q5rpg9bamrg335zc4fw91hk6jcxvy45";
		};
	}
		];

		programs.tmux.enable = true;
		programs.tmux.historyLimit = 1000000;
		programs.tmux.extraConfig = ''
			unbind C-b
			set -g prefix C-Space
			bind C-Space send-prefix

			setw -g mode-keys vi
			setw -g status-keys vi
			'';

#wayland.windowManager.sway.enable = true;
#wayland.windowManager.sway.extraSessionCommands = 
#	''
#	export SDL_VIDEODRIVER=wayland
#	export QT_QPA_PLATFORM=wayland
#	export QT_WAYLAND_DISABLE_WINDOWDECORATIONS="1"
#	export _JAVA_AWT_WM_NONREPARENTING=1
#	'';
#wayland.windowManager.sway.systemdIntegration = true;
#wayland.windowManager.sway.wrapperFeatures.gtk = true;
#


		programs.neovim.enable = true;
		programs.neovim.extraConfig = 
			''
			" TAKEN FROM ISAACS CONFIG (https://github.com/isaacmorneau/dotfiles/blob/master/.vim/vimrc)
colorscheme neodark
let g:tex_flavor = 'latex'
"Base vim setup
" Jump to last open
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
"Indentation rules for language
filetype plugin indent on
"why not use ed otherwise?
syntax on
"what am i typing
set showcmd
"what did i pick
set showmatch
"follow case like a normal person
set ignorecase
set smartcase
set cursorline

"i only have so much screen space
set wrap
"go back like a normal person
set backspace=indent,eol,start
"duh
set autoindent
set copyindent

set splitbelow
set splitright

"nnoremap <Space> <C-w>
let mapleader = "\<SPACE>"

tnoremap <Esc> <C-\><C-n>

"when entering a terminal enter in insert mode
"autocmd BufWinEnter,WinEnter term://* startinsert

"line numbers
set number
set relativenumber
"whats open?
set title
"dont care if its not valid,dont tell me
set noerrorbells
"(when i didnt have this before i wiped my hosts file)
set undofile
set undolevels=1000
set undoreload=10000
"reload when i change it with say git
set autoread
"manage buffers nicely
set hidden

"fold setting"
"folding settings
set foldmethod=indent   "fold based on indent
set foldnestmax=10      "deepest fold is 10 levels
set nofoldenable        "dont fold by default
set foldlevel=1         "this is just what i use



"give it a little bigger of a bump when i go off the edge
set scrolloff=3
set sidescrolloff=5
"visualize whitepsace
set listchars=tab:→→,trail:●,nbsp:○
set list
"if has('unnamedplus')
set clipboard=unnamed,unnamedplus
"endif
"ex mode is BS disable it
"nnoremap Q <nop>
"this is why we have airline
set noshowmode
"delete comment character when joining commented lines
set formatoptions+=j
"this enables true color support but will break how everything looks if you
"use a terminal that doesnt support it such as urxvt
set tgc
"set the encodings to be sane
" note that to add word to custom dictionary, use zg (and undo is zug)
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8
set bomb
set binary
set matchpairs+=<:>
"tabs are bad, also set this after encoding or weird things happen
set expandtab
let g:highlightedyank_highlight_duration = 400
set pastetoggle=<leader>v
"to avoid the mistake of uppercasing these
cnoreabbrev W! w!
cnoreabbrev Q! q!
cnoreabbrev Qa! qa!
cnoreabbrev Wq wq
cnoreabbrev Wa wa
cnoreabbrev wQ wq
cnoreabbrev WQ wq
cnoreabbrev W w
cnoreabbrev Q q
cnoreabbrev Qa qa
function! InitializeDirectories()
        let parent = $HOME
        let prefix = 'vim'
        let dir_list = {
                                \ 'backup': 'backupdir',
                                \ 'views':  'viewdir',
                                \ 'swap':   'directory',
                                \ 'undo':   'undodir' }

        let common_dir = parent . '/.' . prefix

        for [dirname, settingname] in items(dir_list)
                let directory = common_dir . dirname . '/'
                if exists("*mkdir")
                        if !isdirectory(directory)
                                call mkdir(directory)
                        endif
                endif
                if !isdirectory(directory)
                        echo "Warning: Unable to create backup directory: " . directory
                        echo "Try: mkdir -p " . directory
                else
                        let directory = substitute(directory, " ", "\\\\ ", "g")
                        exec "set " . settingname . "=" . directory
                endif
        endfor
        let g:scratch_dir = common_dir . 'scratch'. '/'
        if exists("*mkdir")
                if !isdirectory(g:scratch_dir)
                        call mkdir(g:scratch_dir)
                endif
        endif
        if !isdirectory(g:scratch_dir)
                echo "Warning: Unable to create scratch directory: " . g:scratch_dir
                echo "Try: mkdir -p " . g:scratch_dir
        endif
endfunction
call InitializeDirectories()

"been around for ages yet isnt default for % to match if else etc
runtime macros/matchit.vim
"so that line wraps are per terminal line not per global line
nnoremap j gj
nnoremap k gk
"work around for mouse selection to clipboard
"if term supports mouse then the selection will be visual anyway
vnoremap <LeftRelease> "*ygv
"i dont actually want visual mode mouse control
"but i still do want scroll and cursor clicking
set mouse=nv
let g:polyglot_disabled = ['latex', 'c/c++', 'c++11']
let g:UltiSnipsExpandTrigger='<c-h>'
let g:UltiSnipsJumpForwardTrigger='<c-h>'
let g:UltiSnipsJumpBackwardTrigger='<c-g>'
let g:UltiSnipsSnippetDirectories=['UltiSnips', '/home/dieraca/.config/nvim/snippets/UltiSnips/']

let g:tex_flavor = 'latex'
let g:vimtex_view_method='zathura'
let g:vimtex_quickfix_mode=0
set conceallevel=1
let g:tex_conceal='abdmg'
"let g:vimtex_compiler_latexmk = {
    "\ 'options' : [
    "\   '-pdf',
    "\   '-pdflatex="xelatex --shell-escape %O %S"',
    "\   '-verbose',
    "\   '-file-line-error',
    "\   '-synctex=1',
    "\   '-interaction=nonstopmode',
    "\ ]
    "\}
let g:vimtex_compiler_latexmk = {
    \ 'options' : [
    \   'main.tex',
    \   '-shell-escape',
    \   '-interaction=nonstopmode',
    \ ]
    \}
" my macros don't work withtectonic not sure why...
"let g:vimtex_compiler_latexmk = {
    "\ 'options' : [
    "\   '-pdf',
    "\   '-pdflatex="tectonic"',
    "\   '-verbose',
    "\   '-file-line-error',
    "\   '-synctex=1',
    "\   '-interaction=nonstopmode',
    "\ ]
    "\}

"[fzf]
"map <C-m> FZF<CR>
"map <s-enter> :FZF<CR>
set wildmode=list:longest,list:full
set wildignore+=*.o,*.obj,.git,*.rbc,*.pyc,__pycache__
let $FZF_DEFAULT_COMMAND =  "find * -path '*/\.*' -prune -o -path 'node_modules/**' -prune -o -path 'target/**' -prune -o -path 'dist/**' -prune -o  -type f -print -o -type l -print 2> /dev/null"
map <leader>bb :Buffers<cr>
map <leader>bl :Lines<cr>
map <leader>bt :BTags<cr>
map <leader>bm :Marks<cr>
map <leader><leader> :FZF<cr>
map <leader>pp :pwd<cr>
map <leader>gg :Rg<cr>
nmap <silent> <leader>h :History<cr>
nmap <silent> <F5> :w<cr>

let g:fzf_layout = { 'window': 'call FloatingFZF()' }

function! FloatingFZF()
  let buf = nvim_create_buf(v:false, v:true)
  call setbufvar(buf, '&signcolumn', 'no')

  let height = float2nr(300)
  let width = float2nr(300)
  let horizontal = float2nr((&columns - width) / 2)
  let vertical = 1

  let opts = {
        \ 'relative': 'editor',
        \ 'row': 3,
        \ 'col': 20,
        \ 'width': width,
        \ 'height': height,
        \ 'style': 'minimal'
        \ }

  call nvim_open_win(buf, v:true, opts)
endfunction


"[Easy Align]
"Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
"Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" [ripgrep]
if executable('rg')
        let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'
        set grepprg=rg\ --vimgrep
        command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --fixed-strings --ignore-case --hidden --follow --glob "!.git/*" --color "always" '.shellescape(<q-args>).'| tr -d "\017"', 1, <bang>0)
endif


"[vim-simple-sessions]
" TODO I want =1 but idk how to get that to work lol
let g:ss_auto_exit=0

"[rainbow]
let g:rainbow_active = 1
"honestly the default config is fine
"
""[update-daily]
"custom command to also update remote plugins for stuff like deoplete
"let g:update_daily = 'PU'

"[Airline]
set laststatus=2
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif
let g:airline#extensions#coc#enabled = 1

let g:airline#extensions#tabline#enabled = 1

"i dont know what adds this bullshit but its annoying as hell
let g:omni_sql_no_default_maps = 1

let g:rustfmt_autosave = 1


"autocmd BufRead *.rs :setlocal tags=./rusty-tags.vi;/
"autocmd BufWritePost *.rs :silent! exec "!rusty-tags vi --quiet --start-dir=" . expand('%:p:h') . "&" | redraw!

" spacemacs keybinds
map <leader>ws :sp<cr>
map <leader>wv :vs<cr>
map <leader>bd :q<cr>
map <leader>bD :Bclose!<cr>
map <leader>wd :q<cr>
map <leader>bn :tabnext<cr>
map <leader>bp :tabprevious<cr>
map <leader>bN :tabedit<cr>
" enter spawns a new window
map <C-m> :tabedit<cr>:FZF<cr>


"split nav
map <leader>wl :wincmd l<cr>
map <leader>wj :wincmd j<cr>
map <leader>wk :wincmd k<cr>
map <leader>wh :wincmd h<cr>
map <leader>tv :vsplit<cr> :terminal<cr> A
map <leader>ts :split<cr> :terminal<cr> A
map <leader>tn :tab term<cr> A

map <leader>gt gt
map <leader>gT gT
" buffer management
map <leader>bn :bn<cr>
map <leader>bp :bp<cr>
map <leader>bd :bdelete<cr>
map <leader>bD :bdelete!<cr>
"map <leader>;;

map <leader>mb :VimtexCompile<cr>

inoremap <C-p> <Esc>: silent exec '.!inkscape-figures create "'.getline('.').'" "'.b:vimtex.root.'/figures/"'<CR><CR>:w<CR>
nnoremap <C-p> : silent exec '!inkscape-figures edit "'.b:vimtex.root.'/figures/" > /dev/null 2>&1 &'<CR><CR>:redraw!<CR>

"Cntrl + l to fix previous spelling mistake
inoremap <C-l> <c-g>u<Esc>[s1z=`]i<c-g>u
"latex sane tabs + spelling
autocmd FileType tex setlocal ts=2 sw=2 sts=0 expandtab spell
let g:vimtex_complete_enabled = 1
let g:vimtex_complete_close_braces = 1
let g:vimtex_complete_ignore_case = 1
let g:vimtex_complete_smart_case = 1
"let g:vimtex_complete_bib = 1
"
let g:deoplete#enable_at_startup=1
let g:vimtex_compiler_progname='nvr'
set spell spelllang=en_us
set spellfile=/home/dieraca/.config/nvim/spell/en.utf-8.add

"colorizer config
let g:colorizer_auto_color=1

" coc config
" Show all diagnostics; escape to get out
nnoremap <silent> <leader>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
nnoremap <silent> <leader>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <leader>c  :<C-u>CocList commands<cr>
" Find symbol of current document
nnoremap <silent> <leader>o  :<C-u>CocList outline<cr>
" Search workleader symbols
nnoremap <silent> <leader>s  :<C-u>CocList -I symbols<cr>
" Resume latest coc list
nnoremap <silent> <leader>p  :<C-u>CocListResume<CR>
" fix current line
nmap <leader>qq  <Plug>(coc-fix-current)

"" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>
function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" Use `[c` and `]c` to navigate errors in current project
nmap <silent> [c <Plug>(coc-diagnostic-prev)
nmap <silent> ]c <Plug>(coc-diagnostic-next)
" error handling aimed at vimtex specifically
nmap <silent> <leader>ee :VimtexErrors<cr>

" Remap keys for gotos
nmap <silent> <leader>d <Plug>(coc-definition)
nmap <silent> <leader>td <Plug>(coc-type-definition)
nmap <silent> <leader>i <Plug>(coc-implementation)
nmap <silent> <leader>r <Plug>(coc-references)
vnoremap <leader>yc y:call NERDComment('x', 'Toggle')<cr>p
vnoremap <leader>wc :w !detex \| wc -w<CR>
nmap <leader>ww :OnlineThesaurusCurrentWord<CR>
"vnoremap <leader>ww :w !detex \| wc -w<CR>

"nmap <leader>kk :Vista!!<cr>

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')
nmap <leader>l :Format<cr>

nmap <C-Tab> gt
nmap <C-S-Tab> gT
nmap <leader>tt :tabedit<cr>:Explore<cr>

nmap <C-j> :tabprevious<cr>
nmap <C-k> :tabnext<cr>
" don't work
"nmap <C-S-k> :bn<cr>
"nmap <C-S-j> :bp<cr>
nmap <C-l> :tabm +1<cr>
nmap <C-h> :tabm -1<cr>


nmap <leader>gs :MagitOnly<cr>
nmap <C-Backspace> :call TermOpen('~/.config/nvim/ranger/ranger.py')<CR>

" for markdown
"nnoremap <F5> :s/^\s*\(-<space>\\|\*<space>\)\?\zs\(\[[^\]]*\]<space>\)\?\ze./[<space>]<space>/<CR>
"nnoremap <silent> <F5> :s/^\s*\(-<space>\\|\*<space>\)\?\zs\(\[[^\]]*\]<space>\)\?\ze./[<space>]<space>/<CR>0f]h
"nnoremap <silent> <F6> :s/^\s*\(-<space>\\|\*<space>\)\?\zs\(\[[^\]]*\]<space>\)\?\ze./[x]<space>/<CR>0f]h
"vnoremap <silent> <F5> :s/^\s*\(-<space>\\|\*<space>\)\?\zs\(\[[^\]]*\]<space>\)\?\ze./[<space>]<space>/<CR>0f]h
"vnoremap <silent> <F6> :s/^\s*\(-<space>\\|\*<space>\)\?\zs\(\[[^\]]*\]<space>\)\?\ze./[x]<space>/<CR>0f]h

set fillchars=vert:┃ " for vsplits

set fillchars+=fold:· " for folds

hi VertSplit guifg=#FF5C8F

nnoremap <F8>  :call S_copyPasteMode()<cr>
nnoremap <F9> :call S_exitCopyPasteMode()<cr>

function S_copyPasteMode()
        GitGutterDisable
        set nonumber
        set norelativenumber
endfunction

function S_exitCopyPasteMode()
        GitGutterEnable
        set relativenumber
        set number
endfunction

set breakindent

set statusline+=%{NearestMethodOrFunction()}

" By default vista.vim never run if you don't call it explicitly.
"
" If you want to show the nearest function in your statusline automatically,
" you can add the following line to your vimrc
"autocmd VimEnter * call vista#RunForNearestMethodOrFunction()

" vista stuff
"let g:vista_default_executive = 'coc'
"let g:vista#renderer#icons = {
"\   "typeParameter": "->",
"\   "function": "->",
"\   "method": "->",
"\   "field": "->",
"\   "variable": "->",
"\   "constant": "->",
"\   "struct": "->",
"\  }

" latex specific things

let g:airline_section_b = ""
let g:airline_detect_modified=1
let g:airline_detect_paste=0
let g:airline_detect_crypt=0
let g:airline_detect_spell=0
let g:airline_detect_spelllang=0
let g:airline_symbols_ascii = 1
let g:airline_skip_empty_sections = 1
let g:airline_highlighting_cache = 1
let g:airline_section_y  = ""
let g:airline_section_z  = "%P"

" really just to help me remember, with shitty regex:
" peekaboo: ("|@)(space)?



autocmd BufReadPre *.tex let b:vimtex_main = 'main.tex'
let g:indentLine_fileTypeExclude = ['tex', 'markdown']
"TODO fix
"let g:indentLine_concealcursor = \'\'
let g:indentLine_conceallevel = 1
let g:Illuminate_delay = 0
hi CursorLine gui=underline cterm=underline

nnoremap <Leader>t :ThesaurusQueryReplaceCurrentWord<CR>


" thing to show all hl groups
nmap <leader>po :so $VIMRUNTIME/syntax/hitest.vim<CR>
nmap <leader>pp :call <SID>SynStack()<CR> nmap <leader>pp :call <SID>SynStack()<CR>
function! <SID>SynStack()
  if !exists("*synstack")
    return
  endif
  echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunc

" this would be cool if inactive window included other details of the inactive
" window : P
" active window highlighting
"hi ActiveWindow guifg=NONE guibg=#181d26 gui=NONE
"hi InactiveWindow guifg=NONE guibg=#151810 gui=NONE

 ""Call method on window enter
"augroup WindowManagement
  "autocmd!
  "autocmd WinEnter * call Handle_Win_Enter()
"augroup END

"" Change highlight group of active/inactive windows
"function! Handle_Win_Enter()
  "setlocal winhighlight=Normal:ActiveWindow,NormalNC:InactiveWindow
"endfunction
nnoremap S :keeppatterns substitute/\s*\%#\s*/\r/e <bar> normal! ==<CR>


" adds in coc ultisnip CR completion
" TODO set this up TODOTODO
"inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm() :
   "\"\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
for s:char in [ '_', '.', ':', ',', ';', '<bar>', '/', '<bslash>', '*', '+', '%', '$' ]
  execute 'xmap i' . s:char . ' <Plug>(textobj-sandwich-query-i)' . s:char
  execute 'omap i' . s:char . ' <Plug>(textobj-sandwich-query-i)' . s:char
  execute 'xmap a' . s:char . ' <Plug>(textobj-sandwich-query-a)' . s:char
  execute 'omap a' . s:char . ' <Plug>(textobj-sandwich-query-a)' . s:char
endfor

			'';
                programs.neovim.extraPython3Packages = (ps: with ps; [ jedi flake8 pep8 ]);
		programs.neovim.plugins = [
		        pkgs.vimPlugins.fugitive
			pkgs.vimPlugins.vim-illuminate
			pkgs.vimPlugins.neodark-vim
			pkgs.vimPlugins.gitgutter
			pkgs.vimPlugins.rainbow
			pkgs.vimPlugins.fzf-vim
			pkgs.vimPlugins.fzfWrapper
			pkgs.vimPlugins.vim-better-whitespace
			pkgs.vimPlugins.vim-polyglot
			pkgs.vimPlugins.vim-surround
			pkgs.vimPlugins.vim-airline
			pkgs.vimPlugins.vim-gutentags
			pkgs.vimPlugins.bclose-vim
			pkgs.vimPlugins.indentLine
			pkgs.vimPlugins.nerdcommenter
			pkgs.vimPlugins.vim-speeddating
			pkgs.vimPlugins.vim-textobj-variable-segment
			pkgs.vimPlugins.vim-textobj-user
			pkgs.vimPlugins.vim-eunuch
			pkgs.vimPlugins.ultisnips
			pkgs.vimPlugins.vim-snippets
			pkgs.vimPlugins.vimtex
			pkgs.vimPlugins.delimitMate
			pkgs.vimPlugins.wal-vim
			pkgs.vimPlugins.coc-nvim
			pkgs.vimPlugins.coc-python
			pkgs.vimPlugins.coc-emmet
			pkgs.vimPlugins.vim-sandwich
			];
		programs.neovim.viAlias = true;
		programs.neovim.vimAlias = true;
		programs.neovim.withNodeJs = true;
                #programs.neovim.withPython = true;
                programs.neovim.withPython3 = true;
		programs.neovim.withRuby = true;




		nixpkgs.overlays = [ (import ./overs) ] ;
		home.packages = [ pkgs.rootbar pkgs.grim pkgs.slurp pkgs.clipman pkgs.wl-clipboard pkgs.opam2nix pkgs.deepfry pkgs.imagemagick ];
		manual.html.enable = true;

                programs.opam.enable = true;
                programs.opam.enableZshIntegration = true;
}
