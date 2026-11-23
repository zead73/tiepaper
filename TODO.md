# TiePaper to do

1. ~~**Plain text editor mode.**~~ Done (2026-11-22). Every file not named `.pcl` opens as plain text and is saved
   byte for byte; Ctrl+Shift+T switches a document between plain and PaperClip mode.
2. ~~**Programming syntax.**~~ Done (2026-11-23): Pascal, C/C++, Rust, Python, shell and config files, by file name, Ctrl+Shift+G turns it off.
3. ~~**More syntax languages.**~~ Done (2026-11-23): Go, Java, JavaScript, C#, Lua, HTML, Markdown and SQL, by file
   extension (key highlighting in `key value` config files, e.g. kitty.conf, sshd_config, shipped with item 2).
4. **Language picker and colouring performance.** A way to pick the language by hand for files with no telling
   name. Colouring re-tokenizes every paragraph above the last visible one after each edit: about 40 ms at
   20,000 lines, so a very large file would feel slow; remembering the first changed paragraph would fix that.
5. **Tab width display in plain mode.** A tab character is kept in the file but shows as an arrow one cell wide,
   so tab-aligned files (fstab, sshd_config, Makefiles) look ragged. Needs a screen-column versus
   character-index mapping in the layout, cursor, mouse and selection code. Also wanted for syntax highlighting.
6. **Plain mode rough edges.**
   - Characters outside the Basic Multilingual Plane (emoji) are two UTF-16 cells shown as two `?`; they save
     correctly if left alone, but deleting one half breaks them.
   - Optional auto-indent on Return.
   - Offer to open a new untitled document as plain text.

Not planned: mail merge, form letters, telecommunications, disk-drive commands, printer files.
