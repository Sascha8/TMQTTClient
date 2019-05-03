{
  -------------------------------------------------
  MQTT.pas -  A Library for Publishing and Subscribing to messages from an MQTT Message
  broker such as the RSMB (http://alphaworks.ibm.com/tech/rsmb).

  MQTT - http://mqtt.org/
  Spec - http://publib.boulder.ibm.com/infocenter/wmbhelp/v6r0m0/topic/com.ibm.etools.mft.doc/ac10840_.htm

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

unit MQTT;

interface

uses
  SysUtils,
  Classes,
  IdBaseComponent,
  IdComponent,
  IdTCPConnection,
  IdTCPClient,
  IdGlobal;

type
  TBytes = array of Byte;

  TMQTTMessage = Record
    FixedHeader: Byte;
    RL: TBytes;
    Data: TidBytes;
  End;

  TRxStates = (RX_CONNECTION, RX_FIXED_HEADER, RX_LENGTH, RX_DATA, RX_ERROR);

  TConnAckEvent = procedure(Sender: TObject; ReturnCode: integer) of object;
  TPublishEvent = procedure(Sender: TObject; topic, payload: string) of object;
  TPingRespEvent = procedure(Sender: TObject) of object;
  TDisconnectEvent = procedure(Sender: TObject) of object;
  TConnError = procedure(Sender: TObject; ErrMessage: String) of object;
  TSubAckEvent = procedure(Sender: TObject; MessageID: integer; GrantedQoS: integer) of object;
  TUnSubAckEvent = procedure(Sender: TObject; MessageID: integer) of object;

  // Message type. 4 Bit unsigned.
  TMQTTMessageType = (
    Reserved0, // 0	Reserved
    CONNECT, // 1	Client request to connect to Broker
    CONNACK, // 2	Connect Acknowledgment
    PUBLISH, // 3	Publish message
    PUBACK, // 4	Publish Acknowledgment
    PUBREC, // 5	Publish Received (assured delivery part 1)
    PUBREL, // 6	Publish Release (assured delivery part 2)
    PUBCOMP, // 7	Publish Complete (assured delivery part 3)
    SUBSCRIBE, // 8	Client Subscribe request
    SUBACK, // 9	Subscribe Acknowledgment
    UNSUBSCRIBE, // 10	Client Unsubscribe request
    UNSUBACK, // 11	Unsubscribe Acknowledgment
    PINGREQ, // 12	PING Request
    PINGRESP, // 13	PING Response
    DISCONNECT, // 14	Client is Disconnecting
    Reserved15 // 15
    );

  TMQTTClient = class(TThread)
  private
    FClientID: string;
    FHostname: string;
    FPort: integer;
    FTCPClient: TIdTCPClient;
    FMessageID: integer;
    fCurrentMessage: TMQTTMessage;
    FConnAckEvent: TConnAckEvent;
    FPublishEvent: TPublishEvent;
    FPingRespEvent: TPingRespEvent;
    FSubAckEvent: TSubAckEvent;
    FUnSubAckEvent: TUnSubAckEvent;
    FDisconnectEvent: TDisconnectEvent;
    fConnError: TConnError;
    // Gets a next Message ID and increases the Message ID Increment
    function GetMessageID: TBytes;
    // Takes a string and converts to An Array of Bytes preceded by 2 Length Bytes.
    function StrToBytes(str: string; perpendLength: boolean): TBytes;
    // Byte Array Helper Functions
    procedure AppendArray(var aDest: TBytes; aSource: Array of Byte);
    procedure CopyIntoArray(var aDestArray: Array of Byte; aSourceArray: Array of Byte;
      StartIndex: integer);
    // Message Component Build helpers
    function FixedHeader(aMessageType: TMQTTMessageType; aDup: Word; aQos: Word; aRetain: Word): Byte;
    // Calculates the Remaining Length bytes of the FixedHeader as per the spec.
    function RemainingLength(aMessageLength: integer): TBytes;
    // Variable Header per command creation funcs
    function VariableHeaderConnect(aKeepAlive: Word): TBytes;
    function VariableHeaderPublish(aTopic: string): TBytes;
    function VariableHeaderSubscribe: TBytes;
    function VariableHeaderUnsubscribe: TBytes;
    // Helper Function - Puts the seperate component together into an Array of Bytes for transmission
    function BuildCommand(aFixedHead: Byte; aRemainL: TBytes; aVariableHead: TBytes;
      aPayload: Array of Byte): TBytes;
    // Internally Write the provided data to the Socket. Wrapper function.
    procedure SocketWrite(Data: TBytes);
    /// /
    function IsConnected: boolean;
    // This takes a 1-4 Byte Remaining Length bytes as per the spec and returns the Length value it represents
    // Increases the size of the Dest array and Appends NewBytes to the end of DestArray
    // Takes a 2 Byte Length array and returns the length of the ansistring it preceeds as per the spec.
    function BytesToStrLength(aLengthBytes: TBytes): integer;
    // This is our data processing and event firing command. To be called via Synchronize.
    procedure HandleData;
    procedure CONNECT;
    procedure DISCONNECT;
  protected
    procedure Execute; override;
  public
    function PUBLISH(aTopic: string; aPayload: string): boolean; overload;
    function PUBLISH(aTopic: string; aPayload: string; aRetain: boolean): boolean; overload;
    function SUBSCRIBE(aTopic: string): integer;
    function UNSUBSCRIBE(aTopic: string): integer;
    procedure PINGREQ;
    constructor Create(aHostname: string; aPort: integer); overload;
    destructor Destroy; override;
    property ClientID: string read FClientID write FClientID;
    property OnConnAck: TConnAckEvent read FConnAckEvent write FConnAckEvent;
    property OnPublish: TPublishEvent read FPublishEvent write FPublishEvent;
    property OnPingResp: TPingRespEvent read FPingRespEvent write FPingRespEvent;
    property OnSubAck: TSubAckEvent read FSubAckEvent write FSubAckEvent;
    property OnUnSubAck: TUnSubAckEvent read FUnSubAckEvent write FUnSubAckEvent;
    property OnDisconnect: TDisconnectEvent read FDisconnectEvent write FDisconnectEvent;
    property OnConnError: TConnError read fConnError write fConnError;
  end;

implementation

uses
  IdStack;

{ TMQTTClient }

{ *------------------------------------------------------------------------------
  Instructs the Client to try to connect to the server at TMQTTClient.Hostname and
  TMQTTClient.Port and then to send the initial CONNECT message as required by the
  protocol. Check for a CONACK message to verify successful connection.
  @return Returns whether the Data was written successfully to the socket.
  ------------------------------------------------------------------------------* }
procedure TMQTTClient.CONNECT;
var
  Data: TBytes;
  RL: TBytes;
  VH: TBytes;
  FH: Byte;
  lPayload: TBytes;
begin
  FH := FixedHeader(MQTT.CONNECT, 0, 0, 0);
  VH := VariableHeaderConnect(40);
  SetLength(lPayload, 0);
  AppendArray(lPayload, StrToBytes(FClientID, true));
  AppendArray(lPayload, StrToBytes('lwt', true));
  AppendArray(lPayload, StrToBytes(FClientID + ' died', true));
  RL := RemainingLength(Length(VH) + Length(lPayload));
  Data := BuildCommand(FH, RL, VH, lPayload);
  SocketWrite(Data);
end;

{ *------------------------------------------------------------------------------
  Sends the DISCONNECT packets and then Disconnects gracefully from the server
  which it is currently connected to.
  @return Returns whether the Data was written successfully to the socket.
  ------------------------------------------------------------------------------* }
procedure TMQTTClient.DISCONNECT;
var
  Data: TBytes;
begin
  SetLength(Data, 2);
  Data[0] := FixedHeader(MQTT.DISCONNECT, 0, 0, 0);
  Data[1] := 0;
  SocketWrite(Data);
  FTCPClient.DISCONNECT;
end;

procedure TMQTTClient.Execute;
var
  lRXState: TRxStates;
  lRemainingLength: integer;
  lDigit: integer;
  lMultiplier: integer;
begin
  lMultiplier := -1;
  lRemainingLength := -1;
  lRXState := RX_CONNECTION;
  while not Terminated do
  begin
    case lRXState of
      RX_CONNECTION:
        begin
          try
            FreeAndNil(FTCPClient);
          except
          end;
          FTCPClient := TIdTCPClient.Create(nil);
          FTCPClient.ReuseSocket := TIdReuseSocket.rsFalse;
          FTCPClient.ConnectTimeout := 5000;
          FTCPClient.ReadTimeout := 2000;
          try
            FTCPClient.CONNECT(FHostname, FPort);
            CONNECT();
            lRXState := RX_FIXED_HEADER;
          except
            on E: Exception do
            begin
              if Assigned(fConnError) then
              begin
                fConnError(Self, E.Message);
              end;
              Sleep(1000);
              Continue;
            end;
          end;
        end;
      RX_FIXED_HEADER:
        begin
          lMultiplier := 1;
          lRemainingLength := 0;
          fCurrentMessage.Data := nil;
          try
            if FTCPClient.IOHandler.InputBufferIsEmpty then
            begin
              FTCPClient.IOHandler.CheckForDataOnSource(2000);
            end;
            if Terminated then
            begin
              Break;
            end;
            if not FTCPClient.IOHandler.InputBufferIsEmpty then
            begin
              fCurrentMessage.FixedHeader := FTCPClient.IOHandler.ReadByte;
              lRXState := RX_LENGTH;
            end;
            if not IsConnected then { on mobile disconnection is not detected using CheckForDataOnSource }
            begin
              lRXState := RX_CONNECTION;
              if Assigned(FDisconnectEvent) then
              begin
                FDisconnectEvent(Self);
              end;
            end;
          except
            on E: EIdSocketError do
            begin
              if E.LastError <> 10054 then
              // if fTCPClient.IOHandler.Connected then
              begin
                lRXState := RX_ERROR;
              end
              else
              begin
                lRXState := RX_CONNECTION;
                if Assigned(FDisconnectEvent) then
                begin
                  FDisconnectEvent(Self);
                end;
              end;
            end;
            on Ex: Exception do
            begin
              raise;
            end;
          end;

        end;
      RX_LENGTH:
        begin
          try
            lDigit := FTCPClient.IOHandler.ReadByte;
            lRemainingLength := lRemainingLength + (lDigit and 127) * lMultiplier;
            if (lDigit and 128) > 0 then
            begin
              lMultiplier := lMultiplier * 128;
              lRXState := RX_LENGTH;
            end
            else
            begin
              lRXState := RX_DATA;
            end;
          except
            lRXState := RX_ERROR;
          end;
        end;
      RX_DATA:
        begin
          SetLength(fCurrentMessage.Data, lRemainingLength);
          try
            FTCPClient.IOHandler.ReadBytes(fCurrentMessage.Data, lRemainingLength, False);
            lRXState := RX_FIXED_HEADER;
            Synchronize(HandleData);
          except
            lRXState := RX_ERROR;
          end;
        end;
      RX_ERROR:
        begin
          Sleep(1000);
          lRXState := RX_FIXED_HEADER;
        end;

    end;
  end;
end;

{ *------------------------------------------------------------------------------
  Sends a PINGREQ to the server informing it that the client is alice and that it
  should send a PINGRESP back in return.
  @return Returns whether the Data was written successfully to the socket.
  ------------------------------------------------------------------------------* }
procedure TMQTTClient.PINGREQ;
var
  FH: Byte;
  RL: Byte;
  Data: TBytes;
begin
  SetLength(Data, 2);
  FH := FixedHeader(MQTT.PINGREQ, 0, 0, 0);
  RL := 0;
  Data[0] := FH;
  Data[1] := RL;
  SocketWrite(Data);
end;

{ *------------------------------------------------------------------------------
  Publishes a message sPayload to the Topic on the remote broker with the retain flag
  defined as given in the 3rd parameter.
  @param Topic   The Topic Name of your message eg /station1/temperature/
  @param sPayload   The Actual Payload of the message eg 18 degrees celcius
  @param Retain   Should this message be retained for clients connecting subsequently
  @return Returns whether the Data was written successfully to the socket.
  ------------------------------------------------------------------------------* }
function TMQTTClient.PUBLISH(aTopic, aPayload: string; aRetain: boolean): boolean;
var
  Data: TBytes;
  FH: Byte;
  RL: TBytes;
  VH: TBytes;
  payload: TBytes;
begin
  Result := False;
  FH := FixedHeader(MQTT.PUBLISH, 0, 0, Ord(aRetain));
  VH := VariableHeaderPublish(aTopic);
  SetLength(payload, 0);
  AppendArray(payload, StrToBytes(aPayload, False));
  RL := RemainingLength(Length(VH) + Length(payload));
  Data := BuildCommand(FH, RL, VH, payload);
  SocketWrite(Data);
end;

{ *------------------------------------------------------------------------------
  Publishes a message sPayload to the Topic on the remote broker with the retain flag
  defined as False.
  @param Topic   The Topic Name of your message eg /station1/temperature/
  @param sPayload   The Actual Payload of the message eg 18 degrees celcius
  @return Returns whether the Data was written successfully to the socket.
  ------------------------------------------------------------------------------* }
function TMQTTClient.PUBLISH(aTopic, aPayload: string): boolean;
begin
  Result := PUBLISH(aTopic, aPayload, False);
end;

{ *------------------------------------------------------------------------------
  Subscribe to Messages published to the topic specified. Only accepts 1 topic per
  call at this point.
  @param Topic   The Topic that you wish to Subscribe to.
  @return Returns the Message ID used to send the message for the purpose of comparing
  it to the Message ID used later in the SUBACK event handler.
  ------------------------------------------------------------------------------* }
function TMQTTClient.SUBSCRIBE(aTopic: string): integer;
var
  Data: TBytes;
  FH: Byte;
  RL: TBytes;
  VH: TBytes;
  payload: TBytes;
begin
  FH := FixedHeader(MQTT.SUBSCRIBE, 0, 1, 0);
  VH := VariableHeaderSubscribe;
  Result := (Self.FMessageID - 1);
  SetLength(payload, 0);
  AppendArray(payload, StrToBytes(aTopic, true));
  // Append a new Byte to Add the Requested QoS Level for that Topic
  SetLength(payload, Length(payload) + 1);
  // Always Append Requested QoS Level 0
  payload[Length(payload) - 1] := $0;
  RL := RemainingLength(Length(VH) + Length(payload));
  Data := BuildCommand(FH, RL, VH, payload);
  SocketWrite(Data);
end;

{ *------------------------------------------------------------------------------
  Unsubscribe to Messages published to the topic specified. Only accepts 1 topic per
  call at this point.
  @param Topic   The Topic that you wish to Unsubscribe to.
  @return Returns the Message ID used to send the message for the purpose of comparing
  it to the Message ID used later in the UNSUBACK event handler.
  ------------------------------------------------------------------------------* }
function TMQTTClient.UNSUBSCRIBE(aTopic: string): integer;
var
  Data: TBytes;
  FH: Byte;
  RL: TBytes;
  VH: TBytes;
  payload: TBytes;
begin
  FH := FixedHeader(MQTT.UNSUBSCRIBE, 0, 0, 0);
  VH := VariableHeaderUnsubscribe;
  Result := (Self.FMessageID - 1);
  SetLength(payload, 0);
  AppendArray(payload, StrToBytes(aTopic, true));
  RL := RemainingLength(Length(VH) + Length(payload));
  Data := BuildCommand(FH, RL, VH, payload);
  SocketWrite(Data);
end;

{ *------------------------------------------------------------------------------
  Not Reliable. This is a leaky abstraction. The Core Socket components can only
  tell if the connection is truly Connected if they try to read or write to the
  socket. Therefore this reflects a boolean flag which is set in the
  TMQTTClient.Connect and .Disconnect methods.
  @return Returns whether the internal connected flag is set or not.
  ------------------------------------------------------------------------------* }
function TMQTTClient.IsConnected: boolean;
begin
  Result := Assigned(FTCPClient) and FTCPClient.Connected;
end;

{ *------------------------------------------------------------------------------
  Component Constructor,
  @param Hostname   Hostname of the MQTT Server
  @param Port   Port of the MQTT Server
  @return Instance
  ------------------------------------------------------------------------------* }
constructor TMQTTClient.Create(aHostname: string; aPort: integer);
begin
  inherited Create(true);
  Randomize;
  // Create a Default ClientID as a default. Can be overridden with TMQTTClient.ClientID any time before connection.
  FClientID := 'dMQTTClient' + IntToStr(Random(1000) + 1);
  FHostname := string(aHostname);
  FPort := aPort;
  FMessageID := 1;
  FTCPClient := nil;
end;

destructor TMQTTClient.Destroy;
begin
  if IsConnected then
  begin
    DISCONNECT;
  end;
  // FReadThread.Terminate;
  // FReadThread.Free;
  // FReadThread := nil;
  // Self.FSocket.Free;
  FreeAndNil(FTCPClient);
  inherited;
end;

function TMQTTClient.FixedHeader(aMessageType: TMQTTMessageType; aDup, aQos,
  aRetain: Word): Byte;
begin
  { Fixed Header Spec:
    bit	   |7 6	5	4	    | |3	     | |2	1	     |  |  0   |
    byte 1 |Message Type| |DUP flag| |QoS level|	|RETAIN| }
  Result := (Ord(aMessageType) * 16) + (aDup * 8) + (aQos * 2) + (aRetain * 1);
end;

function TMQTTClient.GetMessageID: TBytes;
begin
  Assert((Self.FMessageID > Low(Word)), 'Message ID too low');
  Assert((Self.FMessageID < High(Word)), 'Message ID has gotten too big');

  { Self.FMessageID is initialised to 1 upon TMQTTClient.Create
    The Message ID is a 16-bit unsigned integer, which typically increases by exactly
    one from one message to the next, but is not required to do so.
    The two bytes of the Message ID are ordered as MSB, followed by LSB (big-endian). }
  SetLength(Result, 2);
  Result[0] := Hi(Self.FMessageID);
  Result[1] := Lo(Self.FMessageID);
  Inc(Self.FMessageID);
end;

procedure TMQTTClient.HandleData;
var
  MessageType: Byte;
  DataLen: integer;
  Qos: integer;
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
        DataAsString := TEncoding.ANSI.GetString(fCurrentMessage.Data);
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
          Qos := 0;
          if (Length(fCurrentMessage.Data) - 2) > 0 then
          begin
            ResponseVH := Copy(TBytes(fCurrentMessage.Data), 2, 1);
            Qos := ResponseVH[0];
          end;
          if Assigned(OnSubAck) then
            OnSubAck(Self, DataLen, Qos);
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

procedure TMQTTClient.SocketWrite(Data: TBytes);
begin
  if not FTCPClient.IOHandler.Connected then
  begin
    raise Exception.Create('Not Connected');
  end;
  FTCPClient.IOHandler.write(TidBytes(Data), Length(Data));
end;

function TMQTTClient.StrToBytes(str: string; perpendLength: boolean): TBytes;
begin
  Result := TBytes(TEncoding.ANSI.GetBytes(str));

  { This is a UTF-8 hack to give 2 Bytes of Length followed by the string itself. }
  if perpendLength then
  begin
    Result := [0, 0] + Result;
    Result[0] := (Length(Result) - 2) div 256;
    Result[1] := (Length(Result) - 2) mod 256;
  end;
end;

function TMQTTClient.RemainingLength(aMessageLength: integer): TBytes;
var
  byteindex: integer;
  digit: integer;
begin
  SetLength(Result, 1);
  byteindex := 0;
  while (aMessageLength > 0) do
  begin
    digit := aMessageLength mod 128;
    aMessageLength := aMessageLength div 128;
    if aMessageLength > 0 then
    begin
      digit := digit or $80;
    end;
    Result[byteindex] := digit;
    if aMessageLength > 0 then
    begin
      Inc(byteindex);
      SetLength(Result, Length(Result) + 1);
    end;
  end;
end;

function TMQTTClient.VariableHeaderConnect(aKeepAlive: Word): TBytes;
const
  MQTT_PROTOCOL = 'MQIsdp';
  MQTT_VERSION = 3;
var
  Qos, Retain: Word;
  iByteIndex: integer;
  ProtoBytes: TBytes;
begin
  // Set the Length of our variable header array.
  SetLength(Result, 12);
  iByteIndex := 0;
  // Put out Protocol string in there.
  ProtoBytes := StrToBytes(MQTT_PROTOCOL, true);
  CopyIntoArray(Result, ProtoBytes, iByteIndex);
  Inc(iByteIndex, Length(ProtoBytes));
  // Version Number = 3
  Result[iByteIndex] := MQTT_VERSION;
  Inc(iByteIndex);
  // Connect Flags
  Qos := 0;
  Retain := 0;
  Result[iByteIndex] := 0;
  Result[iByteIndex] := (Retain * 32) + (Qos * 16) + (1 * 4) + (1 * 2);
  Inc(iByteIndex);
  Result[iByteIndex] := 0;
  Inc(iByteIndex);
  Result[iByteIndex] := aKeepAlive;
end;

function TMQTTClient.VariableHeaderPublish(aTopic: string): TBytes;
var
  BytesTopic: TBytes;
begin
  BytesTopic := StrToBytes(aTopic, true);
  SetLength(Result, Length(BytesTopic));
  CopyIntoArray(Result, BytesTopic, 0);
end;

function TMQTTClient.VariableHeaderSubscribe: TBytes;
begin
  Result := Self.GetMessageID;
end;

function TMQTTClient.VariableHeaderUnsubscribe: TBytes;
begin
  Result := Self.GetMessageID;
end;

procedure TMQTTClient.CopyIntoArray(var aDestArray: Array of Byte; aSourceArray: Array of Byte;
  StartIndex: integer);
begin
  Assert(StartIndex >= 0);
  Move(aSourceArray[0], aDestArray[StartIndex], Length(aSourceArray));
end;

procedure TMQTTClient.AppendArray(var aDest: TBytes; aSource: Array of Byte);
var
  DestLen: integer;
begin
  DestLen := Length(aDest);
  SetLength(aDest, DestLen + Length(aSource));
  Move(aSource, aDest[DestLen], Length(aSource));
end;

function TMQTTClient.BuildCommand(aFixedHead: Byte; aRemainL: TBytes;
  aVariableHead: TBytes; aPayload: Array of Byte): TBytes;
var
  iNextIndex: integer;
begin
  // Attach Fixed Header (1 byte)
  iNextIndex := 0;
  SetLength(Result, 1);
  Result[iNextIndex] := aFixedHead;

  // Attach RemainingLength (1-4 bytes)
  iNextIndex := Length(Result);
  SetLength(Result, Length(Result) + Length(aRemainL));
  CopyIntoArray(Result, aRemainL, iNextIndex);

  // Attach Variable Head
  iNextIndex := Length(Result);
  SetLength(Result, Length(Result) + Length(aVariableHead));
  CopyIntoArray(Result, aVariableHead, iNextIndex);

  // Attach Payload.
  iNextIndex := Length(Result);
  SetLength(Result, Length(Result) + Length(aPayload));
  CopyIntoArray(Result, aPayload, iNextIndex);
end;

function TMQTTClient.BytesToStrLength(aLengthBytes: TBytes): integer;
begin
  Assert(Length(aLengthBytes) = 2);
  Result := aLengthBytes[0] shl 8;
  Result := Result + aLengthBytes[1];
end;

end.
