object frmFBMigration: TfrmFBMigration
  Left = 0
  Top = 0
  Caption = 'frmFBMigration'
  ClientHeight = 582
  ClientWidth = 787
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  TextHeight = 15
  object lblStatus: TLabel
    Left = 48
    Top = 536
    Width = 83
    Height = 28
    Alignment = taCenter
    Caption = 'lblStatus'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -20
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object MemoLog: TMemo
    Left = 40
    Top = 248
    Width = 585
    Height = 241
    Lines.Strings = (
      'MemoLog')
    TabOrder = 0
  end
  object ProgressBar: TProgressBar
    Left = 48
    Top = 32
    Width = 593
    Height = 21
    TabOrder = 1
  end
  object btnRun: TButton
    Left = 48
    Top = 88
    Width = 137
    Height = 25
    Caption = 'Migra'
    TabOrder = 2
    OnClick = btnRunClick
  end
  object btnOpenHTML: TButton
    Left = 48
    Top = 148
    Width = 137
    Height = 25
    Caption = 'Apri Log HTML'
    TabOrder = 3
    OnClick = btnOpenHTMLClick
  end
  object btnOpenJSON: TButton
    Left = 48
    Top = 200
    Width = 137
    Height = 25
    Caption = 'Apri Log JSON'
    TabOrder = 4
    OnClick = btnOpenJSONClick
  end
end
