{ tests_syntax.inc - the syntax colouring tokenizer (included by test_core.pas) }

{ a class string for a line: . text, k keyword, t type, s string, n number, c comment, p preprocessor }
function Shape(lang: TLang; const line: UnicodeString; st: Word; out nst: Word): string;
var
  cls: TClsArray;
  i: Integer;
begin
  SetLength(cls, 0);
  nst := HighlightLine(lang, line, st, cls);
  Result := '';
  for i := 0 to Length(line) - 1 do
    Result := Result + Copy('.ktsncp', cls[i] + 1, 1);
end;

{ 'k5 .6 s8' -> 'kkkkk......ssssssss' }
function Run(const spec: string): string;
var
  i, n, code: Integer;
  parts: TStringList;
  p: string;
begin
  Result := '';
  parts := TStringList.Create;
  try
    parts.Delimiter := ' ';
    parts.StrictDelimiter := True;
    parts.DelimitedText := spec;
    for i := 0 to parts.Count - 1 do
    begin
      p := parts[i];
      if p = '' then Continue;
      Val(Copy(p, 2, 10), n, code);
      if code <> 0 then n := 1;
      Result := Result + StringOfChar(p[1], n);
    end;
  finally
    parts.Free;
  end;
end;

procedure ShapeIs(lang: TLang; const line: string; const spec: string);
var
  st: Word;
begin
  CheckEq(Shape(lang, U(line), 0, st), Run(spec), LangName(lang) + ': ' + line);
end;

{ the state after a line, then the shape of the next line seen from that state }
procedure TwoLines(lang: TLang; const a, specA, b, specB: string; endsClosed: Boolean);
var
  st, st2: Word;
begin
  CheckEq(Shape(lang, U(a), 0, st), Run(specA), LangName(lang) + ' first: ' + a);
  Check(st <> 0, LangName(lang) + ' leaves a state after: ' + a);
  CheckEq(Shape(lang, U(b), st, st2), Run(specB), LangName(lang) + ' second: ' + b);
  Check((st2 = 0) = endsClosed, LangName(lang) + ' final state for: ' + b);
end;

procedure TestSyntax;
var
  st: Word;
  seed, i, j, k: Integer;
  pieces: array[0..39] of string;
  line: string;
  lang: TLang;
  cls: TClsArray;
begin
  { which language a file gets }
  Check(LangFor('a.pas', '') = lnPascal, 'LangFor .pas');
  Check(LangFor('/x/UNIT.INC', '') = lnPascal, 'LangFor .INC');
  Check(LangFor('m.cpp', '') = lnC, 'LangFor .cpp');
  Check(LangFor('x.rs', '') = lnRust, 'LangFor .rs');
  Check(LangFor('notes.txt', '') = lnNone, 'LangFor .txt');
  Check(LangFor('notes', '') = lnNone, 'LangFor no extension');
  Check(LangFor('run', '#!/bin/bash') = lnShell, 'LangFor bash shebang');
  Check(LangFor('run', '#!/usr/bin/env python3') = lnPython, 'LangFor python shebang');
  Check(LangFor('fstab', '') = lnConf, 'LangFor fstab');
  Check(LangFor('kitty.conf', '') = lnConf, 'LangFor .conf');
  Check(LangFor('.bashrc', '') = lnShell, 'LangFor .bashrc');
  Check(LangFor('README', '# hello') = lnNone, 'LangFor a # first line is not a shebang');

  { Pascal }
  ShapeIs(lnPascal, 'begin x := ''don''''t'';', 'k5 .6 s8 .1');
  ShapeIs(lnPascal, '#13#10 $FF 12.5 1..10', 's6 .1 n3 .1 n4 .1 n1 .2 n2');
  ShapeIs(lnPascal, '{$mode objfpc}', 'p14');
  ShapeIs(lnPascal, '{$I x.inc} y', 'p10 .2');
  ShapeIs(lnPascal, '{ a comment } x', 'c13 .2');
  ShapeIs(lnPascal, 'BEGIN End', 'k5 .1 k3');
  ShapeIs(lnPascal, 'TFoo Tx Table', 't4 .1 .2 .1 .5');
  ShapeIs(lnPascal, 'a(*b*)c', '.1 c5 .1');
  ShapeIs(lnPascal, 'x // t', '.2 c4');
  ShapeIs(lnPascal, 'a'#9'begin', '.1 .1 k5');
  ShapeIs(lnPascal, '''' + S8(UnicodeString(#$D83D#$DE00)) + '''', 's4');
  TwoLines(lnPascal, '{ open', 'c6', 'still (* not closed } end', 'c21 .1 k3', True);
  TwoLines(lnPascal, '(* open', 'c7', 'x } y *) z', 'c8 .2', True);
  TwoLines(lnPascal, '(* open', 'c7', 'x } y', 'c5', False);
  TwoLines(lnPascal, '{ open', 'c6', 'x *) y', 'c6', False);
  { openers cut off by the end of the line }
  ShapeIs(lnPascal, 'x (', '.3');
  ShapeIs(lnPascal, '/', '.1');
  ShapeIs(lnPascal, '#', '.1');
  ShapeIs(lnPascal, '$', '.1');
  ShapeIs(lnPascal, '1e', 'n2');
  ShapeIs(lnPascal, '''abc', 's4');
  Check(Shape(lnPascal, U('{'), 0, st) = 'c', 'Pascal { at end of line');
  Check(st <> 0, 'Pascal { at end of line leaves a state');
  Check(Shape(lnPascal, U('(*'), 0, st) = 'cc', 'Pascal (* at end of line');
  Check(st <> 0, 'Pascal (* at end of line leaves a state');
  Check(Shape(lnPascal, U('{$'), 0, st) = 'pp', 'Pascal {$ at end of line');

  { C }
  ShapeIs(lnC, '"a\"b" ''x'' ''\''''', 's6 .1 s3 .1 s4');
  ShapeIs(lnC, '#include <stdio.h>', 'p8 .1 s9');
  ShapeIs(lnC, '  #define X 1', '.2 p7 .3 n1');
  ShapeIs(lnC, '/* a */ x /* b', 'c7 .3 c4');
  ShapeIs(lnC, '0x1F 1.5e-3 10UL', 'n4 .1 n6 .1 n4');
  ShapeIs(lnC, 'uint8_t v; int', 't7 .4 t3');
  ShapeIs(lnC, 'if (x) return;', 'k2 .5 k6 .1');
  ShapeIs(lnC, 'a /', '.3');
  ShapeIs(lnC, '"', 's1');
  ShapeIs(lnC, '''', 's1');
  ShapeIs(lnC, '#', 'p1');
  ShapeIs(lnC, 'x = a # b', '.9');
  ShapeIs(lnC, '// "not a string"', 'c17');
  TwoLines(lnC, '/* a */ x /* b', 'c7 .3 c4', 'c */ int', 'c4 .1 t3', True);
  Check(Shape(lnC, U('/*'), 0, st) = 'cc', 'C /* at end of line');
  Check(st <> 0, 'C /* at end of line leaves a state');
  Check(Shape(lnC, U('//'), 0, st) = 'cc', 'C // at end of line');
  Check(st = 0, 'C // leaves no state');

  { Rust }
  ShapeIs(lnRust, '/* a /* b */ still */ x', 'c21 .2');
  TwoLines(lnRust, '/* a /* b */', 'c12', ' c */ x', 'c5 .2', True);
  TwoLines(lnRust, '/* a /* b */', 'c12', ' c */ x /* d', 'c5 .3 c4', False);
  ShapeIs(lnRust, '&''a str ''b'' ''\n'' ''\u{1F600}''', '.1 t2 .1 t3 .1 s3 .1 s4 .1 s11');
  ShapeIs(lnRust, 'r#"a"b"# x', 's8 .2');
  TwoLines(lnRust, 'r##"abc', 's7', '"# still "## x', 's12 .2', True);
  TwoLines(lnRust, 'let s = "abc', 'k3 .5 s4', 'def" + 1', 's4 .3 n1', True);
  ShapeIs(lnRust, 'println!("x");', 'p8 .1 s3 .2');
  ShapeIs(lnRust, 'x!=y', '.4');
  ShapeIs(lnRust, '"a\\"', 's5');
  ShapeIs(lnRust, '''', '.1');
  ShapeIs(lnRust, 'r', '.1');
  ShapeIs(lnRust, 'r#', '.2');
  ShapeIs(lnRust, 'fn x() {}', 'k2 .7');
  ShapeIs(lnRust, '''\\''; x', 's4 .1 .2');
  ShapeIs(lnRust, '''\''''; x', 's4 .1 .2');

  { Python, shell, config }
  TwoLines(lnPython, 'x = """a', '.4 s4', 'b""" + y', 's4 .4', True);
  ShapeIs(lnPython, 'def f(): # c', 'k3 .6 c3');
  ShapeIs(lnPython, 's = f"a#b"', '.5 s5');
  ShapeIs(lnShell, 'echo "$HOME" # hi', 't4 .1 s7 .1 c4');
  ShapeIs(lnShell, 'FOO=bar', 't3 .4');
  ShapeIs(lnShell, 'a#b', '.3');
  ShapeIs(lnShell, 'it''s', '.4');
  ShapeIs(lnShell, 'echo $HOME ${x}', 't4 .1 t5 .1 t4');
  ShapeIs(lnConf, 'foreground #dddddd', '.18');
  ShapeIs(lnConf, 'key = x # note', 'k3 .5 c6');
  ShapeIs(lnConf, '  # indented', '.2 c10');
  ShapeIs(lnConf, 'a = b #', 'k1 .5 c1');
  ShapeIs(lnShell, 'echo a #b', 't4 .3 c2');
  ShapeIs(lnConf, 'UUID=4b9dd8ec-8e67 utf-8 60 0', 'k4 .1 .13 .1 .5 .1 n2 .1 n1');
  ShapeIs(lnShell, 'echo $1 $? 5', 't4 .1 t2 .1 t2 .1 n1');
  ShapeIs(lnConf, '[Section]', 't9');
  ShapeIs(lnConf, 'key = value', 'k3 .8');
  ShapeIs(lnConf, '# c', 'c3');
  ShapeIs(lnConf, '; c', 'c3');
  ShapeIs(lnConf, 'Port 22', '.5 n2');
  ShapeIs(lnConf, 'enabled = yes', 'k7 .3 k3');
  ShapeIs(lnNone, 'begin end', '.9');

  { the text is never touched and nothing can run off the end, whatever the line holds }
  pieces[0] := '{'; pieces[1] := '}'; pieces[2] := '(*'; pieces[3] := '*)'; pieces[4] := '/*';
  pieces[5] := '*/'; pieces[6] := '//'; pieces[7] := '"'; pieces[8] := ''''; pieces[9] := '\';
  pieces[10] := '#'; pieces[11] := '$'; pieces[12] := 'r#"'; pieces[13] := '"#'; pieces[14] := '''''''';
  pieces[15] := '"""'; pieces[16] := ' '; pieces[17] := #9; pieces[18] := 'begin'; pieces[19] := 'x1';
  pieces[20] := '0x'; pieces[21] := '1.5e'; pieces[22] := '!'; pieces[23] := '<'; pieces[24] := '>';
  pieces[25] := '{$'; pieces[26] := '[a]'; pieces[27] := '='; pieces[28] := ';'; pieces[29] := '${';
  pieces[30] := 'include'; pieces[31] := 'r'; pieces[32] := 'br'; pieces[33] := #$EE#$83#$B0;
  pieces[34] := #$F0#$9F#$98#$80; pieces[35] := #$C3#$A9; pieces[36] := '1'; pieces[37] := '..';
  pieces[38] := '_t'; pieces[39] := #13;
  RandSeed := 20261123;
  k := 0;
  for lang := lnPascal to lnConf do
  begin
    st := 0;
    for i := 1 to 3000 do
    begin
      line := '';
      for j := 1 to Random(8) do line := line + pieces[Random(40)];
      SetLength(cls, 0);
      st := HighlightLine(lang, U(line), st, cls);
      if Random(5) = 0 then st := 0;
      if Length(cls) < Length(U(line)) then Inc(k);
    end;
  end;
  CheckInt(k, 0, 'tokenizer fills a class for every character');
end;
