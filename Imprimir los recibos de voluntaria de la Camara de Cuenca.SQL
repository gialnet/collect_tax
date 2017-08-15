CREATE OR REPLACE PACKAGE PKCamaraVoluntaria
AS

procedure AddNotiCartaPago;

PROCEDURE AllRecibosNotificacion
				(xNIF 	in	char,
				xAyto	in 	char,
				xCargo	in	char);


xNumRecibos			int default 0;
xMaximoPermitido	int;
xCodOpe				int;

END;
/


CREATE OR REPLACE PACKAGE BODY PKCamaraVoluntaria
AS

--
-- Genera la carta de pago 
--
procedure AddNotiCartaPago
as
begin
	
	-- Creo una nueva carta de pago y le meto los recibos
	-- que componen este codigo de operacion
	PkCartaPagoBanco.NewCartaPago;
	PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe);
	
	-- Obtengo un nuevo código de operación
	CODIGO_OPERACION(xCodOpe);
	
	
end;




PROCEDURE AllRecibosNotificacion
				(xNIF 	in	char,
				xAyto	in 	char,
				xCargo	in	char)
AS

--Relacion de deudas de un determinado NIF y ayto, pendientes de cobro
CURSOR cAytoNotificacion IS
	SELECT ID,NOTIFICADO,RELACION_APREMIO,N_CARGO FROM VALORES
	WHERE NIF=xNIF
		AND AYTO=xAyto
		AND N_CARGO=xCargo
	    AND VOL_EJE='V'
     	AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
	for update of CODIGO_OPERACION;

BEGIN

	for v_Noti IN cAytoNotificacion loop		
		
		xNumRecibos:= xNumRecibos + 1;		
		
		UPDATE VALORES SET CODIGO_OPERACION=xCodOpe	where Current of cAytoNotificacion;
	
		IF xNumRecibos=xMaximoPermitido THEN
	
			AddNotiCartaPago;
		
			xNumRecibos:=0;
			
		END IF;
		
	end loop;

END;

END;
/


CREATE OR REPLACE PROCEDURE GeneraCartasPagoVoluntaria	(xAYTO IN 	char)
AS

xCargo	char(10);

--Deudas de un CARGO/S agrupadas por NIF, sin notificar y pendientes de cobro
CURSOR cNIFAytoCargo IS
	SELECT NIF FROM VALORES
	WHERE AYTO=xAyto
		AND N_CARGO=xCargo
		AND VOL_EJE='V'      	
      	AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
	GROUP BY NIF;

BEGIN	

	xCargo:='2003/00026';

	SELECT N_RECIBOS_NOTI into PKCamaraVoluntaria.xMaximoPermitido
	FROM CONFIGURACION WHERE ZONA= (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

	-- Obtengo un código de operación.
	CODIGO_OPERACION(PKCamaraVoluntaria.xCodOpe);	

	for v_NIF IN cNIFAytoCargo LOOP

		PKCamaraVoluntaria.xNumRecibos:=0;

		PKCamaraVoluntaria.AllRecibosNotificacion(v_NIF.NIF,xAyto,xCargo);

		-- Siguiendo con el mismo ejemplo anterior, los 2 recibos restantes
		-- se generan las cartas de pago, y sus notificaciones indicarán
		-- que hay 2 recibos en el mismo. Esta parte se hace despues del cursor
		-- Introduzco los últimos del impreso.
		-- Creo una nueva carta de pago y le meto los recibos del impreso
		if PKCamaraVoluntaria.xNumRecibos > 0 then
			PKCamaraVoluntaria.AddNotiCartaPago;
		end if;

	end loop;


END;
/



--
--
--
CREATE OR REPLACE PROCEDURE ImpreRecibosVolCamaraComercio
AS
xEmisora		char(6);
xSufijo			char(3);
xRemesa			char(2);
xDias			integer;
xImpor			float;
xDC				char(2);
xDIG_C60_M2		char(2);
xFVencimiento	date;
xCodBarraModa1  char(38);
xCodBarraModa2	char(42);
xIdCartaPago 	float;
xNIF			char(10);
xDiaSemana 		varchar2(15);

--
CURSOR cCartasAgrupadas is
		select id FROM CARTAPAGOBANCO WHERE TRUNC(F_CREACION)=TO_DATE('25/11/2003','DD/MM/YYYY')
		and cargo='2003/00026';
		
--relacion de valores de una carta de pago
CURSOR cCartasPagoNoti IS SELECT * FROM RECIBOSCARTAPAGOBANCO
		WHERE cartapagobanco=xIdCartaPago;
		
BEGIN
    
	-- Primero borra todos los datos de las tablas temporales que va a rellenar.
	DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID;
	DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
	DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;
	

	for vGrupo in cCartasAgrupadas loop

		xIdCartaPago:=vGrupo.ID;
		
		for vNoti in cCartasPagoNoti loop

			--insertamos en TMPDEUDASVIVAS y en TmpEntregasValor
			NotifiRellenaCartasPago(xIdCartaPago,vNoti.Valor, xNIF);

		end loop;
		
		
		--insertamos los datos postales de la carta de pago
		PkwtDocIngreso.wtDatosPostalesDeudor(xNIF, 0, 'N');

		--se accede a la tabla de configuracion para recoger los datos de la emisora,
		--sufijo y dias de vencimiento para pagar en el BANCO POR CORREO
		select EMISORA,SUFIJO,DIAS_ASUSTA,REMESA_MOD1 into xEmisora,xSufijo,xDias,xRemesa
		from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

		--averiguamos el importe de la carta de pago porque interviene en el
		--calculo del digito de control

		--Como son cartas masivas hay que sumar los valores pero que corresponde a una
		--carta de pago, no se puede hacer por NIF porque puede que un contribuyente
		--al tener 2 notificaciones tiene 2 cartas de pago.

		select sum(PRINCIPAL) into xImpor from TmpDeudasVivas
		where IDCARTAPAGOBANCO=xIdCartaPago and Usuario=UID;

		--la fecha de vencimiento del pago en el banco sera hoy mas los dias que se le de por
		--configuracion, en el caso de que el resultado de la suma fuera sabado o domingo se pasaría a
		--lunes
		select to_char(sysdate+xDias,'Day') into xDiaSemana from Dual;

		--SABADO
		if Upper(RTRIM(xDiaSemana)) in ('SÁBADO','SABADO','SATURDAY') then
			xFVencimiento:=sysdate+xDias+2;
		--DOMINGO
		elsif Upper(RTRIM(xDiaSemana)) IN ('DOMINGO','SUNDAY') then
			xFVencimiento:=sysdate+xDias+1;
		else
			xFVencimiento:=sysdate+xDias;
		end if;

		
		--calcular los dígitos de control del cuaderno 60 modalidad 1
		--esto se incluye para Ateco, para que no tengan que generarlos ellos al
		--crear la base de datos access. 
		
		CALCULA_DC_60 (xImpor, xIdCartaPago, xSufijo,
					   to_char(sysdate,'yy'),xRemesa,xEmisora,xDC);
					   
		xCodBarraModa1:='90502'||xEmisora||LPAD(xIdCartaPago,10,'0')||xDC||
        				xSufijo||to_char(sysdate,'yy')||xRemesa||
        				LPAD(xImpor*100,8,'0');

		--calcular los digitos de control del cuaderno 60 modalidad 2
		CALCULA_DC_MODALIDAD2_60(xImpor, xIdCartaPago, xSufijo,
			to_char(sysdate,'yy'), '1',
			to_char(xFVencimiento,'y'), to_char(xFVencimiento,'ddd'),
			xEmisora, xDIG_C60_M2);

		xCodBarraModa2:='90521'||xEmisora||LPAD(xIdCartaPago,10,'0')||
				xDIG_C60_M2||'1'||
				xSufijo||to_char(sysdate,'yy')||
				to_char(xFVencimiento,'y')||to_char(xFVencimiento,'ddd')||
				--expresado en centimos de euros
			      LPAD(xImpor*100,8,'0')||'0';

		--se lo pasamos a los datos de cabecera
		Update TmpDeudorDPostales set
				EMISOR=xEmisora,
				REFERENCIA=LPAD(xIdCartaPago,10,'0'),
				TRIBUTO=xSufijo,
				EJERCICIO=to_char(sysdate,'yy'),
				REMESA=xRemesa,
				IMPO=LPAD(xImpor,12,'0'),
				IMPORTE=xImpor,
				DISCRI_PERIODO='1',
				DIGITO_YEAR=to_char(xFVencimiento,'y'),
				F_JULIANA=to_char(xFVencimiento,'ddd'),
				FECHA_VENCIMIENTO=xFVencimiento,
				DC=xDC,
				COD_BARRAS_MOD1=xCodBarraModa1,
				DIGITO_C60_MODALIDAD2=xDIG_C60_M2,
				COD_BARRAS_MOD2=xCodBarraModa2,
				IDCARTAPAGOBANCO=xIdCartaPago
		where usuario=UID and referencia is null;


	end loop;
	
	UPDATE TMPDEUDASVIVAS SET RECARGO20=0,COSTASFIJAS=0,DEUDA=PRINCIPAL,PENDIENTE=PRINCIPAL,PENDIFIJO=PRINCIPAL
	WHERE USUARIO=UID;

END;
/

