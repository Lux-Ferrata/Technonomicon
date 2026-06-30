# Technonomicon

Personal NixOS system configuration for Akmon (desktop) and Kvasir (ThinkPad T480s).

## Post-install steps

### Zotero — move data out of home root

Zotero defaults to `~/Zotero`. To move it to a hidden directory:

1. Open Zotero → **Edit → Preferences → Advanced → Files and Folders**
2. Under **Data Directory Location**, select **Custom** and set it to `~/.zotero`
3. Zotero will offer to move existing data — accept
4. Delete the old directory: `rm -rf ~/Zotero`


# TODO
## Major Changes
- [ ] switch to BTRFS
- [ ] Enable Impermance and TmpFS
- [ ] Full Disk Encryption
- [ ] Create Refrence Boot Image

## Packages to Add 
| Package | Why |
|---------|-----|
| `typst` + `tinymist` | Modern LaTeX alternative — compiles in milliseconds, cleaner syntax, first-class math |
| `julia` | Scientific computing; increasingly dominant in numerical math/physics |
| `R` + `rPackages` | Statistics and data science; required for most quant courses |
| `maxima` | Open-source computer algebra system (symbolic math, ODEs, integrals) |
| `octave` | MATLAB-compatible numerics for courses that require MATLAB |
| `gnuplot` | Quick plots from CLI/scripts without a full notebook |
| `quarto` | Reproducible academic documents integrating R, Python, Julia; replaces org-export to Hugo |
| `lean4` | Proof assistant — excellent for CS/math theory and formal verification |
| `gap` | Group theory CAS; useful for abstract algebra coursework |
| `sage` | Math Tool Chain |
| `foliate` | EPUB reader |
| `khal` + `vdirsyncer` | CalDAV calendar sync (Google Calendar in the terminal) |
| `calcurse` | TUI calendar |
| `julia-mono` (font) | Monospace font with Unicode math symbol coverage |
| `cm-unicode` (font) | Computer Modern Unicode — LaTeX-quality math in display contexts |
| **TUI email** | | |
| `aerc` + `notmuch` + `isync` + `msmtp` | Fast keyboard-only email triage from the terminal |
| **Quantified life** | | |
| `dijo` | TUI habit tracker with visual dot-streak grid |
| `porsmo` | TUI Pomodoro timer |
| `wtfutil` | Configurable terminal dashboard (tasks, clock, GitHub, etc.) |
| `activitywatch` | Automatic self-hosted app/window-usage tracker; privacy-respecting |
| `hledger` + `hledger-ui` + `hledger-web` | Modern plain-text accounting (better reports than ledger) |
| `haskellPackages.arbtt` | Rule-based automatic time tracker (X/Wayland window titles → categories) |
| `datasette` | SQLite data browser/API; great for exploring activitywatch or custom tracking DBs |
| **Extra Hyprland tools** | | |
| `hyprpicker` | Wayland color picker (replaces `wl-color-picker`) |
| `satty` | Screenshot annotation tool |
| `wf-recorder` | Lightweight Wayland screen recorder |
| `nwg-look` | GTK theme configurator for Wayland |
| **Terminal tools** | | |
| `glow` | Render markdown in terminal |
| `presenterm` | Markdown-based terminal presentations |
| `frogmouth` | TUI markdown reader with navigation |

