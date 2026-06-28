(in-package :nyxt-user)

;;; Vim keybindings on web pages only — not on prompt/status/message buffers
;;; Scoping to web-buffer prevents vi-normal bindings from eating q/w in hint prompts
(define-configuration web-buffer
  ((default-modes (append '(vi-normal-mode) %slot-value%))))

;;; Start page
(define-configuration browser
  ((default-new-buffer-url (quri:uri "https://en.wikipedia.org/wiki/Special:Random"))))

;;; Search engines — Google default, w: Wikipedia, dd: DuckDuckGo
(define-configuration browser
  ((search-engines
    (list
     (make-instance 'search-engine
                    :name "Google"
                    :shortcut "g"
                    :control-url "https://www.google.com/search?q=~a")
     (make-instance 'wikipedia-search-engine :shortcut "w")
     (make-instance 'ddg-search-engine :shortcut "dd")))))

;;; Privacy
(define-configuration browser
  ((default-cookie-policy :no-third-party)))

;;; Close the blank window that finalize-startup creates unconditionally
(define-configuration browser
  ((after-startup-hook
    (hooks:add-hook %slot-value%
      (make-instance 'hooks:handler
                     :fn (lambda (browser)
                           (declare (ignore browser))
                           (dolist (w (window-list))
                             (when (string= "" (title (active-buffer w)))
                               (ffi-window-delete w))))
                     :name 'close-blank-startup-window)))))

;;; Downloads — straight to ~/Downloads
(define-configuration browser
  ((download-path (make-instance 'download-directory
                                 :dirname (uiop:xdg-download-dir)))))
