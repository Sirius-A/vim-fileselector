if exists('g:loaded_fileselector') || &compatible
    finish
endif

let g:loaded_fileselector=1

if !exists('g:fileselector_extra_dirs')
    let g:fileselector_extra_dirs=''
endif

if !exists('g:fileselector_exclude_pattern')
    let g:fileselector_exclude_pattern='/.git'
endif

let s:mru_file_dir = $HOME . '/.cache/vim-fileselector'
let s:mru_file = s:mru_file_dir . '/mru'
let s:mru_max_length = 1000

call mkdir(s:mru_file_dir, 'p')

let s:mru_files = []

function! s:MRU_AddFile(bufnr_filetoadd)
    let fname = fnamemodify(bufname(a:bufnr_filetoadd + 0), ':p')
    if fname ==# '' || &buftype !=# ''
        return
    endif

    if g:fileselector_exclude_pattern !=# []
        if fname =~# join(g:fileselector_exclude_pattern, '\|')
            return
        endif
    endif

    let idx = index(s:mru_files, fname)
    if idx == -1 && !filereadable(fname)
        return
    endif

    if filereadable(s:mru_file)
        let s:mru_files = readfile(s:mru_file)
        if s:mru_files[0] =~# '^#'
            call remove(s:mru_files, 0)
        else
            let s:mru_files = []
        endif
    else
        let s:mru_files = []
    endif

    call filter(s:mru_files, 'v:val !=# fname')
    call insert(s:mru_files, fname, 0)

    if len(s:mru_files) > s:mru_max_length
        call remove(s:mru_files, s:mru_max_length, -1)
    endif

    let l = []
    call add(l, '# vim-fileselector - most recently used at the top')
    call extend(l, s:mru_files)
    call writefile(l, s:mru_file)
endfunction

augroup vim-fileselector
    autocmd BufRead * call s:MRU_AddFile(expand('<abuf>'))
    autocmd BufNewFile * call s:MRU_AddFile(expand('<abuf>'))
    autocmd BufWritePost * call s:MRU_AddFile(expand('<abuf>'))
augroup END

let s:zeroending = "tr '\\n' '\\0'"
let s:relativeifier = "xargs -0 realpath --relative-base=$HOME | sed -e 's/^\\([^\\/]\\)/~\\/\\1/'"
let s:existence_check = "perl -ne 'print if -e substr(\$_, 0, -1);'"

let s:source_mru = 'cat ' . s:mru_file . ' | ' . s:existence_check . ' | ' . s:zeroending
let s:source_git = 'git ls-files -z'

if executable('rg')
    " From some informal benchmarking I've done, rg seems to be ~50% faster
    " than fd at this query.
    let s:source_find_prefix = 'rg --color=never --hidden --files '
    let s:source_find_postfix = ''
elseif executable('fd')
    let s:source_find_prefix = 'fd --color=never --hidden --type file . '
    let s:source_find_postfix = ''
else
    let s:source_find_prefix = 'find '
    let s:source_find_postfix = ' -type f'
endif

if g:fileselector_extra_dirs !=# ''
    let s:source_find = s:source_find_prefix .
                \ g:fileselector_extra_dirs .
                \ s:source_find_postfix .
                \ " | egrep -v '" . join(g:fileselector_exclude_pattern, '|') . "' | " . s:zeroending
else
    let s:source_find = 'true'
endif

let s:deduplicator = "awk '!seen[$0]++'"

let s:sources = '{ ' . s:source_mru . ' ; ' . s:source_git . ' ; ' . s:source_find . '; } 2>/dev/null | ' . s:relativeifier . ' | ' . s:deduplicator

let s:preview = "echo {} | sed -e 's^~^$HOME^' | tr '\\n' '\\0' | xargs -0 head -\\$((\\$LINES-2))"

function! s:MRUDisplay()
    call fzf#run(fzf#wrap({'source': s:sources, 'options': '--tiebreak=index --preview="' . s:preview . '"'}))
endfunction

command! -bar MRUDisplay call <SID>MRUDisplay()
