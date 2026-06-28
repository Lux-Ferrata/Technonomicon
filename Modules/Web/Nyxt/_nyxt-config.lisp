(in-package :nyxt-user)

(define-configuration web-buffer
  ((default-modes (append '(vi-normal-mode nyxt/mode/style:dark-mode) %slot-value%))))

(define-configuration browser
  ((theme theme:+dark-theme+)
   (default-new-buffer-url (quri:uri "https://en.wikipedia.org/wiki/Special:Random"))
   (default-cookie-policy :no-third-party)
   (search-engines
    (list
     (make-instance 'search-engine
                    :name "Google"
                    :shortcut "g"
                    :control-url "https://www.google.com/search?q=~a")
     (make-instance 'wikipedia-search-engine :shortcut "w")
     (make-instance 'ddg-search-engine :shortcut "dd")))))
