program DropboxCleaner;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.Classes,
  System.IOUtils,
  System.Types,
  System.UITypes,
  System.SysUtils,
  RegularExpressions,
  Winapi.Windows,
  System.JSON;

var
  Regex: TRegEx;
  Matches: TMatchCollection;
  Groups: TGroupCollection;

function GetFileLastWriteTime(const FileName: String): TDateTime;
var
  SearchRec: TSearchRec;
  SystemTime: TSystemTime;
begin
  Result := 0;
  if (FindFirst(FileName, faAnyFile, SearchRec) = 0) then
  begin
    if FileTimeToSystemTime(SearchRec.FindData.ftLastWriteTime, SystemTime) then
      Result := SystemTimeToDateTime(SystemTime)
  end;
end;

function GetRealFileName: string;
begin
  Result := Groups.Item[1].Value + Groups.Item[6].Value;
end;

procedure ProcessFile(const Directory, ConflictedFileName: String);
var
  ConflictedFileFullName: String;
  ConflictedFileLastWriteTime: TDateTime;
  OriginalFileLastWriteTime: TDateTime;
  OriginalFileFullName: String;
begin
  OriginalFileFullName := IncludeTrailingPathDelimiter(Directory) + GetRealFileName;
  OriginalFileLastWriteTime := GetFileLastWriteTime(OriginalFileFullName);
  ConflictedFileFullName := IncludeTrailingPathDelimiter(Directory) + ConflictedFileName;
  ConflictedFileLastWriteTime := GetFileLastWriteTime(ConflictedFileFullName);
  if (OriginalFileLastWriteTime > ConflictedFileLastWriteTime) then
  begin
    Writeln('X ' + ConflictedFileFullName);
    System.SysUtils.DeleteFile(ConflictedFileFullName);
  end
  else
  begin
    Writeln('X ' + OriginalFileFullName);
    Writeln('R ' + ConflictedFileFullName);
    System.SysUtils.DeleteFile(OriginalFileFullName);
    System.SysUtils.RenameFile(ConflictedFileFullName, OriginalFileFullName);
  end;
end;

function IsConflictedFile(const FileName: String): Boolean;
begin
  Result := False;
  Matches := Regex.Matches(FileName);
  if (Matches.Count > 0) then
  begin
    Groups := Matches.Item[0].Groups;
    if (Groups.Count >= 5) then
      Result := Groups.Item[4].Value = ' 衝突的複本 ';
  end;
end;

procedure SearchConflictFiles(const Directory: String);
var
  SearchRec: TSearchRec;
begin
  if (FindFirst(IncludeTrailingPathDelimiter(Directory) + '*.*', faAnyFile, SearchRec) = 0) then
  begin
    if IsConflictedFile(SearchRec.Name) then
      ProcessFile(Directory, SearchRec.Name);
    while (FindNext(SearchRec) = 0) do
    begin
      if IsConflictedFile(SearchRec.Name) then
        ProcessFile(Directory, SearchRec.Name);
    end;
    System.SysUtils.FindClose(SearchRec);
  end;
end;

procedure SearchDirectory(const Directory: String);
var
  SearchRec: TSearchRec;
begin
  Writeln(Directory);
  SearchConflictFiles(Directory);
  if (FindFirst(IncludeTrailingPathDelimiter(Directory) + '*.*', faDirectory, SearchRec) = 0) then
  begin
    if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      SearchDirectory(SearchRec.Name);
    while (FindNext(SearchRec) = 0) do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        SearchDirectory(IncludeTrailingPathDelimiter(Directory) + SearchRec.Name);
    end;
    System.SysUtils.FindClose(SearchRec);
  end;
end;

function GetDropboxPath: String;
var
  LocalAppDataDirectory: string;
  InfoFileName: string;
  FileStream: TFileStream;
  StringStream: TStringStream;
  JSONObject: TJSONObject;
begin
  LocalAppDataDirectory := GetEnvironmentVariable('LOCALAPPDATA');
  InfoFileName := IncludeTrailingPathDelimiter(LocalAppDataDirectory) + 'Dropbox\info.json';
  if FileExists(InfoFileName) then
  begin
    FileStream := TFileStream.Create(InfoFileName, fmOpenRead);
    try
      StringStream := TStringStream.Create;
      StringStream.LoadFromStream(FileStream);
      JSONObject := TJSONObject.ParseJSONValue(StringStream.DataString) as TJSONObject;
      try
        Result := JSONObject.GetValue<string>('personal.path');
      finally
        JSONObject.Free;
      end;
      StringStream.Free;
    finally
      FileStream.Free;
    end;
  end
  else
    Result := '';
end;

procedure Execute;
var
  DropboxPath: string;
begin
  DropboxPath := GetDropboxPath;
  if (DropboxPath <> '') then
  begin
    Regex := TRegEx.Create('^(.*)( \(與)(.*)( 衝突的複本 )(.*\))([\.]*.*)$');
    SearchDirectory(DropboxPath);
  end;
end;

begin
  Execute;
  Readln;

end.
