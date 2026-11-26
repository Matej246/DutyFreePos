unit uPotvrdaKupnje;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics,
  Dialogs, StdCtrls, SQLDB;

type

  { TfrmPotvrdaKupnje }

  TfrmPotvrdaKupnje = class(TForm)
    btnPotvrdiKupnju: TButton;
    lblStatusKupnje: TButton;
    lblPDVPotvrda: TLabel;
    lblUkupnoPotvrda: TLabel;
    lblNaslovPotvrda: TLabel;
    lstPregledKupnje: TListBox;

    procedure btnPotvrdiKupnjuClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);

  private
    NaplataZavrsena: Boolean;

  public
    RacunID: Int64;
    BrojRacuna: String;
    PreostaliSaldoCenti: Int64;
    DatumRacuna: String;

  end;

var
  frmPotvrdaKupnje: TfrmPotvrdaKupnje;

implementation

uses
  uMain, uKupac, uRacun;

{$R *.lfm}

type
  TStavkaKupnje = record
    ArtiklID: Integer;
    Sifra: String;
    Naziv: String;
    Kolicina: Integer;
    NetoCenti: Int64;
    PDVPostotak: Integer;
    PDVCenti: Int64;
    CijenaCenti: Int64;
  end;

procedure TfrmPotvrdaKupnje.FormCreate(Sender: TObject);
begin
  Caption := 'DutyFree POS - Potvrda kupnje';
  NaplataZavrsena := False;
end;

procedure TfrmPotvrdaKupnje.FormShow(Sender: TObject);
var
  UkupnoCenti: Int64;
  PreostaloCenti: Int64;
begin

  NaplataZavrsena := False;

  lstPregledKupnje.Items.Assign(
    frmKupac.lstKosarica.Items);

  UkupnoCenti := Round(Ukupno * 100);

  PreostaloCenti :=
    frmMain.SaldoCenti - UkupnoCenti;

  lblUkupnoPotvrda.Caption :=
    'UKUPNO: ' +
    FormatFloat('0.00', UkupnoCenti / 100) +
    ' DFC';

  if frmMain.PorezniRezim = 'IZVAN_EU' then
    lblPDVPotvrda.Caption :=
      'PDV: 0,00 DFC (IZVAN EU)'
  else
    lblPDVPotvrda.Caption :=
      'PDV: uključen u cijenu';

  lblStatusKupnje.SetBounds(
    20,
    lblPDVPotvrda.Top + 30,
    ClientWidth - 40,
    65
  );

  lblStatusKupnje.Caption :=
    'Trenutni saldo: ' +
    FormatFloat('0.00', frmMain.SaldoCenti / 100) +
    ' DFC | Preostalo: ' +
    FormatFloat('0.00', PreostaloCenti / 100) +
    ' DFC';

  btnPotvrdiKupnju.Top :=
    lblStatusKupnje.Top +
    lblStatusKupnje.Height + 15;

  if ClientHeight <
    btnPotvrdiKupnju.Top +
    btnPotvrdiKupnju.Height + 20 then
    ClientHeight :=
      btnPotvrdiKupnju.Top +
      btnPotvrdiKupnju.Height + 20;

  btnPotvrdiKupnju.Enabled :=
    (UkupnoCenti > 0) and
    (PreostaloCenti >= 0) and
    (lstPregledKupnje.Items.Count > 0);

  if PreostaloCenti < 0 then
  begin

    lblStatusKupnje.Caption :=
      'NEDOVOLJNO DFC SREDSTAVA!';

    ShowMessage(
      'Nemate dovoljno DFC sredstava za kupnju!');

  end;

end;

procedure TfrmPotvrdaKupnje.btnPotvrdiKupnjuClick(
  Sender: TObject);
var
  Q: TSQLQuery;
  Stavke: array of TStavkaKupnje;
  i, j, Indeks, ArtiklID: Integer;
  StanjeZalihe: Integer;
  SaldoCenti: Int64;
  NetoUkupno: Int64;
  PDVUkupno: Int64;
  UkupnoCenti: Int64;
  GUID: TGUID;
  Rezim: String;
begin

  if NaplataZavrsena then
    Exit;

  if lstPregledKupnje.Items.Count = 0 then
  begin
    ShowMessage('Košarica je prazna!');
    Exit;
  end;

  if lstPregledKupnje.Items.Count <>
    frmKupac.lstKosarica.Items.Count then
  begin
    ShowMessage('Košarica je promijenjena!');
    Hide;
    Exit;
  end;

  for i := 0 to lstPregledKupnje.Items.Count - 1 do
  begin

    if (lstPregledKupnje.Items[i] <>
        frmKupac.lstKosarica.Items[i]) or
       (lstPregledKupnje.Items.Objects[i] <>
        frmKupac.lstKosarica.Items.Objects[i]) then
    begin
      ShowMessage('Košarica je promijenjena!');
      Hide;
      Exit;
    end;

  end;

  btnPotvrdiKupnju.Enabled := False;

  Q := TSQLQuery.Create(nil);

  try
    try

      Q.Database := frmMain.SQLite3Connection1;
      Q.Transaction := frmMain.SQLTransaction1;

      if frmMain.SQLTransaction1.Active then
        raise Exception.Create(
          'Druga SQL transakcija je aktivna!');

      frmMain.SQLTransaction1.StartTransaction;

      try

        { 1. PROVJERA KARTE I SALDA }

        Q.SQL.Text :=
          'SELECT novcanik_id, saldo_centi, ' +
          'porezni_rezim, status_karte ' +
          'FROM v_kupac_prijava ' +
          'WHERE karta_id = :karta';

        Q.ParamByName('karta').AsInteger :=
          frmMain.KartaID;

        Q.Open;

        if Q.IsEmpty then
          raise Exception.Create(
            'Avionska karta nije pronađena!');

        if Q.FieldByName('status_karte').AsString
          <> 'AKTIVNA' then
          raise Exception.Create(
            'Avionska karta nije aktivna!');

        if Q.FieldByName('novcanik_id').AsInteger
          <> frmMain.NovcanikID then
          raise Exception.Create(
            'Novčanik putnika nije ispravan!');

        SaldoCenti :=
          Q.FieldByName('saldo_centi').AsLargeInt;

        Rezim :=
          Q.FieldByName('porezni_rezim').AsString;

        Q.Close;

        if Rezim <> frmMain.PorezniRezim then
          raise Exception.Create(
            'Porezni režim je promijenjen!');

        { 2. GRUPIRANJE PROIZVODA }

        SetLength(Stavke, 0);

        for i := 0 to
          lstPregledKupnje.Items.Count - 1 do
        begin

          ArtiklID := PtrInt(
            lstPregledKupnje.Items.Objects[i]);

          Indeks := -1;

          for j := 0 to High(Stavke) do
          begin

            if Stavke[j].ArtiklID = ArtiklID then
            begin
              Indeks := j;
              Break;
            end;

          end;

          if Indeks = -1 then
          begin

            Indeks := Length(Stavke);

            SetLength(Stavke, Indeks + 1);

            Stavke[Indeks].ArtiklID := ArtiklID;
            Stavke[Indeks].Kolicina := 1;

          end
          else
            Inc(Stavke[Indeks].Kolicina);

        end;

        { 3. PROVJERA CIJENA I ZALIHA }

        NetoUkupno := 0;
        PDVUkupno := 0;

        for i := 0 to High(Stavke) do
        begin

          Q.SQL.Text :=
            'SELECT a.sifra, a.naziv, ' +
            'a.cijena_neto_centi, ' +
            'a.pdv_postotak, z.kolicina ' +
            'FROM artikli a ' +
            'JOIN zalihe z ' +
            'ON z.artikl_id = a.artikl_id ' +
            'JOIN kategorije k ' +
            'ON k.kategorija_id = a.kategorija_id ' +
            'WHERE a.artikl_id = :id ' +
            'AND a.aktivan = 1 ' +
            'AND k.aktivna = 1';

          Q.ParamByName('id').AsInteger :=
            Stavke[i].ArtiklID;

          Q.Open;

          if Q.IsEmpty then
            raise Exception.Create(
              'Proizvod više nije dostupan!');

          Stavke[i].Sifra :=
            Q.FieldByName('sifra').AsString;

          Stavke[i].Naziv :=
            Q.FieldByName('naziv').AsString;

          Stavke[i].NetoCenti :=
            Q.FieldByName(
              'cijena_neto_centi').AsLargeInt;

          Stavke[i].PDVPostotak :=
            Q.FieldByName('pdv_postotak').AsInteger;

          StanjeZalihe :=
            Q.FieldByName('kolicina').AsInteger;

          Q.Close;

          if StanjeZalihe < Stavke[i].Kolicina then
            raise Exception.Create(
              'Nedovoljna zaliha: ' +
              Stavke[i].Naziv);

          if Rezim = 'IZVAN_EU' then
            Stavke[i].PDVPostotak := 0;

          Stavke[i].PDVCenti :=
            (Stavke[i].NetoCenti *
             Stavke[i].PDVPostotak + 50) div 100;

          Stavke[i].CijenaCenti :=
            Stavke[i].NetoCenti +
            Stavke[i].PDVCenti;

          NetoUkupno := NetoUkupno +
            Stavke[i].NetoCenti *
            Stavke[i].Kolicina;

          PDVUkupno := PDVUkupno +
            Stavke[i].PDVCenti *
            Stavke[i].Kolicina;

        end;

        UkupnoCenti := NetoUkupno + PDVUkupno;

        if UkupnoCenti <= 0 then
          raise Exception.Create(
            'Neispravan iznos kupnje!');

        if UkupnoCenti <> Round(Ukupno * 100) then
          raise Exception.Create(
            'Cijene proizvoda su promijenjene!');

        if SaldoCenti < UkupnoCenti then
          raise Exception.Create(
            'Nedovoljno DFC sredstava!');

        PreostaliSaldoCenti :=
          SaldoCenti - UkupnoCenti;

        { 4. GENERIRANJE BROJA RACUNA }

        if CreateGUID(GUID) <> 0 then
          raise Exception.Create(
            'Nije moguće generirati broj računa!');

        BrojRacuna :=
          'DF-' + Copy(GUIDToString(GUID), 2, 36);

        { 5. SPREMANJE RACUNA }

        Q.SQL.Text :=
          'INSERT INTO racuni (' +
          'broj_racuna, karta_id, porezni_rezim, ' +
          'iznos_neto_centi, iznos_pdv_centi, ' +
          'ukupno_centi) VALUES (' +
          ':broj, :karta, :rezim, ' +
          ':neto, :pdv, :ukupno)';

        Q.ParamByName('broj').AsString :=
          BrojRacuna;

        Q.ParamByName('karta').AsInteger :=
          frmMain.KartaID;

        Q.ParamByName('rezim').AsString :=
          Rezim;

        Q.ParamByName('neto').AsLargeInt :=
          NetoUkupno;

        Q.ParamByName('pdv').AsLargeInt :=
          PDVUkupno;

        Q.ParamByName('ukupno').AsLargeInt :=
          UkupnoCenti;

        Q.ExecSQL;

        Q.SQL.Text :=
          'SELECT racun_id, datum_izdavanja ' +
          'FROM racuni WHERE broj_racuna = :broj';

        Q.ParamByName('broj').AsString :=
          BrojRacuna;

        Q.Open;

        if Q.IsEmpty then
          raise Exception.Create(
            'Račun nije pronađen!');

        RacunID :=
          Q.FieldByName('racun_id').AsLargeInt;

        DatumRacuna :=
          Q.FieldByName('datum_izdavanja').AsString;

        Q.Close;

        { 6. SPREMANJE STAVKI RACUNA }

        for i := 0 to High(Stavke) do
        begin

          Q.SQL.Text :=
            'INSERT INTO stavke_racuna (' +
            'racun_id, pozicija, artikl_id, ' +
            'sifra_artikla, naziv_artikla, ' +
            'kolicina, jedinicna_neto_centi, ' +
            'primijenjeni_pdv_postotak, ' +
            'jedinicna_pdv_centi, ' +
            'jedinicna_ukupno_centi, ' +
            'ukupno_stavke_centi) VALUES (' +
            ':racun, :pozicija, :artikl, ' +
            ':sifra, :naziv, :kolicina, ' +
            ':neto, :postotak, :pdv, ' +
            ':cijena, :ukupno)';

          Q.ParamByName('racun').AsLargeInt :=
            RacunID;

          Q.ParamByName('pozicija').AsInteger :=
            i + 1;

          Q.ParamByName('artikl').AsInteger :=
            Stavke[i].ArtiklID;

          Q.ParamByName('sifra').AsString :=
            Stavke[i].Sifra;

          Q.ParamByName('naziv').AsString :=
            Stavke[i].Naziv;

          Q.ParamByName('kolicina').AsInteger :=
            Stavke[i].Kolicina;

          Q.ParamByName('neto').AsLargeInt :=
            Stavke[i].NetoCenti;

          Q.ParamByName('postotak').AsInteger :=
            Stavke[i].PDVPostotak;

          Q.ParamByName('pdv').AsLargeInt :=
            Stavke[i].PDVCenti;

          Q.ParamByName('cijena').AsLargeInt :=
            Stavke[i].CijenaCenti;

          Q.ParamByName('ukupno').AsLargeInt :=
            Stavke[i].CijenaCenti *
            Stavke[i].Kolicina;

          Q.ExecSQL;

        end;

        { 7. UMANJENJE SALDA }

        Q.SQL.Text :=
          'UPDATE novcanici ' +
          'SET saldo_centi = saldo_centi - :iznos ' +
          'WHERE novcanik_id = :id ' +
          'AND saldo_centi >= :iznos';

        Q.ParamByName('iznos').AsLargeInt :=
          UkupnoCenti;

        Q.ParamByName('id').AsInteger :=
          frmMain.NovcanikID;

        Q.ExecSQL;

        if Q.RowsAffected <> 1 then
          raise Exception.Create(
            'Umanjenje salda nije uspjelo!');

        { 8. UMANJENJE ZALIHA }

        for i := 0 to High(Stavke) do
        begin

          Q.SQL.Text :=
            'UPDATE zalihe ' +
            'SET kolicina = kolicina - :kolicina ' +
            'WHERE artikl_id = :id ' +
            'AND kolicina >= :kolicina';

          Q.ParamByName('kolicina').AsInteger :=
            Stavke[i].Kolicina;

          Q.ParamByName('id').AsInteger :=
            Stavke[i].ArtiklID;

          Q.ExecSQL;

          if Q.RowsAffected <> 1 then
            raise Exception.Create(
              'Umanjenje zalihe nije uspjelo: ' +
              Stavke[i].Naziv);

        end;

        { 9. EVIDENTIRANJE TRANSAKCIJE }

        Q.SQL.Text :=
          'INSERT INTO transakcije_kredita (' +
          'novcanik_id, tip, iznos_centi, ' +
          'saldo_nakon_centi, racun_id) VALUES (' +
          ':novcanik, ''KUPNJA'', :iznos, ' +
          ':saldo, :racun)';

        Q.ParamByName('novcanik').AsInteger :=
          frmMain.NovcanikID;

        Q.ParamByName('iznos').AsLargeInt :=
          -UkupnoCenti;

        Q.ParamByName('saldo').AsLargeInt :=
          PreostaliSaldoCenti;

        Q.ParamByName('racun').AsLargeInt :=
          RacunID;

        Q.ExecSQL;

        { 10. POTVRDA SQL TRANSAKCIJE }

        frmMain.SQLTransaction1.Commit;

      except

        Q.Close;

        if frmMain.SQLTransaction1.Active then
          frmMain.SQLTransaction1.Rollback;

        raise;

      end;

      NaplataZavrsena := True;

    except
      on E: Exception do
      begin

        btnPotvrdiKupnju.Enabled := True;

        ShowMessage(
          'NAPLATA NIJE USPJELA!' +
          LineEnding + E.Message);

        Exit;

      end;
    end;

  finally
    Q.Free;
  end;

  { 11. OSVJEZAVANJE PRIKAZA }

  frmMain.SaldoCenti :=
    PreostaliSaldoCenti;

  frmKupac.lblSaldo.Caption :=
    'DFC saldo: ' +
    FormatFloat(
      '0.00', PreostaliSaldoCenti / 100) +
    ' DFC';

  lblStatusKupnje.Caption :=
    'KUPNJA USPJEŠNA! Preostali saldo: ' +
    FormatFloat(
      '0.00', PreostaliSaldoCenti / 100) +
    ' DFC';

  btnPotvrdiKupnju.Enabled := False;

  frmKupac.Enabled := False;

  { 12. PRIKAZ RACUNA I AUTOMATSKA ODJAVA }

  try

    if not Assigned(frmRacun) then
      frmRacun := TfrmRacun.Create(Application);

    frmRacun.ShowModal;

  finally

    // Praznjenje kosarice
    frmKupac.lstKosarica.Items.Clear;

    // Ponistavanje ukupnog iznosa
    Ukupno := 0;

    frmKupac.lblUkupno.Caption :=
      'UKUPNO: 0,00 DFC';

    // Ponovno omogucavanje trgovine
    frmKupac.Enabled := True;

    // Zatvaranje potvrde kupnje
    Hide;

    // Automatska odjava putnika
    frmKupac.OdjaviPutnika;

  end;

end;

end.
