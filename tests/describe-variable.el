(describe-variable 'tab-width)
(other-window 1)
(set-mark (point))
(forward-word 6)
(copy-region-as-kill (mark) (point))
(other-window -1)
(yank)
(save-buffer)
(save-buffers-kill-emacs)
