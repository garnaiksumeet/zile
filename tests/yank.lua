(set_mark (point))
(forward_line 2)
(kill_region (point) (mark))
(forward_line 3)
(yank)
(save_buffer)
(save_buffers_kill_zi)
