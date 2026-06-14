;; ==========================================
;; 1. SYSTEM DEFAULTS & INTERFACE
;; ==========================================
(setq inhibit-startup-screen t)         ; Disable welcome screen
(menu-bar-mode -1)                      ; Disable top menu bar
(tool-bar-mode -1)                      ; Disable graphical icon bar
(setq global-hl-line-mode t)            ; Highlight current line (set cursorline)

;; Line Numbers (set number, set relativenumber)
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative) 

;; Scrolling (set scrolloff=8)
(setq scroll-margin 8
      scroll-conservatively 101)        ; Smooth scrolling performance

;; ==========================================
;; 2. PACKAGE MANAGER SETUP
;; ==========================================
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t)

;; ==========================================
;; 3. VIM EMULATION (EVIL MODE) & LEADER
;; ==========================================
(use-package evil
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-undo-system 'undo-redo)     ; Modern Vim undo/redo setup
  :config
  (evil-mode 1)
  
  ;; Set Leader Key (let mapleader = " ")
  (evil-set-leader 'normal (kbd "SPC"))
  
  ;; Quick Escape Chord (inoremap jk <Esc>)
  (use-package evil-escape
    :config
    (evil-escape-mode 1)
    (setq-default evil-escape-key-sequence "jk")
    (setq-default evil-escape-delay 0.15)))

(use-package evil-collection
  :after evil
  :config
  (evil-collection-init))

;; ==========================================
;; 4. TABS, INDENTATION & LSP LANGUAGES
;; ==========================================
(setq-default indent-tabs-mode nil)     ; set expandtab
(setq-default tab-width 4)              ; set tabstop=4
(electric-pair-mode 1)                  ; Auto-close brackets () [] {}

;; Filetype Hooks (augroup filetype_indent)
(defun my/set-two-space-indent ()
  (setq-local tab-width 2))

(defun my/set-physical-tabs ()
  (setq-local indent-tabs-mode t)       ; set noexpandtab
  (setq-local tab-width 4))

;; YAML, HTML, CSS, Markdown -> 2 spaces
(add-hook 'yaml-mode-hook #'my/set-two-space-indent)
(add-hook 'html-mode-hook #'my/set-two-space-indent)
(add-hook 'css-mode-hook #'my/set-two-space-indent)
(add-hook 'markdown-mode-hook #'my/set-two-space-indent)

;; Makefiles require real tabs
(add-hook 'makefile-mode-hook #'my/set-physical-tabs)

;; Containerfile Association (augroup containerfile_detection)
(add-to-list 'auto-mode-alist '("Containerfile\\'" . dockerfile-mode))
(add-to-list 'auto-mode-alist '("Containerfile\\..*\\'" . dockerfile-mode))
(add-to-list 'auto-mode-alist '("containerfile\\'" . dockerfile-mode))
(add-to-list 'auto-mode-alist '("containerfile\\..*\\'" . dockerfile-mode))

;; ==========================================
;; 5. SEARCH & FILE MANAGEMENT
;; ==========================================
(setq case-fold-search t)               ; set ignorecase
(setq evil-smartcase t)                 ; set smartcase
(setq make-backup-files nil)            ; set nobackup
(setq auto-save-default nil)            ; set noswapfile

;; Persistent Undo history (if has('undofile'))
(use-package undo-fu-session
  :config
  (global-undo-fu-session-mode))

;; ==========================================
;; 6. WAYLAND CLIPBOARD COOPERATION
;; ==========================================
;; Intercept Emacs kill/yank rings and pipe them through wl-copy and wl-paste
(setq select-enable-clipboard t)

(defun my/wl-copy (text)
  (let ((process-connection-type nil))
    (let ((proc (start-process "wl-copy" nil "wl-copy")))
      (process-send-string proc text)
      (process-send-eof proc))))

(defun my/wl-paste ()
  (if (and (executable-find "wl-paste")
           (not (string= (buffer-name) " *Echo Area*")))
      (shell-command-to-string "wl-paste --no-newline")))

;; Bind these functions to Emacs' clipboard hooks
(setq interprogram-cut-function 'my/wl-copy)
(setq interprogram-paste-function 'my/wl-paste)
;; =========================================
;; ==========================================
;; 7. HIGH-RESOLUTION TYPOGRAPHY & THEME
;; ==========================================
(defun my/set-font ()
  (set-frame-font "InputMono Nerd Font 13" nil t))
(my/set-font)
(add-hook 'server-after-make-frame-hook 'my/set-font)

;; Cloned Everforest theme path setup
(add-to-list 'custom-theme-load-path "~/.config/emacs/everforest-theme")
(load-theme 'everforest-hard-dark t)

;; Transparency Tweak (function! GiveMeTransparency())
(defun my/apply-transparency ()
  (set-face-background 'default "unspecified-bg")
  (set-face-background 'line-number "unspecified-bg")
  (set-face-background 'line-number-current-line "unspecified-bg"))

;; Force terminal transparency execution
(unless (display-graphic-p)
  (my/apply-transparency))
