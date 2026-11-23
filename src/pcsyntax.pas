{ pcsyntax.pas - syntax colouring for plain text mode.

  One line at a time: HighlightLine takes the line and the state the previous line ended in (inside a
  block comment, a multi-line string...), fills in a class for every character and returns the state
  this line ends in.  It never changes the text.  No SDL and no application types here, so the core
  tests can drive it directly. }
{$mode objfpc}{$H+}
unit pcsyntax;

interface

uses
  SysUtils, StrUtils;

const
  HC_TEXT = 0;
  HC_KEYWORD = 1;
  HC_TYPE = 2;
  HC_STRING = 3;
  HC_NUMBER = 4;
  HC_COMMENT = 5;
  HC_PREPROC = 6;      { C preprocessor lines, Pascal compiler directives, Rust macros }
  HC_LAST = 6;

type
  TLang = (lnNone, lnPascal, lnC, lnRust, lnPython, lnShell, lnConf);
  TClsArray = array of Byte;

{ the language for a file name; the first line is only looked at for a #! line }
function LangFor(const fileName: string; const firstLine: UnicodeString): TLang;
function LangName(l: TLang): string;
{ Classes land in cls[0 .. Length(s)-1] (cls grows if it must).  The state is 0 at the top of a file. }
function HighlightLine(lang: TLang; const s: UnicodeString; inState: Word; var cls: TClsArray): Word;

implementation

const
  KW_PASCAL = ' and array as asm begin case class const constructor destructor div do downto else end except ' +
    'exports file finalization finally for function goto if implementation in inherited initialization ' +
    'inline interface is label library mod nil not object of on operator or out packed procedure program ' +
    'property raise record repeat resourcestring set shl shr then threadvar to try type unit until uses var ' +
    'while with xor absolute abstract alias assembler cdecl dispose exit false forward generic ' +
    'helper new nostackframe override overload private protected public published ' +
    'register reintroduce result self specialize stdcall true virtual static strict ' +
    'deprecated platform external far near interrupt ';
  TY_PASCAL = ' integer cardinal byte word longint longword shortint smallint int64 qword boolean char ' +
    'widechar ansichar string ansistring unicodestring widestring shortstring real single double ' +
    'extended currency pointer variant text tobject exception pchar pbyte nativeint nativeuint ' +
    'bytebool wordbool longbool uint8 uint16 uint32 uint64 int8 int16 int32 ';
  KW_C = ' auto break case const continue default do else enum extern for goto if inline register ' +
    'restrict return sizeof static struct switch typedef union volatile while NULL true false nullptr ' +
    'class namespace new delete public private protected template typename virtual this using try ' +
    'catch throw operator override final constexpr explicit friend mutable noexcept static_cast ' +
    'dynamic_cast reinterpret_cast const_cast ';
  TY_C = ' void char short int long float double signed unsigned bool size_t ssize_t FILE wchar_t ' +
    '_Bool auto_ptr string ';
  KW_RUST = ' as async await break const continue crate dyn else enum extern false fn for if impl in ' +
    'let loop match mod move mut pub ref return self static struct super trait true type unsafe use ' +
    'where while union ';
  TY_RUST = ' i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str String Vec ' +
    'Option Result Box Self Some None Ok Err ';
  KW_PYTHON = ' and as assert async await break class continue def del elif else except finally for ' +
    'from global if import in is lambda nonlocal not or pass raise return try while with yield None ' +
    'True False ';
  TY_PYTHON = ' self cls int str float list dict set tuple bool bytes object type range len print ';
  KW_SHELL = ' if then else elif fi for while until do done case esac in function select return exit ' +
    'break continue export local readonly declare unset shift set source alias eval exec trap true false ';
  TY_SHELL = ' echo printf cd pwd read test ls cat grep sed awk mkdir rm cp mv chmod chown sudo ';
  KW_CONF = ' true false yes no on off ';

function InList(const list, w: string): Boolean;
begin
  Result := Pos(' ' + w + ' ', list) > 0;
end;

{ the word as a plain ASCII string for the keyword tables; False when it cannot be a keyword }
function AsciiWord(const s: UnicodeString; a, b: Integer; lower: Boolean; out w: string): Boolean;
var
  i: Integer;
  c: WideChar;
begin
  Result := False;
  w := '';
  if (b - a + 1 > 24) or (b < a) then Exit;
  SetLength(w, b - a + 1);
  for i := a to b do
  begin
    c := s[i];
    if c > #127 then Exit;
    if lower and (c >= 'A') and (c <= 'Z') then c := WideChar(Ord(c) + 32);
    w[i - a + 1] := Char(Ord(c));
  end;
  Result := True;
end;

function LangFor(const fileName: string; const firstLine: UnicodeString): TLang;
var
  ext, nm: string;
  p: Integer;
begin
  Result := lnNone;
  ext := LowerCase(ExtractFileExt(fileName));
  nm := LowerCase(ExtractFileName(fileName));
  if (ext = '.pas') or (ext = '.pp') or (ext = '.lpr') or (ext = '.dpr') or (ext = '.inc') then Exit(lnPascal);
  if (ext = '.c') or (ext = '.h') or (ext = '.cpp') or (ext = '.hpp') or (ext = '.cc') or (ext = '.cxx') or
     (ext = '.hh') or (ext = '.hxx') or (ext = '.ino') then Exit(lnC);
  if ext = '.rs' then Exit(lnRust);
  if (ext = '.py') or (ext = '.pyw') then Exit(lnPython);
  if (ext = '.sh') or (ext = '.bash') or (ext = '.zsh') or (nm = '.bashrc') or (nm = '.zshrc') or
     (nm = '.profile') or (nm = '.bash_profile') or (nm = 'pkgbuild') then Exit(lnShell);
  if (ext = '.conf') or (ext = '.cfg') or (ext = '.ini') or (ext = '.service') or (ext = '.timer') or
     (ext = '.socket') or (ext = '.mount') or (ext = '.target') or (ext = '.desktop') or (ext = '.toml') or
     (ext = '.mk') or (nm = 'makefile') or (nm = 'gnumakefile') or (nm = 'sshd_config') or
     (nm = 'ssh_config') or (nm = 'fstab') or (nm = 'crontab') or (nm = '.gitconfig') then Exit(lnConf);
  if (Length(firstLine) > 2) and (firstLine[1] = '#') and (firstLine[2] = '!') then
  begin
    if (Pos('python', string(firstLine)) > 0) then Exit(lnPython);
    p := Pos('sh', string(firstLine));
    if p > 0 then Exit(lnShell);
  end;
end;

function LangName(l: TLang): string;
begin
  case l of
    lnPascal: Result := 'Pascal';
    lnC: Result := 'C';
    lnRust: Result := 'Rust';
    lnPython: Result := 'Python';
    lnShell: Result := 'Shell';
    lnConf: Result := 'Config';
  else
    Result := '';
  end;
end;

function HighlightLine(lang: TLang; const s: UnicodeString; inState: Word; var cls: TClsArray): Word;
var
  n, i, j, k, q, lineStart, kind, extra, h, depth: Integer;
  c: WideChar;
  w: string;
  hashLang, cLike: Boolean;

  function At(k: Integer): WideChar;
  begin
    if (k >= 1) and (k <= n) then Result := s[k] else Result := #0;
  end;

  procedure Mark(a, b: Integer; v: Byte);
  var
    q: Integer;
  begin
    if b > n then b := n;
    for q := a to b do cls[q - 1] := v;
  end;

  function IsDigit(ch: WideChar): Boolean;
  begin
    Result := (ch >= '0') and (ch <= '9');
  end;

  function IsWordStart(ch: WideChar): Boolean;
  begin
    Result := ((ch >= 'a') and (ch <= 'z')) or ((ch >= 'A') and (ch <= 'Z')) or (ch = '_') or
      ((ch > #127) and not ((ch >= #$D800) and (ch <= #$F8FF)));
  end;

  function IsWordChar(ch: WideChar): Boolean;
  begin
    Result := IsWordStart(ch) or IsDigit(ch);
  end;

  function IsHex(ch: WideChar): Boolean;
  begin
    Result := IsDigit(ch) or ((ch >= 'a') and (ch <= 'f')) or ((ch >= 'A') and (ch <= 'F'));
  end;

  { the closing quote at or after "from", skipping backslash escapes; 0 when the line ends first }
  function ScanQuote(q: WideChar; from: Integer; esc: Boolean): Integer;
  var
    m: Integer;
  begin
    m := from;
    while m <= n do
    begin
      if esc and (s[m] = '\') then Inc(m, 2)
      else if s[m] = q then Exit(m)
      else Inc(m);
    end;
    Result := 0;
  end;

  { where a closing pattern starts at or after "from"; 0 when there is none }
  function FindClose(const pat: UnicodeString; from: Integer): Integer;
  begin
    if from > n then Exit(0);
    Result := PosEx(pat, s, from);
  end;

  { a C-style block comment from i (just past the opener); nested for Rust.  Leaves i past it. }
  procedure BlockComment(startAt: Integer; nested: Boolean);
  var
    m: Integer;
  begin
    m := startAt;
    if not nested then
    begin
      j := FindClose('*/', m);
      if j = 0 then begin Mark(startAt, n, HC_COMMENT); kind := 1; extra := 0; i := n + 1; Exit; end;
      Mark(startAt, j + 1, HC_COMMENT);
      kind := 0;
      i := j + 2;
      Exit;
    end;
    while (m <= n) and (depth > 0) do
    begin
      if (At(m) = '/') and (At(m + 1) = '*') then begin Inc(depth); Inc(m, 2); end
      else if (At(m) = '*') and (At(m + 1) = '/') then begin Dec(depth); Inc(m, 2); end
      else Inc(m);
    end;
    Mark(startAt, m - 1, HC_COMMENT);
    if depth = 0 then kind := 0 else begin kind := 1; extra := depth; end;
    i := m;
  end;

  { a number starting at i; leaves i just past it }
  procedure Number;
  var
    m: Integer;
  begin
    m := i;
    if c = '$' then
    begin
      Inc(m);
      while IsHex(At(m)) or (At(m) = '_') do Inc(m);
    end
    else if (c = '0') and ((At(i + 1) = 'x') or (At(i + 1) = 'X')) then
    begin
      Inc(m, 2);
      while IsWordChar(At(m)) do Inc(m);
    end
    else
    begin
      while IsDigit(At(m)) or (At(m) = '_') do Inc(m);
      if (At(m) = '.') and IsDigit(At(m + 1)) then
      begin
        Inc(m);
        while IsDigit(At(m)) or (At(m) = '_') do Inc(m);
      end;
      if ((At(m) = 'e') or (At(m) = 'E')) and
         (IsDigit(At(m + 1)) or (((At(m + 1) = '+') or (At(m + 1) = '-')) and IsDigit(At(m + 2)))) then
      begin
        Inc(m, 2);
        while IsDigit(At(m)) or (At(m) = '_') do Inc(m);
      end;
      if not (lang in [lnShell, lnConf]) then
        while IsWordChar(At(m)) do Inc(m);     { suffixes: 10UL, 1u32, 2.5f }
    end;
    if (lang in [lnShell, lnConf]) and
       (IsWordChar(At(m)) or (At(m) = '-') or ((At(i - 1) = '-') and IsWordChar(At(i - 2)))) then
    begin
      { 4b9dd8ec-8e67, utf-8 and the like are names, not numbers }
      while IsWordChar(At(m)) or (At(m) = '-') do Inc(m);
      i := m;
      Exit;
    end;
    Mark(i, m - 1, HC_NUMBER);
    i := m;
  end;

begin
  n := Length(s);
  if Length(cls) < n then SetLength(cls, n);
  for i := 0 to n - 1 do cls[i] := HC_TEXT;
  Result := 0;
  if lang = lnNone then Exit;
  kind := inState and 7;
  extra := inState shr 3;
  hashLang := lang in [lnPython, lnShell, lnConf];
  cLike := lang in [lnC, lnRust];
  lineStart := 1;
  while (lineStart <= n) and ((s[lineStart] = ' ') or (s[lineStart] = #9)) do Inc(lineStart);
  i := 1;
  depth := extra;

  { carry on from the previous line }
  if kind <> 0 then
  begin
    case kind of
      1:
        if lang = lnPascal then
        begin
          j := FindClose('}', 1);
          if j = 0 then begin Mark(1, n, HC_COMMENT); i := n + 1; end
          else begin Mark(1, j, HC_COMMENT); kind := 0; i := j + 1; end;
        end
        else BlockComment(1, lang = lnRust);
      2:
        begin
          j := FindClose('*)', 1);
          if j = 0 then begin Mark(1, n, HC_COMMENT); i := n + 1; end
          else begin Mark(1, j + 1, HC_COMMENT); kind := 0; i := j + 2; end;
        end;
      3:
        if lang = lnPython then
        begin
          if extra = 1 then w := '''''''' else w := '"""';
          j := 1;
          k := 0;
          while j <= n do
          begin
            if s[j] = '\' then Inc(j, 2)
            else if (Copy(s, j, 3) = UnicodeString(w)) then begin k := j; Break; end
            else Inc(j);
          end;
          if k = 0 then begin Mark(1, n, HC_STRING); i := n + 1; end
          else begin Mark(1, k + 2, HC_STRING); kind := 0; i := k + 3; end;
        end
        else
        begin
          j := ScanQuote('"', 1, True);
          if j = 0 then begin Mark(1, n, HC_STRING); i := n + 1; end
          else begin Mark(1, j, HC_STRING); kind := 0; i := j + 1; end;
        end;
      4:
        begin
          k := 0;
          for j := 1 to n do
            if s[j] = '"' then
            begin
              h := 0;
              while (h < extra) and (At(j + 1 + h) = '#') do Inc(h);
              if h = extra then begin k := j + extra; Break; end;
            end;
          if k = 0 then begin Mark(1, n, HC_STRING); i := n + 1; end
          else begin Mark(1, k, HC_STRING); kind := 0; i := k + 1; end;
        end;
    else
      kind := 0;
    end;
  end;

  while i <= n do
  begin
    c := s[i];
    if (c = ' ') or (c = #9) then begin Inc(i); Continue; end;

    { ---- comments ---- }
    if (lang in [lnPascal, lnC, lnRust]) and (c = '/') and (At(i + 1) = '/') then
    begin
      Mark(i, n, HC_COMMENT);
      i := n + 1;
      Break;
    end;
    if cLike and (c = '/') and (At(i + 1) = '*') then
    begin
      depth := 1;
      Mark(i, i + 1, HC_COMMENT);
      BlockComment(i + 2, lang = lnRust);
      Continue;
    end;
    if lang = lnPascal then
    begin
      if c = '{' then
      begin
        j := FindClose('}', i + 1);
        if At(i + 1) = '$' then
        begin
          if j = 0 then begin Mark(i, n, HC_PREPROC); kind := 1; i := n + 1; end
          else begin Mark(i, j, HC_PREPROC); i := j + 1; end;
        end
        else if j = 0 then begin Mark(i, n, HC_COMMENT); kind := 1; i := n + 1; end
        else begin Mark(i, j, HC_COMMENT); i := j + 1; end;
        Continue;
      end;
      if (c = '(') and (At(i + 1) = '*') then
      begin
        j := FindClose('*)', i + 2);
        if j = 0 then begin Mark(i, n, HC_COMMENT); kind := 2; i := n + 1; end
        else begin Mark(i, j + 1, HC_COMMENT); i := j + 2; end;
        Continue;
      end;
    end;
    if hashLang and (c = '#') and
       ((lang = lnPython) or (i = 1) or (i = lineStart) or
        (((s[i - 1] = ' ') or (s[i - 1] = #9)) and ((lang = lnShell) or (i = n) or (At(i + 1) = ' ') or (At(i + 1) = #9)))) then
    begin
      Mark(i, n, HC_COMMENT);
      i := n + 1;
      Break;
    end;
    if (lang = lnConf) and (c = ';') and (i = lineStart) then
    begin
      Mark(i, n, HC_COMMENT);
      i := n + 1;
      Break;
    end;

    { ---- config files: [section] and key = value ---- }
    if (lang = lnConf) and (i = lineStart) then
    begin
      if c = '[' then
      begin
        j := FindClose(']', i + 1);
        if j > 0 then
        begin
          Mark(i, j, HC_TYPE);
          i := j + 1;
          Continue;
        end;
      end
      else if IsWordStart(c) then
      begin
        j := i;
        while (j <= n) and (s[j] <> ' ') and (s[j] <> #9) and (s[j] <> '=') do Inc(j);
        k := j;
        while (k <= n) and ((s[k] = ' ') or (s[k] = #9)) do Inc(k);
        if At(k) = '=' then
        begin
          Mark(i, j - 1, HC_KEYWORD);
          i := j;
          Continue;
        end;
      end;
    end;

    { ---- C preprocessor ---- }
    if (lang = lnC) and (c = '#') and (i = lineStart) then
    begin
      j := i + 1;
      while (At(j) = ' ') or (At(j) = #9) do Inc(j);
      k := j;
      while IsWordChar(At(k)) do Inc(k);
      Mark(i, k - 1, HC_PREPROC);
      if AsciiWord(s, j, k - 1, False, w) and ((w = 'include') or (w = 'import')) then
      begin
        j := k;
        while (At(j) = ' ') or (At(j) = #9) do Inc(j);
        if At(j) = '<' then
        begin
          k := FindClose('>', j + 1);
          if k = 0 then k := n;
          Mark(j, k, HC_STRING);
          i := k + 1;
          Continue;
        end;
      end;
      i := k;
      Continue;
    end;

    { ---- strings and characters ---- }
    if lang = lnPascal then
    begin
      if c = '''' then
      begin
        j := ScanQuote('''', i + 1, False);
        if j = 0 then j := n;
        Mark(i, j, HC_STRING);
        i := j + 1;
        Continue;
      end;
      if (c = '#') and (IsDigit(At(i + 1)) or (At(i + 1) = '$')) then
      begin
        j := i + 1;
        if At(j) = '$' then Inc(j);
        while IsHex(At(j)) do Inc(j);
        Mark(i, j - 1, HC_STRING);
        i := j;
        Continue;
      end;
    end
    else if (c = '"') or (c = '''') then
    begin
      if lang = lnRust then
      begin
        if c = '"' then
        begin
          j := ScanQuote('"', i + 1, True);
          if j = 0 then begin Mark(i, n, HC_STRING); kind := 3; extra := 0; i := n + 1; end
          else begin Mark(i, j, HC_STRING); i := j + 1; end;
          Continue;
        end;
        { 'a is a lifetime, 'a' and '\n' are characters }
        if At(i + 1) = '\' then
        begin
          j := ScanQuote('''', i + 1, True);
          if j = 0 then j := n;
          Mark(i, j, HC_STRING);
          i := j + 1;
        end
        else if At(i + 2) = '''' then begin Mark(i, i + 2, HC_STRING); Inc(i, 3); end
        else if (At(i + 1) >= #$D800) and (At(i + 1) <= #$DBFF) and (At(i + 3) = '''') then
        begin
          Mark(i, i + 3, HC_STRING);
          Inc(i, 4);
        end
        else if IsWordStart(At(i + 1)) then
        begin
          j := i + 1;
          while IsWordChar(At(j)) do Inc(j);
          Mark(i, j - 1, HC_TYPE);
          i := j;
        end
        else Inc(i);
        Continue;
      end;
      if lang = lnPython then
      begin
        if (At(i + 1) = c) and (At(i + 2) = c) then
        begin
          k := 0;
          j := i + 3;
          while j <= n do
          begin
            if s[j] = '\' then Inc(j, 2)
            else if (At(j) = c) and (At(j + 1) = c) and (At(j + 2) = c) then begin k := j; Break; end
            else Inc(j);
          end;
          if k = 0 then
          begin
            Mark(i, n, HC_STRING);
            kind := 3;
            if c = '''' then extra := 1 else extra := 2;
            i := n + 1;
          end
          else begin Mark(i, k + 2, HC_STRING); i := k + 3; end;
          Continue;
        end;
        j := ScanQuote(c, i + 1, True);
        if j = 0 then j := n;
        Mark(i, j, HC_STRING);
        i := j + 1;
        Continue;
      end;
      if lang = lnC then
      begin
        j := ScanQuote(c, i + 1, True);
        if j = 0 then j := n;
        Mark(i, j, HC_STRING);
        i := j + 1;
        Continue;
      end;
      { shell and config files: only a quote that opens a word and has its partner on this line }
      if (i = 1) or not IsWordChar(s[i - 1]) then
      begin
        j := ScanQuote(c, i + 1, c = '"');
        if j > 0 then
        begin
          Mark(i, j, HC_STRING);
          i := j + 1;
          Continue;
        end;
      end;
      Inc(i);
      Continue;
    end;

    { ---- shell variables ---- }
    if (lang = lnShell) and (c = '$') then
    begin
      j := i + 1;
      if At(j) = '{' then
      begin
        k := FindClose('}', j + 1);
        if k = 0 then k := n;
        Mark(i, k, HC_TYPE);
        i := k + 1;
        Continue;
      end;
      if IsWordStart(At(j)) then
      begin
        while IsWordChar(At(j)) do Inc(j);
        Mark(i, j - 1, HC_TYPE);
        i := j;
        Continue;
      end;
      if IsDigit(At(j)) or (At(j) = '?') or (At(j) = '!') or (At(j) = '@') or (At(j) = '*') or (At(j) = '$') then
      begin
        Mark(i, j, HC_TYPE);      { $1 $? $@ $$ }
        i := j + 1;
        Continue;
      end;
      Inc(i);
      Continue;
    end;

    { ---- numbers ---- }
    if IsDigit(c) or ((lang = lnPascal) and (c = '$') and IsHex(At(i + 1))) then
    begin
      Number;
      Continue;
    end;

    { ---- words ---- }
    if IsWordStart(c) then
    begin
      { Rust raw strings: r"..", r#".."#, br#".."# }
      if (lang = lnRust) and ((c = 'r') or ((c = 'b') and (At(i + 1) = 'r'))) then
      begin
        j := i + 1;
        if c = 'b' then Inc(j);
        h := 0;
        while At(j) = '#' do begin Inc(h); Inc(j); end;
        if At(j) = '"' then
        begin
          q := j + 1;
          while q <= n do
          begin
            if s[q] = '"' then
            begin
              k := 0;
              while (k < h) and (At(q + 1 + k) = '#') do Inc(k);
              if k = h then Break;
            end;
            Inc(q);
          end;
          if q > n then
          begin
            Mark(i, n, HC_STRING);
            kind := 4;
            extra := h;
            i := n + 1;
          end
          else
          begin
            Mark(i, q + h, HC_STRING);
            i := q + h + 1;
          end;
          Continue;
        end;
      end;
      j := i;
      while IsWordChar(At(j)) do Inc(j);
      case lang of
        lnPascal:
          if AsciiWord(s, i, j - 1, True, w) then
          begin
            if InList(KW_PASCAL, w) then Mark(i, j - 1, HC_KEYWORD)
            else if InList(TY_PASCAL, w) then Mark(i, j - 1, HC_TYPE)
            else if (Length(w) > 2) and (w[1] = 't') and (s[i] = 'T') and
                    (s[i + 1] >= 'A') and (s[i + 1] <= 'Z') then Mark(i, j - 1, HC_TYPE);
          end
          else if (s[i] = 'T') and (j - i > 2) and (s[i + 1] >= 'A') and (s[i + 1] <= 'Z') then
            Mark(i, j - 1, HC_TYPE);
        lnC:
          if AsciiWord(s, i, j - 1, False, w) then
          begin
            if InList(KW_C, w) then Mark(i, j - 1, HC_KEYWORD)
            else if InList(TY_C, w) or ((Length(w) > 2) and (Copy(w, Length(w) - 1, 2) = '_t')) then
              Mark(i, j - 1, HC_TYPE);
          end;
        lnRust:
          if AsciiWord(s, i, j - 1, False, w) then
          begin
            if InList(KW_RUST, w) then Mark(i, j - 1, HC_KEYWORD)
            else if InList(TY_RUST, w) then Mark(i, j - 1, HC_TYPE)
            else if (At(j) = '!') and (At(j + 1) <> '=') then Mark(i, j, HC_PREPROC);
          end;
        lnPython:
          if AsciiWord(s, i, j - 1, False, w) then
          begin
            if InList(KW_PYTHON, w) then Mark(i, j - 1, HC_KEYWORD)
            else if InList(TY_PYTHON, w) then Mark(i, j - 1, HC_TYPE);
          end;
        lnShell:
          if AsciiWord(s, i, j - 1, False, w) then
          begin
            if InList(KW_SHELL, w) then Mark(i, j - 1, HC_KEYWORD)
            else if InList(TY_SHELL, w) then Mark(i, j - 1, HC_TYPE)
            else
            begin
              k := j;
              if (i = lineStart) and (At(k) = '=') then Mark(i, j - 1, HC_TYPE);
            end;
          end;
        lnConf:
          if AsciiWord(s, i, j - 1, True, w) and InList(KW_CONF, w) then Mark(i, j - 1, HC_KEYWORD);
      end;
      i := j;
      Continue;
    end;

    Inc(i);
  end;
  if kind = 0 then extra := 0;
  if extra > 8191 then extra := 8191;
  Result := Word(kind or (extra shl 3));
end;

end.
