--
-- ********************************** GENERAR LOS ACUSES ******************************
--

--
-- Notificaci�n de un valor en voluntaria
--
-- 1. Si el valor NO tiene notificaci�n, se crea una notificaci�n para el mismo
--
-- 2. Si el valor tiene notificaci�n (y no esta enviado al BOP),
--  	incrementa el numero de envios de la notificaci�n (N_ENVIOS).
--
CREATE OR REPLACE PROCEDURE NOTIFICACION_ENVOLUNTARIA(
		xIDValor 	IN INTEGER,
		xRelacion 	IN Char,
		xNif 		in CHAR,
		xOrden	in integer)
AS
xF_Envio_BOP DATE;
BEGIN


--UPDATE VALORES SET ORDEN_APREMIO=ID
--      WHERE ID=xIDValor
--	RETURN NIF INTO xNif;

-- Inserto una notificaci�n para este valor en caso de que no la hubiese con antelaci�n
begin
   SELECT F_ENVIO_BOP INTO xF_ENVIO_BOP FROM NOTIFICACIONES WHERE VALOR=xIDValor AND
	TIPO_NOTI='VOL';
EXCEPTION
   WHEN NO_DATA_FOUND THEN
   	INSERT INTO NOTIFICACIONES(VALOR,N_ENVIOS,TIPO_NOTI,NIF,F_1INTENTO,N_ORDEN,N_RELACION)
      	VALUES (xIDValor,1,'VOL',xNif,SYSDATE,xOrden, xRelacion);
	RETURN;
end;

IF xF_ENVIO_BOP IS NULL THEN-- Si no est� enviado ni publicado en el BOP, modifico las Notif.
	UPDATE NOTIFICACIONES SET N_ENVIOS=N_ENVIOS+1, F_2INTENTO=SYSDATE,F_INTENTO=SYSDATE
	WHERE VALOR=xIDValor
		AND TIPO_NOTI='VOL';
END IF;

END;
/

--
--
-- Notificaciones en voluntaria por cargos o conjunto de cargos
--
--
CREATE OR REPLACE PROCEDURE NotificacionesVolCargos
AS

xZona 	char(2);
mNumero 	char(10);
xCargoRela	char(10);
xCuantos    Integer;
xAYTO 	Char(3);
xCARGO 	CHAR(10);
xOrden	integer default 0;


-- Conjunto de cargos

CURSOR cAYTOS IS SELECT AYTO, CARGO
	FROM TMP_LISTACARGOS WHERE SESIONID=GETSID();

-- Relaci�n de valores en voluntaria y pendiente de ingreso de un conjunto de cargos

CURSOR cCargo IS
	SELECT ID,NIF FROM VALORES
	WHERE AYTO=xAYTO
		AND N_CARGO=xCARGO
		AND VOL_EJE='V'
      	AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL;



BEGIN


SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

DAME_RELACION(mNumero);

	begin
		SELECT distinct CARGO into xCargoRela FROM TMP_LISTACARGOS WHERE SESIONID=GETSID();
	exception
		when too_many_rows then
			xCargoRela:=null;
	end;


INSERT INTO RELACIONES_NOTI
	(RELACION, FECHA, CARGO, USUARIO, ZONA, VOL_EJE)
	VALUES (mNumero, sysdate, xCargoRela, USER, xZona, 'V');


FOR v_cAYTOS IN cAYTOS LOOP

	xAYTO:=v_cAYTOS.AYTO;
	xCARGO:=v_cAYTOS.CARGO;
	FOR v_cCargo IN cCargo LOOP

		xOrden:=xOrden+1;
		NOTIFICACION_ENVOLUNTARIA(v_cCargo.ID,mNumero,v_cCargo.NIF,xOrden);

	END LOOP;


END LOOP;

SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES WHERE N_RELACION=mNumero;

IF xCuantos > 0 THEN

   UPDATE RELACIONES_NOTI SET RECIBOS=xCuantos
	WHERE RELACION=mNumero;
ELSE

   DELETE FROM RELACIONES_NOTI WHERE RELACION=mNumero;

END IF;

END;
/

--
-- Notificaciones en voluntaria de una liquidaci�n o de un  grupo de liquidaciones
--
--
-- Todas las liquidaciones del grupo tienen que tener tupla en NOTIFICACIONES.
-- Esto se protege desde DELPHI.
--
--
CREATE OR REPLACE PROCEDURE NOTIFICACION_VOL_GRUPO(
		xIDValor 	IN INTEGER,
		xGrupo	IN INTEGER,
		xRelacion 	IN Char,
		xNif 		in CHAR,
		xOrden	in integer)
AS
	xNifV		CHAR(10);
	xRelacionV 	CHAR(10);
	xOrdenV	INTEGER;

	Cursor CLiquidaciones is
		SELECT ID,IDVALOR,NIF FROM LIQUIDACIONES WHERE GRUPO=xGRUPO;
BEGIN

   IF xGRUPO=0 THEN

	NOTIFICACION_ENVOLUNTARIA(xIDValor,xRelacion,xNif,xOrden);

   ELSE

	FOR VLIQUI IN CLiquidaciones LOOP

		begin
			SELECT NIF,N_RELACION,N_ORDEN

			INTO xNifV,xRelacionV,xOrdenV

			FROM NOTIFICACIONES WHERE VALOR=VLIQUI.IDVALOR AND TIPO_NOTI='VOL';
		exception
			when no_data_found then
				xNifV:=null;
		end;

		if xNifV is not null then
			NOTIFICACION_ENVOLUNTARIA(VLIQUI.IDValor,xRelacionV,xNifV,xOrdenV);
		end if;

	END LOOP;

   END IF;

END;
/



-- Creado: 24/03/2003. Agust�n Le�n Robles
--
-- Calcular el final del periodo voluntario de las liquidaciones, segun la fecha de la notificacion
--	Las notificadas o publicadas entre el d�a 1 y el 15 su final del periodo voluntario es el 5 del mes siguiente
--	Las notificadas o publicadas entre el d�a 16 y el final de cada mes su final del periodo voluntario 
--		es el 20 del mes siguiente
--
-- Modificado: 08/06/2004. Agust�n Le�n Robles. Entrada en vigor de la Nueva Ley General Tributaria (art 62). 
--	Las notificadas o publicadas entre el d�a 1 y el 15 su final del periodo voluntario es el 20 del mes siguiente
--	Las notificadas o publicadas entre el d�a 16 y el final de cada mes su final del periodo voluntario 
--		es el 5 del segundo mes posterior
create or replace function DameFinalPerVoluntaria(xFRecibi	IN	date)
return date
AS
	xDIA             INTEGER;
	xMES             INTEGER;
	xYEAR            INTEGER;
	NDIA             INTEGER;
	NMES             INTEGER;
	NYEAR            INTEGER;
	xFECHA_CAD       CHAR(19);
	xDiaSemana 		 varchar2(15);
	xFecha			 date;
BEGIN


	NDIA:=DAYOFMONTH(xFRecibi);
	NMES:=MONTH(xFRecibi);
	NYEAR:=F_YEAR(xFRecibi);

	--Entrada en vigor de la nueva Ley General Tributaria art. 62 Ley 58/2003 de 17 de diciembre 
	if trunc(SYSDATE,'dd') >= to_Date('01/07/2004','DD/MM/YYYY') then
	
		IF NDIA < 16 THEN
			xDIA:=20;
			xMES:=NMES+1;
		ELSE
			xDIA:=5;
			xMES:=NMES+2;
		END IF;		
		
		xYEAR:=NYEAR;
		
		if xMES=13 then
			xMES:=1;
			xYEAR:=NYEAR+1;
		end if;
	
		if xMES=14 then
			xMES:=2;
			xYEAR:=NYEAR+1;
		end if;
	
	else --Antiguos plazos de pago de las liquidaciones en voluntaria		

		IF NDIA < 16 THEN
			xDIA:=5;
		ELSE
			xDIA:=20;
		END IF;

		xMES:=NMES+1;
		xYEAR:=NYEAR;

		IF NMES = 12 THEN
			xMES:=1;
			xYEAR:=NYEAR+1;
		END IF;

	end if;
	
	xFECHA_CAD:= xDia||'/'||xMes||'/'||xYear;	
	xFecha:=TO_DATE(xFECHA_CAD,'dd/mm/yyyy');
	
	select to_char(xFecha,'Day') into xDiaSemana from Dual;

	--SABADO
	if Upper(RTRIM(xDiaSemana)) in ('S�BADO','SABADO','SATURDAY') then
		xFecha:=xFecha+2;
	--DOMINGO
	elsif Upper(RTRIM(xDiaSemana)) IN ('DOMINGO','SUNDAY') then
		xFecha:=xFecha+1;	
	end if;	
	
	return xFecha;

END;
/


/******************************************************************************************
Acci�n: Procesar los acuses
Autor: Lucas Fern�ndez P�rez
Parametros:
	xID     : Id de la notificaci�n en la tabla Notificaciones
	xIDLiqui: ID de la liquidaci�n en la tabla Liquidaciones
	xTipoAcuse:  0: No se trabaja con la tabla NOTIFICACIONES.
			 1: Se trabaja con la tabla de NOTIFICACIONES.
	xFRecibi: Fecha del Recibi
	xAcuse: C�digo de Acuse de Recibo
	xTercero: Datos para el tipo de acuse TERCERO
	xTipo: 1-El interesado, 2-Un tercero, 3-Rehusado, 4-Desconocido, 5-Ausente
	xReferencia: Referencia donde esta el acuse
MODIFICACI�N: 16/12/2002 M� Carmen Junco G�mez. Si la liquidaci�n ten�a calculada la fecha
	de fin del periodo voluntario (cuaderno 60), cambiamos esta fecha por la nueva
	fecha calculada, s�lo si la notificaci�n ha sido positiva. Lo mismo en la tabla
	de valores.
MODIFICACION: 24/03/2003. Agust�n Le�n Robles. Se actualiza el final del periodo 
			voluntario solo si el acuse es positivo
			
MODIFICACION: 25/03/2003. Lucas Fern�ndez P�rez. Si el pase era manual,no pon�a la fecha
	de notificaci�n porque no consultaba si la notificaci�n era positiva (la consulta estaba
	dentro de la opci�n de pase autom�tico).

******************************************************************************************/
CREATE OR REPLACE PROCEDURE AplicarWriteAcuseVoluntaria(
         xID          IN INTEGER,
         xIDLiqui     IN INTEGER,
	   xTipoAcuse   IN INTEGER,
         xFRecibi     IN DATE,
         xAcuse       IN CHAR,
         xTercero     IN VARCHAR,
         xTipo        IN CHAR,
	   xReferencia  IN VARCHAR)

AS
    xNoti 			char(1);
    xEnvios 		INTEGER;
    xF_Envio		date;
    xF_Publi		date;

BEGIN


	--xNoti: si el acuse de recibo elegido es del tipo notificado o no
	Select notificado into xNoti from tipo_acuses where tipo=xTipo;

   IF xTipoAcuse=1 THEN -- El acuse es sobre la tabla de NOTIFICACIONES.

	-- ver qu� envio es este, si es el primero o el segundo
	SELECT N_ENVIOS,F_ENVIO_BOP,F_PUBLICACION
	INTO xEnvios,xF_Envio,xF_Publi
	FROM NOTIFICACIONES WHERE ID=xID;

	-- Si esta enviado al BOP o publicado, no acepta modificar la Notificacion

	IF (xF_ENVIO IS NOT NULL OR xF_Publi IS NOT NULL) THEN
		RETURN;
	END IF;

	-- Primer intento
	IF xEnvios=1 THEN
		UPDATE notificaciones Set
			F_1ACUSE=xFRecibi,ACUSE1=xAcuse,TERCERO_1NOTIFI=xTercero,
			NOTIFICADO=xNoti,F_NOTIFICACION=xFRecibi,
			F_LAST_ACUSE=xFRecibi,LAST_ACUSE=xAcuse,
			Referencia=xReferencia
      	WHERE id=xID;

	ELSE  --segundo intento

		UPDATE notificaciones Set
			F_2ACUSE=xFRecibi, ACUSE2=xAcuse,TERCERO_2NOTIFI=xTercero,
			NOTIFICADO=xNoti,F_NOTIFICACION=xFRecibi,
			F_LAST_ACUSE=xFRecibi,LAST_ACUSE=xAcuse,
			Referencia=xReferencia
	      WHERE id=xID;
	END IF;

	IF xNOTI='S' THEN
	   UPDATE VALORES SET FIN_PE_VOL=DameFinalPerVoluntaria(xFRecibi)
	   WHERE ID=(SELECT IDVALOR FROM LIQUIDACIONES WHERE ID=xIDLIQUI);
	END IF;

   END IF; -- If tipoacuse=1


   -- Hago la notificaci�n en la tabla de LIQUIDACIONES,
   -- calculando el FIN DE PERIODO VOLUNTARIO
   -- si ya ten�a fecha de final del periodo voluntario (por cuaderno60), cambiamos esta
   -- fecha por la fecha calculada, s�lo en el caso en el que la notificaci�n haya sido
   -- positiva.
   IF (xNOTI='S') THEN
      UPDATE LIQUIDACIONES SET F_NOTIFICACION=xFRecibi,
						F_FIN_PE_VOL=DECODE(xNOTI,'S',DameFinalPerVoluntaria(xFRecibi),F_FIN_PE_VOL)
	WHERE ID=xIDLIQUI;
   END IF;

   IF SQL%FOUND THEN
	INSERT_HISTORIA_LIQUI(xIDLiqui,'W','SE GRABA LA F. DE NOTIFICACION');
   END IF;


END;
/

--
-- Parametros:
--		xIDNoti : Id de Notificaciones
--		xIDLiqui: Id de Liquidaciones
--		xTipoAcuse:  0: No se trabaja con la tabla NOTIFICACIONES.
--				 1: Se trabaja con la tabla de NOTIFICACIONES.
--		xIDValor: ID de Valores
--		xGrupo: Grupo de liquidaciones a procesar
--		xFRecibi: Fecha del Recibi
--		xAcuse: C�digo de Acuse de Recibo
--		xTercero: Datos para el tipo de acuse TERCERO
--		xTipo: 1-El interesado, 2-Un tercero, 3-Rehusado, 4-Desconocido, 5-Ausente
--		xReferencia: Referencia donde esta el acuse
--
CREATE OR REPLACE PROCEDURE WriteAcuseVoluntaria(
         xIDNoti        IN INTEGER,
	   xIDLiqui		IN INTEGER,
	   xTipoAcuse    	IN VARCHAR,
	   xGrupo	    	IN INTEGER,
         xFRecibi    	IN DATE,
         xAcuse       	IN CHAR,
         xTercero     	IN VARCHAR,
         xTipo        	IN CHAR,
	   xReferencia  	IN VARCHAR)

AS
	Cursor CLiquidaciones is
		SELECT N.ID,L.ID AS IDLIQUI FROM LIQUIDACIONES L, NOTIFICACIONES N
		WHERE L.IDVALOR=N.VALOR AND N.TIPO_NOTI='VOL' AND L.GRUPO=xGRUPO;
BEGIN

   IF xGRUPO=0 THEN
	AplicarWriteAcuseVoluntaria( xIDNoti,xIDLiqui,xTipoAcuse,xFRecibi,xAcuse,
						xTercero,xTipo,xReferencia);
   ELSE
	FOR VLIQUI IN CLiquidaciones LOOP
	   AplicarWriteAcuseVoluntaria(VLIQUI.ID,VLIQUI.IDLIQUI,xTipoAcuse,xFRecibi,xAcuse,
						xTercero,xTipo,xReferencia);
	END LOOP;
   END IF;

END;
/


/*****************************************************************************************
Acci�n: anular el acuse de la Notificaci�n de voluntaria de una liquidaci�n
Parametros:
		xID	  : Id de Notificaciones
		xIDLiqui: ID de Liquidaciones
		xTipoAcuse:  0: No se trabaja con la tabla NOTIFICACIONES.
					 1: Se trabaja con la tabla de NOTIFICACIONES.
MODIFICACI�N: si cuando se grab� el acuse se cambi� la fecha de final del periodo
	    voluntario de la liquidaci�n y del valor, habr� que poner de nuevo el
	    valor que hubiera.
Modificaci�n: 24/03/2003. Siempre se anula la fecha del final del periodo voluntario
Modificaci�n: 25/01/2005. Lucas Fernandez Perez. Se eliminan los campos FICHERO-IMAGEN e IMAGEN 
   de la tabla NOTIFICACIONES. 
******************************************************************************************/
CREATE OR REPLACE PROCEDURE AplicarAnulaAcuseVoluntaria(
         xID            IN INTEGER,
         xIDLiqui       IN INTEGER,
	   xTipoAcuse	IN INTEGER)

AS
    xEnvios 	INTEGER;
    xF_Envio	date;
    xF_Publi	date;
    xIDVALOR	integer;

BEGIN

   IF xTipoAcuse=1 THEN

	-- ver qu� envio es este, si es el primero o el segundo
	SELECT N_ENVIOS,F_ENVIO_BOP,F_PUBLICACION
	INTO xEnvios,xF_Envio,xF_Publi
	FROM NOTIFICACIONES WHERE ID=xID;

	-- Si esta enviado al BOP o publicado, no anula la Notificacion
	IF (xF_ENVIO IS NOT NULL OR xF_Publi IS NOT NULL) THEN
		RETURN;
	END IF;

	-- Primer intento
	IF xEnvios=1 THEN
		UPDATE notificaciones Set
			F_1ACUSE=NULL,ACUSE1=NULL,TERCERO_1NOTIFI=NULL,
			NOTIFICADO='N',F_NOTIFICACION=NULL,
			F_LAST_ACUSE=NULL,LAST_ACUSE=NULL,
			Referencia=NULL
      	WHERE id=xID;

	ELSE  --segundo intento

		UPDATE notificaciones Set
			F_2ACUSE=NULL, ACUSE2=NULL,TERCERO_2NOTIFI=NULL,
			NOTIFICADO='N',F_NOTIFICACION=NULL,
			F_LAST_ACUSE=F_1ACUSE,LAST_ACUSE=ACUSE1,
			Referencia=NULL
	      WHERE id=xID;

	END IF;

   END IF; -- If tipoAcuse=1


   UPDATE LIQUIDACIONES SET F_NOTIFICACION=NULL, F_FIN_PE_VOL=NULL
   WHERE ID=xIDLiqui
   RETURNING IDVALOR INTO xIDVALOR;

   UPDATE VALORES SET FIN_PE_VOL=NULL WHERE ID=xIDVALOR;

   IF SQL%FOUND THEN
	INSERT_HISTORIA_LIQUI(xIDLiqui,'W','SE ANULA LA F. DE NOTIFICACION');
   END IF;


END;
/

--
-- Parametros:
--		xID: Id de Notificaciones
--		xIDLiqui: ID de Liquidaciones
--		xTipoAcuse:  0: No se trabaja con la tabla NOTIFICACIONES.
--				 1: Se trabaja con la tabla de NOTIFICACIONES.
--
CREATE OR REPLACE PROCEDURE AnulaAcuseVoluntaria(
         xID          IN INTEGER,
         xIDLiqui     IN INTEGER,
	   xGrupo	    IN INTEGER,
	   xTipoAcuse   IN INTEGER)

AS
	Cursor CLiquidaciones is
		SELECT N.ID,L.ID AS IDLIQUI FROM LIQUIDACIONES L, NOTIFICACIONES N
		WHERE L.IDVALOR=N.VALOR AND N.TIPO_NOTI='VOL' AND L.GRUPO=xGRUPO;
BEGIN

   IF xGRUPO=0 THEN
	AplicarAnulaAcuseVoluntaria(xID,xIDLiqui,xTipoAcuse);
   ELSE
	FOR VLIQUI IN CLiquidaciones LOOP
	   AplicarAnulaAcuseVoluntaria(VLIQUI.ID,VLIQUI.IDLIQUI,xTipoAcuse);
	END LOOP;
   END IF;

END;
/

--
-- ********************************** PROCESAR LAS PUBLICACIONES ************************
--

--
-- Mandar a publicar aquellas notificaciones que tras recibir su acuse de recibo
-- han quedado sin notificar en una determinada relaci�n o en todas las relaciones
--
-- xTodas: 'S' -> De todas las relaciones. 'N'-> S�lamente de la relacion "xRela"
--
-- xTIPO: 	1. Con acuse negativo (Desconocidos o ausentes) en 2� Notificaci�n
--		2. Casos especiales de 2� Notificaci�n (accediendo a TMP_BOP)
--		3. Casos especiales de 1� Notificaci�n (accediendo a TMP_BOP)
--		4. Sin Acuse en 1� Notificaci�n
-- MODIFICACION: 28/05/04. Gloria Maria Calle Hernandez. Cambiadas consultas para discriminar
-- por last_acuse no por acuse2 como hac�amos para las de segunda notificaci�n.
-- MODIFICACION: 04/06/04. Gloria Maria Calle Hernandez. Excluir entre los pendientes aquellos 
-- que esten propuestros de baja.

CREATE OR REPLACE PROCEDURE PublicarSendEnVoluntaria(
		xFecha 	In DATE,
		xRela 	IN Char,
		xTODAS 	IN CHAR,
		xTIPO 	IN INTEGER)
AS

xZona 	char(2);
mNumero 	char(10);
xCuantos    Integer;


-- Todas las notificaciones de una relaci�n de correos que est�n sin notificar

   CURSOR cRelacion IS SELECT * FROM NOTIFICACIONES
	WHERE N_RELACION=xRela
	AND NOTIFICADO='N'
	AND F_ENVIO_BOP IS NULL
	FOR UPDATE OF F_ENVIO_BOP;

BEGIN


   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   DAME_RELACION(mNumero);

   INSERT INTO RELACIONES_NOTI
	(RELACION, FECHA, TIPO_NOTI, USUARIO, ZONA, VOL_EJE)
	VALUES (mNumero, sysdate, 'P', USER, xZona, 'V');

   IF xTodas='N' THEN

	if xTIPO='1' then -- Notificaciones con segundo acuse, pero Negativo
  		UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
           	WHERE N_RELACION=xRELA AND NOTIFICADO='N' AND F_ENVIO_BOP IS NULL
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
           		AND LAST_ACUSE IS NOT NULL;

	elsif xTIPO='2' then -- Casos especiales de segundo acuse de notificaci�n
	  	UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
		WHERE N_RELACION=xRELA AND NOTIFICADO='N' AND F_ENVIO_BOP IS NULL
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
			AND LAST_ACUSE IN (SELECT CODIGO FROM TMP_BOP WHERE USUARIO=USER);

	elsif xTIPO='3' then -- Casos especiales de primer acuse de notificaci�n
	  	UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
		WHERE N_RELACION=xRELA AND NOTIFICADO='N' AND F_ENVIO_BOP IS NULL
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
			AND ACUSE1 IN (SELECT CODIGO FROM TMP_BOP WHERE RTRIM(USUARIO)=USER);

	elsif xTIPO='4' then -- Sin primer acuse de notificaci�n
	  	UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
		WHERE N_RELACION=xRELA AND NOTIFICADO='N' AND F_ENVIO_BOP IS NULL
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
			AND F_1ACUSE IS NULL;
	end if;

   ELSE -- IF xTodas='S'

	if xTIPO='1' then -- Notificaciones con segundo acuse, pero Negativo
  		UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
           	WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND TIPO_NOTI='VOL'
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
           		AND LAST_ACUSE IS NOT NULL;

	elsif xTIPO='2' then -- Casos especiales de segundo acuse de notificaci�n
	  	UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
		WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND TIPO_NOTI='VOL'
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
			AND LAST_ACUSE IN (SELECT CODIGO FROM TMP_BOP WHERE USUARIO=USER);

	elsif xTIPO='3' then -- Casos especiales de primer acuse de notificaci�n
	  	UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
		WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND TIPO_NOTI='VOL'
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
			AND ACUSE1 IN (SELECT CODIGO FROM TMP_BOP WHERE RTRIM(USUARIO)=USER);

	elsif xTIPO='4' then -- Sin primer acuse de notificaci�n
	  	UPDATE NOTIFICACIONES SET N_RELACION=mNumero, F_ENVIO_BOP=xFecha
		WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND TIPO_NOTI='VOL'
			AND VALOR IN (SELECT ID FROM VALORES WHERE F_INGRESO IS NULL AND
						FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL)
			AND F_1ACUSE IS NULL;

	end if;


   END IF;



   SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES WHERE N_RELACION=mNumero;
   IF xCuantos > 0 THEN
      UPDATE RELACIONES_NOTI SET RECIBOS=xCuantos
	   WHERE RELACION=mNumero;
   ELSE
   	DELETE FROM RELACIONES_NOTI WHERE RELACION=mNumero;
   END IF;


END;
/


--
-- Recibir la fecha de publicaci�n
--
-- Modificado: 24/03/2003. Agust�n Le�n Robles
--		Cuando se publiquen las liquidaciones el final del periodo voluntario sera en funcion 
--				de la fecha de publicacion
--
CREATE OR REPLACE PROCEDURE PublicarRecibirEnVoluntaria(
		xFecha In DATE,
		xRela IN Char)
AS

CURSOR cLiqui IS SELECT ID,IDVALOR FROM LIQUIDACIONES
	WHERE IDVALOR IN (SELECT VALOR FROM NOTIFICACIONES WHERE
				 N_RELACION=xRela AND F_ENVIO_BOP IS NOT NULL)
	FOR UPDATE OF F_NOTIFICACION;

BEGIN

	UPDATE NOTIFICACIONES SET F_PUBLICACION=xFECHA,NOTIFICADO='S',
                			  F_NOTIFICACION=xFECHA
	WHERE N_RELACION=xRela AND F_ENVIO_BOP IS NOT NULL;

	FOR vLiqui IN cLiqui LOOP

		UPDATE LIQUIDACIONES SET F_NOTIFICACION=xFECHA,
						F_FIN_PE_VOL=DameFinalPerVoluntaria(xFecha)
		WHERE CURRENT OF cLiqui;

		UPDATE VALORES SET FIN_PE_VOL=DameFinalPerVoluntaria(xFecha)
		WHERE ID=vLiqui.IDVALOR and f_ingreso is null and fecha_de_baja is null;

		INSERT_HISTORIA_LIQUI(VLIQUI.ID,'W','SE GRABA LA F.NOTIFICACION POR PUBLICACION EN EL B.O.P.');

	END LOOP;

END;
/

