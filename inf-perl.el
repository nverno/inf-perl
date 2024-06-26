;;; inf-perl.el --- Run a Perl repl in an inferior process -*- lexical-binding: t; -*-
;;
;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/inf-perl
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;; Created: 26 June 2024
;; Keywords: perl, languages
;;
;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;
;;; Commentary:
;;
;; Inf-perl provides a REPL buffer for interacting with a Perl process.
;;
;;; Code:

(require 'comint)

(defgroup inf-perl nil
  "Inferior perl."
  :group 'languages
  :prefix "inf-perl-")

(defcustom inf-perl-command "reply"
  "Command to run inferior Perl process."
  :type 'string)

(defcustom inf-perl-arguments '()
  "Arguments passed to `inf-perl-command'."
  :type '(repeat string))

(defcustom inf-perl-prompt "^[0-9]+> *"
  "Top-level prompt used by the inferior Perl process."
  :type 'string
  :safe 'stringp)

(defcustom inf-perl-startfile nil
  "File to pass to the inferior Perl process as initial input."
  :type '(choice (const :tag "None" nil) file))

(defcustom inf-perl-history-filename nil
  "File used to save command history of the inferior Perl process."
  :type '(choice (const :tag "None" nil) file))

(defcustom inf-perl-process-name "Perl"
  "Name of inferior Perl process."
  :type 'string)


(defvar inf-perl-font-lock-keywords '()
  "Extra font-lock keywords for `inf-perl-mode'.")

(defun inf-perl-buffer ()
  "Return inferior Perl buffer."
  (if (derived-mode-p 'inf-perl-mode)
      (current-buffer)
    (let* ((proc-name inf-perl-process-name)
           (buffer-name (format "*%s*" proc-name)))
      (when (comint-check-proc buffer-name)
        buffer-name))))

(defun inf-perl-process ()
  "Return inferior Perl process."
  (get-buffer-process (inf-perl-buffer)))

;;;###autoload
(defun inf-perl-run (&optional prompt cmd startfile show)
  "Run a Perl interpreter in an inferior process.
With prefix, PROMPT, read command.
If CMD is non-nil, use it to start repl.
STARTFILE overrides `inf-perl-startfile' when present.
When called interactively, or with SHOW, show the repl buffer after starting."
  (interactive (list current-prefix-arg nil nil t))
  (let* ((cmd (inf-perl--calculate-command
               "Run Perl: " inf-perl-command inf-perl-arguments prompt cmd))
         (startfile (or startfile inf-perl-startfile))
         (buffer (inf-perl--make-comint
                  cmd inf-perl-process-name inf-perl-history-filename startfile)))
    (with-current-buffer buffer
      (unless (derived-mode-p 'inf-perl-mode)
        (inf-perl-mode)))
    (when show
      (pop-to-buffer buffer))
    (get-buffer-process buffer)))

(defun inf-perl--calculate-command
    (prompt-msg default-command default-args &optional force-prompt program)
  "Return command to start Perl process.
If PROGRAM is non-nil, use it to start process.
Prompt with PROMPT-MSG with default DEFAULT-COMMAND and DEFAULT-ARGS.
If FORCE-PROMPT, read command interactively."
  (let* ((program (or program (if (functionp default-command)
                                  (funcall default-command)
                                default-command)))
         (cmdline (concat program " " (mapconcat 'identity default-args " "))))
    (if force-prompt (read-shell-command prompt-msg cmdline) cmdline)))

(defun inf-perl--write-history (process _)
  "Write history file for inferior Perl PROCESS."
  (let ((buffer (process-buffer process)))
    (when (and buffer (buffer-live-p buffer))
      (with-current-buffer buffer (comint-write-input-ring)))))

(defun inf-perl--make-comint (cmd proc-name &optional history-file start-file)
  "Create a Perl comint buffer.
CMD is the command to be executed and PROC-NAME is the process name that will be
given to the comint buffer.
If STARTFILE is non-nil, use that instead of `inf-perl-startfile'
which is used by default. See `make-comint' for details of STARTFILE.
If SHOW is non-nil, display the Typescript comint buffer after it is created.
Returns the name of the created comint buffer."
  (let ((proc-buff-name (format "*%s*" proc-name)))
    (unless (comint-check-proc proc-buff-name)
      (let* ((cmdlist (split-string-and-unquote cmd))
             (program (car cmdlist))
             (args (cdr cmdlist))
             (buffer (apply #'make-comint-in-buffer
                            proc-name proc-buff-name
                            program start-file args)))
        (when history-file
          (set-process-sentinel
           (get-buffer-process buffer) #'inf-perl--write-history))))
    proc-buff-name))

;;;###autoload
(define-derived-mode inf-perl-mode comint-mode "Perl"
  "Major mode for Perl repl."
  (setq mode-line-process '(":%s"))
  (setq-local comment-start "#"
              comment-end ""
              comment-start-skip "#+ *")
  (setq-local comint-prompt-regexp inf-perl-prompt)
  (setq-local comint-prompt-read-only t)
  (setq-local comint-use-prompt-regexp nil)
  (setq-local comint-highlight-input nil)
  (setq-local comint-input-ignoredups t)
  (setq-local comint-indirect-setup-function #'perl-mode)
  (setq-local font-lock-defaults '(inf-perl-font-lock-keywords nil nil nil))
  (comint-fontify-input-mode))

(provide 'inf-perl)
;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:
;;; inf-perl.el ends here
