unit Table;

interface

uses SysUtils, Generics.Collections, FieldVariable;

type
  /// <summary> Class to store file contents in</summary>
  TTable = class
    constructor Create;
    destructor Destroy; override;
  private
    /// <summary> List of field names, one by one</summary>
    FFieldKeys: TArray<string>;
    /// <summary> Fields storage</summary>
    FFields: TDictionary<string, TFieldVariable>;
    /// <summary> Data storage</summary>
    FData: TArray<TArray<string>>;
    // Get/set:
    function FGetField( Index: Integer ): TFieldVariable;
    function FGetFieldByName( Name: string ): TFieldVariable;
    function FGetData( Column, Row: Integer ): string; overload;
    function FGetData( Name: string; Row: Integer ): string; overload;
  public
    // Data access:
    property Data[ Column, Row: Integer ]: string read FGetData; default;
    property Data[ Name: string; Row: Integer ]: string read FGetData; default;
    // Fields parameters access:
    property Field[ Index: Integer ]: TFieldVariable read FGetField;
    property FieldByName[ Name: string ]: TFieldVariable read FGetFieldByName;
    // Fields by index:
    property FirstField: TFieldVariable index 0 read FGetField;
    property LastField: TFieldVariable index -1 read FGetField;

    {$region 'Summary'}
    /// <returns> Field index if added, -1 if AField not assigned, -2 if exists</returns>
    /// <remarks> Don't use after adding data</remarks>
    {$endregion}
    function AddField( const AField: TFieldVariable ): Integer;
    {$region 'Summary'}
    /// <returns> False on fail</returns>
    /// <remarks> Don't use before all fields are added</remarks>
    {$endregion}
    function ParseBuffer(const ABuffer: TBytes): Boolean;
    function FieldsCount: Integer;
    function RowsCount: Integer;
    {$region 'Summary'}
    /// <summary> Save all data to file</summary>
    /// <param name="IsCSV"> Screen values for correct CSV save: if any
    /// comma, new lines and quotes in values, add quotes on start and end,
    /// replcae inner quotes with double</param>
    {$endregion}
    procedure SaveToFile(FileName: string; Separator: string; IsCSV: Boolean );
  end;

implementation

uses Parser, Math, Classes;

{ TTable }

function TTable.AddField(const AField: TFieldVariable): Integer;
begin
  if not Assigned( AField ) then
    Exit( -1 );
  if FFields.ContainsKey( AField.Name ) then
    Exit( -2 );
  Insert( AField.Name, FFieldKeys, Length(FFieldKeys) );
  FFields.Add( AField.Name, AField );
  Result := High( FFieldKeys );
end;

constructor TTable.Create;
begin
  FFields := TDictionary<string, TFieldVariable>.Create;
end;

destructor TTable.Destroy;
begin
  var keys := FFields.Keys.ToArray;
  for var key in keys do
    if Assigned( FFields[key] ) then
      FreeAndNil( FFields[key] );
  FreeAndNil( FFields );

  Finalize( FFieldKeys );
  SetLength( FFieldKeys, 0 );

  Finalize( FData );
  SetLength( FData, 0 );
  inherited;
end;

function TTable.FGetFieldByName(Name: string): TFieldVariable;
begin
  if FFields.ContainsKey( Name ) then
    Result := FFields[ Name ]
  else
    Result := nil;
end;

function TTable.FieldsCount: Integer;
begin
  Result := Length( FFieldKeys );
end;

function TTable.FGetField(Index: Integer): TFieldVariable;
begin
  var idx := Index;
  if idx < 0 then
    idx := High( FFieldKeys );
  if idx < Length( FFieldKeys ) then
    Result := FGetFieldByName( FFieldKeys[idx] )
  else
    Result := nil;
end;

function TTable.FGetData(Name: string; Row: Integer): string;
begin
  for var i := Low( FFieldKeys ) to High( FFieldKeys ) do
    if FFieldKeys[i] = Name then
      Exit( FGetData(i, Row) );
end;


function TTable.FGetData(Column, Row: Integer): string;
begin
  if ( Row >= Low(FData) ) and ( Row <= High(FData) ) and
     ( Column >= Low(FData[Row]) ) and ( Column <= High(FData[Row]) ) then
    Result := FData[Row][Column]
  else
    Result := 'error';
end;

function TTable.ParseBuffer(const ABuffer: TBytes): Boolean;
begin
  if Length( FFieldKeys ) = 0 then
    Exit( False );
  var data: TArray<string>;
  SetLength( data, Length(FFieldKeys) );
  var currentPos: Integer := 0;
  for var i := Low( FFieldKeys ) to High( FFieldKeys ) do
  begin
    var field := FFields[ FFieldKeys[i] ];
    var buf: TBytes := Copy( ABuffer, currentPos, field.Length );
    case field.FieldType of
      ftReal:
        begin
          var val: Double := PDouble( @buf[0] )^;
          data[i] := FormatFloat( '0.' + string.Create('0', field.Digits), val );
          if Math.IsNan( val ) then
          begin
            var valSingle: Single := PSingle( @buf[0] )^;
            data[i] := FormatFloat( '0.' + string.Create('0', field.Digits), valSingle );
          end;
        end;
      ftInteger:
        begin
          var val: Cardinal := PCardinal( @buf[0] )^;
          data[i] := UIntToStr( val );
        end;
      ftString:
        begin
          SetString( data[i], PAnsiChar(@buf[0]), Length(buf) );
          DeleteTrailingSpaces( data[i] );
        end;
    end;
    Inc( currentPos, field.Length );
  end;
  Insert( data, FData, Length(FData) );
  Result := True;
end;

function TTable.RowsCount: Integer;
begin
  if Length( FFieldKeys ) = 0 then
    Exit( 0 );
  Result := Length( FData );
end;

procedure TTable.SaveToFile(FileName: string; Separator: string; IsCSV: Boolean );
  function PrepareStr( const AString: string ): string;
  begin
    if IsCSV and (
       AString.Contains(',') or
       AString.Contains(#13#10) or
       AString.Contains('"') ) then
    begin
      Result := '"' + StringReplace( AString, '"', '""', [rfReplaceAll] ) + '"';
    end
    else
      Result := AString;
  end;
begin
  var s := TStringList.Create;
  try
    if IsCSV and ( ExtractFileExt(FileName).ToUpper = '.CSV') then
      s.Add( 'sep=' + Separator );
    var line: string := EmptyStr;
    for var i := 0 to FieldsCount-1 do
      line := line + PrepareStr( Field[i].Name ) + Separator;
    s.Add( line );

    for var r := 0 to RowsCount-1 do
    begin
      line := EmptyStr;
      for var c := 0 to FieldsCount-1 do
        line := line + PrepareStr( FGetData(c, r) ) + Separator;
      s.Add( line );
    end;

    s.SaveToFile( FileName );
  finally
    s.Free;
  end;
end;

end.
