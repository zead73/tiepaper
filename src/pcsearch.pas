{ pcsearch - TiePaper search strings.

  Special characters (from the PaperClip II manual):
    .   any character
    ?   any alphabetic character
    [   only at the beginning of a word
    ]   only at the end of a word
    '   the next character must match exactly, case included, and is not special
  Matching ignores case unless a character is quoted with '.  A search never
  spans a return marker. }
unit pcsearch;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Character;

type
  TPatKind = (pkChar, pkAny, pkAlpha, pkWordStart, pkWordEnd);
  TPatItem = record
    Kind: TPatKind;
    Ch: WideChar;
    Exact: Boolean;
  end;
  TPattern = array of TPatItem;

function CompilePattern(const s: UnicodeString): TPattern;
{ Finds the first match at or after position start (0-based) in text.  pos/len are 0-based. }
function FindIn(const pat: TPattern; const text: UnicodeString; start: Integer;
  out pos, len: Integer): Boolean;
function MatchAt(const pat: TPattern; const text: UnicodeString; at: Integer; out len: Integer): Boolean;

implementation

function IsWordCh(ch: WideChar): Boolean;
begin
  Result := TCharacter.IsLetterOrDigit(ch) or (ch = '_');
end;

function CompilePattern(const s: UnicodeString): TPattern;
var
  i, n: Integer;
begin
  SetLength(Result, 0);
  i := 1;
  while i <= Length(s) do
  begin
    n := Length(Result);
    SetLength(Result, n + 1);
    Result[n].Exact := False;
    Result[n].Ch := s[i];
    case s[i] of
      '.': Result[n].Kind := pkAny;
      '?': Result[n].Kind := pkAlpha;
      '[': Result[n].Kind := pkWordStart;
      ']': Result[n].Kind := pkWordEnd;
      '''':
        begin
          Result[n].Kind := pkChar;
          Result[n].Exact := True;
          if i < Length(s) then
          begin
            Inc(i);
            Result[n].Ch := s[i];
          end
          else
            Result[n].Ch := '''';
        end;
    else
      Result[n].Kind := pkChar;
    end;
    Inc(i);
  end;
end;

function MatchAt(const pat: TPattern; const text: UnicodeString; at: Integer; out len: Integer): Boolean;
var
  k, t: Integer;
  ch: WideChar;
begin
  t := at;
  for k := 0 to High(pat) do
  begin
    case pat[k].Kind of
      pkWordStart:
        begin
          if (t > 0) and IsWordCh(text[t]) then Exit(False);
        end;
      pkWordEnd:
        begin
          if (t < Length(text)) and IsWordCh(text[t + 1]) then Exit(False);
          if (t = 0) then Exit(False);
        end;
    else
      begin
        if t >= Length(text) then Exit(False);
        ch := text[t + 1];
        case pat[k].Kind of
          pkAny: ;
          pkAlpha: if not TCharacter.IsLetter(ch) then Exit(False);
          pkChar:
            if pat[k].Exact then
            begin
              if ch <> pat[k].Ch then Exit(False);
            end
            else if TCharacter.ToLower(ch) <> TCharacter.ToLower(pat[k].Ch) then Exit(False);
        end;
        Inc(t);
      end;
    end;
  end;
  len := t - at;
  Result := True;
end;

function FindIn(const pat: TPattern; const text: UnicodeString; start: Integer;
  out pos, len: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  if Length(pat) = 0 then Exit;
  for i := start to Length(text) do
    if MatchAt(pat, text, i, len) then
    begin
      pos := i;
      Exit(True);
    end;
end;

end.
