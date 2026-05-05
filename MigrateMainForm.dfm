object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Paradox -> Firebird Migration Tool'
  ClientHeight = 420
  ClientWidth = 680
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 15
  object BtnStart: TButton
    Left = 16
    Top = 16
    Width = 150
    Height = 32
    Caption = 'Avvia Migrazione'
    TabOrder = 0
    OnClick = BtnStartClick
  end
  object ProgressBar: TProgressBar
    Left = 16
    Top = 64
    Width = 648
    Height = 24
    TabOrder = 1
  end
  object MemoLog: TMemo
    Left = 16
    Top = 104
    Width = 648
    Height = 300
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object FDConnParadox: TFDConnection
    Params.Strings = (
      'DriverID=BDE')
    LoginPrompt = False
    Left = 232
    Top = 16
  end
  object FDConnFB: TFDConnection
    Params.Strings = (
      'DriverID=FB'
      'User_Name=sysdba'
      'Password=masterkey')
    LoginPrompt = False
    Left = 296
    Top = 16
  end
end
