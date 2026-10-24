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

{ The help text is a list of source lines: "#Heading", "keys|what they do", or plain text (a paragraph
  that gets wrapped).  WrapHelp turns it into display lines for the current window width, each
  starting with a kind letter: H heading, K a key line (key, #1, then the rest of the line, already
  padded to the description column), D a continuation line (indent included), T plain text. }

const
  HelpKeyMax = 26;   { widest key column; longer keys would have to be shortened in the text }

{ takes the next line of at most w characters off the front of rest, breaking at a space }
function HelpBreak(var rest: string; w: Integer): string;
var
  k: Integer;
begin
  if Length(rest) <= w then
  begin
    Result := rest;
    rest := '';
    Exit;
  end;
  k := w;
  while (k > 0) and (rest[k + 1] <> ' ') do Dec(k);
  if k = 0 then k := w;
  Result := TrimRight(Copy(rest, 1, k));
  rest := TrimLeft(Copy(rest, k + 1, MaxInt));
end;

procedure TApp.WrapHelp(width: Integer);
var
  i, p, keyW, descCol, avail: Integer;
  s, key, rest: string;
begin
  if HelpLines = nil then HelpLines := TStringList.Create;
  HelpLines.Clear;
  HelpWrapW := width;
  keyW := 0;
  for i := 0 to HelpText.Count - 1 do
  begin
    p := Pos('|', HelpText[i]);
    if p > keyW + 1 then keyW := p - 1;
  end;
  if keyW > HelpKeyMax then keyW := HelpKeyMax;
  descCol := 2 + keyW + 2;           { where descriptions start, counted from the left margin }
  avail := width - descCol;
  for i := 0 to HelpText.Count - 1 do
  begin
    s := HelpText[i];
    p := Pos('|', s);
    if s = '' then
      HelpLines.Add('T')
    else if s[1] = '#' then
      HelpLines.Add('H' + Copy(s, 2, MaxInt))
    else if p > 0 then
    begin
      key := Copy(s, 1, p - 1);
      rest := Copy(s, p + 1, MaxInt);
      if avail >= 24 then
      begin
        HelpLines.Add('K' + key + #1 + StringOfChar(' ', descCol - 2 - Length(key)) + HelpBreak(rest, avail));
        while rest <> '' do HelpLines.Add('D' + StringOfChar(' ', descCol) + HelpBreak(rest, avail));
      end
      else
      begin
        { a narrow window: the key on a line of its own, the description under it }
        HelpLines.Add('K' + key + #1);
        while rest <> '' do HelpLines.Add('D' + StringOfChar(' ', 6) + HelpBreak(rest, width - 6));
      end;
    end
    else
    begin
      rest := s;
      while rest <> '' do HelpLines.Add('T  ' + HelpBreak(rest, width - 2));
    end;
  end;
end;

procedure TApp.DrawHelp;
var
  textC, backC, dimC, keyC, headC: LongWord;
  i, rows, k, p: Integer;
  s, key: string;
begin
  if (HelpLines = nil) or (HelpWrapW <> Gfx.Cols - 2) then WrapHelp(Gfx.Cols - 2);
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  dimC := RGBOf(Cfg.ColReturn);
  keyC := RGBOf(Cfg.ColMarker);
  headC := RGBOf(Cfg.ColDirective);
  Gfx.FillCells(0, 0, Gfx.Cols, 1, textC);
  Gfx.PutText(0, 0, ' TiePaper help', backC, ST_BOLD);
  Gfx.PutText(1, 1, 'Arrows/PgUp/PgDn scroll   Esc closes', dimC);
  rows := Gfx.Rows - 4;
  for i := 0 to rows - 1 do
  begin
    k := HelpTop + i;
    if k >= HelpLines.Count then Break;
    s := HelpLines[k];
    case s[1] of
      'H': Gfx.PutText(1, 3 + i, UTF8Decode(Copy(s, 2, MaxInt)), headC, ST_BOLD);
      'K':
        begin
          p := Pos(#1, s);
          key := Copy(s, 2, p - 2);
          Gfx.PutText(3, 3 + i, UTF8Decode(key), keyC, ST_BOLD);
          Gfx.PutText(3 + Length(key), 3 + i, UTF8Decode(Copy(s, p + 1, MaxInt)), textC);
        end;
    else
      Gfx.PutText(1, 3 + i, UTF8Decode(Copy(s, 2, MaxInt)), textC);
    end;
  end;
  Gfx.PutText(1, Gfx.Rows - 1, UnicodeString(Format('%d%%', [(HelpTop + rows) * 100 div (HelpLines.Count + 1)])), dimC);
end;

procedure BuildHelp(t: TStringList);
begin
  t.Clear;
  t.Add('#TiePaper works like PaperClip II');
  t.Add('You type plain text and add formatting instructions to it.  The screen shows exactly what you type.  A left arrow marks the end of each paragraph (the "return marker").');
  t.Add('Formatting instructions go on their own lines that start with a checkmark: type a backslash (\) to make it.  Preview with Ctrl+V, output with Ctrl+O.');
  t.Add('Control keys: hold Ctrl and press the key, or tap and release Ctrl and then press the key.  Capitals mean Ctrl+Shift.');
  t.Add('');
  t.Add('#Editing');
  t.Add('Arrows|Move the cursor');
  t.Add('Home / End|Start / end of the line');
  t.Add('Ctrl+Home / Ctrl+End|Top / bottom of the text');
  t.Add('PgUp / PgDn|Up / down a screen');
  t.Add('Ctrl+Up / Ctrl+Down|Fast scroll');
  t.Add('Shift+Return|Start of the next line');
  t.Add('Insert|Insert / overwrite');
  t.Add('Delete / Backspace|Delete');
  t.Add('Ctrl+-|Delete the line');
  t.Add('Ctrl++|Insert a line');
  t.Add('Ctrl+I|Insert many lines');
  t.Add('Ctrl+E|Erase text (or the range) from the cursor down');
  t.Add('Ctrl+U|Unformat text');
  t.Add('Ctrl+Z / Ctrl+Shift+Z|Undo / redo');
  t.Add('F7|Word wrap on / off');
  t.Add('Ctrl+Shift+L|Line length');
  t.Add('Alt+C / Alt+X / Alt+V|Copy / cut / paste with the system clipboard (phrase or range); Ctrl+Insert, Shift+Delete, Shift+Insert work too');
  t.Add('Esc F5 / F5|Set a bookmark (two are kept) / jump to a bookmark');
  t.Add('');
  t.Add('#Tabs');
  t.Add('Tab|Next tab');
  t.Add('Esc Tab|Next numeric tab');
  t.Add('F6|Set / clear a tab at the cursor');
  t.Add('Ctrl+N|Set / clear a numeric tab');
  t.Add('Ctrl+F6|Clear all tabs');
  t.Add('');
  t.Add('#Selecting text');
  t.Add('Shift+arrows|Select as you move');
  t.Add('Shift+Home/End/PgUp/PgDn|Select to the start / end of the line, or a screen at a time');
  t.Add('Ctrl+Shift+Left / Right|Select by word');
  t.Add('Ctrl+Shift+Home / End|Select to the top / bottom of the text');
  t.Add('Mouse drag|Select');
  t.Add('Double-click|Select a word');
  t.Add('Shift+click|Extend the selection');
  t.Add('Alt+A|Select everything');
  t.Add('Esc|Clear the selection');
  t.Add('Alt+B / Alt+I / Alt+U|Bold / italics / underline (Ctrl+B also does bold): switch it on or off at the cursor, or wrap the selection (or the phrase).  The text shows the effect as you type.');
  t.Add('');
  t.Add('Typing, Return, Backspace or Delete replaces or removes the selection.');
  t.Add('');
  t.Add('#Line ranges (whole lines)');
  t.Add('Ctrl+R|Set the range (arrows, then Return)');
  t.Add('Ctrl+T|Transfer');
  t.Add('Ctrl+C|Copy');
  t.Add('Ctrl+D|Delete the range');
  t.Add('Ctrl+E|Erase the range');
  t.Add('Ctrl+Q|Save the range to a file');
  t.Add('');
  t.Add('#Phrases (inside one paragraph)');
  t.Add('Ctrl+P|Set a phrase (Left / Right extend it, S = to the next sentence end, W = next word)');
  t.Add('Ctrl+M|Move the phrase');
  t.Add('Ctrl+K|Copy the phrase');
  t.Add('Ctrl+Y|Set the phrase and delete it');
  t.Add('Ctrl+Shift+K|Change case');
  t.Add('');
  t.Add('Instant phrases: define a line like  \t=text  and Esc t then types the text.  There are 52 keys, a-z and A-Z.');
  t.Add('');
  t.Add('#Columns');
  t.Add('Every line of the table must be a short paragraph of its own.');
  t.Add('Ctrl+Shift+C|Set the column (arrows size it; End or $ goes to the right edge)');
  t.Add('Ctrl+Shift+M / S / R|Move / shift / repeat the column');
  t.Add('Ctrl+Shift+I / D / E / W|Insert spaces / delete / erase / fill');
  t.Add('Ctrl+=|Add the column');
  t.Add('Ctrl+Shift+H|Add rows');
  t.Add('Ctrl+.|Decimal places');
  t.Add('Ctrl+Shift+A|Sort');
  t.Add('Ctrl+Shift+Q|Field separators');
  t.Add('');
  t.Add('#Searching');
  t.Add('Ctrl+F|Find');
  t.Add('Ctrl+H|Hunt for the next one');
  t.Add('Ctrl+@ (Ctrl+Shift+2)|Search and replace');
  t.Add('In a search string:');
  t.Add('.|Any character');
  t.Add('?|Any letter');
  t.Add('[|Start of a word');
  t.Add(']|End of a word');
  t.Add('''|Makes the next character exact (case and meaning)');
  t.Add('');
  t.Add('Use Esc to type print marks in a search string.');
  t.Add('');
  t.Add('#Print marks (after Esc)');
  t.Add('Esc [ ]|Underline on / off');
  t.Add('Esc ( )|Bold on / off');
  t.Add('Esc < >|Italics on / off');
  t.Add('Esc #|Superscript the next character');
  t.Add('Esc % / Esc ''|Superscript on / off');
  t.Add('Esc $|Subscript the next character');
  t.Add('Esc ! / Esc "|Subscript on / off');
  t.Add('Esc .|Underline the next character');
  t.Add('Esc -|Conditional hyphen');
  t.Add('Esc / or Ctrl+Shift+1|Breakpoint');
  t.Add('Shift+Space|Hard space (the words stay together)');
  t.Add('');
  t.Add('#Files and output');
  t.Add('Ctrl+S|Save');
  t.Add('Ctrl+L|Load');
  t.Add('Ctrl+A|Append a file here');
  t.Add('Ctrl+0|Directory');
  t.Add('Ctrl+1|Your home folder');
  t.Add('Ctrl+3|Directory with wild cards');
  t.Add('Ctrl+V|Preview');
  t.Add('Ctrl+O|Output (PDF, text or printer)');
  t.Add('Ctrl+Shift+O|Print at once');
  t.Add('Ctrl+Shift+Y|Spell check with the system checker (hunspell, aspell or enchant; Windows'' own).  1-9 take a suggestion, R retype, I ignore, A add to the dictionary, Space skip');
  t.Add('F2|Screen options');
  t.Add('F4|File options');
  t.Add('F1|This help');
  t.Add('Ctrl+Shift+X|Quit');
  t.Add('');
  t.Add('Names ending in .txt are saved as plain text; anything else keeps tabs and line length.');
  t.Add('');
  t.Add('#Format instructions');
  t.Add('Each goes on a line that starts with a checkmark; join several with colons.');
  t.Add('lm10 rm70|Left and right margin (lm+5 or lm-3 adjusts relative to the base; lm+0 undoes it)');
  t.Add('pp66 pg56 vp0|Paper length, lines printed per page, blank lines at the top');
  t.Add('of5|Printer offset: shift everything right');
  t.Add('sp2  ls8|Print spacing (1-9) and lines per inch (6, 8 or other = 4)');
  t.Add('pt10|Characters per inch: 10, 12, 15, or any 4-30');
  t.Add('ju on|Justify (ju off turns it off)');
  t.Add('ce on|Centre (ce off turns it off)');
  t.Add('ra on|Right align (ra off turns it off)');
  t.Add('fp  fp8|New page now, or only if fewer than 8 lines remain');
  t.Add('ln4|Insert 4 blank lines');
  t.Add('ma+5|Indent the next paragraph');
  t.Add('ai+5|Automatic first-line indent for every paragraph (ai+0 turns it off)');
  t.Add('hd3:left,middle,right|Header 3 lines above the text.  The character after the number is the separator, so  hd3!Left!Mid!Right  allows commas; hd0 turns it off');
  t.Add('ft2:,,<>|Footer 2 lines above the bottom edge; <> is the page number, [] the chapter');
  t.Add('p#5  p#+1|Set / adjust the page number');
  t.Add('ch2  ch+1|Chapter number');
  t.Add('hl hr fl fr|Header / footer margins');
  t.Add('ml on|Lock them to stay put');
  t.Add('ph pf|Their pitch');
  t.Add('cm:text|Comment (a comment on line 1 is offered as the file name)');
  t.Add('ps:message|Pause message shown in the preview');
  t.Add('nx:name|Carry on with the next file (must be last)');
  t.Add('lk|Ask for the next file');
  t.Add('ex:name|Print another file here, then come back');
  t.Add('tf:name  tb:text|Write a table of contents file while previewing or outputting');
  t.Add('');
  t.Add('The header needs room above the text: use vp, e.g.  \vp4:hd2:Title,,<>');
  t.Add('');
  t.Add('#Differences from the Commodore program');
  t.Add('Not included: the SpellPack checker, form letters, telecommunications, disk commands and printer files.  Output is PDF, text or your system printer.  Characters are Unicode.');
  t.Add('Line length defaults to the window width, and changing it never erases text.');
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
      rows := Gfx.Rows - 4;
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
