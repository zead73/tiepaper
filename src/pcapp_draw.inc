{ pcapp_draw.inc - drawing the editing screen (included by pcapp.pas) }

function TApp.TextTop: Integer;
begin
  Result := 2;
end;

function TApp.TextRows: Integer;
begin
  Result := Gfx.Rows - 3;
  if Result < 1 then Result := 1;
end;

function TApp.LayoutWidth: Integer;
begin
  if not Cfg.WrapView then Exit(4000);
  if Doc.LineLen > 0 then Result := Doc.LineLen
  else Result := Gfx.Cols - 1;
  if Result > MAXWIDTH then Result := MAXWIDTH;
  if Result < 20 then Result := 20;
end;

procedure TApp.LayoutNow;
begin
  Doc.EnsureLayout(LayoutWidth);
end;

function TApp.MixColor(a, b: LongWord; pct: Integer): LongWord;
var
  ch, sh: Integer;
  ca, cb: Integer;
begin
  Result := 0;
  for ch := 0 to 2 do
  begin
    sh := ch * 8;
    ca := (a shr sh) and $FF;
    cb := (b shr sh) and $FF;
    Result := Result or (LongWord(ca + (cb - ca) * pct div 100) shl sh);
  end;
end;

procedure TApp.CursorRowCol(out row, col: Integer);
begin
  LayoutNow;
  Doc.PosToRowCol(Doc.CurP, Doc.CurC, row, col);
end;

procedure TApp.EnsureCursorVisible;
var
  row, col, rows: Integer;
begin
  CursorRowCol(row, col);
  rows := TextRows;
  if FollowCursor then
  begin
    if row < TopRow then TopRow := row;
    if row >= TopRow + rows then TopRow := row - rows + 1;
    if col < LeftCol then LeftCol := col;
    if col >= LeftCol + Gfx.Cols - 1 then LeftCol := col - Gfx.Cols + 2;
  end;
  if TopRow > Doc.RowCount - 1 then TopRow := Doc.RowCount - 1;
  if TopRow < 0 then TopRow := 0;
  if LeftCol < 0 then LeftCol := 0;
  if (LayoutWidth <= Gfx.Cols - 1) then LeftCol := 0;
end;

const
  MarkerTable: array[0..11] of record ch, glyph, alt: WideChar; end = (
    (ch: #$E001; glyph: #$2514; alt: 'u'),
    (ch: #$E002; glyph: #$2518; alt: 'u'),
    (ch: #$E003; glyph: #$258C; alt: 'B'),
    (ch: #$E004; glyph: #$2590; alt: 'b'),
    (ch: #$E005; glyph: '/'; alt: '/'),
    (ch: #$E006; glyph: '\'; alt: '\'),
    (ch: #$E007; glyph: #$2191; alt: '^'),
    (ch: #$E008; glyph: #$25B2; alt: '^'),
    (ch: #$E009; glyph: #$25B3; alt: '^'),
    (ch: #$E00A; glyph: #$2193; alt: 'v'),
    (ch: #$E00B; glyph: #$25BC; alt: 'v'),
    (ch: #$E00C; glyph: #$25BD; alt: 'v'));

function TApp.MarkerGlyph(ch: WideChar): WideChar;
var
  i: Integer;
begin
  if ch = CH_CHECK then
  begin
    if Gfx.HasGlyph(#$221A) then Exit(#$221A) else Exit('v');
  end;
  if ch = CH_ULCHAR then Exit('_');
  for i := 0 to High(MarkerTable) do
    if MarkerTable[i].ch = ch then
    begin
      if Gfx.HasGlyph(MarkerTable[i].glyph) then Exit(MarkerTable[i].glyph)
      else Exit(MarkerTable[i].alt);
    end;
  Result := '?';
end;

{ Draws one character cell of document text: markers get their own shapes. }
procedure DrawDocChar(app: TApp; col, row: Integer; ch: WideChar; fg, markFg, dirFg: LongWord);
begin
  case ch of
    ' ': ;
    CH_HARDSPACE: app.Gfx.DrawBar(col, row, 0, markFg);
    CH_SHY: app.Gfx.DrawBar(col, row, 1, markFg);
    CH_BREAK: app.Gfx.DrawBar(col, row, 2, markFg);
    CH_CHECK: app.Gfx.PutChar(col, row, app.MarkerGlyph(ch), ST_BOLD, dirFg);
    #$E001..#$E00C, CH_ULCHAR: app.Gfx.PutChar(col, row, app.MarkerGlyph(ch), ST_REGULAR, markFg);
    #0..#31: app.Gfx.PutChar(col, row, '?', ST_REGULAR, fg);
  else
    app.Gfx.PutChar(col, row, ch, ST_REGULAR, fg);
  end;
end;

{ ---- live print enhancements: bold, italics, underline, super/subscript ---- }

procedure ApplyStyleMark(var st: Byte; ch: WideChar);
begin
  case ch of
    CH_BOLD_ON: st := st or A_BOLD;
    CH_BOLD_OFF: st := st and not A_BOLD;
    CH_IT_ON: st := st or A_ITAL;
    CH_IT_OFF: st := st and not A_ITAL;
    CH_UL_ON: st := st or A_UL;
    CH_UL_OFF: st := st and not A_UL;
    CH_SUP_ON: st := st or A_SUP;
    CH_SUP_OFF: st := st and not A_SUP;
    CH_SUB_ON: st := st or A_SUB;
    CH_SUB_OFF: st := st and not A_SUB;
  end;
end;

{ The style in force at the start of every paragraph, as the formatter would carry it. }
procedure TApp.EnsureStyleCache;
var
  p, i: Integer;
  st: Byte;
  s: UnicodeString;
begin
  if StyleValid and (StyleRev = Doc.Rev) and (Length(ParaStyle) >= Doc.Count) then Exit;
  SetLength(ParaStyle, Doc.Count + 1);
  st := 0;
  for p := 0 to Doc.Count - 1 do
  begin
    ParaStyle[p] := st;
    s := Doc[p];
    if IsFormatLine(s) then Continue;
    for i := 1 to Length(s) do
      if (s[i] >= #$E001) and (s[i] <= #$E00C) then ApplyStyleMark(st, s[i]);
  end;
  StyleRev := Doc.Rev;
  StyleValid := True;
end;

function TApp.StyleAt(p, c: Integer): Byte;
var
  i: Integer;
  s: UnicodeString;
begin
  EnsureStyleCache;
  if (p < 0) or (p >= Doc.Count) then Exit(0);
  Result := ParaStyle[p];
  s := Doc[p];
  if IsFormatLine(s) then Exit(0);
  for i := 1 to c do
    if i <= Length(s) then ApplyStyleMark(Result, s[i]);
end;

{ Ctrl+B, Alt+B / Alt+I / Alt+U.  With a phrase set the phrase is wrapped in the marks; otherwise
  the next mark is dropped in at the cursor: on if that style is off here, off if it is on. }
procedure TApp.ToggleStyle(kind: Char);
var
  onM, offM: WideChar;
  bit: Byte;
  nm: string;
  l1, l2, h1, h2: Integer;
begin
  case kind of
    'B': begin onM := CH_BOLD_ON; offM := CH_BOLD_OFF; bit := A_BOLD; nm := 'Bold'; end;
    'I': begin onM := CH_IT_ON; offM := CH_IT_OFF; bit := A_ITAL; nm := 'Italics'; end;
  else
    begin onM := CH_UL_ON; offM := CH_UL_OFF; bit := A_UL; nm := 'Underline'; end;
  end;
  Doc.PushUndo(0);
  if SelActive and SelBounds(l1, l2, h1, h2) then
  begin
    Doc.InsText(h1, h2, offM);
    Doc.InsText(l1, l2, onM);
    SelActive := False;
    SetMsg(UnicodeString(nm + ' applied to the selection (Ctrl+Z undoes)'));
  end
  else if Doc.PhraseSet then
  begin
    Doc.InsText(Doc.PhP, Doc.PhC2, offM);
    Doc.InsText(Doc.PhP, Doc.PhC1, onM);
    SetMsg(UnicodeString(nm + ' applied to the phrase (Ctrl+Z undoes)'));
  end
  else if (StyleAt(Doc.CurP, Doc.CurC) and bit) <> 0 then
  begin
    Doc.InsText(Doc.CurP, Doc.CurC, offM);
    SetMsg(UnicodeString(nm + ' off'));
  end
  else
  begin
    Doc.InsText(Doc.CurP, Doc.CurC, onM);
    SetMsg(UnicodeString(nm + ' on: type, then press the same key to turn it off'));
  end;
  WantCol := -1;
end;

procedure TApp.DrawEditor;
var
  i, r, p, st, ln, k, col, idx, absCol, cRow, cCol, lo, hi, loc, hic, rows: Integer;
  s: UnicodeString;
  isDir, lastRow: Boolean;
  state: array of Byte;
  textC, backC, dirC, markC_, retC, softC, flashC: LongWord;
  fg, mfg, dfg: LongWord;
  attr, eff: Byte;
  nextSup, nextSub: Boolean;
  pidx, fstyle, dy: Integer;
  ch: WideChar;
  selOn: Boolean;
  slP, slC, shP, shC: Integer;
begin
  LayoutNow;
  EnsureCursorVisible;
  EnsureStyleCache;
  CursorRowCol(cRow, cCol);
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  dirC := RGBOf(Cfg.ColDirective);
  markC_ := RGBOf(Cfg.ColMarker);
  retC := RGBOf(Cfg.ColReturn);
  softC := MixColor(backC, textC, 24);
  flashC := dirC;
  SetLength(state, Gfx.Cols + 1);
  rows := TextRows;
  selOn := SelActive and SelBounds(slP, slC, shP, shC);
  for i := 0 to rows - 1 do
  begin
    r := TopRow + i;
    if r >= Doc.RowCount then Break;
    p := Doc.RowPara(r);
    s := Doc[p];
    st := Doc.RowStart(r);
    ln := Doc.RowLen(r);
    lastRow := (r = Doc.ParaFirstRow(p + 1) - 1);
    isDir := IsFormatLine(s);
    { work out which cells are highlighted }
    for col := 0 to Gfx.Cols - 1 do
    begin
      absCol := col + LeftCol;
      idx := st + absCol;
      state[col] := 0;
      if Doc.RangeSet and (p >= Doc.RangeP1) and (p <= Doc.RangeP2) then state[col] := 2;
      if Doc.PhraseSet and (p = Doc.PhP) and (idx >= Doc.PhC1) and (idx < Doc.PhC2) then state[col] := 2;
      if Doc.ColSet and (p >= Doc.ColP1) and (p <= Doc.ColP2) and (idx >= Doc.ColC1) and (idx < Doc.ColC2) then
        state[col] := 2;
      case SelKind of
        1:
          begin
            lo := SelP0; hi := Doc.CurP;
            if lo > hi then begin k := lo; lo := hi; hi := k; end;
            if (p >= lo) and (p <= hi) then state[col] := 1;
          end;
        2:
          if (p = SelP0) and (idx >= SelC0) and (idx < SelC1) then state[col] := 1;
        3:
          begin
            lo := SelRow0; hi := SelRow1;
            if lo > hi then begin k := lo; lo := hi; hi := k; end;
            loc := SelCol0; hic := SelCol1;
            if loc > hic then begin k := loc; loc := hic; hic := k; end;
            if (r >= lo) and (r <= hi) and (absCol >= loc) and (absCol <= hic) then state[col] := 1;
          end;
      end;
      if selOn and ((p > slP) or ((p = slP) and (idx >= slC))) and ((p < shP) or ((p = shP) and (idx < shC))) and
         (idx <= Length(s)) and ((idx < Length(s)) or (p < shP)) then
        state[col] := 1;
      if (FlashP >= 0) and (p = FlashP) and (idx >= FlashC1) and (idx < FlashC2) then state[col] := 3;
    end;
    for col := 0 to Gfx.Cols - 1 do
      case state[col] of
        1: Gfx.FillCells(col, TextTop + i, 1, 1, textC);
        2: Gfx.FillCells(col, TextTop + i, 1, 1, softC);
        3: Gfx.FillCells(col, TextTop + i, 1, 1, flashC);
      end;
    { the style in force where this row begins }
    attr := 0;
    if not isDir then
    begin
      attr := ParaStyle[p];
      for k := 1 to st do ApplyStyleMark(attr, s[k]);
    end;
    nextSup := False;
    nextSub := False;
    for k := 0 to ln - 1 do
    begin
      idx := st + k;
      ch := s[idx + 1];
      if not isDir then
      begin
        ApplyStyleMark(attr, ch);
        if ch = CH_SUP_NEXT then nextSup := True
        else if ch = CH_SUB_NEXT then nextSub := True;
      end;
      col := k - LeftCol;
      if (col < 0) or (col >= Gfx.Cols) then Continue;
      fg := textC; mfg := markC_; dfg := dirC;
      if isDir then fg := dirC;
      if state[col] in [1, 3] then begin fg := backC; mfg := backC; dfg := backC; end;
      eff := 0;
      if (not isDir) and (not IsMarkerChar(ch)) and (ch <> CH_ULCHAR) then
      begin
        eff := attr;
        if nextSup then eff := eff or A_SUP;
        if nextSub then eff := eff or A_SUB;
        nextSup := False;
        nextSub := False;
      end;
      if eff = 0 then
        DrawDocChar(Self, col, TextTop + i, ch, fg, mfg, dfg)
      else
      begin
        { live bold / italics / underline: the preview colour for that combination }
        pidx := PrevIndex((eff and A_BOLD) <> 0, (eff and A_UL) <> 0, (eff and A_ITAL) <> 0);
        if (pidx >= 0) and (not (state[col] in [1, 3])) then fg := RGBOf(Cfg.ColPrev[pidx]);
        fstyle := ST_REGULAR;
        if ((eff and A_BOLD) <> 0) and ((eff and A_ITAL) <> 0) then fstyle := ST_BOLDITALIC
        else if (eff and A_BOLD) <> 0 then fstyle := ST_BOLD
        else if (eff and A_ITAL) <> 0 then fstyle := ST_ITALIC;
        dy := 0;
        if (eff and A_SUP) <> 0 then dy := -(Gfx.CellH div 5)
        else if (eff and A_SUB) <> 0 then dy := Gfx.CellH div 6;
        if ch = CH_HARDSPACE then Gfx.DrawBar(col, TextTop + i, 0, mfg)
        else if ch <> ' ' then Gfx.PutChar(col, TextTop + i, ch, fstyle, fg, dy);
        if (eff and A_UL) <> 0 then Gfx.HLine(col, TextTop + i, 1, Gfx.CellH - 3, fg);
      end;
    end;
    if lastRow and Cfg.ShowReturn then
    begin
      col := ln - LeftCol;
      if (col >= 0) and (col < Gfx.Cols) then
      begin
        fg := retC;
        if state[col] in [1, 3] then fg := backC;
        Gfx.PutChar(col, TextTop + i, #$2190, ST_REGULAR, fg);
      end;
    end;
  end;
end;

procedure TApp.DrawCursor;
var
  row, col, sr, sc: Integer;
  ch: WideChar;
  s: UnicodeString;
  textC, backC: LongWord;
begin
  if not BlinkOn then Exit;
  CursorRowCol(row, col);
  sr := row - TopRow + TextTop;
  sc := col - LeftCol;
  if (sr < TextTop) or (sr >= TextTop + TextRows) or (sc < 0) or (sc >= Gfx.Cols) then Exit;
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  if InsertMode then
    Gfx.FillRectPx(Gfx.CellX(sc), Gfx.CellY(sr), 3, Gfx.CellH, textC)
  else
  begin
    Gfx.FillCells(sc, sr, 1, 1, textC);
    s := Doc[Doc.CurP];
    if Doc.CurC < Length(s) then
    begin
      ch := s[Doc.CurC + 1];
      DrawDocChar(Self, sc, sr, ch, backC, backC, backC);
    end;
  end;
end;

procedure TApp.DrawStatus;
var
  textC, backC: LongWord;
  left, right, nm: UnicodeString;
  row, col: Integer;
  styl: Byte;
begin
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  Gfx.FillCells(0, 0, Gfx.Cols, 1, textC);
  if Doc.FileName <> '' then nm := UTF8Decode(ExtractFileName(Doc.FileName)) else nm := '(untitled)';
  if Doc.Modified then nm := nm + ' *';
  left := ' TiePaper  ' + nm;
  CursorRowCol(row, col);
  right := UnicodeString(Format('Line %d/%d  Col %d ', [Doc.CurP + 1, Doc.Count, col + 1]));
  styl := StyleAt(Doc.CurP, Doc.CurC);
  if (styl and A_UL) <> 0 then right := 'U ' + right;
  if (styl and A_ITAL) <> 0 then right := 'I ' + right;
  if (styl and A_BOLD) <> 0 then right := 'B ' + right;
  if InsertMode then right := 'INS ' + right;
  if (SDL_GetModState() and 8192) <> 0 then right := 'LOK ' + right;
  if NumMode then right := 'NMR ' + right;
  if SelActive then right := 'SEL ' + right;
  if Doc.RangeSet then right := 'RNG ' + right;
  if Doc.PhraseSet then right := 'PHR ' + right;
  if Doc.ColSet then right := 'COL ' + right;
  if not Cfg.WrapView then right := 'NOWRAP ' + right;
  if CtrlMode then right := 'CTRL ' + right;
  if EscMode then right := 'ESC ' + right;
  Gfx.PutText(0, 0, left, backC, ST_BOLD);
  Gfx.PutText(Gfx.Cols - Length(right), 0, right, backC, ST_REGULAR);
end;

procedure TApp.DrawTabLine;
var
  col, absCol, row, ccol: Integer;
  textC, backC, dimC, fg, bg: LongWord;
  lw: Integer;
begin
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  dimC := RGBOf(Cfg.ColReturn);
  if Msg <> '' then
  begin
    if MsgErr then begin bg := RGBOf(2); fg := RGBOf(1); end
    else begin bg := RGBOf(Cfg.ColBorder); fg := backC; end;
    Gfx.FillCells(0, 1, Gfx.Cols, 1, bg);
    Gfx.PutText(1, 1, Msg, fg, ST_BOLD);
    Exit;
  end;
  lw := LayoutWidth;
  CursorRowCol(row, ccol);
  for col := 0 to Gfx.Cols - 1 do
  begin
    absCol := col + LeftCol;
    if absCol <= MAXWIDTH then
    begin
      if (Doc.Tabs[absCol] and TAB_NUM) <> 0 then
      begin
        Gfx.FillCells(col, 1, 1, 1, textC);
        Gfx.PutChar(col, 1, 'N', ST_BOLD, backC);
        Continue;
      end
      else if (Doc.Tabs[absCol] and TAB_REG) <> 0 then
      begin
        Gfx.FillCells(col, 1, 1, 1, textC);
        Continue;
      end;
    end;
    if (absCol + 1) mod 10 = 0 then
      Gfx.PutChar(col, 1, WideChar(Ord('0') + ((absCol + 1) div 10) mod 10), ST_REGULAR, dimC)
    else if (absCol + 1) mod 5 = 0 then
      Gfx.PutChar(col, 1, #$00B7, ST_REGULAR, dimC)
    else
      Gfx.HLine(col, 1, 1, Gfx.CellH - 3, MixColor(backC, textC, 30));
    if (absCol = lw) and Cfg.WrapView then
      Gfx.FillRectPx(Gfx.CellX(col), Gfx.CellY(1), 1, Gfx.CellH, dimC);
  end;
  if ccol >= 0 then
    Gfx.FillRectPx(Gfx.CellX(ccol - LeftCol), Gfx.CellY(1) + Gfx.CellH - 3, Gfx.CellW, 2, textC);
end;

procedure TApp.DrawHint;
var
  t: UnicodeString;
  dimC: LongWord;
begin
  dimC := RGBOf(Cfg.ColReturn);
  if CtrlMode then
    t := 'CONTROL: press a command key.  Esc or Ctrl cancels.'
  else if EscMode then
    t := 'ESCAPE: [ ] underline  ( ) bold  < > italic  # next sup  $ next sub  % ! sup/sub on  '' " off  . underline char  - hyphen  letter = phrase'
  else if SelKind = 2 then
    t := 'Phrase: Left/Right change it, S sentence, W word, Return sets it, Esc cancels'
  else if SelKind = 3 then
    t := 'Column: arrow keys size it, End or $ goes to the right edge, Return sets it, Esc cancels'
  else if SelKind = 1 then
    t := 'Range: Up/Down change it, Return sets it, Esc cancels'
  else
    if Gfx.Cols >= 92 then
      t := 'F1 Help   Ctrl+S Save   Ctrl+L Load   Ctrl+V Preview   Ctrl+O Output   Ctrl+Shift+X Quit'
    else
      t := 'F1 Help  ^S Save  ^L Load  ^V Preview  ^O Output  ^Shift+X Quit';
  Gfx.PutText(1, Gfx.Rows - 1, Copy(t, 1, Gfx.Cols - 2), dimC, ST_REGULAR);
end;

procedure TApp.DrawEditScreen;
begin
  DrawEditor;
  DrawStatus;
  DrawTabLine;
  DrawHint;
  if (not PromptActive) and (not Assigned(FullScreen)) then DrawCursor;
end;
