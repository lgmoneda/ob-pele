;;; ob-pele.el --- Render Pele diagrams with Org Babel -*- lexical-binding: t; -*-

;; Author: Luis Moneda (https://github.com/lgmoneda)
;; Maintainer: Luis Moneda (https://github.com/lgmoneda)
;; URL: https://github.com/lgmoneda/ob-pele
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org "9.4"))
;; Keywords: literate programming, multimedia
;; SPDX-License-Identifier: MIT

;;; Commentary:
;; Execute pele source blocks using Node.js and the adjacent renderer.mjs.
;; Run `npm ci' in this package directory before using the backend.
;; A :file argument ending in .svg is required.  See README.org.

;;; Code:
(require 'ob)
(require 'json)
(require 'subr-x)

(defgroup ob-pele nil
  "Render diagrams using Pele."
  :group 'org-babel)

(defcustom ob-pele-node-command "node"
  "Node.js executable (version 20 or later)."
  :type 'string
  :group 'ob-pele)

(defcustom ob-pele-renderer
  (expand-file-name "renderer.mjs"
                    (file-name-directory (or load-file-name buffer-file-name)))
  "Absolute path to the Pele renderer script."
  :type 'file
  :group 'ob-pele)

(defvar org-babel-default-header-args:pele
  '((:results . "file graphics") (:exports . "results"))
  "Default header arguments for Pele blocks.")

(defun ob-pele--options (params)
  "Convert supported header arguments in PARAMS into renderer options."
  (let (options)
    (dolist (entry '((:font-size . fontSize) (:max-width . maxWidth)
                     (:padding . padding)))
      (when-let* ((value (cdr (assq (car entry) params))))
        (unless (and (string-match-p "\\`[0-9]+\\(?:\\.[0-9]+\\)?\\'" (format "%s" value))
                     (if (eq (car entry) :padding)
                         (>= (string-to-number (format "%s" value)) 0)
                       (> (string-to-number (format "%s" value)) 0)))
          (user-error "Pele: invalid %s: %s" (car entry) value))
        (push (cons (cdr entry) (string-to-number (format "%s" value))) options)))
    (when-let* ((font (cdr (assq :font-family params))))
      (push (cons 'fontFamily (format "%s" font)) options))
    (if options (json-encode options) "{}")))

;;;###autoload
(defun org-babel-execute:pele (body params)
  "Render Pele BODY using PARAMS to the required :file SVG path."
  (let* ((file (cdr (assq :file params)))
         (session (cdr (assq :session params)))
         (options (ob-pele--options params)))
    (unless (and (stringp file) (not (string-empty-p file)))
      (user-error "Pele requires a :file output.svg header"))
    (unless (equal (downcase (or (file-name-extension file) "")) "svg")
      (user-error "Pele currently supports only .svg output"))
    (when (or (file-remote-p default-directory) (file-remote-p file))
      (user-error "Pele currently supports local files only"))
    (when (and session (not (equal session "none")))
      (user-error "Pele does not support sessions"))
    (when (assq :var params)
      (user-error "Pele does not support :var; use Org noweb references"))
    (unless (executable-find ob-pele-node-command)
      (user-error "Pele: Node.js not found; customize ob-pele-node-command"))
    (unless (file-readable-p ob-pele-renderer)
      (user-error "Pele renderer not found: %s" ob-pele-renderer))
    (let ((output (generate-new-buffer " *ob-pele output*"))
          (stderr (make-temp-file "ob-pele-error-"))
          (coding-system-for-read 'utf-8-unix)
          (coding-system-for-write 'utf-8-unix))
      (unwind-protect
          (with-temp-buffer
            (insert body)
            (let ((status (call-process-region
                           (point-min) (point-max) ob-pele-node-command
                           nil (list output stderr) nil ob-pele-renderer options)))
              (unless (equal status 0)
                (error "%s" (with-temp-buffer
                              (insert-file-contents stderr)
                              (string-trim (buffer-string)))))
              ;; Only touch the destination after successful rendering.
              (with-current-buffer output
                (unless (string-prefix-p "<svg" (buffer-string))
                  (error "Pele renderer returned no SVG"))
                (write-region (point-min) (point-max) (expand-file-name file) nil 'silent))))
        (kill-buffer output)
        (delete-file stderr))))
  ;; Org inserts the :file result link when the backend returns nil.
  nil)

(provide 'ob-pele)
;;; ob-pele.el ends here
