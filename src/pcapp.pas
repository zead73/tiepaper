{ pcapp - the TiePaper editor application.

  One class holds the whole interactive program.  Its methods are grouped in
  include files by area so each stays readable:

    pcapp_input.inc    events, key translation, prompts
    pcapp_draw.inc     drawing the editing screen
    pcapp_edit.inc     typing, cursor movement, tabs, lines
    pcapp_blocks.inc   line ranges, phrases, columns
    pcapp_search.inc   find, hunt, search and replace, unformat
    pcapp_files.inc    load, save, append, directory, output
    pcapp_screens.inc  preview, help, menus

  Key bindings follow the PaperClip II manual (Appendix A); see docs/keys.md for
  the PC substitutions for the Commodore-only keys. }
unit pcapp;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Character, pcsdl, pcconfig, pcgfx, pcdoc, pcsearch, pccolumns, pcfmt, pcout, pcspell;

const
  SYM_CTRLTAP = $7FFF0001;      { a Control key pressed and released on its own }

type
  TDirEntry = record
    Name: string;
    IsDir: Boolean;
    Size: Int64;
    Time: TDateTime;
  end;
  TDirItems = array of TDirEntry;

  TEvKind = (ekNone, ekKey, ekText, ekWheel, ekClick, ekDrag, ekRelease, ekQuit, ekResize);

  TKeyEv = record
    Kind: TEvKind;
    Sym: LongInt;
    Ctrl, Shift, Alt: Boolean;
    Text: UnicodeString;
    X, Y, Wheel, Clicks: Integer;
  end;

  TProc = procedure of object;

  TApp = class
  public
    Gfx: TGfx;
    Doc: TDoc;
    Cfg: TSettings;
    ConfigPath: string;
    HeadlessShot: string;
    constructor Create;
    destructor Destroy; override;
    function Start(const initialFile: string): string;
    procedure Run;
    procedure SetScript(const fn: string);
    procedure SaveConfig;
  private
    { ---- view ---- }
    TopRow, LeftCol: Integer;
    BlinkOn: Boolean;
    InsertMode, NumMode, CtrlMode, EscMode: Boolean;
    Msg: UnicodeString;
    MsgErr: Boolean;
    WantCol: Integer;
    FollowCursor: Boolean;
    SelActive, DragOn: Boolean;           { text selection }
    SelAP, SelAC, DragAP, DragAC: Integer;
    StyleRev: LongWord;
    StyleValid: Boolean;
    ParaStyle: array of Byte;
    JumpIdx: Integer;
    Done, QuitReq: Boolean;
    FullScreen, Overlay: TProc;
    { prompt state, drawn by the overlay }
    PromptActive: Boolean;
    PromptText, PromptInput: UnicodeString;
    PromptCur: Integer;
    PromptEsc: Boolean;
    PromptFresh: Boolean;
    PromptYN: Boolean;
    { transient selection and highlights }
    SelKind: Integer;                 { 0 none, 1 range, 2 phrase, 3 column }
    SelP0, SelC0, SelC1, SelRow0, SelCol0, SelRow1, SelCol1: Integer;
    FlashP, FlashC1, FlashC2: Integer;
    { search }
    LastSearch: UnicodeString;
    { columns }
    FieldSeps: UnicodeString;
    DecPlaces: Integer;
    MarkC: array[0..1] of Integer;
    { histories }
    Histories: array[0..4] of TStringList;
    { events }
    EvQ: array of TKeyEv;
    SwallowText: Boolean;
    SwallowUntil: LongWord;
    CtrlHeld, CtrlTapOK: Boolean;
    Script: TStringList;
    ScriptPos: Integer;
    ScriptRunning: Boolean;
    LastDir: string;
    PendingMsg: UnicodeString;
    { preview }
    PvFmt: TFormatter;
    PvTop, PvLeft, PvZoom, PvTotal: Integer;
    PvStarts: TIntArray;
    { help and menus }
    HelpText: TStringList;
    HelpTop, HelpWrapW: Integer;
    HelpLines: TStringList;
    MenuKind, MenuSel: Integer;
    MenuTitle: string;
    MenuNames, MenuVals: array of string;
    { directory screen }
    DirItems: TDirItems;
    DirPath, DirMask: string;
    DirSel, DirTop: Integer;

    { ---- input ---- }
    procedure PushEvent(const ev: TKeyEv);
    function NextEvent(var ev: TKeyEv; waitMs: Integer): Boolean;
    function Translate(var e: TSDL_Event; var ev: TKeyEv): Boolean;
    function ScriptNext(var ev: TKeyEv): Boolean;
    function WaitKey(var ev: TKeyEv): Boolean;
    procedure Render;
    function Ask(const prompt: UnicodeString; var value: UnicodeString; hist: Integer;
      allowEsc: Boolean): Boolean;
    function AskInt(const prompt: UnicodeString; var v: Integer; lo, hi: Integer): Boolean;
    function AskYN(const prompt: UnicodeString): Integer;       { 1 yes, 0 no, -1 cancel }
    function AskChoice(const prompt, chars: UnicodeString): WideChar;
    procedure DrawPromptOverlay;
    procedure SetMsg(const s: UnicodeString; err: Boolean = False);
    function EscToMarker(ch: WideChar; out m: UnicodeString): Boolean;
    function KeyToCtrlChar(sym: LongInt; shift: Boolean): WideChar;

    { ---- drawing ---- }
    function LayoutWidth: Integer;
    procedure LayoutNow;
    procedure EnsureCursorVisible;
    function TextRows: Integer;
    function TextTop: Integer;
    procedure DrawEditor;
    procedure DrawStatus;
    procedure DrawTabLine;
    procedure DrawHint;
    procedure DrawEditScreen;
    function MarkerGlyph(ch: WideChar): WideChar;
    function MixColor(a, b: LongWord; pct: Integer): LongWord;
    procedure DrawCursor;
    procedure EnsureStyleCache;
    function StyleAt(p, c: Integer): Byte;
    procedure ToggleStyle(kind: Char);

    { ---- editing ---- }
    procedure HandleKey(const ev: TKeyEv);
    procedure HandleText(const s: UnicodeString);
    procedure HandleKeyInner(const ev: TKeyEv);
    procedure HandleClick(x, y, clicks: Integer; shift: Boolean);
    procedure HandleDrag(x, y: Integer);
    procedure BeginSel;
    procedure EndSel;
    function SelBounds(out loP, loC, hiP, hiC: Integer): Boolean;
    function SelText: UnicodeString;
    procedure DeleteSelection;
    procedure SelectWordAt(p, c: Integer);
    procedure SelectAll;
    function PixelToPos(x, y: Integer; out p, c: Integer): Boolean;
    procedure CtrlCommand(ch: WideChar);
    procedure EscChar(const s: UnicodeString);
    procedure CursorRowCol(out row, col: Integer);
    procedure MoveToRowCol(row, col: Integer);
    procedure MoveVert(delta: Integer);
    procedure MoveLeft;
    procedure MoveRight;
    procedure MoveWordLeft;
    procedure MoveWordRight;
    procedure GoTop;
    procedure GoBottom;
    procedure PageMove(dir: Integer);
    procedure InsertTyped(const s: UnicodeString);
    procedure NumericChar(ch: WideChar);
    procedure DoReturn;
    procedure DoBackspace;
    procedure DoDelete;
    procedure DoTab(numericOnly: Boolean);
    procedure ToggleTab(numeric: Boolean);
    procedure ClearTabs;
    procedure DoInsertLine;
    procedure DoDeleteLine;
    procedure DoInsertLines;
    procedure DoEraseText;
    procedure NextLineStart;
    procedure SetBookmark;
    procedure GotoBookmark;
    procedure SetLineLength;
    procedure PadParaTo(p, c: Integer);
    procedure InsertAtCursor(const s: UnicodeString);
    procedure Undo;
    procedure Redo;
    procedure ClipCopy(cut: Boolean);
    procedure ClipPaste;
    function IsNumChar(ch: WideChar): Boolean;
    function TryQuit: Boolean;
    function CurRow: Integer;

    { ---- blocks ---- }
    function RunSelect(kind: Integer; deleteAfter: Boolean): Boolean;
    procedure RangeSet;
    procedure RangeTransfer;
    procedure RangeCopy;
    procedure RangeDelete;
    procedure RangeSave;
    procedure PhraseSet(deleteNow: Boolean);
    procedure PhraseMove;
    procedure PhraseCopy;
    procedure PhraseCase;
    procedure ColumnSet;
    procedure ColumnDo(op: Char);
    procedure ColumnSum(rows: Boolean);
    procedure ColumnDecimals;
    procedure ColumnSeps;
    procedure ColumnSort;
    procedure ColumnFill;
    procedure FinishColumnOp(const err: string);
    function PhraseText: UnicodeString;

    { ---- search ---- }
    function FindFrom(var p, c: Integer; const pat: TPattern; out mlen: Integer): Boolean;
    procedure DoFind;
    procedure DoHunt;
    procedure HuntNext;
    procedure DoReplace;
    procedure DoUnformat;
    function ChainNext(out name: string): Boolean;
    function ResolvePath(const name: string): string;

    { ---- files ---- }
    function ConfirmDiscard: Boolean;
    function DefaultName: string;
    procedure DoLoad;
    procedure DoSave;
    procedure DoAppend;
    function LoadPath(const fn: string; quiet: Boolean): Boolean;
    function SavePath(const fn: string; quiet: Boolean): Boolean;
    procedure DoDirectory(which: Integer);
    procedure UpdateTitle;
    function LoadChainFile(const name: string; var paras: TStrArray): Boolean;
    function AskNextFile: string;
    function BuildFormat: TFormatter;
    function WriteToc(f: TFormatter; out isErr: Boolean): UnicodeString;
    procedure DoOutput(quick: Boolean);
    procedure OutputPages(f: TFormatter);
    function DocDir: string;

    { ---- screens ---- }
    procedure DoSpell;
    procedure DoPreview;
    procedure DoHelp;
    procedure DoScreenMenu;
    procedure DoFileMenu;
    procedure ShowWarnings(f: TFormatter);
    function PvPageAt(globalRow: Integer): Integer;
    procedure DrawPreview;
    procedure PvApplyZoom;
    procedure DrawWarnScreen;
    procedure DrawHelp;
    procedure WrapHelp(width: Integer);
    procedure MenuFillScreen;
    procedure MenuFillFile;
    procedure MenuAdd(const n, v: string);
    procedure DrawMenuOverlay;
    procedure MenuAdjust(dir: Integer);
    procedure MenuEnter;
    procedure RunMenu(kind: Integer; const title: string);
    procedure LoadDirectory(const path, mask: string);
    procedure DrawDirScreen;
  end;

procedure OpenExternally(const path: string);
function PrintFileExternally(const path: string; copies: Integer): string;

implementation

uses
  {$IFDEF WINDOWS}Windows, ShellApi,{$ELSE}Process,{$ENDIF}
  StrUtils;

function IfThenInt(c: Boolean; a, b: Integer): Integer;
begin
  if c then Result := a else Result := b;
end;

{ case-insensitive match with * and ? }
function MatchesMask(const name, mask: string): Boolean;

  function Rec(n, m: Integer): Boolean;
  begin
    while m <= Length(mask) do
    begin
      if mask[m] = '*' then
      begin
        Inc(m);
        if m > Length(mask) then Exit(True);
        while n <= Length(name) + 1 do
        begin
          if Rec(n, m) then Exit(True);
          Inc(n);
        end;
        Exit(False);
      end
      else if n > Length(name) then Exit(False)
      else if (mask[m] <> '?') and (LowerCase(mask[m]) <> LowerCase(name[n])) then Exit(False);
      Inc(n);
      Inc(m);
    end;
    Result := n > Length(name);
  end;

begin
  Result := Rec(1, 1);
end;

function IfThenStr(c: Boolean; const a, b: string): string;
begin
  if c then Result := a else Result := b;
end;

{$I pcapp_input.inc}
{$I pcapp_draw.inc}
{$I pcapp_edit.inc}
{$I pcapp_blocks.inc}
{$I pcapp_search.inc}
{$I pcapp_files.inc}
{$I pcapp_screens.inc}
{$I pcapp_spell.inc}

constructor TApp.Create;
var
  i: Integer;
begin
  inherited Create;
  Doc := TDoc.Create;
  Gfx := TGfx.Create;
  DefaultSettings(Cfg);
  InsertMode := True;
  BlinkOn := True;
  FollowCursor := True;
  FieldSeps := '                ';
  DecPlaces := 255;
  FlashP := -1;
  MarkC[0] := 0;
  MarkC[1] := 0;
  for i := 0 to High(Histories) do Histories[i] := TStringList.Create;
  Script := TStringList.Create;
end;

destructor TApp.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(Histories) do Histories[i].Free;
  Script.Free;
  HelpText.Free;
  HelpLines.Free;
  PvFmt.Free;
  Gfx.Free;
  Doc.Free;
  inherited Destroy;
end;

procedure TApp.SaveConfig;
begin
  try
    SaveSettings(Cfg, ConfigPath);
  except
    on e: Exception do SetMsg('Cannot save the configuration: ' + UnicodeString(e.Message), True);
  end;
end;

function TApp.Start(const initialFile: string): string;
begin
  MigrateOldConfig;
  ConfigPath := ConfigFile('tiepaper.ini');
  LoadSettings(Cfg, ConfigPath);
  Result := Gfx.Init('TiePaper', Cfg);
  if Result <> '' then Exit;
  Gfx.Resized;
  LastDir := Cfg.LastDir;
  if (initialFile <> '') then
  begin
    if FileExists(initialFile) then LoadPath(initialFile, True)
    else
    begin
      Doc.FileName := ExpandFileName(initialFile);
      SetMsg('New file ' + UnicodeString(initialFile));
    end;
  end;
  UpdateTitle;
  if Msg = '' then SetMsg('F1 for help');
end;

procedure TApp.Run;
var
  ev: TKeyEv;
begin
  while not Done do
  begin
    if not WaitKey(ev) then
    begin
      if QuitReq then
      begin
        QuitReq := False;
        if TryQuit then Done := True;
      end;
      Continue;
    end;
    case ev.Kind of
      ekKey: HandleKey(ev);
      ekText: HandleText(ev.Text);
      ekWheel:
        begin
          if ev.Ctrl then
          begin
            if ev.Wheel > 0 then Gfx.SetFontSize(Gfx.FontPx + 2)
            else Gfx.SetFontSize(Gfx.FontPx - 2);
            Cfg.FontSize := Gfx.FontPx;
          end
          else
          begin
            FollowCursor := False;
            TopRow := TopRow - ev.Wheel * 3;
            if TopRow < 0 then TopRow := 0;
            if TopRow > Doc.RowCount - 1 then TopRow := Doc.RowCount - 1;
          end;
        end;
      ekClick: HandleClick(ev.X, ev.Y, ev.Clicks, ev.Shift);
      ekDrag: HandleDrag(ev.X, ev.Y);
      ekRelease: DragOn := False;
    end;
    if QuitReq then
    begin
      QuitReq := False;
      if TryQuit then Done := True;
    end;
  end;
  Cfg.WinW := Gfx.WidthPx;
  Cfg.WinH := Gfx.HeightPx;
  Cfg.LastDir := LastDir;
  SaveConfig;
end;

end.
