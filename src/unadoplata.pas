unit uNadoplata;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  Dialogs, StdCtrls, SQLDB;

type

  { TfrmNadoplata }

  TfrmNadoplata = class(TForm)
    btnIskoristiBon: TButton;
    edtKodBona: TEdit;
    lblUputaBon: TLabel;
    lblStatusNadoplate: TLabel;
    lblSaldoNadoplata: TLabel;
    lblNaslovNadoplata: TLabel;

    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btnIskoristiBonClick(Sender: TObject);

  private
    procedure OsvjeziSaldo;

  public

  end;

var
  frmNadoplata: TfrmNadoplata;

implementation

uses
  uMain, uKupac;

{$R *.lfm}

{ TfrmNadoplata }

// Pocetne postavke forme
procedure TfrmNadoplata.FormCreate(Sender: TObject);
begin
  Caption := 'DutyFree POS - Nadoplata DFC';

  edtKodBona.MaxLength := 14;
  edtKodBona.Text := '';

  lblStatusNadoplate.Caption :=
    'Unesite kod vaučera';

  OnShow := @FormShow;
end;

// Osvjezavanje prikaza salda
procedure TfrmNadoplata.OsvjeziSaldo;
begin
  lblSaldoNadoplata.Caption :=
    'Trenutni saldo: ' +
    FormatFloat('0.00', frmMain.SaldoCenti / 100) +
    ' DFC';

  if Assigned(frmKupac) then
    frmKupac.lblSaldo.Caption :=
      'DFC saldo: ' +
      FormatFloat('0.00', frmMain.SaldoCenti / 100) +
      ' DFC';
end;

// Prikaz forme
procedure TfrmNadoplata.FormShow(Sender: TObject);
begin
  edtKodBona.Text := '';

  lblStatusNadoplate.Font.Color := clBlack;

  lblStatusNadoplate.Caption :=
    'Unesite 14-znamenkasti kod vaučera';

  btnIskoristiBon.Enabled := True;

  OsvjeziSaldo;
end;

// Iskoristavanje vaučera
procedure TfrmNadoplata.btnIskoristiBonClick(
  Sender: TObject);
var
  Q: TSQLQuery;
  Kod: String;
  StatusVaucera: String;
  i: Integer;
  VaucerID: Int64;
  VrijednostCenti: Int64;
  StariSaldoCenti: Int64;
  NoviSaldoCenti: Int64;
  TransakcijaPokrenuta: Boolean;
begin

  Kod := Trim(edtKodBona.Text);

  // 1. Provjera duljine koda

  if Length(Kod) <> 14 then
  begin
    lblStatusNadoplate.Font.Color := clRed;

    lblStatusNadoplate.Caption :=
      'Neispravan kod vaučera!';

    ShowMessage(
      'Kod vaučera mora imati 14 znamenki!');

    Exit;
  end;

  // 2. Provjera znamenki

  for i := 1 to Length(Kod) do
  begin
    if not (Kod[i] in ['0'..'9']) then
    begin
      ShowMessage(
        'Kod smije sadržavati samo brojeve!');

      Exit;
    end;
  end;

  // 3. Provjera prijavljenog putnika

  if (frmMain.PutnikID <= 0) or
     (frmMain.NovcanikID <= 0) then
  begin
    ShowMessage('Putnik nije prijavljen!');
    Exit;
  end;

  btnIskoristiBon.Enabled := False;

  TransakcijaPokrenuta := False;

  Q := TSQLQuery.Create(nil);

  try
    try

      Q.Database := frmMain.SQLite3Connection1;
      Q.Transaction := frmMain.SQLTransaction1;

      if frmMain.SQLTransaction1.Active then
        raise Exception.Create(
          'Druga SQL transakcija je aktivna!');

      frmMain.SQLTransaction1.StartTransaction;

      TransakcijaPokrenuta := True;

      // 4. Pronalaženje vaučera

      Q.SQL.Text :=
        'SELECT v.vaucer_id, v.status, ' +
        'b.vrijednost_centi, b.aktivna ' +
        'FROM vauceri v ' +
        'JOIN vrste_bonova b ' +
        'ON b.vrsta_bona_id = v.vrsta_bona_id ' +
        'WHERE v.kod = :kod';

      Q.ParamByName('kod').AsString := Kod;

      Q.Open;

      if Q.IsEmpty then
        raise Exception.Create(
          'Vaučer nije pronađen!');

      VaucerID :=
        Q.FieldByName('vaucer_id').AsLargeInt;

      StatusVaucera :=
        Q.FieldByName('status').AsString;

      VrijednostCenti :=
        Q.FieldByName('vrijednost_centi').AsLargeInt;

      if StatusVaucera = 'ISKORISTEN' then
        raise Exception.Create(
          'Vaučer je već iskorišten!');

      if StatusVaucera = 'PONISTEN' then
        raise Exception.Create(
          'Vaučer je poništen!');

      if StatusVaucera <> 'NEISKORISTEN' then
        raise Exception.Create(
          'Vaučer nije valjan!');

      if Q.FieldByName('aktivna').AsInteger <> 1 then
        raise Exception.Create(
          'Vrsta bona nije aktivna!');

      Q.Close;

      // 5. Provjera karte i stvarnog salda

      Q.SQL.Text :=
        'SELECT saldo_centi ' +
        'FROM v_kupac_prijava ' +
        'WHERE karta_id = :karta ' +
        'AND putnik_id = :putnik ' +
        'AND novcanik_id = :novcanik ' +
        'AND status_karte = ''AKTIVNA''';

      Q.ParamByName('karta').AsInteger :=
        frmMain.KartaID;

      Q.ParamByName('putnik').AsInteger :=
        frmMain.PutnikID;

      Q.ParamByName('novcanik').AsInteger :=
        frmMain.NovcanikID;

      Q.Open;

      if Q.IsEmpty then
        raise Exception.Create(
          'Aktivna karta ili novčanik nisu pronađeni!');

      StariSaldoCenti :=
        Q.FieldByName('saldo_centi').AsLargeInt;

      Q.Close;

      NoviSaldoCenti :=
        StariSaldoCenti + VrijednostCenti;

      // 6. Oznacavanje vaučera kao iskoristenog

      Q.SQL.Text :=
        'UPDATE vauceri SET ' +
        'status = ''ISKORISTEN'', ' +
        'iskoristen_u = datetime(''now''), ' +
        'iskoristio_putnik_id = :putnik ' +
        'WHERE vaucer_id = :id ' +
        'AND status = ''NEISKORISTEN''';

      Q.ParamByName('putnik').AsInteger :=
        frmMain.PutnikID;

      Q.ParamByName('id').AsLargeInt :=
        VaucerID;

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Vaučer nije moguće iskoristiti!');

      // 7. Povecanje salda novcanika

      Q.SQL.Text :=
        'UPDATE novcanici ' +
        'SET saldo_centi = saldo_centi + :iznos ' +
        'WHERE novcanik_id = :id ' +
        'AND putnik_id = :putnik';

      Q.ParamByName('iznos').AsLargeInt :=
        VrijednostCenti;

      Q.ParamByName('id').AsInteger :=
        frmMain.NovcanikID;

      Q.ParamByName('putnik').AsInteger :=
        frmMain.PutnikID;

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Nadoplata novčanika nije uspjela!');

      // 8. Evidentiranje transakcije

      Q.SQL.Text :=
        'INSERT INTO transakcije_kredita (' +
        'novcanik_id, tip, iznos_centi, ' +
        'saldo_nakon_centi, vaucer_id) ' +
        'VALUES (:novcanik, ''NADOPLATA'', ' +
        ':iznos, :saldo, :vaucer)';

      Q.ParamByName('novcanik').AsInteger :=
        frmMain.NovcanikID;

      Q.ParamByName('iznos').AsLargeInt :=
        VrijednostCenti;

      Q.ParamByName('saldo').AsLargeInt :=
        NoviSaldoCenti;

      Q.ParamByName('vaucer').AsLargeInt :=
        VaucerID;

      Q.ExecSQL;

      // 9. Potvrda SQL transakcije

      frmMain.SQLTransaction1.Commit;

      TransakcijaPokrenuta := False;

    except
      on E: Exception do
      begin

        Q.Close;

        if TransakcijaPokrenuta and
           frmMain.SQLTransaction1.Active then
          frmMain.SQLTransaction1.Rollback;

        lblStatusNadoplate.Font.Color := clRed;

        lblStatusNadoplate.Caption :=
          'NADOPLATA NIJE USPJELA!';

        ShowMessage(E.Message);

        Exit;

      end;
    end;

    // 10. Osvjezavanje salda nakon uspjeha

    frmMain.SaldoCenti := NoviSaldoCenti;

    OsvjeziSaldo;

    lblStatusNadoplate.Font.Color := clGreen;

    lblStatusNadoplate.Caption :=
      'NADOPLATA USPJEŠNA!';

    edtKodBona.Text := '';

    ShowMessage(
      'NADOPLATA USPJEŠNA!' +
      LineEnding + LineEnding +
      'Dodano: ' +
      FormatFloat('0.00', VrijednostCenti / 100) +
      ' DFC' +
      LineEnding +
      'Novi saldo: ' +
      FormatFloat('0.00', NoviSaldoCenti / 100) +
      ' DFC'
    );

  finally

    Q.Free;

    btnIskoristiBon.Enabled := True;

  end;

end;

end.
