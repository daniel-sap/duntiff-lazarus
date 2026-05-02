unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  DunTif.Model;

type

  { TFrmMain }

  TFrmMain = class(TForm)
    btnOpen: TButton;
    btnLoad: TButton;
    btnSaveAs: TButton;
    btnRoundtrip: TButton;
    lblFile: TLabel;
    lblStatus: TLabel;
    OpenDialog1: TOpenDialog;
    PaintBox1: TPaintBox;
    PanelMain: TPanel;
    PanelTop: TPanel;
    SaveDialog1: TSaveDialog;
    procedure btnLoadClick(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure btnRoundtripClick(Sender: TObject);
    procedure btnSaveAsClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
  private
    FDoc: TDunTifDocument;
    FFileName: string;
    procedure SetFileName(const AFileName: string);
    procedure ClearModel;
    procedure LoadModel;
    procedure SetStatus(const S: string; AColor: TColor = clDefault);
    procedure RedrawImage;
  end;

var
  FrmMain: TFrmMain;

implementation

uses
  DunTif.ModelReader, DunTif.ModelWriter,
  FPImage;

{$R *.lfm}

procedure StretchDrawFPImage(ACanvas: TCanvas; const ARect: TRect; AImg: TFPCustomImage);
var
  Bmp: TBitmap;
  x, y: Integer;
  c: TFPColor;
begin
  if (AImg = nil) or (AImg.Width <= 0) or (AImg.Height <= 0) then
    Exit;

  { TLazIntfImage + TBitmap.LoadFromIntfImage can raise FPImageException "Failed to create handles"
    on some Lazarus/Windows setups; copy pixels via Colors + RGBToColor instead. }
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(AImg.Width, AImg.Height);
    Bmp.PixelFormat := pf32bit;
    for y := 0 to AImg.Height - 1 do
      for x := 0 to AImg.Width - 1 do
      begin
        c := AImg.Colors[x, y];
        Bmp.Canvas.Pixels[x, y] := RGBToColor(c.red shr 8, c.green shr 8, c.blue shr 8);
      end;
    ACanvas.StretchDraw(ARect, Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure TFrmMain.SetStatus(const S: string; AColor: TColor);
begin
  lblStatus.Caption := S;
  if AColor <> clDefault then
    lblStatus.Font.Color := AColor
  else
    lblStatus.Font.Color := clWindowText;
end;

procedure TFrmMain.SetFileName(const AFileName: string);
begin
  FFileName := AFileName;
  if FFileName = '' then
    lblFile.Caption := '(no file selected)'
  else
    lblFile.Caption := FFileName;
end;

procedure TFrmMain.ClearModel;
begin
  FreeAndNil(FDoc);
end;

procedure TFrmMain.LoadModel;
begin
  if FFileName = '' then
    Exit;

  ClearModel;
  try
    FDoc := TDunTifModelReader.LoadFromFile(FFileName);
    RedrawImage;
    SetStatus(Format('Loaded %dx%d  comp=%d  photo=%d  spp=%d  bps=[%s]', [
      FDoc.Width,
      FDoc.Height,
      FDoc.Metadata.Compression,
      FDoc.Metadata.Photometric,
      FDoc.Metadata.SamplesPerPixel,
      FDoc.Metadata.BitsPerSample
    ]), clDefault);
  except
    on E: Exception do
    begin
      ClearModel;
      RedrawImage;
      SetStatus(E.Message, clRed);
      MessageDlg('Load failed', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFrmMain.RedrawImage;
begin
  PaintBox1.Invalidate;
end;

procedure TFrmMain.btnOpenClick(Sender: TObject);
begin
  OpenDialog1.Filter := 'TIFF images|*.tif;*.tiff|All files|*.*';
  if OpenDialog1.Execute then
    SetFileName(OpenDialog1.FileName);
end;

procedure TFrmMain.btnLoadClick(Sender: TObject);
begin
  LoadModel;
end;

procedure TFrmMain.btnSaveAsClick(Sender: TObject);
begin
  if FDoc = nil then
  begin
    SetStatus('Nothing to save — load a TIFF first.', clMaroon);
    Exit;
  end;
  SaveDialog1.Filter := 'TIFF images|*.tif;*.tiff|All files|*.*';
  SaveDialog1.DefaultExt := 'tif';
  if not SaveDialog1.Execute then
    Exit;
  try
    TDunTifModelWriter.SaveToFile(SaveDialog1.FileName, FDoc);
    SetStatus('Saved: ' + SaveDialog1.FileName, clGreen);
  except
    on E: Exception do
    begin
      SetStatus(E.Message, clRed);
      MessageDlg('Save failed', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TFrmMain.btnRoundtripClick(Sender: TObject);
var
  tempPath: string;
  doc2: TDunTifDocument;
begin
  if FDoc = nil then
  begin
    SetStatus('Load a file first.', clMaroon);
    Exit;
  end;
  tempPath := IncludeTrailingPathDelimiter(GetTempDir) +
    'duntifdemo_' + IntToStr(GetTickCount64) + '.tif';
  try
    TDunTifModelWriter.SaveToFile(tempPath, FDoc);
    doc2 := TDunTifModelReader.LoadFromFile(tempPath);
    try
      if (doc2.Width = FDoc.Width) and (doc2.Height = FDoc.Height) then
        SetStatus(Format('Roundtrip OK (%dx%d)', [FDoc.Width, FDoc.Height]), clGreen)
      else
        SetStatus(Format('Size mismatch: %dx%d vs %dx%d',
          [doc2.Width, doc2.Height, FDoc.Width, FDoc.Height]), clRed);
    finally
      doc2.Free;
    end;
  except
    on E: Exception do
    begin
      SetStatus(E.Message, clRed);
      MessageDlg('Roundtrip failed', E.Message, mtError, [mbOK], 0);
    end;
  end;
  if FileExists(tempPath) then
    DeleteFile(tempPath);
end;

procedure TFrmMain.PaintBox1Paint(Sender: TObject);
var
  R: TRect;
begin
  R := PaintBox1.ClientRect;
  if (FDoc = nil) or (FDoc.Image = nil) or (FDoc.Width = 0) or (FDoc.Height = 0) then
  begin
    PaintBox1.Canvas.Brush.Color := clBtnFace;
    PaintBox1.Canvas.FillRect(R);
    PaintBox1.Canvas.TextOut(12, 12, 'Open a .tif file and press Load.');
    Exit;
  end;
  try
    PaintBox1.Canvas.Brush.Color := clWhite;
    PaintBox1.Canvas.FillRect(R);
    StretchDrawFPImage(PaintBox1.Canvas, R, FDoc.Image);
  except
    on E: Exception do
    begin
      PaintBox1.Canvas.Brush.Color := clBtnFace;
      PaintBox1.Canvas.FillRect(R);
      PaintBox1.Canvas.TextOut(12, 12, 'Preview error: ' + E.Message);
    end;
  end;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
  ClearModel;
end;

end.
