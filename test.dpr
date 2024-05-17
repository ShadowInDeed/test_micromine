program test;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Parser in 'Parser.pas',
  Table in 'Table.pas',
  FieldVariable in 'FieldVariable.pas';

procedure AskPressEnter( ManualMode: Boolean );
begin
  if not ManualMode then
    Exit;
  Writeln( 'Press Enter' );
  Readln;
end;

begin
  try
    if ParamCount < 3 then
      Writeln( 'Micromine file parser. Use parameters for fast parse and save:', sLineBreak,
       #9'Param 1: input file name, micromine file', sLineBreak,
       #9'Param 2: output file name, to save data to', sLineBreak,
       #9'Param 3: values separator, for example comma. If output file is CSV, "sep" ',
       'header will be added' );

    var InputFileName: string := EmptyStr;
    var OutputFileName: string := EmptyStr;
    var Separator: string := EmptyStr;
    /// <summary> Ask for return after final message if even one parameter was not set</summary>
    var ManualMode: Boolean := False;

    // Param 1: input file name - micromine file
    if ParamCount >= 1 then
      InputFileName := ParamStr( 1 );
    // Param 2: output file name - txt or csv or any, will be saved as text
    if ParamCount >= 2 then
      OutputFileName := ParamStr( 2 );
    // Param 3: data separator
    if ParamCount >= 3 then
      Separator := ParamStr( 3 );

    // Ask for input file name:
    if InputFileName.IsEmpty or not FileExists( InputFileName ) then
    repeat
      Write( 'Enter Micromine file name: ' );
      Readln( InputFileName );
      ManualMode := True;
    until not InputFileName.IsEmpty and FileExists( InputFileName );

    // Ask for output file name:
    if OutputFileName.IsEmpty then
      repeat
        Write( 'Enter output file name: ' );
        Readln( OutputFileName );
        ManualMode := True;
      until not OutputFileName.IsEmpty;

    // Ask for separtor:
    if Separator.IsEmpty then
      repeat
        Write( 'Enter values separator: ' );
        Readln( Separator );
        ManualMode := True;
      until not Separator.IsEmpty;

    /// <summary> Screen values in result file for correect CSV saving</summary>
    var forceCSV: Boolean := False;

    // File not CSV, separator is default decimal separator:
    if ( Separator = FormatSettings.DecimalSeparator ) and
       ( ExtractFileExt(OutputFileName).ToUpper <> '.CSV' ) then
    begin
      Write( 'Warning: output file is not CSV. Separator is the default decimal separator. ' );
      // Force CSV screen if not manual mode:
      if not ManualMode then
      begin
        Writeln( 'File will be saved with CSV data screening.' );
        forceCSV := True;
      end
      // Ask for user if manual mode:
      else
      begin
        var answer: string := EmptyStr;
        repeat
          Writeln( 'Do you want to use CSV data screening? y/n' );
          Readln( answer );
        until ( answer.ToUpper = 'Y' ) or ( answer.ToUpper = 'N' );
        forceCSV := ( answer.ToUpper = 'Y' );
      end;
    end;

    /// <summary> File parse result</summary>
    /// <remarks> See return codes <see cref="Parser.pas"/></remarks>
    var parseResult: Integer;
    var tab := TTable.Create;
    try
      // Parse file - main work:
      parseResult := TryParseFile( InputFileName, tab );
      // Handle result
      // .. success:
      if parseResult = PARSE_OK then
      begin
        tab.SaveToFile( OutputFileName, Separator,
          (forceCSV or (ExtractFileExt(OutputFileName).ToUpper = '.CSV')) );
        Writeln( 'Done and saved to ' + InputFileName );
      end
      // .. fail - report:
      else
      begin
        Writeln( 'Error while parsing file "', InputFileName, '": ' );
        Write( #9 );
        case parseResult of
          PARSE_ERROR_FILE_NOT_FOUND:
            Writeln( 'File not found.' );
          PARSE_ERROR_INVALID_DATA:
            Writeln( 'Invalid data. Maybe, file header length is not correct.' );
          PARSE_ERROR_INVALID_HEADER:
            Writeln( 'Invalid file header. No required keywords. Maybe, it''s not Micromine file.' );
          PARSE_ERROR_INVALID_META:
            Writeln( 'Invalid content: no place for metadata.' );
          PARSE_ERROR_NO_VARIABLES:
            Writeln( 'Invalid content: no variables or incorrect value.' );
          PARSE_ERROR_UNEXPECTED_VALUES_END:
            Writeln( 'Invalid content: unexpected variables declaration data.' );
          PARSE_ERROR_UNEXPECTED_EOF:
            Writeln( 'Invalid content: data section size is incorrect. Maybe, file is incomplete' );
          else
            Writeln( 'Unknown error. Something went wrong.' );
        end;
      end;
    finally
      tab.Free;
    end;
    // Press enter if manual mode:
    AskPressEnter( ManualMode );
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
