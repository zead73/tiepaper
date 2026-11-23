# TiePaper to do

1. ~~**Plain text editor mode.**~~ Done (2026-11-22). Every file not named `.pcl` opens as plain text and is saved
   byte for byte; Ctrl+Shift+T switches a document between plain and PaperClip mode.
2. ~~**Programming syntax.**~~ Done (2026-11-23): Pascal, C/C++, Rust, Python, shell and config files, by file name, Ctrl+Shift+G turns it off.
3. ~~**More syntax languages.**~~ Done (2026-11-23): Go, Java, JavaScript, C#, Lua, HTML, Markdown and SQL, by file
   extension (key highlighting in `key value` config files, e.g. kitty.conf, sshd_config, shipped with item 2).
4. ~~**Language picker and colouring performance.**~~ Done (2026-11-23): Ctrl+Shift+P steps through the
   languages by hand, for files whose name does not pick one. Colouring now retokenizes only from the lowest
   paragraph an edit actually touched (`TDoc.DirtyFrom`) instead of the whole file on every keystroke.
5. ~~**Tab width display in plain mode.**~~ Done (2026-11-23): a tab now expands on screen to the next multiple
   of `[editing] tabwidth` (default 4), so tab-aligned files (fstab, sshd_config, Makefiles) line up. Cursor
   movement, mouse clicks and the legacy PaperClip column-select feature all convert between screen column and
   character offset (`CharColToScreenCol`/`ScreenColToCharCol` in `pcdoc.pas`); the file on disk is untouched,
   still one tab byte. Known limitation: word wrap (`Cfg.WrapView`) still budgets by character count, so a
   wrapped line with tabs can run past the window edge - turn word wrap off (NOWRAP) for tab-aligned files, which
   is also how the manual's own tab stops are meant to be read.
6. **Plain mode rough edges.**
   - Characters outside the Basic Multilingual Plane (emoji) are two UTF-16 cells shown as two `?`; they save
     correctly if left alone, but deleting one half breaks them.
   - ~~Optional auto-indent on Return.~~ Done (2026-11-23): `[editing] autoindent`, default on, plain mode only.
   - Offer to open a new untitled document as plain text.

Not planned: mail merge, form letters, telecommunications, disk-drive commands, printer files.
