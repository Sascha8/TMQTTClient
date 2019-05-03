{
  -------------------------------------------------
  MQTTReadThread.pas -  Contains the socket receiving thread that is part of the
  TMQTTClient library (MQTT.pas).

  MIT License -  http://www.opensource.org/licenses/mit-license.php
  Copyright (c) 2009 Jamie Ingilby

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
  -------------------------------------------------
}

unit MQTTReadThread;

interface

uses
  SysUtils,
  Classes,
  System.AnsiStrings,
  IdTCPClient,
  IdGlobal;

type
  TBytes = array of Byte;

type
  TMQTTMessage = Record
    FixedHeader: Byte;
    RL: TBytes;
    Data: TidBytes;
  End;

Type
  TRxStates = (RX_FIXED_HEADER, RX_LENGTH, RX_DATA, RX_ERROR);

  TConnAckEvent = procedure(Sender: TObject; ReturnCode: integer) of object;
  TPublishEvent = procedure(Sender: TObject; topic, payload: ansistring) of object;
  TPingRespEvent = procedure(Sender: TObject) of object;
  TSubAckEvent = procedure(Sender: TObject; MessageID: integer; GrantedQoS: integer) of object;
  TUnSubAckEvent = procedure(Sender: TObject; MessageID: integer) of object;

  TMQTTReadThread = class(TThread)
  private
    fTCPClient: TIdTCPClient;
    fCurrentMessage: TMQTTMessage;
    // Events
    fConnAckEvent: TConnAckEvent;
    FPublishEvent: TPublishEvent;
    FPingRespEvent: TPingRespEvent;
    FSubAckEvent: TSubAckEvent;
    FUnSubAckEvent: TUnSubAckEvent;
    // This takes a 1-4 Byte Remaining Length bytes as per the spec and returns the Length value it represents
    // Increases the size of the Dest array and Appends NewBytes to the end of DestArray
    // Takes a 2 Byte Length array and returns the length of the ansistring it preceeds as per the spec.
    function BytesToStrLength(LengthBytes: TBytes): integer;
    // This is our data processing and event firing command. To be called via Synchronize.
    procedure HandleData;
  protected
    procedure Execute; override;
  public
    constructor Create(Socket: TIdTCPClient);
    property OnConnAck: TConnAckEvent read fConnAckEvent write fConnAckEvent;
    property OnPublish: TPublishEvent read FPublishEvent write FPublishEvent;
    property OnPingResp: TPingRespEvent read FPingRespEvent write FPingRespEvent;
    property OnSubAck: TSubAckEvent read FSubAckEvent write FSubAckEvent;
    property OnUnSubAck: TUnSubAckEvent read FUnSubAckEvent write FUnSubAckEvent;
  end;

implementation

uses
  MQTT,
  IdStackConsts;

{ TMQTTReadThread }

constructor TMQTTReadThread.Create(Socket: TIdTCPClient);
begin
  inherited Create(true);
  fTCPClient := Socket;
  FreeOnTerminate := False;
end;

procedure TMQTTReadThread.Execute;
var
  rxState: TRxStates;
  remainingLength: integer;
  digit: integer;
  multiplier: integer;
begin
  rxState := RX_FIXED_HEADER;
  while not Terminated do
  begin
    case rxState of
      RX_FIXED_HEADER:
        begin
          multiplier := 1;
          remainingLength := 0;
          fCurrentMessage.Data := nil;
          // CurrentMessage.FixedHeader := FPSocket^.RecvByte(1000);
          try
            if fTCPClient.IOHandler.CheckForDataOnSource(1000) then
            begin
              fCurrentMessage.FixedHeader := fTCPClient.IOHandler.ReadByte;
              rxState := RX_LENGTH;
            end
            else
            begin
              Continue;
            end;
          except
            rxState := RX_ERROR
          end;

          // if (FPSocket^.LastError = Id_WSAETIMEDOUT { ESysETIMEDOUT } ) then
          // Continue;
          // if (FPSocket^.LastError <> 0) then
          // rxState := RX_ERROR
          // else
          // rxState := RX_LENGTH;
        end;
      RX_LENGTH:
        begin
          // digit := FPSocket^.RecvByte(1000);
          try
            digit := fTCPClient.IOHandler.ReadByte;
            remainingLength := remainingLength + (digit and 127) * multiplier;
            if (digit and 128) > 0 then
            begin
              multiplier := multiplier * 128;
              rxState := RX_LENGTH;
            end
            else
            begin
              rxState := RX_DATA;
            end;
          except
            rxState := RX_ERROR;
            Continue;
          end;
          // if (FPSocket^.LastError = Id_WSAETIMEDOUT { ESysETIMEDOUT } ) then
          // Continue;
          // if (FPSocket^.LastError <> 0) then
          // rxState := RX_ERROR
          // else
          // begin
          // remainingLength := remainingLength + (digit and 127) * multiplier;
          // if (digit and 128) > 0 then
          // begin
          // multiplier := multiplier * 128;
          // rxState := RX_LENGTH;
          // end
          // else
          // rxState := RX_DATA;
          // end;
        end;
      RX_DATA:
        begin
          SetLength(fCurrentMessage.Data, remainingLength);

          // FPSocket^.RecvBufferEx(Pointer(CurrentMessage.Data), remainingLength, 1000);
          // if (FPSocket^.LastError <> 0) then
          // rxState := RX_ERROR
          // else
          // begin
          // Synchronize(HandleData);
          // rxState := RX_FIXED_HEADER;
          // end;
          try
            fTCPClient.IOHandler.ReadBytes(fCurrentMessage.Data, remainingLength, False);
            Synchronize(HandleData);
            rxState := RX_FIXED_HEADER;
          except
            rxState := RX_ERROR;
          end;
          Continue;
        end;
      RX_ERROR:
        begin
          sleep(1000);
        end;
    end;
  end;
end;

procedure TMQTTReadThread.HandleData;
var
  MessageType: Byte;
  DataLen: integer;
  QoS: integer;
  topic: ansistring;
  payload: ansistring;
  ResponseVH: TBytes;
  ConnectReturn: integer;
begin
  if (fCurrentMessage.FixedHeader <> 0) then
  begin
    MessageType := fCurrentMessage.FixedHeader shr 4;

    if (MessageType = Ord(MQTT.CONNACK)) then
    begin
      // Check if we were given a Connect Return Code.
      ConnectReturn := 0;
      // Any return code except 0 is an Error
      if ((Length(fCurrentMessage.Data) > 0) and (Length(fCurrentMessage.Data) < 4)) then
      begin
        ConnectReturn := fCurrentMessage.Data[1];
        Exception.Create('Connect Error Returned by the Broker. Error Code: ' +
          IntToStr(fCurrentMessage.Data[1]));
      end;
      if Assigned(OnConnAck) then
        OnConnAck(Self, ConnectReturn);
    end
    else
      if (MessageType = Ord(MQTT.PUBLISH)) then
    begin
      // Read the Length Bytes
      DataLen := BytesToStrLength(Copy(TBytes(fCurrentMessage.Data), 0, 2));
      // Get the Topic
      // SetString(topic, PChar(@CurrentMessage.Data[2]), DataLen);
      SetString(topic, PAnsiChar(@fCurrentMessage.Data[2]), DataLen); // dteti
      // Get the Payload
      // SetString(payload, PChar(@CurrentMessage.Data[2 + DataLen]),
      // (Length(CurrentMessage.Data) - 2 - DataLen));
      SetString(payload, PAnsiChar(@fCurrentMessage.Data[2 + DataLen]),
        (Length(fCurrentMessage.Data) - 2 - DataLen)); // dteti
      if Assigned(OnPublish) then
        OnPublish(Self, topic, payload);
    end
    else
      if (MessageType = Ord(MQTT.SUBACK)) then
    begin
      // Reading the Message ID
      ResponseVH := Copy(TBytes(fCurrentMessage.Data), 0, 2);
      DataLen := BytesToStrLength(ResponseVH);
      // Next Read the Granted QoS
      QoS := 0;
      if (Length(fCurrentMessage.Data) - 2) > 0 then
      begin
        ResponseVH := Copy(TBytes(fCurrentMessage.Data), 2, 1);
        QoS := ResponseVH[0];
      end;
      if Assigned(OnSubAck) then
        OnSubAck(Self, DataLen, QoS);
    end
    else
      if (MessageType = Ord(MQTT.UNSUBACK)) then
    begin
      // Read the Message ID for the event handler
      ResponseVH := Copy(TBytes(fCurrentMessage.Data), 0, 2);
      DataLen := BytesToStrLength(ResponseVH);
      if Assigned(OnUnSubAck) then
        OnUnSubAck(Self, DataLen);
    end
    else
      if (MessageType = Ord(MQTT.PINGRESP)) then
    begin
      if Assigned(OnPingResp) then
        OnPingResp(Self);
    end;
  end;
end;

function TMQTTReadThread.BytesToStrLength(LengthBytes: TBytes): integer;
begin
  Assert(Length(LengthBytes) = 2,
    'UTF-8 Length Bytes preceeding the text must be 2 Bytes in Legnth');

  Result := 0;
  Result := LengthBytes[0] shl 8;
  Result := Result + LengthBytes[1];
end;

end.
