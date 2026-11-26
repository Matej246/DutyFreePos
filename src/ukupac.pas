unit uKupac;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, SQLDB;

type

  TArtikl = record
    ID: Integer;
    Naziv: String;
    NetoCenti: Int64;
    PDVCenti: Int64;
    CijenaCenti: Int64;
    Zaliha: Integer;
  end;

  { TfrmKupac }

  TfrmKupac = class(TForm)
    btnBomboni: TButton;
    btnMagnet: TButton;
    btnParfem50: TButton;
    btnKrema: TButton;
    btnVoda: TButton;
    btnSuveniri: TButton;
    btnSlatkisi: TButton;
    btnPica: TButton;
    btnGrickalice: TButton;
    btnParfemi: TButton;
    btnKozmetika: TButton;
    btnCokolada: TButton;
    btnCips: TButton;
    btnNaplati: TButton;
    btnNadoplati: TButton;
    btnOdjava: TButton;

    lblUkupno: TLabel;
    lblKosarica: TLabel;
    lblProizvodi: TLabel;
    lblSaldo: TLabel;
    lblPDV: TLabel;
    lblLet: TLabel;
    lblPutnik: TLabel;
    lblNaslov: TLabel;

    lstKosarica: TListBox;

    pnlKosarica: TPanel;
    pnlProizvodi: TPanel;
    pnlKategorije: TPanel;
    pnlHeader: TPanel;
    scrProizvodi: TScrollBox;

    procedure btnCipsClick(Sender: TObject);
    procedure btnCokoladaClick(Sender: TObject);
    procedure btnBomboniClick(Sender: TObject);
    procedure btnGrickaliceClick(Sender: TObject);
    procedure btnKozmetikaClick(Sender: TObject);
    procedure btnKremaClick(Sender: TObject);
    procedure btnMagnetClick(Sender: TObject);
    procedure btnNadoplatiClick(Sender: TObject);
    procedure btnNaplatiClick(Sender: TObject);
    procedure btnParfem50Click(Sender: TObject);
    procedure btnParfemiClick(Sender: TObject);
    procedure btnPicaClick(Sender: TObject);
    procedure btnSlatkisiClick(Sender: TObject);
    procedure btnSuveniriClick(Sender: TObject);
    procedure btnVodaClick(Sender: TObject);
    procedure btnOdjavaClick(Sender: TObject);
    procedure FormShow(Sender: TObject);

  private
    Artikli: array of TArtikl;

    procedure SakrijStareProizvode;
    procedure ObrisiDinamickeGumbe;
    procedure UcitajProizvode(KategorijaID: Integer);
    procedure ProizvodClick(Sender: TObject);
    procedure StvoriKarticu(i: Integer);

  public
    procedure OdjaviPutnika;

  end;

var
  frmKupac: TfrmKupac;
  Ukupno: Double = 0;

implementation

uses
  uMain, uPotvrdaKupnje, uNadoplata, uRacun;

{$R *.lfm}

// SAKRIVANJE STARIH GUMBA

procedure TfrmKupac.SakrijStareProizvode;
begin
  btnCokolada.Visible := False;
  btnBomboni.Visible := False;
  btnVoda.Visible := False;
  btnCips.Visible := False;
  btnParfem50.Visible := False;
  btnKrema.Visible := False;
  btnMagnet.Visible := False;
end;

// BRISANJE DINAMIČKIH KARTICA

procedure TfrmKupac.ObrisiDinamickeGumbe;
var
  i: Integer;
begin
  for i := scrProizvodi.ControlCount - 1 downto 0 do
  begin
    if scrProizvodi.Controls[i] is TPanel then
    begin
      if scrProizvodi.Controls[i].Name = '' then
        scrProizvodi.Controls[i].Free;
    end;
  end;

  SetLength(Artikli, 0);
end;

// STVARANJE KARTICE PROIZVODA

procedure TfrmKupac.StvoriKarticu(i: Integer);
var
  Kartica: TPanel;
  Naziv: TLabel;
  Cijena: TLabel;
  Zaliha: TLabel;
  Gumb: TButton;
  Sirina: Integer;
  BrojStupaca: Integer;
begin
  BrojStupaca := 2;

  Sirina := (scrProizvodi.ClientWidth - 45) div 2;

  if Sirina < 180 then
  begin
    BrojStupaca := 1;
    Sirina := scrProizvodi.ClientWidth - 35;
  end;

  // OKVIR PROIZVODA

  Kartica := TPanel.Create(Self);
  Kartica.Parent := scrProizvodi;

  Kartica.Left :=
    10 + (i mod BrojStupaca) * (Sirina + 10);

  Kartica.Top :=
    10 + (i div BrojStupaca) * 165;

  Kartica.Width := Sirina;
  Kartica.Height := 155;

  Kartica.Caption := '';
  Kartica.BevelOuter := bvLowered;
  Kartica.ParentColor := False;
  Kartica.Color := clWhite;

  // NAZIV PROIZVODA

  Naziv := TLabel.Create(Kartica);
  Naziv.Parent := Kartica;
  Naziv.AutoSize := False;
  Naziv.Left := 5;
  Naziv.Top := 8;
  Naziv.Width := Kartica.ClientWidth - 10;
  Naziv.Height := 40;
  Naziv.Alignment := taCenter;
  Naziv.Layout := tlCenter;
  Naziv.WordWrap := True;

  Naziv.Font.Size := 11;
  Naziv.Font.Style := [fsBold];

  Naziv.Caption := Artikli[i].Naziv;

  // CIJENA PROIZVODA

  Cijena := TLabel.Create(Kartica);
  Cijena.Parent := Kartica;
  Cijena.AutoSize := False;
  Cijena.Left := 5;
  Cijena.Top := 50;
  Cijena.Width := Kartica.ClientWidth - 10;
  Cijena.Height := 28;
  Cijena.Alignment := taCenter;

  Cijena.Font.Size := 15;
  Cijena.Font.Style := [fsBold];
  Cijena.Font.Color := clGreen;

  Cijena.Caption :=
    FormatFloat('0.00',
      Artikli[i].CijenaCenti / 100) + ' DFC';

  // ZALIHA PROIZVODA

  Zaliha := TLabel.Create(Kartica);
  Zaliha.Parent := Kartica;
  Zaliha.AutoSize := False;
  Zaliha.Left := 5;
  Zaliha.Top := 82;
  Zaliha.Width := Kartica.ClientWidth - 10;
  Zaliha.Height := 22;
  Zaliha.Alignment := taCenter;

  Zaliha.Font.Size := 10;

  Zaliha.Caption :=
    'Zaliha: ' +
    IntToStr(Artikli[i].Zaliha) + ' kom.';

  if Artikli[i].Zaliha <= 3 then
    Zaliha.Font.Color := clRed
  else
    Zaliha.Font.Color := clGray;

  // GUMB ZA DODAVANJE U KOŠARICU

  Gumb := TButton.Create(Kartica);
  Gumb.Parent := Kartica;

  Gumb.Left := 10;
  Gumb.Top := 110;
  Gumb.Width := Kartica.ClientWidth - 20;
  Gumb.Height := 35;

  Gumb.Caption := 'DODAJ U KOŠARICU';
  Gumb.Font.Size := 10;

  Gumb.Tag := i;
  Gumb.OnClick := @ProizvodClick;
end;

// UČITAVANJE PROIZVODA IZ BAZE

procedure TfrmKupac.UcitajProizvode(
  KategorijaID: Integer);
var
  Q: TSQLQuery;
  i: Integer;
  PDVPostotak: Integer;
begin
  SakrijStareProizvode;
  ObrisiDinamickeGumbe;

  scrProizvodi.VertScrollBar.Position := 0;

  Q := TSQLQuery.Create(nil);

  try
    try
      Q.Database := frmMain.SQLite3Connection1;
      Q.Transaction := frmMain.SQLTransaction1;

      if not frmMain.SQLTransaction1.Active then
        frmMain.SQLTransaction1.StartTransaction;

      Q.SQL.Text :=
        'SELECT a.artikl_id, a.naziv, ' +
        'a.cijena_neto_centi, a.pdv_postotak, ' +
        'z.kolicina ' +
        'FROM artikli a ' +
        'JOIN kategorije k ON ' +
        'k.kategorija_id = a.kategorija_id ' +
        'JOIN zalihe z ON ' +
        'z.artikl_id = a.artikl_id ' +
        'WHERE a.aktivan = 1 ' +
        'AND k.aktivna = 1 ' +
        'AND z.kolicina > 0 ';

      if KategorijaID > 0 then
      begin
        Q.SQL.Add(
          'AND a.kategorija_id = :kategorija');

        Q.ParamByName('kategorija').AsInteger :=
          KategorijaID;
      end;

      Q.SQL.Add('ORDER BY a.naziv');

      Q.Open;

      while not Q.EOF do
      begin
        i := Length(Artikli);

        SetLength(Artikli, i + 1);

        Artikli[i].ID :=
          Q.FieldByName('artikl_id').AsInteger;

        Artikli[i].Naziv :=
          Q.FieldByName('naziv').AsString;

        Artikli[i].NetoCenti :=
          Q.FieldByName('cijena_neto_centi').AsLargeInt;

        Artikli[i].Zaliha :=
          Q.FieldByName('kolicina').AsInteger;

        PDVPostotak :=
          Q.FieldByName('pdv_postotak').AsInteger;

        // POREZNI REŽIM PUTNIKA

        if frmMain.PorezniRezim = 'IZVAN_EU' then
          PDVPostotak := 0;

        Artikli[i].PDVCenti :=
          (Artikli[i].NetoCenti *
           PDVPostotak + 50) div 100;

        Artikli[i].CijenaCenti :=
          Artikli[i].NetoCenti +
          Artikli[i].PDVCenti;

        // STVARANJE KARTICE PROIZVODA

        StvoriKarticu(i);

        Q.Next;
      end;

      Q.Close;
      frmMain.SQLTransaction1.Commit;

    except
      on E: Exception do
      begin
        Q.Close;

        if frmMain.SQLTransaction1.Active then
          frmMain.SQLTransaction1.Rollback;

        ObrisiDinamickeGumbe;

        ShowMessage(
          'GREŠKA PRI UČITAVANJU PROIZVODA:' +
          LineEnding + E.Message);
      end;
    end;

  finally
    Q.Free;
  end;
end;

// DODAVANJE PROIZVODA U KOŠARICU

procedure TfrmKupac.ProizvodClick(Sender: TObject);
var
  i, j: Integer;
  KolicinaUKosarici: Integer;
begin
  i := TButton(Sender).Tag;

  if (i < 0) or (i >= Length(Artikli)) then
    Exit;

  KolicinaUKosarici := 0;

  for j := 0 to lstKosarica.Items.Count - 1 do
  begin
    if PtrInt(lstKosarica.Items.Objects[j]) =
      Artikli[i].ID then
      Inc(KolicinaUKosarici);
  end;

  if KolicinaUKosarici >= Artikli[i].Zaliha then
  begin
    ShowMessage(
      'Nema dovoljno proizvoda na zalihi!');
    Exit;
  end;

  lstKosarica.Items.AddObject(
    Artikli[i].Naziv + ' - ' +
    FormatFloat('0.00',
      Artikli[i].CijenaCenti / 100) + ' DFC',
    TObject(PtrInt(Artikli[i].ID)));

  Ukupno := Ukupno +
    Artikli[i].CijenaCenti / 100;

  lblUkupno.Caption :=
    'UKUPNO: ' +
    FormatFloat('0.00', Ukupno) + ' DFC';
end;

// OTVARANJE TRGOVINE

procedure TfrmKupac.FormShow(Sender: TObject);
begin
  Caption := 'DutyFree POS - Trgovina';

  lblUkupno.Caption :=
    'UKUPNO: ' +
    FormatFloat('0.00', Ukupno) + ' DFC';

  UcitajProizvode(0);
end;

// KATEGORIJE

procedure TfrmKupac.btnSlatkisiClick(Sender: TObject);
begin
  UcitajProizvode(1);
end;

procedure TfrmKupac.btnPicaClick(Sender: TObject);
begin
  UcitajProizvode(2);
end;

procedure TfrmKupac.btnGrickaliceClick(Sender: TObject);
begin
  UcitajProizvode(3);
end;

procedure TfrmKupac.btnParfemiClick(Sender: TObject);
begin
  UcitajProizvode(4);
end;

procedure TfrmKupac.btnKozmetikaClick(Sender: TObject);
begin
  UcitajProizvode(5);
end;

procedure TfrmKupac.btnSuveniriClick(Sender: TObject);
begin
  UcitajProizvode(6);
end;

// STARI DOGAĐAJI

procedure TfrmKupac.btnCokoladaClick(Sender: TObject);
begin
end;

procedure TfrmKupac.btnBomboniClick(Sender: TObject);
begin
end;

procedure TfrmKupac.btnVodaClick(Sender: TObject);
begin
end;

procedure TfrmKupac.btnCipsClick(Sender: TObject);
begin
end;

procedure TfrmKupac.btnParfem50Click(Sender: TObject);
begin
end;

procedure TfrmKupac.btnKremaClick(Sender: TObject);
begin
end;

procedure TfrmKupac.btnMagnetClick(Sender: TObject);
begin
end;

// NADOPLATA DFC SREDSTAVA

procedure TfrmKupac.btnNadoplatiClick(Sender: TObject);
begin

  // Provjera prijavljenog putnika

  if (frmMain.PutnikID <= 0) or
     (frmMain.NovcanikID <= 0) then
  begin
    ShowMessage('Putnik nije prijavljen!');
    Exit;
  end;

  // Kreiranje forme za nadoplatu

  if not Assigned(frmNadoplata) then
    frmNadoplata :=
      TfrmNadoplata.Create(Application);

  // Otvaranje forme za nadoplatu

  frmNadoplata.ShowModal;

  // Osvježavanje salda nakon zatvaranja nadoplate

  lblSaldo.Caption :=
    'DFC saldo: ' +
    FormatFloat('0.00', frmMain.SaldoCenti / 100) +
    ' DFC';

end;

// NAPLATI

procedure TfrmKupac.btnNaplatiClick(Sender: TObject);
begin
  if lstKosarica.Items.Count = 0 then
  begin
    ShowMessage('Košarica je prazna!');
    Exit;
  end;

  if not Assigned(frmPotvrdaKupnje) then
    frmPotvrdaKupnje :=
      TfrmPotvrdaKupnje.Create(Application);

  frmPotvrdaKupnje.Show;
end;

// ODJAVA PUTNIKA

procedure TfrmKupac.OdjaviPutnika;
begin

  // Zatvaranje potvrde kupnje

  if Assigned(frmPotvrdaKupnje) then
  begin
    frmPotvrdaKupnje.Hide;
    frmPotvrdaKupnje.lstPregledKupnje.Items.Clear;
    frmPotvrdaKupnje.btnPotvrdiKupnju.Enabled := False;
    frmPotvrdaKupnje.lblStatusKupnje.Caption := '';
    frmPotvrdaKupnje.lblUkupnoPotvrda.Caption := '';
    frmPotvrdaKupnje.lblPDVPotvrda.Caption := '';
  end;

  // Zatvaranje računa

  if Assigned(frmRacun) then
  begin
    frmRacun.Hide;
    frmRacun.lstStavkeRacuna.Items.Clear;
    frmRacun.lblBrojRacuna.Caption := '';
    frmRacun.lblDatumRacuna.Caption := '';
    frmRacun.lblLetRacuna.Caption := '';
    frmRacun.lblPotrosenoRacun.Caption := '';
    frmRacun.lblPreostaliSaldo.Caption := '';
  end;

  // Zatvaranje nadoplate

  if Assigned(frmNadoplata) then
  begin
    frmNadoplata.Hide;
    frmNadoplata.edtKodBona.Clear;
    frmNadoplata.lblSaldoNadoplata.Caption := '';
    frmNadoplata.lblStatusNadoplate.Caption := '';
  end;

  // Pražnjenje košarice

  lstKosarica.Items.Clear;

  Ukupno := 0;

  lblUkupno.Caption := 'UKUPNO: 0,00 DFC';

  // Brisanje prikazanih proizvoda

  ObrisiDinamickeGumbe;

  // Poništavanje podataka prijavljenog putnika

  frmMain.KartaID := 0;
  frmMain.PutnikID := 0;
  frmMain.LetID := 0;
  frmMain.NovcanikID := 0;

  frmMain.ImePutnika := '';
  frmMain.BrojLeta := '';
  frmMain.Odrediste := '';
  frmMain.PorezniRezim := '';

  frmMain.SaldoCenti := 0;

  // Brisanje prikazanih podataka

  lblPutnik.Caption := 'Putnik: -';
  lblLet.Caption := 'Let: -';
  lblPDV.Caption := 'PDV režim: -';
  lblSaldo.Caption := 'DFC saldo: -';

  // Priprema početnog ekrana

  frmMain.edtBarkod.Clear;

  frmMain.lblStatusKarte.Caption :=
    'Unesite barkod avionske karte';

  // Povratak na početni ekran

  frmMain.Show;

  Hide;

  frmMain.BringToFront;

  frmMain.edtBarkod.SetFocus;

end;

// GUMB ODJAVA

procedure TfrmKupac.btnOdjavaClick(Sender: TObject);
begin

  if MessageDlg(
    'Odjava',
    'Želite li se odjaviti?',
    mtConfirmation,
    [mbYes, mbNo],
    0) = mrYes then
  begin
    OdjaviPutnika;
  end;

end;

end.
