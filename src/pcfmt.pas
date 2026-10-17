{ pcfmt - the output formatter.

  TiePaper is a post-formatting word processor: the text on the screen is plain,
  and the layout is decided when it is output.  This unit walks the paragraphs,
  carries out the format lines (those starting with the checkmark) and the
  embedded print enhancements, and lays everything out on pages.

  Defaults come from the manual: paper 66 lines, 56 printed lines per page, left
  margin 10, right margin 70, 10 characters per inch, 6 lines per inch.

  Pages are built the way a printer would print them: a header is written when a
  page is started and a footer when it is finished, each using the settings in
  force at that moment. }
unit pcfmt;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Contnrs, pcdoc;

const
  A_BOLD = 1;
  A_ITAL = 2;
  A_UL = 4;
  A_SUP = 8;
  A_SUB = 16;

type
  TCell = record
    Ch: WideChar;
    Attr: Byte;
  end;
  TCellArr = array of TCell;

  TOutLine = record
    Cells: TCellArr;      { column 1 is the left edge of the paper }
    Pitch: Integer;       { characters per inch for this line; 0 = 10 }
    Src: Integer;         { source paragraph in the main document, or -1 }
  end;

  TPage = class
  public
    Lines: array of TOutLine;    { one per paper line }
    Number: Integer;             { page number as shown in headers }
    Seq: Integer;                { 1, 2, 3 ... in output order }
    LPI: Integer;
    Notes: TStringList;          { pause prompts that fall on this page }
    constructor Create(paperLines: Integer);
    destructor Destroy; override;
    function LastUsed: Integer;  { 1-based number of the last non-blank line, 0 if none }
  end;

  TFileLoader = function(const name: string; var paras: TStrArray): Boolean of object;
  TAskNextFile = function: string of object;

  TFormatter = class
  private
    LM, RM, LMAdj, RMAdj: Integer;
    PL, PG, VP, Offset: Integer;
    LPI, SP, Pitch: Integer;
    Just, Center, RightAl: Boolean;
    AI, MA: Integer;
    HdOn, FtOn: Boolean;
    HdN, FtN: Integer;
    HdTxt, FtTxt: array[0..2] of UnicodeString;
    HL, HR, FL, FR: Integer;
    MLock: Boolean;
    HdPitch, FtPitch: Integer;
    PageNo, ChapNo: Integer;
    Bold, Ital, UL, SupRun, SubRun, SupNext, SubNext: Boolean;
    CurPage: TPage;
    Used: Integer;
    PagePL, PagePG, PageVP, PageLPI: Integer;
    Pending: TStringList;
    TocFile: string;
    Chain: Integer;
    FWarned: TStringList;
    function EffLM: Integer;
    function EffRM: Integer;
    procedure Warn(src: Integer; const msg: string);
    procedure WarnOnce(const msg: string);
    function Cap: Integer;
    procedure BeginPage;
    procedure FinishPage;
    procedure AddLine(const cells: TCellArr; leftCol, src: Integer);
    procedure PlaceHF(target: TPage; lineNo: Integer; const parts: array of UnicodeString;
      lcol, rcol, linePitch: Integer; pageNumber: Integer);
    procedure EmitParagraph(const s: UnicodeString; src: Integer);
    function Directive(const s: UnicodeString; src, depth: Integer): Boolean;
    function Follow(const name: string; src, depth: Integer; external_: Boolean): Boolean;
    procedure Process(const paras: TStrArray; root: Boolean; depth: Integer);
    function PitchValue(v: Integer): Integer;
    procedure SyncHFMargins(left: Boolean);
  public
    Pages: TObjectList;
    Warnings: TStringList;
    TocEntries: TStringList;       { page <tab> text }
    TocFileName: string;
    Loader: TFileLoader;
    AskNext: TAskNextFile;
    DefaultPaperLines: Integer;    { 66 for Letter, 70 for A4 }
    constructor Create;
    destructor Destroy; override;
    procedure Run(const paras: TStrArray);
    function PageCount: Integer;
    function GetPage(i: Integer): TPage;
  end;

function PitchOf(const l: TOutLine): Integer;
function LineText(const l: TOutLine): UnicodeString;

implementation

function PitchOf(const l: TOutLine): Integer;
begin
  if l.Pitch <= 0 then Result := 10 else Result := l.Pitch;
end;

function LineText(const l: TOutLine): UnicodeString;
var
  i: Integer;
begin
  SetLength(Result, Length(l.Cells));
  for i := 0 to High(l.Cells) do Result[i + 1] := l.Cells[i].Ch;
end;

function IfInt(c: Boolean; a, b: Integer): Integer;
begin
  if c then Result := a else Result := b;
end;

{ TPage }

constructor TPage.Create(paperLines: Integer);
begin
  inherited Create;
  SetLength(Lines, paperLines);
  Notes := TStringList.Create;
end;

destructor TPage.Destroy;
begin
  Notes.Free;
  inherited Destroy;
end;

function TPage.LastUsed: Integer;
var
  i, j: Integer;
begin
  Result := 0;
  for i := High(Lines) downto 0 do
    for j := 0 to High(Lines[i].Cells) do
      if Lines[i].Cells[j].Ch <> ' ' then Exit(i + 1);
end;

{ TFormatter }

constructor TFormatter.Create;
begin
  inherited Create;
  Pages := TObjectList.Create(True);
  Warnings := TStringList.Create;
  TocEntries := TStringList.Create;
  Pending := TStringList.Create;
  FWarned := TStringList.Create;
  DefaultPaperLines := 66;
end;

destructor TFormatter.Destroy;
begin
  FWarned.Free;
  Pending.Free;
  TocEntries.Free;
  Warnings.Free;
  Pages.Free;
  inherited Destroy;
end;

function TFormatter.PageCount: Integer;
begin
  Result := Pages.Count;
end;

function TFormatter.GetPage(i: Integer): TPage;
begin
  Result := TPage(Pages[i]);
end;

function TFormatter.EffLM: Integer;
begin
  Result := LM + LMAdj;
  if Result < 1 then Result := 1;
  if Result > 250 then Result := 250;
end;

function TFormatter.EffRM: Integer;
begin
  Result := RM + RMAdj;
  if Result < 1 then Result := 1;
  if Result > 250 then Result := 250;
end;

procedure TFormatter.Warn(src: Integer; const msg: string);
begin
  if src >= 0 then Warnings.Add(Format('Line %d: %s', [src + 1, msg]))
  else Warnings.Add(msg);
end;

procedure TFormatter.WarnOnce(const msg: string);
begin
  if FWarned.IndexOf(msg) < 0 then
  begin
    FWarned.Add(msg);
    Warnings.Add(msg);
  end;
end;

{ lines of text that fit on the page being filled }
function TFormatter.Cap: Integer;
var
  c, psize, vpos, plen: Integer;
begin
  if CurPage <> nil then begin psize := PagePG; vpos := PageVP; plen := PagePL; end
  else begin psize := PG; vpos := VP; plen := PL; end;
  c := psize;
  if plen - vpos < c then c := plen - vpos;
  if c < 1 then c := 1;
  Result := c;
end;

function TFormatter.PitchValue(v: Integer): Integer;
begin
  if (v >= 4) and (v <= 30) then Result := v
  else Result := 5;          { the "optional" pitch is double width }
end;

function BlankCells(n: Integer): TCellArr;
var
  i: Integer;
begin
  SetLength(Result, n);
  for i := 0 to n - 1 do
  begin
    Result[i].Ch := ' ';
    Result[i].Attr := 0;
  end;
end;

function SubstTokens(const s: UnicodeString; pageNumber, chapter: Integer): UnicodeString;
var
  i: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(s) do
  begin
    if (s[i] = '<') and (i < Length(s)) and (s[i + 1] = '>') then
    begin
      Result := Result + UnicodeString(IntToStr(pageNumber));
      Inc(i, 2);
    end
    else if (s[i] = '[') and (i < Length(s)) and (s[i + 1] = ']') then
    begin
      Result := Result + UnicodeString(IntToStr(chapter));
      Inc(i, 2);
    end
    else
    begin
      Result := Result + s[i];
      Inc(i);
    end;
  end;
end;

procedure TFormatter.PlaceHF(target: TPage; lineNo: Integer; const parts: array of UnicodeString;
  lcol, rcol, linePitch: Integer; pageNumber: Integer);
var
  cells: TCellArr;
  txt: array[0..2] of UnicodeString;
  width, i, start: Integer;

  procedure Put(col: Integer; const t: UnicodeString);
  var
    k, idx: Integer;
  begin
    for k := 1 to Length(t) do
    begin
      idx := col - 1 + k - 1;
      if idx < 0 then Continue;
      if idx >= Length(cells) then
      begin
        i := Length(cells);
        SetLength(cells, idx + 1);
        while i <= idx do
        begin
          cells[i].Ch := ' ';
          cells[i].Attr := 0;
          Inc(i);
        end;
      end;
      cells[idx].Ch := t[k];
      cells[idx].Attr := 0;
    end;
  end;

begin
  if (lineNo < 1) or (lineNo > Length(target.Lines)) then Exit;
  for i := 0 to 2 do txt[i] := StripMarkers(SubstTokens(parts[i], pageNumber, ChapNo));
  width := rcol - lcol + 1;
  if width < 1 then width := 1;
  cells := BlankCells(rcol + Offset);
  Put(lcol + Offset, txt[0]);
  start := lcol + (width - Length(txt[1])) div 2;
  Put(start + Offset, txt[1]);
  Put(rcol - Length(txt[2]) + 1 + Offset, txt[2]);
  target.Lines[lineNo - 1].Cells := cells;
  target.Lines[lineNo - 1].Pitch := linePitch;
  target.Lines[lineNo - 1].Src := -1;
end;

procedure TFormatter.BeginPage;
var
  ln: Integer;
begin
  PagePL := PL;
  PagePG := PG;
  PageVP := VP;
  PageLPI := LPI;
  CurPage := TPage.Create(PagePL);
  CurPage.Number := PageNo;
  CurPage.Seq := Pages.Count + 1;
  CurPage.LPI := PageLPI;
  Pages.Add(CurPage);
  Used := 0;
  while Pending.Count > 0 do
  begin
    CurPage.Notes.Add(Pending[0]);
    Pending.Delete(0);
  end;
  if PageVP + PagePG > PagePL then
    WarnOnce('The page size plus the vertical position is larger than the paper length');
  if HdOn then
  begin
    ln := PageVP + 1 - HdN;
    if ln < 1 then
      WarnOnce('The header would print above the top of the paper: set the vertical position (vp) to at least ' +
        IntToStr(HdN))
    else
      PlaceHF(CurPage, ln, [HdTxt[0], HdTxt[1], HdTxt[2]], HL, HR,
        IfInt(HdPitch > 0, HdPitch, Pitch), PageNo);
  end;
end;

procedure TFormatter.FinishPage;
var
  ln, j: Integer;
  busy: Boolean;
begin
  if CurPage = nil then Exit;
  if FtOn then
  begin
    ln := PagePL + 1 - FtN;
    if (ln < 1) or (ln > PagePL) then
      WarnOnce('The footer position is outside the paper')
    else
    begin
      busy := False;
      for j := 0 to High(CurPage.Lines[ln - 1].Cells) do
        if CurPage.Lines[ln - 1].Cells[j].Ch <> ' ' then busy := True;
      if busy then
        WarnOnce('The footer overlaps printed text: reduce the page size (pg) or the footer position')
      else
        PlaceHF(CurPage, ln, [FtTxt[0], FtTxt[1], FtTxt[2]], FL, FR,
          IfInt(FtPitch > 0, FtPitch, Pitch), PageNo);
    end;
  end;
  CurPage := nil;
  Inc(PageNo);
  Used := 0;
end;

procedure TFormatter.AddLine(const cells: TCellArr; leftCol, src: Integer);
var
  full: TCellArr;
  lead, i, ln, k: Integer;
begin
  if CurPage = nil then BeginPage;
  if PageVP + Used >= PagePL then
  begin
    FinishPage;
    BeginPage;
  end;
  lead := Offset + leftCol - 1;
  if lead < 0 then lead := 0;
  SetLength(full, lead + Length(cells));
  for i := 0 to lead - 1 do
  begin
    full[i].Ch := ' ';
    full[i].Attr := 0;
  end;
  for i := 0 to High(cells) do full[lead + i] := cells[i];
  ln := PageVP + Used;
  CurPage.Lines[ln].Cells := full;
  CurPage.Lines[ln].Pitch := Pitch;
  CurPage.Lines[ln].Src := src;
  Inc(Used);
  for k := 2 to SP do
    if Used < Cap then Inc(Used);
  if Used >= Cap then FinishPage;
end;

type
  TTokKind = (tkChar, tkSpace, tkHard, tkShy, tkBrk);
  TTok = record
    Kind: TTokKind;
    Ch: WideChar;
    Attr: Byte;
  end;

procedure TFormatter.EmitParagraph(const s: UnicodeString; src: Integer);
var
  toks: array of TTok;
  nt: Integer;
  i, k, w, ws, q, x, wcalc, width, left: Integer;
  first, allBlank: Boolean;

  procedure AddTok(kind: TTokKind; ch: WideChar);
  var
    a: Byte;
  begin
    if nt >= Length(toks) then SetLength(toks, nt * 2 + 16);
    toks[nt].Kind := kind;
    toks[nt].Ch := ch;
    a := 0;
    if Bold then a := a or A_BOLD;
    if Ital then a := a or A_ITAL;
    if UL then a := a or A_UL;
    if kind in [tkChar, tkSpace, tkHard] then
    begin
      if SupRun or SupNext then a := a or A_SUP;
      if SubRun or SubNext then a := a or A_SUB;
      SupNext := False;
      SubNext := False;
    end;
    toks[nt].Attr := a;
    Inc(nt);
  end;

  function TokW(const t: TTok): Integer;
  begin
    if t.Kind in [tkShy, tkBrk] then Result := 0 else Result := 1;
  end;

  { output one line made of tokens a..b-1 }
  procedure Emit(a, b: Integer; hyphen, isLast: Boolean);
  var
    cells, outc: TCellArr;
    c, e, lw, gaps, extra, base, rem, g, lcol, n2, pad, p: Integer;
    seenText, inGap: Boolean;
    t: TTok;
  begin
    e := b;
    while (e > a) and (toks[e - 1].Kind = tkSpace) do Dec(e);
    SetLength(cells, 0);
    for c := a to e - 1 do
    begin
      t := toks[c];
      if t.Kind in [tkShy, tkBrk] then Continue;
      n2 := Length(cells);
      SetLength(cells, n2 + 1);
      if t.Kind = tkHard then cells[n2].Ch := ' ' else cells[n2].Ch := t.Ch;
      cells[n2].Attr := t.Attr;
    end;
    if hyphen then
    begin
      n2 := Length(cells);
      SetLength(cells, n2 + 1);
      cells[n2].Ch := '-';
      if e > a then cells[n2].Attr := toks[e - 1].Attr else cells[n2].Attr := 0;
    end;
    lw := Length(cells);
    lcol := left;
    if Center then
      lcol := EffLM + (EffRM - EffLM + 1 - lw) div 2
    else if Just and (not isLast) and (lw > 0) then
    begin
      { count the gaps between words (leading spaces are not stretched) }
      gaps := 0;
      seenText := False;
      inGap := False;
      for c := 0 to lw - 1 do
        if cells[c].Ch <> ' ' then begin seenText := True; inGap := False; end
        else if seenText and (not inGap) then begin Inc(gaps); inGap := True; end;
      { a gap with no word after it is trailing, not a gap }
      if (lw > 0) and (cells[lw - 1].Ch = ' ') then Dec(gaps);
      extra := width - lw;
      if (gaps > 0) and (extra > 0) then
      begin
        base := extra div gaps;
        rem := extra mod gaps;
        SetLength(outc, 0);
        g := 0;
        seenText := False;
        inGap := False;
        for c := 0 to lw - 1 do
        begin
          if cells[c].Ch <> ' ' then begin seenText := True; inGap := False; end
          else if seenText and (not inGap) then
          begin
            inGap := True;
            pad := base;
            if g < rem then Inc(pad);
            Inc(g);
            p := Length(outc);
            SetLength(outc, p + pad);
            for n2 := 0 to pad - 1 do
            begin
              outc[p + n2].Ch := ' ';
              outc[p + n2].Attr := cells[c].Attr;
            end;
          end;
          n2 := Length(outc);
          SetLength(outc, n2 + 1);
          outc[n2] := cells[c];
        end;
        cells := outc;
      end;
    end
    else if RightAl and (not Just) then
      lcol := EffRM - lw + 1;
    if lcol < 1 then lcol := 1;
    AddLine(cells, lcol, src);
  end;

begin
  toks := nil;
  nt := 0;
  SetLength(toks, 64);
  for i := 1 to Length(s) do
    case s[i] of
      CH_UL_ON: UL := True;
      CH_UL_OFF: UL := False;
      CH_BOLD_ON: Bold := True;
      CH_BOLD_OFF: Bold := False;
      CH_IT_ON: Ital := True;
      CH_IT_OFF: Ital := False;
      CH_SUP_NEXT: SupNext := True;
      CH_SUB_NEXT: SubNext := True;
      CH_SUP_ON: SupRun := True;
      CH_SUP_OFF: SupRun := False;
      CH_SUB_ON: SubRun := True;
      CH_SUB_OFF: SubRun := False;
      CH_HARDSPACE: AddTok(tkHard, ' ');
      CH_SHY: AddTok(tkShy, '-');
      CH_BREAK: AddTok(tkBrk, ' ');
      CH_ULCHAR: AddTok(tkChar, '_');
      ' ': AddTok(tkSpace, ' ');
    else
      AddTok(tkChar, s[i]);
    end;

  allBlank := True;
  for i := 0 to nt - 1 do
    if toks[i].Kind <> tkSpace then allBlank := False;
  if allBlank then
  begin
    AddLine(nil, EffLM, src);
    MA := 0;
    Exit;
  end;

  i := 0;
  first := True;
  while i < nt do
  begin
    if first then left := EffLM + AI + MA else left := EffLM;
    if left < 1 then left := 1;
    if left > EffRM then left := EffRM;
    width := EffRM - left + 1;
    if width < 1 then width := 1;
    if not first then
      while (i < nt) and (toks[i].Kind = tkSpace) do Inc(i);
    if i >= nt then Break;
    k := i;
    w := 0;
    while k < nt do
    begin
      if (w + TokW(toks[k]) > width) and (toks[k].Kind <> tkSpace) then Break;
      Inc(w, TokW(toks[k]));
      Inc(k);
    end;
    if k >= nt then
    begin
      Emit(i, nt, False, True);
      i := nt;
    end
    else
    begin
      { toks[k] does not fit: find the start of its word }
      ws := k;
      while (ws > i) and (toks[ws - 1].Kind <> tkSpace) do Dec(ws);
      q := -1;
      for x := k - 1 downto ws do
        if toks[x].Kind in [tkShy, tkBrk] then
        begin
          if toks[x].Kind = tkShy then
          begin
            wcalc := 0;
            for w := i to x - 1 do Inc(wcalc, TokW(toks[w]));
            if wcalc + 1 <= width then q := x;
          end
          else
            q := x;
          if q >= 0 then Break;
        end;
      if q >= 0 then
      begin
        Emit(i, q, toks[q].Kind = tkShy, False);
        i := q + 1;
      end
      else if ws > i then
      begin
        Emit(i, ws, False, False);
        i := ws;
      end
      else
      begin
        Emit(i, k, False, False);
        i := k;
      end;
    end;
    first := False;
    MA := 0;
  end;
  MA := 0;
end;

{ ---- format lines ---- }

function ArgNum(const arg: UnicodeString; out sign, v: Integer): Boolean;
var
  i, n: Integer;
begin
  Result := False;
  sign := 0;
  v := 0;
  i := 1;
  while (i <= Length(arg)) and not ((arg[i] >= '0') and (arg[i] <= '9')) do Inc(i);
  if i > Length(arg) then Exit;
  if i > 1 then
  begin
    if arg[i - 1] = '+' then sign := 1
    else if arg[i - 1] = '-' then sign := -1;
  end;
  n := 0;
  while (i <= Length(arg)) and (arg[i] >= '0') and (arg[i] <= '9') and (n < 6) do
  begin
    v := v * 10 + (Ord(arg[i]) - 48);
    Inc(i);
    Inc(n);
  end;
  Result := True;
end;

{ on/off in any of the forms the manual allows: 1, 0, " on", " off", " one" ... }
function ArgFlag(const arg: UnicodeString): Boolean;
var
  i: Integer;
  t: UnicodeString;
begin
  Result := True;
  i := 1;
  while (i <= Length(arg)) and (arg[i] <> ' ') and not ((arg[i] >= '0') and (arg[i] <= '9')) do Inc(i);
  if i > Length(arg) then Exit;
  while (i <= Length(arg)) and (arg[i] = ' ') do Inc(i);
  if i > Length(arg) then Exit;
  if (arg[i] >= '0') and (arg[i] <= '9') then Exit(arg[i] <> '0');
  t := LowerCase(Copy(arg, i, 2));
  if t = 'of' then Result := False;
end;

function TFormatter.Follow(const name: string; src, depth: Integer; external_: Boolean): Boolean;
var
  paras: TStrArray;
begin
  Result := False;
  if name = '' then
  begin
    Warn(src, 'A link needs a file name');
    Exit;
  end;
  Inc(Chain);
  if Chain > 200 then
  begin
    Warn(src, 'Too many linked files (is there a loop?)');
    Exit;
  end;
  if (not Assigned(Loader)) or (not Loader(name, paras)) then
  begin
    Warn(src, 'Cannot read linked file ' + name);
    Exit;
  end;
  Process(paras, False, depth + 1);
  Result := True;
end;

procedure TFormatter.SyncHFMargins(left: Boolean);
begin
  if MLock then Exit;
  if left then begin HL := EffLM; FL := EffLM; end
  else begin HR := EffRM; FR := EffRM; end;
end;

{ Returns True when a link has been followed and this paragraph list is finished. }
function TFormatter.Directive(const s: UnicodeString; src, depth: Integer): Boolean;
var
  p, n, e, sign, v, i, remaining: Integer;
  cmd: string;
  arg, name, sep: UnicodeString;
  parts: array[0..2] of UnicodeString;
  c1, c2: WideChar;
  isText: Boolean;
  fname: string;

  function ChLower(c: WideChar): Char;
  begin
    if (c >= 'A') and (c <= 'Z') then c := WideChar(Ord(c) + 32);
    if Ord(c) < 128 then Result := Char(Ord(c)) else Result := '?';
  end;

  function StripColon(const t: UnicodeString): UnicodeString;
  begin
    Result := t;
    if (Result <> '') and (Result[1] = ':') then Delete(Result, 1, 1);
  end;

  procedure SplitHF(const t: UnicodeString; var dest: array of UnicodeString; out num: Integer);
  var
    k, st, cnt: Integer;
    sp_: WideChar;
    body: UnicodeString;
  begin
    num := 0;
    k := 1;
    while (k <= Length(t)) and (t[k] >= '0') and (t[k] <= '9') do
    begin
      num := num * 10 + (Ord(t[k]) - 48);
      Inc(k);
    end;
    dest[0] := ''; dest[1] := ''; dest[2] := '';
    if k > Length(t) then Exit;
    sp_ := t[k];
    body := Copy(t, k + 1, MaxInt);
    { old-style lines used ':' after the number and commas between the parts }
    if (sp_ = ':') and (Pos(':', body) = 0) and (Pos(',', body) > 0) then sp_ := ',';
    cnt := 0;
    st := 1;
    for k := 1 to Length(body) + 1 do
      if (k > Length(body)) or ((body[k] = sp_) and (cnt < 2)) then
      begin
        dest[cnt] := Copy(body, st, k - st);
        Inc(cnt);
        st := k + 1;
        if cnt > 2 then Break;
      end;
  end;

begin
  Result := False;
  n := Length(s);
  p := 2;
  while p <= n do
  begin
    while (p <= n) and ((s[p] = ' ') or (s[p] = ':')) do Inc(p);
    if p > n then Break;
    if p + 1 > n then
    begin
      Warn(src, 'Incomplete format command');
      Break;
    end;
    c1 := s[p];
    c2 := s[p + 1];
    if c2 = '=' then Break;                  { instant phrase or printer-code definition: not printed }
    cmd := ChLower(c1) + ChLower(c2);
    isText := (cmd = 'cm') or (cmd = 'ps') or (cmd = 'tb') or (cmd = 'tf') or (cmd = 'nx') or
              (cmd = 'ex') or (cmd = 'ep') or (cmd = 'lk') or (cmd = 'hd') or (cmd = 'ft');
    if isText then
    begin
      arg := Copy(s, p + 2, MaxInt);
      p := n + 1;
    end
    else
    begin
      e := p + 2;
      while (e <= n) and (s[e] <> ':') do Inc(e);
      arg := Copy(s, p + 2, e - p - 2);
      p := e + 1;
    end;

    if cmd = 'lm' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if sign > 0 then LMAdj := v
        else if sign < 0 then LMAdj := -v
        else begin LM := v; LMAdj := 0; end;
        if (LM < 1) or (LM + LMAdj < 1) then begin Warn(src, 'Left margin out of range'); end;
        if EffLM > EffRM then begin Warn(src, 'The left margin cannot be right of the right margin'); LMAdj := 0; if LM > EffRM then LM := EffRM; end;
        SyncHFMargins(True);
      end
      else Warn(src, 'lm needs a number');
    end
    else if cmd = 'rm' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if sign > 0 then RMAdj := v
        else if sign < 0 then RMAdj := -v
        else begin RM := v; RMAdj := 0; end;
        if EffRM < EffLM then begin Warn(src, 'The right margin cannot be left of the left margin'); RMAdj := 0; if RM < EffLM then RM := EffLM; end;
        SyncHFMargins(False);
      end
      else Warn(src, 'rm needs a number');
    end
    else if cmd = 'pp' then
    begin
      if ArgNum(arg, sign, v) and (v >= 1) then
      begin
        if (CurPage <> nil) and (Used > 0) then FinishPage;
        PL := v;
        PG := v;
      end
      else Warn(src, 'pp needs a number');
    end
    else if cmd = 'pg' then
    begin
      if ArgNum(arg, sign, v) and (v >= 1) then
      begin
        if (CurPage <> nil) and (Used > 0) then FinishPage;
        PG := v;
      end
      else Warn(src, 'pg needs a number');
    end
    else if cmd = 'vp' then
    begin
      if ArgNum(arg, sign, v) then VP := v else Warn(src, 'vp needs a number');
    end
    else if cmd = 'of' then
    begin
      if ArgNum(arg, sign, v) then Offset := v else Warn(src, 'of needs a number');
    end
    else if cmd = 'ls' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if (v = 6) or (v = 8) then LPI := v else LPI := 4;
      end
      else Warn(src, 'ls needs a number');
    end
    else if cmd = 'sp' then
    begin
      if ArgNum(arg, sign, v) and (v >= 1) then begin if v > 9 then v := 9; SP := v; end
      else Warn(src, 'sp needs a number');
    end
    else if cmd = 'pt' then
    begin
      if ArgNum(arg, sign, v) then Pitch := PitchValue(v) else Warn(src, 'pt needs a number');
    end
    else if cmd = 'ph' then
    begin
      if ArgNum(arg, sign, v) then HdPitch := PitchValue(v) else Warn(src, 'ph needs a number');
    end
    else if cmd = 'pf' then
    begin
      if ArgNum(arg, sign, v) then FtPitch := PitchValue(v) else Warn(src, 'pf needs a number');
    end
    else if cmd = 'ln' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if (CurPage <> nil) and (Used > 0) then
        begin
          Used := Used + v;
          if Used >= Cap then FinishPage;
        end;
      end
      else Warn(src, 'ln needs a number');
    end
    else if cmd = 'cm' then
    begin
      { a comment }
    end
    else if cmd = 'ps' then
    begin
      name := Trim(StripColon(arg));
      if CurPage <> nil then CurPage.Notes.Add(UTF8Encode(name))
      else Pending.Add(UTF8Encode(name));
    end
    else if cmd = 'ju' then Just := ArgFlag(arg)
    else if (cmd = 'ce') or (cmd = 'cn') then Center := ArgFlag(arg)
    else if cmd = 'ra' then RightAl := ArgFlag(arg)
    else if cmd = 'ml' then MLock := ArgFlag(arg)
    else if cmd = 'fp' then
    begin
      if CurPage <> nil then
      begin
        if ArgNum(arg, sign, v) then
        begin
          remaining := Cap - Used;
          if remaining < v then FinishPage;
        end
        else FinishPage;
      end;
    end
    else if cmd = 'ma' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if sign < 0 then MA := -v else MA := v;
      end
      else Warn(src, 'ma needs a number');
    end
    else if cmd = 'ai' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if sign < 0 then AI := -v else AI := v;
      end
      else Warn(src, 'ai needs a number');
    end
    else if (cmd = 'hd') or (cmd = 'ft') then
    begin
      SplitHF(arg, parts, v);
      if cmd = 'hd' then
      begin
        HdOn := v > 0;
        HdN := v;
        for i := 0 to 2 do HdTxt[i] := parts[i];
      end
      else
      begin
        FtOn := v > 0;
        FtN := v;
        for i := 0 to 2 do FtTxt[i] := parts[i];
      end;
    end
    else if cmd = 'hl' then begin if ArgNum(arg, sign, v) then HL := v else Warn(src, 'hl needs a number'); end
    else if cmd = 'hr' then begin if ArgNum(arg, sign, v) then HR := v else Warn(src, 'hr needs a number'); end
    else if cmd = 'fl' then begin if ArgNum(arg, sign, v) then FL := v else Warn(src, 'fl needs a number'); end
    else if cmd = 'fr' then begin if ArgNum(arg, sign, v) then FR := v else Warn(src, 'fr needs a number'); end
    else if cmd = 'p#' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if sign > 0 then PageNo := PageNo + v
        else if sign < 0 then PageNo := PageNo - v
        else PageNo := v;
      end
      else Warn(src, 'p# needs a number');
    end
    else if cmd = 'ch' then
    begin
      if ArgNum(arg, sign, v) then
      begin
        if sign > 0 then ChapNo := ChapNo + v
        else if sign < 0 then ChapNo := ChapNo - v
        else ChapNo := v;
      end
      else Warn(src, 'ch needs a number');
    end
    else if cmd = 'tf' then
    begin
      name := Trim(StripColon(arg));
      if (Length(name) > 1) and (name[2] = ':') and ((name[1] = '0') or (name[1] = '1')) then Delete(name, 1, 2);
      TocFile := UTF8Encode(name);
    end
    else if cmd = 'tb' then
    begin
      if CurPage <> nil then v := CurPage.Number else v := PageNo;
      TocEntries.Add(IntToStr(v) + #9 + UTF8Encode(Trim(StripColon(arg))));
    end
    else if cmd = 'nx' then
    begin
      fname := UTF8Encode(Trim(StripColon(arg)));
      Follow(fname, src, depth, False);
      Exit(True);
    end
    else if cmd = 'lk' then
    begin
      if Assigned(AskNext) then fname := AskNext() else fname := '';
      if fname = '' then Exit(True);
      Follow(fname, src, depth, False);
      Exit(True);
    end
    else if cmd = 'ex' then
    begin
      if depth >= 1 then Warn(src, 'Only one level of external file links is allowed')
      else Follow(UTF8Encode(Trim(StripColon(arg))), src, depth, True);
    end
    else if cmd = 'ep' then
      Warn(src, 'External print (ep:) sends raw data to a printer and is not supported')
    else
      Warn(src, 'Unknown format command "' + UTF8Encode(UnicodeString(c1) + UnicodeString(c2)) + '"');
  end;
end;

procedure TFormatter.Process(const paras: TStrArray; root: Boolean; depth: Integer);
var
  i: Integer;
  src: Integer;
begin
  for i := 0 to High(paras) do
  begin
    if root then src := i else src := -1;
    if IsFormatLine(paras[i]) then
    begin
      if Directive(paras[i], src, depth) then Exit;
    end
    else
      EmitParagraph(paras[i], src);
  end;
end;

procedure TFormatter.Run(const paras: TStrArray);
begin
  Pages.Clear;
  Warnings.Clear;
  TocEntries.Clear;
  Pending.Clear;
  FWarned.Clear;
  LM := 10; RM := 70; LMAdj := 0; RMAdj := 0;
  PL := DefaultPaperLines;
  PG := PL - 10;
  VP := 0;
  Offset := 0;
  LPI := 6;
  SP := 1;
  Pitch := 10;
  Just := False; Center := False; RightAl := False;
  AI := 0; MA := 0;
  HdOn := False; FtOn := False;
  HdN := 0; FtN := 0;
  HdTxt[0] := ''; HdTxt[1] := ''; HdTxt[2] := '';
  FtTxt[0] := ''; FtTxt[1] := ''; FtTxt[2] := '';
  HL := 10; HR := 70; FL := 10; FR := 70;
  MLock := False;
  HdPitch := 0; FtPitch := 0;
  PageNo := 1;
  ChapNo := 1;
  Bold := False; Ital := False; UL := False;
  SupRun := False; SubRun := False; SupNext := False; SubNext := False;
  CurPage := nil;
  Used := 0;
  TocFile := '';
  TocFileName := '';
  Chain := 0;
  Process(paras, True, 0);
  FinishPage;
  TocFileName := TocFile;
end;

end.
