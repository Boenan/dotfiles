;;; init.el -*- lexical-binding: t; -*-

;; Packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq use-package-always-ensure t)

;; Keep the Customize output of init.el and git)
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror)

;; Defaults
(defun my/other-window-only ()
  "Go to the other window and close all other windows."
  (interactive)
  (other-window 1)
  (delete-other-windows))

(use-package emacs
  :ensure nil
  :custom
  (make-backup-files nil)
  (create-lockfiles nil)
  (use-short-answers t)
  (ring-bell-function #'ignore)
  (display-line-numbers-type 'relative)
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

(use-package gruber-darker-theme
  :config
  (load-theme 'gruber-darker t))

(package-vc-install "https://github.com/Boenan/ek9")
