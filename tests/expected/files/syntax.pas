{$mode objfpc}{$H+}
program Demo;

{ A brace comment
  over two lines }
uses
  SysUtils, Classes;

type
  TShape = class
    Name: string;
    procedure Draw(n: Integer); virtual;
  end;

(* old style
   comment *)
const
  Limit = $FF;     // hex
  Pi2 = 6.28e0;
  Msg = 'don''t panic'#13#10;

procedure TShape.Draw(n: Integer);
var
  i: Integer;
begin
  for i := 1 to n do
    WriteLn('x', i);   { trailing }
end;

begin
  if Limit > 10 then WriteLn(Msg);
end.
 // edited
