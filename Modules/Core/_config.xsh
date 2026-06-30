import os
import subprocess

# Integrate "nix-shell" and "direnv" commands
execx($(nix-your-shell xonsh))

# =============================================================================
# 1. STANDARD SHELL OPTIONS & THEME
# =============================================================================
$AUTO_CD = True
$COLOR_INPUT = True
$HISTCONTROL = {'ignoredups'}

$COMPLETIONS_CONFIRM = False
$UPDATE_COMPLETIONS_ON_KEYPRESS = False
$COMPLETIONS_BRACKETS = False     # Stops looking up matching brackets on completion
$COMPLETION_QUERY_LIMIT = 50       # Prevents lag on massive directories (default is 100)

# Execution Time Tracking (Replaces OMZ 'timer')
$TIMER_FORMAT = '[Execution Time: {time:.2f}s]'
$TIMER_THRESHOLD = 3

# Colored Man Pages Configuration (Replaces OMZ 'colored-man-pages')
$LESS_TERMCAP_mb = "\x1b[1;31m"      # Begin blinking
$LESS_TERMCAP_md = "\x1b[1;36m"      # Begin bold
$LESS_TERMCAP_me = "\x1b[0m"         # End mode
$LESS_TERMCAP_se = "\x1b[0m"         # End standout-mode
$LESS_TERMCAP_so = "\x1b[01;33m"     # Begin standout-mode (info boxes)
$LESS_TERMCAP_ue = "\x1b[0m"         # End underline
$LESS_TERMCAP_us = "\x1b[1;4;32m"    # Begin underline

# =============================================================================
# 2. DYNAMIC SESSION VARIABLES
# =============================================================================
$SUDO_EDITOR = "nvim"
$EDITOR = "nvim"

# =============================================================================
# 3. INIT SCRIPTS & EXTERNAL PLUGINS
# =============================================================================
xontrib load direnv
xontrib load fzf-widgets

# FZF Keybindings
$fzf_history_binding = "c-r"
$fzf_ssh_binding = "c-s"
$fzf_file_binding = "c-t"
$fzf_dir_binding = "c-g"

execx($(zoxide init xonsh))
execx($(starship init xonsh))

# Clear screen on boot
print('\n' * 100, end='')
os.system("eza --icons --oneline --group-directories-first --color=always")

# =============================================================================
# 4. DIRECTORY ALIASES
# =============================================================================
aliases['tn'] = 'cd ~/Projects/Technonomicon'
aliases['ps'] = 'cd ~/Projects/Personal-Blog/content/posts'
aliases['pj'] = 'cd ~/Projects'
aliases['dl'] = 'cd ~/Downloads'

# Standard Safety/Utility Aliases (Replaces parts of OMZ 'git' & 'cp')
aliases['gst'] = 'git status -sb'
aliases['gco'] = 'git checkout'
aliases['gl'] = 'git log --oneline -n 10'
aliases['cp']  = 'cp -r'
aliases['cpv'] = 'rsync -h --progress'  # Modern rsync copy with progress bar

# =============================================================================
# 5. CORE EVENTS & HOOKS (Includes Auto-Eza)
# =============================================================================
_auto_ls_cwd = [os.getcwd()]

@events.on_postcommand
def auto_ls(cmd, rtn, out, ts, **kw):
    current = os.getcwd()
    if _auto_ls_cwd[0] != current:
        _auto_ls_cwd[0] = current
        os.system("eza --icons --oneline --group-directories-first --color=always")

# =============================================================================
# 6. CUSTOM SHELL UTILITIES & WRAPPERS
# =============================================================================

# --- Clipboard Utilities (Replaces OMZ 'copypath' & 'copyfile') ---
def _copypath(args):
    cwd = os.getcwd()
    subprocess.run(['wl-copy'], input=cwd.encode())
    print(f"📋 Copied current path: {cwd}")
aliases['copypath'] = _copypath

def _copyfile(args):
    if not args:
        print("Usage: copyfile <filename>")
        return 1
    try:
        with open(args[0], 'rb') as f:
            subprocess.run(['wl-copy'], input=f.read())
        print(f"📋 Copied contents of {args[0]}")
    except FileNotFoundError:
        print(f"❌ Error: File '{args[0]}' not found.")
aliases['copyfile'] = _copyfile

# --- Interactive FZF Menus (Replaces your original text utilities) ---
def _rg_menu(args):
    query = args[0] if args else ""
    rg -i @(query) | fzf
aliases['rg-menu'] = _rg_menu

def _rgx_menu(args):
    query = args[0] if args else ""
    rg --regex @(query) | fzf
aliases['rgx-menu'] = _rgx_menu

def _fd_menu(args):
    query = args[0] if args else ""
    fd -i @(query) | fzf
aliases['fd-menu'] = _fd_menu

def _fdx_menu(args):
    query = args[0] if args else ""
    fd --regex @(query) | fzf
aliases['fdx-menu'] = _fdx_menu

# --- Command Progress Monitor (Translates your monitor_command tool) ---
def _monitor_command(args):
    if not args:
        print("Usage: monitor_command <command> [args...]")
        return 1

    # Launch your target process in the background
    p = subprocess.Popen(args)
    try:
        # Run the progress command against the dynamic background PID
        subprocess.run(['progress', '-mp', str(p.pid)])
        p.wait()
    except KeyboardInterrupt:
        # Gracefully handle Ctrl+C interrupts without leaving orphan tasks
        p.terminate()
aliases['monitor_command'] = _monitor_command

# --- Splits PDFs into smaller files ---
def _pdf_split(args):
    if not args:
        print("Usage: pdf-split <filename.pdf>")
        return 1
    # Run natively using Xonsh's clean string formatting
    filename = args[0]
    os.system(f'nix-shell -p ocamlPackages.cpdf --run "cpdf -split-bookmarks 0 \'{filename}\' -utf8 -o \'@B.pdf\'"')
aliases['pdf-split'] = _pdf_split

# --- Clears Terminal Display ---
def _clear_all(args):
    # Runs the standard shell clear, then uses pure Python for the 100 newlines
    os.system('clear')
    print('\n' * 100, end='')
aliases['ca'] = _clear_all

# =============================================================================
# 6. CUSTOM WORD NAVIGATION & DELETION
# =============================================================================

$XONSH_CTRL_BKSP_DELETION = True

@events.on_ptk_create
def add_custom_keybindings(prompter, **kwargs):
    bindings = kwargs.get('bindings')
    if not bindings:
        return

    # --- Ctrl + Left Arrow: Jump to previous word ---
    @bindings.add('c-left')
    def _(event):
        b = event.current_buffer
        pos = b.document.find_start_of_previous_word(count=event.arg)
        if pos:
            b.cursor_position += pos

    # --- Ctrl + Right Arrow: Jump to next word ---
    @bindings.add('c-right')
    def _(event):
        b = event.current_buffer
        pos = b.document.find_end_of_next_word(count=event.arg)
        if pos:
            b.cursor_position += pos

# =============================================================================
# 7. CUSTOM SHELL ALIASES
# =============================================================================

aliases.update({
    'cat': 'bat',
    'cd': 'z',

    # Modern Search & Grep Tooling
    'find': 'fd -g -i',
    'grep': 'rg -i',
    'dd': 'caligula burn',

    # Advanced Eza Listing Configurations
    'lx': 'eza --icons --oneline --group-directories-first --color auto --all',
    'lld': 'eza --icons --oneline --group-directories-first --color auto --tree',
    'lxd': 'eza --icons --oneline --group-directories-first --color auto --tree --all --ignore-glob="??????????????????????????????????????"',
    'll': 'eza --icons --oneline --group-directories-first --color auto',
    'ls': 'eza --icons --oneline --group-directories-first --color auto --long',
    'lsx': 'eza --icons --oneline --group-directories-first --color auto --long --all',
    'ld': 'eza --icons --oneline --only-dirs --color auto',

    # Trash & Safe Removal
    'rm': 'trash-put -v',
    'rm-s': 'shred -f',
    'rm-r': 'trash-restore',

    # System Lifecycle Controls
    'power-off': 'bash /etc/scripts/clean-power-off.sh',
    'logout': 'sudo kill -9 -1',
    'restart': 'bash /etc/scripts/clean-reboot.sh',

    # Downloads & Compression
    'bzip': 'bzip3',
    'book-dl': 'aria2c -x 16 -s 16',

    # Editors
    'eo': 'nvim',
})

def _eon(args):
    if not args:
        print("Usage: eon <file>")
        return 1
    file = os.path.abspath(args[0])
    wdir = os.path.dirname(file)
    subprocess.Popen(
        ['ghostty', '--working-directory', wdir, '-e', 'nvim', file],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
aliases['eon'] = _eon
