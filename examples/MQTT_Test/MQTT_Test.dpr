program MQTT_Test;

uses
  Forms,
  uMain in 'uMain.pas' {fMain},
  MQTT in '..\..\TMQTTClient\MQTT.pas';

{$R *.res}
{$C-}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'dfg';
  Application.CreateForm(TfMain, fMain);
  Application.Run;

end.

{
- Changes to correct UTF8 encoding in TBytes - using IndyTextEncoding_UTF8.GetString() instead of TEncoding.ANSI.GetString();
- Memory leak in HandleData() fixed through not raised exeption
- ThreadHandling optimized.
- Added Timer for KeepAlive-Ping to Client. Default 60 sec. Changing vtimeout via consructor possible.



Clean session is always 1
Will is alway 1
Will QoS is always 0
Retain is false



}
