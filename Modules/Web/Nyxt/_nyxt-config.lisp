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
                    :name "Google"
                    :shortcut "g"
                    :control-url "https://www.google.com/search?q=~a")
     (make-instance 'wikipedia-search-engine :shortcut "w")
     (make-instance 'ddg-search-engine :shortcut "dd")))))

;;; Privacy
(define-configuration browser
  ((default-cookie-policy :no-third-party)))

;;; Downloads — straight to ~/Downloads
(define-configuration browser
  ((download-path (make-instance 'download-directory
                                 :dirname (uiop:xdg-download-dir)))))
