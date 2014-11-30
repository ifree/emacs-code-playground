;;; playground.el --- a playground to write random code

;;; Commentary:
;;- generate a new buffer
;;- compile and execute user inputs

;;; Code:

(defvar pg-code-setting
  '(
    (c++-mode . (:compile
                 "clang++ -Wall -g %f -o %F"
                 :run
                 "%p/%F"
                 :extension
                 ".cpp"
                 ))
    (c-mode . (:compile
               (lambda (f) (format "%s -Wall -g %s -o %s"
                                   (or (getenv "CC") "gcc")
                                   f
                                   (file-name-sans-extension f)))
               :run
               "%p/%F"
               :extension
               ".c"
               ))
    (java-mode . (:compile
                  "javac %f"
                  :run
                  "cd %p;java %F"
                  :extension
                  ".java"
                  ))))

(defvar pg-mode-buffer-name  "*code-playground*")
(defvar pg-mode-parent-mode nil)
(defvar pg-temp-dir nil
  "define temp file location, if `nil` use system defaults.")

(defun pg-get-ext (&optional mode)
  (let ((settings (cdr (assoc (or mode pg-mode-parent-mode) pg-code-setting))))
    (plist-get settings :extension)))

(defun pg-temp-file (mode)
  (if pg-temp-dir
      (let* ((ext (pg-get-ext mode))
            (tmp-file
             (concat pg-temp-dir (make-temp-name "pg") ext)))
        (shell-command (concat "echo >" tmp-file))
        tmp-file)
    (make-temp-file "pg" nil (pg-get-ext mode))))

(defun pg-start-coding (mode)
  (interactive (list (completing-read "select major mode "
                                      pg-code-setting)))
  (eval `(pg-mode-setup ,(intern mode)))
  (message "mode is %s" mode)
  (let ((file (pg-temp-file (intern mode))))
    (find-file file)
    (pg-mode)))


(defmacro pg-mode-setup (mode)
  `(define-derived-mode pg-mode ,mode pg-mode-buffer-name
     (setq pg-mode-parent-mode (quote ,mode))
     
     (define-key pg-mode-map ,(kbd "<f5>") 'pg-compile)
     (define-key pg-mode-map ,(kbd "<f6>") 'pg-recompile)
     (define-key pg-mode-map ,(kbd "<f8>") 'pg-run)
     
     (run-with-idle-timer 0.01 nil (lambda (m) (message "%s" m))
                          (substitute-command-keys
                           (concat "Type <\\[pg-compile]> to compile "
                                   "<\\[pg-recompile]> to recompile "
                                   "<\\[pg-run]> to run.")))))


(defun pg-format (cmd-str)
  (let ((full-file-name (buffer-file-name))
        (file-name (file-name-nondirectory (buffer-file-name))))
    (if (stringp cmd-str)
        (with-temp-buffer
          (insert cmd-str)      
          (while (search-backward-regexp "%[fFp]" (point-min) t)
             (let ((match (match-string-no-properties 0)))
              (cond
               ((string= "%F" (match-string-no-properties 0))
                (replace-match
                 (file-name-sans-extension file-name) t))
               ((string= "%f" (match-string-no-properties 0))
                (replace-match  file-name))
               ((string= "%p" (match-string-no-properties 0))
                (replace-match
                 (file-name-directory full-file-name)))
               )
              )
            )
          (buffer-string))
      (funcall cmd-str file-name))))

(defun pg-compile (&optional need-run)
  (interactive)
  (let* ((settings (cdr (assoc pg-mode-parent-mode pg-code-setting)))
         (cmd-compile (plist-get settings :compile))
         (cmd-run (plist-get settings :run))
         )
    (if need-run
        (when  cmd-run
          (message (shell-command-to-string (pg-format cmd-run))))
      (when cmd-compile
        (setq compile-command (pg-format cmd-compile))
        (call-interactively 'compile)))))

(defun pg-recompile ()
  (interactive)
  (recompile))

(defun pg-run ()
  (interactive)
  (pg-compile t))


(provide 'playground)

;;; playground.el ends here
