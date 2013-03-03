;;; org-bibtex.el
;; 
;; ATTENTION:
;; This file relies heavily on the 4 variables you see below, so read
;; them and check if they are OK for you before you do anything.

;; The only function you need to call is `org/new-paper'. It will ask
;; you for a URL. Paste in the URL of the paper and it does the rest.
;;
;; Unfortunately it only understands a few URLs right now. If you'd
;; like to improve it in this sense, the only thing you need to do is
;; add extra clauses in the `org/extract-doi' function and the 
;; `org/paper-url' function.

(defcustom org/pdf-paper-download-folder "~/Dropbox/Papers/" 
  "Directory where pdf files will be saved. They are save as
  \"Paper Title.pdf\" (with spaces)."
  :type 'string
  :group 'org-bibtex)

(defcustom org/papers-file "~/Dropbox/Org/papers.org.bib" 
  "The file where paper headlines are to be entered."
  :type 'string
  :group 'org-bibtex)

(defcustom org/papers-headline "\n* To read" 
  "The level-1 headline under which new papers should be inserted.

This MUST be a string matching \"\\n* \" followed by the name of a
headline (the number of '*' is up to you). This is used in a
simple call to `search-forward', so this headline must exist in
the file or the function will fail."
  :type 'string
  :group 'org-bibtex)

(defvar org/curl-path (executable-find "curl")
  "Path to curl application. Customize this if emacs can't find
  your curl.")

;; (defvar org/temp-download-newname
;;   (concat user-emacs-directory "org-temp-download")
;;   "File where to save temporary downloads.")


(defun org/new-paper (&optional url)
  "Create a headline for the paper in URL, and refile it under
`org/papers-headline'."
  (interactive "sURL: ")
  (let ((bibtex (org/retrieve-bibtex url))
        title authors year file publisher urlprob doi)

    (find-file org/papers-file)
    (beginning-of-buffer)
    (search-forward org/papers-headline)
    (move-beginning-of-line 2)
    (insert
     (with-temp-buffer
       (insert bibtex)
       (insert "\n")
       (setq title     (org/extract-bibtex-property "title")
             year      (org/extract-bibtex-property "year")
             author    (org/extract-bibtex-property "author")
             publisher (org/extract-bibtex-property "publisher")
             file (concat org/pdf-paper-download-folder
                          (org/title-to-filename title) ".pdf"))
       (org/extract-bibtex-property "DOI")
       (org/extract-bibtex-property "url" url)

       (beginning-of-buffer)
       (insert
        (concat "*** " title "
:PROPERTIES:
:File: [[file:" file "]]
:URL: [[" url "]]
:Author: " (concat "\""
                   (replace-regexp-in-string " and " "\" \"" author)
                   "\"") "
:Publisher: " publisher "
:END:

**** Bibtex
"))
       (search-forward "{")
       (delete-region (point) (line-end-position))
       (setq author (split-string author))

       (insert
        (if (= (car (reverse (string-to-list (car author)))) ?,)
            (car author)
          (concat (nth 1 author) ",")))
       (backward-char 1)
       (insert (replace-regexp-in-string "^ *[0-9][0-9]" "" year))
       (buffer-string)))
    (search-backward "\n**** Bibtex")
    (url-copy-file (org/paper-pdf-url url) file 1)))

(defun org/title-to-filename (title)
  "Replace illegal characters in title to make a viable filename."
  (replace-regexp-in-string  "[^ a-zA-Z0-9_.^=%-]" "" title))

(defun org/paper-pdf-url (url)
  "Generate a url for downloading the pdf corresponding to URL."
  (setq url (if (string-match "^http://" url)
                url (concat "http://" url)))
  (cond
   ((string-match "^.*arxiv.org/.*$" url)
    (replace-regexp-in-string "abs" "pdf" url))
   ((string-match "^.*nature.com/.*$" url)
    (replace-regexp-in-string "\.html" ".pdf"
                              (replace-regexp-in-string "/\\(abs\\|full\\)/" "/pdf/" url)))
   ))

(defun org/extract-bibtex-property (name &optional url)
  "Get the value for the property named NAME from the bibtex in
the current (temp-)buffer."
  (save-excursion
    (beginning-of-buffer)
    (let ((case-fold-search t))
      (if (search-forward-regexp (concat "^ *" name " *= *{\\(.*\\)}, *$") nil t)
          (match-string 1)
        (let ((value
               (cond
                ((string-equal name "publisher")
                 (read-string "Publisher missing [arXiv]:"
                              nil nil "arXiv"))
                ((string-equal name "DOI") nil)
                ((string-equal name "url") url)
                (t (read-string (concat name " missing:"))))))
          (beginning-of-buffer)
          (next-line 1)
          (if value (insert (format "  %s={%s}\n" name value)))
          value)))))


(defun org/retrieve-bibtex (url)
  "Get the bibtex string for the paper in URL."
  (cond
   ((string-match "^.*arxiv.org/.*$" url)
    (let ((doi (replace-regexp-in-string ".*\\([0-9][0-9][0-9][0-9]\\.[0-9][0-9][0-9][0-9]\\).*" "\\1" url))
        left)
    
    (switch-to-buffer (url-retrieve-synchronously
                       (concat "http://www.crcg.de/arXivToBibTeX/?format=bibtex&q=" doi)))
    (beginning-of-buffer)
    (search-forward "@misc{")
    (setq left (match-beginning 0))
    (search-forward "
}")
    (setq left (replace-regexp-in-string "@misc" "@article"
                                         (buffer-substring-no-properties left (match-end 0))))
    (kill-buffer)
    (replace-regexp-in-string "\n *\\([A-Za-z]\\)" "\n  \\1"
                              (replace-regexp-in-string " = " "=" left))))
   (t 
    (let* ((doi (org/extract-doi url)))
      (with-temp-buffer
        (call-process org/curl-path nil t nil
                      "-s" "-L" "-H" "Accept: application/x-bibtex"
                      (concat "http://dx.doi.org/" doi))
        (beginning-of-buffer)
        (replace-regexp "\\([}0-9]\\), " "\\1,\n  ")
        (beginning-of-buffer)
        (replace-regexp "}}" "}\n}")
        (buffer-string))))
   ))

(defun org/extract-doi (url)
  "Guess doi from the given URL. 

You can improve this function by telling it how to extract the
DOI from other journals. It first detects what journal the URL
belongs to, then extracts and returns the DOI."
  (cond
   ((string-match "^.*iop\.org/[-0-9/]+$" url)
    (concat "10.1088/"
            (replace-regexp-in-string
             ".*iop\.org/\\(.*\\)/$" "\\1" url)))
   ((string-match "^.*nature\.com/.*$" url)
    (concat "10.1038/"
            (replace-regexp-in-string
             ".*/\\([^/]*\\)\\..*" "\\1" url)))
   ((string-match "^.*aps\.org/.*/v[0-9]*/.*/e[0-9]*$" url)
    (let ((end (replace-regexp-in-string 
                ".*/\\([A-Z][A-Z][A-Z]\\)/v\\([0-9]+\\)/.*/e\\([0-9]+\\).*" ".\\2.\\3" url))
          (j  (replace-regexp-in-string
               ".*/PR\\([A-Z]\\)/v\\([0-9]+\\)/.*/e\\([0-9]+\\).*" "PhysRev\\1"
               (replace-regexp-in-string
                ".*/\\(PRL\\)/v\\([0-9]+\\)/.*/e\\([0-9]+\\).*" "PhysRevLett" url))))
      (concat "10.1103/" j end)))
   (t (error "Couldn't extract DOI. URL not recognized."))))
