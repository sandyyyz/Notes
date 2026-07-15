set nocscopeverbose
set nocompatible

"set textwidth=80
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" 插件管理
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" no vi compat
set nocompatible
" filetype func off
filetype off
" initialize vundle
set rtp+=~/.vim/bundle/Vundle.vim

call vundle#begin()
" start- all plugins below

Plugin 'VundleVim/Vundle.vim'
Plugin 'morhetz/gruvbox'
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'
Plugin 'suan/vim-instant-Markdown'
Bundle 'Valloric/YouCompleteMe'

" stop - all plugins above
call vundle#end()
filetype plugin indent on

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sets how many lines of history VIM has to remember
set history=1000

" Set to auto read when a file is changed from the outside
set autoread
" Enable filetype plugin
"filetype plugin on
" Enable filetype indent
"filetype indent on
filetype plugin indent on
filetype on
let g:neocomplcache_enable_at_startup = 1
"let g:neocomplcache_enable_auto_select = 1
set completeopt=longest,menu
"let g:SuperTabRetainCompletionType=2
"let g:SuperTabDefaultCompletionType="<C-X><C-O>"

" hightlight keyword
syntax on

"mouse
"enable mouse
"n:normal mode
"v: visual mode
"i: input mode
"c: cmdline mode
"h:help
"a:all
set mouse=a
set mouse=i
set mouse=c
set mouse=h
set mouse=n
set mouse=v
set selection=exclusive
set selectmode=mouse,key

"set clipboard+=unnamed
set clipboard=unnamedplus

set fenc=utf-8
set fencs=utf-8,usc-bom,euc-jp,gb18030,gbk,gb2312,cp936
set fileencoding=utf-8
"set encoding=cp936

highlight StatusLine guifg=SlateBlue guibg=Yellow
highlight StatusLineNC guifg=Gray guibg=White


set report=0

set matchtime=5

set t_Co=256

set background=dark

colorscheme gruvbox
"colorscheme darkburn
"colorscheme elflord
"colorscheme torte
"colorscheme darkblue
"colorscheme koehler
"colorscheme morning
"colorscheme murphy
"colorscheme pablo
"colorscheme peachpuff
"colorscheme ron
"colorscheme shine
"colorscheme slate
"colorscheme evening
"colorscheme zellner
"colorscheme desert
"colorscheme delek
"colorscheme default
"colorscheme blue
"colorscheme zellner


""""""""""""""""""""""""""""""""""""""""""""""""""""
" => misc
"""""""""""""""""""""""""""""""""""""""""""""""""""""
" With a map leader it's possible to do extra key combinations
" like <leader>w saves the current file
let mapleader = ","
let g:mapleader = ","

set tags=tags;\
set path+=include;\

nmap <leader>x :%!xxd<CR>
"nmap mm :%!xxd -r<CR>
nmap qq :q!<cr>
nmap tt :Tlist<cr>
nmap ww <C-w><C-w>
nmap -- 5<C-w>-
nmap ++ 5<C-w>+
nmap >> 5<C-w>>
nmap << 5<C-w><
nmap 11 :set nonu<cr>
nmap 22 :set nu<cr>
nmap cm :!

"map <leader>s :split<cr>
"map <leader>v :vsplit<cr>
nmap <leader>s :split<cr>
nmap <leader>v :vsplit<cr>
nmap <leader>c <C-w>c
"For replace
nmap ff :1,$s///g
"exaple 12.aaa-->aaa
"nmap fk :1,$s/^.*\.//g<cr>



"Ignorecase
"nmap <F2> :set ic<cr>/
"No Ignorecase
"nmap <F3> :set noic<cr>

" Fast saving
nmap <leader>w :w!<cr>

" Create a new file
map <leader>e :e!

" Use the arrows to something usefull
"map <right> :bn<cr>
"map <left> :bp<cr>

" When pressing <leader>cd switch to the directory of the open buffer
"map <leader>cd :cd %:p:h<cr>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Tab configuration
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"nmap tn :tabnew<space>
"nmap tc :tabclose<cr>
"nmap nt :tabnext<cr>
"map <leader>te :tabedit
"map <leader>tm :tabmove


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => buffer
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Close all the buffers
"map <leader>ba :1,300 bd!<cr>
" Close the current buffer
"map <leader>bd :Bclose<cr>
nmap bd :bdelete<cr>
nmap vv :bnext<cr>
nmap zz :bprevious<cr>
map <leader>u :TMiniBufExplorer<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => comments
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"F7 for comment
"For C/C++
"vmap <F7> :s=^\(//\)*=//=g<cr>:noh<cr>
"nmap <F7> :s=^\(//\)*=//=g<cr>:noh<cr>
""imap <F7> <ESC>:s=^\(//\)*=//=g<cr>:noh<cr>
""F6 for uncomment
"vmap <F6> :s=^\(//\)*==g<cr>:noh<cr>
"nmap <F6> :s=^\(//\)*==g<cr>:noh<cr>
""imap <F6> <ESC>:s=^\(//\)*==g<cr>:noh<cr>

vmap <C-S-P> dO#endif<Esc>PO#if 0<Esc>
nmap c<space> :<leader>c<space>

"For shell or Makefile
"vmap <leader># :s=^\(#\)*=#=g<cr>:noh<cr>
""nmap <leader># :s=^\(#\)*=#=g<cr>:noh<cr>
""imap <leader># <ESC>:s=^\(#\)*=#=g<cr>:noh<cr>

"vmap <leader>" :s=^\("\)*="=g<cr>:noh<cr>
"nmap <leader>" :s=^\("\)*="=g<cr>:noh<cr>
"imap <leader>" <ESC>:s=^\("\)*="=g<cr>:noh<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Pressing ,ss will toggle and untoggle spell checking
map <leader>ss :setlocal spell!<cr>
"Shortcuts using <leader>
"map <leader>sn ]s
"map <leader>sp [s
"map <leader>sa zg
"map <leader>s? z=


let g:winManagerWindowLayout='FileExplorer|TagList'
"let g:winManagerWindowLayout='FileExplorer'
nmap wm :WMToggle<cr>
"map <F4> :WMToggle<CR>

"Taglist
let Tlist_Show_One_File=1
let Tlist_Exit_OnlyWindow=1


" Remove the Windows ^M - when the encodings gets messed up
noremap <Leader>m mmHmt:%s/<C-V><cr>//ge<cr>'tzt'm
"delete ^M
nmap dm :%s/\r\+$//e<cr>:set ff=unix<cr>
"set notextmode


"""""""""""""""""""""
"光标自动定位到上次关闭的位置处
" Make Vim jump to the last position when reopening a file
if has("autocmd")
	au BufReadPost * if line("`\"") > 1 && line("`\"") <= line("$") | exe "normal! g`\"" | endif
endif
"""""""""""""""""""""
"Only do this part when compiled with support for autocommands.
if has("autocmd")
	" When editing a file, always jump to the last known cursor position.
	" Don't do it when the position is invalid or when inside an event handler
	" (happens when dropping a file on gvim).
	autocmd BufReadPost *
				\ if line("'\"") > 0 && line("'\"") <= line("$") |
				\   exe "normal g`\"" |
				\ endif
endif " has("autocmd")



""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Maintainer: amix the lucky stiff
"             http://amix.dk - amix@amix.dk
"
" Version: 3.6 - 25/08/10 14:40:30
"
" Blog_post:
"       http://amix.dk/blog/post/19486#The-ultimate-vim-configuration-vimrc
" Syntax_highlighted:
"       http://amix.dk/vim/vimrc.html
" Raw_version:
"       http://amix.dk/vim/vimrc.txt
"
" How_to_Install_on_Unix:
"    $ mkdir ~/.vim_runtime
"    $ svn co svn://orangoo.com/vim ~/.vim_runtime
"    $ cat ~/.vim_runtime/install.sh
"    $ sh ~/.vim_runtime/install.sh <system>
"      <sytem> can be `mac`, `linux` or `windows`
"
" How_to_Upgrade:
"    $ svn update ~/.vim_runtime
"
" Sections:
"    -> General
"    -> VIM user interface
""    -> Colors and Fonts
"    -> Files and backups
"    -> Text, tab and indent related
"    -> Visual mode related
"    -> Command mode related
"    -> Moving around, tabs and buffers
"    -> Statusline
"    -> Parenthesis/bracket expanding
"    -> General Abbrevs
"    -> Editing mappings
"
"    -> Cope
"    -> Minibuffer plugin
"    -> Omni complete functions
"    -> Python section
"    -> JavaScript section
"
"
" Plugins_Included:
"     > minibufexpl.vim - http://www.vim.org/scripts/script.php?script_id=159
"       Makes it easy to get an overview of buffers:
"           info -> :e ~/.vim_runtime/plugin/minibufexpl.vim
"
"     > bufexplorer - http://www.vim.org/scripts/script.php?script_id=42
"       Makes it easy to switch between buffers:
"           info -> :help bufExplorer
"
"     > yankring.vim - http://www.vim.org/scripts/script.php?script_id=1234
"       Emacs's killring, useful when using the clipboard:
"           info -> :help yankring
"
"     > surround.vim - http://www.vim.org/scripts/script.php?script_id=1697
"       Makes it easy to work with surrounding text:
"           info -> :help surround
"
"     > snipMate.vim - http://www.vim.org/scripts/script.php?script_id=2540
"       Snippets for many languages (similar to TextMate's):
"           info -> :help snipMate
"
"     > mru.vim - http://www.vim.org/scripts/script.php?script_id=521
"       Plugin to manage Most Recently Used (MRU) files:
"           info -> :e ~/.vim_runtime/plugin/mru.vim
"
"     > Command-T - http://www.vim.org/scripts/script.php?script_id=3025
"       Command-T plug-in provides an extremely fast, intuitive mechanism for opening filesa:
"           info -> :help CommandT
"           screencast and web-help -> http://amix.dk/blog/post/19501
"
"
"  Revisions:
"     > 3.6: Added lots of stuff (colors, Command-T, Vim 7.3 persistent undo etc.)
"     > 3.5: Paste mode is now shown in status line  if you are in paste mode
"     > 3.4: Added mru.vim
"     > 3.3: Added syntax highlighting for Mako mako.vim
"     > 3.2: Turned on python_highlight_all for better syntax
"            highlighting for Python
"     > 3.1: Added revisions ;) and bufexplorer.vim
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Omni complete functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"autocmd FileType css set omnifunc=csscomplete#CompleteCSS
"autocmd FileType html set omnifunc=htmlcomplete#CompleteTags
"autocmd FileType python set omnifunc=pythoncomplete#Complete
"autocmd FileType javascript set omnifunc=javascriptcomplete#CompleteJS
"autocmd FileType xml set omnifunc=xmlcomplete#CompleteTags
"autocmd FileType php set omnifunc=phpcomplete#CompletePHP
"autocmd FileType c set omnifunc=ccomplete#Complete

""""""""""""""""""""""""""""""
" => Python section
""""""""""""""""""""""""""""""
let python_highlight_all = 1
au FileType python syn keyword pythonDecorator True None False self

au BufNewFile,BufRead *.jinja set syntax=htmljinja
au BufNewFile,BufRead *.mako set ft=mako

au FileType python inoremap <buffer> $r return
au FileType python inoremap <buffer> $i import
au FileType python inoremap <buffer> $p print
au FileType python inoremap <buffer> $f #--- PH ----------------------------------------------<esc>FP2xi
au FileType python map <buffer> <leader>1 /class
au FileType python map <buffer> <leader>2 /def
au FileType python map <buffer> <leader>C ?class
au FileType python map <buffer> <leader>D ?def


""""""""""""""""""""""""""""""
" => JavaScript section
"""""""""""""""""""""""""""""""
au FileType javascript call JavaScriptFold()
au FileType javascript setl fen
au FileType javascript setl nocindent

au FileType javascript imap <c-t> AJS.log();<esc>hi
au FileType javascript imap <c-a> alert();<esc>hi

au FileType javascript inoremap <buffer> $r return
au FileType javascript inoremap <buffer> $f //--- PH ----------------------------------------------<esc>FP2xi

function! JavaScriptFold()
setl foldmethod=syntax
setl foldlevelstart=1
syn region foldBraces start=/{/ end=/}/ transparent fold keepend extend

function! FoldText()
return substitute(getline(v:foldstart), '{.*', '{...}', '')
endfunction
setl foldtext=FoldText()
endfunction


"imap () ()<Left>
"imap [] []<Left>
"imap {} {}<Left>
"imap "" ""<Left>
"imap <> <><Left>

" change word to uppercase
"inoremap <C-u> <esc>gUiwea



""""""""""""""""""""""""""""""
" => Command-T
""""""""""""""""""""""""""""""
let g:CommandTMaxHeight = 15
set wildignore+=*.o,*.obj,.git,*.pyc
noremap <leader>j :CommandT<cr>
noremap <leader>y :CommandTFlush<cr>
"Quickly open a buffer for scripbble
map <leader>q :e ~/buffer<cr>
au BufRead,BufNewFile ~/buffer iab <buffer> xh1 ===========================================

map <leader>pp :setlocal paste!<cr>

"map <leader>bb :cd ..<cr>

""""""""""""""""""""""""""""""
" => MRU plugin
""""""""""""""""""""""""""""""
let MRU_Max_Entries = 400
map <leader>f :MRU<CR>



"Move a line of text using ALT+[jk] or Comamnd+[jk] on mac
nmap <M-j> mz:m+<cr>`z
nmap <M-k> mz:m-2<cr>`z
vmap <M-j> :m'>+<cr>`<my`>mzgv`yo`z
vmap <M-k> :m'<-2<cr>`>my`<mzgv`yo`z






""""""""""""""""""""""""""""""
" => Visual mode related
""""""""""""""""""""""""""""""
" Really useful!
"  In visual mode when you press * or # to search for the current selection
vnoremap <silent> * :call VisualSearch('f')<CR>
vnoremap <silent> # :call VisualSearch('b')<CR>

" When you press gv you vimgrep after the selected text
vnoremap <silent> gv :call VisualSearch('gv')<CR>
map <leader>g :vimgrep // **/*.<left><left><left><left><left><left><left>


function! CmdLine(str)
exe "menu Foo.Bar :" . a:str
emenu Foo.Bar
unmenu Foo
endfunction

" From an idea by Michael Naumann
function! VisualSearch(direction) range
let l:saved_reg = @"
execute "normal! vgvy"

let l:pattern = escape(@", '\\/.*$^~[]')
let l:pattern = substitute(l:pattern, "\n$", "", "")

if a:direction == 'b'
execute "normal ?" . l:pattern . "^M"
elseif a:direction == 'gv'
call CmdLine("vimgrep " . '/'. l:pattern . '/' . ' **/*.')
elseif a:direction == 'f'
execute "normal /" . l:pattern . "^M"
endif

let @/ = l:pattern
let @" = l:saved_reg
endfunction



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Command mode related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Smart mappings on the command line
cno $h e ~/
cno $d e ~/Desktop/
cno $j e ./
cno $c e <C-\>eCurrentFileDir("e")<cr>

" $q is super useful when browsing on the command line
cno $q <C-\>eDeleteTillSlash()<cr>

" Bash like keys for the command line
cnoremap <C-A>		<Home>
cnoremap <C-E>		<End>
cnoremap <C-K>		<C-U>

cnoremap <C-P> <Up>
cnoremap <C-N> <Down>

" Useful on some European keyboards
"map 陆 $
"imap 陆 $
"vmap 陆 $
"cmap 陆 $


func! Cwd()
let cwd = getcwd()
return "e " . cwd
endfunc

func! DeleteTillSlash()
let g:cmd = getcmdline()
if MySys() == "linux" || MySys() == "mac"
let g:cmd_edited = substitute(g:cmd, "\\(.*\[/\]\\).*", "\\1", "")
else
let g:cmd_edited = substitute(g:cmd, "\\(.*\[\\\\]\\).*", "\\1", "")
endif
if g:cmd == g:cmd_edited
if MySys() == "linux" || MySys() == "mac"
let g:cmd_edited = substitute(g:cmd, "\\(.*\[/\]\\).*/", "\\1", "")
else
let g:cmd_edited = substitute(g:cmd, "\\(.*\[\\\\\]\\).*\[\\\\\]", "\\1", "")
endif
endif
return g:cmd_edited
endfunc

func! CurrentFileDir(cmd)
return a:cmd . " " . expand("%:p:h") . "/"
endfunc





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around, tabs and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Map space to / (search) and c-space to ? (backgwards search)
map <space> /
map <c-space> ?
map <silent> <leader><cr> :noh<cr>

" Smart way to move btw. windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l


command! Bclose call <SID>BufcloseCloseIt()
function! <SID>BufcloseCloseIt()
let l:currentBufNum = bufnr("%")
let l:alternateBufNum = bufnr("#")

if buflisted(l:alternateBufNum)
buffer #
else
bnext
endif

if bufnr("%") == l:currentBufNum
new
endif

if buflisted(l:currentBufNum)
execute("bdelete! ".l:currentBufNum)
endif
endfunction

" Specify the behavior when switching between buffers
try
set switchbuf=usetab
"  set stal=2           //shang mian xian shi
catch
endtry



function! CurDir()
let curdir = substitute(getcwd(), '/Users/amir/', "~/", "g")
return curdir
endfunction

function! HasPaste()
if &paste
return 'PASTE MODE  '
else
return ''
endif
endfunction


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => General Abbrevs
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
iab xdate <c-r>=strftime("%d/%m/%y %H:%M:%S")<cr>


"Delete trailing white space, useful for Python ;)
func! DeleteTrailingWS()
exe "normal mz"
%s/\s\+$//ge
exe "normal `z"
endfunc
autocmd BufWrite *.py :call DeleteTrailingWS()

set guitablabel=%t



""""""""""""""""""""""""""""""
" => Minibuffer plugin
""""""""""""""""""""""""""""""
let g:miniBufExplModSelTarget = 1
let g:miniBufExplorerMoreThanOne = 2
let g:miniBufExplModSelTarget = 0
let g:miniBufExplUseSingleClick = 1
let g:miniBufExplMapWindowNavVim = 1
"let g:miniBufExplVSplit = 25
"let g:miniBufExplSplitBelow=1

let g:miniBufExplMapWindowNavArrows = 1
let g:miniBufExplMapCTabSwitchBufs = 1

let g:bufExplorerSortBy = "name"

autocmd BufRead,BufNew :call UMiniBufExplorer


""""""""""""""""""""""""""""""
" => bufExplorer plugin
""""""""""""""""""""""""""""""
" Do not show default help.
let g:bufExplorerDefaultHelp=0
" Show relative paths
let g:bufExplorerShowRelativePath=1
"let g:bufExplorerSortBy='mru'        " Sort by most recently used.
"let g:bufExplorerSplitRight=1        " Split left.
"let g:bufExplorerSplitVertical=1     " Split vertically.
"let g:bufExplorerSplitVertSize = 30  " Split width
"let g:bufExplorerUseCurrentWindow=1  " Open in new window.
"let g:bufExplorerDisableDefaultKeyMapping =0 " Do not disable default key mappings.
map <leader>o :BufExplorer<cr>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Colors and Fonts
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"syntax enable "Enable syntax hl

"" Set font according to system
  "set gfn=Monospace\ 10
  "set shell=/bin/bash

"if has("gui_running")
  "set guioptions-=T
  "set t_Co=256
  "set background=dark
  "colorscheme peaksea
  "set nonu
"else
  "colorscheme zellner
  "set background=dark

  "set nonu
"endif

"set encoding=utf8
"try
    "lang en_US
"catch
"endtry





"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => MISC
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if &term=="xterm"
"set t_Co=8
set t_Sb=^[[4%dm
set t_Sf=^[[3%dm
endif


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => VIM user interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Set 7 lines to the curors - when moving vertical..
set so=7

set wildmenu "Turn on WiLd menu

set ruler "Always show current position(Line and column)

set cmdheight=1 "The commandbar height

set hid "Change buffer - without saving

" Set backspace config
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

set smartcase
"set ignorecase "Ignore case when searching

set hlsearch "Highlight search things

set incsearch "Make search act like search in modern browsers
set nolazyredraw "Don't redraw while executing macros

set magic "Set magic on, for regular expressions

set showmatch "Show matching bracets when text indicator is over them
set mat=2 "How many tenths of a second to blink

" No sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" When vimrc is edited, reload it
"autocmd! bufwritepost vimrc source ~/.vim_runtime/vimrc


""""""""""""""""""""""""""""""
" => Vim grep
""""""""""""""""""""""""""""""
let Grep_Skip_Dirs = 'RCS CVS SCCS .svn generated'
set grepprg=/bin/grep\ -nH



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Editing mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"Remap VIM 0
"map 0 ^


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Parenthesis/bracket expanding
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"vnoremap $1 <esc>`>a)<esc>`<i(<esc>
"vnoremap $2 <esc>`>a]<esc>`<i[<esc>
"vnoremap $3 <esc>`>a}<esc>`<i{<esc>
"vnoremap $$ <esc>`>a"<esc>`<i"<esc>
"vnoremap $q <esc>`>a'<esc>`<i'<esc>
"vnoremap $e <esc>`>a"<esc>`<i"<esc>

" Map auto complete of (, ", ', [
"inoremap $1 ()<esc>i
"inoremap $2 []<esc>i
"inoremap $3 {}<esc>i
"inoremap $4 {<esc>o}<esc>O
"inoremap $q ''<esc>i
"inoremap $e ""<esc>i
"inoremap $t <><esc>i

function ClosePair(char)
	if getline('.')[col('.') - 1] == a:char
		return "\<Right>"
	else
		return a:char
	endif
endf

"inoremap ( ()<ESC>i
"inoremap { {}<ESC>i
"inoremap [ []<ESC>i
"inoremap < <><ESC>i
"inoremap ) <c-r>=ClosePair(')')<CR>
"inoremap } <c-r>=ClosePair('}')<CR>
"inoremap ] <c-r>=ClosePair(']')<CR>
"inoremap > <c-r>=ClosePair('>')<CR>

"function! AutoPair(open, close)
"        let line = getline('.')
"        if col('.') > strlen(line) || line[col('.') - 1] == ' '
"                return a:open.a:close."\<ESC>i"
"        else
"                return a:open
"        endif
"endf
"
"function! ClosePair(char)
"        if getline('.')[col('.') - 1] == a:char
"                return "\<Right>"
"        else
"                return a:char
"        endif
"endf
"
"function! SamePair(char)
"        let line = getline('.')
"        if col('.') > strlen(line) || line[col('.') - 1] == ' '
"                return a:char.a:char."\<ESC>i"
"        elseif line[col('.') - 1] == a:char
"                return "\<Right>"
"        else
"                return a:char
"        endif
"endf

"inoremap ( <c-r>=AutoPair('(', ')')<CR>
"inoremap ) <c-r>=ClosePair(')')<CR>
"inoremap { <c-r>=AutoPair('{', '}')<CR>
"inoremap } <c-r>=ClosePair('}')<CR>
"inoremap [ <c-r>=AutoPair('[', ']')<CR>
"inoremap ] <c-r>=ClosePair(']')<CR>
"inoremap " <c-r>=SamePair('"')<CR>
"inoremap ' <c-r>=SamePair("'")<CR>
"inoremap ` <c-r>=SamePair('`')<CR>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Files, backups and undo
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Turn backup off, since most stuff is in SVN, git anyway...
set nobackup
set nowb
set noswapfile
"set swapfile

"Persistent undo
try
	if MySys() == "windows"
		set undodir=C:\Windows\Temp
	else
		set undodir=~/.vim_runtime/undodir
	endif

	set undofile
catch
endtry


""""""""""""""""""""""""""""""
" => Statusline
""""""""""""""""""""""""""""""
" Always show the statusline
set laststatus=2

" Format the statusline
"set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{CurDir()}%h\ \ \ Line:\ %l/%L:%c
set statusline=%F%m%r%h%w\[POS=%l,%v][%p%%]\%{strftime(\"%d/%m/%y\ -\ %H:%M\")}


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set autoindent
"set ai "Auto indent
set si "Smart indet
set cindent
set smarttab
set shiftwidth=8
set softtabstop=8
" set ts=8, ts is tabstop
set tabstop=8
set noexpandtab
"set shiftwidth=4
"set softtabstop=4
"set tabstop=4

set wrap "Wrap lines
"set nowrap "noWrap lines
"set tw=78
"set lbr

set nu

"set paste


set cursorcolumn
"hi CursorColumn cterm=NONE ctermbg=darkred ctermfg=white guibg=darkred guifg=white
set cursorline
"hi CursorLine cterm=NONE ctermbg=darkred ctermfg=white guibg=darkred guifg=white


if has("cscope")
	" 指定用来执行cscope的命令
	set csprg=/usr/bin/cscope
	" 设置cstag命令查找次序：0先找cscope数据库再找tags文件；1先找tags文件再找cscope数据库
	set csto=1
	" 同时搜索cscope数据库和tags文件
	set cst
	" 使用QuickFix窗口来显示cscope查找结果
	"set cscopequickfix=s-,c-,d-,i-,t-,e-
	"添加cscope数据库时提示是否成功或者失败
	"set csverb
	"添加cscope数据库时不提示是否成功或者失败
	"set nocsverb
	"‘cspc’的值决定了一个文件的路径的多少部分被显示。默认值是0，所以整个路径都会被显示。值为1的话，那么就只会显示文件名，不带路径。
	set cspc=5
	"set cscopetag
	" 若当前目录下存在cscope数据库，添加该数据库到vim
	if filereadable("cscope.out")
		set nocscopeverbose
		cs add cscope.out
	" 否则只要环境变量CSCOPE_DB不为空，则添加其指定的数据库到vim
	elseif $CSCOPE_DB  != ""
		cs add $CSCOPE_DB
	"else search cscope.out elsewhere
	else
		let cscope_file=findfile("cscope.out", ".;")
		let cscope_pre=matchstr(cscope_file, ".*/")
		if !empty(cscope_file) && filereadable(cscope_file)
			exe "cs add" cscope_file cscope_pre
		endif
	endif
        "查找本定义
	nmap <leader>g :cs find g<space>
        nmap cg :cs find g <C-R>=expand("<cword>")<CR><CR>
        "查找调用本函数的函数
        nmap cc :cs find c <C-R>=expand("<cword>")<CR><CR>
	"查找C代码符号
        "nmap cs :scs find s <C-R>=expand("<cword>")<CR><CR> :copen<CR><CR>
        nmap cs :cs find s <C-R>=expand("<cword>")<CR><CR>
        "查找本函数调用的函数
        nmap cd :cs find d <C-R>=expand("<cword>")<CR><CR>
        "查找字符串
        nmap ct :cs find t <C-R>=expand("<cword>")<CR><CR>
        nmap ce :cs find e <C-R>=expand("<cword>")<CR><CR>
        "查找这个文件<such as headr file>
        nmap cf :cs find f <C-R>=expand("<cfile>")<CR><CR>
        "查找保含该头文件的文件
        nmap ci :cs find i <C-R>=expand("<cfile>")<CR><CR>
        "nmap ci :cs find i <C-R>=expand("<cfile>")<CR><CR> :copen<CR><CR>
endif


"higlight the space end of line
highlight WhitespaceEOL ctermbg=red guibg=red
match WhitespaceEOL /\s\+$/

"delete space
"nmap fk :1,$s/ *$//g<cr>
nmap ds :%s/\s\+$//<cr>
"Display tab to >-, and space to -
"set listchars=tab:>-,trail:-


""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Fold
" indent: auto
" manual: manual(zf: create; zo: open)
""""""""""""""""""""""""""""""""""""""""""""""""""""""
set fdm=manual
"set fdm=indent


function AddTitle()
call setline(1, "/*")
call append(1, " *")
call append(2, " *")
call append(3, " * Copyright (C) 2016.")
call append(4, " *	http://")
call append(5, " * Author: Sun Jiwei <sjiwei@163.com>")
call append(6, " *")
call append(7, " * This program is free software; you can redistribute it and/or modify")
call append(8, " * it under the terms of the GNU General Public License as published by")
call append(9, " * the Free Software Foundation; either version 2 of the License, or")
call append(10, " * (at your option) any later version.")
call append(11, " *")
call append(12, " * This program is distributed in the hope that it will be useful,")
call append(13, " * but WITHOUT ANY WARRANTY; without even the implied warranty of")
call append(14, " * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the")
call append(15, " * GNU General Public License for more details.")
call append(16, " *")
call append(17, " * You should have received a copy of the GNU General Public License")
call append(18, " * along with this program; if not, write to the Free Software")
call append(19, " * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.")
call append(20, " *")
call append(21, " */")
endfunction

nmap zs :call AddTitle()<CR>:2<CR>
"nmap zs :call AddTitle()<CR>:$<CR>o



"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Cope
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Do :help cope if you are unsure what cope is. It's super useful!
map <leader>cc :botright cope<cr>
map <leader>n :cn<cr>
map <leader>p :cp<cr>

"以unix格式显示换行符
"nmap xsm :e ++ff=unix
"以dos格式显示换行符
"nmap xsd :e ++ff=dos

"set filetype=unix
"set ffs=unix,dos,mac "Default file types

"以UNIX的换行符格式保存文件，注意是去掉一个^M
":set ff=unix
"以dos的换行符格式保存文件, 注意是在行尾变为两个^M
"set ff=dos

"c 重新格式化长注释行不会添加注释; r 按回车不会添加注释; o 按o不会添加注释
"nmap nt :set fo-=cro<CR>
"au FileType * setl fo-=cro


set viminfo='1000
