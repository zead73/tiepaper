# Format lines

A format line is a paragraph that starts with the checkmark `✓` (type a backslash `\`
at the start of a line). Several commands can share a line, separated by colons:

```
✓lm10:rm70:ju on:sp2
```

Commands only affect the text after them. Format lines are not printed. The command is
the first two letters; the value follows. For on/off commands any of `1`, `0`, ` on`,
` off`, ` one` works (`✓ju on`, `✓justification on`, `✓ju1` are the same).

A number can be absolute (`lm20`) or relative to the base setting (`lm+5`, `lm-3`).
Relative settings never accumulate: they are always measured from the last absolute
value, and `lm+0` returns to it.

Defaults (the manual's): paper 66 lines, 56 printed lines per page, left margin 10,
right margin 70, 10 characters per inch, 6 lines per inch, page 1.

| Command | Meaning |
|---------|---------|
| `lm10` `rm70` | Left / right margin (columns) |
| `pp66` | Paper length in lines; also makes every line printable, so follow it with `pg` |
| `pg56` | Lines printed per page |
| `vp0` | Blank lines left at the top of each page |
| `of0` | Printer offset: shift everything right by this many columns |
| `ls6` | Lines per inch: 6, 8, or any other number for the "optional" 4 |
| `sp1` | Print spacing: 1 single, 2 double, 3 triple ... up to 9 |
| `pt10` | Characters per inch: 10, 12, 15, or any 4-30; anything else is the optional 5 (double width) |
| `ju on` | Justify (both margins even; the last line of a paragraph stays ragged) |
| `ce on` | Centre between the margins (overrides justification) |
| `ra on` | Right align (overridden by centring and justification) |
| `fp` `fp8` | New page now; with a number, only if fewer than that many lines remain |
| `ln4` | Insert 4 blank lines (ignored at the top of a page; stops at the page end) |
| `ma+5` | Margin adjust: moves the first line of the **next** paragraph only |
| `ai+5` | Automatic indent: moves the first line of **every** paragraph (`ai+0` stops it) |
| `hd3:left,middle,right` | Header, 3 lines above the text |
| `ft2:left,middle,right` | Footer, 2 lines above the bottom edge of the paper |
| `p#5` `p#+1` | Set / adjust the page number |
| `ch2` `ch+1` | Set / adjust the chapter number |
| `hl` `hr` `fl` `fr` | Header and footer left / right margins |
| `ml on` | Lock the header and footer margins so text margin changes leave them alone |
| `ph12` `pf12` | Header / footer pitch |
| `cm:text` | Comment, ignored. A comment on line one is offered as the file name |
| `ps:message` | Pause message, shown in the preview on the page it falls on |
| `nx:name` | Continue with another file (must be the last line) |
| `lk` | Ask for the next file |
| `ex:name` | Print another file here and come back (one level) |
| `tf:name` | Name the table-of-contents file |
| `tb text` | Add an entry (with the current page number) to that file |
| `x=text` | Instant phrase for the Esc key `x`; not printed |

## Headers and footers

The character after the number separates the three parts (left, centre, right), so you can
use any character that does not occur in the text:

```
✓hd2!Smith & Sons!Annual Report!Draft 3
✓ft2:,,Page <>
```

`<>` becomes the page number and `[]` the chapter number. The older form with a colon after
the number and commas between the parts still works. `hd0` / `ft0` turn them off.

A header is written when a page is started and a footer when it is finished, with the
settings in force at that moment. To have a header on page two only, put the `hd` line after
the first paragraph.

**The header needs room above the text.** With the defaults the first text line is line 1
of the paper, so use a vertical position: `✓vp4:hd2:Title,,<>` prints the header on line 3
and the text from line 5. If there is no room the preview warns instead of dropping it
silently (press `W` in the preview).

## Print marks inside the text

Underline, bold, italics and super/subscript are switches in the text (typed with Esc, see
[keys.md](keys.md)); they are shown on screen as small symbols and never print. Hard space
keeps words together. A conditional hyphen shows only if the word has to be broken there. A
breakpoint allows a break without a hyphen, handy for words that already contain hyphens.

## Differences from PaperClip II

* `pp` and `pg` in the middle of a page start a new page first.
* `fp` on a page that has had nothing printed on it does nothing (no blank pages).
* Output goes to PDF (Courier at the chosen pitch), plain text, or the system printer, so
  the printer-file commands and raw printer codes are gone. `ep:` is reported, not obeyed.
* `pt` accepts any pitch from 4 to 30.
