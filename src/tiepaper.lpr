{ TiePaper - a modern take on the PaperClip II word processor.

  tiepaper [file]                           start the editor
  tiepaper --pdf in out.pdf               format a document to PDF, no window
  tiepaper --text in out.txt              format a document to plain text, no window
  tiepaper --script commands.txt [file]   run scripted keystrokes (used by the tests)
  tiepaper --version | --help }
program tiepaper;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$APPTYPE GUI}{$ENDIF}
{$R ../assets/tiepaper.res}  { the icon: exe icon on Windows, window icon everywhere }

uses
  {$IFDEF UNIX}cwstring,{$ENDIF}
  {$IFDEF WINDOWS}Windows,{$ENDIF}
  SysUtils, Classes, pcdoc, pcfmt, pcout, pcconfig, pcsdl, pcspell, pcapp;

const
  Version = '0.1';

type
  TCli = class
    BaseDir: string;
    function Load(const name: string; var paras: TStrArray): Boolean;
  end;

function TCli.Load(const name: string; var paras: TStrArray): Boolean;
var
  t: TDoc;
  fn: string;
  i: Integer;
begin
  Result := False;
  fn := name;
  if not FileExists(fn) then fn := BaseDir + name;
  if not FileExists(fn) then Exit;
  t := TDoc.Create;
  try
    if t.LoadFromFile(fn) <> '' then Exit;
    SetLength(paras, t.Count);
    for i := 0 to t.Count - 1 do paras[i] := t[i];
    Result := True;
  finally
    t.Free;
  end;
end;

{$IFDEF WINDOWS}
function AttachConsole(pid: LongWord): LongBool; stdcall; external 'kernel32.dll' name 'AttachConsole';

var
  ConsoleTried: Boolean = False;
  ConsoleOK: Boolean = False;
{$ENDIF}

{ The Windows exe has no console of its own; borrow the one it was started from. }
procedure Say(const s: string);
begin
  {$IFDEF WINDOWS}
  if not ConsoleTried then
  begin
    ConsoleTried := True;
    if AttachConsole(LongWord(-1)) then
    begin
      AssignFile(Output, 'CONOUT$');
      {$I-}
      Rewrite(Output);
      {$I+}
      ConsoleOK := IOResult = 0;
    end;
  end;
  { with no console at all (or redirected output) writing may fail; that is fine }
  {$I-}
  WriteLn(s);
  {$I+}
  if IOResult <> 0 then ConsoleOK := False;
  {$ELSE}
  WriteLn(s);
  {$ENDIF}
end;

function Export(const inFile, outFile: string; pdf: Boolean): Integer;
var
  d: TDoc;
  f: TFormatter;
  cli: TCli;
  paras: TStrArray;
  i: Integer;
  err: string;
  s: TSettings;
begin
  Result := 1;
  d := TDoc.Create;
  f := TFormatter.Create;
  cli := TCli.Create;
  try
    err := d.LoadFromFile(inFile);
    if err <> '' then begin Say('Cannot read ' + inFile + ': ' + err); Exit; end;
    cli.BaseDir := ExtractFilePath(ExpandFileName(inFile));
    SetLength(paras, d.Count);
    for i := 0 to d.Count - 1 do paras[i] := d[i];
    MigrateOldConfig;
    LoadSettings(s, ConfigFile('tiepaper.ini'));
    f.DefaultPaperLines := PaperLinesFor(TPaperSize(s.Paper));
    f.Loader := @cli.Load;
    f.Run(paras);
    for i := 0 to f.Warnings.Count - 1 do Say('warning: ' + f.Warnings[i]);
    if pdf then err := WritePDF(f, outFile, TPaperSize(s.Paper), 1, 0)
    else err := WritePlainText(f, outFile, 1, 0);
    if err <> '' then begin Say(err); Exit; end;
    Say(Format('%s: %d page(s)', [outFile, f.PageCount]));
    Result := 0;
  finally
    cli.Free;
    f.Free;
    d.Free;
  end;
end;

{ tiepaper --spell word ...   checks words with the system spell checker (a quick way to see it works) }
function SpellTest(firstWord: Integer): Integer;
var
  sp: TSpeller;
  err, line: string;
  i, k: Integer;
  sugg: TStringList;
begin
  sp := CreateSpeller('', err);
  if sp = nil then begin Say(err); Exit(1); end;
  sugg := TStringList.Create;
  try
    Say('using ' + sp.Description);
    for i := firstWord to ParamCount do
    begin
      sugg.Clear;
      if sp.Check(UTF8Decode(ParamStr(i)), sugg) then Say(ParamStr(i) + ': ok')
      else
      begin
        line := ParamStr(i) + ': misspelled';
        for k := 0 to sugg.Count - 1 do line := line + ' | ' + sugg[k];
        Say(line);
      end;
    end;
  finally
    sugg.Free;
    sp.Free;
  end;
  Result := 0;
end;

var
  app: TApp;
  err, arg, file_, scriptFile: string;
  i: Integer;

begin
  {$IFDEF WINDOWS}
  SetMultiByteConversionCodePage(CP_UTF8);
  SetMultiByteRTLFileSystemCodePage(CP_UTF8);
  DefaultSystemCodePage := CP_UTF8;
  {$ENDIF}
  file_ := '';
  scriptFile := '';
  i := 1;
  while i <= ParamCount do
  begin
    arg := ParamStr(i);
    if (arg = '--version') or (arg = '-v') then
    begin
      Say('TiePaper ' + Version);
      Halt(0);
    end
    else if (arg = '--help') or (arg = '-h') then
    begin
      Say('TiePaper ' + Version);
      Say('  tiepaper [file]');
      Say('  tiepaper --pdf in out.pdf');
      Say('  tiepaper --text in out.txt');
      Halt(0);
    end
    else if (arg = '--pdf') and (i + 2 <= ParamCount) then
      Halt(Export(ParamStr(i + 1), ParamStr(i + 2), True))
    else if (arg = '--text') and (i + 2 <= ParamCount) then
      Halt(Export(ParamStr(i + 1), ParamStr(i + 2), False))
    else if (arg = '--spell') and (i + 1 <= ParamCount) then
      Halt(SpellTest(i + 1))
    else if (arg = '--script') and (i + 1 <= ParamCount) then
    begin
      scriptFile := ParamStr(i + 1);
      Inc(i);
    end
    else if (Length(arg) > 0) and (arg[1] <> '-') then
      file_ := arg;
    Inc(i);
  end;

  app := TApp.Create;
  try
    err := app.Start(file_);
    if err <> '' then
    begin
      {$IFDEF WINDOWS}
      MessageBoxA(0, PAnsiChar(err), 'TiePaper', 0);
      {$ELSE}
      WriteLn(StdErr, 'TiePaper: ', err);
      {$ENDIF}
      Halt(1);
    end;
    if scriptFile <> '' then app.SetScript(scriptFile);
    app.Run;
  finally
    app.Free;
  end;
end.
