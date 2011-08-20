;;; runlol.el --- Let Emacs and Runlol cooperate

;; Copyright (C) 2011 Bodil Stokke

;; Version 0.1
;; Keywords: runlol testing TDD
;; Author: Bodil Stokke <runlol@bodil.tv>
;; URL: http://github.com/bodil/runlol

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

;;; Commentary

;; Provides the following features:

;;  * Displays the current test status of a running Runlol instance in
;;    the Emacs modeline.

;;; Installation

;; Put this file somewhere in your load-path, and put the following in
;; your .emacs:

;;   (require 'runlol)

;;; Code:

(require 'json)

(defgroup runlol nil
  "Runlol interaction.")

(defcustom runlol-socket "~/.runlol.socket"
  "Location of the runlol socket."
  :type 'string
  :group 'runlol)

(defface runlol-green-face
  '((t (:background "green" :foreground "black" :box (:line-width 1 :color "grey75" :style released-button) :weight bold)))
  "Face for status display when tests are green."
  :group 'runlol)

(defface runlol-red-face
  '((t (:background "red" :foreground "white" :box (:line-width 1 :color "grey75" :style released-button) :bold t)))
  "Face for status display when tests are red."
  :group 'runlol)

(defun runlol--on-state (state)
  (if (eq state nil)
      (setq global-mode-string nil)
    (let ((failing (cdr (assoc 'failing (assoc 'tests state)))))
      (let ((modeline-text (if (= failing 0) " TESTS OK " (format " FAIL:% 3d " failing))))
        (setq global-mode-string
              (propertize modeline-text 'face
                          (if (= failing 0) 'runlol-green-face 'runlol-red-face)))))))

(defun runlol--update-state ()
  (if (not (file-exists-p (expand-file-name runlol-socket)))
      (runlol--on-state nil)
    (let ((runlol-buffer (get-buffer-create "*runlol-process*")))
      (with-current-buffer runlol-buffer
        (erase-buffer))
      (make-network-process :name "runlol-poller"
                            :family 'local
                            :remote (expand-file-name runlol-socket)
                            :buffer runlol-buffer
                            :nowait t
                            :sentinel (lambda (process msg)
                                        (if (string-match "connection broken by remote peer" msg)
                                            (runlol--on-state
                                             (json-read-from-string
                                              (with-current-buffer (get-buffer "*runlol-process*")
                                                (buffer-string))))))))))

(setq runlol--timer-failsafe nil)

(defun runlol-start-timer ()
  (runlol--update-state)
  (if (not runlol--timer-failsafe)
      (run-at-time "1 sec" nil 'runlol-start-timer)))

(runlol-start-timer)

(provide 'runlol)
