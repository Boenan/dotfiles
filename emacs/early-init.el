;;; early-init.el -*- lexical-binding: t; -*-
;; Start faster: delay garbage collection during startup.
(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook
	  (lambda () (setq gc-cons-threshold (* 16 1024 1024))))

(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)

(add-to-list 'default-frame-alist '(font . "Iosevka-15"))

(setq inhibit-startup-screen t)
