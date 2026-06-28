(in-package :nyxt-user)

;;; Vim keybindings globally
(define-configuration buffer
  ((default-modes (pushnew 'vi-normal-mode %slot-value%))))

;;; One window per page
(define-configuration browser
  ((open-external-link-in-new-window-p t)))

;;; Start page
(define-configuration browser
  ((default-new-buffer-url (quri:uri "https://en.wikipedia.org/wiki/Special:Random"))))

;;; Search engines — Google default, w: Wikipedia, dd: DuckDuckGo
(define-configuration context-buffer
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

;;; Dark mode + ad blocking
(define-configuration web-buffer
  ((default-modes (pushnew 'nyxt/mode/blocker:blocker-mode %slot-value%))
   (default-modes (pushnew 'nyxt/mode/force-https:force-https-mode %slot-value%))))

;;; Privacy
(define-configuration web-buffer
  ((cookies-policy :no-third-party)
   (allow-geolocation-p nil)))

;;; Downloads — no prompt, straight to ~/Downloads
(define-configuration browser
  ((downloads-path (make-instance 'downloads-data-path
                                  :dirname (uiop:xdg-download-dir)))))

;;; Session restore
(define-configuration browser
  ((restore-session-on-startup-p t)))

;;; Bitwarden — ;b fills credentials via bw CLI
(define-command-global bitwarden-fill ()
  "Fill credentials using Bitwarden CLI via bemenu."
  (let* ((url (render-url (url (current-buffer))))
         (items (uiop:run-program
                 (list "bw" "list" "items" "--url" url "--session"
                       (uiop:getenv "BW_SESSION"))
                 :output '(:string :stripped t)))
         (chosen (uiop:run-program
                  (list "bemenu" "-i" "-p" "Bitwarden")
                  :input items
                  :output '(:string :stripped t))))
    (declare (ignore chosen))
    (echo "Bitwarden: not yet implemented — use bw CLI directly")))

(define-configuration vi-normal-mode
  ((keymap-scheme
    (let ((map (make-keymap "vi-normal-user-map")))
      (define-key map ";b" 'bitwarden-fill)
      map))))
