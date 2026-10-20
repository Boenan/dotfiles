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
  :config
  (global-display-line-numbers-mode 1)
  (recentf-mode 1)
  (savehist-mode 1)
  (save-place-mode 1)
  (global-auto-revert-mode 1)
  (electric-pair-mode 1))

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

(use-package gruber-darker-theme
  :config
  (load-theme 'gruber-darker t))

