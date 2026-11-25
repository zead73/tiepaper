{ Headless tests for the document model, formatter, search, columns and output.
  Run with tests/run-tests.sh.  Expected values come from the PaperClip II manual. }
program test_core;

{$mode objfpc}{$H+}
{$IFDEF UNIX}{$DEFINE USECW}{$ENDIF}

uses
  {$IFDEF USECW}cwstring,{$ENDIF}
  SysUtils, Classes, {$IFDEF UNIX}BaseUnix,{$ENDIF} pcdoc, pcsearch, pccolumns, pcfmt, pcout, pcspell, pcdirs, pcsyntax;

var
  Fails, Passes: Integer;

procedure Check(ok: Boolean; const msg: string);
begin
  if ok then Inc(Passes)
  else begin Inc(Fails); WriteLn('FAIL: ', msg); end;
end;

procedure CheckEq(const got, want: string; const msg: string);
begin
  if got = want then Inc(Passes)
  else begin Inc(Fails); WriteLn('FAIL: ', msg, #10'   got : [', got, ']'#10'   want: [', want, ']'); end;
end;

procedure CheckInt(got, want: Integer; const msg: string);
begin
  if got = want then Inc(Passes)
  else begin Inc(Fails); WriteLn('FAIL: ', msg, ' got ', got, ' want ', want); end;
end;

function U(const s: string): UnicodeString;
begin
  Result := UTF8Decode(s);
end;

function S8(const s: UnicodeString): string;
begin
  Result := UTF8Encode(s);
end;

function Fmt(const paras: array of string; paper: Integer = 66): TFormatter;
var
  a: TStrArray;
  i: Integer;
begin
  SetLength(a, Length(paras));
  for i := 0 to High(paras) do a[i] := U(paras[i]);
  Result := TFormatter.Create;
  Result.DefaultPaperLines := paper;
  Result.Run(a);
end;

function PageLine(f: TFormatter; pg, ln: Integer): string;
begin
  Result := S8(LineText(f.GetPage(pg - 1).Lines[ln - 1]));
end;

function Trimmed(const s: string): string;
begin
  Result := TrimRight(s);
end;

const
  CK = #$E2#$9C#$93;          { the checkmark in UTF-8 }

procedure TestWrap;
var
  starts: TIntArray;
  n: Integer;
begin
  SetLength(starts, 4);
  WrapPara('hello world foo bar', 11, starts, n);
  CheckInt(n, 2, 'wrap rows');
  CheckInt(starts[1], 12, 'wrap second row starts at "foo"');
  WrapPara('abcdefghij', 4, starts, n);
  CheckInt(n, 3, 'long word hard-splits');
  WrapPara('', 10, starts, n);
  CheckInt(n, 1, 'empty paragraph is one row');
  WrapPara('aaaa bbbb', 4, starts, n);
  CheckInt(n, 2, 'space right at the window edge hangs');
  CheckInt(starts[1], 5, 'second word starts after hanging space');
end;

procedure TestTabCol;
var
  s: UnicodeString;
begin
  { "a\tbb\tc": a=col0, tab->col4, bb=col4-5, tab->col8, c=col8 (tab width 4) }
  s := U('a' + #9 + 'bb' + #9 + 'c');
  CheckInt(CharColToScreenCol(s, 0, 0, 4), 0, 'tab: screen col of first char');
  CheckInt(CharColToScreenCol(s, 0, 1, 4), 1, 'tab: screen col right after "a"');
  CheckInt(CharColToScreenCol(s, 0, 2, 4), 4, 'tab: screen col after first tab stop');
  CheckInt(CharColToScreenCol(s, 0, 4, 4), 6, 'tab: screen col after "bb"');
  CheckInt(CharColToScreenCol(s, 0, 5, 4), 8, 'tab: screen col after second tab stop');
  CheckInt(CharColToScreenCol(s, 0, 6, 4), 9, 'tab: screen col after "c"');
  { a tab that lands exactly on a stop still advances a full width }
  CheckInt(CharColToScreenCol(U(#9 + #9), 0, 2, 4), 8, 'tab: two tabs from column 0 reach column 8');
  { reverse mapping: char offset for a given screen column, with midpoint rounding inside a tab }
  CheckInt(ScreenColToCharCol(s, 0, 6, 0, 4), 0, 'tab: screen col 0 is "a"');
  CheckInt(ScreenColToCharCol(s, 0, 6, 1, 4), 1, 'tab: screen col 1 is the tab');
  CheckInt(ScreenColToCharCol(s, 0, 6, 2, 4), 1, 'tab: screen col 2 (left half of tab) rounds back to the tab');
  CheckInt(ScreenColToCharCol(s, 0, 6, 3, 4), 2, 'tab: screen col 3 (right half of tab) rounds to the next char');
  CheckInt(ScreenColToCharCol(s, 0, 6, 4, 4), 2, 'tab: screen col 4 is "b"');
  CheckInt(ScreenColToCharCol(s, 0, 6, 9, 4), 6, 'tab: screen col at end of row is end of row');
  CheckInt(ScreenColToCharCol(s, 0, 6, 20, 4), 17, 'tab: screen col past the row overshoots by the same amount');
  { round trip for every character offset in a tab-heavy line }
  CheckInt(ScreenColToCharCol(s, 0, 6, CharColToScreenCol(s, 0, 3, 4), 4), 3, 'tab: round trip mid-tab-run');
end;

procedure TestDoc;
var
  d: TDoc;
  row, col, p, c: Integer;
  err: string;
  fn: string;
begin
  d := TDoc.Create;
  d.SetText('one'#10'two'#10'three'#10);
  d.EnsureLayout(40);
  CheckInt(d.Count, 3, 'trailing newline does not add a paragraph piece at SetText level');
  d.InsText(1, 3, ' and a half');
  CheckEq(S8(d[1]), 'two and a half', 'InsText');
  d.SplitPara(1, 3);
  CheckEq(S8(d[1]), 'two', 'split head');
  CheckEq(S8(d[2]), ' and a half', 'split tail');
  d.JoinPara(1);
  CheckEq(S8(d[1]), 'two and a half', 'join');
  d.DelParas(0, 1);
  CheckEq(S8(d[0]), 'two and a half', 'DelParas');
  { marks follow edits }
  d.PhraseSet := True; d.PhP := 0; d.PhC1 := 4; d.PhC2 := 7;
  d.InsText(0, 0, 'XX');
  CheckInt(d.PhC1, 6, 'phrase tracks insertion before it');
  d.InsPara(0, 'new');
  CheckInt(d.PhP, 1, 'phrase tracks inserted paragraph');
  { layout lookup }
  d.Clear;
  d.SetText('aaa bbb ccc ddd');
  d.EnsureLayout(8);
  CheckInt(d.RowCount, 2, 'layout rows');
  d.PosToRowCol(0, 9, row, col);
  CheckInt(row, 1, 'cursor in second row');
  CheckInt(col, 1, 'cursor column in second row');
  d.RowColToPos(0, 100, p, c);
  CheckInt(c, 7, 'clamping on a non-final row keeps the cursor on that row');
  { save and load round trip with tabs and markers }
  d.Clear;
  d.SetText('line one'#10 + S8(CH_BOLD_ON) + 'bold' + S8(CH_BOLD_OFF) + ' text'#10);
  d.Tabs[4] := TAB_REG;
  d.Tabs[19] := TAB_NUM;
  d.LineLen := 100;
  fn := GetTempDir + 'pc_test_roundtrip.pcl';
  err := d.SaveToFile(fn, True);
  CheckEq(err, '', 'save');
  d.Clear;
  err := d.LoadFromFile(fn);
  CheckEq(err, '', 'load');
  CheckInt(d.Count, 2, 'paragraph count after reload');
  Check(d.Tabs[4] = TAB_REG, 'regular tab restored');
  Check(d.Tabs[19] = TAB_NUM, 'numeric tab restored');
  CheckInt(d.LineLen, 100, 'line length restored');
  Check(d[1][1] = CH_BOLD_ON, 'embedded marker survives');
  DeleteFile(fn);
  DeleteFile(fn + '.bak');
  { undo }
  d.Clear;
  d.SetText('abc');
  d.PushUndo(0);
  d.InsText(0, 3, 'def');
  Check(d.Undo, 'undo available');
  CheckEq(S8(d[0]), 'abc', 'undo restores text');
  Check(d.Redo, 'redo available');
  CheckEq(S8(d[0]), 'abcdef', 'redo');
  { colouring cache: DirtyFrom tracks the lowest paragraph an edit touched, not the whole file,
    so syntax colouring need not retokenize from the start after every keystroke }
  d.Clear;
  d.SetText('a'#10'b'#10'c'#10'd'#10'e');
  CheckInt(d.DirtyFrom, 0, 'DirtyFrom starts at 0 after a full load');
  d.DirtyFrom := MaxInt;
  d[2] := 'C';
  CheckInt(d.DirtyFrom, 2, 'SetLine marks only its own paragraph dirty');
  d.DirtyFrom := MaxInt;
  d.InsText(3, 0, 'X');
  CheckInt(d.DirtyFrom, 3, 'InsText marks only its own paragraph dirty');
  d.DirtyFrom := MaxInt;
  d.SplitPara(1, 1);
  CheckInt(d.DirtyFrom, 1, 'SplitPara marks from the split paragraph');
  d.DirtyFrom := MaxInt;
  d.JoinPara(0);
  CheckInt(d.DirtyFrom, 0, 'JoinPara marks from the joined paragraph');
  d.DirtyFrom := MaxInt;
  d.DelParas(4, 1);
  CheckInt(d.DirtyFrom, 4, 'DelParas marks from the deleted paragraph');
  d.DirtyFrom := MaxInt;
  d.ReplaceText(2, 'zzz');
  CheckInt(d.DirtyFrom, 2, 'ReplaceText marks only its own paragraph dirty');
  d.DirtyFrom := MaxInt;
  d.InsPara(1, 'new');
  CheckInt(d.DirtyFrom, 1, 'InsPara marks from the inserted paragraph');
  d.DirtyFrom := MaxInt;
  d[3] := 'x';
  d[1] := 'y';
  CheckInt(d.DirtyFrom, 1, 'DirtyFrom keeps the lowest paragraph touched across edits');
  d.Free;
end;

procedure TestSearch;
var
  pat: TPattern;
  pos_, len: Integer;
begin
  pat := CompilePattern('the');
  Check(FindIn(pat, 'In THE end', 0, pos_, len), 'case-insensitive find');
  CheckInt(pos_, 3, 'position of THE');
  pat := CompilePattern('t.e');
  Check(FindIn(pat, 'tbe', 0, pos_, len), '. matches any character');
  pat := CompilePattern('t?e');
  Check(FindIn(pat, 'tbe', 0, pos_, len), '? matches a letter');
  Check(not FindIn(pat, 't7e', 0, pos_, len), '? does not match a digit');
  pat := CompilePattern('[the');
  Check(FindIn(pat, 'then', 0, pos_, len), '[ matches at word start');
  Check(not FindIn(pat, 'clothe', 0, pos_, len), '[ does not match inside a word');
  pat := CompilePattern('the]');
  Check(FindIn(pat, 'clothe', 0, pos_, len), '] matches at word end');
  Check(not FindIn(pat, 'then', 0, pos_, len), '] does not match mid-word');
  pat := CompilePattern('[the]');
  Check(FindIn(pat, 'say the thing', 0, pos_, len), 'bracketed whole word');
  Check(not FindIn(pat, 'then clothe', 0, pos_, len), 'whole word refuses partial matches');
  pat := CompilePattern('''the');
  Check(FindIn(pat, 'the', 0, pos_, len), 'quote then lowercase matches');
  Check(not FindIn(pat, 'The', 0, pos_, len), 'quote makes the next character case-sensitive');
  pat := CompilePattern('ab''?');
  Check(FindIn(pat, 'x ab? y', 0, pos_, len), 'quote makes a special character literal');
  Check(not FindIn(pat, 'abc', 0, pos_, len), 'literal ? does not match a letter');
end;

procedure TestFormatterBasics;
var
  f: TFormatter;
  i: Integer;
  ln: string;
  long: string;
begin
  { defaults: left margin 10, right 70 -> 61 columns, text starts in column 10 }
  long := '';
  for i := 1 to 30 do long := long + 'word ';
  f := Fmt([long]);
  CheckInt(f.PageCount, 1, 'one page');
  ln := PageLine(f, 1, 1);
  Check(Copy(ln, 1, 9) = StringOfChar(' ', 9), 'text starts after 9 spaces');
  Check(Length(Trimmed(ln)) <= 70, 'line stays inside the right margin');
  Check(Trimmed(ln)[10] = 'w', 'first text character in column 10');
  f.Free;
  { justification: every line but the last is exactly 61 wide }
  f := Fmt([CK + 'ju1', long]);
  ln := PageLine(f, 1, 1);
  CheckInt(Length(Trimmed(ln)), 70, 'justified line reaches the right margin');
  CheckInt(Length(Trimmed(PageLine(f, 1, 2))), 70, 'second justified line');
  f.Free;
  { relative margins from the manual: 20, +10 -> 30, -3 -> 17, +5 -> 25 }
  f := Fmt([CK + 'lm20:rm70', 'a', CK + 'lm+10', 'b', CK + 'lm-3', 'c', CK + 'lm+5', 'd', CK + 'lm+0', 'e']);
  CheckInt(Pos('a', PageLine(f, 1, 1)), 20, 'base margin 20');
  CheckInt(Pos('b', PageLine(f, 1, 2)), 30, 'relative +10');
  CheckInt(Pos('c', PageLine(f, 1, 3)), 17, 'relative -3');
  CheckInt(Pos('d', PageLine(f, 1, 4)), 25, 'relative +5');
  CheckInt(Pos('e', PageLine(f, 1, 5)), 20, 'lm+0 returns to the base margin');
  f.Free;
  { alternative spellings of the same command }
  f := Fmt([CK + 'justification on', 'x ' + StringOfChar('y', 3), CK + 'ju off', 'z']);
  Check(f.Warnings.Count = 0, 'long command names are accepted: ' + f.Warnings.Text);
  f.Free;
  { centering and right alignment }
  f := Fmt([CK + 'ce1', 'Title', CK + 'ce0' + ':ra1', 'Right', CK + 'ra0', 'Left']);
  CheckInt(Pos('Title', PageLine(f, 1, 1)), 10 + (61 - 5) div 2, 'centred between margins');
  CheckInt(Pos('Right', PageLine(f, 1, 2)), 70 - 5 + 1, 'right aligned to the margin');
  CheckInt(Pos('Left', PageLine(f, 1, 3)), 10, 'ragged left restored');
  f.Free;
  { print spacing }
  f := Fmt([CK + 'sp2', 'one', 'two']);
  CheckInt(Pos('one', PageLine(f, 1, 1)), 10, 'double spacing first line');
  CheckEq(Trimmed(PageLine(f, 1, 2)), '', 'double spacing leaves a blank line');
  CheckInt(Pos('two', PageLine(f, 1, 3)), 10, 'double spacing second line');
  f.Free;
  { blank paragraphs print a blank line; automatic indent applies to paragraph first lines }
  f := Fmt([CK + 'ai5', 'first line of a paragraph that needs to wrap around the right margin of the page nicely']);
  CheckInt(Pos('first', PageLine(f, 1, 1)), 15, 'automatic indentation');
  Check(Pos('wrap', PageLine(f, 1, 1)) > 0, 'wrapped');
  f.Free;
  { margin adjust affects only the next paragraph's first line }
  f := Fmt([CK + 'ma+3', 'a', 'b']);
  CheckInt(Pos('a', PageLine(f, 1, 1)), 13, 'margin adjust applies once');
  CheckInt(Pos('b', PageLine(f, 1, 2)), 10, 'and is then forgotten');
  f.Free;
end;

procedure TestPages;
var
  f: TFormatter;
  paras: array of string;
  i: Integer;
begin
  SetLength(paras, 120);
  for i := 0 to 119 do paras[i] := 'line ' + IntToStr(i + 1);
  f := Fmt(paras);
  CheckInt(f.PageCount, 3, '120 single lines make three 56-line pages');
  CheckInt(f.GetPage(0).LastUsed, 56, 'page 1 has 56 lines');
  CheckInt(f.GetPage(2).LastUsed, 8, 'page 3 has the remaining 8');
  f.Free;

  { header and footer with page numbers; vp makes room for the header }
  SetLength(paras, 61);
  paras[0] := CK + 'vp4:pg20:hd2:Title,Centre,Right';
  paras[1] := CK + 'ft2!left!<>!end';
  for i := 2 to 60 do paras[i] := 'text ' + IntToStr(i);
  f := Fmt(paras);
  Check(f.Warnings.Count = 0, 'no warnings: ' + f.Warnings.Text);
  CheckInt(f.PageCount, 3, 'pg20 makes pages of 20 lines (59 lines of text)');
  CheckInt(Pos('Title', PageLine(f, 1, 3)), 10, 'header two lines above the text, left');
  CheckInt(Pos('Right', PageLine(f, 1, 3)), 70 - 5 + 1, 'header right part at the right margin');
  Check(Pos('Centre', PageLine(f, 1, 3)) > 0, 'header centre part');
  CheckInt(Pos('text 2', PageLine(f, 1, 5)), 10, 'text starts below the vertical position');
  Check(Pos('1', Copy(PageLine(f, 1, 65), 1, 100)) > 0, 'footer shows page number 1');
  Check(Pos('2', PageLine(f, 2, 65)) > 0, 'footer shows page number 2');
  Check(Pos('end', PageLine(f, 1, 65)) > 0, 'footer separator ! gives a right part');
  f.Free;

  { a header above the paper warns instead of vanishing silently }
  f := Fmt([CK + 'hd3:Header', 'text']);
  Check(f.Warnings.Count > 0, 'header with no room warns');
  f.Free;

  { forced paging }
  f := Fmt(['a', CK + 'fp', 'b', CK + 'fp5', 'c']);
  CheckInt(f.PageCount, 2, 'fp starts a new page; fp5 does not when there is room');
  f.Free;
  f := Fmt([CK + 'pg6', 'a', 'b', 'c', 'd', CK + 'fp3', 'e']);
  CheckInt(f.PageCount, 2, 'fp3 moves on when fewer than 3 lines remain');
  f.Free;
  { blank lines are ignored at the top of a page, applied elsewhere }
  f := Fmt(['a', CK + 'ln2', 'b']);
  CheckInt(Pos('b', PageLine(f, 1, 4)), 10, 'ln inserts blank lines');
  f.Free;
end;

procedure TestEnhancements;
var
  f: TFormatter;
  ln: TOutLine;
  s: string;
begin
  s := S8(CH_UL_ON) + 'under' + S8(CH_UL_OFF) + ' ' + S8(CH_BOLD_ON) + 'bold' + S8(CH_BOLD_OFF) +
       S8(CH_SUP_NEXT) + '2';
  f := Fmt([s]);
  ln := f.GetPage(0).Lines[0];
  CheckEq(S8(LineText(ln)), StringOfChar(' ', 9) + 'under bold2', 'markers do not print');
  Check(ln.Cells[9].Attr and A_UL <> 0, 'underline attribute');
  Check(ln.Cells[15].Attr and A_BOLD <> 0, 'bold attribute');
  Check(ln.Cells[19].Attr and A_SUP <> 0, 'superscript next character');
  f.Free;
  { hard space keeps words together; conditional hyphen hyphenates only if needed }
  f := Fmt([CK + 'lm1:rm9', 'aaaa bb' + S8(CH_HARDSPACE) + 'cc ddd']);
  CheckEq(Trimmed(PageLine(f, 1, 1)), 'aaaa', 'hard space words wrap together');
  CheckEq(Trimmed(PageLine(f, 1, 2)), 'bb cc ddd', 'hard space prints as a space');
  f.Free;
  f := Fmt([CK + 'lm1:rm10', 'aaa hypo' + S8(CH_SHY) + 'allergenic']);
  CheckEq(Trimmed(PageLine(f, 1, 1)), 'aaa hypo-', 'conditional hyphen breaks the word');
  CheckEq(Trimmed(PageLine(f, 1, 2)), 'allergenic', 'rest of the word on the next line');
  f.Free;
  f := Fmt([CK + 'lm1:rm40', 'hypo' + S8(CH_SHY) + 'allergenic']);
  CheckEq(Trimmed(PageLine(f, 1, 1)), 'hypoallergenic', 'conditional hyphen vanishes when not needed');
  f.Free;
  f := Fmt([CK + 'lm1:rm9', 'aaa hypo-' + S8(CH_BREAK) + 'allergenic']);
  CheckEq(Trimmed(PageLine(f, 1, 1)), 'aaa hypo-', 'breakpoint splits after the hyphen');
  f.Free;
end;

type
  TLoaderBox = class
    function Load(const name: string; var paras: TStrArray): Boolean;
    function Ask: string;
  end;

function TLoaderBox.Load(const name: string; var paras: TStrArray): Boolean;
begin
  SetLength(paras, 2);
  Result := True;
  if name = 'part two' then
  begin
    paras[0] := U('second file');
    paras[1] := U(CK + 'tb Chapter Two');
  end
  else if name = 'ctl' then
  begin
    SetLength(paras, 1);
    paras[0] := U('from the external file');
  end
  else Result := False;
end;

function TLoaderBox.Ask: string;
begin
  Result := 'part two';
end;

procedure TestLinks;
var
  f: TFormatter;
  box: TLoaderBox;
begin
  box := TLoaderBox.Create;
  f := TFormatter.Create;
  f.Loader := @box.Load;
  f.AskNext := @box.Ask;
  f.Run([U('first file'), U(CK + 'tf:contents'), U(CK + 'tb Chapter One'), U(CK + 'nx:part two')]);
  CheckEq(Trimmed(S8(LineText(f.GetPage(0).Lines[0]))), '         first file', 'first file printed');
  CheckEq(Trimmed(S8(LineText(f.GetPage(0).Lines[1]))), '         second file', 'linked file continues the page');
  CheckInt(f.TocEntries.Count, 2, 'table of contents entries from both files');
  CheckEq(f.TocEntries[0], '1'#9'Chapter One', 'toc entry with page number');
  CheckEq(f.TocFileName, 'contents', 'toc file name');
  f.Free;
  f := TFormatter.Create;
  f.Loader := @box.Load;
  f.AskNext := @box.Ask;
  f.Run([U('a'), U(CK + 'lk')]);
  CheckEq(Trimmed(S8(LineText(f.GetPage(0).Lines[1]))), '         second file', 'non-specific link asks for the file');
  f.Free;
  f := TFormatter.Create;
  f.Loader := @box.Load;
  f.Run([U('top'), U(CK + 'ex:ctl'), U('bottom')]);
  CheckEq(Trimmed(S8(LineText(f.GetPage(0).Lines[1]))), '         from the external file', 'external link inlines the file');
  CheckEq(Trimmed(S8(LineText(f.GetPage(0).Lines[2]))), '         bottom', 'and returns to the control file');
  f.Free;
  box.Free;
end;

procedure SetupCol(d: TDoc; const rows: array of string; p1, c1, p2, c2: Integer);
var
  i: Integer;
begin
  d.Clear;
  d.SetText('');
  for i := 0 to High(rows) do
    if i = 0 then d[0] := U(rows[0]) else d.InsPara(i, U(rows[i]));
  d.ColSet := True;
  d.ColP1 := p1; d.ColC1 := c1; d.ColP2 := p2; d.ColC2 := c2;
end;

procedure TestColumns;
var
  d: TDoc;
  res: UnicodeString;
  rows: TStrArray;
  err: string;
begin
  d := TDoc.Create;
  { the move example from the manual }
  SetupCol(d, ['John Doe       Anywhere', 'Sam  Spade     Nowhere', 'Fred Ferdinand Somewhere'], 0, 0, 2, 5);
  err := ColMove(d, 0, 15);
  CheckEq(err, '', 'move column');
  CheckEq(S8(d[0]), 'Doe       John Anywhere', 'move: first row');
  CheckEq(S8(d[2]), 'Ferdinand Fred Somewhere', 'move: last row');
  d.Clear;
  { shift leaves blanks behind; repeat keeps the original }
  SetupCol(d, ['abc    ', 'def    '], 0, 0, 1, 3);
  err := ColShift(d, 0, 4);
  CheckEq(err, '', 'shift column');
  CheckEq(S8(d[0]), '    abc', 'shift: moved and blanked');
  SetupCol(d, ['abc    ', 'def    '], 0, 0, 1, 3);
  ColRepeat(d, 0, 4);
  CheckEq(S8(d[1]), 'def def', 'repeat keeps the original');
  SetupCol(d, ['abcdef', 'ghijkl'], 0, 1, 1, 3);
  ColDelete(d);
  CheckEq(S8(d[0]), 'adef', 'delete closes the gap');
  SetupCol(d, ['abcdef', 'ghijkl'], 0, 1, 1, 3);
  ColErase(d);
  CheckEq(S8(d[1]), 'g  jkl', 'erase blanks the column');
  SetupCol(d, ['abcdef', 'ghijkl'], 0, 1, 1, 3);
  ColInsertSpaces(d, 2, 80);
  CheckEq(S8(d[0]), 'a  bcdef', 'insert spaces in front of the column');
  { addition from the manual: 147.78 $100 (12.00) -18 98,654 = $98,874.75 }
  SetupCol(d, ['  147.78', '   $100', '(12.00)', '   -18', ' 98,654'], 0, 0, 4, 8);
  err := ColSumDown(d, 255, res);
  CheckEq(err, '', 'sum column');
  CheckEq(S8(res), '$98,871.78', 'sum keeps style (dollar, commas) and exact digits');
  SetupCol(d, ['1.10', '2.20'], 0, 0, 1, 4);
  ColSumDown(d, 1, res);
  CheckEq(S8(res), '3.3', 'fixed decimal places');
  SetupCol(d, ['0.005', '0.004'], 0, 0, 1, 5);
  ColSumDown(d, 2, res);
  CheckEq(S8(res), '0.01', 'rounding half up');
  SetupCol(d, ['(5)', '2'], 0, 0, 1, 3);
  ColSumDown(d, 255, res);
  CheckEq(S8(res), '(3)', 'parenthesis style for negative results');
  { rows }
  SetupCol(d, ['1 2 3', '4 5 6'], 0, 0, 1, 5);
  err := ColSumRows(d, '                ', 255, rows);
  CheckEq(err, '', 'add rows');
  CheckEq(S8(rows[0]), '6', 'row 1 total');
  CheckEq(S8(rows[1]), '15', 'row 2 total');
  { big numbers: up to 38 digits }
  SetupCol(d, [StringOfChar('9', 38), '1'], 0, 0, 1, 38);
  err := ColSumDown(d, 255, res);
  CheckEq(err, 'Overflow error', 'overflow beyond 38 digits');
  { sorting, from the manual }
  SetupCol(d, ['Chuck Wagone', 'Ben Dover', 'Terry Dactyle', 'Sal Amander', 'Perry Scope'], 0, 0, 4, 20);
  err := ColSort(d, [2], True, False, StringOfChar(' ', 16));
  CheckEq(err, '', 'sort');
  CheckEq(Trimmed(S8(d[0])), 'Sal Amander', 'sorted by last name: first');
  CheckEq(Trimmed(S8(d[4])), 'Chuck Wagone', 'sorted by last name: last');
  SetupCol(d, ['5.23', 'fred', 'teen3', '52'], 0, 0, 3, 5);
  ColSort(d, [1], True, False, StringOfChar(' ', 16));
  CheckEq(Trimmed(S8(d[0])), '5.23', 'numbers sort numerically first');
  CheckEq(Trimmed(S8(d[1])), '52', 'second number');
  CheckEq(Trimmed(S8(d[2])), 'fred', 'then text');
  CheckEq(Trimmed(S8(d[3])), 'teen3', 'text with digits is text');
  SetupCol(d, ['b 2', 'a 2', 'a 1'], 0, 0, 2, 3);
  ColSort(d, [2, 1], True, False, StringOfChar(' ', 16));
  CheckEq(Trimmed(S8(d[0])), 'a 1', 'multi-field sort: first key then second (low)');
  CheckEq(Trimmed(S8(d[1])), 'a 2', 'multi-field sort (middle)');
  SetupCol(d, ['a', 'c', 'b'], 0, 0, 2, 1);
  ColSort(d, [1], False, False, StringOfChar(' ', 16));
  CheckEq(S8(d[0]), 'c', 'descending');
  { placing a result with the decimal point under the cursor }
  SetupCol(d, ['', ''], 0, 0, 0, 1);
  d.Clear;
  d.SetText('x'#10);
  PlaceResult(d, 0, 10, '$98,874.75');
  CheckInt(Pos('.', S8(d[0])), 11, 'decimal point under the chosen column');
  d.Free;
end;

procedure TestSpellScan;
var
  d: TDoc;
  hits: THitArray;
begin
  d := TDoc.Create;
  d.SetText('Hello wrld, it''s NASA x2 abc123 a ' + S8(CH_BOLD_ON) + 'bo' + S8(CH_UL_ON) + 'ld' + S8(CH_UL_OFF) + S8(CH_BOLD_OFF) + ' fine.'#10 +
            S8(CH_CHECK) + 'cm:skipthis words'#10 + 'last wordz');
  ScanWords(d, 0, hits);
  CheckInt(Length(hits), 7, 'Hello wrld it''s bold fine last wordz; NASA, x2, abc123 and a are left out');
  CheckEq(S8(hits[0].Word), 'Hello', 'first word');
  CheckEq(S8(hits[1].Word), 'wrld', 'comma ends a word');
  CheckInt(hits[1].C1, 6, 'position of wrld');
  CheckEq(S8(hits[2].Word), 'it''s', 'apostrophe stays inside the word');
  CheckEq(S8(hits[3].Word), 'bold', 'print marks inside a word are looked through');
  CheckEq(S8(hits[4].Word), 'fine', 'text after the marks');
  CheckInt(hits[5].P, 2, 'the format line is skipped, the last paragraph is paragraph 2');
  CheckEq(S8(hits[6].Word), 'wordz', 'last word');
  Check(IsAcronym('NASA') and (not IsAcronym('Nasa')) and (not IsAcronym('A')), 'acronym detection');
  d.Free;
end;

procedure TestOutput;
var
  f: TFormatter;
  fn: string;
  sz: Int64;
  fs: TFileStream;
  head: string;
begin
  f := Fmt([S8(CH_BOLD_ON) + 'Hello' + S8(CH_BOLD_OFF) + ' PDF world']);
  fn := GetTempDir + 'pc_test_out.pdf';
  CheckEq(WritePDF(f, fn, psLetter, 1, 0), '', 'pdf written');
  fs := TFileStream.Create(fn, fmOpenRead);
  sz := fs.Size;
  SetLength(head, 8);
  fs.ReadBuffer(head[1], 8);
  fs.Free;
  Check(sz > 500, 'pdf has content');
  CheckEq(Copy(head, 1, 5), '%PDF-', 'pdf header');
  DeleteFile(fn);
  fn := GetTempDir + 'pc_test_out.txt';
  CheckEq(WritePlainText(f, fn, 1, 0), '', 'text written');
  DeleteFile(fn);
  f.Free;
end;

procedure TestHelpFilter;
var
  src, dst: TStringList;

  function Run(const q: string): string;
  var
    i: Integer;
  begin
    FilterHelp(src, dst, q);
    Result := '';
    for i := 0 to dst.Count - 1 do Result := Result + dst[i] + ';';
  end;

begin
  src := TStringList.Create;
  dst := TStringList.Create;
  src.Add('#Editing');
  src.Add('Ctrl+Z|Undo');
  src.Add('Ctrl+I|Insert many lines');
  src.Add('');
  src.Add('#Files');
  src.Add('Ctrl+S|Save the file');
  src.Add('A paragraph about backups.');
  CheckEq(Run('undo'), '#Editing;Ctrl+Z|Undo;', 'help filter: one entry with its heading');
  CheckEq(Run('UNDO'), '#Editing;Ctrl+Z|Undo;', 'help filter ignores case');
  CheckEq(Run('ctrl+s'), '#Files;Ctrl+S|Save the file;', 'help filter matches the key');
  CheckEq(Run('ctrl'), '#Editing;Ctrl+Z|Undo;Ctrl+I|Insert many lines;;#Files;Ctrl+S|Save the file;',
    'help filter: two sections with a gap');
  CheckEq(Run('files'), '#Files;Ctrl+S|Save the file;A paragraph about backups.;', 'help filter: a heading keeps its section');
  CheckEq(Run('files  backups'), '#Files;A paragraph about backups.;', 'help filter: every word must match');
  CheckEq(Run('undo save'), '', 'help filter: words in different entries do not match');
  CheckEq(Run('zzzz'), '', 'help filter: nothing');
  src.Free;
  dst.Free;
end;

{$I tests_dirs.inc}
{$I tests_syntax.inc}


{ ---- plain text mode: a file must come back byte for byte ---- }

procedure WriteRaw(const fn, data: string);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(fn, fmCreate);
  try
    if Length(data) > 0 then fs.WriteBuffer(data[1], Length(data));
  finally
    fs.Free;
  end;
end;

function ReadRaw(const fn: string): string;
var
  fs: TFileStream;
begin
  Result := '';
  fs := TFileStream.Create(fn, fmOpenRead);
  try
    SetLength(Result, fs.Size);
    if fs.Size > 0 then fs.ReadBuffer(Result[1], fs.Size);
  finally
    fs.Free;
  end;
end;

procedure RoundTrip(const name, data: string);
var
  d: TDoc;
  fn, err: string;
begin
  fn := 'build/test/plain/' + name;
  WriteRaw(fn, data);
  d := TDoc.Create;
  try
    err := d.LoadFromFile(fn, True);
    CheckEq(err, '', name + ': loads');
    Check(d.Plain, name + ': is in plain mode');
    err := d.SaveToFile(fn + '.out', False, True);
    CheckEq(err, '', name + ': saves');
    Check(ReadRaw(fn + '.out') = data, name + ': comes back byte for byte');
  finally
    d.Free;
  end;
end;

procedure TestPlain;
var
  d: TDoc;
  {$IFDEF UNIX}
  fn, err: string;
  st: Stat;
  {$ENDIF}
begin
  ForceDirectories('build/test/plain');
  RoundTrip('lf', 'one'#10'two'#10);
  RoundTrip('crlf', 'one'#13#10'two'#13#10);
  RoundTrip('nofinal', 'one'#10'two');
  RoundTrip('single', 'a');
  RoundTrip('empty', '');
  RoundTrip('blank', #10);
  RoundTrip('blanks', 'a'#10#10#10);
  RoundTrip('tabs', 'all:'#10#9'cc -o x x.c'#10'a'#9'b'#9'c'#10);
  RoundTrip('bom', #$EF#$BB#$BF'name=caf'#$C3#$A9#10);
  RoundTrip('latin1', 'caf'#$E9' = '#$80#10);
  RoundTrip('emoji', 'x = '#$F0#$9F#$98#$80' y'#10);
  RoundTrip('backslash', 'path=C:\dir\file'#10'\ju on'#10);
  RoundTrip('check', #$E2#$9C#$93'ju on'#10);
  RoundTrip('pua', 'a'#$EE#$80#$83'b'#$EE#$83#$B0'c'#10);
  RoundTrip('meta', #$EE#$83#$B0'PAPERCLIP 1 ll=60 tabs='#10'text'#10);
  RoundTrip('ctrl', 'a'#12'b'#27'[0m'#13'c'#10);
  RoundTrip('nbsp', 'a'#$C2#$A0'b'#$C2#$AD'c'#$E2#$80#$8B'd'#10);
  RoundTrip('crlfnofinal', 'a'#13#10'b');
  RoundTrip('trailingspace', 'a  '#10'  b'#10);
  { files that cannot be edited faithfully are refused and leave the document alone }
  WriteRaw('build/test/plain/bin', 'ab'#0'cd');
  d := TDoc.Create;
  try
    d.SetText('keep me');
    Check(d.LoadFromFile('build/test/plain/bin', True) <> '', 'a file with NUL bytes is refused');
    CheckEq(S8(d[0]), 'keep me', 'and the document is untouched');
    { mixed line endings are normalised and the user is told }
    WriteRaw('build/test/plain/mixed', 'a'#13#10'b'#10'c'#13#10);
    CheckEq(d.LoadFromFile('build/test/plain/mixed', True), '', 'mixed loads');
    Check(d.CRLF, 'the majority style wins');
    Check(d.LoadNote <> '', 'and says so');
    { an edited Latin-1 file keeps its encoding unless it gets a character Latin-1 lacks }
    WriteRaw('build/test/plain/l1', 'caf'#$E9#10);
    d.LoadFromFile('build/test/plain/l1', True);
    d.InsText(0, 0, U('x'));
    CheckEq(d.SaveToFile('build/test/plain/l1', False, True), '', 'saves an edited Latin-1 file');
    CheckEq(ReadRaw('build/test/plain/l1'), 'xcaf'#$E9#10, 'still Latin-1');
    d.InsText(0, 0, WideChar($20AC));
    d.SaveToFile('build/test/plain/l1', False, True);
    CheckEq(ReadRaw('build/test/plain/l1'), #$E2#$82#$AC'xcaf'#$C3#$A9#10, 'a euro sign makes it UTF-8');
    Check(d.SaveNote <> '', 'and says so');
    { an empty file that gets text ends with a newline }
    WriteRaw('build/test/plain/e2', '');
    d.LoadFromFile('build/test/plain/e2', True);
    d.InsText(0, 0, U('hi'));
    d.SaveToFile('build/test/plain/e2', False, True);
    CheckEq(ReadRaw('build/test/plain/e2'), 'hi'#10, 'typed into an empty file');
    { the same file in PaperClip mode still expands tabs and drops control characters }
    WriteRaw('build/test/plain/pc', 'a'#9'b'#10);
    d.LoadFromFile('build/test/plain/pc');
    Check(not d.Plain, 'PaperClip mode by default');
    CheckEq(S8(d[0]), 'a       b', 'tabs expand to 8');
    { leaving plain mode expands them too }
    d.LoadFromFile('build/test/plain/pc', True);
    CheckEq(S8(d[0]), 'a'#9'b', 'plain keeps the tab');
    d.ToPaperClip;
    CheckEq(S8(d[0]), 'a       b', 'leaving plain mode expands it');
    Check(not d.Plain, 'and is no longer plain');
  finally
    d.Free;
  end;
  {$IFDEF UNIX}
  { permissions and links survive a save }
  fn := 'build/test/plain/script';
  WriteRaw(fn, '#!/bin/sh'#10'echo hi'#10);
  FpChmod(fn, &750);
  d := TDoc.Create;
  try
    d.LoadFromFile(fn, True);
    d.InsText(1, 0, U('# '));
    CheckEq(d.SaveToFile(fn, False, True), '', 'script saves');
    FpStat(fn, st);
    CheckInt(st.st_mode and &7777, &750, 'the mode is kept');
    CheckEq(ReadRaw(fn), '#!/bin/sh'#10'# echo hi'#10, 'script text');
    DeleteFile('build/test/plain/link');
    FpSymlink('script', 'build/test/plain/link');
    d.LoadFromFile('build/test/plain/link', True);
    d.InsText(1, 0, U('# '));
    err := d.SaveToFile('build/test/plain/link', False, True);
    CheckEq(err, '', 'saves through a link');
    FpLStat('build/test/plain/link', st);
    Check(fpS_ISLNK(st.st_mode), 'the link is still a link');
    CheckEq(ReadRaw(fn), '#!/bin/sh'#10'# # echo hi'#10, 'and the file it points to changed');
  finally
    d.Free;
  end;
  {$ENDIF}
end;

begin
  {$IFDEF WINDOWS}
  SetMultiByteConversionCodePage(CP_UTF8);
  SetMultiByteRTLFileSystemCodePage(CP_UTF8);
  DefaultSystemCodePage := CP_UTF8;
  {$ENDIF}
  Fails := 0;
  Passes := 0;
  TestWrap;
  TestTabCol;
  TestDoc;
  TestSearch;
  TestFormatterBasics;
  TestPages;
  TestEnhancements;
  TestLinks;
  TestColumns;
  TestSpellScan;
  TestOutput;
  TestDirs;
  TestPlain;
  TestSyntax;
  TestHelpFilter;
  WriteLn(Passes, ' passed, ', Fails, ' failed');
  if Fails > 0 then Halt(1);
end.
