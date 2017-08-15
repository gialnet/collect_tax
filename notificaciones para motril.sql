CREATE OR REPLACE PROCEDURE NOTIFICACION_DE_APREMIO(
		xCargo     IN CHAR, 
		xFechaNoti IN DATE,
		xAyto      IN CHAR,
		xGenerarCartasPago	IN	CHAR)
AS
mNumero CHAR(10);
xCuantos INTEGER DEFAULT 0;
xSIRECARGO INTEGER;
xZona char(2);
mPrincipal float default 0;

CURSOR cNotificacion IS
	SELECT ID FROM VALORES 
	WHERE AYTO=xAyto
		AND N_CARGO=xCargo
         	AND VOL_EJE='E'
      	AND RELACION_APREMIO IS NULL
	      AND NOTIFICADO='N'
      	AND F_INGRESO IS NULL
	      AND FECHA_DE_BAJA IS NULL
FOR UPDATE OF RELACION_APREMIO,RECARGO,ORDEN_APREMIO;


BEGIN

SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

DAME_RELACION(mNumero);

INSERT INTO RELACIONES_NOTI
             (RELACION,FECHA,CARGO,AYTO,USUARIO,ZONA,SUFIJO,YEAR,REMESA)
   VALUES (mNumero,xFechaNoti,xCargo,xAyto,USER,xZona,'000','0000','00');

/*
  EL FLAG DE CONFIGURACION DEL PROGRAMA xSIRECARGO=0 INDICA SI HAY
  QUE PONER EL 20% AUTOMATICAMENTE EN EL MOMENTO DE GENERAR LA
  NOTIFICACION DE APREMIO.
*/

SELECT RECARGO INTO xSiRecargo FROM CONFIGURACION WHERE ID=1;

IF (xSiRecargo=0) THEN

	FOR xNotificado IN cNotificacion loop

		--me devuelve el principal de la deuda en ejecutiva, ya que si ha habido 
		--entregas a cuenta en voluntaria y luego pasamos a ejecutiva el recibo, 
		--el recargo se tiene que calcular sobre el principal del valor 
		--menos la suma de las entregas a cuenta en voluntaria	

		mPrincipal:=DameIngresosVoluntaria(xNotificado.ID);

	      UPDATE VALORES SET RELACION_APREMIO=mNumero,ORDEN_APREMIO=xNotificado.ID,
		                  RECARGO=ROUND((mPrincipal*20/100), 2)
		where current of cNotificacion;

		xCuantos:=xCuantos + 1;

	end loop;
ELSE
      UPDATE VALORES SET RELACION_APREMIO=mNumero,ORDEN_APREMIO=ID
      WHERE AYTO=xAyto
		AND N_CARGO=xCargo
        	AND VOL_EJE='E'
       	AND RELACION_APREMIO IS NULL
	      AND NOTIFICADO='N'
      	AND F_INGRESO IS NULL
	      AND FECHA_DE_BAJA IS NULL;

	xCuantos:=SQL%ROWCOUNT;

END IF;

INSERT INTO NOTIFICACIONES
             (VALOR,N_ENVIOS,TIPO_NOTI,NIF,F_1INTENTO,N_RELACION,N_ORDEN)
SELECT ID,1,'000',NIF,xFechaNoti, mNumero, ORDEN_APREMIO
	          FROM VALORES 
		    WHERE RELACION_APREMIO = mNumero;


/* ESTO ES PARA GRABAR EN APREMIOS CUANTOS RECIBOS SON */
UPDATE RELACIONES_NOTI SET RECIBOS=xCuantos WHERE RELACION=mNumero;

UPDATE CARGOS SET APREMIADO='S' WHERE CARGO=xCargo AND AYTO=xAyto;

END;
/
