object frmFBMigration: TfrmFBMigration
  Left = 200
  Top = 120
  Caption = 'Firebird Migration'
  ClientHeight = 512
  ClientWidth = 818
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  DesignSize = (
    818
    512)
  TextHeight = 13
  object lblStatus: TLabel
    Left = 16
    Top = 16
    Width = 69
    Height = 13
    Caption = 'Stato: pronto'
  end
  object lblTables: TLabel
    Left = 16
    Top = 48
    Width = 96
    Height = 13
    Caption = 'Tabelle da migrare:'
  end
  object ProgressBarTotal: TProgressBar
    Left = 16
    Top = 80
    Width = 520
    Height = 17
    TabOrder = 0
  end
  object ProgressBarTable: TProgressBar
    Left = 16
    Top = 104
    Width = 520
    Height = 17
    TabOrder = 1
  end
  object clbTables: TCheckListBox
    Left = 16
    Top = 136
    Width = 240
    Height = 280
    ItemHeight = 17
    TabOrder = 2
  end
  object reLog: TRichEdit
    Left = 272
    Top = 136
    Width = 522
    Height = 272
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = ANSI_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 3
    ExplicitWidth = 520
    ExplicitHeight = 264
  end
  object btnRun: TButton
    Left = 16
    Top = 432
    Width = 120
    Height = 25
    Caption = 'Migra selezionate'
    TabOrder = 4
    OnClick = btnRunClick
  end
  object btnOpenHTML: TButton
    Left = 152
    Top = 432
    Width = 120
    Height = 25
    Caption = 'Apri Log HTML'
    TabOrder = 5
    OnClick = btnOpenHTMLClick
  end
  object btnOpenJSON: TButton
    Left = 288
    Top = 432
    Width = 120
    Height = 25
    Caption = 'Apri Report JSON'
    TabOrder = 6
    OnClick = btnOpenJSONClick
  end
end
