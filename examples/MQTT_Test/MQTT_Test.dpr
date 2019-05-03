program MQTT_Test;

uses
  Forms,
  uMain in 'uMain.pas' {fMain} ,
  MQTT in '..\..\TMQTTClient\MQTT.pas',
  MQTTReadThread in '..\..\TMQTTClient\MQTTReadThread.pas';

{$R *.res}


begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfMain, fMain);
  Application.Run;

end.
