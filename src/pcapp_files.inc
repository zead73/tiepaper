{ pcapp_files.inc - load, save, append, directory and output (included by pcapp.pas) }

procedure TApp.UpdateTitle;
var
  t: string;
begin
  if Doc.FileName <> '' then t := ExtractFileName(Doc.FileName) else t := '(untitled)';
  if Doc.Modified then t := t + ' *';
  Gfx.SetTitle('TiePaper - ' + t);
end;

function TApp.ConfirmDiscard: Boolean;
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

{ The comment on line one (checkmark cm:name) is offered as the file name, as in PaperClip. }
function TApp.DefaultName: string;
var
  s: UnicodeString;
begin
  Result := '';
  s := Doc[0];
  if IsFormatLine(s) and (Length(s) >= 4) and (LowerCase(Copy(s, 2, 2)) = 'cm') then
  begin
    Result := Trim(UTF8Encode(Copy(s, 4, MaxInt)));
    if (Result <> '') and (Result[1] = ':') then Delete(Result, 1, 1);
    Result := Trim(Result);
  end;
  if (Result = '') and (Doc.FileName <> '') then Result := ExtractFileName(Doc.FileName);
  if Result = '' then Result := 'untitled.pcl';
end;

function TApp.LoadPath(const fn: string; quiet: Boolean): Boolean;
var
  err: string;
begin
  err := Doc.LoadFromFile(fn);
  if err <> '' then
  begin
    SetMsg(UnicodeString('Cannot load ' + ExtractFileName(fn) + ': ' + err), True);
    Exit(False);
  end;
  Doc.FileName := ExpandFileName(fn);
  LastDir := ExtractFilePath(Doc.FileName);
  TopRow := 0;
  LeftCol := 0;
  NumMode := False;
  FlashP := -1;
  WantCol := -1;
  UpdateTitle;
  if not quiet then
    SetMsg(UnicodeString(Format('Loaded %s: %d line(s)', [ExtractFileName(fn), Doc.Count])));
  Result := True;
end;

function TApp.SavePath(const fn: string; quiet: Boolean): Boolean;
var
  err: string;
  plain: Boolean;
begin
  plain := LowerCase(ExtractFileExt(fn)) = '.txt';
  err := Doc.SaveToFile(fn, not plain);
  if err <> '' then
  begin
    SetMsg(UnicodeString('Cannot save: ' + err), True);
    Exit(False);
  end;
  Doc.FileName := ExpandFileName(fn);
  Doc.Modified := False;
  LastDir := ExtractFilePath(Doc.FileName);
  UpdateTitle;
  if not quiet then
  begin
    if plain then
      SetMsg(UnicodeString('Saved ' + ExtractFileName(fn) + ' as plain text (tabs and line length are not kept)'))
    else
      SetMsg(UnicodeString('Saved ' + ExtractFileName(fn)));
  end;
  Result := True;
end;

procedure TApp.DoSave;
var
  name: UnicodeString;
  fn: string;
begin
  name := UTF8Decode(DefaultName);
  if not Ask('Filename?', name, 0, False) then Exit;
  fn := NormalizeName(UTF8Encode(name));
  if fn = '' then Exit;
  fn := ResolvePath(fn);
  if FileExists(fn) and (ExpandFileName(fn) <> ExpandFileName(Doc.FileName)) then
    if AskYN('Replace existing file?') <> 1 then Exit;
  SavePath(fn, False);
end;

function FindExisting(const fn: string): string;
begin
  Result := fn;
  if FileExists(fn) then Exit;
  if ExtractFileExt(fn) = '' then
  begin
    if FileExists(fn + '.pcl') then Result := fn + '.pcl'
    else if FileExists(fn + '.txt') then Result := fn + '.txt';
  end;
end;

{ Expands * and ? in a file name to the first match, as the disk drive did. }
function ExpandWild(const fn: string): string;
var
  sr: TSearchRec;
  dir: string;
begin
  Result := fn;
  if (Pos('*', fn) = 0) and (Pos('?', fn) = 0) then Exit;
  dir := ExtractFilePath(fn);
  if FindFirst(fn, faAnyFile and not faDirectory, sr) = 0 then
  begin
    Result := dir + sr.Name;
    SysUtils.FindClose(sr);
  end;
end;

procedure TApp.DoLoad;
var
  name: UnicodeString;
  fn, nx: string;
begin
  if not ConfirmDiscard then Exit;
  if ChainNext(nx) then name := UTF8Decode(nx)
  else if Doc.FileName <> '' then name := UTF8Decode(ExtractFileName(Doc.FileName))
  else name := '';
  if not Ask('Filename?', name, 0, False) then Exit;
  fn := Trim(UTF8Encode(name));
  if fn = '' then Exit;
  fn := FindExisting(ExpandWild(ResolvePath(fn)));
  if not FileExists(fn) then
  begin
    SetMsg(UnicodeString('62,file not found: ' + ExtractFileName(fn)), True);
    Exit;
  end;
  LoadPath(fn, False);
end;

procedure TApp.DoAppend;
var
  name: UnicodeString;
  fn: string;
  t: TDoc;
  i, at, n: Integer;
  err: string;
begin
  name := '';
  if not Ask('Filename?', name, 0, False) then Exit;
  fn := Trim(UTF8Encode(name));
  if fn = '' then Exit;
  fn := FindExisting(ExpandWild(ResolvePath(fn)));
  if not FileExists(fn) then
  begin
    SetMsg(UnicodeString('62,file not found: ' + ExtractFileName(fn)), True);
    Exit;
  end;
  t := TDoc.Create;
  try
    err := t.LoadFromFile(fn);
    if err <> '' then
    begin
      SetMsg(UnicodeString(err), True);
      Exit;
    end;
    Doc.PushUndo(0);
    at := Doc.CurP;
    n := t.Count;
    for i := 0 to n - 1 do Doc.InsPara(at + i, t[i]);
    Doc.CurP := at;
    Doc.CurC := 0;
    SetMsg(UnicodeString(Format('Appended %d line(s) from %s', [n, ExtractFileName(fn)])));
  finally
    t.Free;
  end;
end;

{ ---- the directory screen ---- }

procedure TApp.LoadDirectory(const path, mask: string);
var
  sr: TSearchRec;
  n: Integer;
  e: TDirEntry;
  i, j: Integer;
  tmp: TDirEntry;
begin
  DirPath := ExcludeTrailingPathDelimiter(ExpandFileName(path));
  if DirPath = '' then DirPath := PathDelim;
  DirMask := mask;
  SetLength(DirItems, 0);
  n := 0;
  e.Name := '..';
  e.IsDir := True;
  e.Size := 0;
  e.Time := 0;
  SetLength(DirItems, 1);
  DirItems[0] := e;
  n := 1;
  if FindFirst(IncludeTrailingPathDelimiter(DirPath) + '*', faAnyFile, sr) = 0 then
  begin
    repeat
      if (sr.Name = '.') or (sr.Name = '..') then Continue;
      if (sr.Attr and faDirectory) = 0 then
        if (mask <> '') and (mask <> '*') and (mask <> '*.*') and
           (not MatchesMask(sr.Name, mask)) then Continue;
      e.Name := sr.Name;
      e.IsDir := (sr.Attr and faDirectory) <> 0;
      e.Size := sr.Size;
      e.Time := FileDateToDateTime(sr.Time);
      SetLength(DirItems, n + 1);
      DirItems[n] := e;
      Inc(n);
    until FindNext(sr) <> 0;
    SysUtils.FindClose(sr);
  end;
  { directories first, then files; each in name order }
  for i := 2 to n - 1 do
  begin
    tmp := DirItems[i];
    j := i - 1;
    while (j >= 1) and
          ((DirItems[j].IsDir < tmp.IsDir) or
           ((DirItems[j].IsDir = tmp.IsDir) and (LowerCase(DirItems[j].Name) > LowerCase(tmp.Name)))) do
    begin
      DirItems[j + 1] := DirItems[j];
      Dec(j);
    end;
    DirItems[j + 1] := tmp;
  end;
  DirSel := 0;
  DirTop := 0;
end;

procedure TApp.DrawDirScreen;
var
  textC, backC, dimC, fg, bg: LongWord;
  i, k, rows, nameW: Integer;
  e: TDirEntry;
  line, sz: UnicodeString;
begin
  textC := RGBOf(Cfg.ColText);
  backC := RGBOf(Cfg.ColBack);
  dimC := RGBOf(Cfg.ColReturn);
  Gfx.FillCells(0, 0, Gfx.Cols, 1, textC);
  Gfx.PutText(0, 0, ' Directory  ' + UTF8Decode(DirPath), backC, ST_BOLD);
  if DirMask <> '' then
    Gfx.PutText(Gfx.Cols - Length(DirMask) - 2, 0, UTF8Decode(DirMask), backC, ST_REGULAR);
  if Msg <> '' then
  begin
    Gfx.FillCells(0, 1, Gfx.Cols, 1, RGBOf(2));
    Gfx.PutText(1, 1, Msg, RGBOf(1), ST_BOLD);
  end
  else
    Gfx.PutText(1, 1, 'Up/Down choose   Enter opens or loads   A appends   Backspace goes up   Esc returns', dimC);
  rows := Gfx.Rows - 3;
  if DirSel < DirTop then DirTop := DirSel;
  if DirSel >= DirTop + rows then DirTop := DirSel - rows + 1;
  nameW := Gfx.Cols - 32;
  if nameW < 12 then nameW := 12;
  for i := 0 to rows - 1 do
  begin
    k := DirTop + i;
    if k >= Length(DirItems) then Break;
    e := DirItems[k];
    fg := textC;
    bg := backC;
    if k = DirSel then begin fg := backC; bg := textC; end;
    Gfx.FillCells(0, 2 + i, Gfx.Cols, 1, bg);
    if e.IsDir then line := '[' + UTF8Decode(e.Name) + ']' else line := UTF8Decode(e.Name);
    Gfx.PutText(1, 2 + i, Copy(line, 1, nameW), fg, IfThenInt(e.IsDir, ST_BOLD, ST_REGULAR));
    if not e.IsDir then
    begin
      sz := UnicodeString(IntToStr(e.Size));
      Gfx.PutText(1 + nameW + 10 - Length(sz), 2 + i, sz, fg);
      Gfx.PutText(1 + nameW + 12, 2 + i, UnicodeString(FormatDateTime('yyyy-mm-dd hh:nn', e.Time)), fg);
    end;
  end;
  Gfx.PutText(1, Gfx.Rows - 1, UnicodeString(Format('%d item(s)', [Length(DirItems) - 1])), dimC);
end;

procedure TApp.DoDirectory(which: Integer);
var
  ev: TKeyEv;
  startDir, mask, home, fn: string;
  s: UnicodeString;
  e: TDirEntry;
  t: TDoc;
  i, at: Integer;
  err: string;
begin
  startDir := ExcludeTrailingPathDelimiter(DocDir);
  mask := '';
  case which of
    1:
      begin
        home := SysUtils.GetEnvironmentVariable({$IFDEF WINDOWS}'USERPROFILE'{$ELSE}'HOME'{$ENDIF});
        if home <> '' then startDir := home;
      end;
    3:
      begin
        s := UTF8Decode(IncludeTrailingPathDelimiter(startDir) + '*.pcl');
        if not Ask('Directory (wild cards allowed)?', s, 0, False) then Exit;
        fn := Trim(UTF8Encode(s));
        if fn = '' then Exit;
        startDir := ExtractFilePath(ResolvePath(fn));
        if startDir = '' then startDir := DocDir;
        mask := ExtractFileName(fn);
      end;
  end;
  LoadDirectory(startDir, mask);
  FullScreen := @DrawDirScreen;
  try
    while WaitKey(ev) do
    begin
      Msg := '';
      if ev.Kind = ekWheel then
      begin
        DirSel := DirSel - ev.Wheel * 3;
        if DirSel < 0 then DirSel := 0;
        if DirSel > High(DirItems) then DirSel := High(DirItems);
        Continue;
      end;
      if ev.Kind = ekText then
      begin
        if (ev.Text[1] = 'a') or (ev.Text[1] = 'A') then
        begin
          e := DirItems[DirSel];
          if e.IsDir then Continue;
          fn := IncludeTrailingPathDelimiter(DirPath) + e.Name;
          t := TDoc.Create;
          try
            err := t.LoadFromFile(fn);
            if err = '' then
            begin
              FullScreen := nil;
              Doc.PushUndo(0);
              at := Doc.CurP;
              for i := 0 to t.Count - 1 do Doc.InsPara(at + i, t[i]);
              Doc.CurP := at;
              Doc.CurC := 0;
              SetMsg(UnicodeString(Format('Appended %d line(s) from %s', [t.Count, e.Name])));
              Break;
            end
            else SetMsg(UnicodeString(err), True);
          finally
            t.Free;
          end;
        end;
        Continue;
      end;
      if ev.Kind <> ekKey then Continue;
      case ev.Sym of
        SDLK_ESCAPE: Break;
        SDLK_UP: if DirSel > 0 then Dec(DirSel);
        SDLK_DOWN: if DirSel < High(DirItems) then Inc(DirSel);
        SDLK_PAGEUP: begin DirSel := DirSel - (Gfx.Rows - 4); if DirSel < 0 then DirSel := 0; end;
        SDLK_PAGEDOWN: begin DirSel := DirSel + (Gfx.Rows - 4); if DirSel > High(DirItems) then DirSel := High(DirItems); end;
        SDLK_HOME: DirSel := 0;
        SDLK_END: DirSel := High(DirItems);
        SDLK_BACKSPACE: LoadDirectory(ExtractFilePath(DirPath), DirMask);
        SDLK_RETURN, SDLK_KP_ENTER:
          begin
            e := DirItems[DirSel];
            if e.IsDir then
            begin
              if e.Name = '..' then LoadDirectory(ExtractFilePath(DirPath), DirMask)
              else LoadDirectory(IncludeTrailingPathDelimiter(DirPath) + e.Name, DirMask);
            end
            else
            begin
              FullScreen := nil;
              if ConfirmDiscard then
              begin
                LoadPath(IncludeTrailingPathDelimiter(DirPath) + e.Name, False);
                Break;
              end;
              FullScreen := @DrawDirScreen;
            end;
          end;
      end;
    end;
  finally
    FullScreen := nil;
  end;
end;

{ ---- output ---- }

function TApp.LoadChainFile(const name: string; var paras: TStrArray): Boolean;
var
  t: TDoc;
  i: Integer;
  fn: string;
begin
  Result := False;
  fn := FindExisting(ResolvePath(name));
  if not FileExists(fn) then Exit;
  t := TDoc.Create;
  try
    if t.LoadFromFile(fn) <> '' then Exit;
    SetLength(paras, t.Count);
    for i := 0 to t.Count - 1 do paras[i] := t[i];
    Result := True;
  finally
    t.Free;
  end;
end;

function TApp.AskNextFile: string;
var
  s: UnicodeString;
begin
  s := '';
  if Ask('Next file name? (empty = end of document)', s, 0, False) then Result := Trim(UTF8Encode(s))
  else Result := '';
end;

function TApp.BuildFormat: TFormatter;
var
  paras: TStrArray;
  i: Integer;
begin
  SetLength(paras, Doc.Count);
  for i := 0 to Doc.Count - 1 do paras[i] := Doc[i];
  Result := TFormatter.Create;
  Result.Loader := @LoadChainFile;
  Result.AskNext := @AskNextFile;
  Result.DefaultPaperLines := PaperLinesFor(TPaperSize(Cfg.Paper));
  Result.Run(paras);
end;

function TApp.WriteToc(f: TFormatter; out isErr: Boolean): UnicodeString;
var
  err2: string;
  t: TDoc;
  i, p: Integer;
  line: string;
  fn: string;
  lines: UnicodeString;
  pg, txt: string;
begin
  Result := '';
  isErr := False;
  if (f.TocFileName = '') or (f.TocEntries.Count = 0) then Exit;
  fn := ResolvePath(NormalizeName(f.TocFileName));
  lines := '';
  for i := 0 to f.TocEntries.Count - 1 do
  begin
    p := Pos(#9, f.TocEntries[i]);
    pg := Copy(f.TocEntries[i], 1, p - 1);
    txt := Copy(f.TocEntries[i], p + 1, MaxInt);
    line := txt;
    while Length(UTF8Decode(line)) < 54 do line := line + '.';
    line := line + ' ' + StringOfChar(' ', 4 - Length(pg)) + pg;
    lines := lines + UTF8Decode(line) + #10;
  end;
  t := TDoc.Create;
  try
    t.SetText(lines);
    err2 := t.SaveToFile(fn, True);
    if err2 = '' then
      Result := UnicodeString('Table of contents written to ' + ExtractFileName(fn))
    else
    begin
      Result := UnicodeString('Cannot write the table of contents: ' + err2);
      isErr := True;
    end;
  finally
    t.Free;
  end;
end;

function FindProgram(const name: string): string;
begin
  Result := ExeSearch(name, SysUtils.GetEnvironmentVariable('PATH'));
end;

procedure OpenExternally(const path: string);
begin
  {$IFDEF WINDOWS}
  ShellExecute(0, 'open', PChar(path), nil, nil, SW_SHOWNORMAL);
  {$ELSE}
  if FindProgram('xdg-open') <> '' then
  begin
    with TProcess.Create(nil) do
    try
      Executable := FindProgram('xdg-open');
      Parameters.Add(path);
      Options := [poNoConsole];
      Execute;
    finally
      Free;
    end;
  end;
  {$ENDIF}
end;

function PrintFileExternally(const path: string; copies: Integer): string;
{$IFDEF WINDOWS}
var
  r: HINST;
begin
  r := ShellExecute(0, 'print', PChar(path), nil, nil, SW_HIDE);
  if r <= 32 then
  begin
    OpenExternally(path);
    Result := 'No PDF printing program found: the PDF was opened instead, print it from there';
  end
  else Result := '';
end;
{$ELSE}
var
  lp, outp: string;
begin
  lp := FindProgram('lp');
  if lp = '' then
  begin
    OpenExternally(path);
    Exit('No "lp" command: the PDF was opened instead, print it from there');
  end;
  if RunCommand(lp, ['-n', IntToStr(copies), path], outp) then Result := ''
  else Result := 'lp failed: ' + Trim(outp);
  if (Result = '') and (Trim(outp) <> '') then Result := Trim(outp);
end;
{$ENDIF}

procedure TApp.OutputPages(f: TFormatter);
var
  c: WideChar;
  name: UnicodeString;
  fn, err, base, tmp: string;
  first, last, copies: Integer;
begin
  c := AskChoice('Output to:  P)DF file   T)ext file   R) printer   (Esc cancels)', 'PTR');
  if c = #0 then Exit;
  first := 1;
  last := f.PageCount;
  if not AskInt('Starting page?', first, 1, f.PageCount) then Exit;
  if not AskInt('Ending page?', last, first, f.PageCount) then Exit;
  base := ChangeFileExt(DefaultName, '');
  case c of
    'P', 'T':
      begin
        if c = 'P' then name := UTF8Decode(base + '.pdf') else name := UTF8Decode(base + '.txt');
        if not Ask('Filename?', name, 0, False) then Exit;
        fn := Trim(UTF8Encode(name));
        if fn = '' then Exit;
        fn := ResolvePath(fn);
        if FileExists(fn) and (AskYN('Replace existing file?') <> 1) then Exit;
        if c = 'P' then err := WritePDF(f, fn, TPaperSize(Cfg.Paper), first, last)
        else err := WritePlainText(f, fn, first, last);
        if err <> '' then SetMsg(UnicodeString(err), True)
        else SetMsg(UnicodeString(Format('Wrote %s (%d page(s))', [ExtractFileName(fn), last - first + 1])));
      end;
    'R':
      begin
        copies := 1;
        if not AskInt('Number of copies?', copies, 1, 255) then Exit;
        tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'tiepaper-print.pdf';
        err := WritePDF(f, tmp, TPaperSize(Cfg.Paper), first, last);
        if err <> '' then begin SetMsg(UnicodeString(err), True); Exit; end;
        err := PrintFileExternally(tmp, copies);
        if err = '' then SetMsg(UnicodeString(Format('Sent %d page(s) to the printer', [last - first + 1])))
        else SetMsg(UnicodeString(err), True);
      end;
  end;
end;

procedure TApp.DoOutput(quick: Boolean);
var
  f: TFormatter;
  tmp, err: string;
  tocMsg: UnicodeString;
  tocErr: Boolean;
begin
  f := BuildFormat;
  try
    tocMsg := WriteToc(f, tocErr);
    if f.PageCount = 0 then
    begin
      SetMsg('There is nothing to output', True);
      Exit;
    end;
    if quick then
    begin
      if AskYN(UnicodeString(Format('Print %d page(s) now?', [f.PageCount]))) <> 1 then Exit;
      tmp := IncludeTrailingPathDelimiter(GetTempDir) + 'tiepaper-print.pdf';
      err := WritePDF(f, tmp, TPaperSize(Cfg.Paper), 1, 0);
      if err = '' then err := PrintFileExternally(tmp, 1);
      if err = '' then SetMsg(UnicodeString(Format('Sent %d page(s) to the printer', [f.PageCount])))
      else SetMsg(UnicodeString(err), True);
    end
    else
      OutputPages(f);
    if tocMsg <> '' then SetMsg(Msg + '   ' + tocMsg, MsgErr or tocErr);
    if f.Warnings.Count > 0 then
      SetMsg(Msg + UnicodeString(Format('   (%d warning(s): see Preview)', [f.Warnings.Count])), MsgErr);
  finally
    f.Free;
  end;
end;
