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
                  )))
  "Mode specific mapping.
Each mode has `:compile`,  `:run` and
`:extension` target, each target requires a string or (function
file).  Note: avilable format symbols are %p for full path, %F
for `file-name-sans-extension`, %f for file-name-no-directory." )

(defvar pg-mode-buffer-name  "*code-playground*")
(defvar pg-mode-parent-mode nil)
(defvar pg-temp-dir nil
  "Define temp file location, if `nil` use system defaults.")

(defun pg-get-ext (&optional mode)
  "Get extension by MODE."
  (let ((settings (cdr (assoc (or mode pg-mode-parent-mode) pg-code-setting))))
    (plist-get settings :extension)))

(defun pg-temp-file (mode)
  "Get temp file name by MODE."
  (let* ((dir (or pg-temp-dir temporary-file-directory))
         (ext (pg-get-ext mode))
         (tmp-file
             (concat dir (make-temp-name "pg") ext)))
    tmp-file))


(defun pg-start-coding (mode)
  "Start coding with MODE."
  (interactive (list (completing-read "select major mode "
                                      pg-code-setting)))
  (eval `(pg-mode-setup ,(intern mode)))
  (message "mode is %s" mode)
  (let ((file (pg-temp-file (intern mode))))
    (find-file file)
    (pg-mode)))


(defmacro pg-mode-setup (mode)
  "Setup MODE that derivde from know major mode."
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
  "Format CMD-STR."
  (let ((full-file-name (buffer-file-name))
        (file-name (file-name-nondirectory (buffer-file-name))))
    (if (stringp cmd-str)
        (with-temp-buffer
          (insert cmd-str)      
          (while (search-backward-regexp "%[fFp]" (point-min) t)
             (let ((match (match-string-no-properties 0)))
              (cond
               ((string= "%F" match)
                (replace-match
                 (file-name-sans-extension file-name) t))
               ((string= "%f" match)
                (replace-match  file-name))
               ((string= "%p" match)
                (replace-match
                 (file-name-directory full-file-name)))
               )
              )
            )
          (buffer-string))
      (funcall cmd-str file-name))))

(defun pg-compile (&optional need-run)
  "Compile file, if NEED-RUN run it withou compile."
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
  "Recompile file."
  (interactive)
  (recompile))

(defun pg-run ()
  "Run."
  (interactive)
  (pg-compile t))


(provide 'playground)

;;; playground.el ends here
