object fMain: TfMain
  Left = 0
  Top = 0
  Caption = 'TMQTTClient Test Project'
  ClientHeight = 556
  ClientWidth = 451
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  PixelsPerInch = 96
  TextHeight = 16
  object lblHeader: TLabel
    Left = 8
    Top = 6
    Width = 410
    Height = 34
    Alignment = taCenter
    AutoSize = False
    Caption = 'Sample Client'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -29
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    Layout = tlCenter
  end
  object lnlMQTTInfo: TLabel
    Left = 5
    Top = 480
    Width = 194
    Height = 13
    Caption = 'For more information about MQTT goto: '
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object lblMQTTUrl: TLabel
    Left = 205
    Top = 480
    Width = 102
    Height = 13
    Cursor = crHandPoint
    Caption = 'http://www.mqtt.org'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlue
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsUnderline]
    ParentFont = False
    OnClick = lblUrlClick
  end
  object lblPrimarilyTested: TLabel
    Left = 5
    Top = 499
    Width = 154
    Height = 13
    Caption = 'Server primarily tested against: '
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object lblRSMBUrl: TLabel
    Left = 165
    Top = 499
    Width = 108
    Height = 13
    Cursor = crHandPoint
    Caption = 'https://mosquitto.org/'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlue
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = [fsUnderline]
    ParentFont = False
    OnClick = lblUrlClick
  end
  object lblLimits: TLabel
    Left = 5
    Top = 517
    Width = 398
    Height = 13
    Caption = 
      'This Sample is not comprehensive of either the TMQTTClient nor t' +
      'he MQTT Protocol'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object lblLimits2: TLabel
    Left = 5
    Top = 535
    Width = 288
    Height = 13
    Caption = 'but is a good place to start in learning how to use the client.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object btnConnect: TButton
    Left = 343
    Top = 56
    Width = 98
    Height = 25
    Caption = 'Connect'
    TabOrder = 0
    OnClick = btnConnectClick
  end
  object btnDisconnect: TButton
    Left = 343
    Top = 87
    Width = 98
    Height = 25
    Caption = 'Disconnect'
    TabOrder = 1
    OnClick = btnDisconnectClick
  end
  object btnPublish: TButton
    Left = 343
    Top = 150
    Width = 98
    Height = 25
    Caption = 'Publish'
    TabOrder = 2
    OnClick = btnPublishClick
  end
  object eTopic: TEdit
    Left = 8
    Top = 152
    Width = 121
    Height = 24
    TabOrder = 3
    Text = '/dev/test'
  end
  object eMessage: TEdit
    Left = 135
    Top = 152
    Width = 202
    Height = 24
    TabOrder = 4
    Text = 'Testing '#10003#9788#9787#9889
  end
  object eIP: TEdit
    Left = 8
    Top = 58
    Width = 202
    Height = 24
    TabOrder = 5
    Text = 'media2'
  end
  object ePort: TEdit
    Left = 216
    Top = 58
    Width = 121
    Height = 24
    TabOrder = 6
    Text = '1883'
  end
  object btnPing: TButton
    Left = 343
    Top = 118
    Width = 98
    Height = 25
    Caption = 'Ping'
    TabOrder = 7
    OnClick = btnPingClick
  end
  object btnSubscribe: TButton
    Left = 343
    Top = 219
    Width = 98
    Height = 25
    Caption = 'Subscribe'
    TabOrder = 8
    OnClick = btnSubscribeClick
  end
  object eSubTopic: TEdit
    Left = 135
    Top = 219
    Width = 202
    Height = 24
    TabOrder = 9
    Text = '#'
  end
  object mStatus: TMemo
    Left = 9
    Top = 258
    Width = 434
    Height = 175
    ScrollBars = ssVertical
    TabOrder = 10
  end
  object btnPublishRetain: TButton
    Left = 343
    Top = 179
    Width = 98
    Height = 25
    Caption = 'Publish Retain'
    TabOrder = 11
    OnClick = btnPublishRetainClick
  end
  object btnClear: TButton
    Left = 130
    Top = 439
    Width = 183
    Height = 27
    Caption = 'Clear'
    TabOrder = 12
    OnClick = btnClearClick
  end
end
