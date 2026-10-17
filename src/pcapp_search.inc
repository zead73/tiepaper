{ pcapp_search.inc - find, hunt, search and replace, unformat (included by pcapp.pas) }

function IsAbsPath(const name: string): Boolean;
begin
  Result := (name <> '') and ((name[1] = PathDelim) or (name[1] = '/') or
            ((Length(name) > 1) and (name[2] = ':')) or (name[1] = '~'));
end;

function TApp.DocDir: string;
begin
  if Doc.FileName <> '' then Result := ExtractFilePath(ExpandFileName(Doc.FileName))
  else if LastDir <> '' then Result := IncludeTrailingPathDelimiter(LastDir)
  else Result := IncludeTrailingPathDelimiter(GetCurrentDir);
end;

function TApp.ResolvePath(const name: string): string;
var
  home: string;
begin
  Result := name;
  if (Result <> '') and (Result[1] = '~') then
  begin
    home := SysUtils.GetEnvironmentVariable({$IFDEF WINDOWS}'USERPROFILE'{$ELSE}'HOME'{$ENDIF});
    Result := IncludeTrailingPathDelimiter(home) + Copy(Result, 3, MaxInt);
  end;
  if not IsAbsPath(Result) then Result := DocDir + Result;
end;

{ A document that ends with a global link (checkmark nx:name) names the next file. }
function TApp.ChainNext(out name: string): Boolean;
var
  i: Integer;
  s: UnicodeString;
begin
  Result := False;
  name := '';
  for i := Doc.Count - 1 downto Doc.Count - 2 do
  begin
    if i < 0 then Break;
    s := Doc[i];
    if IsFormatLine(s) and (Length(s) >= 4) and (LowerCase(Copy(s, 2, 2)) = 'nx') then
    begin
      name := Trim(UTF8Encode(Copy(s, 4, MaxInt)));
      if (name <> '') and (name[1] = ':') then Delete(name, 1, 1);
      name := Trim(name);
      Result := name <> '';
      Exit;
    end;
    if Trim(UTF8Encode(s)) <> '' then Break;
  end;
end;

function TApp.FindFrom(var p, c: Integer; const pat: TPattern; out mlen: Integer): Boolean;
var
  i, fromC, pos_: Integer;
begin
  Result := False;
  mlen := 0;
  for i := p to Doc.Count - 1 do
  begin
    if i = p then fromC := c else fromC := 0;
    if FindIn(pat, Doc[i], fromC, pos_, mlen) then
    begin
      p := i;
      c := pos_;
      Exit(True);
    end;
  end;
end;

procedure TApp.HuntNext;
var
  pat: TPattern;
  p, c, mlen, r: Integer;
  nm: string;
begin
  if LastSearch = '' then
  begin
    SetMsg('No search string', True);
    Exit;
  end;
  pat := CompilePattern(LastSearch);
  p := Doc.CurP;
  c := Doc.CurC;
  repeat
    if FindFrom(p, c, pat, mlen) then
    begin
      Doc.CurP := p;
      Doc.CurC := c + mlen;
      FlashP := p;
      FlashC1 := c;
      FlashC2 := c + mlen;
      WantCol := -1;
      SetMsg('Found');
      Exit;
    end;
    if ChainNext(nm) then
    begin
      r := AskYN('Fetch next file?');
      if r = 1 then
      begin
        if not ConfirmDiscard then Exit;
        if not LoadPath(ResolvePath(nm), True) then Exit;
        p := 0;
        c := 0;
        Continue;
      end;
    end;
    SetMsg('Search ended');
    Exit;
  until False;
end;

procedure TApp.DoFind;
var
  s: UnicodeString;
begin
  s := LastSearch;
  if not Ask('Search string?', s, 1, True) then Exit;
  if s = '' then
  begin
    SetMsg('No search string', True);
    Exit;
  end;
  LastSearch := s;
  HuntNext;
end;

procedure TApp.DoHunt;
begin
  HuntNext;
end;

type
  TReplPair = record
    Search, Repl: UnicodeString;
  end;

procedure TApp.DoReplace;
var
  pairs: array[0..4] of TReplPair;
  n, k, q, g, i, total, filesDone, startP, startC, endP, p, c, mlen, r2, fileTotal: Integer;
  s, rep: UnicodeString;
  inRange, qNext, query, stopAll, changed: Boolean;
  fname, nm: string;
  pat: TPattern;
  line: UnicodeString;
  ch: WideChar;
  nextName: UnicodeString;

  function OnePass(const pr: TReplPair): Boolean;     { False = stopped by the user }
  begin
    Result := True;
    pat := CompilePattern(pr.Search);
    p := startP;
    c := startC;
    while FindFrom(p, c, pat, mlen) do
    begin
      if p > endP then Break;
      if query then
      begin
        Doc.CurP := p;
        Doc.CurC := c + mlen;
        FlashP := p;
        FlashC1 := c;
        FlashC2 := c + mlen;
        ch := AskChoice('Replace this one?   Y)es   N)o   A)ll the rest   Esc stops', 'YNA');
        FlashP := -1;
        if ch = #0 then
        begin
          Result := False;
          Exit;
        end;
        if ch = 'N' then
        begin
          c := c + mlen;
          if mlen = 0 then Inc(c);
          Continue;
        end;
        if ch = 'A' then query := False;
      end;
      line := Doc[p];
      Delete(line, c + 1, mlen);
      Insert(pr.Repl, line, c + 1);
      Doc.ReplaceText(p, line);
      changed := True;
      Inc(total);
      Inc(fileTotal);
      c := c + Length(pr.Repl);
      if (mlen = 0) and (Length(pr.Repl) = 0) then Inc(c);
    end;
  end;

begin
  n := 0;
  repeat
    s := '';
    if not Ask('Search String?', s, 1, True) then Exit;
    if s = '' then
    begin
      SetMsg('No search string', True);
      Exit;
    end;
    rep := '';
    if not Ask('Replace with?', rep, 2, True) then Exit;
    pairs[n].Search := s;
    pairs[n].Repl := rep;
    Inc(n);
    if n >= 5 then Break;
    k := AskYN('More?');
    if k < 0 then Exit;
  until k = 0;
  q := AskYN('Query before replacement?');
  if q < 0 then Exit;
  g := AskYN('Global?');
  if g < 0 then Exit;
  inRange := False;
  qNext := False;
  if (g = 0) and Doc.RangeSet then
  begin
    k := AskYN('Search and replace in range only?');
    if k < 0 then Exit;
    inRange := k = 1;
  end;
  if g = 1 then
  begin
    k := AskYN('Query on next file?');
    if k < 0 then Exit;
    qNext := k = 1;
    nextName := UTF8Decode(Doc.FileName);
    if not Ask('File name?', nextName, 0, False) then Exit;
    if not ConfirmDiscard then Exit;
    fname := ResolvePath(UTF8Encode(nextName));
    if not LoadPath(fname, True) then Exit;
  end;
  Doc.PushUndo(0);
  total := 0;
  filesDone := 0;
  stopAll := False;
  repeat
    query := q = 1;
    changed := False;
    fileTotal := 0;
    for i := 0 to n - 1 do
    begin
      if g = 1 then
      begin
        startP := 0;
        startC := 0;
        endP := Doc.Count - 1;
      end
      else if inRange then
      begin
        startP := Doc.RangeP1;
        startC := 0;
        endP := Doc.RangeP2;
      end
      else
      begin
        startP := Doc.CurP;
        startC := Doc.CurC;
        endP := Doc.Count - 1;
      end;
      if not OnePass(pairs[i]) then
      begin
        stopAll := True;
        Break;
      end;
    end;
    Inc(filesDone);
    if g <> 1 then Break;
    if changed then
    begin
      if not SavePath(Doc.FileName, True) then Break;
    end;
    if stopAll then Break;
    if not ChainNext(nm) then Break;
    if qNext then
    begin
      r2 := AskYN('Fetch next file?');
      if r2 <> 1 then Break;
    end;
    if not LoadPath(ResolvePath(nm), True) then Break;
  until False;
  SetMsg(UnicodeString(Format('Replace ended: %d replacement(s) in %d file(s)', [total, filesDone])));
end;

function IsBlankLine(const s: UnicodeString): Boolean;
begin
  Result := Trim(UTF8Encode(s)) = '';
end;

function RTrimU(const s: UnicodeString): UnicodeString;
var
  n: Integer;
begin
  n := Length(s);
  while (n > 0) and (s[n] = ' ') do Dec(n);
  Result := Copy(s, 1, n);
end;

function LTrimU(const s: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  i := 1;
  while (i <= Length(s)) and (s[i] = ' ') do Inc(i);
  Result := Copy(s, i, MaxInt);
end;

procedure TApp.DoUnformat;
var
  margin, r1, r2, i, k, n: Integer;
  res: TStrArray;
  cur: UnicodeString;
  inRange: Integer;
begin
  margin := 1;
  if not AskInt('Margin for unformatting? (0 = remove every return marker)', margin, 0, 250) then Exit;
  r1 := 0;
  r2 := Doc.Count - 1;
  if Doc.RangeSet then
  begin
    inRange := AskYN('Unformat in range only?');
    if inRange < 0 then Exit;
    if inRange = 1 then
    begin
      r1 := Doc.RangeP1;
      r2 := Doc.RangeP2;
    end;
  end;
  if AskYN('Are you sure?') <> 1 then Exit;
  Doc.PushUndo(0);
  SetLength(res, 0);
  if margin = 0 then
  begin
    cur := '';
    for i := r1 to r2 do
    begin
      if cur <> '' then cur := cur + ' ';
      cur := cur + Trim(UTF8Encode(Doc[i]));
    end;
    SetLength(res, 1);
    res[0] := UTF8Decode(Trim(UTF8Encode(cur)));
  end
  else
  begin
    i := r1;
    while i <= r2 do
    begin
      if IsBlankLine(Doc[i]) then
      begin
        SetLength(res, Length(res) + 1);
        res[High(res)] := Doc[i];
        Inc(i);
        Continue;
      end;
      cur := Doc[i];
      while (i < r2) and (not IsBlankLine(Doc[i + 1])) and (Length(RTrimU(Doc[i])) >= margin) do
      begin
        Inc(i);
        cur := RTrimU(cur) + ' ' + LTrimU(Doc[i]);
      end;
      SetLength(res, Length(res) + 1);
      res[High(res)] := cur;
      Inc(i);
    end;
  end;
  n := r2 - r1 + 1;
  for k := 0 to n - 1 do
    if k < Length(res) then Doc.ReplaceText(r1 + k, res[k]);
  if Length(res) < n then Doc.DelParas(r1 + Length(res), n - Length(res))
  else
    for k := n to High(res) do Doc.InsPara(r1 + k, res[k]);
  Doc.CurP := r1;
  if Doc.CurP >= Doc.Count then Doc.CurP := Doc.Count - 1;
  Doc.CurC := 0;
  Doc.RangeSet := False;
  SetMsg('Text unformatted (Ctrl+Z undoes)');
end;
