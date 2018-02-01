{-----------------------------------------------------------------------------
 Unit Name: PythonVersions
 Author:    Kiriakos
 Date:      PyScripter
 Purpose:   Discover and get info about Python versions
            Part of the Python for Delphi library

 History:
-----------------------------------------------------------------------------}

unit PythonVersions;

interface
Uses
  Classes;

type

  TPythonVersion = record
  private
    FDisplayName: string;
    FHelpFile: string;
    function GetDLLName: string;
    function GetSysArchitecture:string;
    function GetIsPython3K: Boolean;
    function GetHelpFile: string;
    function GetDisplayName: string;
  public
    IsRegistered: Boolean;
    IsAllUsers: Boolean;
    SysVersion: string;
    Version: string;
    DLLPath: string;
    InstallPath: string;
    PythonPath: string;
    procedure AssignTo(PythonEngine: TPersistent);
    property DLLName: string read GetDLLName;
    property SysArchitecture: string read GetSysArchitecture;
    property IsPython3K: Boolean read GetIsPython3K;
    property HelpFile: string read GetHelpFile write FHelpFile;
    property DisplayName: string read GetDisplayName write FDisplayName;
  end;

  TPythonVersions = array of TPythonVersion;

  (*
    Compares two Version strings and returns -1, 0, 1 depending on result
    The function result has the semantics of Delphi compare functions
    -1: A is bigger (newer), 0: equal versions, 1: B is bigger (newer)
  *)
  function  CompareVersions(A, B : String) : Integer;


  {$IFDEF MSWINDOWS}
  (* Checks whether a Python version is registered and returns the related info *)
  function GetRegisterPythonVersion(SysVersion: string;
    out PythonVersion: TPythonVersion): Boolean;
  (* Returns all registered Python versions *)
  function GetRegisteredPythonVersions : TPythonVersions;
  (* Returns the highest numbered registered Python version *)
  function GetLatestRegisteredPythonVersion(PythonVersion: TPythonVersion): Boolean;
  {$ENDIF}

implementation

Uses
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF}
  SysUtils,
  Math,
  Registry,
  PythonEngine;

{ TPythonVersion }

function TPythonVersion.GetDLLName: string;
begin
  {$IFDEF MSWINDOWS}
  Result := 'python' + SysVersion[1] + SysVersion[3] + '.dll';
  {$ELSE}
  Result := 'libpython' + SysVersion + '.so';
  {$ENDIF}
end;

function TPythonVersion.GetSysArchitecture: string;
begin
  Result := '';
  {$IFDEF CPUX64}
  Result := '64bit';
  {$ENDIF}
  {$IFDEF CPU64}
  Result := '64bit';
  {$ENDIF}
  {$IFDEF CPU64bits}
  Result := '64bit';
  {$ENDIF}
  if Result = '' then
    Result := '32bit';
end;

procedure TPythonVersion.AssignTo(PythonEngine: TPersistent);
begin
  if PythonEngine is TPythonEngine then begin
    TPythonEngine(PythonEngine).UseLastKnownVersion := False;
    TPythonEngine(PythonEngine).RegVersion := SysVersion;
    TPythonEngine(PythonEngine).DllName := DLLName;
    TPythonEngine(PythonEngine).DllPath := DLLPath;
  end;
end;

function TPythonVersion.GetDisplayName: string;
begin
  Result := FDisplayName;
  if Result = '' then
    Result := Format('Python %s (%s)', [SysVersion, SysArchitecture]);
end;

function TPythonVersion.GetHelpFile: string;
var
  PythonHelpFilePath: string;
  Res: Integer;
  SR: TSearchRec;
begin
  Result := FHelpFile;
  // for unregistered Python
  if (Result = '') and (InstallPath <> '') then
  begin
    PythonHelpFilePath := InstallPath + '\Doc\python*.chm';
    Res := FindFirst(PythonHelpFilePath, faAnyFile, SR);
    if Res = 0 then
      Result := InstallPath + '\Doc\' + SR.Name;
    FindClose(SR);
  end;
end;

function TPythonVersion.GetIsPython3K: Boolean;
begin
  try
    Result := StrToInt(SysVersion[1]) >= 3;
  except
    Result := False;
  end;
end;

function  CompareVersions(A, B : String) : Integer;

  function GetNextNumber(var Version: string): Integer;
  var
    P: Integer;
    S: string;
  begin
    P := Pos('.', Version);
    if P > 0 then
    begin
      S := Copy(Version, 1, P - 1);
      Version := Copy(Version, P + 1, Length(Version) - P);
    end
    else
    begin
      S := Version;
      Version := '';
    end;
    Result := StrToIntDef(S, 0)
  end;

var
  N1, N2: Integer;
begin
  Result := 0;
  repeat
    N1 := GetNextNumber(A);
    N2 := GetNextNumber(B);
    if N2 > N1 then
    begin
      Result := 1;
      Exit;
    end
    else
    if N2 < N1 then
    begin
      Result := -1;
      Exit;
    end
  until (A = '') and (B = '');
end;

{$IFDEF MSWINDOWS}
function GetRegisterPythonVersion(SysVersion: string;
  out PythonVersion: TPythonVersion): Boolean;
  // Python provides for All user and Current user installations
  // All User installations place the Python DLL in the Windows System directory
  // and write registry info to HKEY_LOCAL_MACHINE
  // Current User installations place the DLL in the install path and
  // the registry info in HKEY_CURRENT_USER.
  // Hence, for Current user installations we need to try and find the install path
  // since it may not be on the system path.

  // The above convension was changed in Python 3.5.  Now even for all user
  // installations the dll is located at the InstallPath.
  // Also from version 3.5 onwards 32 bit version have a suffix -32 e.g. "3.6-32"
  // See also PEP 514

  function ReadFromRegistry(Root: HKEY; key: string): Boolean;
  begin
    Result := False;
    try
      with TRegistry.Create(KEY_READ and not KEY_NOTIFY) do
        try
          RootKey := Root;
          if OpenKey(Key + '\InstallPath', False) then begin
            PythonVersion.InstallPath := ReadString('');
            if PythonVersion.IsAllUsers and (CompareVersions(SysVersion, '3.5') > 0) then
              PythonVersion.DLLPath := ''
            else
              PythonVersion.DLLPath := PythonVersion.InstallPath;
            CloseKey;
          end;
          Result := PythonVersion.InstallPath <> '';
          if not Result then Exit;

          if OpenKey(Key, False) then begin
            PythonVersion.DisplayName := ReadString('DisplayName');
            PythonVersion.Version := ReadString('Version');
            CloseKey;
          end;
          if OpenKey(Key + '\PythonPath', False) then begin
            PythonVersion.PythonPath := ReadString('');
            CloseKey;
          end;
          if OpenKey(Key + '\Help\Main Python Documentation', False) then begin
            PythonVersion.HelpFile := ReadString('');
            CloseKey;
          end;
        finally
          Free;
        end;
    except
    end;

  end;

var
  key: string;
  VersionSuffix: string;
begin
  // Initialize PythohVersion
  Finalize(PythonVersion);
  FillChar(PythonVersion, SizeOf(TPythonVersion), 0);

  VersionSuffix := '';
{$IFDEF CPUX86}
  if CompareVersions(SysVersion, '3.5') <= 0 then
    VersionSuffix := '-32';
{$ENDIF}
  key := Format('\Software\Python\PythonCore\%s%s', [SysVersion, VersionSuffix]);


  PythonVersion.SysVersion := SysVersion;
  // First try HKEY_CURRENT_USER as per PEP514
  PythonVersion.IsAllUsers := False;
  Result := ReadFromRegistry(HKEY_CURRENT_USER, key);

  //Then try for an all user installation
  if not Result then begin
    PythonVersion.IsAllUsers := True;
    Result := ReadFromRegistry(HKEY_LOCAL_MACHINE, key);
  end;

  PythonVersion.IsRegistered := Result;
end;

function GetRegisteredPythonVersions : TPythonVersions;
Var
  Count: Integer;
  I: Integer;
  PythonVersion : TPythonVersion;
begin
  Count := 0;
  SetLength(Result, High(PYTHON_KNOWN_VERSIONS) - COMPILED_FOR_PYTHON_VERSION_INDEX + 1);
  for I := High(PYTHON_KNOWN_VERSIONS) downto COMPILED_FOR_PYTHON_VERSION_INDEX do
    if GetRegisterPythonVersion(PYTHON_KNOWN_VERSIONS[I].RegVersion, PythonVersion) then
    begin
      Result[Count] := PythonVersion;
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function GetLatestRegisteredPythonVersion(PythonVersion: TPythonVersion): Boolean;
Var
  I: Integer;
begin
  Result := False;
  for I := High(PYTHON_KNOWN_VERSIONS) downto COMPILED_FOR_PYTHON_VERSION_INDEX do
  begin
    Result := GetRegisterPythonVersion(PYTHON_KNOWN_VERSIONS[I].RegVersion, PythonVersion);
    if Result then break;
  end;
end;

{$ENDIF}


end.
