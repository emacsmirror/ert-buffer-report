;;; ert-buffer-report.el --- Extensions for ert-buffer.el

;; Author: Thorsten Jolitz <tjolitz AT gmail DOT com>
;; Version: 0.9
;; URL: https://github.com/tj64/ert-buffer-report

;;;; MetaData
;;   :PROPERTIES:
;;   :copyright: Thorsten Jolitz
;;   :copyright-years: 2014+
;;   :version:  0.9
;;   :licence:  GPL 3 or later (free software)
;;   :licence-url: http://www.gnu.org/licenses/
;;   :part-of-emacs: no
;;   :extension-author: Thorsten Jolitz
;;   :extension-author-email: <tjolitz AT gmail DOT com>
;;   :orig-author:  Stefan Merten
;;   :orig-author-email: <smerten AT oekonux DOT de>
;;   :url-orig-lib: http://goo.gl/Ov8MLf
;;   :keywords: emacs org-mode comment-editing
;;   :git-repo: https://github.com/tj64/ert-buffer-report
;;   :git-clone: git://github.com/tj64/ert-buffer-report.git
;;   :END:

;;;; Commentary
;;;;; Introduction

;; This library requires, builds-on and extends `ert-buffer.el' (and thus
;; includes parts of its code in modified versions). It is not meant to
;; replace `ert-buffer.el' in any way, it is just that - and extension in
;; functionality and use-cases.

;; The main purpose of `ert-buffer-report.el' is quick & easy adhoc
;; testing with (existing) real-world buffers and creating readable test
;; reports as Org-mode files. The library was developed for testing
;; `outorg.el' (which converts programming-mode buffers to org-mode and
;; vice-versa), thus it is especially suited to test for undesired
;; buffer-conversion side-effects.

;;;;; Use Cases

;;;;;; Testing for Conversion Side-Effects (do/undo-tests)

;;  1. Convert buffer from state A [BEFORE] to state B (e.g. change major-mode,
;;     uncomment comments, wrap source-code in code-blocks ...)

;;  2. Call some buffer-modifying command in state B

;;  3. Save resulting undo-buffer-tree

;;  4. Reconvert buffer from state B to state A

;;  5. Repeat (1) - convert from A -> B

;;  6. Undo the changes stored in saved undo-buffer-tree

;;  7. Repeat (4) - reconvert from B -> A [AFTER]

;; After 4 conversions in total (2 in each direction), there should be no
;; DIFFS between buffer-state A [BEFORE] and buffer-state A [AFTER] if
;; the conversion itself has no (undesired) side-effects.

;;;;;; Testing for expected DIFFS (stored as MD5s)

;;;;;; TDD by editing buffers (instead of writing tests)

;;;; Credits

;; The original author of the patched/overwritten functions in this
;; library is of course the author of `ert-buffer.el', Stefan Merten, and
;; all his original code is still contained in the patched/overwritten
;; function.

;;; Requires

(require 'ert-buffer)

;;; Variables

;;;; Consts

;; (defconst ert-buffer-report-temp-dir "~/junk/tmp-ert/")
;; (defconst ert-buffer-report-diff-executable "diff")

;;;; Vars

(defvar ert-buffer-report-insert-buffer-strings-p nil)
(defvar ert-buffer-report-ignore-return-values-p t)

;; (defvar outorg-test-saved-org-cmd ()
;;   "Org command to be used in ERT test.")

;; (defvar outorg-test-saved-major-mode nil
;;   "Major mode to be used in ERT test.")

;; (defvar outorg-test-saved-prefix-arg nil
;;   "Prefix arg to be used in ERT test.")

(defvar ert-buffer-report-saved-major-mode nil
  "Major mode to be used in ERT test.")

(defvar ert-buffer-report-saved-prefix-arg nil
  "Prefix arg to be used in ERT test.")

(defvar ert-buffer-report-saved-form nil
  "Form to be used in ERT test.")

;;;; Customs

;;;;; Custom Groups

(defgroup ert-buffer-report nil
  "Library for easy buffer testing, extending `ert-buffer.el'."
  :prefix "ert-buffer-report"
  :group 'lisp
  :link '(url-link
          "http://docutils.sourceforge.net/tools/editors/emacs/tests/ert-buffer.el"))

;;;;; Custom Vars

(defcustom ert-buffer-report-diff-executable "diff"
  "Executable for DIFF program."
  :group 'ert-buffer-report
  :type 'string)

;; set to in init.el "~/junk/tmp-ert/"
(defcustom ert-buffer-report-temp-dir "~/.ert.d/"
  "Directory for storing (temporary) test results and reports."
  :group 'ert-buffer-report
  :type 'string)

(unless (file-directory-p ert-buffer-report-temp-dir)
  (make-directory ert-buffer-report-temp-dir 'parents))

(defcustom ert-buffer-report-fail-with-content t
  "Fail test if content is not equal."
  :group 'ert-buffer-report
  :type 'boolean)

(defcustom ert-buffer-report-fail-with-point nil
  "Fail test if point-position is not equal."
  :group 'ert-buffer-report
  :type 'boolean)

(defcustom ert-buffer-report-fail-with-return-value t
  "Fail test if return-value is not equal."
  :group 'ert-buffer-report
  :type 'boolean)

;; FIXME docstring 

;; Though, an indicator for current test scope is added to the prompt
;;  (\"b\" when output is restricted to body only, \"s\" when it is
;;  restricted to the current subtree, \"v\" when only visible
;;  elements are considered for export, \"f\" when publishing
;;  functions should be passed the FORCE argument and \"a\" when the
;;  export should be asynchronous).  Also, [?] allows to switch back
;;  to standard mode.
(defcustom ert-buffer-report-dispatch-use-expert-ui nil
  "Non-nil means using a non-intrusive `ert-buffer-report-dispatch'.
In that case, no help buffer is displayed."
  :group 'ert-buffer-report
  :type 'boolean)


;;; Macros

;; copied and adapted from ert-buffer.el
(defmacro ert-buffer-report-equal (form input exp-output &optional interactive)
  "See docstring of `ert-equal-buffer'."
  `(let ((formq ',form))
     (ert-buffer-report--equal-buffer
      formq ,input ,exp-output t nil ,interactive)))

(put 'ert-buffer-report-equal
     'ert-explainer
     'ert-equal-buffer-return-explain)

;; copied and adapted from ert-buffer.el
(defmacro ert-buffer-report-equal-return (form input exp-output exp-return &optional interactive)
  "See docstring of `ert-equal-buffer-return'."
  `(let ((formq ',form))
     (ert-buffer-report--equal-buffer
      formq ,input ,exp-output nil ,exp-return ,interactive)))

(put 'ert-buffer-report-equal-return
     'ert-explainer
     'ert-equal-buffer-return-explain)

(defun ert-buffer-report-eval-form ()
  "Form to be used inside `ert-deftest'.
Simply evaluates the form stored in variable
`ert-buffer-report-saved-form'."
  (eval ert-buffer-report-saved-form))
 


(defun ert-buffer-report-run (org-cmd &optional use-prefix-arg-p return-p)
  "Prepare and run ERT test.

This command records the major-mode of current-buffer in global
variable `outorg-test-saved-major-mode', the given
prefix-argument in `outorg-test-saved-prefix-arg' (if
USE-PREFIX-ARG-P is non-nil) and the given ORG-CMD in
`outorg-test-saved-org-cmd', and it copies the content of current
buffer into a temporary *outorg-test-buffer* and sets its
major-mode.

After this preparation it calls either

 - `outorg-test-conversion-with-equal' :: RETURN-P is nil

 - `outorg-test-conversion-with-equal-return' :: RETURN-P is
      non-nil

depending on the values of optional function argument RETURN-P or
on `outorg-test-with-return-p'. These two tests make use of the
*outorg-test-buffer* and the three global variables mentioned
above."
  (interactive
   (if current-prefix-arg
       (list
	(read-command "Org Command: ")
	(y-or-n-p "Use prefix-arg for calling outorg ")
	(y-or-n-p "Test return values "))
     (list (read-command "Org Command: "))))
  (let ((old-buf (current-buffer))
	(maj-mode (outorg-get-buffer-mode)))
    ;; (ret-p (or return-p outorg-test-with-return-p))
    ;; (exp-p (or EXPLAIN-P outorg-test-with-explain-p)
    ;; (use-pref-arg-p (or use-prefix-arg-p
    ;; 		    outorg-test-with-return-p))))
    ;; necessary (?) HACK
    (setq outorg-test-saved-org-cmd org-cmd)
    (setq outorg-test-saved-major-mode maj-mode)
    (when use-prefix-arg-p
      (setq outorg-test-saved-prefix-arg current-prefix-arg))
    (save-restriction
      (widen)
      (with-current-buffer
	  (get-buffer-create "*outorg-test-buffer*")
	(erase-buffer)
	(insert-buffer-substring old-buf)
	(if (eq maj-mode 'ess-mode)
	    ;; special case R-mode
	    (funcall 'R-mode)
	  (funcall outorg-test-saved-major-mode))
	;; (funcall maj-mode)
	;; (call-interactively 'ert-run-tests-interactively)
	(if return-p
	    (funcall 'ert-run-tests-interactively
		     'outorg-test-conversion-with-equal-return)
	  (funcall
	   'ert-run-tests-interactively
	   'outorg-test-conversion-with-equal))))))

;; (defun ert-buffer-report-run (org-cmd &optional use-prefix-arg-p return-p)
;;   "Prepare and run ERT test.

;; This command records the major-mode of current-buffer in global
;; variable `outorg-test-saved-major-mode', the given
;; prefix-argument in `outorg-test-saved-prefix-arg' (if
;; USE-PREFIX-ARG-P is non-nil) and the given ORG-CMD in
;; `outorg-test-saved-org-cmd', and it copies the content of current
;; buffer into a temporary *outorg-test-buffer* and sets its
;; major-mode.

;; After this preparation it calls either

;;  - `outorg-test-conversion-with-equal' :: RETURN-P is nil

;;  - `outorg-test-conversion-with-equal-return' :: RETURN-P is
;;       non-nil

;; depending on the values of optional function argument RETURN-P or
;; on `outorg-test-with-return-p'. These two tests make use of the
;; *outorg-test-buffer* and the three global variables mentioned
;; above."
;;   (interactive
;;    (if current-prefix-arg
;;        (list
;; 	(read-command "Org Command: ")
;; 	(y-or-n-p "Use prefix-arg for calling outorg ")
;; 	(y-or-n-p "Test return values "))
;;      (list (read-command "Org Command: "))))
;;   (let ((old-buf (current-buffer))
;; 	(maj-mode (outorg-get-buffer-mode)))
;;     ;; (ret-p (or return-p outorg-test-with-return-p))
;;     ;; (exp-p (or EXPLAIN-P outorg-test-with-explain-p)
;;     ;; (use-pref-arg-p (or use-prefix-arg-p
;;     ;; 		    outorg-test-with-return-p))))
;;     ;; necessary (?) HACK
;;     (setq outorg-test-saved-org-cmd org-cmd)
;;     (setq outorg-test-saved-major-mode maj-mode)
;;     (when use-prefix-arg-p
;;       (setq outorg-test-saved-prefix-arg current-prefix-arg))
;;     (save-restriction
;;       (widen)
;;       (with-current-buffer
;; 	  (get-buffer-create "*outorg-test-buffer*")
;; 	(erase-buffer)
;; 	(insert-buffer-substring old-buf)
;; 	(if (eq maj-mode 'ess-mode)
;; 	    ;; special case R-mode
;; 	    (funcall 'R-mode)
;; 	  (funcall outorg-test-saved-major-mode))
;; 	;; (funcall maj-mode)
;; 	;; (call-interactively 'ert-run-tests-interactively)
;; 	(if return-p
;; 	    (funcall 'ert-run-tests-interactively
;; 		     'outorg-test-conversion-with-equal-return)
;; 	  (funcall
;; 	   'ert-run-tests-interactively
;; 	   'outorg-test-conversion-with-equal))))))

;;; Functions

;;;; Non-interactive Functions

;;;;; Overwritten

;; copied and adapted from ert-buffer.el
(defun ert-buffer-report--equal-buffer (form input exp-output ignore-return exp-return interactive)
  "See docstring of `ert--equal-buffer'."
  (let* ((result (ert--run-test-with-buffer
		  (ert-Buf--from-argument input exp-output)
		  form interactive))
	 (buf (ert-Buf--from-argument exp-output input))
	 (comparisons (ert--compare-test-with-buffer
		       result buf ignore-return exp-return))
	 (passed-p (ert-buffer-report--test-passed-p comparisons)))
    (ignore-errors
      (progn
	;; create test report
	(ert-buffer-report--create
	 result buf ignore-return exp-return comparisons passed-p)
	;; return test result (fail -> nil, pass -> t)
	passed-p))))

(defun ert-buffer-report--test-passed-p (comparisons)
  "Return t when all COMPARISONS passed, nil otherwise."
  (unless (and comparisons
	       (listp comparisons)
	       (eq (length comparisons) 3))
    (error "Something wrong with comparison list: %s" comparisons))
  (cond
   ;; content not equal
   ((and (not (nth 0 comparisons))
	 ert-buffer-report-fail-with-content) nil)
   ;; point-position not equal
   ((and (not (nth 1 comparisons))
	 ert-buffer-report-fail-with-point) nil)
   ;; return-value nor equal nor ignored
   ((and (not (nth 2 comparisons))
	 (not ignore-return)
	 ert-buffer-report-fail-with-return-value) nil)
   ;; else pass test
   (t t)))

	
;;;;; Create Report

(defun ert-buffer-report--create (result buf ignore-return exp-return comparisons passed-p)
  "Create test report as Org-mode file."
  (let* ((act-return (car result))
	 (act-buf (cdr result))
	 (temporary-file-directory ert-buffer-report-temp-dir)
	 (ert-report (make-temp-file "ert-report" nil ".org"))
	 (diff-strg
	  (shell-command-to-string
	   (format "%s %s %s"
		   ert-buffer-report-diff-executable
		   (let ((tmp-file-buf (make-temp-file "buf")))
		     (with-current-buffer
			 (find-file-noselect tmp-file-buf)
		       (insert (ert-Buf-content buf))
		       (save-buffer)
		       (kill-buffer))
		     (chmod tmp-file-buf 438)
		     tmp-file-buf)
		   (let ((tmp-file-act-buf
			  (make-temp-file "act-buf")))
		     (with-current-buffer
			 (find-file-noselect tmp-file-act-buf)
		       (insert (ert-Buf-content act-buf))
		       (save-buffer)
		       (kill-buffer))
		     (chmod tmp-file-act-buf 438)
		     tmp-file-act-buf))))
	 (diff-md5 (md5 diff-strg))
	 (org-time-stamp-formats
	  '("<%Y-%m-%d %a>" . "<%Y-%m-%d %a %H:%M:%S>")))
    (chmod ert-report 438)
    (with-current-buffer
	(find-file ert-report)
      (org-mode)
      ;; 1st Level *
      (org-insert-heading)
      (insert "ERT Report ")
      (org-entry-put (point) "Author"
		     (or user-full-name
			 user-login-name
			 "---"))
      (org-entry-put (point) "Email"
		     (or user-mail-address "---"))
      (org-entry-put (point) "Author"
		     (or (user-full-name) "---"))
      ;; (org-entry-put (point) "Input_buffer"
      ;; 	       (or (buffer-name buf) "---"))
      ;; (org-entry-put (point) "Output_buffer"
      ;; 	       (or (buffer-name act-buf) "---"))
      (org-entry-put (point) "DIFF_MD5"
		     (or diff-md5 "---"))
      (org-insert-time-stamp nil t)
      (org-set-tags-to
       (if passed-p ":PASSED:" ":FAILED:"))
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      ;; 2nd Level **
      (org-insert-heading '(4))
      (insert "Test Decision")
      (org-demote-subtree)
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (insert
       (format
	(concat
	 "  based on:\n"
	 " - content :: %s\n"
	 " - point :: %s\n"
	 " - return-value :: %s\n")
	ert-buffer-report-fail-with-content
	ert-buffer-report-fail-with-point
	(and ert-buffer-report-fail-with-return-value
	     (not ignore-return))))
      (unless (looking-at "^$") (newline))
      ;; 2nd Level **
      (org-insert-heading '(4))
      (insert "Summary")
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (insert
       (format
	(concat
	 " - Point position :: %s -> %s\n"
	 " - Mark position :: %s -> %s\n"
	 " - Content length :: %d -> %d\n"
	 " - Return value :: %s\n")
	(ert-Buf-point buf) (ert-Buf-point act-buf)
	(ert-Buf-mark buf) (ert-Buf-mark act-buf)
	(length (ert-Buf-content buf))
	(length (ert-Buf-content act-buf))
	(cond
	 (ignore-return "ignored")
	 ((equal act-return exp-return)
	  "expected == actual")
	 ((not (equal act-return exp-return))
	  "expected != actual")
	 (t (error "This should not happen")))))
      (unless (looking-at "^$") (newline))
      ;; 2nd Level **
      (org-insert-heading '(4))
      (insert "Return Value")
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      ;; 3rd Level ***
      (org-insert-heading '(4))
      (insert "Expected Return Value")
      (org-demote-subtree)
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (insert
       (if ignore-return
	   "   [ignored]"
	 (format
	  "#+begin_quote\n%s\n#+end_quote\n" exp-return)))
      (unless (looking-at "^$") (newline))
      ;; 3rd Level ***
      (org-insert-heading '(4))
      (insert "Actual Return Value")
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (insert
       (if ignore-return
	   "   [ignored]"
	 (format
	  "#+begin_quote\n%s\n#+end_quote\n" act-return)))
      (unless (looking-at "^$") (newline))
      ;; 2nd Level **
      (org-insert-heading '(4))
      (insert "Content DIFF")
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (if (org-string-nw-p diff-strg)
	  (insert
	   (format
	    "#+begin_quote\n%s\n#+end_quote\n"
	    diff-strg))
	(insert "   [no-diffs]"))
      (unless (looking-at "^$") (newline))
      ;; 2nd Level **
      (org-insert-heading '(4))
      (insert "Buffer Strings")
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      ;; 3rd Level ***
      (org-insert-heading '(4))
      (insert "Buffer String BEFORE")
      (org-demote-subtree)
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (insert
       (if (not ert-buffer-report-insert-buffer-strings-p)
	   "   [omitted]\n"
	 (format "#+begin_quote\n%s\n#+end_quote\n"
		 (ert-Buf-string buf))))
      (unless (looking-at "^$") (newline))
      ;; 3rd Level ***
      (org-insert-heading '(4))
      (insert "Buffer String AFTER")
      (org-end-of-meta-data-and-drawers)
      (unless (looking-at "^$") (newline))
      (insert
       (if (not ert-buffer-report-insert-buffer-strings-p)
	   "   [omitted]\n"
	 (format "#+begin_quote\n%s\n#+end_quote\n"
		 (ert-Buf-string act-buf))))
      (save-buffer)
      ;; switch to report buffer
      (if (one-window-p)
	  (split-window-sensibly
	   (get-buffer-window))) ; ? why
      (switch-to-buffer-other-window (current-buffer)))))

;;;;; Dispatch Functions

;; copied and modified from ox.el
(defun ert-buffer-report--dispatch-ui (options first-key expertp)
  "Handle interface for `ert-buffer-report-dispatch'.

OPTIONS is a list containing current interactive options set for
export.  It can contain any of the following symbols:
`body'    toggles a body-only export
`subtree' restricts export to current subtree
`visible' restricts export to visible part of buffer.
`force'   force publishing files.
`async'   use asynchronous export process

FIRST-KEY is the key pressed to select the first level menu.  It
is nil when this menu hasn't been selected yet.

EXPERTP, when non-nil, triggers expert UI.  In that case, no help
buffer is provided, but indications about currently active
options are given in the prompt.  Moreover, \[?] allows to switch
back to standard interface."
  (let* ((fontify-key
	  (lambda (key &optional access-key)
	    ;; Fontify KEY string.  Optional argument ACCESS-KEY, when
	    ;; non-nil is the required first-level key to activate
	    ;; KEY.  When its value is t, activate KEY independently
	    ;; on the first key, if any.  A nil value means KEY will
	    ;; only be activated at first level.
	    (if (or (eq access-key t) (eq access-key first-key))
		(org-propertize key 'face 'org-warning)
	      key)))
	 (fontify-value
	  (lambda (value)
	    ;; Fontify VALUE string.
	    (org-propertize value 'face 'font-lock-variable-name-face)))
	 ;; Prepare menu entries by extracting them from registered
	 ;; back-ends and sorting them by access key and by ordinal,
	 ;; if any.
	 (entries
	  (sort (sort (delq nil
			    (mapcar 'org-export-backend-menu
				    org-export--registered-backends))
		      (lambda (a b)
			(let ((key-a (nth 1 a))
			      (key-b (nth 1 b)))
			  (cond ((and (numberp key-a) (numberp key-b))
				 (< key-a key-b))
				((numberp key-b) t)))))
		'car-less-than-car))
	 ;; Compute a list of allowed keys based on the first key
	 ;; pressed, if any.  Some keys
	 ;; (?^B, ?^V, ?^S, ?^F, ?^A, ?&, ?# and ?q) are always
	 ;; available.
	 (allowed-keys
	  (nconc (list 2 22 19 6 1)
		 (if (not first-key) (org-uniquify (mapcar 'car entries))
		   (let (sub-menu)
		     (dolist (entry entries (sort (mapcar 'car sub-menu) '<))
		       (when (eq (car entry) first-key)
			 (setq sub-menu (append (nth 2 entry) sub-menu))))))
		 (cond ((eq first-key ?P) (list ?f ?p ?x ?a))
		       ((not first-key) (list ?P)))
		 (list ?& ?#)
		 (when expertp (list ??))
		 (list ?q)))
	 ;; Build the help menu for standard UI.
	 (help
	  (unless expertp
	    (concat
	     ;; Options are hard-coded.
	     (format "[%s] Body only:    %s           [%s] Visible only:     %s
\[%s] Export scope: %s       [%s] Force publishing: %s
\[%s] Async export: %s\n\n"
		     (funcall fontify-key "C-b" t)
		     (funcall fontify-value
			      (if (memq 'body options) "On " "Off"))
		     (funcall fontify-key "C-v" t)
		     (funcall fontify-value
			      (if (memq 'visible options) "On " "Off"))
		     (funcall fontify-key "C-s" t)
		     (funcall fontify-value
			      (if (memq 'subtree options) "Subtree" "Buffer "))
		     (funcall fontify-key "C-f" t)
		     (funcall fontify-value
			      (if (memq 'force options) "On " "Off"))
		     (funcall fontify-key "C-a" t)
		     (funcall fontify-value
			      (if (memq 'async options) "On " "Off")))
	     ;; Display registered back-end entries.  When a key
	     ;; appears for the second time, do not create another
	     ;; entry, but append its sub-menu to existing menu.
	     (let (last-key)
	       (mapconcat
		(lambda (entry)
		  (let ((top-key (car entry)))
		    (concat
		     (unless (eq top-key last-key)
		       (setq last-key top-key)
		       (format "\n[%s] %s\n"
			       (funcall fontify-key (char-to-string top-key))
			       (nth 1 entry)))
		     (let ((sub-menu (nth 2 entry)))
		       (unless (functionp sub-menu)
			 ;; Split sub-menu into two columns.
			 (let ((index -1))
			   (concat
			    (mapconcat
			     (lambda (sub-entry)
			       (incf index)
			       (format
				(if (zerop (mod index 2)) "    [%s] %-26s"
				  "[%s] %s\n")
				(funcall fontify-key
					 (char-to-string (car sub-entry))
					 top-key)
				(nth 1 sub-entry)))
			     sub-menu "")
			    (when (zerop (mod index 2)) "\n"))))))))
		entries ""))
	     ;; Publishing menu is hard-coded.
	     (format "\n[%s] Publish
    [%s] Current file              [%s] Current project
    [%s] Choose project            [%s] All projects\n\n\n"
		     (funcall fontify-key "P")
		     (funcall fontify-key "f" ?P)
		     (funcall fontify-key "p" ?P)
		     (funcall fontify-key "x" ?P)
		     (funcall fontify-key "a" ?P))
	     (format "[%s] Export stack                  [%s] Insert template\n"
		     (funcall fontify-key "&" t)
		     (funcall fontify-key "#" t))
	     (format "[%s] %s"
		     (funcall fontify-key "q" t)
		     (if first-key "Main menu" "Exit")))))
	 ;; Build prompts for both standard and expert UI.
	 (standard-prompt (unless expertp "Export command: "))
	 (expert-prompt
	  (when expertp
	    (format
	     "Export command (C-%s%s%s%s%s) [%s]: "
	     (if (memq 'body options) (funcall fontify-key "b" t) "b")
	     (if (memq 'visible options) (funcall fontify-key "v" t) "v")
	     (if (memq 'subtree options) (funcall fontify-key "s" t) "s")
	     (if (memq 'force options) (funcall fontify-key "f" t) "f")
	     (if (memq 'async options) (funcall fontify-key "a" t) "a")
	     (mapconcat (lambda (k)
			  ;; Strip control characters.
			  (unless (< k 27) (char-to-string k)))
			allowed-keys "")))))
    ;; With expert UI, just read key with a fancy prompt.  In standard
    ;; UI, display an intrusive help buffer.
    (if expertp
	(ert-buffer-report--dispatch-action
	 expert-prompt allowed-keys entries options first-key expertp)
      ;; At first call, create frame layout in order to display menu.
      (unless (get-buffer "*Org Export Dispatcher*")
	(delete-other-windows)
	(org-switch-to-buffer-other-window
	 (get-buffer-create "*Org Export Dispatcher*"))
	(setq cursor-type nil
	      header-line-format "Use SPC, DEL, C-n or C-p to navigate.")
	;; Make sure that invisible cursor will not highlight square
	;; brackets.
	(set-syntax-table (copy-syntax-table))
	(modify-syntax-entry ?\[ "w"))
      ;; At this point, the buffer containing the menu exists and is
      ;; visible in the current window.  So, refresh it.
      (with-current-buffer "*Org Export Dispatcher*"
	;; Refresh help.  Maintain display continuity by re-visiting
	;; previous window position.
	(let ((pos (window-start)))
	  (erase-buffer)
	  (insert help)
	  (set-window-start nil pos)))
      (org-fit-window-to-buffer)
      (ert-buffer-report--dispatch-action
       standard-prompt allowed-keys entries options first-key expertp))))

;; copied and modified from ox.el
(defun ert-buffer-report--dispatch-action
  (prompt allowed-keys entries options first-key expertp)
  "Read a character from command input and act accordingly.

PROMPT is the displayed prompt, as a string.  ALLOWED-KEYS is
a list of characters available at a given step in the process.
ENTRIES is a list of menu entries.  OPTIONS, FIRST-KEY and
EXPERTP are the same as defined in `ert-buffer-report--dispatch-ui',
which see.

Toggle export options when required.  Otherwise, return value is
a list with action as CAR and a list of interactive export
options as CDR."
  (let (key)
    ;; Scrolling: when in non-expert mode, act on motion keys (C-n,
    ;; C-p, SPC, DEL).
    (while (and (setq key (read-char-exclusive prompt))
		(not expertp)
		(memq key '(14 16 ?\s ?\d)))
      (case key
	(14 (if (not (pos-visible-in-window-p (point-max)))
		(ignore-errors (scroll-up 1))
	      (message "End of buffer")
	      (sit-for 1)))
	(16 (if (not (pos-visible-in-window-p (point-min)))
		(ignore-errors (scroll-down 1))
	      (message "Beginning of buffer")
	      (sit-for 1)))
	(?\s (if (not (pos-visible-in-window-p (point-max)))
		 (scroll-up nil)
	       (message "End of buffer")
	       (sit-for 1)))
	(?\d (if (not (pos-visible-in-window-p (point-min)))
		 (scroll-down nil)
	       (message "Beginning of buffer")
	       (sit-for 1)))))
    (cond
     ;; Ignore undefined associations.
     ((not (memq key allowed-keys))
      (ding)
      (unless expertp (message "Invalid key") (sit-for 1))
      (ert-buffer-report--dispatch-ui options first-key expertp))
     ;; q key at first level aborts export.  At second level, cancel
     ;; first key instead.
     ((eq key ?q) (if (not first-key) (error "Export aborted")
		    (ert-buffer-report--dispatch-ui options nil expertp)))
     ;; Help key: Switch back to standard interface if expert UI was
     ;; active.
     ((eq key ??) (ert-buffer-report--dispatch-ui options first-key nil))
     ;; Send request for template insertion along with export scope.
     ((eq key ?#) (cons 'template (memq 'subtree options)))
     ;; Switch to asynchronous export stack.
     ((eq key ?&) '(stack))
     ;; Toggle options: C-b (2) C-v (22) C-s (19) C-f (6) C-a (1).
     ((memq key '(2 22 19 6 1))
      (ert-buffer-report--dispatch-ui
       (let ((option (case key (2 'body) (22 'visible) (19 'subtree)
			   (6 'force) (1 'async))))
	 (if (memq option options) (remq option options)
	   (cons option options)))
       first-key expertp))
     ;; Action selected: Send key and options back to
     ;; `ert-buffer-report-dispatch'.
     ((or first-key (functionp (nth 2 (assq key entries))))
      (cons (cond
	     ((not first-key) (nth 2 (assq key entries)))
	     ;; Publishing actions are hard-coded.  Send a special
	     ;; signal to `ert-buffer-report-dispatch'.
	     ((eq first-key ?P)
	      (case key
		(?f 'publish-current-file)
		(?p 'publish-current-project)
		(?x 'publish-choose-project)
		(?a 'publish-all)))
	     ;; Return first action associated to FIRST-KEY + KEY
	     ;; path. Indeed, derived backends can share the same
	     ;; FIRST-KEY.
	     (t (catch 'found
		  (mapc (lambda (entry)
			  (let ((match (assq key (nth 2 entry))))
			    (when match (throw 'found (nth 2 match)))))
			(member (assq first-key entries) entries)))))
	    options))
     ;; Otherwise, enter sub-menu.
     (t (ert-buffer-report--dispatch-ui options key expertp)))))
;;;; Commands
;;;;; Toggle Vars

(defun ert-buffer-report-toggle-insert-buffer-strings ()
  "Toggles the value of a boolean var.
If `ert-buffer-report-insert-buffer-strings-p' is non-nil, the
buffer-strings of the test-buffer before and after the test are
included in the test-report."
  (interactive)
  (if ert-buffer-report-insert-buffer-strings-p
      (setq ert-buffer-report-insert-buffer-strings-p nil)
    (setq ert-buffer-report-insert-buffer-strings-p t))
  (message "ERT-report: insert buffer strings is %s"
	   ert-buffer-report-insert-buffer-strings-p))

(defun ert-buffer-report-toggle-ignore-return-values ()
  "Toggles the value of a boolean var.
If `ert-buffer-report-ignore-return-values-p' is non-nil, the
expected and actual return values of the test are included in the
test-report."
  (interactive)
  (if ert-buffer-report-ignore-return-values-p
      (setq ert-buffer-report-ignore-return-values-p nil)
    (setq ert-buffer-report-ignore-return-values-p t))
  (message "ERT-report: ignore return values is %s"
	   ert-buffer-report-ignore-return-values-p))


;;;;; The Dispatcher
;;
;; `ert-buffer-report-dispatch' is the standard interactive way to start an
;; export process.  It uses `ert-buffer-report--dispatch-ui' as a subroutine
;; for its interface, which, in turn, delegates response to key
;; pressed to `ert-buffer-report--dispatch-action'.


;; copied and modified from ox.el
(defun ert-buffer-report-dispatch (&optional arg)
  "Test dispatcher for `ert-buffer-report'.

It provides an access to common buffer-test related tasks in a
dispatch buffer. Its interface comes in two flavors: standard and
expert.

While both share the same set of bindings, only the former
displays the valid keys associations in a dedicated buffer.
Scrolling (resp. line-wise motion) in this buffer is done with
SPC and DEL (resp. C-n and C-p) keys.

Set variable `ert-buffer-report-dispatch-use-expert-ui' to switch to one
flavor or the other.

When ARG is \\[universal-argument], repeat the last buffer-test
action, with the same set of options used back then, on the
current buffer.

When ARG is \\[universal-argument] \\[universal-argument], display the asynchronous export stack."
  (interactive "P")
  (let* ((input
	  (cond ((equal arg '(16)) '(stack))
		((and arg ert-buffer-report-dispatch-last-action))
		(t (save-window-excursion
		     (unwind-protect
			 (progn
			   ;; Remember where we are
			   (move-marker ert-buffer-report-dispatch-last-position
					(point)
					(org-base-buffer (current-buffer)))
			   ;; Get and store an export command
			   (setq ert-buffer-report-dispatch-last-action
				 (ert-buffer-report--dispatch-ui
				  (list org-export-initial-scope
					(and org-export-in-background 'async))
				  nil
				  ert-buffer-report-dispatch-use-expert-ui)))
		       (and (get-buffer "*Org Export Dispatcher*")
			    (kill-buffer "*Org Export Dispatcher*")))))))
	 (action (car input))
	 (optns (cdr input)))
    (unless (memq 'subtree optns)
      (move-marker ert-buffer-report-dispatch-last-position nil))
    (case action
      ;; First handle special hard-coded actions.
      (template (org-export-insert-default-template nil optns))
      (stack (org-export-stack))
      (publish-current-file
       (org-publish-current-file (memq 'force optns) (memq 'async optns)))
      (publish-current-project
       (org-publish-current-project (memq 'force optns) (memq 'async optns)))
      (publish-choose-project
       (org-publish (assoc (org-icompleting-read
			    "Publish project: "
			    org-publish-project-alist nil t)
			   org-publish-project-alist)
		    (memq 'force optns)
		    (memq 'async optns)))
      (publish-all (org-publish-all (memq 'force optns) (memq 'async optns)))
      (otherwise
       (save-excursion
	 (when arg
	   ;; Repeating command, maybe move cursor to restore subtree
	   ;; context.
	   (if (eq (marker-buffer ert-buffer-report-dispatch-last-position)
		   (org-base-buffer (current-buffer)))
	       (goto-char ert-buffer-report-dispatch-last-position)
	     ;; We are in a different buffer, forget position.
	     (move-marker ert-buffer-report-dispatch-last-position nil)))
	 (funcall action
		  ;; Return a symbol instead of a list to ease
		  ;; asynchronous export macro use.
		  (and (memq 'async optns) t)
		  (and (memq 'subtree optns) t)
		  (and (memq 'visible optns) t)
		  (and (memq 'body optns) t)))))))


;;; Tests

;;;; Equal 

(ert-deftest outorg-test-conversion-with-equal ()
  "Test outorg conversion to and from Org.

This test assumes that it is called via user command
`ert-buffer-report-run' with point in the original programming
language buffer to be converted to Org-mode, and with the prefix
argument that should be used for `outorg-edit-as-org'. It further
relies on the `ert-buffer' library for doing its work.

Since outorg is about editing (and thus modifying) a buffer in
Org-mode, defining the expected outcome manually would be bit
cumbersome. Therefore so called 'do/undo' tests (invented and
named by the author) are introduced:

 - do :: convert to org, save original state before editing, edit
         in org, produce and save the diffs between original and
         final state, convert back from org

 - undo :: convert to org again, undo the saved diffs, convert
           back from org

After such an do/undo cyle the test buffer should be in exactly
the same state as before the test, i.e.

 - buffer content after the test should be string-equal to buffer
   content before

 - point should be in the same position

 - the mark should be in the same position (or nil)

These are actually the three criteria checked by the 'ert-buffer'
library, and when one or more of the checks returns nil, the ert
test fails.

This test is a one-size-fits-all test for outorg, since it
allows, when called via command `ert-buffer-report-run', to execute
arbitrary Org-mode commands in the *outorg-edit-buffer* and undo
the changes later on, checking for any undesired permanent side
effects of the conversion process per se."
  (let ((curr-buf-initial-state
	 (with-current-buffer "*outorg-test-buffer*"
	   (ert-Buf-from-buffer))))
    (should
     ;; (ert-equal-buffer
     (ert-buffer-report-equal
      (ert-buffer-report-eval-form)
      curr-buf-initial-state
      t))))

;;;; Equal Return 

(ert-deftest outorg-test-conversion-with-equal-return ()
  "Test outorg conversion to and from Org.

This test takes return values into account. See docstring of
`outorg-test-conversion-with-equal' for more info."
  (let ((curr-buf-initial-state
	 (with-current-buffer "*outorg-test-buffer*"
	   (ert-Buf-from-buffer))))
    (should
     ;; (ert-equal-buffer-return
     (ert-buffer-report-equal-return 
      (ert-buffer-report-eval-form)
      curr-buf-initial-state
      t nil))))


;;; Run Hooks and Provide

(provide 'ert-buffer-report)

;; ert-buffer-report.el ends here

