program DutyFreePOS;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uMain, uKupac, uNadoplata, uPotvrdaKupnje, uRacun
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
Application.CreateForm(TfrmMain, frmMain);
Application.CreateForm(TfrmKupac, frmKupac);
Application.CreateForm(TfrmNadoplata, frmNadoplata);
Application.CreateForm(TfrmPotvrdaKupnje, frmPotvrdaKupnje);
Application.CreateForm(TfrmRacun, frmRacun);
Application.Run;
end.

