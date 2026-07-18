;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; =============================================================================
;; STAGE 1 (cosmetics & non-blocking editor UX) — see the emacs-perf-bisection
;; plan. Later stages (org, org-roam, tree-sitter, forge, LSP, AI tooling) are
;; deliberately left out for now and reintroduced one at a time.
;; =============================================================================

(after! doom-modeline
  (setq display-time-default-load-average nil)
  (setq display-time-format "%H:%M")
  (setq doom-modeline-battery t)
  (setq doom-modeline-persp-name t)
  (display-time-mode 1)
  (display-battery-mode 1))

(after! vterm
  (advice-add #'vterm--redraw :around
              (lambda (orig-fun &rest args)
                (let ((cursor-type cursor-type))
                  (apply orig-fun args)))))

(defun Tn/open-dashboard (&optional frame)
  "Open the Doom dashboard in FRAME, with fallback if the autoload is unavailable."
  (let ((frame (or frame (selected-frame))))
    (cond
     ((fboundp '+doom-dashboard/open)
      (+doom-dashboard/open frame))
     ((require 'doom-dashboard nil t)
      (when (fboundp '+doom-dashboard/open)
        (+doom-dashboard/open frame)))
     (t
      (with-selected-frame frame
        (switch-to-buffer (doom-fallback-buffer)))))))

(when (daemonp)
  ;; `doom-init-ui-h' (which shows the dashboard) runs on `window-setup-hook',
  ;; which fires once at daemon boot, before any client frame exists. Doom's
  ;; own font/theme hooks already defer correctly to `server-after-make-frame-hook'
  ;; (see doom-emacs.el), but the dashboard doesn't, so the first client frame
  ;; needs an explicit nudge once its own theme/fonts have settled.
  (add-hook 'after-make-frame-functions
            (defun +doom-daemon-frame-init-h (frame)
              (when (display-graphic-p frame)
                (remove-hook 'after-make-frame-functions #'+doom-daemon-frame-init-h)
                (run-with-idle-timer 0.1 nil #'Tn/open-dashboard frame)))))

;; =============================================================================
;; 1. PERSONAL IDENTITY & SYSTEM
;; =============================================================================
(setq user-full-name "Xin IronShark"
      user-mail-address "xin@ironshark.org")

(setq confirm-kill-emacs nil)
(setq ispell-program-name "hunspell")
(setq confirm-kill-processes nil)

(global-visual-line-mode t)

(setq scroll-preserve-screen-position t
      scroll-conservatively 0
      maximum-scroll-margin 0.5
      scroll-margin 99999)

(use-package! exec-path-from-shell
  :config
  ;; Daemon startup has no window-system yet, so also check `daemonp' —
  ;; otherwise exec-path-from-shell never runs and clients inherit whatever
  ;; minimal PATH the daemon's own launch environment happened to have.
  (when (or (daemonp) (memq window-system '(mac ns x pgtk)))
    (exec-path-from-shell-initialize)))

(setq initial-major-mode 'org-mode)
(setq initial-scratch-message nil)

(setq org-directory "~/Grimoire/")
(setq org-cite-global-bibliography '("~/Grimoire/bibtex.bib"))

(add-hook 'org-mode-hook 'flyspell-mode)

;; =============================================================================
;; 2. UI, FONTS & THEME
;; =============================================================================
(setq doom-font (font-spec :family "JetBrains Mono" :size 23))
(setq doom-theme 'doom-city-lights)
(setq display-line-numbers-type 'visual)
(add-hook 'visual-line-mode-hook
          (lambda ()
            (setq wrap-prefix (propertize "  ↳ " 'face 'font-lock-comment-face))))

(custom-set-faces!
  '(default :foreground "#CFDFDF")
  '(font-lock-comment-face :foreground "#8C98A6" :slant italic)
  '(font-lock-constant-face :foreground "#FFD700" :weight bold)
  '(font-lock-type-face :foreground "#FFCB6B")
  '(font-lock-number-face :foreground "#FF9F43")
  '(font-lock-string-face :foreground "#FF5370")
  '(font-lock-keyword-face :foreground "#00FFFF" :weight bold)
  '(font-lock-variable-name-face :foreground "#00FA9A")
  '(font-lock-function-name-face :foreground "#1E90FF" :weight bold)
  '(org-level-1 :foreground "#00FFFF" :weight bold :height 1.5 :box (:line-width 5 :color "#1D232F"))
  '(org-level-2 :foreground "#00FFFF" :weight bold :height 1.4 :box (:line-width 5 :color "#1D232F"))
  '(org-level-3 :foreground "#00FFFF" :weight bold :height 1.3 :box (:line-width 5 :color "#1D232F"))
  '(org-level-4 :foreground "#00FFFF" :weight bold :height 1.2 :box (:line-width 5 :color "#1D232F"))
  '(org-level-5 :foreground "#00FFFF" :weight bold :height 1.1 :box (:line-width 5 :color "#1D232F"))
  '(org-level-6 :foreground "#00FFFF" :weight bold :height 1.0 :box (:line-width 5 :color "#1D232F")))

(use-package! highlight-parentheses
  :hook (prog-mode . highlight-parentheses-mode)
  :config
  (setq hl-paren-colors '("#00FFFF" "#39FF14" "#FF00FF" "#FFD700" "#FF9F43"
                          "#00FA9A" "#1E90FF" "#FF5370" "#B24CFF" "#FF1493"))
  (set-face-attribute 'hl-paren-face nil :weight 'bold))

(add-hook 'prog-mode-hook 'whitespace-mode)

(add-hook 'before-save-hook #'delete-trailing-whitespace)

(setq whitespace-style '(face spaces tabs trailing space-mark tab-mark))

;; =============================================================================
;; 3. EDITOR BEHAVIOR & KEYBINDINGS
;; =============================================================================
(map! :i "C-S-v" #'clipboard-yank)
(map! :nvi "<f4>" #'+vterm/toggle)

(defun my/save-buffer-if-file ()
  "Save the current buffer if it's visiting a file and has been modified."
  (when (and (buffer-file-name) (buffer-modified-p))
    (save-buffer)))

(add-hook 'evil-normal-state-entry-hook #'my/save-buffer-if-file)
(add-hook 'evil-insert-state-entry-hook #'my/save-buffer-if-file)
(add-hook 'doom-switch-buffer-hook #'my/save-buffer-if-file)
(add-hook 'doom-switch-window-hook #'my/save-buffer-if-file)
(add-hook 'focus-out-hook #'my/save-buffer-if-file)

(plist-put +ligatures-extra-symbols :modes '(prog-mode text-mode org-mode markdown-mode))

(after! corfu
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))

;; Stop Emacs from calculating syntax highlighting while actively typing
(setq redisplay-skip-fontification-on-input t)

;; Unchoke the LSP data pipe (increase to 4MB)
(setq read-process-output-max (* 4 1024 1024))

;; Make Corfu suggestions appear instantly
(after! corfu
  (setq corfu-auto-delay 0.0
        corfu-auto-prefix 1))

;; Auto-commit-mode for prose writing
(use-package! git-auto-commit-mode
  :config
  (setq gac-automatically-push-p nil
        gac-automatically-add-new-files-p t
        gac-debounce-interval 1.0))

;; =============================================================================
;; 5. PROGRAMMING LANGUAGES & EWW
;; =============================================================================

(use-package! bqn-mode :mode "\\.bqn$")
(use-package! forth-mode :mode "\\.\\(fs\\|fth\\)$")
(add-to-list 'auto-mode-alist '("\\.asm\\'" . asm-mode))
;; NOTE: verilog/vhdl `lsp!' hooks deferred to the LSP stage (Stage 6).

(after! eww
  (setq eww-auto-rename-buffer t)
  (setq shr-use-fonts nil))

;; =============================================================================
;; 12. FIXED MOTIONS (non-tree-sitter half; the AST text-object part is
;; deferred to the tree-sitter stage, Stage 4)
;; =============================================================================

;; --- 1. Avy (On-Screen Jumping) ---
(after! evil-snipe
  (map! :map evil-snipe-local-mode-map :n "s" nil :n "S" nil)
  (map! :map evil-snipe-mode-map       :n "s" nil :n "S" nil)

  (map! :nv "s" #'avy-goto-char-timer
        :nv "S" #'avy-goto-line))

(after! avy
  (setq avy-timeout-seconds 0.3))

(map! :n "<up>"   #'evil-previous-visual-line
      :n "<down>" #'evil-next-visual-line)

;; =============================================================================
;; End Stage 1. Everything below is Doom's own stock config.el boilerplate.
;; =============================================================================

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
