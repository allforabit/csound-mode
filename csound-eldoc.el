(require 'csound-opcodes)

(defun csound-eldoc-get-template (opcode-list)
  (progn (setq templ nil
	       indx 0)
	 (while (and (< indx (length opcode-list))
		     (eq templ nil))
	   (when (eq :template (nth indx opcode-list))
	     (setq templ t))
	   (setq indx (1+ indx)))
	 (if templ
	     (nth indx opcode-list)
	   "")))

(defun csound-eldoc-line-escape-count ()
  (save-excursion
    (progn (setq linenums 1)
	   (while (search-backward-regexp "\\\\.*\n" (line-end-position -1) t)
	     (setq linenums (1- linenums)))
	   linenums)))

(defun csound-eldoc-statement ()
  (save-excursion
    (let ((countback (csound-eldoc-line-escape-count)))
      (buffer-substring
       (line-beginning-position countback)
       (line-end-position)))))

(defun chomp (str)
  "Chomp leading and tailing whitespace from STR."
  (while (string-match "\\`\n+\\|^\\s-+\\|\\s-+$\\|\n+\\'"
		       str)
    (setq str (replace-match "" t t str)))
  str)

(defun csound-eldoc-statement-list (string-statement)
  (split-string
   (chomp string-statement)
   "\\(,+\s*\\)+\\|\\(\s+,*\\)+"))


(defun csound-eldoc-template-lookup (statement-list)
  (progn (setq result nil
	       opdoce nil)
	 (dolist (statement statement-list) 
	   (when (gethash statement csdoc-opcode-database)
	     (setq result (csound-eldoc-get-template
			   (gethash statement csdoc-opcode-database))
		   opcode statement))) 
	 (when result 
	   (let ((rate-list (split-string (replace-regexp-in-string "\n\s" "\n" result) "\n")))	     
	     (if (= (length rate-list) 1)
		 (list opcode (first rate-list))
	       (let ((rate-candidate (substring (first statement-list) 0 1)))
		 (setq rate-match nil)
		 (dolist (xrate rate-list)
		   (when (string= rate-candidate (substring xrate 0 1))
		     (setq rate-match xrate)))
		 (if rate-match
		     (list opcode rate-match)
		   (list opcode (first rate-list)))))))))


(defun csound-eldoc-argument-index (opcode-match opcode-index point-on-opcode?)
  (if point-on-opcode?
      0
    (save-excursion
      (let* ((statement (buffer-substring
			 (line-beginning-position (csound-eldoc-line-escape-count))
			 (point)))
	     (komma-format-list (split-string
				 (replace-regexp-in-string
				  opcode-match
				  (concat "," opcode-match ",")
				  statement) ",")))
	(setq indx 0
	      pos nil)
	(dolist (i komma-format-list)
	  (if (string= opcode-match i)
	      (setq indx 0
		    pos t)
	    (if pos
		(setq indx (1+ indx))
	      (setq indx (1- indx)))))
	indx))))


(defun csound-eldoc-opcode-index (opcode-match template-list)
  (progn
    (setq indx 0 match? nil)
    (while (and (< indx (length template-list))
		(not match?))
      (if (string= (nth indx template-list)
		   opcode-match)
	  (setq match? t)
	(setq indx (1+ indx))))
    indx))


;;;###autoload
(defun csound-eldoc-function ()
  "Returns a doc string appropriate for the current context, or nil." 
  (let* ((csound-statement (csound-eldoc-statement))
	 (statement-list (csound-eldoc-statement-list csound-statement))
	 (template-lookup (csound-eldoc-template-lookup statement-list)))
    (when template-lookup
      (let* ((opcode-match (first template-lookup))
	     (point-on-opcode? (string= opcode-match (thing-at-point 'symbol)))
	     (csound-template (replace-regexp-in-string
			       "[^\\[]\\.\\.\\." ""
			       (replace-regexp-in-string
				"\\[, " "["
				(nth 1 template-lookup))))
	     (template-list (csound-eldoc-statement-list csound-template)) 
	     (template-list-length (1- (length template-list)))
	     (opcode-index (csound-eldoc-opcode-index opcode-match template-list))
	     (argument-index (csound-eldoc-argument-index opcode-match opcode-index point-on-opcode?))
	     ;; (argument-index (if (< argument-index opcode-index)
	     ;; 			 (* -1 argument-index)
	     ;; 		       (+ opcode-index argument-index)))
	     (infinite-args? (string= "[...]" (car (last template-list)))))
	(setq indx -1 list-index 0
	      eldocstr "" inf-arg nil)
	(dolist (arg template-list)
	  (setq 
	   inf-arg (if (and infinite-args?
			    (< template-list-length argument-index))
		       t nil)
	   eldocstr (concat eldocstr
			    ;;(prog2 (put-text-property 0 (length arg) 'face 'error arg) arg)
			    ;;(string= opcode-match (thing-at-point 'symbol))
			    ;; (string= opcode-match (thing-at-point 'symbol))
			    ;; (if (= indx 0)
			    ;; 	;;(string= arg opcode-match)
			    ;;   "" ", ")
			    ;; 
			    (when (string= arg opcode-match)
			      (put-text-property 0 (length arg) 'face
						 (list :foreground "#C70039"
						       :weight (if point-on-opcode?
								   'bold 'normal)) arg))
			    (if (or (and (= indx argument-index)
					 ;;(string= arg (car (last template-list)))
					 (not point-on-opcode?))
				    (and inf-arg (string= "[...]" arg)))
				(prog2 (put-text-property 0 (length arg) 'face '(:foreground "#A4FF00" :weight bold) arg)
				    arg)
			      arg)
			    (if (or (eq template-list-length list-index)
				    (string= arg opcode-match)
				    (string= opcode-match (nth (1+ list-index) template-list))
				    (string= "=" arg))
				" "
			      ", "))
	   indx (if (string= arg opcode-match) 1
		  (if (string= "=" arg)
		      indx
		    (if (> 0 indx)
			(1- indx)
		      (1+ indx))))
	   list-index (1+ list-index))) 
	eldocstr))))


(provide 'csound-eldoc)

