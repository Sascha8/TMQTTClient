unit MainFormU;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.Controls.Presentation,
  FMX.StdCtrls,
  MQTT,
  FMX.ScrollBox,
  FMX.Memo,
  FMX.Layouts;

type
  TForm3 = class(TForm)
    btnStart: TButton;
    mStatus: TMemo;
    Layout1: TLayout;
    btnPublish: TButton;
    btnSub1: TButton;
    btnSub2: TButton;
    Layout2: TLayout;
    btnPing: TButton;
    Layout3: TLayout;
    Layout4: TLayout;
    chkRetain: TCheckBox;
    procedure btnStartClick(Sender: TObject);
    procedure btnPublishClick(Sender: TObject);
    procedure btnSub1Click(Sender: TObject);
    procedure btnSub2Click(Sender: TObject);
    procedure btnPingClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    fMQTTClient: TMQTTClient;
    procedure OnConnAck(Sender: TObject; ReturnCode: integer);
    procedure OnConnError(Sender: TObject; ErrMessage: String);
    procedure OnDisconnect(Sender: TObject);
    procedure OnPingResp(Sender: TObject);
    procedure OnPublish(Sender: TObject; topic, payload: string);
    procedure OnSubAck(Sender: TObject; MessageID, GrantedQoS: integer);
    procedure OnUnSubAck(Sender: TObject; MessageID: integer);
    //
  public
    { Public declarations }
  end;

var
  Form3: TForm3;

{$R *.fmx}

implementation

procedure TForm3.OnPublish(Sender: TObject; topic, payload: string);
begin
  mStatus.Lines.Add('Publish Received. Topic: ' + topic + ' Payload: ' + payload);
end;

procedure TForm3.OnSubAck(Sender: TObject; MessageID: integer; GrantedQoS: integer);
begin
  mStatus.Lines.Add('Sub Ack Received');
end;

procedure TForm3.OnUnSubAck(Sender: TObject; MessageID: integer);
begin
  mStatus.Lines.Add('Unsubscribe Ack Received');
end;

procedure TForm3.OnConnAck(Sender: TObject; ReturnCode: integer);
begin
  mStatus.Lines.Add('Connection Acknowledged, Return Code: ' + IntToStr(Ord(ReturnCode)));
end;

procedure TForm3.OnConnError(Sender: TObject; ErrMessage: String);
begin
  mStatus.Lines.Add('Connection Error!');
end;

procedure TForm3.OnDisconnect(Sender: TObject);
begin
  mStatus.Lines.Add('Disconnect!');
end;

procedure TForm3.OnPingResp(Sender: TObject);
begin
  mStatus.Lines.Add('PING! PONG!');
end;

procedure TForm3.btnPingClick(Sender: TObject);
begin
  fMQTTClient.PINGREQ;
end;

procedure TForm3.btnPublishClick(Sender: TObject);
begin
  fMQTTClient.PUBLISH('/dev/test', '(1) ' + TimeToStr(now), chkRetain.IsChecked);
  fMQTTClient.PUBLISH('/dev/test2', '(2) ' + TimeToStr(now), chkRetain.IsChecked);
end;

procedure TForm3.btnSub1Click(Sender: TObject);
begin
  fMQTTClient.SUBSCRIBE('/dev/test');
end;

procedure TForm3.btnSub2Click(Sender: TObject);
begin
  fMQTTClient.SUBSCRIBE('/dev/test2');
end;

procedure TForm3.btnStartClick(Sender: TObject);
begin
  fMQTTClient := TMQTTClient.Create('192.168.1.11', 1883);
  try
    fMQTTClient.OnConnAck := OnConnAck;
    fMQTTClient.OnConnError := OnConnError;
    fMQTTClient.OnPingResp := OnPingResp;
    fMQTTClient.OnPublish := OnPublish;
    fMQTTClient.OnSubAck := OnSubAck;
    fMQTTClient.OnUnSubAck := OnUnSubAck;
    fMQTTClient.OnDisconnect := OnDisconnect;
    fMQTTClient.Start;
  except
    FreeAndNil(fMQTTClient);
    raise;
  end;
end;

procedure TForm3.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if Assigned(fMQTTClient) then
  begin
    fMQTTClient.Terminate;
    fMQTTClient.WaitFor;
    fMQTTClient.Free;
  end;
end;

end.
