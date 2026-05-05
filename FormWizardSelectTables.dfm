object FormSelectTables: TFormSelectTables
  Left = 0
  Top = 0
  Caption = 'Seleziona tabelle da migrare'
  ClientHeight = 420
  ClientWidth = 420
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object Label1: TLabel
    Left = 16
    Top = 16
    Width = 207
    Height = 15
    Caption = 'Seleziona le tabelle Paradox da migrare:'
  end
  object CheckListTables: TCheckListBox
    Left = 16
    Top = 40
    Width = 388
    Height = 300
    ItemHeight = 17
    TabOrder = 0
  end
  object BtnSelectAll: TButton
    Left = 16
    Top = 350
    Width = 100
    Height = 25
    Caption = 'Seleziona tutto'
    TabOrder = 1
    OnClick = BtnSelectAllClick
  end
  object BtnUnselectAll: TButton
    Left = 130
    Top = 350
    Width = 100
    Height = 25
    Caption = 'Deseleziona tutto'
    TabOrder = 2
    OnClick = BtnUnselectAllClick
  end
  object BtnOK: TButton
    Left = 260
    Top = 350
    Width = 60
    Height = 25
    Caption = 'OK'
    ModalResult = 1
    TabOrder = 3
    OnClick = BtnOKClick
  end
  object BtnCancel: TButton
    Left = 340
    Top = 350
    Width = 60
    Height = 25
    Caption = 'Annulla'
    ModalResult = 2
    TabOrder = 4
  end
end
