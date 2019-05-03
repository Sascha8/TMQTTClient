unit uMain;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  MQTT,
  MQTTReadThread,
  ExtCtrls,
  ShellAPI,
  IdBaseComponent,
  IdComponent,
  IdTCPConnection,
  IdTCPClient;

type
  TfMain = class(TForm)
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnPublish: TButton;
    eTopic: TEdit;
    eMessage: TEdit;
    eIP: TEdit;
    ePort: TEdit;
    btnPing: TButton;
    btnSubscribe: TButton;
    eSubTopic: TEdit;
    mStatus: TMemo;
    lblHeader: TLabel;
    lnlMQTTInfo: TLabel;
    lblMQTTUrl: TLabel;
    lblPrimarilyTested: TLabel;
    lblRSMBUrl: TLabel;
    lblLimits: TLabel;
    lblLimits2: TLabel;
    lblSynapse: TLabel;
    btnPublishRetain: TButton;
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnPublishClick(Sender: TObject);
    procedure btnPingClick(Sender: TObject);
    procedure OnConnAck(Sender: TObject; ReturnCode: integer);
    procedure OnPingResp(Sender: TObject);
    procedure OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
    procedure OnUnSubAck(Sender: TObject);
    procedure OnPublish(Sender: TObject; topic, payload: string);
    procedure btnSubscribeClick(Sender: TObject);
    procedure lblUrlClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnPublishRetainClick(Sender: TObject);
  private
    fMQTTClient: TMQTTClient;
  public
    { Public declarations }
  end;

var
  fMain: TfMain;
  fRL: TBytes;

implementation

{$R *.dfm}


procedure TfMain.OnPublish(Sender: TObject; topic, payload: string);
begin
  mStatus.Lines.Add('Publish Received. Topic: ' + topic + ' Payload: ' + payload);
end;

procedure TfMain.OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
begin
  mStatus.Lines.Add('Sub Ack Received');
end;

procedure TfMain.OnUnSubAck(Sender: TObject);
begin
  mStatus.Lines.Add('Unsubscribe Ack Received');
end;

procedure TfMain.OnConnAck(Sender: TObject; ReturnCode: integer);
begin
  mStatus.Lines.Add('Connection Acknowledged, Return Code: ' + IntToStr(Ord(ReturnCode)));
end;

procedure TfMain.OnPingResp(Sender: TObject);
begin
  mStatus.Lines.Add('PING! PONG!');
end;

procedure TfMain.btnConnectClick(Sender: TObject);
begin
  if Assigned(fMQTTClient) then
  begin
    Exit;
  end;

  fMQTTClient := TMQTTClient.Create(eIP.Text, StrToInt(ePort.Text));
  try
    fMQTTClient.OnConnAck := OnConnAck;
    fMQTTClient.OnPingResp := OnPingResp;
    fMQTTClient.OnPublish := OnPublish;
    fMQTTClient.OnSubAck := OnSubAck;
    fMQTTClient.Connect;
  except
    FreeAndNil(fMQTTClient);
    raise;
  end;
end;

procedure TfMain.btnDisconnectClick(Sender: TObject);
begin
  if Assigned(fMQTTClient) then
  begin
    fMQTTClient.Disconnect;
    FreeAndNil(fMQTTClient);
  end;
end;

procedure TfMain.btnPingClick(Sender: TObject);
begin
  fMQTTClient.PingReq;
end;

procedure TfMain.btnPublishClick(Sender: TObject);
begin
  fMQTTClient.Publish(eTopic.Text, eMessage.Text);
end;

procedure TfMain.btnPublishRetainClick(Sender: TObject);
begin
  fMQTTClient.Publish(eTopic.Text, eMessage.Text, True);
end;

procedure TfMain.btnSubscribeClick(Sender: TObject);
begin
  fMQTTClient.Subscribe(eSubTopic.Text);
end;

procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FreeAndNil(fMQTTClient);
end;

procedure TfMain.lblUrlClick(Sender: TObject);
begin
  ShellExecute(self.WindowHandle, 'open', PChar((Sender as TLabel).Caption), nil, nil,
    SW_SHOWNORMAL);
end;

end.
