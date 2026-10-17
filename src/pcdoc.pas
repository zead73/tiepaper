{ pcdoc - the document model.

  A document is a list of paragraphs.  Each paragraph ends with a "return
  marker" (shown as a left arrow), exactly as in PaperClip.  Long paragraphs are
  word-wrapped for display only; the wrapping width never changes the text.

  Embedded print enhancements (underline, boldface, ...) and the format-line
  checkmark live in the text as ordinary characters, so they can be edited,
  searched, moved and copied like any other text.  Where Unicode already has the
  right character it is used (hard space = U+00A0, conditional hyphen = U+00AD,
  breakpoint = U+200B); the on/off switches use the private-use area. }
unit pcdoc;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

const
  MAXWIDTH = 400;               { widest editing line }

  CH_CHECK = WideChar($2713);   { starts a format line }
  CH_UL_ON = WideChar($E001);
  CH_UL_OFF = WideChar($E002);
  CH_BOLD_ON = WideChar($E003);
  CH_BOLD_OFF = WideChar($E004);
  CH_IT_ON = WideChar($E005);
  CH_IT_OFF = WideChar($E006);
  CH_SUP_NEXT = WideChar($E007);
  CH_SUP_ON = WideChar($E008);
  CH_SUP_OFF = WideChar($E009);
  CH_SUB_NEXT = WideChar($E00A);
  CH_SUB_ON = WideChar($E00B);
  CH_SUB_OFF = WideChar($E00C);
  CH_ULCHAR = WideChar($E010);  { prints as a plain underline character }
  CH_HARDSPACE = WideChar($00A0);
  CH_SHY = WideChar($00AD);     { conditional hyphen }
  CH_BREAK = WideChar($200B);   { breakpoint }
  CH_META = WideChar($E0F0);    { first line of a saved file: line length and tabs }

  TAB_REG = 1;
  TAB_NUM = 2;

type
  TIntArray = array of Integer;
  TStrArray = array of UnicodeString;

  TUndoSnap = record
    Lines: TStrArray;
    CurP, CurC: Integer;
  end;

  TDoc = class
  private
    FLines: TStrArray;
    FCount: Integer;
    FUndo: array of TUndoSnap;
    FRedo: array of TUndoSnap;
    FLastKey: Integer;
    { layout cache }
    FLayW: Integer;
    FLayDirty: Boolean;
    FRowPara, FRowStart, FRowLen: TIntArray;
    FParaRow: TIntArray;
    FRowCount: Integer;
    function GetLine(i: Integer): UnicodeString;
    procedure SetLine(i: Integer; const s: UnicodeString);
    procedure Grow(n: Integer);
    procedure Touch;
    procedure Snapshot(var snap: TUndoSnap);
    procedure Restore(const snap: TUndoSnap);
    procedure ClearMarks;
  public
    FileName: string;
    Rev: LongWord;                          { changes whenever the text does }
    Modified: Boolean;
    LineLen: Integer;                       { 0 = fit the window }
    Tabs: array[0..MAXWIDTH] of Byte;       { by 0-based column }
    CurP, CurC: Integer;                    { cursor: paragraph and character }

    RangeSet: Boolean;
    RangeP1, RangeP2: Integer;
    PhraseSet: Boolean;
    PhP, PhC1, PhC2: Integer;               { C2 is exclusive }
    ColSet: Boolean;
    ColP1, ColP2, ColC1, ColC2: Integer;    { C2 is exclusive }
    MarkP: array[0..1] of Integer;          { two bookmarks; -1 = unset }
    MarkNext: Integer;

    constructor Create;
    procedure Clear;
    property Count: Integer read FCount;
    property Line[i: Integer]: UnicodeString read GetLine write SetLine; default;

    { primitive edits: every edit goes through these so marks and the cursor stay put }
    procedure InsText(p, c: Integer; const s: UnicodeString);
    procedure DelText(p, c, n: Integer);
    procedure SplitPara(p, c: Integer);
    procedure JoinPara(p: Integer);
    procedure InsPara(p: Integer; const s: UnicodeString);
    procedure DelParas(p, n: Integer);
    procedure ReplaceText(p: Integer; const s: UnicodeString);   { no mark adjustment beyond clamping }

    { undo: key <> 0 merges consecutive edits with the same key (typing) }
    procedure PushUndo(key: Integer);
    function Undo: Boolean;
    function Redo: Boolean;
    procedure ForgetUndo;
    procedure BreakGroup;

    { display layout }
    procedure EnsureLayout(w: Integer);
    property RowCount: Integer read FRowCount;
    function RowPara(r: Integer): Integer;
    function RowStart(r: Integer): Integer;
    function RowLen(r: Integer): Integer;
    function ParaFirstRow(p: Integer): Integer;
    function ParaRows(p: Integer): Integer;
    procedure PosToRowCol(p, c: Integer; out row, col: Integer);
    procedure RowColToPos(row, col: Integer; out p, c: Integer);

    { files }
    function LoadFromFile(const fn: string): string;     { '' = ok }
    function SaveToFile(const fn: string; withMeta: Boolean): string;
    function PlainText: UnicodeString;
    procedure SetText(const s: UnicodeString);

    function NextTab(col: Integer; numericOnly: Boolean): Integer;   { -1 = none }
    function TabCount: Integer;
    function MetaLine: UnicodeString;
    procedure ApplyMeta(const s: UnicodeString);
  end;

function IsFormatLine(const s: UnicodeString): Boolean;
function IsMarkerChar(ch: WideChar): Boolean;
function StripMarkers(const s: UnicodeString): UnicodeString;
function DecodeText(const raw: RawByteString): UnicodeString;
procedure WrapPara(const s: UnicodeString; w: Integer; var starts: TIntArray; var cnt: Integer);
function Latin1Fold(const s: UnicodeString): UnicodeString;

implementation

function IsFormatLine(const s: UnicodeString): Boolean;
begin
  Result := (Length(s) > 0) and (s[1] = CH_CHECK);
end;

function IsMarkerChar(ch: WideChar): Boolean;
begin
  Result := ((ch >= #$E001) and (ch <= #$E010)) or (ch = CH_SHY) or (ch = CH_BREAK);
end;

function StripMarkers(const s: UnicodeString): UnicodeString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    case s[i] of
      CH_UL_ON, CH_UL_OFF, CH_BOLD_ON, CH_BOLD_OFF, CH_IT_ON, CH_IT_OFF,
      CH_SUP_NEXT, CH_SUP_ON, CH_SUP_OFF, CH_SUB_NEXT, CH_SUB_ON, CH_SUB_OFF,
      CH_SHY, CH_BREAK: ;
      CH_HARDSPACE: Result := Result + ' ';
      CH_ULCHAR: Result := Result + '_';
    else
      Result := Result + s[i];
    end;
end;

function Latin1Fold(const s: UnicodeString): UnicodeString;
begin
  Result := LowerCase(s);
end;

{ Decodes UTF-8 when the bytes are valid UTF-8, otherwise treats them as Latin-1.
  Characters outside the BMP become U+FFFD (the editor is one cell per character). }
function DecodeText(const raw: RawByteString): UnicodeString;
var
  i, n, len, extra: Integer;
  b: Byte;
  cp: LongWord;
  valid: Boolean;
  r: UnicodeString;
begin
  n := Length(raw);
  i := 1;
  if (n >= 3) and (raw[1] = #$EF) and (raw[2] = #$BB) and (raw[3] = #$BF) then i := 4;
  valid := True;
  { validate }
  len := i;
  while len <= n do
  begin
    b := Ord(raw[len]);
    if b < $80 then extra := 0
    else if (b and $E0) = $C0 then extra := 1
    else if (b and $F0) = $E0 then extra := 2
    else if (b and $F8) = $F0 then extra := 3
    else begin valid := False; Break; end;
    if len + extra > n then begin valid := False; Break; end;
    while extra > 0 do
    begin
      Inc(len);
      if (Ord(raw[len]) and $C0) <> $80 then begin valid := False; Break; end;
      Dec(extra);
    end;
    if not valid then Break;
    Inc(len);
  end;
  SetLength(r, n);
  len := 0;
  if not valid then
  begin
    for i := 1 to n do
    begin
      Inc(len);
      r[len] := WideChar(Ord(raw[i]));
    end;
    SetLength(r, len);
    Exit(r);
  end;
  while i <= n do
  begin
    b := Ord(raw[i]);
    if b < $80 then begin cp := b; Inc(i); end
    else if (b and $E0) = $C0 then
    begin
      cp := ((b and $1F) shl 6) or (Ord(raw[i + 1]) and $3F);
      Inc(i, 2);
    end
    else if (b and $F0) = $E0 then
    begin
      cp := ((b and $0F) shl 12) or ((Ord(raw[i + 1]) and $3F) shl 6) or (Ord(raw[i + 2]) and $3F);
      Inc(i, 3);
    end
    else
    begin
      cp := $FFFD;
      Inc(i, 4);
    end;
    Inc(len);
    if cp > $FFFF then cp := $FFFD;
    r[len] := WideChar(cp);
  end;
  SetLength(r, len);
  Result := r;
end;

procedure WrapPara(const s: UnicodeString; w: Integer; var starts: TIntArray; var cnt: Integer);
var
  st, n, lim, k, p: Integer;
begin
  cnt := 0;
  n := Length(s);
  st := 0;
  if w < 1 then w := 1;
  repeat
    if cnt >= Length(starts) then SetLength(starts, Length(starts) * 2 + 4);
    starts[cnt] := st;
    Inc(cnt);
    if n - st <= w then Break;
    lim := st + w;                       { 0-based index of first character beyond the window }
    if s[lim + 1] = ' ' then
    begin
      k := lim;                          { trailing spaces hang past the window }
      while (k < n) and (s[k + 1] = ' ') do Inc(k);
    end
    else
    begin
      p := lim - 1;
      while (p >= st) and (s[p + 1] <> ' ') do Dec(p);
      if p >= st then k := p + 1 else k := lim;
    end;
    st := k;
  until st >= n;
end;

{ TDoc }

constructor TDoc.Create;
begin
  inherited Create;
  FLayW := -1;
  Clear;
end;

procedure TDoc.ClearMarks;
begin
  RangeSet := False;
  PhraseSet := False;
  ColSet := False;
  MarkP[0] := -1;
  MarkP[1] := -1;
  MarkNext := 0;
end;

procedure TDoc.Clear;
begin
  SetLength(FLines, 16);
  FCount := 1;
  FLines[0] := '';
  CurP := 0;
  CurC := 0;
  ClearMarks;
  FillChar(Tabs, SizeOf(Tabs), 0);
  LineLen := 0;
  FileName := '';
  Modified := False;
  SetLength(FUndo, 0);
  SetLength(FRedo, 0);
  FLastKey := 0;
  Touch;
end;

procedure TDoc.Touch;
begin
  FLayDirty := True;
  Inc(Rev);
end;

procedure TDoc.Grow(n: Integer);
begin
  if n > Length(FLines) then SetLength(FLines, n * 2);
end;

function TDoc.GetLine(i: Integer): UnicodeString;
begin
  if (i < 0) or (i >= FCount) then Result := '' else Result := FLines[i];
end;

procedure TDoc.SetLine(i: Integer; const s: UnicodeString);
begin
  if (i >= 0) and (i < FCount) then
  begin
    FLines[i] := s;
    Modified := True;
    Touch;
  end;
end;

procedure TDoc.InsText(p, c: Integer; const s: UnicodeString);
var
  n: Integer;
begin
  if (s = '') or (p < 0) or (p >= FCount) then Exit;
  if c > Length(FLines[p]) then c := Length(FLines[p]);
  n := Length(s);
  Insert(s, FLines[p], c + 1);
  if (CurP = p) and (CurC >= c) then Inc(CurC, n);
  if PhraseSet and (PhP = p) then
  begin
    if c <= PhC1 then begin Inc(PhC1, n); Inc(PhC2, n); end
    else if c < PhC2 then Inc(PhC2, n);
  end;
  Modified := True;
  Touch;
end;

procedure TDoc.DelText(p, c, n: Integer);
var
  len: Integer;

  function Fix(x: Integer): Integer;
  begin
    if x <= c then Result := x
    else if x >= c + n then Result := x - n
    else Result := c;
  end;

begin
  if (p < 0) or (p >= FCount) or (n <= 0) then Exit;
  len := Length(FLines[p]);
  if c >= len then Exit;
  if c + n > len then n := len - c;
  Delete(FLines[p], c + 1, n);
  if CurP = p then CurC := Fix(CurC);
  if PhraseSet and (PhP = p) then
  begin
    PhC1 := Fix(PhC1);
    PhC2 := Fix(PhC2);
    if PhC2 <= PhC1 then PhraseSet := False;
  end;
  Modified := True;
  Touch;
end;

procedure TDoc.SplitPara(p, c: Integer);
var
  tail: UnicodeString;
  i: Integer;
begin
  if (p < 0) or (p >= FCount) then Exit;
  if c > Length(FLines[p]) then c := Length(FLines[p]);
  tail := Copy(FLines[p], c + 1, MaxInt);
  FLines[p] := Copy(FLines[p], 1, c);
  Grow(FCount + 1);
  for i := FCount downto p + 2 do FLines[i] := FLines[i - 1];
  FLines[p + 1] := tail;
  Inc(FCount);
  { marks }
  if (CurP > p) then Inc(CurP)
  else if (CurP = p) and (CurC >= c) then begin Inc(CurP); Dec(CurC, c); end;
  if RangeSet then
  begin
    if RangeP1 > p then Inc(RangeP1);
    if RangeP2 > p then Inc(RangeP2);
  end;
  if PhraseSet then
  begin
    if PhP > p then Inc(PhP)
    else if PhP = p then
    begin
      if PhC1 >= c then begin Inc(PhP); Dec(PhC1, c); Dec(PhC2, c); end
      else if PhC2 > c then PhC2 := c;
    end;
  end;
  if ColSet then
  begin
    if ColP1 > p then Inc(ColP1);
    if ColP2 > p then Inc(ColP2);
  end;
  for i := 0 to 1 do
    if MarkP[i] > p then Inc(MarkP[i]);
  Modified := True;
  Touch;
end;

procedure TDoc.JoinPara(p: Integer);
var
  i, oldLen: Integer;
begin
  if (p < 0) or (p + 1 >= FCount) then Exit;
  oldLen := Length(FLines[p]);
  FLines[p] := FLines[p] + FLines[p + 1];
  for i := p + 1 to FCount - 2 do FLines[i] := FLines[i + 1];
  FLines[FCount - 1] := '';
  Dec(FCount);
  if CurP > p + 1 then Dec(CurP)
  else if CurP = p + 1 then begin CurP := p; Inc(CurC, oldLen); end;
  if RangeSet then
  begin
    if RangeP1 > p then Dec(RangeP1);
    if RangeP2 > p then Dec(RangeP2);
  end;
  if PhraseSet then
  begin
    if PhP > p + 1 then Dec(PhP)
    else if PhP = p + 1 then begin PhP := p; Inc(PhC1, oldLen); Inc(PhC2, oldLen); end;
  end;
  if ColSet then
  begin
    if ColP1 > p then Dec(ColP1);
    if ColP2 > p then Dec(ColP2);
  end;
  for i := 0 to 1 do
    if MarkP[i] > p then Dec(MarkP[i]);
  Modified := True;
  Touch;
end;

procedure TDoc.InsPara(p: Integer; const s: UnicodeString);
var
  i: Integer;
begin
  if p < 0 then p := 0;
  if p > FCount then p := FCount;
  Grow(FCount + 1);
  for i := FCount downto p + 1 do FLines[i] := FLines[i - 1];
  FLines[p] := s;
  Inc(FCount);
  if CurP >= p then Inc(CurP);
  if RangeSet then
  begin
    if p <= RangeP1 then begin Inc(RangeP1); Inc(RangeP2); end
    else if p <= RangeP2 then Inc(RangeP2);
  end;
  if PhraseSet and (PhP >= p) then Inc(PhP);
  if ColSet then
  begin
    if p <= ColP1 then begin Inc(ColP1); Inc(ColP2); end
    else if p <= ColP2 then Inc(ColP2);
  end;
  for i := 0 to 1 do
    if MarkP[i] >= p then Inc(MarkP[i]);
  Modified := True;
  Touch;
end;

procedure TDoc.DelParas(p, n: Integer);
var
  i: Integer;

  function Fix(x: Integer): Integer;
  begin
    if x < p then Result := x
    else if x >= p + n then Result := x - n
    else Result := p;
  end;

begin
  if (p < 0) or (p >= FCount) or (n <= 0) then Exit;
  if p + n > FCount then n := FCount - p;
  for i := p to FCount - n - 1 do FLines[i] := FLines[i + n];
  for i := FCount - n to FCount - 1 do FLines[i] := '';
  Dec(FCount, n);
  if FCount = 0 then
  begin
    FCount := 1;
    FLines[0] := '';
  end;
  if (CurP >= p) then
  begin
    if CurP < p + n then CurC := 0;
    CurP := Fix(CurP);
    if CurP >= FCount then CurP := FCount - 1;
  end;
  if RangeSet then
  begin
    if (RangeP1 >= p) and (RangeP2 < p + n) then RangeSet := False
    else begin RangeP1 := Fix(RangeP1); RangeP2 := Fix(RangeP2); if RangeP2 >= FCount then RangeP2 := FCount - 1; end;
  end;
  if PhraseSet then
  begin
    if (PhP >= p) and (PhP < p + n) then PhraseSet := False else PhP := Fix(PhP);
  end;
  if ColSet then
  begin
    if (ColP1 >= p) and (ColP2 < p + n) then ColSet := False
    else begin ColP1 := Fix(ColP1); ColP2 := Fix(ColP2); if ColP2 >= FCount then ColP2 := FCount - 1; end;
  end;
  for i := 0 to 1 do
    if MarkP[i] >= 0 then
    begin
      if (MarkP[i] >= p) and (MarkP[i] < p + n) then MarkP[i] := -1 else MarkP[i] := Fix(MarkP[i]);
    end;
  Modified := True;
  Touch;
end;

procedure TDoc.ReplaceText(p: Integer; const s: UnicodeString);
begin
  if (p < 0) or (p >= FCount) then Exit;
  FLines[p] := s;
  if (CurP = p) and (CurC > Length(s)) then CurC := Length(s);
  if PhraseSet and (PhP = p) then
  begin
    if PhC1 > Length(s) then PhraseSet := False
    else if PhC2 > Length(s) then PhC2 := Length(s);
  end;
  Modified := True;
  Touch;
end;

{ undo }

procedure TDoc.Snapshot(var snap: TUndoSnap);
var
  i: Integer;
begin
  SetLength(snap.Lines, FCount);
  for i := 0 to FCount - 1 do snap.Lines[i] := FLines[i];
  snap.CurP := CurP;
  snap.CurC := CurC;
end;

procedure TDoc.Restore(const snap: TUndoSnap);
var
  i: Integer;
begin
  FCount := Length(snap.Lines);
  if FCount = 0 then FCount := 1;
  SetLength(FLines, FCount + 16);
  for i := 0 to Length(snap.Lines) - 1 do FLines[i] := snap.Lines[i];
  if Length(snap.Lines) = 0 then FLines[0] := '';
  CurP := snap.CurP;
  CurC := snap.CurC;
  if CurP >= FCount then CurP := FCount - 1;
  ClearMarks;
  Modified := True;
  Touch;
end;

procedure TDoc.PushUndo(key: Integer);
const
  MAXUNDO = 200;
var
  n, i, limit: Integer;
begin
  if (key <> 0) and (key = FLastKey) then Exit;
  FLastKey := key;
  n := Length(FUndo);
  limit := MAXUNDO;
  if FCount > 20000 then limit := 30;          { each snapshot is an array of every paragraph }
  while n > limit do
  begin
    for i := 1 to n - 1 do FUndo[i - 1] := FUndo[i];
    Dec(n);
    SetLength(FUndo, n);
  end;
  if n >= limit then
  begin
    for i := 1 to n - 1 do FUndo[i - 1] := FUndo[i];
    Dec(n);
  end
  else
    SetLength(FUndo, n + 1);
  Snapshot(FUndo[n]);
  SetLength(FRedo, 0);
end;

function TDoc.Undo: Boolean;
var
  n: Integer;
begin
  n := Length(FUndo);
  if n = 0 then Exit(False);
  SetLength(FRedo, Length(FRedo) + 1);
  Snapshot(FRedo[High(FRedo)]);
  Restore(FUndo[n - 1]);
  SetLength(FUndo, n - 1);
  FLastKey := 0;
  Result := True;
end;

function TDoc.Redo: Boolean;
var
  n: Integer;
begin
  n := Length(FRedo);
  if n = 0 then Exit(False);
  SetLength(FUndo, Length(FUndo) + 1);
  Snapshot(FUndo[High(FUndo)]);
  Restore(FRedo[n - 1]);
  SetLength(FRedo, n - 1);
  FLastKey := 0;
  Result := True;
end;

procedure TDoc.BreakGroup;
begin
  FLastKey := 0;
end;

procedure TDoc.ForgetUndo;
begin
  SetLength(FUndo, 0);
  SetLength(FRedo, 0);
  FLastKey := 0;
end;

{ layout }

procedure TDoc.EnsureLayout(w: Integer);
var
  p, i, cnt, rows: Integer;
  starts: TIntArray;
begin
  if w < 1 then w := 1;
  if (not FLayDirty) and (w = FLayW) then Exit;
  FLayW := w;
  FLayDirty := False;
  SetLength(FParaRow, FCount + 1);
  SetLength(starts, 16);
  rows := 0;
  if Length(FRowPara) < FCount + 16 then
  begin
    SetLength(FRowPara, FCount * 2 + 16);
    SetLength(FRowStart, Length(FRowPara));
    SetLength(FRowLen, Length(FRowPara));
  end;
  for p := 0 to FCount - 1 do
  begin
    FParaRow[p] := rows;
    WrapPara(FLines[p], w, starts, cnt);
    if rows + cnt > Length(FRowPara) then
    begin
      SetLength(FRowPara, (rows + cnt) * 2);
      SetLength(FRowStart, Length(FRowPara));
      SetLength(FRowLen, Length(FRowPara));
    end;
    for i := 0 to cnt - 1 do
    begin
      FRowPara[rows] := p;
      FRowStart[rows] := starts[i];
      if i + 1 < cnt then FRowLen[rows] := starts[i + 1] - starts[i]
      else FRowLen[rows] := Length(FLines[p]) - starts[i];
      Inc(rows);
    end;
  end;
  FParaRow[FCount] := rows;
  FRowCount := rows;
end;

function TDoc.RowPara(r: Integer): Integer;
begin
  Result := FRowPara[r];
end;

function TDoc.RowStart(r: Integer): Integer;
begin
  Result := FRowStart[r];
end;

function TDoc.RowLen(r: Integer): Integer;
begin
  Result := FRowLen[r];
end;

function TDoc.ParaFirstRow(p: Integer): Integer;
begin
  if p >= FCount then Result := FRowCount else Result := FParaRow[p];
end;

function TDoc.ParaRows(p: Integer): Integer;
begin
  Result := FParaRow[p + 1] - FParaRow[p];
end;

procedure TDoc.PosToRowCol(p, c: Integer; out row, col: Integer);
var
  r, last: Integer;
begin
  if p < 0 then p := 0;
  if p >= FCount then p := FCount - 1;
  r := FParaRow[p];
  last := FParaRow[p + 1] - 1;
  while (r < last) and (c >= FRowStart[r + 1]) do Inc(r);
  row := r;
  col := c - FRowStart[r];
  if col < 0 then col := 0;
end;

procedure TDoc.RowColToPos(row, col: Integer; out p, c: Integer);
var
  maxc: Integer;
begin
  if row < 0 then row := 0;
  if row >= FRowCount then row := FRowCount - 1;
  p := FRowPara[row];
  if col < 0 then col := 0;
  if row = FParaRow[p + 1] - 1 then maxc := FRowLen[row]
  else maxc := FRowLen[row] - 1;
  if maxc < 0 then maxc := 0;
  if col > maxc then col := maxc;
  c := FRowStart[row] + col;
end;

{ files }

function TDoc.MetaLine: UnicodeString;
var
  i: Integer;
  t: UnicodeString;
begin
  t := '';
  for i := 0 to MAXWIDTH do
  begin
    if (Tabs[i] and TAB_REG) <> 0 then
    begin
      if t <> '' then t := t + ',';
      t := t + UnicodeString(IntToStr(i + 1));
    end;
    if (Tabs[i] and TAB_NUM) <> 0 then
    begin
      if t <> '' then t := t + ',';
      t := t + UnicodeString(IntToStr(i + 1)) + 'n';
    end;
  end;
  Result := CH_META + 'PAPERCLIP 1 ll=' + UnicodeString(IntToStr(LineLen)) + ' tabs=' + t;
end;

procedure TDoc.ApplyMeta(const s: UnicodeString);
var
  parts, sl: TStringList;
  i, j, v: Integer;
  item, tl: string;
begin
  FillChar(Tabs, SizeOf(Tabs), 0);
  LineLen := 0;
  parts := TStringList.Create;
  try
    parts.Delimiter := ' ';
    parts.StrictDelimiter := True;
    parts.DelimitedText := UTF8Encode(Copy(s, 2, MaxInt));
    for i := 0 to parts.Count - 1 do
    begin
      item := parts[i];
      if Copy(item, 1, 3) = 'll=' then
      begin
        v := StrToIntDef(Copy(item, 4, MaxInt), 0);
        if (v >= 20) and (v <= MAXWIDTH) then LineLen := v;
      end
      else if Copy(item, 1, 5) = 'tabs=' then
      begin
        sl := TStringList.Create;
        try
          sl.Delimiter := ',';
          sl.StrictDelimiter := True;
          sl.DelimitedText := Copy(item, 6, MaxInt);
          for j := 0 to sl.Count - 1 do
          begin
            tl := sl[j];
            if tl = '' then Continue;
            if tl[Length(tl)] = 'n' then
            begin
              v := StrToIntDef(Copy(tl, 1, Length(tl) - 1), 0);
              if (v >= 1) and (v <= MAXWIDTH + 1) then Tabs[v - 1] := Tabs[v - 1] or TAB_NUM;
            end
            else
            begin
              v := StrToIntDef(tl, 0);
              if (v >= 1) and (v <= MAXWIDTH + 1) then Tabs[v - 1] := Tabs[v - 1] or TAB_REG;
            end;
          end;
        finally
          sl.Free;
        end;
      end;
    end;
  finally
    parts.Free;
  end;
end;

{ Expands tabs to the next multiple of 8 and drops other control characters. }
function CleanLine(const s: UnicodeString): UnicodeString;
var
  i, col, k: Integer;
  clean: Boolean;
begin
  clean := True;
  for i := 1 to Length(s) do
    if s[i] < ' ' then begin clean := False; Break; end;
  if clean then Exit(s);
  Result := '';
  col := 0;
  for i := 1 to Length(s) do
    if s[i] = #9 then
    begin
      k := 8 - (col mod 8);
      Result := Result + UnicodeString(StringOfChar(' ', k));
      Inc(col, k);
    end
    else if s[i] >= ' ' then
    begin
      Result := Result + s[i];
      Inc(col);
    end;
end;

procedure TDoc.SetText(const s: UnicodeString);
var
  i, st, n: Integer;
  t: UnicodeString;
  list: TStrArray;
  cnt: Integer;
begin
  n := Length(s);
  SetLength(list, 16);
  cnt := 0;
  st := 1;
  i := 1;
  while i <= n do
  begin
    if (s[i] = #10) or (s[i] = #13) then
    begin
      t := CleanLine(Copy(s, st, i - st));
      if cnt >= Length(list) then SetLength(list, cnt * 2);
      list[cnt] := t;
      Inc(cnt);
      if (s[i] = #13) and (i < n) and (s[i + 1] = #10) then Inc(i);
      st := i + 1;
    end;
    Inc(i);
  end;
  if st <= n then
  begin
    if cnt >= Length(list) then SetLength(list, cnt * 2);
    list[cnt] := CleanLine(Copy(s, st, MaxInt));
    Inc(cnt);
  end;
  if cnt = 0 then
  begin
    list[0] := '';
    cnt := 1;
  end;
  SetLength(FLines, cnt + 16);
  for i := 0 to cnt - 1 do FLines[i] := list[i];
  FCount := cnt;
  Touch;
end;

function TDoc.LoadFromFile(const fn: string): string;
var
  fs: TFileStream;
  raw: RawByteString;
  txt: UnicodeString;
begin
  Result := '';
  try
    fs := TFileStream.Create(fn, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(raw, fs.Size);
      if fs.Size > 0 then fs.ReadBuffer(raw[1], fs.Size);
    finally
      fs.Free;
    end;
  except
    on e: Exception do Exit(e.Message);
  end;
  txt := DecodeText(raw);
  Clear;
  SetText(txt);
  if (FCount > 0) and (Length(FLines[0]) > 0) and (FLines[0][1] = CH_META) then
  begin
    ApplyMeta(FLines[0]);
    DelParas(0, 1);
  end;
  FileName := fn;
  Modified := False;
  CurP := 0;
  CurC := 0;
  ClearMarks;
  ForgetUndo;
  Touch;
end;

function TDoc.PlainText: UnicodeString;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to FCount - 1 do Result := Result + FLines[i] + #10;
end;

function TDoc.SaveToFile(const fn: string; withMeta: Boolean): string;
var
  tmp, bak: string;
  fs: TFileStream;
  i: Integer;
  u: RawByteString;

  procedure W(const s: UnicodeString);
  begin
    u := UTF8Encode(s);
    if Length(u) > 0 then fs.WriteBuffer(u[1], Length(u));
  end;

begin
  Result := '';
  tmp := fn + '.tmp~';
  try
    fs := TFileStream.Create(tmp, fmCreate);
    try
      if withMeta then W(MetaLine + #10);
      for i := 0 to FCount - 1 do W(FLines[i] + #10);
    finally
      fs.Free;
    end;
    if FileExists(fn) then
    begin
      bak := fn + '.bak';
      if FileExists(bak) then DeleteFile(bak);
      if not RenameFile(fn, bak) then
      begin
        DeleteFile(tmp);
        Exit('Cannot make a backup of ' + fn);
      end;
    end;
    if not RenameFile(tmp, fn) then
    begin
      Result := 'Cannot write ' + fn;
      Exit;
    end;
  except
    on e: Exception do Result := e.Message;
  end;
end;

function TDoc.NextTab(col: Integer; numericOnly: Boolean): Integer;
var
  i, mask: Integer;
begin
  if numericOnly then mask := TAB_NUM else mask := TAB_REG or TAB_NUM;
  for i := col + 1 to MAXWIDTH do
    if (Tabs[i] and mask) <> 0 then Exit(i);
  Result := -1;
end;

function TDoc.TabCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to MAXWIDTH do
    if Tabs[i] <> 0 then Inc(Result);
end;

end.
