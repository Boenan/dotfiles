;;; init.el -*- lexical-binding: t; -*-

;; Packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq use-package-always-ensure t)

;; Keep the Customize output of init.el and git)
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror)

(setq dired-dwim-target t)

;; Defaults
(defun my/other-window-only ()
  "Go to the other window and close all other windows."
  (interactive)
  (other-window 1)
  (delete-other-windows))

(defun my/browse-url-default-web-browser (url &rest _args)
  "Open URL in the desktop's default web browser.
xdg-open selects the program from the file type.  It opens the
XHTML preview of markdown-mode as text/xml, which can go to a
different browser.  If gtk-launch fails, for example in a container
that does not have the desktop file of the browser, use xdg-open."
  (let ((desktop (and (executable-find "xdg-settings")
                      (executable-find "gtk-launch")
                      (string-trim
                       (shell-command-to-string
                        "xdg-settings get default-web-browser 2>/dev/null")))))
    ;; gtk-launch starts the browser and exits.  Wait for it to get the
    ;; exit code.  No pty, so the browser does not get SIGHUP.
    (unless (and desktop (string-suffix-p ".desktop" desktop)
                 (eq 0 (call-process "gtk-launch" nil nil nil desktop url)))
      (browse-url-default-browser url))))

(use-package emacs
  :ensure nil
  :custom
  (make-backup-files nil)
  (create-lockfiles nil)
  (use-short-answers t)
  (ring-bell-function #'ignore)
  (display-line-numbers-type 'relative)
  (browse-url-browser-function #'my/browse-url-default-web-browser)
  :bind (("M-o"     . other-window)
         ("M-O"     . my/other-window-only)
         ("C-'"     . set-mark-command)
         ("C-x C-b" . ibuffer)
         ("C-x k"   . kill-current-buffer)
         ("M-/"     . hippie-expand)
         ("M-z"     . zap-up-to-char)
         ("M-u"     . upcase-dwim)
         ("M-l"     . downcase-dwim)
         ("M-c"     . capitalize-dwim)
         ("C-,"     . duplicate-dwim)
         ("C-c c"   . compile)
         ("C-c p"   . winner-undo)
         ("C-c n"   . winner-redo))
  :bind* (("M-<left>"  . left-word)
          ("M-<right>" . right-word))
  :config
  (global-display-line-numbers-mode 1)
  (recentf-mode 1)
  (savehist-mode 1)
  (save-place-mode 1)
  (global-auto-revert-mode 1)
  (electric-pair-mode 1)
  (delete-selection-mode 1)
  (repeat-mode 1)
  (winner-mode 1)
  (windmove-default-keybindings)
  ;; fixed-pitch uses the "Monospace" font (Noto Sans Mono), which is
  ;; larger than Iosevka.  Markdown code uses fixed-pitch.  Use Iosevka.
  (set-face-attribute 'fixed-pitch nil :family "Iosevka")
  ;; Iosevka has no Nerd Font icons (eza --icons, starship).  Show the
  ;; private use areas with the Nerd Font symbols.
  (dolist (range '((#xe000 . #xf8ff) (#xf0000 . #xfffff)))
    (set-fontset-font t range "Symbols Nerd Font Mono")))

(use-package which-key :ensure nil :config (which-key-mode 1))

(use-package completion-preview :ensure nil :hook (prog-mode . completion-preview-mode))

(use-package editorconfig :ensure nil :config (editorconfig-mode 1))

(use-package vertico :init (vertico-mode 1))

(use-package orderless
  :custom (completion-styles '(orderless basic)))

(use-package marginalia :init (marginalia-mode 1))

(use-package consult :bind (("C-x b" . consult-buffer)
			    ("M-s r" . consult-ripgrep)))

(use-package eglot :ensure nil
  :hook ((rust-ts-mode python-ts-mode) . eglot-ensure))

(use-package treesit-auto
  :custom
  (treesit-auto-install 'prompt)
  (treesit-auto-langs '(yaml rust python bash json toml dockerfile))
  :config
  (global-treesit-auto-mode 1))

;; YAML
(add-to-list 'auto-mode-alist '("\\.ya?ml\\'" . yaml-ts-mode))

;; yaml-ts-mode has no indent function.  TAB moves to the next tab
;; stop, and the tab stops are tab-width (8) columns apart.  Use 2.
(add-hook 'yaml-ts-mode-hook (lambda () (setq-local tab-width 2)))
;; Move by YAML keys with the tree-sitter tree.  Each "key: value" is a
;; block_mapping_pair node.
(defun my/yaml--pair-p (node)
  (equal (treesit-node-type node) "block_mapping_pair"))

(defun my/yaml--pair-at-point ()
  "Return the innermost key/value pair at the indentation of this line."
  (save-excursion
    (back-to-indentation)
    (treesit-parent-until (treesit-node-at (point)) #'my/yaml--pair-p t)))

(defun my/yaml-up-key ()
  "Move to the parent key.
On a line inside a value, such as a list item, move to the key of that value."
  (interactive)
  (let* ((pair (my/yaml--pair-at-point))
         (target (if (and pair (< (treesit-node-start pair) (line-beginning-position)))
                     pair
                   (and pair (treesit-parent-until pair #'my/yaml--pair-p)))))
    (if target
        (goto-char (treesit-node-start target))
      (message "No parent key"))))

(defun my/yaml--sibling-key (next)
  (let ((node (my/yaml--pair-at-point)))
    (while (and node
                (setq node (if next
                               (treesit-node-next-sibling node t)
                             (treesit-node-prev-sibling node t)))
                (not (my/yaml--pair-p node))))
    (if node
        (goto-char (treesit-node-start node))
      (message "No %s key at this level" (if next "next" "previous")))))

(defun my/yaml-next-key ()
  "Move to the next key at the same level."
  (interactive)
  (my/yaml--sibling-key t))

(defun my/yaml-prev-key ()
  "Move to the previous key at the same level."
  (interactive)
  (my/yaml--sibling-key nil))

(with-eval-after-load 'yaml-ts-mode
  (keymap-set yaml-ts-mode-map "C-M-u" #'my/yaml-up-key)
  (keymap-set yaml-ts-mode-map "C-M-n" #'my/yaml-next-key)
  (keymap-set yaml-ts-mode-map "C-M-p" #'my/yaml-prev-key))

;; YAML with Go templates (Helm).  The YAML tree-sitter parser fails on
;; {{ }}, so yaml-ts-mode stops highlighting after the first template.
;; Use the regexp-based yaml-mode and add the template highlighting.
;; treesit-auto remaps yaml-mode to yaml-ts-mode, so use a derived mode.
;; go-template-mode opens the .tpl, .tmpl and .gotmpl files.
(use-package yaml-mode)

(use-package go-template-helper-mode
  :hook (my/yaml-template-mode . go-template-helper-mode))

(define-derived-mode my/yaml-template-mode yaml-mode "YAML-Template"
  "Major mode for YAML files with Go templates, such as Helm templates.")

(add-to-list 'auto-mode-alist
             '("/templates/.*\\.ya?ml\\'" . my/yaml-template-mode))

;; Containerfile
(add-to-list 'auto-mode-alist '("/[Cc]ontainerfile\\(?:\\..*\\)?\\'" . dockerfile-ts-mode))

;; Markdown
(use-package markdown-mode
  :custom
  ;; Make headings larger than the body text.
  (markdown-header-scaling t)
  ;; Color code blocks with the major mode of their language.
  (markdown-fontify-code-blocks-natively t)
  ;; Preview GitHub Markdown as a full HTML page.  The pandoc
  ;; template adds the page styles and the code colors.
  (markdown-command '("pandoc" "--from=gfm" "--to=html5" "--standalone"
                      "--metadata=pagetitle=Markdown Preview"
                      "--variable=mainfont:system-ui, sans-serif"
                      "--variable=monofont:Iosevka, monospace"
                      "--variable=maxwidth:50em"
                      "--variable=header-includes:<style>
code { font-size: 0.95em; }
:not(pre) > code { background: #eff1f3; padding: 0.1em 0.3em; border-radius: 4px; }
pre { background: #f0f2f4; border: 1px solid #d8dde3; padding: 1em; border-radius: 6px; }
</style>")))

;; Terraform
(use-package terraform-mode
  :hook (terraform-mode . eglot-ensure))

;; Git
(use-package magit
  :bind ("C-x g" . magit-status))

;; Terminal
(use-package ghostel
  :custom
  ;; Same shell as Ghostty: fish as a login, interactive shell.
  (ghostel-shell (list (or (executable-find "fish") "fish")
                       "--login" "--interactive"))
  ;; Emacs shows Nerd Font icons in one column only.  Put more space
  ;; between the eza icons and the file names.
  (ghostel-environment '("EZA_ICON_SPACING=2"))
  :bind ("C-x m" . ghostel)
  :config
  ;; The gruber-darker theme sets only the term-color faces, not the
  ;; ansi-color faces.  Use the term-color faces for the normal and
  ;; the bright colors.
  (require 'term)
  (dolist (color '(black red green yellow blue magenta cyan white))
    (dolist (prefix '("" "bright-"))
      (set-face-attribute (intern (format "ghostel-color-%s%s" prefix color))
                          nil :inherit (intern (format "term-color-%s" color)))))
  (ghostel-sync-theme))

;; Agents
(use-package agent-shell
  :bind (:map agent-shell-mode-map
         ("C-c TAB" . agent-shell-cycle-session-mode))
  :config
  ;; C-<tab> is hard to press on the Voyager.  Cycle modes with C-c TAB.
  (with-eval-after-load 'agent-shell-viewport
    (keymap-set agent-shell-viewport-view-mode-map "C-c TAB"
                #'agent-shell-viewport-cycle-session-mode)
    (keymap-set agent-shell-viewport-edit-mode-map "C-c TAB"
                #'agent-shell-viewport-cycle-session-mode))
  ;; Preselect Claude Code in the agent picker.
  (setq agent-shell-preferred-agent-config '(preselect . claude-code))
  ;; Hide the Downloads and temp shell choices.
  (setq agent-shell-session-choices-function
        (lambda (choices)
          (seq-remove (lambda (choice)
                        (memq (cdr choice) '(:downloads-shell :temp-shell)))
                      choices)))
  ;; Send a desktop notification when an agent needs the user.
  (defun my/agent-shell-notify (buffer body)
    "Show BODY for agent-shell BUFFER, unless the user is looking at BUFFER.
The user is looking at BUFFER when Emacs has focus and the selected
window shows BUFFER or its viewport."
    (unless (let ((current (window-buffer (selected-window))))
              (and (eq (frame-focus-state) t)
                   (eq buffer
                       (or (and (fboundp 'agent-shell-viewport--shell-buffer)
                                (agent-shell-viewport--shell-buffer current))
                           current))))
      (start-process "agent-shell-notify" nil
                     "notify-send" "--app-name=Emacs"
                     (buffer-name buffer) body)))
  (defun my/agent-shell-subscribe-notifications ()
    (let ((buffer (current-buffer)))
      (agent-shell-subscribe-to
       :shell-buffer buffer
       :event 'turn-complete
       :on-event (lambda (_event)
                   (my/agent-shell-notify buffer "Task is complete")))
      (agent-shell-subscribe-to
       :shell-buffer buffer
       :event 'permission-request
       :on-event (lambda (_event)
                   (my/agent-shell-notify buffer "Agent needs permission")))))
  (add-hook 'agent-shell-mode-hook #'my/agent-shell-subscribe-notifications)
  ;; Emacs 30 has no `system-sleep' library.  Give agent-shell the two
  ;; functions it uses, so it blocks sleep while an agent is busy.
  (unless (locate-library "system-sleep")
    (defun system-sleep-block-sleep (&optional why _allow-display-sleep)
      (make-process :name "agent-shell-inhibit"
                    :command (list "systemd-inhibit" "--what=idle:sleep" "--who=Emacs"
                                   (concat "--why=" (or why "Emacs"))
                                   "sleep" "infinity")
                    :noquery t))
    (defun system-sleep-unblock-sleep (token)
      (when (process-live-p token)
        (delete-process token)))))

;; Move lines
(use-package move-text
  :bind (("M-p" . move-text-up)
         ("M-n" . move-text-down)))

;; Multiple cursors
(use-package multiple-cursors
  :bind (("C-S-c"       . mc/edit-lines)
         ("C->"         . mc/mark-next-like-this)
         ("C-<"         . mc/mark-previous-like-this)
         ("C-c C-<"     . mc/mark-all-like-this)
         ("C-\""        . mc/skip-to-next-like-this)
         ("C-:"         . mc/skip-to-previous-like-this)))

(use-package gruber-darker-theme
  :config
  (load-theme 'gruber-darker t)
  ;; The bar has the buffer color, so the pills stand out from it.
  (dolist (face '(mode-line mode-line-inactive))
    (set-face-background face "#181818")))

;; Mode line: show each group of information as a separate rounded pill.
;; Minions puts the minor modes in one menu, so the modes pill stays short.
(use-package minions
  :demand t
  :custom (minions-mode-line-delimiters '("" . "")))

(defface my/mode-line-pill '((t :background "#282828"))
  "Face for the text of a mode line pill.")

(require 'svg)

(defvar my/mode-line-pill-ends nil
  "Cache of the pill end strings.  The keys are (SIDE . HEIGHT).")

(defun my/mode-line-pill-end (side)
  "Return the round end of a pill as a string.  SIDE is `left' or `right'.
Font glyphs do not fill the line height, so use an image with the
height of the line.  Without SVG support, return a plain space."
  (let* ((height (frame-char-height))
         (key (cons side height)))
    (or (alist-get key my/mode-line-pill-ends nil nil #'equal)
        (setf (alist-get key my/mode-line-pill-ends nil nil #'equal)
              (if (not (image-type-available-p 'svg))
                  (propertize " " 'face 'my/mode-line-pill)
                (let* ((width (ceiling height 2))
                       (svg (svg-create width height))
                       (font (font-info (face-font 'mode-line))))
                  (svg-rectangle svg 0 0 width height :fill "#181818")
                  (svg-circle svg (if (eq side 'left) width 0)
                              (/ height 2.0) (/ height 2.0) :fill "#282828")
                  ;; Align the image with the font: the top of the
                  ;; image is at the top of the line.
                  (propertize " " 'display
                              (svg-image svg :ascent (round (* 100.0 (aref font 8))
                                                            height)))))))))

(defun my/mode-line-pill (spec)
  "Return the mode line construct SPEC as a pill, or nil if it is empty."
  (let ((text (string-trim (format-mode-line spec))))
    (unless (string-empty-p text)
      ;; The mode line reads the result of :eval again, so escape %.
      (setq text (replace-regexp-in-string "%" "%%" text t t))
      (add-face-text-property 0 (length text) 'my/mode-line-pill t text)
      (concat (my/mode-line-pill-end 'left) text
              (my/mode-line-pill-end 'right) " "))))

(setq-default mode-line-format
              '("%e" mode-line-front-space
                (:eval (my/mode-line-pill
                        '("" mode-line-mule-info mode-line-client
                          mode-line-modified mode-line-remote
                          mode-line-window-dedicated)))
                (:eval (my/mode-line-pill mode-line-buffer-identification))
                (:eval (my/mode-line-pill mode-line-position))
                (:eval (my/mode-line-pill '(vc-mode vc-mode)))
                mode-line-format-right-align
                (:eval (my/mode-line-pill minions-mode-line-modes))
                (:eval (my/mode-line-pill mode-line-misc-info))))

(use-package ek9
  :vc (:url "https://github.com/Boenan/ek9" :rev "0.1.2"))
