(setq inhibit-startup-message t)

(scroll-bar-mode -1)   ; Disable visible scrollbar
(tool-bar-mode -1)     ; Disable the toolbar
(tooltip-mode -1)      ; Disable tooltips
(set-fringe-mode 10)   ; Give some breathing room
(menu-bar-mode -1)     ; Disable the menu bar
(column-number-mode)   ; Enable column numbers mode
(global-display-line-numbers-mode 1)       ; Display line numbers
(setq display-line-numbers-type 'relative) ; Display relative line numbers
;;(setq scroll-margin 5)
(setq scroll-step 1)

;; Disable line numbers in the following modes
(add-hook 'term-mode-hook (lambda () (display-line-numbers-mode -1)))
(add-hook 'shell-mode-hook (lambda () (display-line-numbers-mode -1)))
(add-hook 'eshell-mode-hook (lambda () (display-line-numbers-mode -1)))
(add-hook 'org-mode-hook (lambda () (display-line-numbers-mode -1)))

(set-face-attribute 'default nil :font "Hack Nerd Font Mono" :height 150)
;; Set theme
;;(load-theme 'wombat)

;; Set ESC quit prompt
(global-set-key (kbd "<escape>") 'keyboard-escape-quit)

;; Init package source
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
			 ("org" . "https://orgmode.org/elpa/")
			 ("elpa" . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(use-package ivy
  :diminish
  :bind (("C-s" . swiper)
	 :map ivy-minibuffer-map
	 ("TAB" . ivy-alt-done)
	 ("C-l" . ivy-alt-done)
	 ("C-j" . ivy-next-line)
	 ("C-k" . ivy-previous-line)
	 :map ivy-switch-buffer-map
	 ("C-k" . ivy-previous-line)
	 ("C-l" . ivy-done)
	 ("C-d" . ivy-switch-buffer-kill)
	 :map ivy-reverse-i-search-map
	 ("C-k" . ivy-previous-line)
	 ("C-d" . ivy-reverse-i-search-kill))
  :config
  (ivy-mode 1))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(all-the-icons counsel doom-modeline doom-themes evil-collection
		   general helpful hydra ivy-rich magit projectile
		   treesit-auto)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(use-package swiper
  :after ivy)

(use-package counsel
  :bind (("M-x" . counsel-M-x)
	 ("C-x b" . counsel-ibuffer)
	 ("C-x C-f" . counsel-find-file)
	 :map minibuffer-local-map
	 ("C-r" . counsel-minibuffer-history))
  :after ivy
  :config
  (setq ivy-initial-inputs-alist nil) ; Don't start search with ^
  (counsel-mode 1))

;; After installing this package run: M-x all-the-icons-install-fonts
(use-package all-the-icons)

(use-package doom-modeline
  :init (doom-modeline-mode 1)
  :config ())

(add-to-list 'custom-theme-load-path "~/.config/emacs/themes/")
(use-package doom-themes
  :init (load-theme 'doom-everforest-hard t))

(use-package which-key
  :init (which-key-mode)
  :diminish which-key-mode
  :config
  (setq which-key-idle-delay 0.3))

(use-package ivy-rich
  :init
  (ivy-rich-mode 1))

(use-package helpful
  :custom
  (counsel-describe-function-function #'helpful-callable)
  (counsel-describe-variable-function #'helpful-variable)
  :bind
  ([remap describe-function] . counsel-describe-function)
  ([remap describe-command] . helpful-command)
  ([remap describe-variable] . counsel-describe-variable)
  ([remap describe-key] . helpful-key))

(use-package evil
  :init
  (setq evil-want-integration t)
  (setq evil-want-keybinding nil)
  (setq evil-want-C-u-scroll t)
  (setq evil-want-C-i-jump nil)
  :config
  (evil-mode 1)
  (define-key evil-insert-state-map (kbd "C-g") 'evil-normal-state)

  ;; Use visual line motions outside of visual-line-mode buffers
  (evil-global-set-key 'motion "j" 'evil-next-visual-line)
  (evil-global-set-key 'motion "k" 'evil-previous-visual-line)

  (evil-set-initial-state 'messages-buffer-mode 'normal)
  (evil-set-initial-state 'dashboard-mode 'normal)
  (setq evil-scroll-margin 4)
  (setq evil-scroll-preserve-screen-position t))
  
(use-package evil-collection
  :after evil
  :config
  (setq evil-collection-mode-list
	'(dired magit))
  (evil-collection-init))

(use-package hydra
  :ensure t
  :config
  (defhydra hydra-text-scale (:timeout 4)
    ("j" text-scale-increase "in")
    ("k" text-scale-decrease "out")
    ("f" nil "finsihed" :exit t)))

(use-package general
  :config
  (general-create-definer boenan/leader-keys
    :keymaps '(normal insert visual emacs)
    :prefix "SPC"
    :global-prefix "C-SPC")

  (general-def 'normal 'dired-mode-map
    "SPC" nil)

  (boenan/leader-keys
    :keymaps 'dired-mode-map
    "t" '(:ignore t :which-key "toggles")))

(with-eval-after-load 'hydra
  (boenan/leader-keys
    "b" '(counsel-ibuffer :which-key "ibuffer")
    "t" '(hydra-text-scale/body :which-key "scale text")
    "w w" '(mode-line-other-buffer :which-key "switch to last buffer")
    "s" '(save-buffer :which-key "save buffer")))

(use-package magit
  :config
  (evil-set-initial-state 'magit-status-mode 'normal)
  (evil-set-initial-state 'magit-diff-mode 'normal)
  (evil-set-initial-state 'magit-log-mode 'normal)
  (evil-set-initial-state 'magit-revision-mode 'normal))

(use-package projectile
  :ensure t
  :after evil
  :diminish projectile-mode
  :config (projectile-mode)
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :init
  (when (file-directory-p "~/projects")
    (setq projectile-project-search-path '("~/projects/boenan")))
  (setq projectile-switch-project-action #'projectile-dired)
  (projectile-discover-projects-in-search-path))

(use-package treesit-auto
  :ensure t
  :custom
  (treesit-auto-install 'prompt) ;; Prompts you to install if a grammar is missing
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))
