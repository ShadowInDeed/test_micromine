unit FieldVariable;

interface

uses SysUtils;

type
  TFieldType = (  ftReal,     // R - вещественные числа
                  ftInteger,  // N - натуральные числа
                  ftString ); // C - символьные данные
  TFieldTypeHelper = record helper for TFieldType
    procedure FromChar( const Char: Char );
  end;

  TFieldVariable = class
    constructor Create( const Declaration: string );
    destructor Destroy; override;
  private
    FName: string;
    FType: TFieldType;
    FLength, FDigits: Integer;
  public
    property Name: string read FName;
    property FieldType: TFieldType read FType;
    property Length: Integer read FLength;
    property Digits: Integer read FDigits;
  end;

implementation

uses Parser;

{ TFieldTypeHelper }

procedure TFieldTypeHelper.FromChar( const Char: Char );
begin
  case Char of
    'R': Self := ftReal;
    'N': Self := ftInteger;
    'C': Self := ftString;
    else Self :=  ftString;
  end;
end;

{ TFieldVariable }

constructor TFieldVariable.Create(const Declaration: string);
begin
  if Declaration.Length < _NormalVarDeclLen then
    Exit;

  // Get name:
  FName := Copy( Declaration, 0, _NameLen );

  // Get type:
  FType.FromChar( Declaration[_NameLen + _TypeLen] );
  // Get length:
  if not TryStrToInt( Copy( Declaration, _NameLen + _TypeLen + 1, _LengthLen), FLength ) then
    FLength := 0;
  // Get digits:
  if not TryStrToInt( Copy( Declaration, _NameLen + _TypeLen + _LengthLen + 1, _DigitsLen), FDigits ) then
    FDigits := 0;

  if Declaration.Length = _ExtVarDeclLen then
    FName := Copy( Declaration, _NormalVarDeclLen + 2, _ExtraNameLen );

  // Delete end spaces in name:
  DeleteTrailingSpaces( FName );
end;

destructor TFieldVariable.Destroy;
begin

  inherited;
end;

end.
