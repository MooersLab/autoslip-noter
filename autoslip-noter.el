;;; autoslip-noter.el --- Bridge between autoslip-roam and org-noter -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: Blaine Mooers
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org-roam "2.0") (org-noter "1.5.0") (autoslip-roam "3.0.0"))
;; Keywords: org-mode, org-roam, zettelkasten, folgezettel, pdf
;; URL: https://github.com/MooersLab/autoslip-noter

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; This package connects org-noter to a folgezettel zettelkasten that is
;; managed with autoslip-roam.  It makes one folgezettel note per document
;; (a literature note) and uses that note as the org-noter notes file.
;;
;; With `autoslip-noter-mode' enabled, running M-x org-noter in a PDF
;; buffer does the following:
;;
;; 1. It looks in the org-roam database for a note whose NOTER_DOCUMENT
;;    property points to the PDF.  If one exists, the session starts there.
;; 2. Otherwise it asks for a parent note, suggests the next free child
;;    address, asks for a title, and creates the child note with
;;    `autoslip-roam-create-child'.  autoslip-roam adds the links between
;;    the parent and the child.
;; 3. It writes NOTER_DOCUMENT into the property drawer at the top of the
;;    new note and starts the org-noter session.
;;
;; The page notes that you take during the session are headings in the
;; literature note.  Starting org-noter from the note itself works as it
;; always does, because the note carries the NOTER_DOCUMENT property.
;;
;; The bridge uses only the public hooks of org-noter.  It does not change
;; org-noter or org-roam.
;;
;; Installation:
;;
;;   (require 'autoslip-noter)
;;   (autoslip-noter-mode 1)

;;; Code:

(require 'cl-lib)
(require 'org)
(require 'org-roam)
(require 'autoslip-roam)

(defvar org-noter-create-session-from-document-hook)
(defvar org-noter-property-doc-file)
(declare-function org-noter "org-noter")

(defgroup autoslip-noter nil
  "Bridge between autoslip-roam and org-noter."
  :group 'autoslip-roam
  :prefix "autoslip-noter-")

(defcustom autoslip-noter-capture-template
  '("n" "autoslip-noter literature note" plain "%?"
    :target (file+head "%<%Y%m%d%H%M%S>-${slug}.org"
                       "#+title: ${title}\n#+filetags: :literature:\n")
    :unnarrowed t)
  "The org-roam capture template used for new literature notes.
The bridge carries its own template so that it does not depend on the
templates in `org-roam-capture-templates', which are often written for
other tools and may need values that the bridge cannot supply, such as
a citekey.  The template must create a new file, and it may only use
the ${title} and ${slug} placeholders.  Put a directory in front of the
file name to file the notes in a subdirectory of `org-roam-directory',
for example \"literature/%<%Y%m%d%H%M%S>-${slug}.org\".

This template is ignored when `autoslip-noter-template-key' is non-nil."
  :type '(repeat sexp)
  :group 'autoslip-noter)

(defcustom autoslip-noter-template-key nil
  "Key of a template in `org-roam-capture-templates' to use instead.
When nil, `autoslip-noter-capture-template' is used.  When a string
such as \"m\", the template with that key is used.  That template must
create a new file and must not need placeholders other than ${title}
and ${slug}."
  :type '(choice (const :tag "Use autoslip-noter-capture-template" nil)
                 (string :tag "Template key"))
  :group 'autoslip-noter)

(defcustom autoslip-noter-default-title-function #'file-name-base
  "Function that proposes a title for the note of a document.
It is called with the path of the document and must return a string.
The default returns the file name without its extension, which is the
citekey when the PDF files are named by citekey."
  :type 'function
  :group 'autoslip-noter)

(defcustom autoslip-noter-confirm-address t
  "When non-nil, ask the user to confirm or change the child address.
When nil, the first suggested address is used without a prompt."
  :type 'boolean
  :group 'autoslip-noter)

(defun autoslip-noter--doc-property ()
  "Return the name of the org-noter document property."
  (if (boundp 'org-noter-property-doc-file)
      org-noter-property-doc-file
    "NOTER_DOCUMENT"))

(defun autoslip-noter--same-file-p (a b)
  "Return non-nil when the paths A and B name the same file."
  (and (stringp a) (stringp b)
       (string= (expand-file-name a) (expand-file-name b))))

(defun autoslip-noter--nodes-for-document (doc-path)
  "Return (FILE . TITLE) pairs for the notes that annotate DOC-PATH.
The org-roam database is searched for nodes whose document property
matches DOC-PATH.  Notes with a folgezettel address are listed first."
  (let* ((prop (autoslip-noter--doc-property))
         (rows (org-roam-db-query
                [:select [file title properties] :from nodes
                 :where (like properties $r1)]
                (concat "%" prop "%")))
         with-fz without-fz)
    (dolist (row rows)
      (let ((file (nth 0 row))
            (title (nth 1 row))
            (value (cdr (assoc prop (nth 2 row)))))
        (when (autoslip-noter--same-file-p value doc-path)
          (if (autoslip-roam--extract-from-title title)
              (push (cons file title) with-fz)
            (push (cons file title) without-fz)))))
    (append (nreverse with-fz) (nreverse without-fz))))

;;;###autoload
(defun autoslip-noter-find-notes-file (doc-path)
  "Return the file of the note that annotates DOC-PATH, or nil."
  (car (car (autoslip-noter--nodes-for-document doc-path))))

(defun autoslip-noter--folgezettel-node-p (node)
  "Return non-nil when NODE has a folgezettel address in its title."
  (autoslip-roam--extract-from-title (org-roam-node-title node)))

(defun autoslip-noter--templates ()
  "Return the capture templates for a new literature note."
  (if autoslip-noter-template-key
      (let ((template (assoc autoslip-noter-template-key
                             org-roam-capture-templates)))
        (unless template
          (user-error "No org-roam capture template with key \"%s\""
                      autoslip-noter-template-key))
        (list template))
    (list autoslip-noter-capture-template)))

(defun autoslip-noter--read-address (parent-fz)
  "Read a child address for the parent address PARENT-FZ."
  (let ((suggestions (autoslip-roam-suggest-next-child parent-fz)))
    (unless suggestions
      (user-error "Could not suggest a child address for '%s'" parent-fz))
    (if autoslip-noter-confirm-address
        (completing-read
         (format "Address of the new note (parent: %s): " parent-fz)
         suggestions nil nil nil nil (car suggestions))
      (car suggestions))))

(defun autoslip-noter--create-note (doc-path)
  "Create a folgezettel note for DOC-PATH and return its file.
Ask for the parent note, the child address, and the title."
  (autoslip-roam--maybe-sync-db)
  (let* ((parent (org-roam-node-read
                  nil #'autoslip-noter--folgezettel-node-p nil t
                  "Parent note for this document: "))
         (parent-fz (autoslip-roam--extract-from-title
                     (org-roam-node-title parent)))
         (address (autoslip-noter--read-address parent-fz))
         (default-title (funcall autoslip-noter-default-title-function
                                 doc-path))
         (title (read-string (format "Title for %s: " address)
                             default-title))
         (templates (autoslip-noter--templates))
         (node (condition-case err
                   (autoslip-roam-create-child parent title address t
                                               templates)
                 (user-error (signal (car err) (cdr err)))
                 (error
                  (user-error
                   "The capture template \"%s\" failed (%s).  %s"
                   (car (car templates)) (error-message-string err)
                   "Check `autoslip-noter-capture-template'"))))
         (file (and node (org-roam-node-file node))))
    (unless file
      (user-error "The note %s was not found after the capture" address))
    file))

(defun autoslip-noter--set-document (file doc-path)
  "Record DOC-PATH as the org-noter document of the note in FILE.
The property goes into the property drawer at the top of the file, so
that it belongs to the folgezettel note itself.  Return the buffer that
visits FILE."
  (let ((buffer (find-file-noselect file))
        (prop (autoslip-noter--doc-property)))
    (with-current-buffer buffer
      (org-with-wide-buffer
       (goto-char (point-min))
       (unless (autoslip-noter--same-file-p (org-entry-get nil prop)
                                            doc-path)
         (org-entry-put nil prop (expand-file-name doc-path))
         (save-buffer)
         (org-roam-db-update-file file))))
    buffer))

;;;###autoload
(defun autoslip-noter-create-session (&optional _arg doc-path)
  "Start an org-noter session for DOC-PATH in a folgezettel note.
This function belongs on `org-noter-create-session-from-document-hook'.
`autoslip-noter-mode' puts it there.  Reuse the note that already
annotates DOC-PATH when there is one.  Otherwise create a new child
note with autoslip-roam."
  (let* ((doc-path (expand-file-name (or doc-path buffer-file-name)))
         (file (or (autoslip-noter-find-notes-file doc-path)
                   (autoslip-noter--create-note doc-path)))
         (buffer (autoslip-noter--set-document file doc-path)))
    (with-current-buffer buffer
      (goto-char (point-min))
      (org-noter))
    t))

;;;###autoload
(define-minor-mode autoslip-noter-mode
  "Global minor mode that makes org-noter use folgezettel notes.
When enabled, M-x org-noter in a document buffer finds or creates the
autoslip-roam note for that document."
  :global t
  :group 'autoslip-noter
  :lighter nil
  (require 'org-noter)
  (if autoslip-noter-mode
      (add-hook 'org-noter-create-session-from-document-hook
                #'autoslip-noter-create-session)
    (remove-hook 'org-noter-create-session-from-document-hook
                 #'autoslip-noter-create-session)))

(provide 'autoslip-noter)

;;; autoslip-noter.el ends here
