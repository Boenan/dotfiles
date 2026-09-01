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
