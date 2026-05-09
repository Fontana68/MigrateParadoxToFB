object FormMain: TFormMain
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Paradox '#8594' Firebird Migration Tool'
  ClientHeight = 480
  ClientWidth = 760
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 17
  object PanelTitleBar: TPanel
    Left = 0
    Top = 0
    Width = 760
    Height = 48
    Align = alTop
    BevelOuter = bvNone
    Color = 15987699
    TabOrder = 0
    object LabelTitle: TLabel
      Left = 16
      Top = 12
      Width = 262
      Height = 23
      Caption = 'Paradox '#8594' Firebird Migration Tool'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -17
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object BtnClose: TButton
      Left = 712
      Top = 0
      Width = 48
      Height = 48
      Align = alRight
      Caption = #10005
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = BtnCloseClick
    end
  end
  object PanelContent: TPanel
    Left = 0
    Top = 48
    Width = 760
    Height = 432
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 20
    Padding.Top = 20
    Padding.Right = 20
    Padding.Bottom = 20
    TabOrder = 1
    object BtnStart: TButton
      Left = 20
      Top = 20
      Width = 200
      Height = 40
      Caption = 'Avvia Migrazione'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      StyleElements = [seFont, seClient]
      OnClick = BtnStartClick
    end
    object btnGUI: TButton
      Left = 250
      Top = 20
      Width = 103
      Height = 40
      Caption = 'GUI'
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnClick = btnGUIClick
    end
    object ToggleSwitch1: TToggleSwitch
      Left = 380
      Top = 25
      Width = 163
      Height = 22
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
      StateCaptions.CaptionOn = 'Copia Dati'
      StateCaptions.CaptionOff = 'Database vuoto'
      TabOrder = 2
    end
    object ProgressBar: TProgressBar
      Left = 20
      Top = 80
      Width = 700
      Height = 20
      TabOrder = 3
    end
    object MemoLog: TMemo
      Left = 20
      Top = 120
      Width = 700
      Height = 300
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssVertical
      TabOrder = 4
    end
  end
  object FDConnParadox: TFDConnection
    Params.Strings = (
      'DriverID=BDE')
    LoginPrompt = False
    Left = 688
    Top = 160
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
    Left = 704
    Top = 296
  end
  object FDPhysFBDriverLink1: TFDPhysFBDriverLink
    Embedded = True
    Left = 696
    Top = 240
  end
end
