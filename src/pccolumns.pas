{ pccolumns - the column functions: move, shift, repeat, insert, delete, erase,
  fill, addition (down a column or across rows) and sorting.

  A column is a rectangle: paragraphs ColP1..ColP2 and character columns
  ColC1..ColC2-1.  Every row of the rectangle is one whole paragraph (the editor
  refuses to set a column over a line that wraps), so columns are plain character
  offsets inside a paragraph. }
unit pccolumns;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, pcdoc;

type
  TDec = record
    Neg: Boolean;
    Digits: string;      { all digits, no separator }
    Scale: Integer;      { digits to the right of the decimal point }
  end;

  TColStyle = record
    Commas, Dollar, Parens, Close: Boolean;
  end;

function ColMove(d: TDoc; destP, destC: Integer): string;
function ColShift(d: TDoc; destP, destC: Integer): string;
function ColRepeat(d: TDoc; destP, destC: Integer): string;
function ColInsertSpaces(d: TDoc; n, maxLen: Integer): string;
function ColDelete(d: TDoc): string;
function ColErase(d: TDoc): string;
function ColFill(d: TDoc; ch: WideChar): string;

{ arithmetic; decimals = 255 means "as many as the numbers have" }
function ColSumDown(d: TDoc; decimals: Integer; out res: UnicodeString): string;
function ColSumRows(d: TDoc; const seps: UnicodeString; decimals: Integer;
  out res: TStrArray): string;
procedure PlaceResult(d: TDoc; p, decCol: Integer; const res: UnicodeString);

function ColSort(d: TDoc; const fields: array of Integer; ascending, ignoreLead: Boolean;
  const seps: UnicodeString): string;

function ParseDec(const s: UnicodeString; out v: TDec; var style: TColStyle): Boolean;
function DecAdd(const a, b: TDec; var r: TDec): Boolean;
function DecToStr(const v: TDec; decimals: Integer; const style: TColStyle): UnicodeString;

implementation

const
  MAXDIGITS = 38;

function PadTo(const s: UnicodeString; n: Integer): UnicodeString;
begin
  Result := s;
  while Length(Result) < n do Result := Result + ' ';
end;

function CheckCol(d: TDoc): string;
begin
  if not d.ColSet then Exit('Column not set');
  if (d.ColP1 < 0) or (d.ColP2 >= d.Count) or (d.ColC2 <= d.ColC1) then Exit('Column not set');
  Result := '';
end;

function Seg(d: TDoc; p: Integer): UnicodeString;
begin
  Result := Copy(PadTo(d[p], d.ColC2), d.ColC1 + 1, d.ColC2 - d.ColC1);
end;

function ColMove(d: TDoc; destP, destC: Integer): string;
var
  i, n, src, dst, w: Integer;
  seg_, s: UnicodeString;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  n := d.ColP2 - d.ColP1 + 1;
  w := d.ColC2 - d.ColC1;
  if destP + n > d.Count then Exit('Not enough lines below the cursor');
  if (destP = d.ColP1) and (destC > d.ColC1) and (destC < d.ColC2) then
    Exit('Cannot move a column into itself');
  for i := 0 to n - 1 do
  begin
    src := d.ColP1 + i;
    dst := destP + i;
    seg_ := Seg(d, src);
    { insert at the destination, then delete the original, one line at a time }
    s := PadTo(d[dst], destC);
    Insert(seg_, s, destC + 1);
    d[dst] := s;
    s := d[src];
    if dst = src then
    begin
      if destC <= d.ColC1 then s := PadTo(s, d.ColC1 + w + w);
      if destC <= d.ColC1 then Delete(s, d.ColC1 + w + 1, w) else Delete(s, d.ColC1 + 1, w);
    end
    else
      Delete(s, d.ColC1 + 1, w);
    d[src] := s;
  end;
  d.ColSet := False;
end;

type
  TBlock = array of UnicodeString;

function Extract(d: TDoc): TBlock;
var
  i: Integer;
begin
  SetLength(Result, d.ColP2 - d.ColP1 + 1);
  for i := 0 to High(Result) do Result[i] := Seg(d, d.ColP1 + i);
end;

procedure Paste(d: TDoc; const b: TBlock; destP, destC: Integer);
var
  i: Integer;
  s: UnicodeString;
  w: Integer;
begin
  w := d.ColC2 - d.ColC1;
  for i := 0 to High(b) do
  begin
    s := PadTo(d[destP + i], destC + w);
    Delete(s, destC + 1, w);
    Insert(b[i], s, destC + 1);
    d[destP + i] := s;
  end;
end;

procedure Blank(d: TDoc);
var
  i, w: Integer;
  s: UnicodeString;
begin
  w := d.ColC2 - d.ColC1;
  for i := d.ColP1 to d.ColP2 do
  begin
    s := PadTo(d[i], d.ColC2);
    Delete(s, d.ColC1 + 1, w);
    Insert(UnicodeString(StringOfChar(' ', w)), s, d.ColC1 + 1);
    d[i] := s;
  end;
end;

function ColShift(d: TDoc; destP, destC: Integer): string;
var
  b: TBlock;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  if destP + (d.ColP2 - d.ColP1) >= d.Count then Exit('Not enough lines below the cursor');
  b := Extract(d);
  Blank(d);
  Paste(d, b, destP, destC);
  d.ColSet := False;
end;

function ColRepeat(d: TDoc; destP, destC: Integer): string;
var
  b: TBlock;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  if destP + (d.ColP2 - d.ColP1) >= d.Count then Exit('Not enough lines below the cursor');
  b := Extract(d);
  Paste(d, b, destP, destC);
end;

function ColInsertSpaces(d: TDoc; n, maxLen: Integer): string;
var
  i, room: Integer;
  s: UnicodeString;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  for i := d.ColP1 to d.ColP2 do
  begin
    s := d[i];
    if Length(s) <= d.ColC1 then Continue;
    room := maxLen - Length(s);
    if room < 0 then room := 0;
    if n < room then room := n;
    Insert(UnicodeString(StringOfChar(' ', room)), s, d.ColC1 + 1);
    d[i] := s;
  end;
end;

function ColDelete(d: TDoc): string;
var
  i: Integer;
  s: UnicodeString;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  for i := d.ColP1 to d.ColP2 do
  begin
    s := d[i];
    Delete(s, d.ColC1 + 1, d.ColC2 - d.ColC1);
    d[i] := s;
  end;
  d.ColSet := False;
end;

function ColErase(d: TDoc): string;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  Blank(d);
  d.ColSet := False;
end;

function ColFill(d: TDoc; ch: WideChar): string;
var
  i, w: Integer;
  s: UnicodeString;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  w := d.ColC2 - d.ColC1;
  for i := d.ColP1 to d.ColP2 do
  begin
    s := PadTo(d[i], d.ColC2);
    Delete(s, d.ColC1 + 1, w);
    Insert(UnicodeString(StringOfChar(ch, w)), s, d.ColC1 + 1);
    d[i] := s;
  end;
  d.ColSet := False;
end;

{ ---- decimal arithmetic: up to 38 digits, as in PaperClip ---- }

function ParseDec(const s: UnicodeString; out v: TDec; var style: TColStyle): Boolean;
var
  i: Integer;
  ch: WideChar;
  seenPoint: Boolean;
begin
  v.Neg := False;
  v.Digits := '';
  v.Scale := 0;
  seenPoint := False;
  Result := False;
  for i := 1 to Length(s) do
  begin
    ch := s[i];
    case ch of
      '0'..'9':
        begin
          v.Digits := v.Digits + AnsiChar(Ord(ch));
          if seenPoint then Inc(v.Scale);
          Result := True;
        end;
      '.': seenPoint := True;
      '-': v.Neg := True;
      '(': begin v.Neg := True; style.Parens := True; end;
      ')': style.Close := True;
      ',': style.Commas := True;
      '$': style.Dollar := True;
    end;
  end;
  if not Result then v.Neg := False;
end;

procedure Align(var a, b: TDec);
begin
  while a.Scale < b.Scale do begin a.Digits := a.Digits + '0'; Inc(a.Scale); end;
  while b.Scale < a.Scale do begin b.Digits := b.Digits + '0'; Inc(b.Scale); end;
end;

function CmpMag(const a, b: string): Integer;
var
  x, y: string;
begin
  x := a; y := b;
  while (Length(x) > 1) and (x[1] = '0') do Delete(x, 1, 1);
  while (Length(y) > 1) and (y[1] = '0') do Delete(y, 1, 1);
  if Length(x) <> Length(y) then Exit(Length(x) - Length(y));
  if x < y then Result := -1 else if x > y then Result := 1 else Result := 0;
end;

function AddMag(const a, b: string): string;
var
  i, carry, da, db, s: Integer;
  x, y: string;
begin
  x := a; y := b;
  while Length(x) < Length(y) do x := '0' + x;
  while Length(y) < Length(x) do y := '0' + y;
  Result := '';
  carry := 0;
  for i := Length(x) downto 1 do
  begin
    da := Ord(x[i]) - 48; db := Ord(y[i]) - 48;
    s := da + db + carry;
    carry := s div 10;
    Result := AnsiChar(48 + s mod 10) + Result;
  end;
  if carry > 0 then Result := '1' + Result;
end;

function SubMag(const a, b: string): string;     { a >= b }
var
  i, borrow, da, db, s: Integer;
  x, y: string;
begin
  x := a; y := b;
  while Length(y) < Length(x) do y := '0' + y;
  Result := '';
  borrow := 0;
  for i := Length(x) downto 1 do
  begin
    da := Ord(x[i]) - 48; db := Ord(y[i]) - 48;
    s := da - db - borrow;
    if s < 0 then begin s := s + 10; borrow := 1; end else borrow := 0;
    Result := AnsiChar(48 + s) + Result;
  end;
end;

function DecAdd(const a, b: TDec; var r: TDec): Boolean;
var
  x, y: TDec;
  c: Integer;
  t: string;
begin
  x := a; y := b;
  Align(x, y);
  r.Scale := x.Scale;
  if x.Neg = y.Neg then
  begin
    r.Digits := AddMag(x.Digits, y.Digits);
    r.Neg := x.Neg;
  end
  else
  begin
    c := CmpMag(x.Digits, y.Digits);
    if c = 0 then begin r.Digits := '0'; r.Neg := False; end
    else if c > 0 then begin r.Digits := SubMag(x.Digits, y.Digits); r.Neg := x.Neg; end
    else begin r.Digits := SubMag(y.Digits, x.Digits); r.Neg := y.Neg; end;
  end;
  t := r.Digits;
  while (Length(t) > 1) and (t[1] = '0') and (Length(t) > r.Scale + 1) do Delete(t, 1, 1);
  r.Digits := t;
  Result := Length(r.Digits) <= MAXDIGITS;
end;

function DecToStr(const v: TDec; decimals: Integer; const style: TColStyle): UnicodeString;
var
  digs: string;
  scale, intLen, i, g: Integer;
  ip, fp: string;
  isZero: Boolean;
  carry: Integer;
begin
  digs := v.Digits;
  scale := v.Scale;
  if decimals <> 255 then
  begin
    if decimals > scale then
    begin
      while scale < decimals do begin digs := digs + '0'; Inc(scale); end;
    end
    else if decimals < scale then
    begin
      { round half away from zero }
      carry := 0;
      if Ord(digs[Length(digs) - (scale - decimals) + 1]) >= 53 then carry := 1;
      digs := Copy(digs, 1, Length(digs) - (scale - decimals));
      if digs = '' then digs := '0';
      if carry = 1 then digs := AddMag(digs, '1');
      scale := decimals;
    end;
  end;
  while Length(digs) <= scale do digs := '0' + digs;
  intLen := Length(digs) - scale;
  ip := Copy(digs, 1, intLen);
  fp := Copy(digs, intLen + 1, scale);
  while (Length(ip) > 1) and (ip[1] = '0') do Delete(ip, 1, 1);
  isZero := True;
  for i := 1 to Length(digs) do if digs[i] <> '0' then isZero := False;
  if style.Commas then
  begin
    g := 0;
    digs := '';
    for i := Length(ip) downto 1 do
    begin
      if (g > 0) and (g mod 3 = 0) then digs := ',' + digs;
      digs := ip[i] + digs;
      Inc(g);
    end;
    ip := digs;
  end;
  if style.Dollar then ip := '$' + ip;
  Result := UnicodeString(ip);
  if scale > 0 then Result := Result + '.' + UnicodeString(fp);
  if v.Neg and (not isZero) then
  begin
    if style.Parens then
    begin
      Result := '(' + Result;
      if style.Close then Result := Result + ')';
    end
    else Result := '-' + Result;
  end;
end;

function SumRowsInto(d: TDoc; const seps: UnicodeString; out res: TStrArray; decimals: Integer;
  var outStyle: TColStyle): string;
var
  i, f, k: Integer;
  seg_: UnicodeString;
  tot: TDec;
  v: TDec;
  st: TColStyle;
  fieldStart, nfields: Integer;
  fieldTxt: UnicodeString;
  totals: array of TDec;
  ok: Boolean;
  any: Boolean;
begin
  SetLength(res, 0);
  SetLength(totals, d.ColP2 - d.ColP1 + 1);
  FillChar(st, SizeOf(st), 0);
  for i := d.ColP1 to d.ColP2 do
  begin
    seg_ := Seg(d, i);
    tot.Neg := False; tot.Digits := '0'; tot.Scale := 0;
    f := 0;
    fieldStart := 1;
    nfields := 0;
    k := 1;
    while k <= Length(seg_) + 1 do
    begin
      if (k > Length(seg_)) or ((f < Length(seps)) and (seg_[k] = seps[f + 1])) then
      begin
        fieldTxt := Copy(seg_, fieldStart, k - fieldStart);
        if ParseDec(fieldTxt, v, st) then
        begin
          ok := DecAdd(tot, v, tot);
          if not ok then Exit('Overflow error');
        end;
        Inc(nfields);
        if (f < Length(seps)) and (k <= Length(seg_)) and (seps[f + 1] = ' ') then
          while (k < Length(seg_)) and (seg_[k + 1] = ' ') do Inc(k);   { runs of spaces count as one }
        Inc(f);
        fieldStart := k + 1;
      end;
      Inc(k);
    end;
    totals[i - d.ColP1] := tot;
  end;
  any := False;
  SetLength(res, Length(totals));
  for i := 0 to High(totals) do
  begin
    res[i] := DecToStr(totals[i], decimals, st);
    any := True;
  end;
  outStyle := st;
  if not any then Result := 'Column not set' else Result := '';
end;

function ColSumRows(d: TDoc; const seps: UnicodeString; decimals: Integer;
  out res: TStrArray): string;
var
  st: TColStyle;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  Result := SumRowsInto(d, seps, res, decimals, st);
end;

function ColSumDown(d: TDoc; decimals: Integer; out res: UnicodeString): string;
var
  i: Integer;
  tot, v: TDec;
  st: TColStyle;
begin
  res := '';
  Result := CheckCol(d);
  if Result <> '' then Exit;
  FillChar(st, SizeOf(st), 0);
  tot.Neg := False; tot.Digits := '0'; tot.Scale := 0;
  for i := d.ColP1 to d.ColP2 do
    if ParseDec(Seg(d, i), v, st) then
      if not DecAdd(tot, v, tot) then Exit('Overflow error');
  res := DecToStr(tot, decimals, st);
end;

procedure PlaceResult(d: TDoc; p, decCol: Integer; const res: UnicodeString);
var
  dp, start, i: Integer;
  s: UnicodeString;
begin
  if (p < 0) or (p >= d.Count) then Exit;
  dp := Pos('.', UTF8Encode(res));
  if dp = 0 then dp := Length(res) + 1;
  start := decCol - (dp - 1);
  if start < 0 then start := 0;
  s := PadTo(d[p], start + Length(res));
  for i := 1 to Length(res) do s[start + i] := res[i];
  d[p] := s;
end;

{ ---- sorting ---- }

type
  TSortRow = record
    Text: UnicodeString;
    Keys: array of UnicodeString;
    Idx: Integer;
  end;

procedure SplitFields(const s, seps: UnicodeString; ignoreLead: Boolean; var f: TStrArray);
var
  k, idx, st: Integer;
begin
  SetLength(f, 17);
  for k := 0 to 16 do f[k] := '';
  idx := 0;
  st := 1;
  k := 1;
  while k <= Length(s) do
  begin
    if (idx < Length(seps)) and (idx < 16) and (s[k] = seps[idx + 1]) then
    begin
      f[idx] := Copy(s, st, k - st);
      Inc(idx);
      if ignoreLead then
        while (k < Length(s)) and (s[k + 1] = ' ') do Inc(k);
      st := k + 1;
    end;
    Inc(k);
  end;
  if idx <= 16 then f[idx] := Copy(s, st, MaxInt);
end;

function IsNumField(const s: UnicodeString; out v: Double): Boolean;
var
  t: string;
  i: Integer;
  ch: Char;
  clean: string;
  digits: Integer;
  dummy: TColStyle;
begin
  t := Trim(UTF8Encode(s));
  Result := False;
  if t = '' then Exit;
  clean := '';
  digits := 0;
  for i := 1 to Length(t) do
  begin
    ch := t[i];
    case ch of
      '0'..'9': begin clean := clean + ch; Inc(digits); end;
      '.', '-', '+': clean := clean + ch;
      ',', '$', '(', ')', ' ': ;
    else
      Exit(False);
    end;
  end;
  if digits = 0 then Exit;
  FillChar(dummy, SizeOf(dummy), 0);
  if Pos('(', t) > 0 then clean := '-' + clean;
  v := StrToFloatDef(clean, 0);
  Result := True;
end;

function CompareField(const a, b: UnicodeString): Integer;
var
  x, y: Double;
  na, nb: Boolean;
  sa, sb: UnicodeString;
begin
  na := IsNumField(a, x);
  nb := IsNumField(b, y);
  if na and nb then
  begin
    if x < y then Exit(-1);
    if x > y then Exit(1);
    Exit(0);
  end;
  if na then Exit(-1);
  if nb then Exit(1);
  sa := LowerCase(Trim(a));
  sb := LowerCase(Trim(b));
  if sa < sb then Result := -1 else if sa > sb then Result := 1 else Result := 0;
end;

function ColSort(d: TDoc; const fields: array of Integer; ascending, ignoreLead: Boolean;
  const seps: UnicodeString): string;
var
  n, i, j, k, cmp: Integer;
  rows: array of TSortRow;
  f: TStrArray;
  tmp: TSortRow;
  w: Integer;
  s: UnicodeString;
begin
  Result := CheckCol(d);
  if Result <> '' then Exit;
  if Length(fields) = 0 then Exit('No sort field');
  n := d.ColP2 - d.ColP1 + 1;
  SetLength(rows, n);
  for i := 0 to n - 1 do
  begin
    rows[i].Text := Seg(d, d.ColP1 + i);
    rows[i].Idx := i;
    SplitFields(rows[i].Text, seps, ignoreLead, f);
    SetLength(rows[i].Keys, Length(fields));
    for k := 0 to High(fields) do
      if (fields[k] >= 1) and (fields[k] <= 17) then rows[i].Keys[k] := f[fields[k] - 1];
  end;
  { stable insertion sort; sorts here are short lists }
  for i := 1 to n - 1 do
  begin
    tmp := rows[i];
    j := i - 1;
    while j >= 0 do
    begin
      cmp := 0;
      for k := 0 to High(fields) do
      begin
        cmp := CompareField(rows[j].Keys[k], tmp.Keys[k]);
        if cmp <> 0 then Break;
      end;
      if not ascending then cmp := -cmp;
      if cmp <= 0 then Break;
      rows[j + 1] := rows[j];
      Dec(j);
    end;
    rows[j + 1] := tmp;
  end;
  w := d.ColC2 - d.ColC1;
  for i := 0 to n - 1 do
  begin
    s := PadTo(d[d.ColP1 + i], d.ColC2);
    Delete(s, d.ColC1 + 1, w);
    Insert(rows[i].Text, s, d.ColC1 + 1);
    d[d.ColP1 + i] := s;
  end;
  d.ColSet := False;
end;

end.
