unit fSettings;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StrUtils, StdCtrls, ComCtrls, jpeg, Math, ShellApi;

type
  TfSetup = class(TForm)
    imgHeader: TImage;
    lHeaderShadow: TLabel;
    lHeader: TLabel;
    cAutomode: TCheckBox;
    lAutomodeEvery: TLabel;
    eAutomodeEvery: TEdit;
    lZoom: TLabel;
    eZoom: TTrackBar;
    imgZoomL: TImage;
    imgZoomR: TImage;
    lZoom10: TLabel;
    lZoom1000: TLabel;
    lZoom100: TLabel;
    lZoomFeedback: TLabel;
    lZoom50: TLabel;
    lZoom20: TLabel;
    lZoom200: TLabel;
    lZoom500: TLabel;
    bStartDizzy: TButton;
    Shape1: TShape;
    cFullscreen: TCheckBox;
    lWindowsize: TLabel;
    eWindowWidth: TEdit;
    eWindowHeight: TEdit;
    lWindowSizeX: TLabel;
    cDbgConsole: TCheckBox;
    bDbgShow: TButton;
    lDbgDebug: TLabel;
    cDbgShowPlanes: TCheckBox;
    cTexBlend: TCheckBox;
    lTexBlendDuration: TLabel;
    eTexBlendDuration: TEdit;
    procedure cTexBlendChanged;
    procedure cAutomodeChanged;
    procedure cAutomodeChanged2(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure cAutomodeChanged1(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormActivate(Sender: TObject);
    procedure eZoomChange(Sender: TObject);
    procedure bStartDizzyClick(Sender: TObject);
    procedure cFullscreenChanged();
    procedure cFullscreenChanged1(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure cFullscreenChanged2(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure Button1Click(Sender: TObject);
    procedure bDbgShowClick(Sender: TObject);
    procedure cTexBlendChanged2(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure cTexBlendChanged1(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
  end;

var
  fSetup: TfSetup;

implementation

{$R *.dfm}

procedure TfSetup.cAutomodeChanged();
begin
        { Called when the state of the box has possibly changed }
        eAutomodeEvery.Enabled := cAutomode.Checked;
        lAutomodeEvery.Enabled := cAutomode.Checked;
end;

{ wrappers around cAutomodeChanged - to emit on mouse and key events }
procedure TfSetup.cAutomodeChanged2(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
        cAutomodeChanged();
end;

procedure TfSetup.cAutomodeChanged1(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
        { so cAutomodeChanged sees correct state }
        if key = Ord(' ') then cAutomode.Checked := not cAutomode.Checked;
        cAutomodeChanged();
        if key = Ord(' ') then cAutomode.Checked := not cAutomode.Checked;
end;

procedure TfSetup.FormActivate(Sender: TObject);
        procedure st(v: Integer);
        begin
                eZoom.SetTick(Trunc(log10(v) * 100));
        end;
begin
        st(20);
        st(50);

        st(100);
        st(200);
        st(500);
end;

procedure TfSetup.eZoomChange(Sender: TObject);
begin
        lZoomFeedback.Caption := IntToStr(Trunc(Power(10, eZoom.Position / 100))) + '%';
end;

{ Eats a floating point number, with the decimal separator being either period
  or a comma. Returns NaN if the string is invalid }
function SaneStrToFloat(txt: String): Real;
begin
        { Replace all periods and dots in the string with whatever StrToFloat eats }
        txt := AnsiReplaceStr(txt, ',', DecimalSeparator);
        txt := AnsiReplaceStr(txt, '.', DecimalSeparator);

        { convert }
        try
                Result := StrToFloat(txt);
        except
                Result := NaN;
        end;
end;

{ like FloatToStr just unfucks the decimal separator. }
function SaneFloatToStr(v: Extended): String;
begin
        Result := FloatToStr(v);
        Result := AnsiReplaceStr(Result, DecimalSeparator, '.');
end;

procedure TfSetup.bStartDizzyClick(Sender: TObject);
var optZoom: Real;
var optResolution: Integer;
var optAutomode: Boolean;
var optAutomodeEvery: Real;
var optTexBlend: Boolean;
var opttexBlendDuration: Real;
var optFullscreen: Boolean;
var optWidth, optHeight: Integer;

var fWSError: Boolean;

var options: String;
var toplevel: String;
var perlbin: String;
var exec_status: Integer;
begin
        { Calculate actual scale factor.
          Input is 2..4 to produce a zoom of 10^n
          scale factor is 50=100% 25=200% 100=50% (5000/z) }
        optZoom := power(10, eZoom.position / 100);

        { Calculate a suitable texture resolution for scale..
             ..75    32
           75..120   64
          120..     128
        }
             if optZoom <  75.0 then optResolution := 32
        else if optZoom < 120.0 then optResolution := 64
        else                         optResolution := 128;

        { Automode arguments }
        optAutomode := cAutomode.Checked;
        optAutomodeEvery := SaneStrToFloat(eAutomodeEvery.Text);
        if IsNaN(optAutomodeEvery) and optAutomode then begin
                MessageDlg(
                        'Ungültige Eingabe im Textfeld "Neue Textur alle ... Sekunden" (Automatisches Weiterschalten)',
                        mtError,
                        [mbOK],
                        0);
                Exit; { "return" in sane languages }
        end;

        { TexBlend arguments }
        optTexBlend := cTexBlend.Checked;
        optTexBlendDuration := SaneStrToFloat(eTexBlendDuration.Text);
        if IsNaN(optTexBlendDuration) and optTexBlend then begin
                MessageDlg(
                        'Ungültige Eingabe im Textfeld "Dauer" (Überblenden)',
                        mtError,
                        [mbOK],
                        0);
                Exit; { "return" in sane languages }
        end;
        { add blend duration to automode delay }
        if optTexBlend then optAutomodeEvery := optAutomodeEvery + optTexBlendDuration;

        { Window size/Fullscreen }
        optFullscreen := cFullscreen.Checked;
        if not optFullscreen then begin
                fWSError := false;

                { try converting first }
                try
                        optWidth := StrToInt(eWindowWidth.Text);
                        optHeight := StrToInt(eWindowHeight.Text);
                except
                        fWSError := true;
                        optWidth := 0; optHeight := 0; { eat compiler warnings }
                end;

                { then sanity check the values }
                if (optWidth <= 0) or (optHeight <= 0) then fWSError := true;

                { if any error happened, display an error. }
                if fWSError then begin
                        MessageDlg(
                                'Ungültige Angaben für die Fenstergröße',
                                mtError,
                                [mbOK],
                                0);
                        Exit; { "return" in sane languages }
                end;
        end;

        { assemble the arguments to a command line }
        options := '';
        options := options + ' -r ' + IntToStr(optResolution);
        options := options + ' -z ' + SaneFloatToStr(optZoom);
        if optAutomode then
                options := options + ' -a ' + SaneFloatToStr(optAutomodeEvery);
        if optTexBlend then
                options := options + ' -t Blend -T duration=' + SaneFloatToStr(optTexBlendDuration);
        if optFullscreen then begin
                options := options + ' -f';
        end else begin
                options := options
                        + ' -w ' + IntToStr(optWidth)
                        + ' -h ' + IntToStr(optHeight);
        end;

        { append debug options }
        if cDbgShowPlanes.Checked then
                options := options + ' --debug-show-planes';

        { ok, we're done with argument parsing. first hide the main window }
        Hide;

        { find the toplevel directory }
        toplevel := ExtractFilePath(Application.ExeName) + '\..\..';

        { which perl to use?
          wperl doesn't display a cansole window }
        if cDbgConsole.Checked then
                perlbin := '..\wkperl.bat'
        else
                perlbin := '..\strawberry\perl\bin\wperl.exe';


        { execute perl/dizzy }
        SetCurrentDir(toplevel);
        SetCurrentDir('perl_code');

        exec_status := ShellExecute(
                Handle, 'open',
                PChar(perlbin),
                PChar(
                          '-I../support_libraries/lib '
                        + '-I../support_libraries/arch '
                        + '-I../support_libraries '
                        + '-Ilib dizzy '
                        + options),
                nil, SW_SHOWNORMAL);

        { if we executed properly, exit }
        if exec_status <= 32 then begin { <= 32 describes an error, see winapi }
                MessageDlg(
                        'Fehler beim Ausführen von "' + perlbin + '" '
                        + '(in ' + GetCurrentDir + ') : '
                        + '(' + IntToStr(exec_status) + ') '
                        + SysErrorMessage(exec_status),
                        mtError,
                        [mbOK],
                        0);
        end;
        Application.Terminate;
end;

procedure TfSetup.cFullscreenChanged();
begin
        { Called when the state of the box has possibly changed }
        eWindowWidth.Enabled  := not cFullscreen.Checked;
        eWindowHeight.Enabled := not cFullscreen.Checked;
        lWindowSize.Enabled   := not cFullscreen.Checked;
        lWindowSizeX.Enabled  := not cFullscreen.Checked;
end;

procedure TfSetup.cFullscreenChanged1(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
        cFullscreenChanged;
end;

procedure TfSetup.cFullscreenChanged2(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
        if key = Ord(' ') then cFullscreen.Checked := not cFullscreen.Checked;
        cFullscreenChanged;
        if key = Ord(' ') then cFullscreen.Checked := not cFullscreen.Checked;
end;

procedure TfSetup.Button1Click(Sender: TObject);
begin
        fSetup.Height := fSetup.Height + 100;
end;

procedure TfSetup.bDbgShowClick(Sender: TObject);
begin
        bDbgShow.Enabled := False;
        fSetup.Height := fSetup.Height + 80;

        cDbgConsole.Visible := True;
        cDbgShowPlanes.Visible := True;
        lDbgDebug.Visible := True;
end;

procedure TfSetup.cTexBlendChanged2(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
        { so cTexBlendChanged sees correct state }
        if key = Ord(' ') then cTexBlend.Checked := not cTexBlend.Checked;
        cTexBlendChanged();
        if key = Ord(' ') then cTexBlend.Checked := not cTexBlend.Checked;
end;

procedure TfSetup.cTexBlendChanged1(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
        cTexBlendChanged();
end;

procedure TfSetup.cTexBlendChanged();
begin
        { Called when the state of the box has possibly changed }
        eTexBlendDuration.Enabled := cTexBlend.Checked;
        lTexBlendDuration.Enabled := cTexBlend.Checked;
end;

end.
