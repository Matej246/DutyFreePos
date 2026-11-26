unit uRacun;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  Dialogs, StdCtrls, SQLDB;

type

  { TfrmRacun }

  TfrmRacun = class(TForm)
    btnZavrsi: TButton;
    lblPreostaliSaldo: TLabel;
    lblPotrosenoRacun: TLabel;
    lblLetRacuna: TLabel;
    lblDatumRacuna: TLabel;
    lblBrojRacuna: TLabel;
    lblNaslovRacun: TLabel;
    lstStavkeRacuna: TListBox;

    procedure btnZavrsiClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

  private

  public

  end;

var
  frmRacun: TfrmRacun;

implementation

uses
  uMain, uKupac, uPotvrdaKupnje;

{$R *.lfm}

{ TfrmRacun }

// Otvaranje forme
procedure TfrmRacun.FormCreate(Sender: TObject);
begin
  Caption := 'DutyFree POS - Račun';
end;

// ZAVRŠI - zatvaranje računa
procedure TfrmRacun.btnZavrsiClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

// Učitavanje stvarnog računa iz baze
procedure TfrmRacun.FormShow(Sender: TObject);
var
  Q: TSQLQuery;
  UkupnoCenti: Int64;
  Naziv: String;
  Kolicina: Integer;
  CijenaCenti: Int64;
  StavkaCenti: Int64;
  TransakcijaPokrenuta: Boolean;
begin

  lstStavkeRacuna.Items.Clear;

  lblBrojRacuna.Caption := 'Broj računa: -';
  lblDatumRacuna.Caption := 'Datum kupnje: -';
  lblLetRacuna.Caption := 'Broj leta: -';
  lblPotrosenoRacun.Caption := 'Ukupno potrošeno: -';
  lblPreostaliSaldo.Caption := 'Preostali saldo: -';

  if not Assigned(frmPotvrdaKupnje) then
  begin
    ShowMessage('Račun nije dostupan!');
    Exit;
  end;

  if frmPotvrdaKupnje.RacunID <= 0 then
  begin
    ShowMessage('Neispravan identifikator računa!');
    Exit;
  end;

  // Podaci iz uspješne naplate

  lblBrojRacuna.Caption :=
    'Broj računa: ' +
    frmPotvrdaKupnje.BrojRacuna;

  lblDatumRacuna.Caption :=
    'Datum kupnje (UTC): ' +
    frmPotvrdaKupnje.DatumRacuna;

  lblLetRacuna.Caption :=
    'Let: ' +
    frmMain.BrojLeta + ' - ' +
    frmMain.Odrediste;

  lblPreostaliSaldo.Caption :=
    'Preostali saldo: ' +
    FormatFloat(
      '0.00',
      frmPotvrdaKupnje.PreostaliSaldoCenti / 100
    ) + ' DFC';

  // Učitavanje spremljenih podataka iz SQLite baze

  Q := TSQLQuery.Create(nil);
  TransakcijaPokrenuta := False;

  try
    try

      Q.Database := frmMain.SQLite3Connection1;
      Q.Transaction := frmMain.SQLTransaction1;

      if frmMain.SQLTransaction1.Active then
        raise Exception.Create(
          'Druga SQL transakcija je aktivna!');

      frmMain.SQLTransaction1.StartTransaction;
      TransakcijaPokrenuta := True;

      // Učitavanje ukupnog iznosa računa

      Q.SQL.Text :=
        'SELECT ukupno_centi ' +
        'FROM racuni ' +
        'WHERE racun_id = :id';

      Q.ParamByName('id').AsLargeInt :=
        frmPotvrdaKupnje.RacunID;

      Q.Open;

      if Q.IsEmpty then
        raise Exception.Create(
          'Račun nije pronađen u bazi!');

      UkupnoCenti :=
        Q.FieldByName('ukupno_centi').AsLargeInt;

      Q.Close;

      lblPotrosenoRacun.Caption :=
        'Ukupno potrošeno: ' +
        FormatFloat('0.00', UkupnoCenti / 100) +
        ' DFC';

      // Učitavanje stavki računa

      Q.SQL.Text :=
        'SELECT naziv_artikla, kolicina, ' +
        'jedinicna_ukupno_centi, ' +
        'ukupno_stavke_centi ' +
        'FROM stavke_racuna ' +
        'WHERE racun_id = :id ' +
        'ORDER BY pozicija';

      Q.ParamByName('id').AsLargeInt :=
        frmPotvrdaKupnje.RacunID;

      Q.Open;

      while not Q.EOF do
      begin

        Naziv :=
          Q.FieldByName('naziv_artikla').AsString;

        Kolicina :=
          Q.FieldByName('kolicina').AsInteger;

        CijenaCenti :=
          Q.FieldByName(
            'jedinicna_ukupno_centi').AsLargeInt;

        StavkaCenti :=
          Q.FieldByName(
            'ukupno_stavke_centi').AsLargeInt;

        lstStavkeRacuna.Items.Add(
          Naziv + ' | ' +
          IntToStr(Kolicina) + ' x ' +
          FormatFloat('0.00', CijenaCenti / 100) +
          ' = ' +
          FormatFloat('0.00', StavkaCenti / 100) +
          ' DFC'
        );

        Q.Next;

      end;

      Q.Close;

      frmMain.SQLTransaction1.Commit;
      TransakcijaPokrenuta := False;

    except
      on E: Exception do
      begin

        Q.Close;

        if TransakcijaPokrenuta and
          frmMain.SQLTransaction1.Active then
          frmMain.SQLTransaction1.Rollback;

        lstStavkeRacuna.Items.Clear;

        ShowMessage(
          'Kupnja je naplaćena, ali učitavanje ' +
          'računa nije uspjelo!' +
          LineEnding + E.Message
        );

      end;
    end;

  finally
    Q.Free;
  end;

end;

end.
