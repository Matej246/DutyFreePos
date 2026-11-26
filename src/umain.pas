
unit uMain;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB, Forms, Controls,
  Graphics, Dialogs, StdCtrls;

type

  TfrmMain = class(TForm)
    btnProvjeri: TButton;
    edtBarkod: TEdit;
    Label1: TLabel;
    lblUputaBarkod: TLabel;
    lblStatusKarte: TLabel;
    lblProvjeraKarte: TLabel;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;

    procedure btnProvjeriClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label1Click(Sender: TObject);

  private
    function PoveziBazu: Boolean;

  public
    KartaID: Integer;
    PutnikID: Integer;
    LetID: Integer;
    NovcanikID: Integer;
    ImePutnika: String;
    BrojLeta: String;
    Odrediste: String;
    PorezniRezim: String;
    SaldoCenti: Int64;
  end;

var
  frmMain: TfrmMain;

implementation

uses
  uKupac;

{$R *.lfm}

// POVEZIVANJE S BAZOM
function TfrmMain.PoveziBazu: Boolean;
var
  PutanjaBaze: String;
begin
  Result := False;

  PutanjaBaze := ExpandFileName(
    ExtractFilePath(ParamStr(0)) +
    '..' + PathDelim + 'data' + PathDelim +
    'dutyfree.db');

  if not FileExists(PutanjaBaze) then
  begin
    ShowMessage('Baza nije pronađena!' +
      LineEnding + PutanjaBaze);
    Exit;
  end;

  try
    SQLite3Connection1.DatabaseName := PutanjaBaze;
    SQLite3Connection1.LoginPrompt := False;

    SQLTransaction1.Database := SQLite3Connection1;
    SQLite3Connection1.Transaction := SQLTransaction1;

    SQLQuery1.Database := SQLite3Connection1;
    SQLQuery1.Transaction := SQLTransaction1;

    SQLite3Connection1.Connected := True;

    Result := True;

  except
    on E: Exception do
      ShowMessage('GREŠKA PRI POVEZIVANJU:' +
        LineEnding + E.Message);
  end;
end;

// POKRETANJE PROGRAMA
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  edtBarkod.Text := '';

  btnProvjeri.Enabled := PoveziBazu;

  if btnProvjeri.Enabled then
    lblStatusKarte.Caption := 'Unesite barkod avionske karte'
  else
    lblStatusKarte.Caption := 'Baza nije povezana';
end;

// PROVJERA AVIONSKE KARTE
procedure TfrmMain.btnProvjeriClick(Sender: TObject);
var
  Barkod: String;
  i: Integer;
begin
  Barkod := Trim(edtBarkod.Text);

  // Provjera duljine
  if Length(Barkod) <> 14 then
  begin
    lblStatusKarte.Caption := 'Neispravan barkod!';
    ShowMessage('Barkod mora imati 14 znamenki!');
    Exit;
  end;

  // Provjera znamenki
  for i := 1 to Length(Barkod) do
  begin
    if not (Barkod[i] in ['0'..'9']) then
    begin
      lblStatusKarte.Caption := 'Neispravan barkod!';
      ShowMessage('Barkod smije sadržavati samo brojeve!');
      Exit;
    end;
  end;

  // Provjera karte u SQLite bazi
  try
    SQLQuery1.Close;

    if not SQLTransaction1.Active then
      SQLTransaction1.StartTransaction;

    SQLQuery1.SQL.Text :=
      'SELECT * FROM v_kupac_prijava ' +
      'WHERE barkod = :barkod';

    SQLQuery1.ParamByName('barkod').AsString := Barkod;

    SQLQuery1.Open;

    // Karta nije pronađena
    if SQLQuery1.IsEmpty then
    begin
      SQLQuery1.Close;
      SQLTransaction1.Commit;

      lblStatusKarte.Caption := 'Karta nije pronađena!';
      ShowMessage('Avionska karta ne postoji u bazi!');
      Exit;
    end;

    // Provjera statusa karte
    if SQLQuery1.FieldByName('status_karte').AsString
      <> 'AKTIVNA' then
    begin
      SQLQuery1.Close;
      SQLTransaction1.Commit;

      lblStatusKarte.Caption := 'Karta nije aktivna!';
      ShowMessage('Avionska karta nije aktivna!');
      Exit;
    end;

    // Dohvaćanje podataka iz baze
    KartaID :=
      SQLQuery1.FieldByName('karta_id').AsInteger;

    PutnikID :=
      SQLQuery1.FieldByName('putnik_id').AsInteger;

    LetID :=
      SQLQuery1.FieldByName('let_id').AsInteger;

    NovcanikID :=
      SQLQuery1.FieldByName('novcanik_id').AsInteger;

    ImePutnika :=
      SQLQuery1.FieldByName('ime').AsString + ' ' +
      SQLQuery1.FieldByName('prezime').AsString;

    BrojLeta :=
      SQLQuery1.FieldByName('broj_leta').AsString;

    Odrediste :=
      SQLQuery1.FieldByName('odrediste').AsString;

    PorezniRezim :=
      SQLQuery1.FieldByName('porezni_rezim').AsString;

    SaldoCenti :=
      SQLQuery1.FieldByName('saldo_centi').AsLargeInt;

    SQLQuery1.Close;
    SQLTransaction1.Commit;

  except
    on E: Exception do
    begin
      SQLQuery1.Close;

      if SQLTransaction1.Active then
        SQLTransaction1.Rollback;

      lblStatusKarte.Caption := 'Greška pri provjeri!';
      ShowMessage('GREŠKA:' + LineEnding + E.Message);
      Exit;
    end;
  end;

  // Karta je aktivna
  lblStatusKarte.Caption := 'Karta je valjana!';

  if not Assigned(frmKupac) then
    frmKupac := TfrmKupac.Create(Application);

  // Prijenos podataka na ekran trgovine
  frmKupac.lblPutnik.Caption :=
    'Putnik: ' + ImePutnika;

  frmKupac.lblLet.Caption :=
    'Let: ' + BrojLeta + ' - ' + Odrediste;

  frmKupac.lblPDV.Caption :=
    'PDV režim: ' + PorezniRezim;

  frmKupac.lblSaldo.Caption :=
    'DFC saldo: ' +
    FormatFloat('0.00', SaldoCenti / 100) + ' DFC';

  ShowMessage('KARTA JE VALJANA!' +
    LineEnding + 'Dobro došli, ' + ImePutnika + '!');

  frmKupac.Show;
  Hide;
end;

procedure TfrmMain.Label1Click(Sender: TObject);
begin

end;

end.

