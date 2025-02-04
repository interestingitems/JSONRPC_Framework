program JSONRPC.ServerIndy;

{$APPTYPE CONSOLE}
{$WARN DUPLICATE_CTOR_DTOR OFF}

uses
  System.SysUtils,
  System.Types,
  System.Classes,
  System.JSON,
  JSONRPC.Server.Consts in '..\Server\JSONRPC.Server.Consts.pas',
  JSONRPC.User.SomeTypes in '..\Common\JSONRPC.User.SomeTypes.pas',
  JSONRPC.RIO in '..\Common\JSONRPC.RIO.pas',
  JSONRPC.InvokeRegistry in '..\Common\JSONRPC.InvokeRegistry.pas',
  JSONRPC.Common.Types in '..\Common\JSONRPC.Common.Types.pas',
  JSONRPC.Common.Consts in '..\Common\JSONRPC.Common.Consts.pas',
  JSONRPC.JsonUtils in '..\Common\JSONRPC.JsonUtils.pas',
  JSONRPC.ServerBase.Runner in '..\Server\JSONRPC.ServerBase.Runner.pas',
  JSONRPC.CustomServerIdHTTP.Runner in '..\Server\JSONRPC.CustomServerIdHTTP.Runner.pas',
  JSONRPC.Common.RecordHandlers in '..\Common\JSONRPC.Common.RecordHandlers.pas',
  JSONRPC.Server.JSONRPCHTTPServer in '..\Server\JSONRPC.Server.JSONRPCHTTPServer.pas',
  JSONRPC.User.ServerImpl in 'JSONRPC.User.ServerImpl.pas';

{$R *.res}

procedure WritePrompt; inline;
begin
  Write(cArrow);
end;

procedure WriteCommands;
begin
  Writeln(sCommands);
  WritePrompt;
end;

procedure WriteStatus(const AServerRunner: TCustomJSONRPCServerRunner);
begin
//  Writeln(sIndyVersion + AServerRunner.Version);
  Writeln(sActive + AServerRunner.Active.ToString(TUseBoolStrs.True));
  Writeln(sPort + AServerRunner.Port.ToString);
  WritePrompt;
end;

procedure RunServer(APort: Integer);
var
  LServer: TCustomJSONRPCServerRunner;
  LResponse: string;
begin
  WriteCommands;
  LServer := TJSONRPCServerIdHTTPRunner.Create; // Match the runner type with the client's
  LServer.Host := '0.0.0.0';
  LServer.Port := 8083;

  LServer.OnNotifyPortSet := procedure(const APort: Integer)
  begin
    Writeln(Format(sPortISet, [APort]));
    WritePrompt;
  end;
  LServer.OnNotifyPortInUse := procedure(const APort: Integer)
  begin
    Writeln(Format(sPortInUse, [APort]));
    WritePrompt;
  end;
  LServer.OnNotifyServerIsActive := procedure(const AServerRunner: TCustomJSONRPCServerRunner)
  begin
    WriteLn(Format(sServerStarted, [AServerRunner.Port]));
    WritePrompt;
  end;
  LServer.OnNotifyServerIsInactive := procedure(const AServerRunner: TCustomJSONRPCServerRunner)
  begin
    WriteLn(sServerStopped);
    WritePrompt;
  end;
  LServer.OnNotifyServerIsAlreadyRunning := procedure(const AServerRunner: TCustomJSONRPCServerRunner)
  begin
    Writeln(sServerAlreadyRunning);
    WritePrompt;
  end;

  LServer.OnDispatchedJSONRPC := procedure (const AJSONRequest: string)
  begin
    WriteLn('Dispatched JSON RPC: ', AJSONRequest);
  end;

  LServer.OnLogIncomingJSONRequest := procedure (const AJSONRequest: string)
  begin
    WriteLn('Received JSON RPC: ', AJSONRequest);
  end;

  LServer.OnLogOutgoingJSONResponse := procedure (const AJSONResponse: string)
  begin
    WriteLn('Sent JSON RPC: ', AJSONResponse);
  end;

  try
    LServer.Port := APort;
    LResponse := cCommandStart;
    var LReadLined := False;
    while True do
    begin
      if LResponse = '' then
        begin
          Readln(LResponse);
          LReadLined := True;
        end;
      if LResponse = '' then
        begin
          WritePrompt;
          Continue;
        end;
      // If the command is not entered by the user, do a WriteLn first
      if not LReadLined then
        WriteLn;
      LReadLined := False;
      LResponse := LowerCase(LResponse);
      if LResponse.StartsWith(cCommandSetPort) then
        begin
          if LServer.Active then
            begin
              WriteLn('- Cannot change port while server is active!');
              WriteLn('- Stop the server first!');
              WritePrompt;
            end else
            begin
              Delete(LResponse, 1, Length(cCommandSetPort));
              LResponse := Trim(LResponse);
              LServer.Port := LResponse.ToInteger // SetPort(LServer, LResponse)
            end;
        end
      else if SameText(LResponse, cCommandStart) then
        begin
          LServer.StartServer(APort);
          LResponse := '';
        end
      else if SameText(LResponse, cCommandStatus) then
        WriteStatus(LServer)
      else if SameText(LResponse, cCommandStop) then
        begin
          LServer.StopServer;
        end
      else if SameText(LResponse, cCommandHelp) then
        WriteCommands
      else if SameText(LResponse, cCommandExit) or SameText(LResponse, cCommandQUit) then
        begin
          if LServer.Active then
            begin
              LServer.StopServer;
            end;
          Break;
        end else
      begin
        Writeln(sInvalidCommand);
        WritePrompt;
      end;
      LResponse := '';
    end;
  finally
    LServer.Free;
  end;
end;

procedure RunJSONRPCServer;
var
  LPort: Integer;
begin
  LPort := 8083;
  try
    {$IF DECLARED(WebRequestHandler)}
    if WebRequestHandler <> nil then
      begin
        WebRequestHandler.WebModuleClass := WebModuleClass;
        SetOnDispatchedJSONRPC(procedure (const AJSONRequest: string)
        begin
          WriteLn('Dispatched JSON RPC: ', AJSONRequest);
        end);
        SetOnReceivedJSONRPC(procedure (const AJSONRequest: string)
        begin
          WriteLn('Received JSON RPC: ', AJSONRequest);
        end);
        SetOnSentJSONRPC(procedure (const AJSONResponse: string)
        begin
          WriteLn('Sent JSON RPC: ', AJSONResponse);
        end);
      end;
    {$ELSE}

    {$ENDIF}
    RunServer(LPort);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  RunJSONRPCServer;
end.
