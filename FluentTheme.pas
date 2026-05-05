unit FluentTheme;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.DwmApi,
  System.SysUtils, System.Classes,
  Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Forms, Vcl.Graphics;

type
  TFluentThemeMode = (ftLight, ftDark);

procedure ApplyFluentTheme(Form: TForm; Mode: TFluentThemeMode);
procedure ApplyMica(Form: TForm);
procedure StyleFluentButton(B: TButton; Mode: TFluentThemeMode);
procedure StyleNavButton(B: TButton; Mode: TFluentThemeMode);
procedure FadeIn(Form: TForm; DurationMs: Integer = 250);
procedure SlideIn(Control: TControl; Offset: Integer = 40; DurationMs: Integer = 200);

implementation

const
  COLOR_BG_LIGHT      = $00FFFFFF;
  COLOR_PANEL_LIGHT   = $00F3F3F3;
  COLOR_TEXT_DARK     = $00202020;

  COLOR_BG_DARK       = $00202020;
  COLOR_PANEL_DARK    = $00282828;
  COLOR_TEXT_LIGHT    = $00FFFFFF;

  COLOR_ACCENT        = $00D77800;

type
  TFluentButton = class(TButton)
  private
    FMode: TFluentThemeMode;
    procedure CMMouseEnter(var Msg: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Msg: TMessage); message CM_MOUSELEAVE;
  public
    procedure ApplyStyle(Mode: TFluentThemeMode);
  end;

{------------------------------------------------------------------------------}
{  MICA EFFECT (Windows 11) }
{------------------------------------------------------------------------------}
procedure ApplyMica(Form: TForm);
var
  attr, val: Integer;
begin
  attr := 1029; // DWMWA_SYSTEMBACKDROP_TYPE
  val := 2;     // Mica Alt
  DwmSetWindowAttribute(Form.Handle, attr, @val, SizeOf(val));
end;

{------------------------------------------------------------------------------}
{  THEME APPLICATION }
{------------------------------------------------------------------------------}
procedure ApplyFluentTheme(Form: TForm; Mode: TFluentThemeMode);
var
  I: Integer;
begin
  if Mode = ftDark then
  begin
    Form.Color := COLOR_BG_DARK;
    Form.Font.Color := COLOR_TEXT_LIGHT;
  end
  else
  begin
    Form.Color := COLOR_BG_LIGHT;
    Form.Font.Color := COLOR_TEXT_DARK;
  end;

  for I := 0 to Form.ComponentCount - 1 do
    if Form.Components[I] is TPanel then
      if Mode = ftDark then
        (Form.Components[I] as TPanel).Color := COLOR_PANEL_DARK
      else
        (Form.Components[I] as TPanel).Color := COLOR_PANEL_LIGHT;
end;

{------------------------------------------------------------------------------}
{  BUTTON STYLE (WinUI) }
{------------------------------------------------------------------------------}
procedure StyleFluentButton(B: TButton; Mode: TFluentThemeMode);
var
  FB: TFluentButton;
begin
  // Converti il TButton in TFluentButton mantenendo proprietà
  FB := TFluentButton.Create(B.Owner);
  FB.Parent := B.Parent;
  FB.Left := B.Left;
  FB.Top := B.Top;
  FB.Width := B.Width;
  FB.Height := B.Height;
  FB.Caption := B.Caption;
  FB.OnClick := B.OnClick;

  B.Free;

  FB.ApplyStyle(Mode);
end;

procedure StyleNavButton(B: TButton; Mode: TFluentThemeMode);
begin
  StyleFluentButton(B, Mode);
  B.Align := alTop;
  B.Height := 40;
end;

{------------------------------------------------------------------------------}
{  ANIMATIONS }
{------------------------------------------------------------------------------}
procedure FadeIn(Form: TForm; DurationMs: Integer);
var
  i: Integer;
begin
  Form.AlphaBlend := True;
  Form.AlphaBlendValue := 0;

  for i := 0 to 255 do
  begin
    Form.AlphaBlendValue := i;
    Sleep(DurationMs div 255);
    Application.ProcessMessages;
  end;
end;

procedure SlideIn(Control: TControl; Offset: Integer; DurationMs: Integer);
var
  StartLeft, TargetLeft, Step: Integer;
begin
  StartLeft := Control.Left + Offset;
  TargetLeft := Control.Left;
  Control.Left := StartLeft;

  Step := Offset div (DurationMs div 5);

  while Control.Left > TargetLeft do
  begin
    Control.Left := Control.Left - Step;
    Sleep(5);
    Application.ProcessMessages;
  end;

  Control.Left := TargetLeft;
end;

{------------------------------------------------------------------------------}
{  TFluentButton IMPLEMENTATION }
{------------------------------------------------------------------------------}
procedure TFluentButton.ApplyStyle(Mode: TFluentThemeMode);
begin
  FMode := Mode;

  Font.Name := 'Segoe UI Semibold';
  Font.Size := 10;

  if Mode = ftDark then
  begin
    Self.Color := COLOR_PANEL_DARK;
    Self.Font.Color := COLOR_TEXT_LIGHT;
  end
  else
  begin
    Self.Color := COLOR_PANEL_LIGHT;
    Self.Font.Color := COLOR_TEXT_DARK;
  end;
end;

procedure TFluentButton.CMMouseEnter(var Msg: TMessage);
begin
  Self.Color := COLOR_ACCENT;
  inherited;
end;

procedure TFluentButton.CMMouseLeave(var Msg: TMessage);
begin
  if FMode = ftDark then
    Self.Color := COLOR_PANEL_DARK
  else
    Self.Color := COLOR_PANEL_LIGHT;

  inherited;
end;

end.

