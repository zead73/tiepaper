# Keys

Bindings follow Appendix A of the PaperClip II manual. Where a key only exists on a
Commodore keyboard, a PC key stands in for it (last table).

**Control commands.** Hold **Ctrl** and press the key, *or* tap and release Ctrl on its
own and then press the key, as the original did (the status line shows `CTRL`). Capital
letters below mean **Ctrl+Shift**.

## Editing

| Keys | Action |
|------|--------|
| Arrows, PgUp/PgDn | Move; PgUp/PgDn go a screen |
| Home / End | Start / end of the line on screen |
| Ctrl+Home / Ctrl+End | Top / bottom of the text |
| Ctrl+Up / Ctrl+Down | Fast scroll |
| Ctrl+Left / Ctrl+Right | Word left / right |
| Shift+Return | Start of the next line without changing text |
| Insert | Insert / overwrite (`INS` in the status line) |
| Return | Split the paragraph (in overwrite mode the rest of the line is erased first) |
| Backspace / Delete | Delete left / right; they join paragraphs at the ends |
| Ctrl+Delete | Erase to the end of the paragraph |
| Ctrl+`-` | Delete the line |
| Ctrl+`+` (Ctrl+Shift+=) | Insert a blank line at the cursor |
| Ctrl+I | Insert many blank lines |
| Ctrl+E | Erase text from the cursor line down (or the range, if one is set) |
| Ctrl+U | Unformat text (removes the return markers inside paragraphs) |
| Ctrl+Z / Ctrl+Shift+Z | Undo / redo (new) |
| F7 | Word wrap on/off (off: lines scroll sideways) |
| Ctrl+Shift+L | Line length for this document (0 = fit the window) |
| Ctrl+Shift+X | Quit |
| Esc F5 / F5 | Set a bookmark (two are kept) / jump between them |
| Alt+C, Alt+X, Alt+V | Copy / cut / paste with the system clipboard: the phrase or range (new) |

## Selecting text

| Keys | Action |
|------|--------|
| Shift+arrows, Shift+Home / End, Shift+PgUp / PgDn | Select as you move, across lines and paragraphs |
| Ctrl+Shift+Left / Right | Select by word |
| Ctrl+Shift+Home / End | Select to the top / bottom of the text |
| Mouse drag | Select; the mouse wheel scrolls |
| Double-click | Select a word |
| Shift+click | Extend the selection to the click |
| Alt+A | Select everything |
| Esc | Clear the selection |

Typing, Return, Backspace or Delete replaces or removes the selected text (one undo step).
Alt+C / Alt+X / Alt+V, or Ctrl+Insert / Shift+Delete / Shift+Insert, copy / cut / paste with the
system clipboard. Alt+B / Alt+I / Alt+U (or Ctrl+B) make the selection bold, italic or underlined.
The status line shows `SEL`. Line ranges (Ctrl+R) and phrases (Ctrl+P) still work as in
PaperClip II; selecting is the quicker way for everyday editing.

## Tabs

| Keys | Action |
|------|--------|
| F6 | Set / clear a tab stop at the cursor |
| Ctrl+N | Set / clear a **numeric** tab: digits typed there line up on the decimal point |
| Ctrl+F6 | Clear all tabs |
| Tab | Next tab (the leftmost tab on the next line when there is none; every 8 columns if none are set) |
| Esc Tab | Next numeric tab |

## Line ranges

| Keys | Action |
|------|--------|
| Ctrl+R | Set range: Up/Down change it, Return sets it, Esc cancels |
| Ctrl+T | Transfer (move) the range to the cursor line |
| Ctrl+C | Copy the range there (asks how many copies) |
| Ctrl+D | Delete the range |
| Ctrl+E | Erase the range (answer Y to *Erase range only?*) |
| Ctrl+Q | Save the range to a file |

## Phrases

| Keys | Action |
|------|--------|
| Ctrl+P | Set phrase: Left/Right extend it, **S** to the end of the sentence, **W** to the end of the next word |
| Ctrl+M / Ctrl+K | Move / copy the phrase to the cursor |
| Ctrl+Y | Set and delete in one go |
| Ctrl+Shift+K | Change case of the phrase |
| Esc *letter* | Insert an instant phrase. Define it with a line `✓t=Yours truly,` (52 keys, a-z and A-Z) |

## Columns

Every line in the table must be a paragraph of its own (end each with Return) and fit on
one row; if a line wraps the program tells you to widen it with Ctrl+Shift+L.

| Keys | Action |
|------|--------|
| Ctrl+Shift+C | Set column: arrows size the rectangle, **End** or **$** goes to the right edge |
| Ctrl+Shift+M | Move (inserts at the cursor, deletes the original, line by line) |
| Ctrl+Shift+S | Shift (lays the column over the text at the cursor, leaves blanks behind) |
| Ctrl+Shift+R | Repeat (like shift but the original stays) |
| Ctrl+Shift+I | Insert spaces in front of the column |
| Ctrl+Shift+D / Ctrl+Shift+E | Delete / erase the column |
| Ctrl+Shift+W | Fill the column with a character |
| Ctrl+`=` | Add the column; Return puts the total in the text, decimal point under the cursor |
| Ctrl+Shift+H | Add each row (numbers split by the field separators) |
| Ctrl+`.` | Number of decimal places for results (0-38, or 255 for as many as the numbers have) |
| Ctrl+Shift+A | Sort the column by up to 16 fields, ascending or descending |
| Ctrl+Shift+Q | Define the 16 field separators |

## Searching

| Keys | Action |
|------|--------|
| Ctrl+F | Find (from the cursor; the cursor lands after the match) |
| Ctrl+H | Hunt for the next one |
| Ctrl+Shift+2 (Ctrl+@) | Search and replace: up to five pairs, optionally asking each time, optionally across linked files |

In a search string: `.` any character, `?` any letter, `[` start of a word, `]` end of a
word, `'` makes the next character exact (case-sensitive and not special). Searching ignores
case otherwise. Use Esc inside the prompt to type print marks.

## Bold, italics and underline

| Keys | Action |
|------|--------|
| Alt+B (or Ctrl+B) | Bold on / off at the cursor |
| Alt+I | Italics on / off |
| Alt+U | Underline on / off |
| with text selected, or a phrase set (Ctrl+P, then Return) | The same keys wrap it in the marks instead |

Press the key to start, type, press it again to stop (the status line shows `B`, `I` or `U`
while a style is active). The text is drawn bold, italic or underlined on the editing screen as
you type, in the colours set in the F2 menu; the small marks around it are the switches the
formatter reads and never print. The Esc codes below insert the same marks.

## Print marks (after Esc)

| Keys | Mark |
|------|------|
| Esc `[`  `]` | Underline on / off |
| Esc `(`  `)` | Bold on / off |
| Esc `<`  `>` | Italics on / off |
| Esc `#` | Superscript the next character; Esc `%` on; Esc `'` off |
| Esc `$` | Subscript the next character; Esc `!` on; Esc `"` off |
| Esc `.` | Underline character (always prints) |
| Esc `-` | Conditional hyphen: appears only if the word needs breaking there |
| Esc `/` or Ctrl+Shift+1 | Breakpoint: a place a long word may be broken, without a hyphen |
| Shift+Space (or Esc Space) | Hard space: keeps two words together |
| `\` | The checkmark that starts a format line (Esc `\` types a real backslash) |

## Spell checking

| Keys | Action |
|------|--------|
| Ctrl+Shift+Y | Spell check the document with the operating system's checker |

Linux uses whichever of **hunspell**, **aspell** or **enchant** is installed (plus a
dictionary for your language, e.g. `pacman -S hunspell hunspell-en_ca`); Windows uses its
built-in checker (Windows 8 or later). Words are checked top to bottom, skipping format
lines, words with digits and ALL-CAPS acronyms. At each misspelling the tab line shows
suggestions: **1-9** take one, **R** types a replacement, **I** ignores the word for this
session, **A** adds it to the checker's personal dictionary, **Space** or **Return**
skips it, **Esc** stops. All replacements undo together with Ctrl+Z. The language comes from
your system; set another in File Options (F4), e.g. `en_CA` on Linux or `en-CA` on Windows.
`tiepaper --spell word ...` checks words from the command line.

## Files and output

| Keys | Action |
|------|--------|
| Ctrl+S | Save. The comment on line one (`✓cm:name`) is offered as the file name |
| Ctrl+L | Load. Offers the file named by a trailing `✓nx:` link |
| Ctrl+A | Append a file at the cursor |
| Ctrl+0 / 1 / 3 | Directory of this folder / your home folder / with wild cards |
| Ctrl+V | Preview |
| Ctrl+O | Output: PDF, plain text, or the printer |
| Ctrl+Shift+O | Print everything now with the defaults (asks first) |
| F2 / F4 | Screen options / file options menus |
| F1 | Help |

Names ending in `.txt` are saved as plain text (tabs and line length are not kept);
any other name keeps them in a one-line header.

In the **preview**: PgUp/PgDn move by page, arrows scroll and pan, **Z** (or F8) changes the
zoom, **W** lists formatting warnings, **Enter** returns to the editor at the text you were
looking at, Ctrl+O outputs, Esc goes back.

## Prompts

Prompts appear on the tab line. The suggested answer is highlighted: typing replaces it,
Return accepts it, the arrow keys let you edit it. Up/Down recall earlier answers,
Tab restores the suggestion, Ctrl+U clears, F6 copies 16 characters from the text at the
cursor, Esc cancels. In search strings Esc starts a print mark, so press Esc twice to cancel.

## PC substitutions for Commodore keys

| PaperClip II | Here |
|--------------|------|
| £ key (checkmark) | `\` |
| RUN/STOP (cancel) | Esc |
| CLR/HOME | Home / Ctrl+Home |
| Shift+CLR/HOME (set tab) | F6 (Shift+Home now selects) |
| F1 / F3 (screen down / up) | PgDn / PgUp (F1 is Help) |
| F7 (word wrap) | F7 |
| Shift+F2 / Shift+F4 menus | F2 / F4 |
| Shift+F8 (preview width) | Z or F8 in the preview |
| INST/DEL, ← key | Backspace, Delete |
| C= key | not needed |
| Control, then key | Ctrl held, or Ctrl tapped then the key |
