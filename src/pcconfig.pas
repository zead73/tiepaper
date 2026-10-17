{ pcconfig - settings, the C64 palette, and where things live on disk. }
unit pcconfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, IniFiles;

const
  { Colodore C64 palette }
  Palette: array[0..15] of LongWord = (
    $000000, $FFFFFF, $813338, $75CEC8, $8E3C97, $56AC4D, $2E2C9B, $EDF171,
    $8E5029, $553800, $C46C71, $4A4A4A, $7B7B7B, $A9FF9F, $706DEB, $B2B2B2);
  PaletteNames: array[0..15] of string = (
    'Black', 'White', 'Red', 'Cyan', 'Purple', 'Green', 'Blue', 'Yellow',
    'Orange', 'Brown', 'L Red', 'D Gray', 'Gray', 'L Green', 'L Blue', 'L Gray');

  { preview colours for each combination of print enhancements, in the manual's order }
  PREV_BOLD = 0;
  PREV_UL = 1;
  PREV_BOLD_UL = 2;
  PREV_IT = 3;
  PREV_BOLD_IT = 4;
  PREV_UL_IT = 5;
  PREV_ALL = 6;

type
  TSettings = record
    ColText, ColBack, ColBorder: Integer;
    ColPrev: array[0..6] of Integer;
    ColDirective, ColMarker, ColReturn: Integer;
    FontSize: Integer;
    FontFamily: string;          { file prefix, e.g. LiberationMono }
    FontDir: string;             { empty = look in the usual places }
    ShowReturn: Boolean;
    WrapView: Boolean;
    Paper: Integer;              { 0 = Letter, 1 = A4 }
    WinW, WinH: Integer;
    LastDir: string;
    SpellLang: string;           { '' = the system's language }
  end;

procedure DefaultSettings(var s: TSettings);
function ConfigDir: string;
function ConfigFile(const name: string): string;
procedure LoadSettings(var s: TSettings; const fn: string);
procedure MigrateOldConfig;
procedure SaveSettings(const s: TSettings; const fn: string);
function FindFontFile(const s: TSettings; const style: string): string;   { style: Regular, Bold, ... }
function AppDir: string;
function PrevIndex(bold, ul, ital: Boolean): Integer;     { -1 for none }

implementation

procedure DefaultSettings(var s: TSettings);
begin
  s.ColText := 15;
  s.ColBack := 6;
  s.ColBorder := 14;
  s.ColPrev[PREV_BOLD] := 1;
  s.ColPrev[PREV_UL] := 15;
  s.ColPrev[PREV_BOLD_UL] := 1;
  s.ColPrev[PREV_IT] := 15;
  s.ColPrev[PREV_BOLD_IT] := 1;
  s.ColPrev[PREV_UL_IT] := 15;
  s.ColPrev[PREV_ALL] := 1;
  s.ColDirective := 7;
  s.ColMarker := 3;
  s.ColReturn := 12;
  s.FontSize := 20;
  s.FontFamily := 'LiberationMono';
  s.FontDir := '';
  s.ShowReturn := True;
  s.WrapView := True;
  s.Paper := 0;
  s.WinW := 1100;
  s.WinH := 760;
  s.LastDir := '';
  s.SpellLang := '';
end;

function AppDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

function ConfigDir: string;
begin
  Result := GetAppConfigDir(False);
end;

{ the config folder is always named tiepaper, whatever the executable is called }
function AppName: string;
begin
  Result := 'tiepaper';
end;

{ Before the program was renamed its settings lived in a folder called paperclip.  The first run
  under the new name copies them across (the old file is left where it is). }
procedure MigrateOldConfig;
var
  oldDir, oldFile, newFile: string;
  src, dst: TFileStream;
begin
  newFile := ConfigFile('tiepaper.ini');
  if FileExists(newFile) then Exit;
  oldDir := ExtractFilePath(ExcludeTrailingPathDelimiter(ConfigDir)) + 'paperclip' + PathDelim;
  oldFile := oldDir + 'paperclip.ini';
  if not FileExists(oldFile) then Exit;
  try
    ForceDirectories(ExtractFilePath(newFile));
    src := TFileStream.Create(oldFile, fmOpenRead or fmShareDenyWrite);
    try
      dst := TFileStream.Create(newFile, fmCreate);
      try
        dst.CopyFrom(src, 0);
      finally
        dst.Free;
      end;
    finally
      src.Free;
    end;
  except
    { nothing to migrate if the old file cannot be read; defaults apply }
  end;
end;

function ConfigFile(const name: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ConfigDir) + name;
end;

function PrevIndex(bold, ul, ital: Boolean): Integer;
begin
  Result := -1;
  if bold and (not ul) and (not ital) then Result := PREV_BOLD
  else if ul and (not bold) and (not ital) then Result := PREV_UL
  else if bold and ul and (not ital) then Result := PREV_BOLD_UL
  else if ital and (not bold) and (not ul) then Result := PREV_IT
  else if bold and ital and (not ul) then Result := PREV_BOLD_IT
  else if ul and ital and (not bold) then Result := PREV_UL_IT
  else if bold and ul and ital then Result := PREV_ALL;
end;

function Clamp(v, lo, hi: Integer): Integer;
begin
  if v < lo then Result := lo else if v > hi then Result := hi else Result := v;
end;

procedure LoadSettings(var s: TSettings; const fn: string);
var
  ini: TIniFile;
  i: Integer;
begin
  DefaultSettings(s);
  if not FileExists(fn) then Exit;
  ini := TIniFile.Create(fn);
  try
    s.ColText := Clamp(ini.ReadInteger('colors', 'text', s.ColText), 0, 15);
    s.ColBack := Clamp(ini.ReadInteger('colors', 'background', s.ColBack), 0, 15);
    s.ColBorder := Clamp(ini.ReadInteger('colors', 'border', s.ColBorder), 0, 15);
    for i := 0 to 6 do
      s.ColPrev[i] := Clamp(ini.ReadInteger('colors', 'preview' + IntToStr(i), s.ColPrev[i]), 0, 15);
    s.ColDirective := Clamp(ini.ReadInteger('colors', 'directive', s.ColDirective), 0, 15);
    s.ColMarker := Clamp(ini.ReadInteger('colors', 'marker', s.ColMarker), 0, 15);
    s.ColReturn := Clamp(ini.ReadInteger('colors', 'return', s.ColReturn), 0, 15);
    s.FontSize := Clamp(ini.ReadInteger('display', 'fontsize', s.FontSize), 8, 72);
    s.FontFamily := ini.ReadString('display', 'fontfamily', s.FontFamily);
    s.FontDir := ini.ReadString('display', 'fontdir', s.FontDir);
    s.ShowReturn := ini.ReadBool('display', 'showreturn', s.ShowReturn);
    s.WrapView := ini.ReadBool('display', 'wrap', s.WrapView);
    s.Paper := Clamp(ini.ReadInteger('output', 'paper', s.Paper), 0, 1);
    s.WinW := Clamp(ini.ReadInteger('window', 'width', s.WinW), 400, 8000);
    s.WinH := Clamp(ini.ReadInteger('window', 'height', s.WinH), 300, 6000);
    s.LastDir := ini.ReadString('files', 'lastdir', s.LastDir);
    s.SpellLang := ini.ReadString('spelling', 'language', s.SpellLang);
  finally
    ini.Free;
  end;
end;

procedure SaveSettings(const s: TSettings; const fn: string);
var
  ini: TIniFile;
  i: Integer;
begin
  ForceDirectories(ExtractFilePath(fn));
  ini := TIniFile.Create(fn);
  try
    ini.WriteInteger('colors', 'text', s.ColText);
    ini.WriteInteger('colors', 'background', s.ColBack);
    ini.WriteInteger('colors', 'border', s.ColBorder);
    for i := 0 to 6 do ini.WriteInteger('colors', 'preview' + IntToStr(i), s.ColPrev[i]);
    ini.WriteInteger('colors', 'directive', s.ColDirective);
    ini.WriteInteger('colors', 'marker', s.ColMarker);
    ini.WriteInteger('colors', 'return', s.ColReturn);
    ini.WriteInteger('display', 'fontsize', s.FontSize);
    ini.WriteString('display', 'fontfamily', s.FontFamily);
    ini.WriteString('display', 'fontdir', s.FontDir);
    ini.WriteBool('display', 'showreturn', s.ShowReturn);
    ini.WriteBool('display', 'wrap', s.WrapView);
    ini.WriteInteger('output', 'paper', s.Paper);
    ini.WriteInteger('window', 'width', s.WinW);
    ini.WriteInteger('window', 'height', s.WinH);
    ini.WriteString('files', 'lastdir', s.LastDir);
    ini.WriteString('spelling', 'language', s.SpellLang);
  finally
    ini.Free;
  end;
end;

function FindFontFile(const s: TSettings; const style: string): string;
var
  dirs: array of string;
  fams: array of string;
  d, f: Integer;
  cand: string;

  procedure AddDir(const x: string);
  begin
    SetLength(dirs, Length(dirs) + 1);
    dirs[High(dirs)] := IncludeTrailingPathDelimiter(x);
  end;

  procedure AddFam(const x: string);
  begin
    SetLength(fams, Length(fams) + 1);
    fams[High(fams)] := x;
  end;

begin
  SetLength(dirs, 0);
  SetLength(fams, 0);
  if s.FontDir <> '' then AddDir(s.FontDir);
  AddDir(AppDir + 'fonts');
  AddDir(AppDir + '..' + PathDelim + 'fonts');
  AddDir(ConfigDir + 'fonts');
  {$IFDEF WINDOWS}
  AddDir('C:\Windows\Fonts');
  {$ELSE}
  AddDir('/usr/share/fonts/liberation');
  AddDir('/usr/share/fonts/liberation-fonts');
  AddDir('/usr/share/fonts/truetype/liberation');
  AddDir('/usr/share/fonts/TTF');
  AddDir('/usr/share/fonts/truetype/dejavu');
  {$ENDIF}
  AddFam(s.FontFamily);
  AddFam('LiberationMono');
  AddFam('DejaVuSansMono');
  for f := 0 to High(fams) do
    for d := 0 to High(dirs) do
    begin
      if style = 'Regular' then
      begin
        cand := dirs[d] + fams[f] + '-Regular.ttf';
        if FileExists(cand) then Exit(cand);
        cand := dirs[d] + fams[f] + '.ttf';
        if FileExists(cand) then Exit(cand);
      end
      else
      begin
        cand := dirs[d] + fams[f] + '-' + style + '.ttf';
        if FileExists(cand) then Exit(cand);
        if style = 'Bold' then
        begin
          cand := dirs[d] + fams[f] + '-Bold.ttf';
          if FileExists(cand) then Exit(cand);
        end;
      end;
    end;
  Result := '';
end;

initialization
  OnGetApplicationName := @AppName;
end.
