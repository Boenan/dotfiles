;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-material-dark)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relrtive line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(setq projectile-project-search-path '("~/projects/boenan/"))

(after! projectile
  (setq projectile-switch-project-action #'projectile-dired))

(setq vterm-shell (executable-find "fish"))
(setq shell-file-name (executable-find "fish"))
(setq-hook! 'vterm-mode-hook vterm-shell (executable-find "fish"))
(setq dired-listing-switches "-agho --group-directories-first")
(setq doom-font (font-spec :family "Hack Nerd Font" :size 12))
(add-hook! '(yaml-mode-hook yaml-ts-mode-hook) #'indent-bars-mode)

;; turn off automatic completion popups in YAML files
(add-hook! '(yaml-mode-hook yaml-ts-mode-hook)
  (setq-local corfu-auto nil))


(after! org
       (doom-themes-org-config)
       (setq org-hide-emphasis-markers t
             org-hide-leading-stars t
             org-pretty-entities t))

;; Comment code
(map! :leader "v c" #'comment-line)

;; Smart tab: when point sits inside a delimiter pair, jump past the next
;; closing delimiter or quote on the current line. Otherwise fall back to the
;; normal TAB behaviour (indentation / completion) so editing still works.
(defun my/smart-tab ()
  "Jump past the next closing delimiter or quote on the current line.
Stops after any of: ) ] } > \" '  If none is found ahead on the line,
run the usual TAB command instead."
  (interactive)
  (let ((eol (line-end-position))
        (target nil))
    (when (< (point) eol)  ; only search if not already at end of line
      (save-excursion
        (when (re-search-forward "[])}>\"']" eol t)
          (setq target (point)))))  ; point lands just after the delimiter
    (if target
        (goto-char target)
      (indent-for-tab-command))))

(define-key evil-insert-state-map (kbd "TAB") #'my/smart-tab)

;; Normal-mode indenting: TAB shifts the current line right, Shift-TAB left.
;; Uses Evil's built-in line-wise shift commands (same as >> and <<), which
;; respect shiftwidth/tab-width and accept a count.
;; In visual mode, shift the whole selection and keep it selected so you can
;; repeat with TAB / Shift-TAB.
(map! :n "<tab>"     #'evil-shift-right-line
      :n "<backtab>" #'evil-shift-left-line
      :v "<tab>"     #'+evil/shift-right
      :v "<backtab>" #'+evil/shift-left)

(use-package! exec-path-from-shell
  :config
  (setq exec-path-from-shell-arguments '("-l"))
  (exec-path-from-shell-initialize))

(setq lsp-disabled-clients '(omnisharp csharp-roslyn))

(after! lsp-mode
  (setq lsp-rust-analyzer-server-command '("rust-analyzer")))

;; Ensure rust-analyzer supports standalone files by clearing the project root.
(defun my/rust-analyzer-standalone-hook ()
  (when (and (eq major-mode 'rust-mode)
             (not (locate-dominating-file default-directory "Cargo.toml")))
    (setq-local lsp-session-folders-blacklist '(".*"))))

(add-hook 'lsp-before-initialize-hook #'my/rust-analyzer-standalone-hook)

(add-hook 'rust-mode-hook #'lsp-deferred)

(set-company-backend! 'rust-mode '(company-capf))
(set-company-backend! 'rustic-mode '(company-capf))

;; Browser: always hand URLs to Firefox instead of guessing via xdg-open.
;; This covers `SPC o b' (open current file), `SPC s o' (online search),
;; org/markdown link following and every other `browse-url' caller.
(setq browse-url-browser-function #'browse-url-firefox
      browse-url-firefox-program (or (executable-find "firefox") "firefox")
      browse-url-firefox-new-window-is-tab t)

;; `SPC o B' -- open the URL at point, or prompt for one, in Firefox.
(map! :leader
      (:prefix "o"
       :desc "Browse URL in Firefox" "B" #'browse-url))

;; consult-gh -- the GitHub CLI (`gh') wrapped in a consult interface. Requires
;; `gh' on PATH and an authenticated account (`gh auth login' in the terminal).
(use-package! consult-gh
  :commands (consult-gh
             consult-gh-transient
             consult-gh-search-repos
             consult-gh-search-issues
             consult-gh-search-prs
             consult-gh-search-code
             consult-gh-issue-list
             consult-gh-pr-list
             consult-gh-find-file
             consult-gh-notifications
             consult-gh-dashboard
             consult-gh-orgs
             consult-gh-favorite-repos
             consult-gh-repo-clone
             consult-gh-repo-fork
             consult-gh-auth-switch
             consult-gh-run-list
             consult-gh-workflow-list
             consult-gh-release-list
             consult-gh-commit-list)
  :config
  ;; Orgs/users whose repos `consult-gh-favorite-repos' lists. Add any orgs you
  ;; work in alongside your own handle.
  (setq consult-gh-favorite-orgs-list '("Boenan"))

  ;; Clone into the same tree projectile already searches.
  (setq consult-gh-default-clone-directory "~/projects/boenan/")

  ;; Previews hit the GitHub API, so ask for them explicitly with `M-.' instead
  ;; of firing one off on every candidate you scroll past.
  (setq consult-gh-show-preview t
        consult-gh-preview-key "M-.")

  ;; Offer the repo of the current project first when a command asks for one.
  (setq consult-gh-prioritize-local-folder 'suggest)

  ;; Render issues/PRs/READMEs as GitHub-flavoured markdown (`org-mode' also
  ;; works if you prefer reading them as org).
  (setq consult-gh-preview-major-mode 'gfm-mode)

  ;; In-buffer keys for the view buffers: `gr' to refresh, `gc' to comment,
  ;; `gm' to merge a PR, etc.
  (consult-gh-enable-default-keybindings)

  ;; Embark actions (`C-;') on repos, issues, PRs and code results.
  (require 'consult-gh-embark)
  (consult-gh-embark-mode +1)

  ;; Icons in the minibuffer.
  (require 'consult-gh-nerd-icons)
  (consult-gh-nerd-icons-mode +1))

;; `SPC g h' -- GitHub. `SPC g h h' opens the magit-style dispatch menu.
(map! :leader
      (:prefix ("g" . "git")
       (:prefix ("h" . "github")
        :desc "Dispatch menu"        "h" #'consult-gh-transient
        :desc "Search repos"         "r" #'consult-gh-search-repos
        :desc "Favorite repos"       "R" #'consult-gh-favorite-repos
        :desc "List issues"          "i" #'consult-gh-issue-list
        :desc "Search issues"        "I" #'consult-gh-search-issues
        :desc "List pull requests"   "p" #'consult-gh-pr-list
        :desc "Search pull requests" "P" #'consult-gh-search-prs
        :desc "Search code"          "c" #'consult-gh-search-code
        :desc "Find file in repo"    "f" #'consult-gh-find-file
        :desc "Notifications"        "n" #'consult-gh-notifications
        :desc "Dashboard"            "d" #'consult-gh-dashboard
        :desc "Browse orgs"          "o" #'consult-gh-orgs
        :desc "Action runs"          "a" #'consult-gh-run-list
        :desc "Workflows"            "w" #'consult-gh-workflow-list
        :desc "Releases"             "l" #'consult-gh-release-list
        :desc "Commits"              "m" #'consult-gh-commit-list
        :desc "Clone repo"           "C" #'consult-gh-repo-clone
        :desc "Fork repo"            "F" #'consult-gh-repo-fork
        :desc "Switch account"       "s" #'consult-gh-auth-switch)))

;;; Markdown live preview ------------------------------------------------------
;; `markdown-live-preview-mode' (built into markdown-mode) renders the buffer to
;; HTML with pandoc and shows it in an eww window beside the source. Everything
;; stays inside Emacs -- no browser, no network, no API limits.
;;
;; Requires pandoc:  sudo dnf install pandoc-cli

;; Doom's pandoc backend always passes `-f markdown'. Prefer GitHub-flavoured
;; input in `gfm-mode' (READMEs, issue drafts) so task lists, strikethrough and
;; tables render the way GitHub renders them.
(defun +markdown-compile-pandoc-gfm (beg end output-buffer)
  "Compile markdown with pandoc, using gfm input in `gfm-mode'.
Returns pandoc's exit code, or nil if pandoc isn't installed."
  (when (executable-find "pandoc")
    (call-process-region beg end "pandoc" nil output-buffer nil
                         "-f" (if (eq major-mode 'gfm-mode) "gfm" "markdown")
                         "-t" "html"
                         "--mathjax"
                         ;; Skip pandoc's own highlighting: it wraps every line
                         ;; in an <a> anchor, and we re-fontify with the real
                         ;; major mode below anyway.
                         "--no-highlight")))

(after! markdown-mode
  (add-to-list '+markdown-compile-functions #'+markdown-compile-pandoc-gfm)

  (setq markdown-live-preview-window-function #'markdown-live-preview-window-eww
        ;; Clean up the exported .html when the preview is turned off.
        markdown-live-preview-delete-export 'delete-on-destroy))

;; Hide markup by default, so `**bold**' reads as bold and links collapse to
;; their text while you edit. `SPC m t m' toggles it back per buffer.
(add-hook! '(markdown-mode-hook gfm-mode-hook)
  (defun +markdown-hide-markup-h ()
    (markdown-toggle-markup-hiding 1)))

;; eww gives <pre> no face at all, so code blocks in the preview come out in the
;; proportional body font, indistinguishable from prose. Re-fontify them with
;; the real major mode -- pandoc tags them `class="sourceCode rust"', which
;; `shr-tag-pre-highlight' knows how to read -- and set them on a block
;; background so they read as code.
(defface +markdown-preview-code-block
  '((t :inherit (markdown-code-face fixed-pitch) :extend t))
  "Face applied to code blocks rendered by eww.
Inherits the theme's markdown code background, falling back to plain
fixed-pitch where the theme sets none."
  :group '+markdown)

(defvar +markdown-preview-code-generic-classes
  '("sourcecode" "highlight" "numberlines" "code" "pre" "src" "example")
  "Class tokens that name no language and should be skipped.")

(defun +markdown-preview--code-mode (pre)
  "Return the major mode named by PRE's class/lang attributes, or nil."
  (let* ((code (car (dom-by-tag pre 'code)))
         (tokens (split-string
                  (mapconcat (lambda (attr) (or attr ""))
                             (list (dom-attr pre 'class) (dom-attr pre 'lang)
                                   (dom-attr code 'class) (dom-attr code 'lang))
                             " ")
                  "[ \t\n]+" t)))
    (cl-loop for token in tokens
             for name = (downcase (replace-regexp-in-string
                                   "\\`\\(?:language-\\|lang-\\|src-\\|sh_\\)" "" token))
             unless (member name +markdown-preview-code-generic-classes)
             thereis (cl-loop for suffix in '("-mode" "-ts-mode")
                              for mode = (intern-soft (concat name suffix))
                              when (and mode (fboundp mode)) return mode))))

(defun +markdown-preview--fontify (code mode)
  "Return CODE fontified as MODE, or nil if that fails."
  (with-demoted-errors "Code block fontification failed: %S"
    (with-temp-buffer
      ;; This text came from rendered HTML -- keep modes in untrusted mode.
      (when (boundp 'untrusted-content)
        (setq-local untrusted-content t))
      (insert code)
      (delay-mode-hooks (funcall mode))
      (font-lock-ensure)
      (buffer-string))))

(defun +shr-tag-pre-code-block (pre)
  "Render PRE as a syntax-highlighted code block.
eww applies no face to <pre>, so code otherwise renders in the proportional
body font. Pull the text straight out of the DOM (never `shr-generic', which
needs shr's markers and breaks on anchors inside <pre>), fontify it with the
major mode the class attribute names, and give it a block background."
  (let ((code (dom-texts pre ""))
        (mode (+markdown-preview--code-mode pre))
        start)
    (shr-ensure-newline)
    (setq start (point))
    (insert (or (and mode (+markdown-preview--fontify code mode)) code))
    (shr-ensure-newline)
    (add-face-text-property start (point) '+markdown-preview-code-block 'append)))

;; Inline `code' has the same problem in reverse: shr does give it a face, but
;; `shr-code' is only `:inherit fixed-pitch'. With no `doom-variable-pitch-font'
;; set, fixed- and variable-pitch both resolve to Hack Nerd Font, so inline code
;; comes out identical to the prose around it. Colour it instead of relying on
;; a font contrast that isn't there.
(defface +markdown-preview-inline-code
  '((t :inherit (markdown-inline-code-face fixed-pitch)))
  "Face applied to inline <code> rendered by eww."
  :group '+markdown)

(defun +shr-tag-code-inline (dom)
  "Render inline <code> DOM so it stands out from surrounding text.
Safe to use `shr-generic' here: unlike a code block, this runs in the real
render buffer where shr's markers are valid."
  (let ((start (point)))
    (shr-generic dom)
    ;; Prepend, not append: shr already put `shr-text' (variable-pitch) on this
    ;; run, and the first face in the list wins, so ours has to come first for
    ;; its fixed-pitch family to survive.
    (add-face-text-property start (point) '+markdown-preview-inline-code)))

(after! shr
  ;; <code> inside <pre> never reaches this: `+shr-tag-pre-code-block' pulls its
  ;; text straight from the DOM rather than recursing through shr.
  (setf (alist-get 'pre shr-external-rendering-functions) #'+shr-tag-pre-code-block
        (alist-get 'code shr-external-rendering-functions) #'+shr-tag-code-inline))

;; Preview lands in a persistent half-width window on the right. `:quit nil'
;; keeps ESC from dismissing it, `:select nil' keeps point in the source buffer.
(set-popup-rule! "^\\*eww\\*"
  :side 'right :width 0.5 :select nil :quit nil :ttl nil :modeline t)

;; Out of the box the preview only refreshes on save. Re-export when you pause
;; typing instead, so it tracks unsaved edits. markdown-mode restores the
;; preview window's scroll position on each export, so this doesn't jump around.
(defvar +markdown-live-preview-idle-delay 0.6
  "Seconds of idle time before the live preview re-renders.")

(defvar +markdown-live-preview--timer nil
  "Shared idle timer driving `+markdown-live-preview--maybe-export'.")

(defvar-local +markdown-live-preview--last-tick nil
  "Value of `buffer-chars-modified-tick' at the last export.")

(defun +markdown-live-preview-export-quietly ()
  "Re-render the live preview without disturbing the source buffer.
`markdown-live-preview-export' delegates to `markdown-export', which -- when
the source buffer is modified -- erases it, reinserts its contents and calls
`save-buffer'. That is fine on save, but driving it from a timer would save
the file on every keystroke pause and shred the undo history. This renders
straight into the preview file instead. Returns the preview buffer."
  (let* ((cur-buf (current-buffer))
         (export-file (markdown-live-preview-get-filename))
         (window-data (markdown-live-preview-window-serialize
                       markdown-live-preview-buffer))
         ;; Render the whole buffer even if a region happens to be active
         ;; (e.g. evil visual state), which `markdown' would otherwise honour.
         (transient-mark-mode nil)
         (html-buf (markdown-standalone " *markdown-live-preview-html*")))
    (when export-file
      (with-current-buffer html-buf
        (write-region (point-min) (point-max) export-file nil 'silent))
      (kill-buffer html-buf)
      (save-window-excursion
        (let ((output-buffer (funcall markdown-live-preview-window-function
                                      export-file)))
          (with-current-buffer output-buffer
            (setq markdown-live-preview-source-buffer cur-buf)
            (add-hook 'kill-buffer-hook
                      #'markdown-live-preview-remove-on-kill t t))
          (setq markdown-live-preview-buffer output-buffer)))
      (mapc #'markdown-live-preview-window-deserialize window-data)
      markdown-live-preview-buffer)))

(defun +markdown-live-preview--maybe-export ()
  "Re-export the live preview if this buffer's text changed since last time."
  (when (bound-and-true-p markdown-live-preview-mode)
    (let ((tick (buffer-chars-modified-tick)))
      (unless (eql tick +markdown-live-preview--last-tick)
        (setq +markdown-live-preview--last-tick tick)
        (with-demoted-errors "Markdown live preview: %S"
          (+markdown-live-preview-export-quietly))))))

(defun +markdown-live-preview-toggle-timer-h ()
  "Start the idle timer with the first preview, stop it with the last."
  (if (bound-and-true-p markdown-live-preview-mode)
      (unless +markdown-live-preview--timer
        (setq +markdown-live-preview--timer
              (run-with-idle-timer +markdown-live-preview-idle-delay t
                                   #'+markdown-live-preview--maybe-export)))
    (setq +markdown-live-preview--last-tick nil)
    (unless (cl-some (lambda (buf)
                       (buffer-local-value 'markdown-live-preview-mode buf))
                     (buffer-list))
      (when +markdown-live-preview--timer
        (cancel-timer +markdown-live-preview--timer)
        (setq +markdown-live-preview--timer nil)))))

(add-hook 'markdown-live-preview-mode-hook #'+markdown-live-preview-toggle-timer-h)

;; `SPC m l' -- toggle the preview. Doom already owns `p' (one-shot preview),
;; `e' (export), `o' (open externally) and the `SPC m t' toggle prefix.
(map! :map (markdown-mode-map gfm-mode-map)
      :localleader
      :desc "Live preview" "l" #'markdown-live-preview-mode)
