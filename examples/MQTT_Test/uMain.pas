unit uMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, MQTT, ExtCtrls, ShellAPI,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient;

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
    btnPublishRetain: TButton;
    btnClear: TButton;
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnPublishClick(Sender: TObject);
    procedure btnPingClick(Sender: TObject);
    procedure OnConnAck(Sender: TObject; ReturnCode: integer);
    procedure OnPingResp(Sender: TObject);
    procedure OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
    procedure OnUnSubAck(Sender: TObject; MessageID: integer);
    procedure OnPublish(Sender: TObject; topic, payload: string);
    procedure OnConnError(Sender: TObject; ErrMessage: String);
    procedure OnDisconnect (Sender: TObject);
    procedure btnSubscribeClick(Sender: TObject);
    procedure lblUrlClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnPublishRetainClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
  private
    fMQTTClient: TMQTTClient;
  public
		Procedure TerminateThread();
  end;

var
  fMain: TfMain;

implementation

{$R *.dfm}


procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
	TerminateThread();
end;


procedure TfMain.btnClearClick(Sender: TObject);
begin
	mStatus.Lines.Clear;
end;

Procedure TfMain.btnConnectClick(Sender: TObject);
begin
	if Assigned(fMQTTClient) then Exit;
  fMQTTClient := TMQTTClient.Create(eIP.Text, StrToInt(ePort.Text),60);
	fMQTTClient.FreeOnTerminate:=false;
  fMQTTClient.OnConnAck := OnConnAck;
  fMQTTClient.OnPingResp := OnPingResp;
  fMQTTClient.OnPublish := OnPublish;
  fMQTTClient.OnSubAck := OnSubAck;
  fMQTTClient.OnUnSubAck := OnUnSubAck;
  fMQTTClient.OnDisconnect := OnDisconnect;
  fMQTTClient.OnConnError := OnConnError;
end;

Procedure TfMain.btnDisconnectClick(Sender: TObject);
begin
	TerminateThread;
	mStatus.Lines.Add('Disconnected');
end;

procedure TfMain.btnPingClick(Sender: TObject);
begin
	if Assigned(fMQTTClient)then fMQTTClient.PingReq;
end;

procedure TfMain.btnPublishClick(Sender: TObject);
begin
  if Assigned(fMQTTClient)then fMQTTClient.Publish(eTopic.Text, eMessage.Text);
end;

procedure TfMain.btnPublishRetainClick(Sender: TObject);
begin
  if Assigned(fMQTTClient)then fMQTTClient.Publish(eTopic.Text, eMessage.Text, True);
end;

procedure TfMain.btnSubscribeClick(Sender: TObject);
begin
  if Assigned(fMQTTClient)then fMQTTClient.Subscribe(eSubTopic.Text);
end;

// To exit safely without gpf/mem leaks the thread needs to stopped first.
// Terminate Thread, wait if termminate is done, freeing it and set it to nil
Procedure TfMain.TerminateThread();
Begin
	if Assigned(fMQTTClient)then
  Begin
	  fMQTTClient.Terminate;
 		while fMQTTClient.isTerminated = false do application.ProcessMessages;
    fMQTTClient.free;
    fMQTTClient:=nil;
  End;
End;

Procedure TfMain.OnPublish(Sender: TObject; topic, payload: string);
begin
  mStatus.Lines.Add('Publish Received. Topic: ' + topic + ' Payload: ' + payload);
end;

procedure TfMain.OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
begin
  mStatus.Lines.Add('Sub Ack Received');
end;

procedure TfMain.OnUnSubAck(Sender: TObject; MessageID: integer);
begin
  mStatus.Lines.Add('Unsubscribe Ack Received');
end;

Procedure TfMain.OnConnAck(Sender: TObject; ReturnCode: integer);
begin
  mStatus.Lines.Add('Connection Acknowledged, Return Code: ' + IntToStr(Ord(ReturnCode)));
end;

procedure TfMain.OnPingResp(Sender: TObject);
begin
  mStatus.Lines.Add('PING! PONG!');
end;

procedure TfMain.OnConnError(Sender: TObject; ErrMessage: String);
begin
  mStatus.Lines.Add('Connection error:' + ErrMessage);
end;

procedure TfMain.OnDisconnect (Sender: TObject);
begin
  mStatus.Lines.Add('Disconnected!');
end;

procedure TfMain.lblUrlClick(Sender: TObject);
begin
  ShellExecute(self.WindowHandle, 'open', PChar((Sender as TLabel).Caption), nil, nil,
    SW_SHOWNORMAL);
end;

end.
