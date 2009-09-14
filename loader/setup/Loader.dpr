program Loader;

uses
  Forms,
  fSettings in 'fSettings.pas' {fSetup};

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'Dizzy';
  Application.CreateForm(TfSetup, fSetup);
  Application.Run;
end.
