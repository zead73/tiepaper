{ pcapp_input.inc - events, key translation and prompts (included by pcapp.pas) }

const
  SDLK_KP_MINUS = 1073741910;
  SDLK_KP_PLUS = 1073741911;
  SDLK_KP_PERIOD = 1073741923;

function IsModifierSym(sym: LongInt): Boolean;
begin
  Result := ((sym >= 1073742048) and (sym <= 1073742055)) or (sym = 1073741881) or
            (sym = 1073741907) or (sym = 1073742081);
end;

procedure TApp.PushEvent(const ev: TKeyEv);
begin
  SetLength(EvQ, Length(EvQ) + 1);
  EvQ[High(EvQ)] := ev;
end;

function TApp.Translate(var e: TSDL_Event; var ev: TKeyEv): Boolean;
var
  sym, md: LongInt;
begin
  Result := False;
  ev := Default(TKeyEv);
  case e.typ of
    SDL_QUITEV:
      begin
        ev.Kind := ekQuit;
        Result := True;
      end;
    SDL_WINDOWEVENT:
      case EvWinEvent(e) of
        SDL_WINDOWEVENT_SIZE_CHANGED, SDL_WINDOWEVENT_RESIZED:
          begin
            Gfx.Resized;
            ev.Kind := ekResize;
            Result := True;
          end;
        SDL_WINDOWEVENT_EXPOSED:
          begin
            ev.Kind := ekResize;
            Result := True;
          end;
        SDL_WINDOWEVENT_CLOSE:
          begin
            ev.Kind := ekQuit;
            Result := True;
          end;
      end;
    SDL_KEYDOWN:
      begin
        sym := EvKeySym(e);
        md := EvKeyMod(e);
        if (sym = SDLK_LCTRL) or (sym = SDLK_RCTRL) then
        begin
          if not CtrlHeld then CtrlTapOK := True;
          CtrlHeld := True;
          Exit;
        end;
        if IsModifierSym(sym) then Exit;
        CtrlTapOK := False;
        ev.Kind := ekKey;
        ev.Sym := sym;
        ev.Ctrl := (md and KMOD_CTRL) <> 0;
        ev.Shift := (md and KMOD_SHIFT) <> 0;
        ev.Alt := (md and KMOD_ALT) <> 0;
        Result := True;
      end;
    SDL_KEYUP:
      begin
        sym := EvKeySym(e);
        if (sym = SDLK_LCTRL) or (sym = SDLK_RCTRL) then
        begin
          CtrlHeld := False;
          if CtrlTapOK then
          begin
            ev.Kind := ekKey;
            ev.Sym := SYM_CTRLTAP;
            Result := True;
          end;
          CtrlTapOK := False;
        end;
      end;
    SDL_TEXTINPUT:
      begin
        if SwallowText then
        begin
          SwallowText := False;
          if SDL_GetTicks() < SwallowUntil then Exit;
        end;
        ev.Kind := ekText;
        ev.Text := EvText(e);
        Result := Length(ev.Text) > 0;
      end;
    SDL_RENDER_TARGETS_RESET, SDL_RENDER_DEVICE_RESET:
      begin
        Gfx.ForgetGlyphs;
        ev.Kind := ekResize;
        Result := True;
      end;
    SDL_MOUSEWHEEL:
      begin
        CtrlTapOK := False;
        ev.Kind := ekWheel;
        ev.Wheel := EvWheelY(e);
        ev.Ctrl := (SDL_GetModState() and KMOD_CTRL) <> 0;
        Result := True;
      end;
    SDL_MOUSEBUTTONDOWN:
      begin
        CtrlTapOK := False;
        if EvButton(e) = 1 then
        begin
          ev.Kind := ekClick;
          ev.X := EvButtonX(e);
          ev.Y := EvButtonY(e);
          ev.Clicks := e.raw[18];
          ev.Shift := (SDL_GetModState() and KMOD_SHIFT) <> 0;
          Result := True;
        end;
      end;
    SDL_MOUSEBUTTONUP:
      if EvButton(e) = 1 then
      begin
        ev.Kind := ekRelease;
        Result := True;
      end;
    SDL_MOUSEMOTION:
      if (EvMotionState(e) and 1) <> 0 then
      begin
        ev.Kind := ekDrag;
        ev.X := EvMotionX(e);
        ev.Y := EvMotionY(e);
        Result := True;
      end;
  end;
end;

function TApp.NextEvent(var ev: TKeyEv; waitMs: Integer): Boolean;
var
  e: TSDL_Event;
  i: Integer;
begin
  ev := Default(TKeyEv);
  if Length(EvQ) > 0 then
  begin
    ev := EvQ[0];
    for i := 1 to High(EvQ) do EvQ[i - 1] := EvQ[i];
    SetLength(EvQ, Length(EvQ) - 1);
    Exit(True);
  end;
  if ScriptRunning then Exit(ScriptNext(ev));
  Result := False;
  if SDL_WaitEventTimeout(e, waitMs) = 0 then Exit;
  repeat
    if Translate(e, ev) then Exit(True);
  until SDL_PollEvent(e) = 0;
end;

{ ---- scripted input, used by the tests ---- }

procedure TApp.SetScript(const fn: string);
begin
  Script.LoadFromFile(fn);
  ScriptPos := 0;
  ScriptRunning := True;
end;

function SymFromName(const nm: string; out sym: LongInt): Boolean;
var
  s: string;
begin
  Result := True;
  s := LowerCase(nm);
  if (s = 'return') or (s = 'enter') then sym := SDLK_RETURN
  else if (s = 'escape') or (s = 'esc') then sym := SDLK_ESCAPE
  else if s = 'tab' then sym := SDLK_TAB
  else if s = 'backspace' then sym := SDLK_BACKSPACE
  else if s = 'delete' then sym := SDLK_DELETE
  else if s = 'insert' then sym := SDLK_INSERT
  else if s = 'home' then sym := SDLK_HOME
  else if s = 'end' then sym := SDLK_END
  else if s = 'pageup' then sym := SDLK_PAGEUP
  else if s = 'pagedown' then sym := SDLK_PAGEDOWN
  else if s = 'up' then sym := SDLK_UP
  else if s = 'down' then sym := SDLK_DOWN
  else if s = 'left' then sym := SDLK_LEFT
  else if s = 'right' then sym := SDLK_RIGHT
  else if s = 'space' then sym := SDLK_SPACE
  else if (Length(s) >= 2) and (s[1] = 'f') and (StrToIntDef(Copy(s, 2, 3), 0) in [1..12]) then
    sym := SDLK_F1 + StrToInt(Copy(s, 2, 3)) - 1
  else if Length(s) = 1 then sym := Ord(s[1])
  else Result := False;
end;

function TApp.ScriptNext(var ev: TKeyEv): Boolean;
var
  raw, line, cmd, arg, tok: string;
  p, i: Integer;
  mods: TStringList;
  sym: LongInt;
  w, h: LongInt;
  f: TextFile;
  s: UnicodeString;
begin
  Result := False;
  while ScriptPos < Script.Count do
  begin
    raw := Script[ScriptPos];
    Inc(ScriptPos);
    line := Trim(raw);
    if (line = '') or (line[1] = '#') then Continue;
    p := Pos(' ', raw);
    if p = 0 then begin cmd := LowerCase(line); arg := ''; end
    else begin cmd := LowerCase(Trim(Copy(raw, 1, p - 1))); arg := Copy(raw, p + 1, MaxInt); end;
    if cmd = 'text' then
    begin
      if arg = '' then Continue;               { an empty text event would break the one-character prompts }
      ev := Default(TKeyEv);
      ev.Kind := ekText;
      ev.Text := UTF8Decode(arg);
      Exit(True);
    end
    else if cmd = 'key' then
    begin
      ev := Default(TKeyEv);
      ev.Kind := ekKey;
      mods := TStringList.Create;
      try
        mods.Delimiter := '+';
        mods.StrictDelimiter := True;
        mods.DelimitedText := Trim(arg);
        if mods.Count = 0 then Continue;
        for i := 0 to mods.Count - 2 do
        begin
          tok := LowerCase(mods[i]);
          if tok = 'ctrl' then ev.Ctrl := True
          else if tok = 'shift' then ev.Shift := True
          else if tok = 'alt' then ev.Alt := True;
        end;
        tok := mods[mods.Count - 1];
        if (Trim(arg) <> '') and (Trim(arg)[Length(Trim(arg))] = '+') then tok := '+';
        if tok = '' then tok := '+';
        if SymFromName(tok, sym) then ev.Sym := sym else Continue;
      finally
        mods.Free;
      end;
      Exit(True);
    end
    else if cmd = 'ctap' then
    begin
      ev := Default(TKeyEv);
      ev.Kind := ekKey;
      ev.Sym := SYM_CTRLTAP;
      Exit(True);
    end
    else if cmd = 'shot' then
    begin
      Render;
      Gfx.Screenshot(Trim(arg));
    end
    else if cmd = 'dump' then
    begin
      AssignFile(f, Trim(arg));
      Rewrite(f);
      s := Doc.PlainText;
      Write(f, UTF8Encode(s));
      CloseFile(f);
    end
    else if cmd = 'size' then
    begin
      w := StrToIntDef(Trim(Copy(arg, 1, Pos(' ', arg + ' ') - 1)), 1000);
      h := StrToIntDef(Trim(Copy(arg, Pos(' ', arg + ' ') + 1, 10)), 700);
      SDL_SetWindowSize(Gfx.Window, w, h);
      Gfx.Resized;
    end
    else if cmd = 'font' then
      Gfx.SetFontSize(StrToIntDef(Trim(arg), 20))
    else if cmd = 'open' then
      LoadPath(Trim(arg), False)
    else if cmd = 'click' then
    begin
      ev := Default(TKeyEv);
      ev.Kind := ekClick;
      ev.X := StrToIntDef(Trim(Copy(arg, 1, Pos(' ', arg + ' ') - 1)), 0);
      ev.Y := StrToIntDef(Trim(Copy(arg, Pos(' ', arg + ' ') + 1, 10)), 0);
      Exit(True);
    end
    else if (cmd = 'drag') or (cmd = 'dclick') or (cmd = 'shiftclick') then
    begin
      ev := Default(TKeyEv);
      if cmd = 'drag' then ev.Kind := ekDrag else ev.Kind := ekClick;
      if cmd = 'dclick' then ev.Clicks := 2;
      ev.Shift := cmd = 'shiftclick';
      ev.X := StrToIntDef(Trim(Copy(arg, 1, Pos(' ', arg + ' ') - 1)), 0);
      ev.Y := StrToIntDef(Trim(Copy(arg, Pos(' ', arg + ' ') + 1, 10)), 0);
      Exit(True);
    end
    else if cmd = 'release' then
    begin
      ev := Default(TKeyEv);
      ev.Kind := ekRelease;
      Exit(True);
    end
    else if cmd = 'wheel' then
    begin
      ev := Default(TKeyEv);
      ev.Kind := ekWheel;
      ev.Wheel := StrToIntDef(Trim(arg), 1);
      Exit(True);
    end
    else if cmd = 'quit' then
    begin
      Done := True;
      ScriptRunning := False;
      Exit(False);
    end;
  end;
  ScriptRunning := False;
  Done := True;
end;

{ ---- the render/wait loop ---- }

procedure TApp.Render;
begin
  Gfx.ClearAll(RGBOf(Cfg.ColBorder), RGBOf(Cfg.ColBack));
  if Assigned(FullScreen) then FullScreen()
  else DrawEditScreen;
  if Assigned(Overlay) then Overlay();
  Gfx.Present;
end;

function TApp.WaitKey(var ev: TKeyEv): Boolean;
begin
  Result := False;
  while not Done do
  begin
    Render;
    if NextEvent(ev, 450) then
    begin
      case ev.Kind of
        ekKey, ekText, ekWheel, ekClick, ekDrag, ekRelease:
          begin
            BlinkOn := True;
            Exit(True);
          end;
        ekQuit:
          begin
            QuitReq := True;
            Exit(False);
          end;
      end;
    end
    else
      BlinkOn := not BlinkOn;
  end;
end;

procedure TApp.SetMsg(const s: UnicodeString; err: Boolean);
begin
  Msg := s;
  MsgErr := err;
end;

{ ---- keys ---- }

function TApp.KeyToCtrlChar(sym: LongInt; shift: Boolean): WideChar;
begin
  Result := #0;
  case sym of
    Ord('a')..Ord('z'):
      if shift then Result := WideChar(sym - 32) else Result := WideChar(sym);
    Ord('0')..Ord('9'):
      if shift then
      begin
        if sym = Ord('1') then Result := '!'
        else if sym = Ord('2') then Result := '@';
      end
      else Result := WideChar(sym);
    Ord('='): if shift then Result := '+' else Result := '=';
    Ord('-'): if not shift then Result := '-';
    Ord('.'): if not shift then Result := '.';
    SDLK_KP_PLUS: Result := '+';
    SDLK_KP_MINUS: Result := '-';
    SDLK_KP_PERIOD: Result := '.';
  end;
end;

{ After Esc: the character that stands for an embedded print enhancement. }
function TApp.EscToMarker(ch: WideChar; out m: UnicodeString): Boolean;
begin
  Result := True;
  case ch of
    '[': m := CH_UL_ON;
    ']': m := CH_UL_OFF;
    '(': m := CH_BOLD_ON;
    ')': m := CH_BOLD_OFF;
    '<': m := CH_IT_ON;
    '>': m := CH_IT_OFF;
    '#': m := CH_SUP_NEXT;
    '%': m := CH_SUP_ON;
    '''': m := CH_SUP_OFF;
    '$': m := CH_SUB_NEXT;
    '!': m := CH_SUB_ON;
    '"': m := CH_SUB_OFF;
    '.': m := CH_ULCHAR;
    '-': m := CH_SHY;
    '/': m := CH_BREAK;
    ' ': m := CH_HARDSPACE;
    '\': m := '\';
  else
    Result := False;
  end;
end;

{ ---- prompts ---- }

procedure TApp.DrawPromptOverlay;
var
  txt, shown: UnicodeString;
  fg, bg: LongWord;
  w, scrollStart, i, col, curCol, avail: Integer;
begin
  fg := RGBOf(Cfg.ColBack);
  bg := RGBOf(Cfg.ColText);
  Gfx.FillCells(0, 1, Gfx.Cols, 1, bg);
  txt := PromptText + ' ';
  w := Length(txt);
  if PromptYN then
  begin
    Gfx.PutText(0, 1, txt + '(Y/N)', fg, ST_BOLD);
    Exit;
  end;
  Gfx.PutText(0, 1, txt, fg, ST_BOLD);
  avail := Gfx.Cols - w - 1;
  if avail < 4 then avail := 4;
  scrollStart := 0;
  if PromptCur >= avail then scrollStart := PromptCur - avail + 1;
  shown := Copy(PromptInput, scrollStart + 1, avail);
  if PromptFresh and (Length(shown) > 0) then Gfx.FillCells(w, 1, Length(shown), 1, fg);
  for i := 1 to Length(shown) do
  begin
    col := w + i - 1;
    if PromptFresh then Gfx.PutChar(col, 1, shown[i], ST_REGULAR, bg)
    else if IsMarkerChar(shown[i]) or (shown[i] = CH_HARDSPACE) then
    begin
      Gfx.FillCells(col, 1, 1, 1, bg);
      case shown[i] of
        CH_HARDSPACE: Gfx.DrawBar(col, 1, 0, RGBOf(Cfg.ColMarker) xor $FFFFFF);
        CH_SHY: Gfx.DrawBar(col, 1, 1, RGBOf(Cfg.ColMarker) xor $FFFFFF);
        CH_BREAK: Gfx.DrawBar(col, 1, 2, RGBOf(Cfg.ColMarker) xor $FFFFFF);
      else
        Gfx.PutChar(col, 1, MarkerGlyph(shown[i]), ST_REGULAR, fg);
      end;
    end
    else
      Gfx.PutChar(col, 1, shown[i], ST_REGULAR, fg);
  end;
  curCol := w + (PromptCur - scrollStart);
  if PromptEsc then Gfx.PutText(Gfx.Cols - 4, 1, 'ESC', RGBOf(Cfg.ColBorder), ST_BOLD);
  if BlinkOn and (curCol < Gfx.Cols) then
  begin
    Gfx.FillCells(curCol, 1, 1, 1, fg);
    if PromptCur < Length(PromptInput) then
      Gfx.PutChar(curCol, 1, PromptInput[PromptCur + 1], ST_REGULAR, bg);
  end;
end;

function TApp.Ask(const prompt: UnicodeString; var value: UnicodeString; hist: Integer;
  allowEsc: Boolean): Boolean;
var
  ev: TKeyEv;
  def, m, txt: UnicodeString;
  hi, i: Integer;
  savedOverlay: TProc;
  hl: TStringList;

  procedure InsertInput(const t: UnicodeString);
  begin
    Insert(t, PromptInput, PromptCur + 1);
    Inc(PromptCur, Length(t));
  end;

begin
  Result := False;
  hl := Histories[hist];
  def := value;
  hi := hl.Count;
  PromptActive := True;
  PromptYN := False;
  PromptText := prompt;
  PromptInput := value;
  PromptCur := Length(value);
  PromptEsc := False;
  PromptFresh := value <> '';
  savedOverlay := Overlay;
  Overlay := @DrawPromptOverlay;
  try
    while WaitKey(ev) do
    begin
      case ev.Kind of
        ekText:
          for i := 1 to Length(ev.Text) do
          begin
            if PromptFresh then
            begin
              { the first character typed replaces the suggested answer }
              PromptInput := '';
              PromptCur := 0;
              PromptFresh := False;
            end;
            if PromptEsc then
            begin
              if EscToMarker(ev.Text[i], m) then InsertInput(m);
              PromptEsc := False;
            end
            else
              InsertInput(ev.Text[i]);
          end;
        ekKey:
          begin
            if (ev.Sym = SDLK_SPACE) and ev.Shift then
            begin
              if PromptFresh then begin PromptInput := ''; PromptCur := 0; PromptFresh := False; end;
              InsertInput(CH_HARDSPACE);
              SwallowText := True;
              SwallowUntil := SDL_GetTicks() + 150;
              Continue;
            end;
            case ev.Sym of
              SDLK_RETURN, SDLK_KP_ENTER:
                begin
                  value := PromptInput;
                  if (value <> '') and ((hl.Count = 0) or (hl[hl.Count - 1] <> UTF8Encode(value))) then
                    hl.Add(UTF8Encode(value));
                  Result := True;
                  Break;
                end;
              SDLK_ESCAPE:
                begin
                  if allowEsc and (not PromptEsc) then PromptEsc := True
                  else Break;
                end;
              SDLK_BACKSPACE:
                if PromptFresh then
                begin
                  PromptInput := '';
                  PromptCur := 0;
                  PromptFresh := False;
                end
                else if PromptCur > 0 then
                begin
                  Delete(PromptInput, PromptCur, 1);
                  Dec(PromptCur);
                end;
              SDLK_DELETE:
                if PromptFresh then
                begin
                  PromptInput := '';
                  PromptCur := 0;
                  PromptFresh := False;
                end
                else if PromptCur < Length(PromptInput) then Delete(PromptInput, PromptCur + 1, 1);
              SDLK_LEFT: begin PromptFresh := False; if PromptCur > 0 then Dec(PromptCur); end;
              SDLK_RIGHT: begin PromptFresh := False; if PromptCur < Length(PromptInput) then Inc(PromptCur); end;
              SDLK_HOME: begin PromptFresh := False; PromptCur := 0; end;
              SDLK_END: begin PromptFresh := False; PromptCur := Length(PromptInput); end;
              SDLK_UP:
                if hi > 0 then
                begin
                  Dec(hi);
                  PromptInput := UTF8Decode(hl[hi]);
                  PromptCur := Length(PromptInput);
                  PromptFresh := False;
                end;
              SDLK_DOWN:
                if hi < hl.Count - 1 then
                begin
                  Inc(hi);
                  PromptInput := UTF8Decode(hl[hi]);
                  PromptCur := Length(PromptInput);
                end;
              SDLK_TAB:
                begin
                  PromptInput := def;
                  PromptCur := Length(def);
                  PromptFresh := def <> '';
                end;
              SDLK_F6:
                begin
                  txt := Copy(Doc[Doc.CurP], Doc.CurC + 1, 16);
                  PromptInput := txt;
                  PromptCur := Length(txt);
                  PromptFresh := False;
                end;
              Ord('u'):
                if ev.Ctrl then
                begin
                  PromptInput := '';
                  PromptCur := 0;
                end;
            end;
          end;
      end;
    end;
  finally
    PromptActive := False;
    Overlay := savedOverlay;
  end;
end;

function TApp.AskInt(const prompt: UnicodeString; var v: Integer; lo, hi: Integer): Boolean;
var
  s: UnicodeString;
  n: Integer;
begin
  Result := False;
  s := UnicodeString(IntToStr(v));
  repeat
    if not Ask(prompt, s, 4, False) then Exit;
    n := StrToIntDef(Trim(UTF8Encode(s)), -MaxInt);
    if (n >= lo) and (n <= hi) then
    begin
      v := n;
      Exit(True);
    end;
    SetMsg(UnicodeString(Format('Enter a number from %d to %d', [lo, hi])), True);
  until False;
end;

function TApp.AskYN(const prompt: UnicodeString): Integer;
var
  ev: TKeyEv;
  savedOverlay: TProc;
  c: WideChar;
begin
  Result := -1;
  PromptActive := True;
  PromptYN := True;
  PromptText := prompt;
  savedOverlay := Overlay;
  Overlay := @DrawPromptOverlay;
  try
    while WaitKey(ev) do
    begin
      if ev.Kind = ekText then
      begin
        c := ev.Text[1];
        if (c = 'y') or (c = 'Y') then begin Result := 1; Break; end;
        if (c = 'n') or (c = 'N') then begin Result := 0; Break; end;
      end
      else if ev.Kind = ekKey then
      begin
        if ev.Sym = SDLK_ESCAPE then begin Result := -1; Break; end;
      end;
    end;
  finally
    PromptActive := False;
    PromptYN := False;
    Overlay := savedOverlay;
  end;
end;

function TApp.AskChoice(const prompt, chars: UnicodeString): WideChar;
var
  ev: TKeyEv;
  savedOverlay: TProc;
  c: WideChar;
begin
  Result := #0;
  PromptActive := True;
  PromptYN := False;
  PromptText := prompt;
  PromptInput := '';
  PromptCur := 0;
  PromptEsc := False;
  savedOverlay := Overlay;
  Overlay := @DrawPromptOverlay;
  try
    while WaitKey(ev) do
    begin
      if ev.Kind = ekText then
      begin
        c := UpCase(ev.Text[1]);
        if Pos(c, UpperCase(chars)) > 0 then begin Result := c; Break; end;
      end
      else if ev.Kind = ekKey then
      begin
        if ev.Sym = SDLK_ESCAPE then Break;
        if ((ev.Sym = SDLK_RETURN) or (ev.Sym = SDLK_KP_ENTER)) and (Pos(' ', chars) > 0) then
        begin
          Result := ' ';
          Break;
        end;
      end;
    end;
  finally
    PromptActive := False;
    Overlay := savedOverlay;
  end;
end;
