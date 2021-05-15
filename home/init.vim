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
let g:polyglot_disabled = ['latex', 'c/c++', 'c++11', 'nix']
let g:UltiSnipsExpandTrigger='<c-h>'
let g:UltiSnipsJumpForwardTrigger='<c-h>'
let g:UltiSnipsJumpBackwardTrigger='<c-g>'
let g:UltiSnipsSnippetDirectories=['UltiSnips', '/home/dieraca/.config/nvim/snippets/UltiSnips/']

let g:tex_flavor = 'latex'
let g:vimtex_view_method='zathura'
let g:vimtex_quickfix_mode=0
set conceallevel=1
let g:tex_conceal='abdmg'
let g:vimtex_compiler_latexmk = {
                        \ 'options' : [
                        \   '-pdf',
                        \   '-pdflatex="xelatex --shell-escape %O %S"',
                        \   '-verbose',
                        \   '-file-line-error',
                        \   '-synctex=1',
                        \   '-interaction=nonstopmode',
                        \ ]
\}
"let g:vimtex_compiler_latexmk = {
                        "\ 'options' : [
                        "\   'main.tex',
                        "\   '-shell-escape',
                        "\   '-interaction=nonstopmode',
                        "\ ]
                        "\}
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
"autocmd FileType tex setlocal ts=2 sw=2 sts=0 expandtab spell
let g:vimtex_complete_enabled = 1
let g:vimtex_complete_close_braces = 1
let g:vimtex_complete_ignore_case = 1
let g:vimtex_complete_smart_case = 1
"let g:vimtex_complete_bib = 1
"
let g:deoplete#enable_at_startup=1
let g:vimtex_compiler_progname='nvr'
"set spell spelllang=en_us
"set spellfile=/home/dieraca/.config/nvim/spell/en.utf-8.add

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
nmap <leader>R <Plug>(coc-rename)

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
set nospell



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

set tabstop=4
set shiftwidth=4
set expandtab

