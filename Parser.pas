unit Parser;

interface

uses SysUtils, Classes, Table;

const
  // Error codes:
  PARSE_ERROR_FILE_NOT_FOUND  = -1;
  PARSE_ERROR_INVALID_DATA    = -2;
  PARSE_ERROR_INVALID_HEADER  = -3;
  PARSE_ERROR_INVALID_META    = -4;
  PARSE_ERROR_NO_VARIABLES    = -5;
  PARSE_ERROR_UNEXPECTED_VALUES_END = -6;
  PARSE_ERROR_UNEXPECTED_EOF = -7;
  PARSE_ERROR_UNHANDLED = $FF;
  PARSE_OK = 0;

  // Parse information:
  // .. header:
  _HeaderLen = 42;
  _HeaderMetaLen = $FFF;
  // .. fields declaration:
  _NameLen = 10;  // field name length
  _TypeLen = 1;   // field type length
  _LengthLen = 3; // field data length
  _DigitsLen = 3; // field digits after comma
  _ExtraNameLen = $FF;  // length of long field name, after "|" by default

  _MinLen = _NameLen + _TypeLen + _LengthLen + _DigitsLen;
var
  _NormalVarDeclLen: Integer = _MinLen;
  _ExtVarDeclLen: Integer = _MinLen + _ExtraNameLen + 1;
  _ExtVarDeclSeparator: Byte = $7C; // char "|"

{$region 'Summary'}
/// <summary> Parse file and save its contents to table</summary>
/// <param name="FileName"> Micromine file name, to load data from</param>
/// <param name="ATable"> Table, to save data to. Must be created</param>
{$endregion}
function TryParseFile( FileName: string; var ATable: TTable ): Integer;
procedure DeleteTrailingSpaces( var AString: string );

implementation

uses Math, FieldVariable;

procedure DeleteTrailingSpaces( var AString: string );
begin
  if AString.Length = 0 then
    Exit;
  for var i := AString.Length downto 1 do
    if AString[i] <>  ' ' then
      Break
    else
      Delete( AString, i, 1 );
end;

function TryParseFile( FileName: string; var ATable: TTable ): Integer;
  function BytesToStr( const data: TBytes ): string;
  begin
    SetString( Result, PAnsiChar(@data[0]), Length(data) );
  end;

  function CheckHeader( const data: TBytes ): Boolean;
  begin
    var s: string := BytesToStr( data );
    Result := s.StartsWith( 'THIS IS MICROMINE EXTENDED DATA FILE!' ) ;
  end;

  function GetVarsCount( const data: TBytes; out VarsEndPos: Integer ): Integer;
  begin
    var s: string := BytesToStr( data );
    var d := s.Split( [' ', #13#10] ); // space, \r\n
    if Length( d ) < 1 then
      Exit( 0 );
    if not TryStrToInt( d[0], Result ) then
      Result := 0;
    VarsEndPos := Pos( #13#10, s ) + 2;
  end;

begin
  if not FileExists( FileName ) then
    Exit( PARSE_ERROR_FILE_NOT_FOUND );

  // Load data:
  /// <summary>Raw data from file</summary>
  var data: TBytes;
  var f := TFileStream.Create( FileName, fmOpenRead );
  try
    SetLength(data, f.Size);
    f.ReadBuffer(Pointer(data)^, f.Size);
  finally
    f.Free;
  end;

  var len := Length( data );

  // 42 for file header text:
  if len < _HeaderLen then
    Exit( PARSE_ERROR_INVALID_DATA );

  if not CheckHeader( Copy(data, 0, _HeaderLen) ) then
    Exit( PARSE_ERROR_INVALID_HEADER );

  // FFF for header and meta:
  // FFF - last meta byte, 13 - min. len for "? VARIABLES\r\n"
  if len < _HeaderMetaLen + 13 then
    Exit( PARSE_ERROR_INVALID_META );

  // Get variables count:
  var varsEndPos: Integer := 0;
  var varsCount := GetVarsCount( Copy(data, _HeaderMetaLen+1, Min(30, len - _HeaderMetaLen + 1)), varsEndPos );
  if ( varsCount <= 0 ) or ( varsEndPos = 0 )  then
    Exit( PARSE_ERROR_NO_VARIABLES );

  Inc( varsEndPos, _HeaderMetaLen ); // variables data pos
  var currentPos := varsEndPos;
  var valuesSegmentLen: Integer := 0;

  try
    // Parse vars:
    for var i := 0 to varsCount-1 do
    begin
      var expectedLen: Integer := _NormalVarDeclLen; // normal var len
      // If | in the end - expanded name exists, add FF to normal len
      if data[currentPos + _NormalVarDeclLen] = _ExtVarDeclSeparator then
        expectedLen := _ExtVarDeclLen;

      // No more data - incorrect file:
      if len <= currentPos + expectedLen then
        Exit( PARSE_ERROR_UNEXPECTED_VALUES_END );

      // Add:
      var fieldDecl: string := BytesToStr(Copy(data, currentPos, expectedLen) );
      if ATable.AddField( TFieldVariable.Create( fieldDecl ) ) < 0 then
        Writeln( 'Can''t parse field "', fieldDecl, '". Data may be incorrect' )
      else
        Inc( valuesSegmentLen, ATable.LastField.Length );

      // Move next:
      Inc( currentPos, expectedLen + 2 ); // \r\n in the end
    end;
    Inc( valuesSegmentLen, 2 ); // \r\n in the end

    // Number of records to the end of file:
    var recordsCount: Integer := ( len - currentPos ) div valuesSegmentLen;
    if ( len - currentPos ) <> valuesSegmentLen * recordsCount  then
      Exit( PARSE_ERROR_UNEXPECTED_EOF );

    // Add data:
    for var i := 1 to recordsCount do
    begin
      var rawData: TBytes := Copy( data, currentPos, valuesSegmentLen * i);
      ATable.ParseBuffer( rawData );
      Inc( currentPos, valuesSegmentLen );
    end;

  except
    Exit( PARSE_ERROR_UNHANDLED );
  end;

  Result := 0;
end;

end.
