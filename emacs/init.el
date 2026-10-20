;;; init.el -*- lexical-binding: t; -*-

;; Packages
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq use-package-always-ensure t)

;; Keep the Customize output of init.el and git)
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror)

;; Defaults
(use-package emacs
  :ensure nil
  :custom
  (make-backup-files nil)
  (create-lockfiles nil)
  (use-short-answers t)
  (ring-bell-function #'ignore)
  (display-line-numbers-type 'relative)
  :bind (("M-o"     . other-window)
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
  (windmove-default-keybindings))

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

;; Move lines
(use-package move-text
  :bind (("M-p" . move-text-up)
         ("M-n" . move-text-down)))

(use-package gruber-darker-theme
  :config
  (load-theme 'gruber-darker t))

