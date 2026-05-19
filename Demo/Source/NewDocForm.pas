unit NewDocForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ExtCtrls;

type
  TNewDocPixelFormat = (
    ndpfGray8,
    ndpfRGB8
  );

  TNewDocParams = record
    Width: Integer;
    Height: Integer;
    PixelFormat: TNewDocPixelFormat;
    FillColor: TColor;
  end;

  { Width/height в .lfm (IDE); останалите контроли се създават в кода (съвместимост LCL 1.6). }

  TFrmNewDoc = class(TForm)
    edtHeight: TEdit;
    edtWidth: TEdit;
    lblHeight: TLabel;
    lblWidth: TLabel;
  private
    lblPreset: TLabel;
    lblFormat: TLabel;
    lblFillColor: TLabel;
    cboPreset: TComboBox;
    rbGray: TRadioButton;
    rbRgb: TRadioButton;
    pnlColorPreview: TPanel;
    btnPickColor: TButton;
    btnOk: TButton;
    btnCancel: TButton;
    FFillColor: TColor;
    procedure SetupControls;
    function GetParams: TNewDocParams;
    function ReadDimension(AEdit: TEdit; const AName: string; out AValue: Integer): Boolean;
    procedure ApplyPresetIndex(AIndex: Integer);
    procedure cboPresetChange(Sender: TObject);
    procedure UpdateColorPreview;
    procedure btnPickColorClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    class function Execute(AOwner: TComponent; out AParams: TNewDocParams): Boolean;
  end;

implementation

uses
  Dialogs;

{$R *.lfm}

const
  LARGE_PIXEL_COUNT = 50000000;

constructor TFrmNewDoc.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetupControls;
end;

class function TFrmNewDoc.Execute(AOwner: TComponent; out AParams: TNewDocParams): Boolean;
var
  frm: TFrmNewDoc;
begin
  frm := TFrmNewDoc.Create(AOwner);
  try
    Result := frm.ShowModal = mrOK;
    if Result then
      AParams := frm.GetParams;
  finally
    frm.Free;
  end;
end;

procedure TFrmNewDoc.SetupControls;
begin
  ClientHeight := 300;

  lblPreset := TLabel.Create(Self);
  lblPreset.Parent := Self;
  lblPreset.Left := 16;
  lblPreset.Top := 80;
  lblPreset.Caption := 'Preset:';

  cboPreset := TComboBox.Create(Self);
  cboPreset.Parent := Self;
  cboPreset.Left := 120;
  cboPreset.Top := 76;
  cboPreset.Width := 220;
  cboPreset.Style := csDropDownList;
  cboPreset.Items.Add('Custom');
  cboPreset.Items.Add('640 x 480');
  cboPreset.Items.Add('800 x 600');
  cboPreset.Items.Add('1920 x 1080');
  cboPreset.ItemIndex := 2;
  cboPreset.OnChange := @cboPresetChange;

  lblFormat := TLabel.Create(Self);
  lblFormat.Parent := Self;
  lblFormat.Left := 16;
  lblFormat.Top := 112;
  lblFormat.Caption := 'Format:';

  rbGray := TRadioButton.Create(Self);
  rbGray.Parent := Self;
  rbGray.Left := 120;
  rbGray.Top := 112;
  rbGray.Width := 140;
  rbGray.Caption := 'Grayscale (8-bit)';

  rbRgb := TRadioButton.Create(Self);
  rbRgb.Parent := Self;
  rbRgb.Left := 120;
  rbRgb.Top := 136;
  rbRgb.Width := 120;
  rbRgb.Caption := 'RGB (8-bit)';
  rbRgb.Checked := True;

  lblFillColor := TLabel.Create(Self);
  lblFillColor.Parent := Self;
  lblFillColor.Left := 16;
  lblFillColor.Top := 220;
  lblFillColor.Caption := 'Fill color:';

  pnlColorPreview := TPanel.Create(Self);
  pnlColorPreview.Parent := Self;
  pnlColorPreview.Left := 120;
  pnlColorPreview.Top := 216;
  pnlColorPreview.Width := 80;
  pnlColorPreview.Height := 28;
  pnlColorPreview.BevelOuter := bvLowered;

  btnPickColor := TButton.Create(Self);
  btnPickColor.Parent := Self;
  btnPickColor.Left := 208;
  btnPickColor.Top := 216;
  btnPickColor.Width := 90;
  btnPickColor.Height := 28;
  btnPickColor.Caption := 'Choose...';
  btnPickColor.OnClick := @btnPickColorClick;

  btnOk := TButton.Create(Self);
  btnOk.Parent := Self;
  btnOk.Left := 168;
  btnOk.Top := 260;
  btnOk.Width := 80;
  btnOk.Caption := 'OK';
  btnOk.Default := True;
  btnOk.OnClick := @btnOkClick;

  btnCancel := TButton.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Left := 260;
  btnCancel.Top := 260;
  btnCancel.Width := 80;
  btnCancel.Caption := 'Cancel';
  btnCancel.Cancel := True;
  btnCancel.ModalResult := mrCancel;

  FFillColor := clGreen;
  UpdateColorPreview;
end;

function TFrmNewDoc.ReadDimension(AEdit: TEdit; const AName: string; out AValue: Integer): Boolean;
var
  code: Integer;
begin
  Val(Trim(AEdit.Text), AValue, code);
  Result := (code = 0) and (AValue > 0);
  if not Result then
    ShowMessage(Format('Enter a valid positive integer for %s.', [AName]));
end;

procedure TFrmNewDoc.ApplyPresetIndex(AIndex: Integer);
begin
  case AIndex of
    1: begin edtWidth.Text := '640'; edtHeight.Text := '480'; end;
    2: begin edtWidth.Text := '800'; edtHeight.Text := '600'; end;
    3: begin edtWidth.Text := '1920'; edtHeight.Text := '1080'; end;
  end;
end;

procedure TFrmNewDoc.cboPresetChange(Sender: TObject);
begin
  if cboPreset.ItemIndex > 0 then
    ApplyPresetIndex(cboPreset.ItemIndex);
end;

procedure TFrmNewDoc.UpdateColorPreview;
begin
  pnlColorPreview.Color := FFillColor;
end;

procedure TFrmNewDoc.btnPickColorClick(Sender: TObject);
var
  dlg: TColorDialog;
begin
  dlg := TColorDialog.Create(nil);
  try
    dlg.Color := FFillColor;
    if dlg.Execute then
    begin
      FFillColor := dlg.Color;
      UpdateColorPreview;
    end;
  finally
    dlg.Free;
  end;
end;

function TFrmNewDoc.GetParams: TNewDocParams;
begin
  ReadDimension(edtWidth, 'width', Result.Width);
  ReadDimension(edtHeight, 'height', Result.Height);
  if rbGray.Checked then
    Result.PixelFormat := ndpfGray8
  else
    Result.PixelFormat := ndpfRGB8;
  Result.FillColor := FFillColor;
end;

procedure TFrmNewDoc.btnOkClick(Sender: TObject);
var
  w, h: Integer;
  pixels: Int64;
begin
  if not ReadDimension(edtWidth, 'width', w) then
    Exit;
  if not ReadDimension(edtHeight, 'height', h) then
    Exit;
  pixels := Int64(w) * Int64(h);
  if pixels > LARGE_PIXEL_COUNT then
    if MessageDlg(Format('This will allocate about %d megapixels. Continue?',
      [pixels div 1000000]), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  ModalResult := mrOK;
end;

end.
