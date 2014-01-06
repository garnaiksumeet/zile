; describe-variable "tab-width" RET other-window set-mark
; universal-argument 6 forward-word copy-region-as-kill other-window yank
; save-buffer save-buffers-kill-emacs
(execute-kbd-macro "\M-xdescribe-variable\rtab-width\r\C-xo\C-@\C-u6\M-f\M-w\C-xo\C-y\C-x\C-s\C-x\C-c")
