;;; ob-pele-test.el --- Tests -*- lexical-binding: t; -*-
(require 'ert)
(require 'ob-pele)

(defmacro ob-pele-test--directory (&rest body)
  `(let ((default-directory (file-name-as-directory (make-temp-file "pele test " t))))
     (unwind-protect (progn ,@body) (delete-directory default-directory t))))

(ert-deftest ob-pele-org-execution ()
  (ob-pele-test--directory
   (with-temp-buffer
     (org-mode)
     (insert "#+begin_src pele :file \"diagram ü.svg\"\nflowchart LR\n A[Idea] --> B[Draft]\n#+end_src\n")
     (goto-char (point-min))
     (let ((org-confirm-babel-evaluate nil)) (org-babel-execute-src-block))
     (should (file-exists-p "diagram ü.svg"))
     (should (string-match-p "#\\+RESULTS:" (buffer-string)))
     (should (string-match-p "\\[\\[file:diagram ü.svg\\]\\]" (buffer-string))))))

(ert-deftest ob-pele-failure-preserves-file ()
  (ob-pele-test--directory
   (with-temp-file "existing.svg" (insert "keep me"))
   (should-error (org-babel-execute:pele "not a diagram" '((:file . "existing.svg"))))
   (should (equal "keep me" (with-temp-buffer (insert-file-contents "existing.svg") (buffer-string))))))

(ert-deftest ob-pele-header-validation ()
  (dolist (params '(nil ((:file . "x.png")) ((:file . "x.svg") (:font-size . "oops"))
                   ((:file . "x.svg") (:session . "x"))))
    (should-error (org-babel-execute:pele "flowchart LR\n A --> B" params) :type 'user-error)))

(ert-deftest ob-pele-svg-options ()
  (ob-pele-test--directory
   (org-babel-execute:pele "flowchart LR\n A[Olá] --> B[世界]"
                           '((:file . "x.svg") (:font-size . 20) (:padding . 0)))
   (with-temp-buffer
     (insert-file-contents "x.svg")
     (should (search-forward "Olá" nil t))
     (goto-char (point-min))
     (should-not (search-forward "var(--" nil t))
     (goto-char (point-min))
     (should (search-forward "20px" nil t)))))
