{ pcapp_blocks.inc - line ranges, phrases and columns (included by pcapp.pas) }

function NormalizeName(const name: string): string;
begin
  Result := Trim(name);
  if (Result <> '') and (ExtractFileExt(Result) = '') then Result := Result + '.pcl';
end;

function TApp.PhraseText: UnicodeString;
begin
  Result := Copy(Doc[Doc.PhP], Doc.PhC1 + 1, Doc.PhC2 - Doc.PhC1);
end;

{ The highlight-and-extend loop shared by Set Range, Set Phrase and Set Column. }
function TApp.RunSelect(kind: Integer; deleteAfter: Boolean): Boolean;
var
  ev: TKeyEv;
  s: UnicodeString;
  i, lo, hi, loc, hic, k, p: Integer;
  startC, startP: Integer;
  ch: WideChar;
  ok: Boolean;
  width: Integer;
begin
  Result := False;
  startP := Doc.CurP;
  startC := Doc.CurC;
  SelKind := kind;
  LayoutNow;
  case kind of
    1: SelP0 := Doc.CurP;
    2:
      begin
        s := Doc[Doc.CurP];
        if Doc.CurC >= Length(s) then
        begin
          SelKind := 0;
          SetMsg('Put the cursor on the first character of the phrase', True);
          Exit;
        end;
        SelP0 := Doc.CurP;
        SelC0 := Doc.CurC;
        SelC1 := Doc.CurC + 1;
      end;
    3:
      begin
        CursorRowCol(SelRow0, SelCol0);
        SelRow1 := SelRow0;
        SelCol1 := SelCol0;
      end;
  end;
  width := LayoutWidth;
  try
    while WaitKey(ev) do
    begin
      FollowCursor := True;
      LayoutNow;
      if ev.Kind = ekText then
      begin
        ch := ev.Text[1];
        case kind of
          2:
            begin
              s := Doc[SelP0];
              if (ch = 's') or (ch = 'S') then
              begin
                k := SelC1;
                while (k < Length(s)) and (s[k + 1] <> '.') and (s[k + 1] <> '!') and (s[k + 1] <> '?') do Inc(k);
                if k < Length(s) then Inc(k);
                SelC1 := k;
              end
              else if (ch = 'w') or (ch = 'W') then
              begin
                k := SelC1;
                while (k < Length(s)) and (s[k + 1] = ' ') do Inc(k);
                while (k < Length(s)) and (s[k + 1] <> ' ') do Inc(k);
                SelC1 := k;
              end;
            end;
          3:
            if ch = '$' then SelCol1 := width;
        end;
        Continue;
      end;
      if ev.Kind <> ekKey then Continue;
      case ev.Sym of
        SDLK_ESCAPE:
          begin
            SetMsg('Cancelled');
            Break;
          end;
        SDLK_RETURN, SDLK_KP_ENTER:
          begin
            case kind of
              1:
                begin
                  lo := SelP0; hi := Doc.CurP;
                  if lo > hi then begin k := lo; lo := hi; hi := k; end;
                  Doc.RangeSet := True;
                  Doc.RangeP1 := lo;
                  Doc.RangeP2 := hi;
                  SetMsg(UnicodeString(Format('Line range set: %d line(s)', [hi - lo + 1])));
                  Result := True;
                end;
              2:
                begin
                  Doc.PhP := SelP0;
                  Doc.PhC1 := SelC0;
                  Doc.PhC2 := SelC1;
                  Doc.PhraseSet := True;
                  if deleteAfter then
                  begin
                    Doc.PushUndo(0);
                    Doc.PhraseSet := False;
                    Doc.DelText(SelP0, SelC0, SelC1 - SelC0);
                    SetMsg('Phrase deleted (Ctrl+Z undoes)');
                  end
                  else
                  begin
                    Doc.CurP := SelP0;
                    Doc.CurC := SelC0;
                    SetMsg(UnicodeString(Format('Phrase set: %d character(s)', [SelC1 - SelC0])));
                  end;
                  Result := True;
                end;
              3:
                begin
                  lo := SelRow0; hi := SelRow1;
                  if lo > hi then begin k := lo; lo := hi; hi := k; end;
                  loc := SelCol0; hic := SelCol1;
                  if loc > hic then begin k := loc; loc := hic; hic := k; end;
                  ok := True;
                  for i := lo to hi do
                  begin
                    p := Doc.RowPara(i);
                    if Doc.ParaRows(p) <> 1 then
                    begin
                      ok := False;
                      Break;
                    end;
                  end;
                  if not ok then
                    SetMsg('A line in the column wraps onto several rows: widen it first (Ctrl+Shift+L sets the line length)', True)
                  else
                  begin
                    Doc.ColSet := True;
                    Doc.ColP1 := Doc.RowPara(lo);
                    Doc.ColP2 := Doc.RowPara(hi);
                    Doc.ColC1 := loc;
                    Doc.ColC2 := hic + 1;
                    Doc.CurP := Doc.ColP1;
                    Doc.CurC := loc;
                    if Doc.CurC > Length(Doc[Doc.CurP]) then Doc.CurC := Length(Doc[Doc.CurP]);
                    SetMsg(UnicodeString(Format('Column set: %d line(s), %d wide', [hi - lo + 1, hic - loc + 1])));
                    Result := True;
                  end;
                end;
            end;
            Break;
          end;
        SDLK_UP:
          case kind of
            1: MoveVert(-1);
            3: if SelRow1 > 0 then Dec(SelRow1);
          end;
        SDLK_DOWN:
          case kind of
            1: MoveVert(1);
            3: if SelRow1 < Doc.RowCount - 1 then Inc(SelRow1);
          end;
        SDLK_PAGEUP: if kind = 1 then PageMove(-1);
        SDLK_PAGEDOWN: if kind = 1 then PageMove(1);
        SDLK_HOME: if kind = 1 then GoTop;
        SDLK_END:
          case kind of
            1: GoBottom;
            3: SelCol1 := width;
          end;
        SDLK_RIGHT:
          case kind of
            2: if SelC1 < Length(Doc[SelP0]) then Inc(SelC1);
            3: if SelCol1 < width then Inc(SelCol1);
          end;
        SDLK_LEFT:
          case kind of
            2: if SelC1 > SelC0 + 1 then Dec(SelC1);
            3: if SelCol1 > 0 then Dec(SelCol1);
          end;
      end;
      if kind = 3 then
      begin
        { keep the real cursor near the active corner so the view follows it }
        MoveToRowCol(SelRow1, SelCol1);
      end
      else if kind = 2 then
      begin
        Doc.CurP := SelP0;
        Doc.CurC := SelC1;
      end;
    end;
  finally
    SelKind := 0;
  end;
  if (not Result) and (kind <> 1) then
  begin
    Doc.CurP := startP;
    Doc.CurC := startC;
  end;
end;

{ ---- line ranges ---- }

procedure TApp.RangeSet;
begin
  RunSelect(1, False);
end;

procedure TApp.RangeTransfer;
var
  r1, r2, n, p, i: Integer;
  lines: array of UnicodeString;
begin
  if not Doc.RangeSet then begin SetMsg('No Line Range set', True); Exit; end;
  r1 := Doc.RangeP1;
  r2 := Doc.RangeP2;
  n := r2 - r1 + 1;
  p := Doc.CurP;
  if (p >= r1) and (p <= r2) then
  begin
    SetMsg('You cannot move a range into itself: put the cursor outside it', True);
    Exit;
  end;
  Doc.PushUndo(0);
  SetLength(lines, n);
  for i := 0 to n - 1 do lines[i] := Doc[r1 + i];
  Doc.RangeSet := False;
  if p > r2 then
  begin
    for i := 0 to n - 1 do Doc.InsPara(p + i, lines[i]);
    Doc.DelParas(r1, n);
    Doc.CurP := p - n;
  end
  else
  begin
    Doc.DelParas(r1, n);
    for i := 0 to n - 1 do Doc.InsPara(p + i, lines[i]);
    Doc.CurP := p;
  end;
  Doc.CurC := 0;
  SetMsg(UnicodeString(Format('%d line(s) moved', [n])));
end;

procedure TApp.RangeCopy;
var
  n, cnt, p, k, i, at: Integer;
  lines: array of UnicodeString;
begin
  if not Doc.RangeSet then begin SetMsg('No Line Range set', True); Exit; end;
  p := Doc.CurP;
  if (p >= Doc.RangeP1) and (p <= Doc.RangeP2) then
  begin
    SetMsg('You cannot copy a range into itself: put the cursor outside it', True);
    Exit;
  end;
  n := 1;
  if not AskInt('Number of copies?', n, 1, 255) then Exit;
  cnt := Doc.RangeP2 - Doc.RangeP1 + 1;
  SetLength(lines, cnt);
  for i := 0 to cnt - 1 do lines[i] := Doc[Doc.RangeP1 + i];
  Doc.PushUndo(0);
  at := p;
  for k := 1 to n do
    for i := 0 to cnt - 1 do
    begin
      Doc.InsPara(at, lines[i]);
      Inc(at);
    end;
  Doc.CurP := p;
  Doc.CurC := 0;
  SetMsg(UnicodeString(Format('%d line(s) copied %d time(s)', [cnt, n])));
end;

procedure TApp.RangeDelete;
var
  n: Integer;
begin
  if not Doc.RangeSet then begin SetMsg('No Line Range set', True); Exit; end;
  if AskYN('Are you sure?') <> 1 then Exit;
  Doc.PushUndo(0);
  n := Doc.RangeP2 - Doc.RangeP1 + 1;
  Doc.CurP := Doc.RangeP1;
  Doc.CurC := 0;
  Doc.DelParas(Doc.RangeP1, n);
  Doc.RangeSet := False;
  if Doc.CurP >= Doc.Count then Doc.CurP := Doc.Count - 1;
  SetMsg(UnicodeString(Format('%d line(s) deleted (Ctrl+Z undoes)', [n])));
end;

procedure TApp.RangeSave;
var
  name: UnicodeString;
  fn, err: string;
  t: TDoc;
  i: Integer;
begin
  if not Doc.RangeSet then begin SetMsg('No Line Range set', True); Exit; end;
  name := '';
  if not Ask('Filename?', name, 0, False) then Exit;
  fn := NormalizeName(UTF8Encode(name));
  if fn = '' then Exit;
  fn := ResolvePath(fn);
  if FileExists(fn) and (AskYN('Replace existing file?') <> 1) then Exit;
  t := TDoc.Create;
  try
    t.SetText('');
    for i := Doc.RangeP1 to Doc.RangeP2 do
      if i = Doc.RangeP1 then t[0] := Doc[i] else t.InsPara(t.Count, Doc[i]);
    t.Tabs := Doc.Tabs;
    t.LineLen := Doc.LineLen;
    err := t.SaveToFile(fn, LowerCase(ExtractFileExt(fn)) <> '.txt');
  finally
    t.Free;
  end;
  if err <> '' then SetMsg(UnicodeString(err), True)
  else SetMsg(UnicodeString('Range saved as ' + ExtractFileName(fn)));
end;

{ ---- phrases ---- }

procedure TApp.PhraseSet(deleteNow: Boolean);
begin
  RunSelect(2, deleteNow);
end;

procedure TApp.PhraseMove;
var
  txt: UnicodeString;
begin
  if not Doc.PhraseSet then begin SetMsg('No Phrase set', True); Exit; end;
  if (Doc.CurP = Doc.PhP) and (Doc.CurC >= Doc.PhC1) and (Doc.CurC < Doc.PhC2) then
  begin
    SetMsg('You cannot move a phrase into itself: put the cursor outside it', True);
    Exit;
  end;
  Doc.PushUndo(0);
  txt := PhraseText;
  Doc.DelText(Doc.PhP, Doc.PhC1, Length(txt));
  Doc.PhraseSet := False;
  Doc.InsText(Doc.CurP, Doc.CurC, txt);
  SetMsg('Phrase moved');
  WantCol := -1;
end;

procedure TApp.PhraseCopy;
var
  txt: UnicodeString;
begin
  if not Doc.PhraseSet then begin SetMsg('No Phrase set', True); Exit; end;
  if (Doc.CurP = Doc.PhP) and (Doc.CurC >= Doc.PhC1) and (Doc.CurC < Doc.PhC2) then
  begin
    SetMsg('You cannot copy a phrase into itself: put the cursor outside it', True);
    Exit;
  end;
  Doc.PushUndo(0);
  txt := PhraseText;
  Doc.InsText(Doc.CurP, Doc.CurC, txt);
  SetMsg('Phrase copied');
  WantCol := -1;
end;

procedure TApp.PhraseCase;
var
  r: Integer;
  txt, s: UnicodeString;
begin
  if not Doc.PhraseSet then begin SetMsg('No Phrase set', True); Exit; end;
  r := AskYN('Change to upper case?');
  if r < 0 then Exit;
  Doc.PushUndo(0);
  txt := PhraseText;
  if r = 1 then txt := UpperCase(txt) else txt := LowerCase(txt);
  s := Doc[Doc.PhP];
  Delete(s, Doc.PhC1 + 1, Doc.PhC2 - Doc.PhC1);
  Insert(txt, s, Doc.PhC1 + 1);
  Doc.ReplaceText(Doc.PhP, s);
  SetMsg('Case changed');
end;

{ ---- columns ---- }

procedure TApp.ColumnSet;
begin
  RunSelect(3, False);
end;

procedure TApp.FinishColumnOp(const err: string);
begin
  if err <> '' then SetMsg(UnicodeString(err), True)
  else SetMsg('Done (Ctrl+Z undoes)');
  WantCol := -1;
end;

procedure TApp.ColumnDo(op: Char);
var
  n: Integer;
  err: string;
begin
  if not Doc.ColSet then begin SetMsg('Column not set', True); Exit; end;
  err := '';
  case op of
    'M':
      begin
        Doc.PushUndo(0);
        err := ColMove(Doc, Doc.CurP, Doc.CurC);
      end;
    'S':
      begin
        Doc.PushUndo(0);
        err := ColShift(Doc, Doc.CurP, Doc.CurC);
      end;
    'R':
      begin
        Doc.PushUndo(0);
        err := ColRepeat(Doc, Doc.CurP, Doc.CurC);
      end;
    'I':
      begin
        n := 1;
        if not AskInt('Number of spaces to insert?', n, 1, 255) then Exit;
        Doc.PushUndo(0);
        err := ColInsertSpaces(Doc, n, LayoutWidth);
        Doc.ColSet := False;
      end;
    'D':
      begin
        Doc.PushUndo(0);
        err := ColDelete(Doc);
      end;
    'E':
      begin
        Doc.PushUndo(0);
        err := ColErase(Doc);
      end;
  end;
  FinishColumnOp(err);
end;

procedure TApp.ColumnDecimals;
var
  n: Integer;
begin
  n := DecPlaces;
  if not AskInt('Number of decimal places? (0-38, 255 = as many as the numbers have)', n, 0, 255) then Exit;
  if (n > 38) and (n <> 255) then
  begin
    SetMsg('Use 0 to 38, or 255 for floating', True);
    Exit;
  end;
  DecPlaces := n;
  if n = 255 then SetMsg('Results show every decimal place')
  else SetMsg(UnicodeString(Format('Results show %d decimal place(s)', [n])));
end;

procedure TApp.ColumnSeps;
var
  s: UnicodeString;
begin
  s := FieldSeps;
  if not Ask('Field separators?', s, 2, True) then Exit;
  while Length(s) < 16 do s := s + ' ';
  FieldSeps := Copy(s, 1, 16);
  SetMsg('Field separators set');
end;

procedure TApp.ColumnSum(rows: Boolean);
var
  err: string;
  res: UnicodeString;
  results: TStrArray;
  ev: TKeyEv;
  i: Integer;
begin
  if not Doc.ColSet then begin SetMsg('Column not set', True); Exit; end;
  if not rows then
  begin
    err := ColSumDown(Doc, DecPlaces, res);
    if err <> '' then begin SetMsg(UnicodeString(err), True); Exit; end;
    SetMsg('Total ' + res + '   Return puts it in the text with the decimal point under the cursor; any other key drops it');
  end
  else
  begin
    err := ColSumRows(Doc, FieldSeps, DecPlaces, results);
    if err <> '' then begin SetMsg(UnicodeString(err), True); Exit; end;
    if Length(results) > 0 then
      SetMsg(UnicodeString(Format('%d row total(s), first %s.   Return places them under the cursor; any other key drops them',
        [Length(results), UTF8Encode(results[0])])));
  end;
  if not WaitKey(ev) then Exit;
  if (ev.Kind = ekKey) and ((ev.Sym = SDLK_RETURN) or (ev.Sym = SDLK_KP_ENTER)) then
  begin
    Doc.PushUndo(0);
    if not rows then PlaceResult(Doc, Doc.CurP, Doc.CurC, res)
    else
      for i := 0 to High(results) do
      begin
        if Doc.CurP + i >= Doc.Count then Doc.InsPara(Doc.Count, '');
        PlaceResult(Doc, Doc.CurP + i, Doc.CurC, results[i]);
      end;
    SetMsg('Result placed');
  end
  else
    SetMsg('Result dropped');
end;

procedure TApp.ColumnSort;
var
  fields: array of Integer;
  f, r: Integer;
  asc, ign: Boolean;
  err: string;
begin
  if not Doc.ColSet then begin SetMsg('Column not set', True); Exit; end;
  SetLength(fields, 0);
  repeat
    f := 1;
    if not AskInt('Field number?', f, 1, 17) then Exit;
    SetLength(fields, Length(fields) + 1);
    fields[High(fields)] := f;
    if Length(fields) >= 16 then Break;
    r := AskYN('More?');
    if r < 0 then Exit;
  until r = 0;
  r := AskYN('Ascending order?');
  if r < 0 then Exit;
  asc := r = 1;
  r := AskYN('Ignore leading spaces in fields?');
  if r < 0 then Exit;
  ign := r = 1;
  Doc.PushUndo(0);
  err := ColSort(Doc, fields, asc, ign, FieldSeps);
  FinishColumnOp(err);
end;

procedure TApp.ColumnFill;
var
  s: UnicodeString;
  ch: WideChar;
  err: string;
begin
  if not Doc.ColSet then begin SetMsg('Column not set', True); Exit; end;
  s := ' ';
  if not Ask('Character with which to fill column?', s, 3, True) then Exit;
  if s = '' then ch := ' ' else ch := s[1];
  Doc.PushUndo(0);
  err := ColFill(Doc, ch);
  FinishColumnOp(err);
end;
