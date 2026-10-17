{ pcapp_edit.inc - typing, cursor movement, tabs and line commands (included by pcapp.pas) }

function IsPrintableSym(sym: LongInt): Boolean;
begin
  Result := (sym >= 32) and (sym <= 126);
end;

function TApp.IsNumChar(ch: WideChar): Boolean;
begin
  Result := ((ch >= '0') and (ch <= '9')) or (ch = '-') or (ch = '(') or (ch = ')') or
            (ch = ',') or (ch = '$');
end;

procedure TApp.PadParaTo(p, c: Integer);
var
  s: UnicodeString;
begin
  s := Doc[p];
  if Length(s) < c then
  begin
    s := s + UnicodeString(StringOfChar(' ', c - Length(s)));
    Doc.ReplaceText(p, s);
  end;
end;

procedure TApp.InsertAtCursor(const s: UnicodeString);
begin
  if s = '' then Exit;
  Doc.PushUndo(0);
  if (not InsertMode) and (Doc.CurC < Length(Doc[Doc.CurP])) then
    Doc.DelText(Doc.CurP, Doc.CurC, Length(s));
  Doc.InsText(Doc.CurP, Doc.CurC, s);
  WantCol := -1;
end;

procedure TApp.NumericChar(ch: WideChar);
var
  s: UnicodeString;
  c, k: Integer;
begin
  Doc.PushUndo(1);
  c := Doc.CurC;
  PadParaTo(Doc.CurP, c);
  s := Doc[Doc.CurP];
  k := 0;
  while (k < c) and IsNumChar(s[c - k]) do Inc(k);
  if (k < c) and (s[c - k] = ' ') then
  begin
    { slide the number left by one and drop the new digit in beside the cursor }
    Delete(s, c - k, 1);
    Insert(ch, s, c);
    Doc.ReplaceText(Doc.CurP, s);
  end
  else
  begin
    Insert(ch, s, c + 1);
    Doc.ReplaceText(Doc.CurP, s);
    Inc(Doc.CurC);
  end;
end;

procedure TApp.InsertTyped(const s: UnicodeString);
var
  i: Integer;
  ch: WideChar;
begin
  for i := 1 to Length(s) do
  begin
    ch := s[i];
    if ch < ' ' then Continue;
    if NumMode then
    begin
      if IsNumChar(ch) then
      begin
        NumericChar(ch);
        Continue;
      end;
      NumMode := False;
    end;
    if ch = '\' then ch := CH_CHECK;
    Doc.PushUndo(1);
    if (not InsertMode) and (Doc.CurC < Length(Doc[Doc.CurP])) then
      Doc.DelText(Doc.CurP, Doc.CurC, 1);
    Doc.InsText(Doc.CurP, Doc.CurC, ch);
    WantCol := -1;
  end;
end;

{ ---- movement ---- }

procedure TApp.MoveToRowCol(row, col: Integer);
var
  p, c: Integer;
begin
  LayoutNow;
  Doc.RowColToPos(row, col, p, c);
  Doc.CurP := p;
  Doc.CurC := c;
end;

procedure TApp.MoveVert(delta: Integer);
var
  row, col, nr: Integer;
begin
  Doc.BreakGroup;
  NumMode := False;
  CursorRowCol(row, col);
  if WantCol < 0 then WantCol := col;
  nr := row + delta;
  if nr < 0 then nr := 0;
  if nr > Doc.RowCount - 1 then nr := Doc.RowCount - 1;
  MoveToRowCol(nr, WantCol);
end;

procedure TApp.MoveLeft;
begin
  Doc.BreakGroup;
  NumMode := False;
  WantCol := -1;
  if Doc.CurC > 0 then Dec(Doc.CurC)
  else if Doc.CurP > 0 then
  begin
    Dec(Doc.CurP);
    Doc.CurC := Length(Doc[Doc.CurP]);
  end;
end;

procedure TApp.MoveRight;
begin
  Doc.BreakGroup;
  NumMode := False;
  WantCol := -1;
  if Doc.CurC < Length(Doc[Doc.CurP]) then Inc(Doc.CurC)
  else if Doc.CurP < Doc.Count - 1 then
  begin
    Inc(Doc.CurP);
    Doc.CurC := 0;
  end;
end;

procedure TApp.MoveWordLeft;
var
  s: UnicodeString;
begin
  Doc.BreakGroup;
  WantCol := -1;
  if Doc.CurC = 0 then
  begin
    MoveLeft;
    Exit;
  end;
  s := Doc[Doc.CurP];
  while (Doc.CurC > 0) and (s[Doc.CurC] = ' ') do Dec(Doc.CurC);
  while (Doc.CurC > 0) and (s[Doc.CurC] <> ' ') do Dec(Doc.CurC);
end;

procedure TApp.MoveWordRight;
var
  s: UnicodeString;
begin
  Doc.BreakGroup;
  WantCol := -1;
  s := Doc[Doc.CurP];
  if Doc.CurC >= Length(s) then
  begin
    MoveRight;
    Exit;
  end;
  while (Doc.CurC < Length(s)) and (s[Doc.CurC + 1] <> ' ') do Inc(Doc.CurC);
  while (Doc.CurC < Length(s)) and (s[Doc.CurC + 1] = ' ') do Inc(Doc.CurC);
end;

procedure TApp.GoTop;
begin
  Doc.BreakGroup;
  NumMode := False;
  Doc.CurP := 0;
  Doc.CurC := 0;
  WantCol := -1;
end;

procedure TApp.GoBottom;
begin
  Doc.BreakGroup;
  NumMode := False;
  Doc.CurP := Doc.Count - 1;
  Doc.CurC := Length(Doc[Doc.CurP]);
  WantCol := -1;
end;

procedure TApp.PageMove(dir: Integer);
begin
  MoveVert(dir * (TextRows - 1));
end;

procedure TApp.NextLineStart;
var
  row, col: Integer;
begin
  Doc.BreakGroup;
  CursorRowCol(row, col);
  if row < Doc.RowCount - 1 then MoveToRowCol(row + 1, 0);
  WantCol := -1;
end;

procedure TApp.SetBookmark;
begin
  MarkC[Doc.MarkNext] := Doc.CurC;
  Doc.MarkP[Doc.MarkNext] := Doc.CurP;
  SetMsg(UnicodeString(Format('Bookmark %d set', [Doc.MarkNext + 1])));
  Doc.MarkNext := 1 - Doc.MarkNext;
end;

procedure TApp.GotoBookmark;
var
  i, n: Integer;
begin
  Doc.BreakGroup;
  if (Doc.MarkP[0] < 0) and (Doc.MarkP[1] < 0) then
  begin
    SetMsg('No bookmark set (Esc then F5 sets one)', True);
    Exit;
  end;
  { alternate between the two bookmarks }
  n := JumpIdx;
  for i := 1 to 2 do
  begin
    n := 1 - n;
    if Doc.MarkP[n] >= 0 then
    begin
      Doc.CurP := Doc.MarkP[n];
      Doc.CurC := MarkC[n];
      if Doc.CurC > Length(Doc[Doc.CurP]) then Doc.CurC := Length(Doc[Doc.CurP]);
      JumpIdx := n;
      WantCol := -1;
      Exit;
    end;
  end;
end;

{ ---- editing ---- }

procedure TApp.DoReturn;
var
  rest: Integer;
begin
  NumMode := False;
  Doc.PushUndo(0);
  if SelActive then DeleteSelection;
  if not InsertMode then
  begin
    rest := Length(Doc[Doc.CurP]) - Doc.CurC;
    if rest > 0 then Doc.DelText(Doc.CurP, Doc.CurC, rest);
  end;
  Doc.SplitPara(Doc.CurP, Doc.CurC);
  WantCol := -1;
end;

procedure TApp.DoBackspace;
begin
  if SelActive then
  begin
    Doc.PushUndo(0);
    DeleteSelection;
    Exit;
  end;
  Doc.PushUndo(2);
  WantCol := -1;
  if Doc.CurC > 0 then Doc.DelText(Doc.CurP, Doc.CurC - 1, 1)
  else if Doc.CurP > 0 then Doc.JoinPara(Doc.CurP - 1);
end;

procedure TApp.DoDelete;
begin
  if SelActive then
  begin
    Doc.PushUndo(0);
    DeleteSelection;
    Exit;
  end;
  Doc.PushUndo(2);
  WantCol := -1;
  if Doc.CurC < Length(Doc[Doc.CurP]) then Doc.DelText(Doc.CurP, Doc.CurC, 1)
  else if Doc.CurP < Doc.Count - 1 then Doc.JoinPara(Doc.CurP);
end;

procedure TApp.DoTab(numericOnly: Boolean);
var
  row, col, nxt, c, rowStart, first: Integer;
begin
  Doc.BreakGroup;
  if Doc.TabCount = 0 then
  begin
    { no tab stops set: behave like a text editor and move to the next multiple of 8 }
    if numericOnly then
    begin
      SetMsg('No numeric tab stops set (Ctrl+N sets one)', True);
      Exit;
    end;
    CursorRowCol(row, col);
    c := Doc.CurC - col + ((col div 8) + 1) * 8;
    PadParaTo(Doc.CurP, c);
    Doc.CurC := c;
    WantCol := -1;
    NumMode := False;
    Exit;
  end;
  CursorRowCol(row, col);
  nxt := Doc.NextTab(col, numericOnly);
  if nxt < 0 then
  begin
    { no more tabs on this line: go to the leftmost tab on the next line down }
    first := Doc.NextTab(-1, numericOnly);
    if first < 0 then
    begin
      SetMsg('No numeric tab stops set', True);
      Exit;
    end;
    if Doc.CurP >= Doc.Count - 1 then Doc.InsPara(Doc.Count, '');
    Inc(Doc.CurP);
    Doc.CurC := 0;
    nxt := first;
    rowStart := 0;
  end
  else
    rowStart := Doc.CurC - col;
  { reaching the tab column may mean padding the line with spaces }
  c := rowStart + nxt;
  PadParaTo(Doc.CurP, c);
  Doc.CurC := c;
  WantCol := -1;
  NumMode := (Doc.Tabs[nxt] and TAB_NUM) <> 0;
end;

procedure TApp.ToggleTab(numeric: Boolean);
var
  row, col: Integer;
  bit: Byte;
begin
  CursorRowCol(row, col);
  if col > MAXWIDTH then Exit;
  if numeric then bit := TAB_NUM else bit := TAB_REG;
  Doc.Tabs[col] := Doc.Tabs[col] xor bit;
  Doc.Modified := True;
  if numeric and ((Doc.Tabs[col] and TAB_NUM) <> 0) then
  begin
    NumMode := True;
    SetMsg('Numeric tab set: digits now line up on the decimal point');
  end
  else if numeric then
    SetMsg('Numeric tab removed')
  else if (Doc.Tabs[col] and TAB_REG) <> 0 then SetMsg('Tab set')
  else SetMsg('Tab removed');
end;

procedure TApp.ClearTabs;
begin
  FillChar(Doc.Tabs, SizeOf(Doc.Tabs), 0);
  Doc.Modified := True;
  NumMode := False;
  SetMsg('All tab stops cleared');
end;

procedure TApp.DoInsertLine;
var
  p: Integer;
begin
  Doc.PushUndo(0);
  p := Doc.CurP;
  Doc.InsPara(p, '');
  Doc.CurP := p;
  Doc.CurC := 0;
end;

procedure TApp.DoDeleteLine;
begin
  Doc.PushUndo(0);
  Doc.DelParas(Doc.CurP, 1);
  if Doc.CurP >= Doc.Count then Doc.CurP := Doc.Count - 1;
  Doc.CurC := 0;
  SetMsg('Line deleted (Ctrl+Z undoes)');
end;

procedure TApp.DoInsertLines;
var
  n, i, p: Integer;
begin
  n := 1;
  if not AskInt('Number of Lines to insert?', n, 1, 255) then Exit;
  Doc.PushUndo(0);
  p := Doc.CurP;
  for i := 1 to n do Doc.InsPara(p, '');
  Doc.CurP := p;
  Doc.CurC := 0;
end;

procedure TApp.DoEraseText;
var
  r: Integer;
begin
  if Doc.RangeSet then
  begin
    r := AskYN('Erase range only?');
    if r < 0 then Exit;
    if r = 1 then
    begin
      Doc.PushUndo(0);
      for r := Doc.RangeP1 to Doc.RangeP2 do Doc.ReplaceText(r, '');
      Doc.RangeSet := False;
      SetMsg('Range erased');
      Exit;
    end;
  end
  else
  begin
    if AskYN('Are you sure?') <> 1 then Exit;
  end;
  Doc.PushUndo(0);
  r := Doc.CurP;
  Doc.DelParas(r, Doc.Count - r);
  Doc.CurP := Doc.Count - 1;
  if Doc.CurP < 0 then Doc.CurP := 0;
  Doc.CurC := 0;
  SetMsg('Text erased (Ctrl+Z undoes)');
end;

procedure TApp.SetLineLength;
var
  n: Integer;
begin
  n := Doc.LineLen;
  if not AskInt('Line length? (0 = fit the window, else 20-' + UnicodeString(IntToStr(MAXWIDTH)) + ')', n, 0, MAXWIDTH) then Exit;
  if (n > 0) and (n < 20) then
  begin
    SetMsg('The line length must be at least 20', True);
    Exit;
  end;
  Doc.LineLen := n;
  Doc.Modified := True;
  LeftCol := 0;
  if n = 0 then SetMsg('Line length follows the window')
  else SetMsg(UnicodeString(Format('Line length set to %d (saved with the document)', [n])));
end;

procedure TApp.Undo;
begin
  if Doc.Undo then SetMsg('Undone') else SetMsg('Nothing to undo', True);
  WantCol := -1;
end;

procedure TApp.Redo;
begin
  if Doc.Redo then SetMsg('Redone') else SetMsg('Nothing to redo', True);
  WantCol := -1;
end;

{ ---- clipboard (a modern extra) ---- }

procedure TApp.ClipCopy(cut: Boolean);
var
  txt: UnicodeString;
  i, sl1, sl2, sl3, sl4: Integer;
  u: UTF8String;
begin
  txt := '';
  if SelActive and SelBounds(sl1, sl2, sl3, sl4) then txt := SelText
  else if Doc.PhraseSet then txt := PhraseText
  else if Doc.RangeSet then
  begin
    for i := Doc.RangeP1 to Doc.RangeP2 do txt := txt + Doc[i] + #10;
  end
  else
  begin
    SetMsg('Set a phrase (Ctrl+P) or a range (Ctrl+R) first', True);
    Exit;
  end;
  u := UTF8Encode(StripMarkers(txt));
  SDL_SetClipboardText(PAnsiChar(u));
  if cut then
  begin
    Doc.PushUndo(0);
    if SelActive then DeleteSelection
    else if Doc.PhraseSet then
    begin
      Doc.DelText(Doc.PhP, Doc.PhC1, Doc.PhC2 - Doc.PhC1);
      Doc.PhraseSet := False;
    end
    else
    begin
      Doc.DelParas(Doc.RangeP1, Doc.RangeP2 - Doc.RangeP1 + 1);
      Doc.RangeSet := False;
    end;
    SetMsg('Cut to the clipboard');
  end
  else
    SetMsg('Copied to the clipboard');
end;

procedure TApp.ClipPaste;
var
  pc: PAnsiChar;
  txt: UnicodeString;
  i, st: Integer;
begin
  pc := SDL_GetClipboardText();
  if pc = nil then Exit;
  txt := UTF8Decode(string(pc));
  SDL_free(pc);
  txt := UnicodeString(StringReplace(UTF8Encode(txt), #9, '    ', [rfReplaceAll]));
  if txt = '' then
  begin
    SetMsg('The clipboard is empty', True);
    Exit;
  end;
  Doc.PushUndo(0);
  if SelActive then DeleteSelection;
  st := 1;
  i := 1;
  while i <= Length(txt) + 1 do
  begin
    if (i > Length(txt)) or (txt[i] = #10) or (txt[i] = #13) then
    begin
      Doc.InsText(Doc.CurP, Doc.CurC, Copy(txt, st, i - st));
      if i <= Length(txt) then
      begin
        if (txt[i] = #13) and (i < Length(txt)) and (txt[i + 1] = #10) then Inc(i);
        Doc.SplitPara(Doc.CurP, Doc.CurC);
      end;
      st := i + 1;
    end;
    Inc(i);
  end;
  SetMsg('Pasted');
  WantCol := -1;
end;

{ ---- keys ---- }

procedure TApp.EscChar(const s: UnicodeString);
var
  ch: WideChar;
  m: UnicodeString;
  i: Integer;
  found: Boolean;
  t: UnicodeString;
begin
  if s = '' then Exit;
  ch := s[1];
  if EscToMarker(ch, m) then
  begin
    InsertAtCursor(m);
    Exit;
  end;
  if ((ch >= 'a') and (ch <= 'z')) or ((ch >= 'A') and (ch <= 'Z')) then
  begin
    { instant phrase: the first line of the form  checkmark, key, =, text }
    found := False;
    for i := 0 to Doc.Count - 1 do
    begin
      t := Doc[i];
      if (Length(t) >= 3) and (t[1] = CH_CHECK) and (t[2] = ch) and (t[3] = '=') then
      begin
        InsertAtCursor(Copy(t, 4, MaxInt));
        found := True;
        Break;
      end;
    end;
    if not found then
      SetMsg('No instant phrase defined for ' + ch + ' (define one with a line like  \' + ch + '=text)', True);
    Exit;
  end;
  SetMsg('Not an Esc code', True);
end;

procedure TApp.CtrlCommand(ch: WideChar);
begin
  FollowCursor := True;
  if ch <> 'b' then SelActive := False;
  case ch of
    'r': RangeSet;
    't': RangeTransfer;
    'c': RangeCopy;
    'd': RangeDelete;
    'e': DoEraseText;
    'q': RangeSave;
    'p': PhraseSet(False);
    'y': PhraseSet(True);
    'm': PhraseMove;
    'k': PhraseCopy;
    'K': PhraseCase;
    'C': ColumnSet;
    'M', 'S', 'R', 'I', 'D', 'E': ColumnDo(Char(Ord(ch)));
    '=': ColumnSum(False);
    'H': ColumnSum(True);
    '.': ColumnDecimals;
    'A': ColumnSort;
    'Q': ColumnSeps;
    'W': ColumnFill;
    'n': ToggleTab(True);
    'L': SetLineLength;
    'X': if TryQuit then Done := True;
    '-': DoDeleteLine;
    '+': DoInsertLine;
    'i': DoInsertLines;
    'u': DoUnformat;
    '@': DoReplace;
    'f': DoFind;
    'h': DoHunt;
    'o': DoOutput(False);
    'O': DoOutput(True);
    'v': DoPreview;
    's': DoSave;
    'l': DoLoad;
    'a': DoAppend;
    '0': DoDirectory(0);
    '1': DoDirectory(1);
    '3': DoDirectory(3);
    'z': Undo;
    'Z': Redo;
    'Y': DoSpell;
    'b': ToggleStyle('B');
    '!': InsertAtCursor(CH_BREAK);
  else
    SetMsg('Control ' + ch + ' is not a TiePaper command (F1 lists them)', True);
  end;
end;

procedure TApp.HandleKeyInner(const ev: TKeyEv);
var
  ch: WideChar;
begin
  FollowCursor := True;
  FlashP := -1;
  Msg := '';
  if ev.Sym = SYM_CTRLTAP then
  begin
    CtrlMode := not CtrlMode;
    EscMode := False;
    Exit;
  end;
  { keys that follow the Esc prefix }
  if EscMode then
  begin
    if IsPrintableSym(ev.Sym) and (not ev.Ctrl) then Exit;      { the text event carries the character }
    EscMode := False;
    case ev.Sym of
      SDLK_TAB: DoTab(True);
      SDLK_F5: SetBookmark;
    end;
    Exit;
  end;
  if CtrlMode or ev.Ctrl then
  begin
    if CtrlMode and (not ev.Ctrl) and IsPrintableSym(ev.Sym) then Exit;
    CtrlMode := False;
    case ev.Sym of
      SDLK_UP: MoveVert(-8);
      SDLK_DOWN: MoveVert(8);
      SDLK_LEFT: MoveWordLeft;
      SDLK_RIGHT: MoveWordRight;
      SDLK_HOME: GoTop;
      SDLK_END: GoBottom;
      SDLK_F6: ClearTabs;
      SDLK_INSERT: ClipCopy(False);
      SDLK_PAGEUP: MoveVert(-(TextRows - 1) * 3);
      SDLK_PAGEDOWN: MoveVert((TextRows - 1) * 3);
      SDLK_DELETE:
        begin
          Doc.PushUndo(0);
          Doc.DelText(Doc.CurP, Doc.CurC, Length(Doc[Doc.CurP]) - Doc.CurC);
        end;
      SDLK_ESCAPE: ;
      SDLK_RETURN, SDLK_KP_ENTER: ;
    else
      begin
        ch := KeyToCtrlChar(ev.Sym, ev.Shift);
        if ch <> #0 then CtrlCommand(ch)
        else SetMsg('Unknown control key', True);
      end;
    end;
    Exit;
  end;
  if ev.Alt then
  begin
    SwallowText := True;
    SwallowUntil := SDL_GetTicks() + 150;
    case ev.Sym of
      Ord('b'): ToggleStyle('B');
      Ord('i'): ToggleStyle('I');
      Ord('u'): ToggleStyle('U');
      Ord('a'): SelectAll;
      Ord('c'): ClipCopy(False);
      Ord('x'): ClipCopy(True);
      Ord('v'): ClipPaste;
    end;
    Exit;
  end;
  case ev.Sym of
    SDLK_RETURN, SDLK_KP_ENTER:
      if ev.Shift then NextLineStart else DoReturn;
    SDLK_BACKSPACE: DoBackspace;
    SDLK_DELETE: if ev.Shift then ClipCopy(True) else DoDelete;
    SDLK_TAB: DoTab(False);
    SDLK_ESCAPE: EscMode := True;
    SDLK_LEFT: MoveLeft;
    SDLK_RIGHT: MoveRight;
    SDLK_UP: MoveVert(-1);
    SDLK_DOWN: MoveVert(1);
    SDLK_HOME:
      begin
        Doc.BreakGroup;
        LayoutNow;
        MoveToRowCol(CurRow, 0);
        WantCol := -1;
      end;
    SDLK_END:
      begin
        Doc.BreakGroup;
        LayoutNow;
        MoveToRowCol(CurRow, 100000);
        WantCol := -1;
      end;
    SDLK_PAGEUP: PageMove(-1);
    SDLK_PAGEDOWN: PageMove(1);
    SDLK_INSERT: if ev.Shift then ClipPaste else InsertMode := not InsertMode;
    SDLK_F6: ToggleTab(False);
    SDLK_SPACE:
      if ev.Shift then
      begin
        InsertAtCursor(CH_HARDSPACE);
        SwallowText := True;
        SwallowUntil := SDL_GetTicks() + 150;
      end;
    SDLK_F1: DoHelp;
    SDLK_F2: DoScreenMenu;
    SDLK_F4: DoFileMenu;
    SDLK_F5: GotoBookmark;
    SDLK_F7:
      begin
        Cfg.WrapView := not Cfg.WrapView;
        LeftCol := 0;
        if Cfg.WrapView then SetMsg('Word wrap on') else SetMsg('Word wrap off: lines scroll sideways');
      end;
    SDLK_F9: DoPreview;
    SDLK_F10: DoOutput(False);
  end;
end;

procedure TApp.HandleText(const s: UnicodeString);
begin
  FollowCursor := True;
  FlashP := -1;
  Msg := '';
  if EscMode then
  begin
    EscMode := False;
    SelActive := False;
    EscChar(s);
    Exit;
  end;
  if CtrlMode then
  begin
    CtrlMode := False;
    CtrlCommand(s[1]);
    Exit;
  end;
  if SelActive then
  begin
    { typing over a selection replaces it (one undo step) }
    Doc.PushUndo(1);
    DeleteSelection;
  end;
  InsertTyped(s);
end;

{ ---- text selection: Shift+arrows, mouse drag, double-click, Alt+A ---- }

procedure TApp.BeginSel;
begin
  if not SelActive then
  begin
    SelAP := Doc.CurP;
    SelAC := Doc.CurC;
    SelActive := True;
  end;
end;

procedure TApp.EndSel;
begin
  if SelActive and (Doc.CurP = SelAP) and (Doc.CurC = SelAC) then SelActive := False;
end;

{ ordered, clamped ends of the selection; False when nothing is selected }
function TApp.SelBounds(out loP, loC, hiP, hiC: Integer): Boolean;
var
  ap, ac, cp, cc: Integer;
begin
  Result := False;
  loP := 0; loC := 0; hiP := 0; hiC := 0;
  if not SelActive then Exit;
  ap := SelAP; ac := SelAC;
  if ap >= Doc.Count then begin ap := Doc.Count - 1; ac := Length(Doc[ap]); end;
  if ac > Length(Doc[ap]) then ac := Length(Doc[ap]);
  cp := Doc.CurP; cc := Doc.CurC;
  if (ap < cp) or ((ap = cp) and (ac <= cc)) then
  begin
    loP := ap; loC := ac; hiP := cp; hiC := cc;
  end
  else
  begin
    loP := cp; loC := cc; hiP := ap; hiC := ac;
  end;
  Result := (loP <> hiP) or (loC <> hiC);
end;

function TApp.SelText: UnicodeString;
var
  loP, loC, hiP, hiC, p: Integer;
begin
  Result := '';
  if not SelBounds(loP, loC, hiP, hiC) then Exit;
  if loP = hiP then Exit(Copy(Doc[loP], loC + 1, hiC - loC));
  Result := Copy(Doc[loP], loC + 1, MaxInt) + #10;
  for p := loP + 1 to hiP - 1 do Result := Result + Doc[p] + #10;
  Result := Result + Copy(Doc[hiP], 1, hiC);
end;

procedure TApp.DeleteSelection;
var
  loP, loC, hiP, hiC: Integer;
begin
  if not SelBounds(loP, loC, hiP, hiC) then
  begin
    SelActive := False;
    Exit;
  end;
  SelActive := False;
  if loP = hiP then
    Doc.DelText(loP, loC, hiC - loC)
  else
  begin
    Doc.DelText(hiP, 0, hiC);
    Doc.DelText(loP, loC, Length(Doc[loP]) - loC);
    if hiP - loP > 1 then Doc.DelParas(loP + 1, hiP - loP - 1);
    Doc.JoinPara(loP);
  end;
  Doc.CurP := loP;
  Doc.CurC := loC;
  WantCol := -1;
  NumMode := False;
end;

procedure TApp.SelectWordAt(p, c: Integer);
var
  s: UnicodeString;
  a, b: Integer;

  function W(k: Integer): Boolean;      { k is a 0-based index }
  begin
    Result := (k >= 0) and (k < Length(s)) and
              (TCharacter.IsLetterOrDigit(s[k + 1]) or (s[k + 1] = '_') or (s[k + 1] = #39));
  end;

begin
  s := Doc[p];
  if Length(s) = 0 then Exit;
  if c >= Length(s) then c := Length(s) - 1;
  a := c;
  b := c;
  if W(c) then
  begin
    while W(a - 1) do Dec(a);
    while W(b) do Inc(b);
  end
  else
    b := c + 1;
  SelAP := p;
  SelAC := a;
  Doc.CurP := p;
  Doc.CurC := b;
  SelActive := b > a;
end;

procedure TApp.SelectAll;
begin
  SelAP := 0;
  SelAC := 0;
  Doc.CurP := Doc.Count - 1;
  Doc.CurC := Length(Doc[Doc.CurP]);
  SelActive := (Doc.Count > 1) or (Doc.CurC > 0);
  SetMsg('Everything selected: type to replace it, Alt+C copies, Esc cancels');
end;

function TApp.PixelToPos(x, y: Integer; out p, c: Integer): Boolean;
var
  col, row: Integer;
begin
  Result := False;
  LayoutNow;
  col := (x - Gfx.Border) div Gfx.CellW;
  if x < Gfx.Border then col := 0;
  row := (y - Gfx.Border) div Gfx.CellH - TextTop;
  if y < Gfx.Border then row := -1;
  if row < 0 then row := -1;
  if row >= TextRows then row := TextRows;
  row := TopRow + row;
  if row < 0 then row := 0;
  if row >= Doc.RowCount then row := Doc.RowCount - 1;
  if col + LeftCol < 0 then col := -LeftCol;
  Doc.RowColToPos(row, col + LeftCol, p, c);
  Result := True;
end;

procedure TApp.HandleClick(x, y, clicks: Integer; shift: Boolean);
var
  p, c, row: Integer;
begin
  FollowCursor := True;
  Msg := '';
  Doc.BreakGroup;
  NumMode := False;
  row := (y - Gfx.Border) div Gfx.CellH;
  if (row < TextTop) or (row >= TextTop + TextRows) then Exit;
  if not PixelToPos(x, y, p, c) then Exit;
  WantCol := -1;
  if shift then
  begin
    BeginSel;
    Doc.CurP := p;
    Doc.CurC := c;
    EndSel;
    Exit;
  end;
  SelActive := False;
  Doc.CurP := p;
  Doc.CurC := c;
  if clicks >= 2 then
  begin
    SelectWordAt(p, c);
    DragOn := False;
  end
  else
  begin
    DragOn := True;
    DragAP := p;
    DragAC := c;
  end;
end;

procedure TApp.HandleDrag(x, y: Integer);
var
  p, c: Integer;
begin
  if not DragOn then Exit;
  FollowCursor := True;
  if not PixelToPos(x, y, p, c) then Exit;
  SelAP := DragAP;
  SelAC := DragAC;
  Doc.CurP := p;
  Doc.CurC := c;
  SelActive := (p <> DragAP) or (c <> DragAC);
  WantCol := -1;
end;

function IsMoveSym(sym: LongInt): Boolean;
begin
  Result := (sym = SDLK_LEFT) or (sym = SDLK_RIGHT) or (sym = SDLK_UP) or (sym = SDLK_DOWN) or
            (sym = SDLK_HOME) or (sym = SDLK_END) or (sym = SDLK_PAGEUP) or (sym = SDLK_PAGEDOWN);
end;

{ Wraps the key handler: Shift with a movement key extends the selection, any other key that
  does not edit the selection drops it. }
procedure TApp.HandleKey(const ev: TKeyEv);
var
  mv, began, keep: Boolean;
begin
  mv := IsMoveSym(ev.Sym) and (not ev.Alt) and (not EscMode);
  began := False;
  keep := (ev.Sym = SDLK_RETURN) or (ev.Sym = SDLK_KP_ENTER) or (ev.Sym = SDLK_BACKSPACE) or
          (ev.Sym = SDLK_DELETE) or (ev.Sym = SDLK_INSERT) or ev.Alt or CtrlMode or
          (ev.Ctrl and (ev.Sym = Ord('b'))) or (ev.Sym = SYM_CTRLTAP);
  if SelActive and (ev.Sym = SDLK_ESCAPE) and (not EscMode) and (not ev.Ctrl) then
  begin
    SelActive := False;
    SetMsg('Selection cleared');
    Exit;
  end;
  if mv then
  begin
    if ev.Shift then
    begin
      BeginSel;
      began := True;
    end
    else SelActive := False;
  end
  else if not keep then SelActive := False;
  HandleKeyInner(ev);
  if began then EndSel;
end;

function TApp.CurRow: Integer;
var
  row, col: Integer;
begin
  CursorRowCol(row, col);
  Result := row;
end;

function TApp.TryQuit: Boolean;
var
  c: WideChar;
begin
  Result := True;
  if not Doc.Modified then Exit;
  c := AskChoice('Text not saved:  S)ave   D)iscard   C)ancel', 'SDC');
  case c of
    'S':
      begin
        DoSave;
        Result := not Doc.Modified;
      end;
    'D': Result := True;
  else
    Result := False;
  end;
end;
