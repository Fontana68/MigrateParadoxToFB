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
  object ToggleSwitch1: TToggleSwitch
    Left = 192
    Top = 20
    Width = 138
    Height = 20
    StateCaptions.CaptionOn = 'Copia Dati'
    StateCaptions.CaptionOff = 'Database vuoto'
    TabOrder = 3
  end
  object btnGUI: TButton
    Left = 360
    Top = 19
    Width = 75
    Height = 25
    Caption = 'btnGUI'
    TabOrder = 4
    OnClick = btnGUIClick
  end
  object FDConnParadox: TFDConnection
    Params.Strings = (
      'DriverID=BDE')
    LoginPrompt = False
    Left = 448
    Top = 16
  end
  object FDConnFB: TFDConnection
    Params.Strings = (
      'DriverID=FB'
      'User_Name=sysdba'
      'CharacterSet=UTF8'
      
        'Database=C:\SW\BuilderC\Progetti\SW800\PumpBDE\MigrateParadoxToF' +
        'B\Source\Win32\Debug\FB\MOT.FDB'
      'PageSize=8192')
    LoginPrompt = False
    Left = 616
    Top = 16
  end
  object FDPhysFBDriverLink1: TFDPhysFBDriverLink
    Embedded = True
    Left = 552
    Top = 16
  end
end
