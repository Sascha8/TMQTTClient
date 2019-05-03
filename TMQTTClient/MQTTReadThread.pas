{
  -------------------------------------------------
  MQTTReadThread.pas -  Contains the socket receiving thread that is part of the
  TMQTTClient library (MQTT.pas).

  MIT License -  http://www.opensource.org/licenses/mit-license.php
  Original Copyright (c) 2009 Jamie Ingilby
  Copyright (c) 2019 Daniele Teti


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
  TRxStates = (RX_FIXED_HEADER, RX_LENGTH, RX_DATA, RX_ERROR, RX_DISCONNECTED);

  TConnAckEvent = procedure(Sender: TObject; ReturnCode: integer) of object;
  TPublishEvent = procedure(Sender: TObject; topic, payload: string) of object;
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
    fOwner: TObject;
    // This takes a 1-4 Byte Remaining Length bytes as per the spec and returns the Length value it represents
    // Increases the size of the Dest array and Appends NewBytes to the end of DestArray
    // Takes a 2 Byte Length array and returns the length of the ansistring it preceeds as per the spec.
    function BytesToStrLength(LengthBytes: TBytes): integer;
    // This is our data processing and event firing command. To be called via Synchronize.
    procedure HandleData;
  protected
    procedure Execute; override;
  public
    constructor Create(Owner: TObject; Socket: TIdTCPClient);
    property OnConnAck: TConnAckEvent read fConnAckEvent write fConnAckEvent;
    property OnPublish: TPublishEvent read FPublishEvent write FPublishEvent;
    property OnPingResp: TPingRespEvent read FPingRespEvent write FPingRespEvent;
    property OnSubAck: TSubAckEvent read FSubAckEvent write FSubAckEvent;
    property OnUnSubAck: TUnSubAckEvent read FUnSubAckEvent write FUnSubAckEvent;
  end;

implementation

uses
  IdStackConsts,
  IdException,
  IdStack,
  MQTT;

{ TMQTTReadThread }

constructor TMQTTReadThread.Create(Owner: TObject; Socket: TIdTCPClient);
begin
  inherited Create(true);
  fTCPClient := Socket;
  fOwner := Owner;
  FreeOnTerminate := False;
end;

procedure TMQTTReadThread.Execute;
var
  rxState: TRxStates;
  remainingLength: integer;
  digit: integer;
  multiplier: integer;
  lConnRetry: integer;
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
          try
            if fTCPClient.IOHandler.InputBufferIsEmpty then
            begin
              fTCPClient.IOHandler.CheckForDataOnSource(2000);
            end;
            if not fTCPClient.IOHandler.InputBufferIsEmpty then
            begin
              fCurrentMessage.FixedHeader := fTCPClient.IOHandler.ReadByte;
              rxState := RX_LENGTH;
            end;
          except
            on E: EIdSocketError do
            begin
              if E.LastError <> 10054 then
              // if fTCPClient.IOHandler.Connected then
              begin
                rxState := RX_ERROR;
              end
              else
              begin
                rxState := RX_DISCONNECTED;
              end;
            end;
            on Ex: Exception do
            begin
              raise;
            end;
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
            rxState := RX_FIXED_HEADER;
            Synchronize(HandleData);
          except
            rxState := RX_ERROR;
          end;
        end;
      RX_ERROR:
        begin
          Sleep(1000);
          rxState := RX_FIXED_HEADER;
        end;

      RX_DISCONNECTED:
        begin
          try
            Inc(lConnRetry);
            Sleep(1000);
            if lConnRetry < 5 then
            begin
              Continue;
            end;
            lConnRetry := 0;
            try
              fTCPClient.DisconnectNotifyPeer;
              fTCPClient.Disconnect;
            except
            end;
            // fTCPClient.Connect('127.0.0.1', 1883);
            TThread.Synchronize(nil,
              procedure
              begin
                try
                  if TMQTTClient(fOwner).Connect then
                  begin
                    rxState := RX_FIXED_HEADER;
                  end;
                except
                  lConnRetry := 0;
                end;
              end);
          except
            lConnRetry := 0;
          end;
        end;
    end;
  end;
end;

procedure TMQTTReadThread.HandleData;
var
  MessageType: Byte;
  DataLen: integer;
  QoS: integer;
  DataAsString, topic, payload: string;
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
        Delete(fCurrentMessage.Data, 0, 2);
        DataAsString := TEncoding.UTF8.GetString(fCurrentMessage.Data);
        topic := DataAsString.Substring(0, DataLen);
        payload := DataAsString.Substring(DataLen);
        // SetString(topic, PChar(@fCurrentMessage.Data[2]), DataLen);
        // Get the Payload
        // SetString(payload, PChar(@fCurrentMessage.Data[2 + DataLen]),
        // (Length(fCurrentMessage.Data) - 2 - DataLen));
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
