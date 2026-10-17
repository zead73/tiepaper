{ pcapp_spell.inc - spell checking with the operating system's checker (included by pcapp.pas) }

{ Walks the document word by word.  Misspelled words stop the check with suggestions on the
  tab line: 1-9 take a suggestion, R types a replacement, I ignores the word for this session,
  A adds it to the checker's personal dictionary, Space or Return skips it, Esc stops. }
procedure TApp.DoSpell;
var
  sp: TSpeller;
  err: string;
  hits: THitArray;
  sugg: TStringList;
  okWords, ignored: TStringList;
  i, k, n, delta, replaced, skipped, idx: Integer;
  h: THit;
  prompt, one, key: UnicodeString;
  c: WideChar;
  repl, rest: UnicodeString;
  s: UnicodeString;
  undoPushed, stopped, valid: Boolean;
begin
  FollowCursor := True;
  sp := CreateSpeller(Cfg.SpellLang, err);
  if sp = nil then
  begin
    SetMsg(UnicodeString(err), True);
    Exit;
  end;
  sugg := TStringList.Create;
  okWords := TStringList.Create;
  ignored := TStringList.Create;
  okWords.Sorted := True;
  okWords.CaseSensitive := True;
  ignored.Sorted := True;
  ignored.CaseSensitive := True;
  try
    ScanWords(Doc, 0, hits);
    replaced := 0;
    skipped := 0;
    undoPushed := False;
    stopped := False;
    i := 0;
    while (i <= High(hits)) and (not stopped) do
    begin
      h := hits[i];
      key := h.Word;
      if (ignored.IndexOf(UTF8Encode(key)) >= 0) or (okWords.IndexOf(UTF8Encode(key)) >= 0) then
      begin
        Inc(i);
        Continue;
      end;
      sugg.Clear;
      if sp.Check(key, sugg) then
      begin
        okWords.Add(UTF8Encode(key));
        Inc(i);
        Continue;
      end;
      { show the word and ask what to do }
      Doc.CurP := h.P;
      Doc.CurC := h.C2;
      FlashP := h.P;
      FlashC1 := h.C1;
      FlashC2 := h.C2;
      prompt := 'Spelling: "' + key + '"';
      for k := 0 to sugg.Count - 1 do
      begin
        one := UnicodeString(Format('  %d)%s', [k + 1, sugg[k]]));
        if Length(prompt) + Length(one) + 34 > Gfx.Cols then Break;
        prompt := prompt + one;
      end;
      prompt := prompt + '   Space skip  I ignore  A add  R retype  Esc stop';
      repeat
        c := AskChoice(prompt, ' 123456789IAR');
        valid := True;
        if (c >= '1') and (c <= '9') and (Ord(c) - 48 > sugg.Count) then valid := False;
      until valid;
      FlashP := -1;
      repl := '';
      case c of
        #0: stopped := True;
        ' ': Inc(skipped);
        'I':
          begin
            sp.IgnoreWord(key);
            ignored.Add(UTF8Encode(key));
          end;
        'A':
          begin
            sp.AddWord(key);
            okWords.Add(UTF8Encode(key));
          end;
        'R':
          begin
            rest := key;
            if Ask('Replace with?', rest, 2, False) and (rest <> '') then repl := rest
            else Inc(skipped);
          end;
        '1'..'9': repl := UTF8Decode(sugg[Ord(c) - 49]);
      end;
      if repl <> '' then
      begin
        if not undoPushed then
        begin
          Doc.PushUndo(0);
          undoPushed := True;
        end;
        s := Doc[h.P];
        n := h.C2 - h.C1;
        Delete(s, h.C1 + 1, n);
        Insert(repl, s, h.C1 + 1);
        Doc.ReplaceText(h.P, s);
        Doc.CurP := h.P;
        Doc.CurC := h.C1 + Length(repl);
        delta := Length(repl) - n;
        for k := i + 1 to High(hits) do
          if hits[k].P = h.P then
          begin
            Inc(hits[k].C1, delta);
            Inc(hits[k].C2, delta);
          end;
        Inc(replaced);
      end;
      Inc(i);
    end;
    FlashP := -1;
    if stopped then
      SetMsg(UnicodeString(Format('Spell check stopped (%d replaced)', [replaced])))
    else if (replaced = 0) and (skipped = 0) and (ignored.Count = 0) then
      SetMsg(UnicodeString('No spelling errors found (' + sp.Description + ')'))
    else
      SetMsg(UnicodeString(Format('Spell check finished: %d replaced, %d skipped (%s)',
        [replaced, skipped, sp.Description])));
  finally
    ignored.Free;
    okWords.Free;
    sugg.Free;
    sp.Free;
  end;
end;
