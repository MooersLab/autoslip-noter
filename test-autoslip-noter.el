;;; test-autoslip-noter.el --- Tests for autoslip-noter -*- lexical-binding: t; -*-

;;; Commentary:

;; Integration tests for autoslip-noter.el using ERT and a real org-roam
;; database in a temporary directory.  org-noter itself is replaced by a
;; stub, because a session needs a displayed document.
;;
;; Run with:
;;   emacs -Q --batch -L . -l ert -l test-autoslip-noter.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'org-roam)
(require 'autoslip-roam)
(require 'autoslip-noter)
(require 'org-noter)

(defvar test-autoslip-noter--calls nil
  "Records of the stubbed `org-noter' calls.")

(defmacro test-autoslip-noter--with-vault (&rest body)
  "Run BODY in a temporary org-roam vault that holds the root note 1."
  (declare (indent 0))
  `(let* ((dir (file-name-as-directory (make-temp-file "autoslip-noter-" t)))
          (org-roam-directory dir)
          (org-roam-db-location (expand-file-name "org-roam.db" dir))
          (org-roam-capture-templates
           '(("n" "normal" plain "%?"
              :if-new (file+head "${slug}.org" "#+title: ${title}\n")
              :unnarrowed t)
             ("l" "literature" plain "%?"
              :if-new (file+head "lit-${slug}.org" "#+title: ${title}\n")
              :unnarrowed t)))
          (org-roam-capture-new-node-hook nil)
          (org-id-locations-file (expand-file-name ".org-id-locations" dir))
          (autoslip-roam-sync-db-before-queries t)
          (test-autoslip-noter--calls nil)
          (pdf (expand-file-name "Smith2020Paper.pdf" dir)))
     (unwind-protect
         (progn
           (with-temp-file (expand-file-name "1-crystallography.org" dir)
             (insert ":PROPERTIES:\n:ID:       root-1\n:END:\n"
                     "#+title: 1. Crystallography\n"))
           (with-temp-file pdf (insert "%PDF-1.4\n"))
           (add-hook 'org-roam-capture-new-node-hook
                     #'autoslip-roam--process-new-node)
           (org-roam-db-sync)
           (cl-letf (((symbol-function 'org-noter)
                      (lambda (&rest _)
                        (push (list (buffer-file-name)
                                    (point)
                                    (org-entry-get nil "NOTER_DOCUMENT"))
                              test-autoslip-noter--calls))))
             ,@body))
       (dolist (buf (buffer-list))
         (when (and (buffer-file-name buf)
                    (string-prefix-p dir (buffer-file-name buf)))
           (with-current-buffer buf (set-buffer-modified-p nil))
           (kill-buffer buf)))
       (org-roam-db--close)
       (delete-directory dir t))))

(defmacro test-autoslip-noter--with-answers (parent address title &rest body)
  "Run BODY with the prompts answered by PARENT, ADDRESS, and TITLE.
A nil TITLE accepts the proposed title."
  (declare (indent 3))
  `(cl-letf (((symbol-function 'org-roam-node-read)
              (lambda (&rest _)
                (autoslip-roam--index-exists-p ,parent)))
             ((symbol-function 'completing-read)
              (lambda (_prompt collection &rest _)
                (or ,address (car collection))))
             ((symbol-function 'read-string)
              (lambda (_prompt &optional initial &rest _)
                (or ,title initial))))
     ,@body))

(ert-deftest test-autoslip-noter-creates-linked-note ()
  "A new document gets a child note that is linked to its parent."
  (test-autoslip-noter--with-vault
    (test-autoslip-noter--with-answers "1." nil nil
      (should (autoslip-noter-create-session nil pdf)))
    (org-roam-db-sync)
    (let ((child (autoslip-roam--index-exists-p "1.1")))
      (should child)
      (should (equal (org-roam-node-title child) "1.1 Smith2020Paper"))
      ;; The stub was called once in the child note with the property set.
      (should (= (length test-autoslip-noter--calls) 1))
      (let ((call (car test-autoslip-noter--calls)))
        (should (file-equal-p (nth 0 call) (org-roam-node-file child)))
        (should (= (nth 1 call) 1))
        (should (equal (nth 2 call) pdf)))
      ;; The child keeps its ID and links back to the parent.
      (with-temp-buffer
        (insert-file-contents (org-roam-node-file child))
        (should (string-match-p ":NOTER_DOCUMENT:" (buffer-string)))
        (should (string-match-p ":ID:" (buffer-string)))
        (should (string-match-p "\\[\\[id:root-1\\]" (buffer-string))))
      ;; The parent links forward to the child.
      (with-temp-buffer
        (insert-file-contents (expand-file-name "1-crystallography.org" dir))
        (should (string-match-p (regexp-quote (org-roam-node-id child))
                                (buffer-string)))))))

(ert-deftest test-autoslip-noter-reuses-existing-note ()
  "A second session for the same document reuses the note."
  (test-autoslip-noter--with-vault
    (test-autoslip-noter--with-answers "1." nil nil
      (autoslip-noter-create-session nil pdf))
    (let ((file (car (car test-autoslip-noter--calls))))
      (cl-letf (((symbol-function 'org-roam-node-read)
                 (lambda (&rest _) (error "Should not prompt"))))
        (should (autoslip-noter-create-session nil pdf)))
      (should (= (length test-autoslip-noter--calls) 2))
      (should (file-equal-p (car (car test-autoslip-noter--calls)) file))
      (should (file-equal-p (autoslip-noter-find-notes-file pdf) file))
      (org-roam-db-sync)
      (should-not (autoslip-roam--index-exists-p "1.2")))))

(ert-deftest test-autoslip-noter-other-document-gets-next-address ()
  "A different document gets the next free child address."
  (test-autoslip-noter--with-vault
    (test-autoslip-noter--with-answers "1." nil nil
      (autoslip-noter-create-session nil pdf))
    (let ((pdf2 (expand-file-name "Jones2021Other.pdf" dir)))
      (should-not (autoslip-noter-find-notes-file pdf2))
      (test-autoslip-noter--with-answers "1." nil "Jones on phasing"
        (autoslip-noter-create-session nil pdf2))
      (org-roam-db-sync)
      (let ((child (autoslip-roam--index-exists-p "1.2")))
        (should child)
        (should (equal (org-roam-node-title child) "1.2 Jones on phasing"))))))

(ert-deftest test-autoslip-noter-template-key ()
  "The capture template named by `autoslip-noter-template-key' is used."
  (test-autoslip-noter--with-vault
    (let ((autoslip-noter-template-key "l"))
      (test-autoslip-noter--with-answers "1." nil nil
        (autoslip-noter-create-session nil pdf))
      (should (string-prefix-p
               "lit-"
               (file-name-nondirectory
                (car (car test-autoslip-noter--calls))))))
    (let ((autoslip-noter-template-key "zz"))
      (should-error (autoslip-noter--templates) :type 'user-error))))

(ert-deftest test-autoslip-noter-ignores-user-templates-by-default ()
  "A broken first template in the user's list does not affect the bridge."
  (test-autoslip-noter--with-vault
    (let ((org-roam-capture-templates
           '(("l" "citar template" plain "%?"
              :if-new (file+head "lit/${citekey}.org" "#+title: ${title}\n")
              :if-new (file+head "${citekey}.org" "#+title: ${title}\n")
              :unnarrowed t))))
      (test-autoslip-noter--with-answers "1." nil "A title with spaces"
        (should (autoslip-noter-create-session nil pdf)))
      (org-roam-db-sync)
      (should (equal (org-roam-node-title (autoslip-roam--index-exists-p "1.1"))
                     "1.1 A title with spaces")))))

(ert-deftest test-autoslip-noter-broken-template-reports-user-error ()
  "A template that cannot be used gives a readable error and no stale state."
  (test-autoslip-noter--with-vault
    (let ((autoslip-noter-capture-template
           '("x" "broken" plain "%?" :unnarrowed t)))
      (test-autoslip-noter--with-answers "1." nil nil
        (should-error (autoslip-noter-create-session nil pdf)
                      :type 'user-error))
      (should-not autoslip-roam--pending-parent-node)
      (should-not test-autoslip-noter--calls))))

(ert-deftest test-autoslip-noter-duplicate-address-is-refused ()
  "An address that is in use signals a `user-error'."
  (test-autoslip-noter--with-vault
    (test-autoslip-noter--with-answers "1." nil nil
      (autoslip-noter-create-session nil pdf))
    (org-roam-db-sync)
    (let ((pdf2 (expand-file-name "Jones2021Other.pdf" dir)))
      (test-autoslip-noter--with-answers "1." "1.1" nil
        (should-error (autoslip-noter-create-session nil pdf2)
                      :type 'user-error)))))

(ert-deftest test-autoslip-noter-mode-toggles-hook ()
  "The minor mode adds and removes the org-noter hook function."
  (let ((org-noter-create-session-from-document-hook
         (list 'org-noter--create-session-from-document-file-default)))
    (autoslip-noter-mode 1)
    (should (eq (car org-noter-create-session-from-document-hook)
                #'autoslip-noter-create-session))
    (autoslip-noter-mode -1)
    (should-not (memq #'autoslip-noter-create-session
                      org-noter-create-session-from-document-hook))))

(provide 'test-autoslip-noter)

;;; test-autoslip-noter.el ends here
