(in-package :nyxt-user)

;;; Vim keybindings globally
(define-configuration buffer
  ((default-modes (append '(vi-normal-mode) %slot-value%))))

;;; One window per page
(define-configuration browser
  ((open-external-link-in-new-window-p t)))

;;; Start page
(define-configuration browser
  ((default-new-buffer-url (quri:uri "https://en.wikipedia.org/wiki/Special:Random"))))

;;; Search engines — Google default, w: Wikipedia, dd: DuckDuckGo
(define-configuration browser
  ((search-engines
    (list
     (make-instance 'search-engine
                    :shortcut "g"
                    :search-url "https://www.google.com/search?q=~a"
                    :fallback-url (quri:uri "https://www.google.com"))
     (make-instance 'search-engine
                    :shortcut "w"
                    :search-url "https://en.wikipedia.org/wiki/Special:Search?search=~a"
                    :fallback-url (quri:uri "https://en.wikipedia.org"))
     (make-instance 'search-engine
                    :shortcut "dd"
                    :search-url "https://duckduckgo.com/?q=~a"
                    :fallback-url (quri:uri "https://duckduckgo.com"))))))

;;; Privacy
(define-configuration browser
  ((default-cookie-policy :no-third-party)))

;;; Downloads — no prompt, straight to ~/Downloads
(define-configuration browser
  ((download-path (make-instance 'download-directory
                                 :dirname (uiop:xdg-download-dir)))))
