; describe-key \C-f other-window set-mark univeral-argument 11
; forward-word copy-region-as-kill other-window yank save-buffer save-buffers-kill-emacs
(execute-kbd-macro "\M-xdescribe-key\r\C-f\C-xo\C-@\C-u11\M-f\M-w\C-xo\C-y\C-x\C-s\C-x\C-c")
