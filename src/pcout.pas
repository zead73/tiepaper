{ pcout - output files: PDF (for printing and sharing) and plain text.

  The PDF writer uses the standard Courier fonts, which every PDF viewer and
  printer driver has, so nothing is embedded.  Text is limited to what Windows
  Latin-1 (cp1252) can show; anything else prints as a question mark. }
unit pcout;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, pcfmt;

type
  TPaperSize = (psLetter, psA4);

function WritePDF(fmt: TFormatter; const fn: string; paper: TPaperSize;
  firstPage, lastPage: Integer): string;
function WritePlainText(fmt: TFormatter; const fn: string; firstPage, lastPage: Integer): string;
function PaperLinesFor(paper: TPaperSize): Integer;

implementation

function PaperLinesFor(paper: TPaperSize): Integer;
begin
  if paper = psA4 then Result := 70 else Result := 66;
end;

function ToWinAnsi(ch: WideChar): Byte;
begin
  case Ord(ch) of
    $20..$7E, $A0..$FF: Result := Ord(ch);
    $20AC: Result := $80;
    $201A: Result := $82;
    $0192: Result := $83;
    $201E: Result := $84;
    $2026: Result := $85;
    $2020: Result := $86;
    $2021: Result := $87;
    $02C6: Result := $88;
    $2030: Result := $89;
    $0160: Result := $8A;
    $2039: Result := $8B;
    $0152: Result := $8C;
    $017D: Result := $8E;
    $2018: Result := $91;
    $2019: Result := $92;
    $201C: Result := $93;
    $201D: Result := $94;
    $2022: Result := $95;
    $2013: Result := $96;
    $2014: Result := $97;
    $02DC: Result := $98;
    $2122: Result := $99;
    $0161: Result := $9A;
    $203A: Result := $9B;
    $0153: Result := $9C;
    $017E: Result := $9E;
    $0178: Result := $9F;
  else
    Result := Ord('?');
  end;
end;

function PdfEscape(b: Byte): string;
begin
  case b of
    Ord('('): Result := '\(';
    Ord(')'): Result := '\)';
    Ord('\'): Result := '\\';
    32..39, 42..91, 93..126: Result := Chr(b);
  else
    Result := '\' + OctStr(b, 3);
  end;
end;

function Fmt2(x: Double): string;
begin
  Result := FormatFloat('0.##', x);
  Result := StringReplace(Result, ',', '.', [rfReplaceAll]);
end;

function PageContent(pg: TPage; pageH: Double; leftEdge: Double): string;
var
  li, ci, runStart, k: Integer;
  ln: TOutLine;
  cw, fs, lh, y, x, rise, size: Double;
  attr: Byte;
  sb: string;
  segs: string;
  txt: string;
  ulStart: Integer;

  function FontOf(a: Byte): string;
  begin
    if (a and A_BOLD <> 0) and (a and A_ITAL <> 0) then Result := '/F4'
    else if a and A_BOLD <> 0 then Result := '/F2'
    else if a and A_ITAL <> 0 then Result := '/F3'
    else Result := '/F1';
  end;

begin
  segs := '';
  lh := 72.0 / pg.LPI;
  for li := 0 to High(pg.Lines) do
  begin
    ln := pg.Lines[li];
    if Length(ln.Cells) = 0 then Continue;
    cw := 72.0 / PitchOf(ln);
    fs := cw / 0.6;
    y := pageH - (li + 1) * lh + (lh - fs) * 0.0 + lh * 0.22;
    ci := 0;
    while ci <= High(ln.Cells) do
    begin
      if ln.Cells[ci].Ch = ' ' then
      begin
        { spaces need no ink unless they are underlined }
        if ln.Cells[ci].Attr and A_UL <> 0 then
        begin
          ulStart := ci;
          while (ci <= High(ln.Cells)) and (ln.Cells[ci].Ch = ' ') and (ln.Cells[ci].Attr and A_UL <> 0) do Inc(ci);
          x := leftEdge + ulStart * cw;
          segs := segs + Format('0.5 w %s %s m %s %s l S'#10,
            [Fmt2(x), Fmt2(y - fs * 0.12), Fmt2(x + (ci - ulStart) * cw), Fmt2(y - fs * 0.12)]);
        end
        else
          Inc(ci);
        Continue;
      end;
      { a run of cells with the same attributes }
      attr := ln.Cells[ci].Attr;
      runStart := ci;
      k := ci;
      while (k <= High(ln.Cells)) and (ln.Cells[k].Attr = attr) do Inc(k);
      txt := '';
      for ci := runStart to k - 1 do txt := txt + PdfEscape(ToWinAnsi(ln.Cells[ci].Ch));
      ci := k;
      size := fs;
      rise := 0;
      if attr and A_SUP <> 0 then begin size := fs * 0.7; rise := fs * 0.35; end
      else if attr and A_SUB <> 0 then begin size := fs * 0.7; rise := -fs * 0.18; end;
      x := leftEdge + runStart * cw;
      { place each character on its own cell so proportional differences never shift columns }
      sb := Format('BT %s %s Tf %s Tc 1 0 0 1 %s %s Tm (%s) Tj ET'#10,
        [FontOf(attr), Fmt2(size), Fmt2(cw - size * 0.6), Fmt2(x), Fmt2(y + rise), txt]);
      segs := segs + sb;
      if attr and A_UL <> 0 then
        segs := segs + Format('0.5 w %s %s m %s %s l S'#10,
          [Fmt2(x), Fmt2(y - fs * 0.12), Fmt2(x + (k - runStart) * cw), Fmt2(y - fs * 0.12)]);
    end;
  end;
  Result := segs;
end;

function WritePDF(fmt: TFormatter; const fn: string; paper: TPaperSize;
  firstPage, lastPage: Integer): string;
var
  fs: TFileStream;
  offs: array of Int64;
  nobj, i, np, pageObjBase, contentBase: Integer;
  xrefPos: Int64;
  pw, ph, leftEdge: Double;
  kids: string;
  content: string;
  pg: TPage;

  procedure W(const s: string);
  begin
    if s <> '' then fs.WriteBuffer(s[1], Length(s));
  end;

  procedure BeginObj(n: Integer);
  begin
    if n >= Length(offs) then SetLength(offs, n + 16);
    offs[n] := fs.Position;
    W(IntToStr(n) + ' 0 obj'#10);
  end;

begin
  Result := '';
  if fmt.PageCount = 0 then Exit('Nothing to output');
  if firstPage < 1 then firstPage := 1;
  if (lastPage < 1) or (lastPage > fmt.PageCount) then lastPage := fmt.PageCount;
  if firstPage > lastPage then Exit('No such page');
  if paper = psA4 then begin pw := 595.28; ph := 841.89; end
  else begin pw := 612; ph := 792; end;
  np := lastPage - firstPage + 1;
  { objects: 1 catalog, 2 pages, 3..6 fonts, then a (page, content) pair per page }
  pageObjBase := 7;
  contentBase := 8;
  SetLength(offs, 8 + np * 2);
  try
    fs := TFileStream.Create(fn, fmCreate);
  except
    on e: Exception do Exit(e.Message);
  end;
  try
    W('%PDF-1.4'#10'%'#$E2#$E3#$CF#$D3#10);
    BeginObj(1);
    W('<< /Type /Catalog /Pages 2 0 R >>'#10'endobj'#10);
    kids := '';
    for i := 0 to np - 1 do kids := kids + IntToStr(pageObjBase + i * 2) + ' 0 R ';
    BeginObj(2);
    W('<< /Type /Pages /Kids [' + kids + '] /Count ' + IntToStr(np) + ' >>'#10'endobj'#10);
    BeginObj(3);
    W('<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>'#10'endobj'#10);
    BeginObj(4);
    W('<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Bold /Encoding /WinAnsiEncoding >>'#10'endobj'#10);
    BeginObj(5);
    W('<< /Type /Font /Subtype /Type1 /BaseFont /Courier-Oblique /Encoding /WinAnsiEncoding >>'#10'endobj'#10);
    BeginObj(6);
    W('<< /Type /Font /Subtype /Type1 /BaseFont /Courier-BoldOblique /Encoding /WinAnsiEncoding >>'#10'endobj'#10);
    for i := 0 to np - 1 do
    begin
      pg := fmt.GetPage(firstPage - 1 + i);
      leftEdge := 0;
      content := PageContent(pg, ph, leftEdge);
      BeginObj(pageObjBase + i * 2);
      W('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ' + Fmt2(pw) + ' ' + Fmt2(ph) + '] ' +
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R /F3 5 0 R /F4 6 0 R >> >> /Contents ' +
        IntToStr(contentBase + i * 2) + ' 0 R >>'#10'endobj'#10);
      BeginObj(contentBase + i * 2);
      W('<< /Length ' + IntToStr(Length(content)) + ' >>'#10'stream'#10);
      W(content);
      W('endstream'#10'endobj'#10);
    end;
    nobj := contentBase + (np - 1) * 2 + 1;
    xrefPos := fs.Position;
    W('xref'#10'0 ' + IntToStr(nobj) + #10);
    W('0000000000 65535 f '#10);
    for i := 1 to nobj - 1 do W(Format('%.10d 00000 n '#10, [offs[i]]));
    W('trailer'#10'<< /Size ' + IntToStr(nobj) + ' /Root 1 0 R >>'#10'startxref'#10 +
      IntToStr(xrefPos) + #10'%%EOF'#10);
  finally
    fs.Free;
  end;
end;

function WritePlainText(fmt: TFormatter; const fn: string; firstPage, lastPage: Integer): string;
var
  fs: TFileStream;
  i, j, last: Integer;
  pg: TPage;
  line: string;
begin
  Result := '';
  if fmt.PageCount = 0 then Exit('Nothing to output');
  if firstPage < 1 then firstPage := 1;
  if (lastPage < 1) or (lastPage > fmt.PageCount) then lastPage := fmt.PageCount;
  try
    fs := TFileStream.Create(fn, fmCreate);
  except
    on e: Exception do Exit(e.Message);
  end;
  try
    for i := firstPage to lastPage do
    begin
      pg := fmt.GetPage(i - 1);
      last := pg.LastUsed;
      for j := 0 to last - 1 do
      begin
        line := UTF8Encode(LineText(pg.Lines[j]));
        { trailing spaces are noise in a text file }
        while (line <> '') and (line[Length(line)] = ' ') do Delete(line, Length(line), 1);
        line := line + #10;
        fs.WriteBuffer(line[1], Length(line));
      end;
      if i < lastPage then
      begin
        line := #12;
        fs.WriteBuffer(line[1], 1);
      end;
    end;
  finally
    fs.Free;
  end;
end;

end.
