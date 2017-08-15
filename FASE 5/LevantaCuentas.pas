unit LevantaCuentas;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  DBTables, Db, Grids, DBGrids, StdCtrls, Buttons, ComCtrls, ExtCtrls, Ora,
  MemDS, DBAccess;

type
  TViewPLCuentas = class(TForm)
    DBGrid1: TDBGrid;
    QLevantar: TOraQuery;
    dsLevanta: TOraDataSource;
    Levanta: TBitBtn;
    Animate1: TAnimate;
    QCuentas: TOraQuery;
    spLevanta: TOraStoredProc;
    BEli: TBitBtn;
    RGTipo: TRadioGroup;
    DBGrid2: TDBGrid;
    QDetalle: TOraQuery;
    dsDetalle: TOraDataSource;
    QEntidad: TOraQuery;
    QOfi: TOraQuery;
    QLevantarIDEXPE: TFloatField;
    QLevantarZONA: TStringField;
    QLevantarLOTE: TStringField;
    QLevantarNIF: TStringField;
    QLevantarLEVANTADO: TStringField;
    QLevantarF_ENTRADA: TDateTimeField;
    QLevantarNIF_1: TStringField;
    QLevantarNOMBRE: TStringField;
    QLevantarVIA: TStringField;
    QLevantarCODIGO_DE_CALLE: TStringField;
    QLevantarCALLE: TStringField;
    QLevantarESCALERA: TStringField;
    QLevantarPLANTA: TStringField;
    QLevantarPISO: TStringField;
    QLevantarPOBLACION: TStringField;
    QLevantarPROVINCIA: TStringField;
    QLevantarCODIGO_POSTAL: TStringField;
    QLevantarESTADO_CIVIL: TStringField;
    QLevantarTIPO_CORREO: TStringField;
    QLevantarPAIS: TStringField;
    QLevantarCONYUGE: TStringField;
    QLevantarREPRESENTANTE: TStringField;
    QLevantarNUMERO: TStringField;
    BSalir: TBitBtn;
    Bevel1: TBevel;
    BSoporte: TBitBtn;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure LevantaClick(Sender: TObject);
    procedure BEliClick(Sender: TObject);
    procedure RGTipoClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure BSoporteClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ViewPLCuentas: TViewPLCuentas;

implementation

uses ComoPrint, CoFuncionesString, PREGUNTA, DiscoEnvioInformacion, Fecha;



{$R *.DFM}

procedure TViewPLCuentas.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  QLevantar.close;
  QDetalle.close;
end;


procedure TViewPLCuentas.LevantaClick(Sender: TObject);
var cadena,mFecha: String;
    mOfi,mDireOfi:string;
    mCuentas:array[0..3] of string;
    mImporte:array[0..3] of string;
    mNuevaReten:array[0..3] of string;
    mSuma:double;
    i:integer;
begin

   if QLevantar.IsEmpty then
      exit;

   Animate1.Visible:=True;
   Animate1.play(1,0,0);

   case RGTipo.ItemIndex of
      0: cadena:='select * from cuentas_a_levantar '+
                 'where id=:ID and entidad=:ENTIDAD ';
      1: cadena:='select * from cuentas_a_levantar '+
                 'where id=:ID and entidad=:ENTIDAD and oficina=:OFICINA ';
   end;

   QCuentas.close;
   QCuentas.SQL.Clear;
   QCuentas.SQL.Add(cadena);
   QCuentas.Open;
   if QCuentas.FieldByName('F_RETENCION').AsDateTime=0 then
      mFecha:=''
   else
      mFecha:=FormatDateTime('d "de"  mmmm  "de"  yyyy',
           QCuentas.fieldbyname('F_RETENCION').AsDateTime);

   mSuma:=0;

   for i:=0 to 3 do
   begin
      if QCuentas.EOF then
         break;

      mCuentas[i]:=QCuentas.fieldbyname('entidad').AsString+'-'+
                   QCuentas.fieldbyname('oficina').AsString+'-'+
                   QCuentas.fieldbyname('dc').AsString+'-'+
                   QCuentas.fieldbyname('cuenta').AsString;

      mImporte[i]:=FormatFloat('0.00',QCuentas.fieldbyname('retenido').AsFloat);

      mNuevaReten[i]:=FormatFloat('0.00',QCuentas.fieldbyname('nuevareten').AsFloat);

      mSuma:=mSuma+QCuentas.fieldbyname('retenido').AsFloat;
      QCuentas.Next;
   end;

   QEntidad.Open;

   //solamente si quieren imprimir la diligencia por oficinas lo abrimos, sino
   //daría error
   if RGTipo.ItemIndex=1 then
   begin
      QOfi.Open;
      mOfi:=QOfi.fieldbyname('oficina').AsString;
      mDireOfi:=QOfi.fieldbyname('direccion').AsString;
      QOfi.close;
   end;

   Application.CreateForm(TComoPrintForm, ComoPrintForm);
   try
      ComoPrintForm.qDocu:='100002';
      ComoPrintForm.CodigoTramite:=-1; //<0 para no ejecutar cierto código
      ComoPrintForm.Quien:='LEVANTAR CUENTAS';
      ComoPrintForm.mTipoCli:='LOC';
      ComoPrintForm.NIFDestinatario:='';
      ComoPrintForm.mIDExpe:=QLevantar.fieldbyname('IDExpe').AsInteger;
      ComoPrintForm.mLote:=QLevantar.fieldbyname('Lote').AsString;
      ComoPrintForm.mEntidad:=QEntidad.fieldbyname('entidad').AsString;
      ComoPrintForm.mNombreEntidad:=QEntidad.fieldbyname('nombre').AsString;
      ComoPrintForm.mSucursal:=mOfi;
      ComoPrintForm.mNombreOficina:=TRIMRIGHT(mDireOfi);
      ComoPrintForm.mCausa:='ingresados';
      ComoPrintForm.mFRetencion:=mFecha;
      ComoPrintForm.mImporteEntrega:=FormatFloat('#,##0.00',mSuma);

      ComoPrintForm.mCuenta1:=mCuentas[0];
      ComoPrintForm.mCuenta2:=mCuentas[1];
      ComoPrintForm.mCuenta3:=mCuentas[2];

      ComoPrintForm.mImporte1:=mImporte[0];
      ComoPrintForm.mImporte2:=mImporte[1];
      ComoPrintForm.mImporte3:=mImporte[2];

      ComoPrintForm.mNuevaReten1:=mNuevaReten[0];
      ComoPrintForm.mNuevaReten2:=mNuevaReten[1];
      ComoPrintForm.mNuevaReten3:=mNuevaReten[2];

      ComoPrintForm.mTotal:=FormatFloat('#,##0.00',mSuma);
      ComoPrintForm.Label1.Caption:='DILIGENCIA DE LEVANTAMIENTO DE CUENTAS CORRIENTES';
      ComoPrintForm.ShowModal;
   finally
      ComoPrintForm.Free;
   end;

   QCuentas.close;
   QEntidad.close;

   Animate1.Visible:=False;
   Animate1.stop;


end;

procedure TViewPLCuentas.BEliClick(Sender: TObject);
var resp:TModalResult;
begin

   if QLevantar.IsEmpty then
      exit;

   Application.CreateForm(TSINO, SINO);
   try
      SINO.Caption:='Eliminar levantamiento de expedientes';
      SINO.L1.Caption:='¿Está seguro de eliminar el levantamiento del Exp: '+
                       QLevantar.fieldbyname('IDEXPE').AsString + ' ?';
      SINO.ShowModal;
   finally
      resp:=SINO.ModalResult;
      SINO.Free;
   end;

   if resp<>idOK then
      exit;


   spLevanta.ParamByName('xIDExpe').AsInteger:=
                QLevantar.fieldbyname('IDEXPE').AsInteger;
   QLevantar.close;
   try
      spLevanta.ExecProc;
   Except
      On E:EDBEngineError do
      begin
         if GetSQLCode(E)=6550 then
            ShowMessage('No tiene autorización suficiente')
      end;
   End;
   spLevanta.Close;
   QLevantar.open;

end;

procedure TViewPLCuentas.RGTipoClick(Sender: TObject);
var cadena:string;
begin

   case RGTipo.ItemIndex of
      0:
       cadena:='select ID,entidad from cuentas_a_levantar '+
            'where id=:IDExpe group by ID,entidad';
      1:
       cadena:='select ID,entidad,oficina from cuentas_a_levantar '+
            'where id=:IDExpe group by ID,entidad,oficina';
   end;

   with QDetalle do
      begin
         close;
         SQL.Clear;
         SQL.Add(cadena);
         Open;
      end;

end;

procedure TViewPLCuentas.FormActivate(Sender: TObject);
begin
   QLevantar.Open;
   QDetalle.Open;
end;

procedure TViewPLCuentas.BSoporteClick(Sender: TObject);
var
   mFecha:TDateTime;
   resp:TModalResult;
begin

   // pedir fecha límite de entrada en el levantamiento
   Application.CreateForm(TFech,Fech);
   Try
      Fech.Caption:='Fecha límite entrada en el levantamiento';
      Fech.ShowModal;
   Finally
      mFecha:=Fech.DTPFecha.Date;
      resp:=Fech.ModalResult;
      Fech.Free;
   End;

   if (resp<>mrOk) then
      Exit;

   Application.CreateForm(TDiscoEmbargos, DiscoEmbargos);
   try
      DiscoEmbargos.mFecha:=mFecha;
      DiscoEmbargos.mEntidad:=QDetalle.FieldByName('ENTIDAD').AsString;
      case RGTipo.ItemIndex of
         0: DiscoEmbargos.mOficina:='0000';
         1: DiscoEmbargos.mOficina:=QDetalle.FieldByName('OFICINA').AsString;
      end;
      DiscoEmbargos.Llamador:='FASE5';
      DiscoEmbargos.ShowModal;
   finally
      DiscoEmbargos.Free;
   end;
end;

end.
