; describe-function "forward-char" RET other-window set-mark
; universal-argument 5 forward-word copy-region-as-kill other-window yank
; save-buffer save-buffers-kill-emacs
(execute-kbd-macro "\M-xdescribe-function\rforward-char\r\C-xo\C-@\C-u5\M-f\M-w\C-xo\C-y\C-x\C-s\C-x\C-c")
