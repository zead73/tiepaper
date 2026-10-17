{ pcapp_screens.inc - preview, help and option menus (included by pcapp.pas) }

{ ---- preview ---- }

const
  PvZoomScale: array[0..3] of Integer = (100, 80, 62, 46);

function TApp.PvPageAt(globalRow: Integer): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to High(PvStarts) do
    if PvStarts[i] <= globalRow then Result := i else Break;
end;

procedure TApp.DrawPreview;
var
  textC, backC, dimC, paperC, fg, bg: LongWord;
  i, gr, pg, off, k, col, rows, paperCols, idx, style, dy: Integer;
  page: TPage;
  ln: TOutLine;
  cell: TCell;
  hdr: UnicodeString;
  st: UnicodeString;
begin
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  dimC := RGBOf(Cfg.ColReturn);
  paperC := MixColor(backC, textC, 9);
  rows := Gfx.Rows - 3;
  if TPaperSize(Cfg.Paper) = psA4 then paperCols := 83 else paperCols := 85;
  { status bar }
  Gfx.FillCells(0, 0, Gfx.Cols, 1, textC);
  pg := PvPageAt(PvTop + 1);
  st := UnicodeString(Format(' Preview   page %d of %d', [pg + 1, PvFmt.PageCount]));
  Gfx.PutText(0, 0, st, backC, ST_BOLD);
  st := UnicodeString(Format('zoom %d%%  ', [PvZoomScale[PvZoom]]));
  if PvFmt.Warnings.Count > 0 then
    st := UnicodeString(Format('%d warning(s): press W   ', [PvFmt.Warnings.Count])) + st;
  Gfx.PutText(Gfx.Cols - Length(st), 0, st, backC, ST_REGULAR);
  { tab line: a message, a pause prompt for this page, or the hint }
  if Msg <> '' then
  begin
    Gfx.FillCells(0, 1, Gfx.Cols, 1, RGBOf(Cfg.ColBorder));
    Gfx.PutText(1, 1, Msg, backC, ST_BOLD);
  end
  else if PvFmt.GetPage(pg).Notes.Count > 0 then
  begin
    Gfx.FillCells(0, 1, Gfx.Cols, 1, RGBOf(Cfg.ColDirective));
    Gfx.PutText(1, 1, 'Pause: ' + UTF8Decode(PvFmt.GetPage(pg).Notes[0]), backC, ST_BOLD);
  end
  else
    Gfx.PutText(1, 1, Copy('PgUp/PgDn page  arrows scroll  Z zoom  W warnings  Enter edit here  Esc back', 1, Gfx.Cols - 2), dimC);
  Gfx.PutText(1, Gfx.Rows - 1, 'Ctrl+O outputs these pages as PDF, text or to the printer', dimC);
  for i := 0 to rows - 1 do
  begin
    gr := PvTop + i;
    if gr >= PvTotal then Break;
    pg := PvPageAt(gr);
    page := PvFmt.GetPage(pg);
    off := gr - PvStarts[pg];
    if off = 0 then
    begin
      hdr := UnicodeString(Format(' Page %d ', [page.Number]));
      Gfx.FillCells(0, 2 + i, Gfx.Cols, 1, MixColor(backC, textC, 18));
      Gfx.PutText(1, 2 + i, hdr, backC, ST_BOLD);
      Continue;
    end;
    if off > Length(page.Lines) then Continue;
    if PvLeft < paperCols then
      Gfx.FillCells(0, 2 + i, IfThenInt(paperCols - PvLeft < Gfx.Cols, paperCols - PvLeft, Gfx.Cols), 1, paperC);
    ln := page.Lines[off - 1];
    for k := 0 to High(ln.Cells) do
    begin
      col := k - PvLeft;
      if (col < 0) or (col >= Gfx.Cols) then Continue;
      cell := ln.Cells[k];
      if cell.Ch = ' ' then Continue;
      fg := textC;
      idx := PrevIndex((cell.Attr and A_BOLD) <> 0, (cell.Attr and A_UL) <> 0, (cell.Attr and A_ITAL) <> 0);
      if idx >= 0 then fg := RGBOf(Cfg.ColPrev[idx]);
      style := ST_REGULAR;
      if ((cell.Attr and A_BOLD) <> 0) and ((cell.Attr and A_ITAL) <> 0) then style := ST_BOLDITALIC
      else if (cell.Attr and A_BOLD) <> 0 then style := ST_BOLD
      else if (cell.Attr and A_ITAL) <> 0 then style := ST_ITALIC;
      dy := 0;
      if (cell.Attr and A_SUP) <> 0 then dy := -(Gfx.CellH div 5)
      else if (cell.Attr and A_SUB) <> 0 then dy := Gfx.CellH div 6;
      Gfx.PutChar(col, 2 + i, cell.Ch, style, fg, dy);
      if (cell.Attr and A_UL) <> 0 then
        Gfx.HLine(col, 2 + i, 1, Gfx.CellH - 3, fg);
    end;
    { cells that are underlined spaces still need their line }
    for k := 0 to High(ln.Cells) do
      if (ln.Cells[k].Ch = ' ') and ((ln.Cells[k].Attr and A_UL) <> 0) then
      begin
        col := k - PvLeft;
        if (col >= 0) and (col < Gfx.Cols) then
          Gfx.HLine(col, 2 + i, 1, Gfx.CellH - 3, RGBOf(Cfg.ColPrev[PREV_UL]));
      end;
  end;
  bg := backC;
end;

procedure TApp.PvApplyZoom;
begin
  Gfx.SetFontSize(Cfg.FontSize * PvZoomScale[PvZoom] div 100);
end;

procedure TApp.DrawWarnScreen;
var
  textC, backC: LongWord;
  i: Integer;
begin
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  Gfx.FillCells(0, 0, Gfx.Cols, 1, textC);
  Gfx.PutText(0, 0, ' Formatting warnings', backC, ST_BOLD);
  for i := 0 to PvFmt.Warnings.Count - 1 do
  begin
    if 2 + i >= Gfx.Rows - 1 then Break;
    Gfx.PutText(1, 2 + i, UTF8Decode(PvFmt.Warnings[i]), RGBOf(Cfg.ColDirective));
  end;
  Gfx.PutText(1, Gfx.Rows - 1, 'Press any key to return', RGBOf(Cfg.ColReturn));
end;

procedure TApp.ShowWarnings(f: TFormatter);
var
  ev: TKeyEv;
  saved: TProc;
begin
  saved := FullScreen;
  FullScreen := @DrawWarnScreen;
  try
    repeat
      if not WaitKey(ev) then Break;
    until (ev.Kind = ekKey) or (ev.Kind = ekText);
  finally
    FullScreen := saved;
  end;
end;

procedure TApp.DoPreview;
var
  i, j, gr, rows, pg, k, src: Integer;
  ev: TKeyEv;
  page: TPage;
  found: Boolean;
  tocMsg: UnicodeString;
  tocErr: Boolean;
begin
  FreeAndNil(PvFmt);
  PvFmt := BuildFormat;
  tocMsg := WriteToc(PvFmt, tocErr);
  if PvFmt.PageCount = 0 then
  begin
    SetMsg('There is nothing to preview', True);
    FreeAndNil(PvFmt);
    Exit;
  end;
  SetLength(PvStarts, PvFmt.PageCount);
  PvTotal := 0;
  for i := 0 to PvFmt.PageCount - 1 do
  begin
    PvStarts[i] := PvTotal;
    Inc(PvTotal, Length(PvFmt.GetPage(i).Lines) + 2);
  end;
  { open at the page that shows the paragraph the cursor is in }
  PvTop := 0;
  found := False;
  for i := 0 to PvFmt.PageCount - 1 do
  begin
    page := PvFmt.GetPage(i);
    for j := 0 to High(page.Lines) do
      if page.Lines[j].Src >= Doc.CurP then
      begin
        PvTop := PvStarts[i];
        found := True;
        Break;
      end;
    if found then Break;
  end;
  PvLeft := 0;
  PvZoom := 0;
  FullScreen := @DrawPreview;
  Msg := '';
  try
    while WaitKey(ev) do
    begin
      Msg := '';
      rows := Gfx.Rows - 3;
      pg := PvPageAt(PvTop + 1);
      case ev.Kind of
        ekWheel:
          begin
            if ev.Ctrl then
            begin
              if (ev.Wheel > 0) and (PvZoom > 0) then Dec(PvZoom)
              else if (ev.Wheel < 0) and (PvZoom < 3) then Inc(PvZoom);
              PvApplyZoom;
            end
            else PvTop := PvTop - ev.Wheel * 3;
          end;
        ekText:
          case ev.Text[1] of
            'z', 'Z':
              begin
                PvZoom := (PvZoom + 1) mod 4;
                PvApplyZoom;
              end;
            'w', 'W': ShowWarnings(PvFmt);
            'q', 'Q': Break;
          end;
        ekKey:
          begin
            if ev.Ctrl and (ev.Sym = Ord('o')) then
            begin
              OutputPages(PvFmt);
              Continue;
            end;
            if ev.Ctrl and (ev.Sym = Ord('v')) then Break;
            case ev.Sym of
              SDLK_ESCAPE, SDLK_F9: Break;
              SDLK_UP: Dec(PvTop);
              SDLK_DOWN: Inc(PvTop);
              SDLK_LEFT: Dec(PvLeft, 4);
              SDLK_RIGHT: Inc(PvLeft, 4);
              SDLK_PAGEUP:
                begin
                  if PvTop > PvStarts[pg] then PvTop := PvStarts[pg]
                  else if pg > 0 then PvTop := PvStarts[pg - 1];
                end;
              SDLK_PAGEDOWN, SDLK_SPACE:
                if pg < PvFmt.PageCount - 1 then PvTop := PvStarts[pg + 1];
              SDLK_HOME: PvTop := 0;
              SDLK_END: PvTop := PvTotal - rows;
              SDLK_F8:
                begin
                  PvZoom := (PvZoom + 1) mod 4;
                  PvApplyZoom;
                end;
              SDLK_RETURN, SDLK_KP_ENTER:
                begin
                  { jump to the source of the first text line on screen }
                  src := -1;
                  for k := 0 to rows - 1 do
                  begin
                    gr := PvTop + k;
                    if gr >= PvTotal then Break;
                    i := PvPageAt(gr);
                    j := gr - PvStarts[i] - 1;
                    if (j >= 0) and (j <= High(PvFmt.GetPage(i).Lines)) then
                      if PvFmt.GetPage(i).Lines[j].Src >= 0 then
                      begin
                        src := PvFmt.GetPage(i).Lines[j].Src;
                        Break;
                      end;
                  end;
                  if src >= 0 then
                  begin
                    Doc.CurP := src;
                    Doc.CurC := 0;
                  end;
                  Break;
                end;
            end;
          end;
      end;
      if PvTop > PvTotal - 1 then PvTop := PvTotal - 1;
      if PvTop < 0 then PvTop := 0;
      if PvLeft < 0 then PvLeft := 0;
    end;
  finally
    FullScreen := nil;
    PvZoom := 0;
    Gfx.SetFontSize(Cfg.FontSize);
    FreeAndNil(PvFmt);
  end;
  if tocMsg <> '' then SetMsg(tocMsg, tocErr);
end;

{ ---- help ---- }

{ breaks the help text to the window width; continuation lines keep the indent plus a little }
procedure TApp.WrapHelp(width: Integer);
var
  i, indent, cut, k: Integer;
  s, rest, head: string;
begin
  if HelpLines = nil then HelpLines := TStringList.Create;
  HelpLines.Clear;
  HelpWrapW := width;
  for i := 0 to HelpText.Count - 1 do
  begin
    s := HelpText[i];
    if (s = '') or (s[1] = '#') or (Length(s) <= width) then
    begin
      HelpLines.Add(s);
      Continue;
    end;
    indent := 0;
    while (indent < Length(s)) and (s[indent + 1] = ' ') do Inc(indent);
    head := '';
    rest := s;
    repeat
      if Length(rest) <= width - Length(head) then
      begin
        HelpLines.Add(head + rest);
        Break;
      end;
      cut := width - Length(head);
      k := cut;
      while (k > indent) and (rest[k + 1] <> ' ') do Dec(k);
      if k <= indent then k := cut;
      HelpLines.Add(head + Copy(rest, 1, k));
      rest := Trim(Copy(rest, k + 1, MaxInt));
      head := StringOfChar(' ', indent + 4);
    until rest = '';
  end;
end;

procedure TApp.DrawHelp;
var
  textC, backC, dimC: LongWord;
  i, rows, k: Integer;
  s: string;
begin
  if (HelpLines = nil) or (HelpWrapW <> Gfx.Cols - 2) then WrapHelp(Gfx.Cols - 2);
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  dimC := RGBOf(Cfg.ColReturn);
  Gfx.FillCells(0, 0, Gfx.Cols, 1, textC);
  Gfx.PutText(0, 0, ' TiePaper help', backC, ST_BOLD);
  Gfx.PutText(1, 1, 'Up/Down/PgUp/PgDn scroll   Esc or F1 closes', dimC);
  rows := Gfx.Rows - 3;
  for i := 0 to rows - 1 do
  begin
    k := HelpTop + i;
    if k >= HelpLines.Count then Break;
    s := HelpLines[k];
    if (s <> '') and (s[1] = '#') then
      Gfx.PutText(1, 2 + i, UTF8Decode(Copy(s, 2, MaxInt)), RGBOf(Cfg.ColDirective), ST_BOLD)
    else
      Gfx.PutText(1, 2 + i, UTF8Decode(s), textC);
  end;
  Gfx.PutText(1, Gfx.Rows - 1, UnicodeString(Format('%d%%', [(HelpTop + rows) * 100 div (HelpLines.Count + 1)])), dimC);
end;

procedure BuildHelp(t: TStringList);
begin
  t.Clear;
  t.Add('#TiePaper works like PaperClip II: you type plain text and add formatting instructions to it.');
  t.Add('');
  t.Add('  The screen shows exactly what you type.  A left arrow marks the end of each paragraph (the');
  t.Add('  "return marker").  Formatting instructions go on their own lines that start with a checkmark.');
  t.Add('  Type a backslash (\) to make the checkmark.  Preview with Ctrl+V; output with Ctrl+O.');
  t.Add('');
  t.Add('#Keys: hold Ctrl, or tap Ctrl and release it, then press the key (capitals mean Ctrl+Shift)');
  t.Add('  Editing');
  t.Add('    Arrows move; Home/End line start/end; Ctrl+Home/End top/bottom of text; PgUp/PgDn a screen');
  t.Add('    Ctrl+Up/Down  fast scroll        Shift+Return  start of the next line');
  t.Add('    Insert  insert/overwrite         Delete  and  Backspace  delete');
  t.Add('    Ctrl+-  delete the line          Ctrl++  insert a line       Ctrl+I  insert many lines');
  t.Add('    Ctrl+E  erase text (or the range) from the cursor down       Ctrl+U  unformat text');
  t.Add('    Ctrl+Z  undo   Ctrl+Shift+Z  redo     F7  word wrap on/off     Ctrl+Shift+L  line length');
  t.Add('    Tab  next tab    Esc Tab  next numeric tab    F6  set/clear tab at the cursor');
  t.Add('    Ctrl+N  set/clear numeric tab    Ctrl+F6  clear all tabs');
  t.Add('    Esc F5  set a bookmark (two are kept)      F5  jump to a bookmark');
  t.Add('    Alt+C / Alt+X / Alt+V  copy / cut / paste with the system clipboard (phrase or range)');
  t.Add('  Selecting text');
  t.Add('    Shift+arrows, Shift+Home/End/PgUp/PgDn, Ctrl+Shift+Left/Right (by word), Ctrl+Shift+Home/End;');
  t.Add('    drag with the mouse, double-click a word, Shift+click to extend, Alt+A selects everything.');
  t.Add('    Typing, Return, Backspace or Delete replaces/removes it; Alt+C/X/V (also Ctrl+Insert,');
  t.Add('    Shift+Delete, Shift+Insert) use the clipboard; Esc clears it.');
  t.Add('    Alt+B / Alt+I / Alt+U  (Ctrl+B too) bold / italics / underline: turns it on or off at the cursor,');
  t.Add('    or wraps the selection (or the phrase) if there is one.  The text shows the effect as you type.');
  t.Add('  Line ranges (whole lines)');
  t.Add('    Ctrl+R  set range (arrows, then Return)    Ctrl+T  transfer    Ctrl+C  copy');
  t.Add('    Ctrl+D  delete range                       Ctrl+E  erase range    Ctrl+Q  save range to a file');
  t.Add('  Phrases (inside one paragraph)');
  t.Add('    Ctrl+P  set phrase (Left/Right extend it, S = to the next sentence end, W = next word)');
  t.Add('    Ctrl+M  move   Ctrl+K  copy   Ctrl+Y  set and delete   Ctrl+Shift+K  change case');
  t.Add('    Instant phrases: define a line  \t=text  then Esc t  types the text.  52 keys, a-z and A-Z.');
  t.Add('  Columns (every line of the table must be a short paragraph of its own)');
  t.Add('    Ctrl+Shift+C  set column (arrows size it, End or $ goes to the right edge)');
  t.Add('    Ctrl+Shift+  M move   S shift   R repeat   I insert spaces   D delete   E erase   W fill');
  t.Add('    Ctrl+=  add the column   Ctrl+Shift+H  add rows   Ctrl+.  decimal places');
  t.Add('    Ctrl+Shift+A  sort   Ctrl+Shift+Q  field separators');
  t.Add('  Searching');
  t.Add('    Ctrl+F  find   Ctrl+H  hunt for the next one   Ctrl+@ (Ctrl+Shift+2)  search and replace');
  t.Add('    In a search string:  .  any character   ?  any letter   [  start of a word   ]  end of a word');
  t.Add('    '' makes the next character exact (case and meaning).  Use Esc to type print marks in it.');
  t.Add('  Print marks (after Esc)');
  t.Add('    Esc [ ]  underline on/off     Esc ( )  bold on/off     Esc < >  italics on/off');
  t.Add('    Esc #  superscript next character   Esc %  superscript on   Esc ''  off');
  t.Add('    Esc $  subscript next character     Esc !  subscript on     Esc "  off');
  t.Add('    Esc .  underline character   Esc -  conditional hyphen   Esc /  or  Ctrl+Shift+1  breakpoint');
  t.Add('    Shift+Space  hard space (the words stay together)');
  t.Add('  Files and output');
  t.Add('    Ctrl+S  save   Ctrl+L  load   Ctrl+A  append a file here   Ctrl+0  directory');
  t.Add('    Ctrl+1  your home folder   Ctrl+3  directory with wild cards');
  t.Add('    Ctrl+V  preview   Ctrl+O  output (PDF, text or printer)   Ctrl+Shift+O  print at once');
  t.Add('    Ctrl+Shift+Y  spell check with the system checker (hunspell/aspell/enchant, or Windows');
  t.Add('    own).  1-9 take a suggestion, R retype, I ignore, A add to the dictionary, Space skip');
  t.Add('    F2  screen options   F4  file options   F1  this help   Ctrl+Shift+X  quit');
  t.Add('    Names ending in .txt are saved as plain text; anything else keeps tabs and line length.');
  t.Add('');
  t.Add('#Format instructions (each on a line that starts with a checkmark; join several with colons)');
  t.Add('    lm10 rm70      left and right margin (lm+5 or lm-3 adjusts relative to the base; lm+0 undoes it)');
  t.Add('    pp66 pg56 vp0  paper length, lines printed per page, blank lines at the top');
  t.Add('    of5            printer offset: shift everything right');
  t.Add('    sp2  ls8       print spacing (1-9)  and lines per inch (6, 8 or other = 4)');
  t.Add('    pt10           characters per inch: 10, 12, 15, or any 4-30');
  t.Add('    ju on          justify      ce on  centre      ra on  right align (off turns each off)');
  t.Add('    fp  fp8        new page now, or only if fewer than 8 lines remain');
  t.Add('    ln4            insert 4 blank lines            ma+5  indent the next paragraph');
  t.Add('    ai+5           automatic first-line indent for every paragraph (ai+0 turns it off)');
  t.Add('    hd3:left,middle,right   header 3 lines above the text (the character after the number is the');
  t.Add('                            separator, so  hd3!Left!Mid!Right  allows commas); hd0 turns it off');
  t.Add('    ft2:,,<>       footer 2 lines above the bottom edge; <> is the page number, [] the chapter');
  t.Add('    p#5  p#+1      set / adjust the page number    ch2  ch+1  chapter number');
  t.Add('    hl hr fl fr    header/footer margins        ml on  lock them to stay put   ph pf  their pitch');
  t.Add('    cm:text        comment (a comment on line 1 is offered as the file name)');
  t.Add('    ps:message     pause message shown in the preview');
  t.Add('    nx:name        carry on with the next file (must be last)      lk  ask for the next file');
  t.Add('    ex:name        print another file here, then come back');
  t.Add('    tf:name  tb:text   write a table of contents file while previewing or outputting');
  t.Add('    The header needs room above the text: use vp, e.g.  \vp4:hd2:Title,,<>');
  t.Add('');
  t.Add('#Differences from the Commodore program');
  t.Add('    Not included: the SpellPack checker, form letters, telecommunications, disk commands and');
  t.Add('    printer files.  Output is PDF, text or your system printer.  Characters are Unicode.');
  t.Add('    Line length defaults to the window width, and changing it never erases text.');
end;

procedure TApp.DoHelp;
var
  ev: TKeyEv;
  rows: Integer;
begin
  if HelpText = nil then
  begin
    HelpText := TStringList.Create;
    BuildHelp(HelpText);
  end;
  HelpTop := 0;
  FullScreen := @DrawHelp;
  try
    while WaitKey(ev) do
    begin
      rows := Gfx.Rows - 3;
      if (HelpLines = nil) or (HelpWrapW <> Gfx.Cols - 2) then WrapHelp(Gfx.Cols - 2);
      if ev.Kind = ekWheel then HelpTop := HelpTop - ev.Wheel * 3
      else if ev.Kind = ekKey then
        case ev.Sym of
          SDLK_ESCAPE, SDLK_F1: Break;
          SDLK_UP: Dec(HelpTop);
          SDLK_DOWN: Inc(HelpTop);
          SDLK_PAGEUP: Dec(HelpTop, rows - 1);
          SDLK_PAGEDOWN, SDLK_SPACE: Inc(HelpTop, rows - 1);
          SDLK_HOME: HelpTop := 0;
          SDLK_END: HelpTop := HelpLines.Count;
        end;
      if HelpTop > HelpLines.Count - rows then HelpTop := HelpLines.Count - rows;
      if HelpTop < 0 then HelpTop := 0;
    end;
  finally
    FullScreen := nil;
  end;
end;

{ ---- option menus ---- }

procedure TApp.MenuFillScreen;
var
  i: Integer;
const
  PrevNames: array[0..6] of string = ('Boldface', 'Underline', 'Bold/Underline', 'Italics',
    'Bold/Italics', 'Underline/Italics', 'Bold/Underline/Italics');
begin
  SetLength(MenuNames, 0);
  SetLength(MenuVals, 0);
  MenuAdd('Text', PaletteNames[Cfg.ColText]);
  MenuAdd('Background', PaletteNames[Cfg.ColBack]);
  MenuAdd('Border', PaletteNames[Cfg.ColBorder]);
  for i := 0 to 6 do MenuAdd(PrevNames[i], PaletteNames[Cfg.ColPrev[i]]);
  MenuAdd('Format lines', PaletteNames[Cfg.ColDirective]);
  MenuAdd('Print marks', PaletteNames[Cfg.ColMarker]);
  MenuAdd('Font size', IntToStr(Cfg.FontSize));
  MenuAdd('Return markers', IfThenStr(Cfg.ShowReturn, 'shown', 'hidden'));
  MenuAdd('Word wrap', IfThenStr(Cfg.WrapView, 'on', 'off'));
  MenuAdd('Save Current Configuration to disk', '');
  MenuAdd('Load New Configuration from disk', '');
  MenuAdd('Reset to the defaults', '');
end;

procedure TApp.MenuFillFile;
begin
  SetLength(MenuNames, 0);
  SetLength(MenuVals, 0);
  MenuAdd('Paper size', IfThenStr(Cfg.Paper = 0, 'Letter (66 lines)', 'A4 (70 lines)'));
  MenuAdd('Font file name', Cfg.FontFamily);
  MenuAdd('Font folder', IfThenStr(Cfg.FontDir = '', '(default places)', Cfg.FontDir));
  MenuAdd('Spelling language', IfThenStr(Cfg.SpellLang = '', '(the system language)', Cfg.SpellLang));
  MenuAdd('Configuration file', ConfigPath);
end;

procedure TApp.MenuAdd(const n, v: string);
begin
  SetLength(MenuNames, Length(MenuNames) + 1);
  SetLength(MenuVals, Length(MenuVals) + 1);
  MenuNames[High(MenuNames)] := n;
  MenuVals[High(MenuVals)] := v;
end;

procedure TApp.DrawMenuOverlay;
var
  i, x, y, w, h, nameW: Integer;
  textC, backC: LongWord;
  line: UnicodeString;
  fg, bg: LongWord;
begin
  if MenuKind = 0 then MenuFillScreen else MenuFillFile;
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  nameW := 36;
  w := 62;
  if w > Gfx.Cols - 2 then w := Gfx.Cols - 2;
  h := Length(MenuNames) + 4;
  x := (Gfx.Cols - w) div 2;
  y := 2;
  Gfx.FillCells(x, y, w, h, backC);
  Gfx.BoxPx(Gfx.CellX(x), Gfx.CellY(y), w * Gfx.CellW, h * Gfx.CellH, textC);
  Gfx.BoxPx(Gfx.CellX(x) + 2, Gfx.CellY(y) + 2, w * Gfx.CellW - 4, h * Gfx.CellH - 4, textC);
  line := UTF8Decode(MenuTitle);
  Gfx.PutText(x + (w - Length(line)) div 2, y, line, textC, ST_BOLD);
  for i := 0 to High(MenuNames) do
  begin
    fg := textC;
    bg := backC;
    if i = MenuSel then begin fg := backC; bg := textC; end;
    Gfx.FillCells(x + 1, y + 1 + i, w - 2, 1, bg);
    Gfx.PutText(x + 2, y + 1 + i, UTF8Decode(MenuNames[i]), fg, ST_REGULAR);
    Gfx.PutText(x + 2 + nameW, y + 1 + i, UTF8Decode(Copy(MenuVals[i], 1, w - nameW - 4)), fg, ST_BOLD);
  end;
  Gfx.PutText(x + 2, y + h - 2, 'Up/Down choose   Left/Right change   Enter select   Esc close',
    RGBOf(Cfg.ColReturn), ST_REGULAR);
end;

function NextColor(cur, dir, avoid: Integer): Integer;
begin
  Result := (cur + dir + 16) mod 16;
  if Result = avoid then Result := (Result + dir + 16) mod 16;
end;

procedure TApp.MenuAdjust(dir: Integer);
begin
  if MenuKind = 0 then
  begin
    case MenuSel of
      0: Cfg.ColText := NextColor(Cfg.ColText, dir, Cfg.ColBack);
      1: Cfg.ColBack := NextColor(Cfg.ColBack, dir, Cfg.ColText);
      2: Cfg.ColBorder := NextColor(Cfg.ColBorder, dir, -1);
      3..9: Cfg.ColPrev[MenuSel - 3] := NextColor(Cfg.ColPrev[MenuSel - 3], dir, Cfg.ColBack);
      10: Cfg.ColDirective := NextColor(Cfg.ColDirective, dir, Cfg.ColBack);
      11: Cfg.ColMarker := NextColor(Cfg.ColMarker, dir, Cfg.ColBack);
      12:
        begin
          Gfx.SetFontSize(Cfg.FontSize + dir * 2);
          Cfg.FontSize := Gfx.FontPx;
        end;
      13: Cfg.ShowReturn := not Cfg.ShowReturn;
      14: begin Cfg.WrapView := not Cfg.WrapView; LeftCol := 0; end;
    end;
  end
  else
  begin
    case MenuSel of
      0: Cfg.Paper := 1 - Cfg.Paper;
    end;
  end;
end;

procedure TApp.MenuEnter;
var
  s: UnicodeString;
  fn: string;
begin
  if MenuKind = 0 then
  begin
    case MenuSel of
      15:
        begin
          s := UTF8Decode(ConfigPath);
          if Ask('File name?', s, 0, False) then
          begin
            fn := Trim(UTF8Encode(s));
            if fn <> '' then
            begin
              Cfg.WinW := Gfx.WidthPx;
              Cfg.WinH := Gfx.HeightPx;
              try
                SaveSettings(Cfg, fn);
                SetMsg(UnicodeString('Configuration saved to ' + fn));
              except
                on e: Exception do SetMsg(UnicodeString(e.Message), True);
              end;
            end;
          end;
        end;
      16:
        begin
          s := UTF8Decode(ConfigPath);
          if Ask('File name?', s, 0, False) then
          begin
            fn := Trim(UTF8Encode(s));
            if FileExists(fn) then
            begin
              LoadSettings(Cfg, fn);
              Gfx.SetFontSize(Cfg.FontSize);
              SetMsg(UnicodeString('Configuration loaded from ' + fn));
            end
            else SetMsg('62,file not found', True);
          end;
        end;
      17:
        begin
          DefaultSettings(Cfg);
          Gfx.SetFontSize(Cfg.FontSize);
          SetMsg('Defaults restored');
        end;
    end;
  end
  else
  begin
    case MenuSel of
      1:
        begin
          s := UTF8Decode(Cfg.FontFamily);
          if Ask('Font file name (e.g. LiberationMono)?', s, 0, False) then
          begin
            Cfg.FontFamily := Trim(UTF8Encode(s));
            SetMsg('The new font is used the next time TiePaper starts');
          end;
        end;
      3:
        begin
          s := UTF8Decode(Cfg.SpellLang);
          if Ask('Spelling language (e.g. en_CA on Linux, en-CA on Windows; empty = system)?', s, 0, False) then
          begin
            Cfg.SpellLang := Trim(UTF8Encode(s));
            SetMsg('Spelling language set');
          end;
        end;
      2:
        begin
          s := UTF8Decode(Cfg.FontDir);
          if Ask('Folder holding the font files?', s, 0, False) then
          begin
            Cfg.FontDir := Trim(UTF8Encode(s));
            SetMsg('The new font folder is used the next time TiePaper starts');
          end;
        end;
    end;
  end;
end;

procedure TApp.RunMenu(kind: Integer; const title: string);
var
  ev: TKeyEv;
  saved: TProc;
begin
  MenuKind := kind;
  MenuTitle := title;
  MenuSel := 0;
  saved := Overlay;
  Overlay := @DrawMenuOverlay;
  try
    while WaitKey(ev) do
    begin
      if ev.Kind = ekText then
      begin
        case ev.Text[1] of
          '+', '=': MenuAdjust(1);
          '-': MenuAdjust(-1);
          ' ': Break;
        end;
        Continue;
      end;
      if ev.Kind <> ekKey then Continue;
      case ev.Sym of
        SDLK_ESCAPE, SDLK_F2, SDLK_F4: Break;
        SDLK_UP: if MenuSel > 0 then Dec(MenuSel);
        SDLK_DOWN: if MenuSel < High(MenuNames) then Inc(MenuSel);
        SDLK_LEFT: MenuAdjust(-1);
        SDLK_RIGHT: MenuAdjust(1);
        SDLK_RETURN, SDLK_KP_ENTER: MenuEnter;
      end;
    end;
  finally
    Overlay := saved;
  end;
  SaveConfig;
end;

procedure TApp.DoScreenMenu;
begin
  RunMenu(0, ' Screen Options ');
end;

procedure TApp.DoFileMenu;
begin
  RunMenu(1, ' File Options ');
end;
