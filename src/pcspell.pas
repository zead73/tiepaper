{ pcspell - spell checking through the operating system's own checker.

  Windows: the built-in spell checker (ISpellChecker, Windows 8 and later).
  Linux:   whichever of hunspell, aspell or enchant is installed, talked to over the
           "ispell -a" pipe protocol they all understand.  Nothing is bundled; add
           words go to the checker's own personal dictionary.

  ScanWords finds the words to check in a document: letters only, apostrophes kept,
  format lines skipped, print marks looked through, words with digits and ALL-CAPS
  words (acronyms) left alone. }
unit pcspell;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Character, pcdoc;

type
  TSpeller = class
  public
    { word is checked as-is; sugg (may be nil) receives UTF-8 suggestions when it is wrong }
    function Check(const word: UnicodeString; sugg: TStringList): Boolean; virtual; abstract;
    procedure AddWord(const word: UnicodeString); virtual; abstract;      { to the personal dictionary }
    procedure IgnoreWord(const word: UnicodeString); virtual; abstract;   { for this session }
    function Description: string; virtual; abstract;
  end;

  THit = record
    P, C1, C2: Integer;          { paragraph, first character, one past the last }
    Word: UnicodeString;
  end;
  THitArray = array of THit;

{ Returns nil and a message in err when no checker can be started. lang may be '' for the system's. }
function CreateSpeller(const lang: string; out err: string): TSpeller;
procedure ScanWords(d: TDoc; fromP: Integer; var hits: THitArray);
function IsAcronym(const w: UnicodeString): Boolean;

implementation

uses
  {$IFDEF WINDOWS}Windows, ActiveX,{$ELSE}Process,{$ENDIF}
  StrUtils;

function IsAcronym(const w: UnicodeString): Boolean;
var
  i, letters: Integer;
begin
  letters := 0;
  for i := 1 to Length(w) do
    if TCharacter.IsLetter(w[i]) then
    begin
      Inc(letters);
      if not TCharacter.IsUpper(w[i]) then Exit(False);
    end;
  Result := letters >= 2;
end;

procedure ScanWords(d: TDoc; fromP: Integer; var hits: THitArray);
var
  p, i, n, st, cnt: Integer;
  s, w: UnicodeString;
  prevDigit, nextDigit: Boolean;

  function Letter(k: Integer): Boolean;
  begin
    Result := (k >= 1) and (k <= n) and TCharacter.IsLetter(s[k]);
  end;

  function Digit(k: Integer): Boolean;
  begin
    Result := (k >= 1) and (k <= n) and (s[k] >= '0') and (s[k] <= '9');
  end;

begin
  SetLength(hits, 0);
  cnt := 0;
  if fromP < 0 then fromP := 0;
  for p := fromP to d.Count - 1 do
  begin
    s := d[p];
    if IsFormatLine(s) then Continue;
    n := Length(s);
    i := 1;
    while i <= n do
    begin
      if not Letter(i) then
      begin
        Inc(i);
        Continue;
      end;
      st := i;
      w := '';
      while i <= n do
      begin
        if Letter(i) then
        begin
          w := w + s[i];
          Inc(i);
        end
        else if ((s[i] = '''') or (s[i] = #$2019)) and Letter(i + 1) and (w <> '') then
        begin
          w := w + '''';
          Inc(i);
        end
        else if (IsMarkerChar(s[i]) or (s[i] = CH_SHY)) and Letter(i + 1) and (w <> '') then
          Inc(i)                                     { a print mark in the middle of a word }
        else
          Break;
      end;
      prevDigit := Digit(st - 1);
      nextDigit := Digit(i);
      if (Length(w) >= 2) and (not prevDigit) and (not nextDigit) and (not IsAcronym(w)) then
      begin
        if cnt >= Length(hits) then SetLength(hits, cnt * 2 + 16);
        hits[cnt].P := p;
        hits[cnt].C1 := st - 1;
        hits[cnt].C2 := i - 1;
        hits[cnt].Word := w;
        Inc(cnt);
      end;
    end;
  end;
  SetLength(hits, cnt);
end;

{$IFDEF WINDOWS}

{ ---- Windows: ISpellChecker, declared from spellcheck.h ---- }

type
  IEnumSpellingError = interface(IUnknown)
    ['{803E3BD4-2828-4410-8290-418D1D73C762}']
    function Next(out error: IUnknown): HResult; stdcall;
  end;

  ISpellChecker = interface(IUnknown)
    ['{B6FD0B71-E2BC-4653-8D05-F197E412770B}']
    function get_LanguageTag(out val: PWideChar): HResult; stdcall;
    function Check(text: PWideChar; out errors: IEnumSpellingError): HResult; stdcall;
    function Suggest(word: PWideChar; out sugg: IEnumString): HResult; stdcall;
    function Add(word: PWideChar): HResult; stdcall;
    function Ignore(word: PWideChar): HResult; stdcall;
  end;

  ISpellCheckerFactory = interface(IUnknown)
    ['{8E018A9D-2415-4677-BF08-794EA61F94BB}']
    function get_SupportedLanguages(out val: IEnumString): HResult; stdcall;
    function IsSupported(languageTag: PWideChar; out val: LongBool): HResult; stdcall;
    function CreateSpellChecker(languageTag: PWideChar; out val: ISpellChecker): HResult; stdcall;
  end;

const
  CLSID_SpellCheckerFactory: TGUID = '{7AB36653-1796-484B-BDFA-E74F1DB7C1DC}';

function GetUserDefaultLocaleName(lpLocaleName: PWideChar; cchLocaleName: LongInt): LongInt;
  stdcall; external 'kernel32.dll' name 'GetUserDefaultLocaleName';

type
  TComSpeller = class(TSpeller)
  private
    FFactory: ISpellCheckerFactory;
    FChecker: ISpellChecker;
    FTag: string;
  public
    function Open(const lang: string; out err: string): Boolean;
    function Check(const word: UnicodeString; sugg: TStringList): Boolean; override;
    procedure AddWord(const word: UnicodeString); override;
    procedure IgnoreWord(const word: UnicodeString); override;
    function Description: string; override;
    destructor Destroy; override;
  end;

function TComSpeller.Open(const lang: string; out err: string): Boolean;
var
  hr: HResult;
  tags: array[0..2] of UnicodeString;
  buf: array[0..84] of WideChar;
  i: Integer;
  ok: LongBool;
begin
  Result := False;
  err := '';
  CoInitialize(nil);
  hr := CoCreateInstance(CLSID_SpellCheckerFactory, nil, CLSCTX_INPROC_SERVER,
    ISpellCheckerFactory, FFactory);
  if hr <> S_OK then
  begin
    err := 'The Windows spell checker is not available (it needs Windows 8 or later with a language installed)';
    Exit;
  end;
  if lang <> '' then tags[0] := UTF8Decode(lang)
  else
  begin
    FillChar(buf, SizeOf(buf), 0);
    if GetUserDefaultLocaleName(@buf[0], 85) > 0 then tags[0] := buf else tags[0] := 'en-US';
  end;
  tags[1] := Copy(tags[0], 1, Pos('-', tags[0] + '-') - 1);
  tags[2] := 'en-US';
  for i := 0 to 2 do
  begin
    ok := False;
    if (tags[i] <> '') and (FFactory.IsSupported(PWideChar(tags[i]), ok) = S_OK) and ok then
      if FFactory.CreateSpellChecker(PWideChar(tags[i]), FChecker) = S_OK then
      begin
        FTag := UTF8Encode(tags[i]);
        Exit(True);
      end;
  end;
  err := 'The Windows spell checker has no dictionary for ' + UTF8Encode(tags[0]);
end;

function TComSpeller.Check(const word: UnicodeString; sugg: TStringList): Boolean;
var
  errs: IEnumSpellingError;
  e: IUnknown;
  en: IEnumString;
  p: PWideChar;
  fetched: LongWord;
begin
  Result := True;
  errs := nil;
  if FChecker.Check(PWideChar(word), errs) <> S_OK then Exit;
  e := nil;
  if errs.Next(e) <> S_OK then Exit;           { no error reported }
  Result := False;
  if sugg <> nil then
  begin
    en := nil;
    if FChecker.Suggest(PWideChar(word), en) = S_OK then
      while (sugg.Count < 9) and (en.Next(1, p, fetched) = S_OK) do
      begin
        sugg.Add(UTF8Encode(UnicodeString(p)));
        CoTaskMemFree(p);
      end;
  end;
end;

procedure TComSpeller.AddWord(const word: UnicodeString);
begin
  FChecker.Add(PWideChar(word));
end;

procedure TComSpeller.IgnoreWord(const word: UnicodeString);
begin
  FChecker.Ignore(PWideChar(word));
end;

function TComSpeller.Description: string;
begin
  Result := 'Windows spell checker (' + FTag + ')';
end;

destructor TComSpeller.Destroy;
begin
  FChecker := nil;
  FFactory := nil;
  inherited Destroy;
end;

function CreateSpeller(const lang: string; out err: string): TSpeller;
var
  s: TComSpeller;
begin
  s := TComSpeller.Create;
  if s.Open(lang, err) then Exit(s);
  s.Free;
  Result := nil;
end;

{$ELSE}

{ ---- Linux: hunspell / aspell / enchant over the ispell pipe protocol ---- }

type
  TPipeSpeller = class(TSpeller)
  private
    FProc: TProcess;
    FName: string;
    function ReadLine(out line: string): Boolean;
    procedure SendLine(const s: string);
  public
    function Open(const lang: string; out err: string): Boolean;
    function Check(const word: UnicodeString; sugg: TStringList): Boolean; override;
    procedure AddWord(const word: UnicodeString); override;
    procedure IgnoreWord(const word: UnicodeString); override;
    function Description: string; override;
    destructor Destroy; override;
  end;

function TPipeSpeller.ReadLine(out line: string): Boolean;
var
  c: Char;
  n: LongInt;
begin
  line := '';
  Result := False;
  repeat
    n := FProc.Output.Read(c, 1);
    if n <= 0 then Exit(line <> '');
    Result := True;
    if c = #10 then Exit;
    if c <> #13 then line := line + c;
  until False;
end;

procedure TPipeSpeller.SendLine(const s: string);
var
  t: string;
begin
  t := s + #10;
  FProc.Input.Write(t[1], Length(t));
end;

function TPipeSpeller.Open(const lang: string; out err: string): Boolean;
const
  Names: array[0..3] of string = ('hunspell', 'aspell', 'enchant-2', 'enchant');
var
  i: Integer;
  exe, banner: string;
begin
  Result := False;
  err := '';
  exe := '';
  for i := 0 to High(Names) do
  begin
    exe := ExeSearch(Names[i], GetEnvironmentVariable('PATH'));
    if exe <> '' then
    begin
      FName := Names[i];
      Break;
    end;
  end;
  if exe = '' then
  begin
    err := 'No spell checker found: install hunspell (and a dictionary), aspell or enchant';
    Exit;
  end;
  FProc := TProcess.Create(nil);
  FProc.Executable := exe;
  FProc.Parameters.Add('-a');
  if FName = 'hunspell' then
  begin
    FProc.Parameters.Add('-i');
    FProc.Parameters.Add('utf-8');
    if lang <> '' then begin FProc.Parameters.Add('-d'); FProc.Parameters.Add(lang); end;
  end
  else if FName = 'aspell' then
  begin
    FProc.Parameters.Add('--encoding=utf-8');
    if lang <> '' then begin FProc.Parameters.Add('-l'); FProc.Parameters.Add(lang); end;
  end
  else if lang <> '' then
  begin
    FProc.Parameters.Add('-d');
    FProc.Parameters.Add(lang);
  end;
  FProc.Options := [poUsePipes, poStderrToOutput];
  try
    FProc.Execute;
  except
    on e: Exception do
    begin
      err := 'Cannot start ' + FName + ': ' + e.Message;
      Exit;
    end;
  end;
  if (not ReadLine(banner)) or (Copy(banner, 1, 1) <> '@') then
  begin
    err := FName + ' did not start properly' + IfThen(banner <> '', ': ' + banner, ' (is a dictionary installed for ' +
      IfThen(lang <> '', lang, 'your language') + '?)');
    Exit;
  end;
  Result := True;
end;

function TPipeSpeller.Check(const word: UnicodeString; sugg: TStringList): Boolean;
var
  line, rest: string;
  p: Integer;
  parts: TStringList;
  i: Integer;
begin
  Result := True;
  SendLine('^' + UTF8Encode(word));
  { the answer is one line followed by an empty line }
  if not ReadLine(line) then Exit;
  if line <> '' then
  begin
    case line[1] of
      '*', '+', '-': Result := True;
      '&', '?', '#':
        begin
          Result := False;
          if (sugg <> nil) and (line[1] <> '#') then
          begin
            p := Pos(': ', line);
            if p > 0 then
            begin
              rest := Copy(line, p + 2, MaxInt);
              parts := TStringList.Create;
              try
                parts.Delimiter := ',';
                parts.StrictDelimiter := True;
                parts.DelimitedText := rest;
                for i := 0 to parts.Count - 1 do
                  if (Trim(parts[i]) <> '') and (sugg.Count < 9) then sugg.Add(Trim(parts[i]));
              finally
                parts.Free;
              end;
            end;
          end;
        end;
    end;
    { swallow the blank line that ends the answer }
    ReadLine(rest);
  end;
end;

procedure TPipeSpeller.AddWord(const word: UnicodeString);
begin
  SendLine('*' + UTF8Encode(word));
  SendLine('#');                                   { save the personal dictionary }
end;

procedure TPipeSpeller.IgnoreWord(const word: UnicodeString);
begin
  SendLine('@' + UTF8Encode(word));
end;

function TPipeSpeller.Description: string;
begin
  Result := FName;
end;

destructor TPipeSpeller.Destroy;
begin
  if FProc <> nil then
  begin
    try
      FProc.CloseInput;
      FProc.Terminate(0);
    except
    end;
    FProc.Free;
  end;
  inherited Destroy;
end;

function CreateSpeller(const lang: string; out err: string): TSpeller;
var
  s: TPipeSpeller;
begin
  s := TPipeSpeller.Create;
  if s.Open(lang, err) then Exit(s);
  s.Free;
  Result := nil;
end;

{$ENDIF}

end.
