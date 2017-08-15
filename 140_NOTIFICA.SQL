-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------
/********************************************************************************/
-- Devuelve el numero siguiente de relación de notificaciones
/********************************************************************************/
/*INTERNO*/
CREATE OR REPLACE PROCEDURE DAME_RELACION(mNumero OUT CHAR)
AS

xIDRela   	INTEGER DEFAULT 0;
xYear 	CHAR(4);

BEGIN

   -- esta primera parte es para lograr el 2000/00033, por ejemplo

   UPDATE GENERNOTI SET ID_RELACION=ID_RELACION+1
   WHERE ID_RELACION > -1
   RETURN ID_RELACION, YEAR_RELACION INTO xIDRela, xYear;

   mNumero:=DAME_NUMEROS(xYear, xIDRela);

END;
/

-- *****************************************************************************************************
-- Permite notificar un valor sin necesidad de generar la relacion del cargo completa.
-- Se usa cuando un valor no tiene notificacion. Este es un caso especial porque en
-- ciertos municipios los valores no notificados no tienen tupla en la tabla de
-- notificaciones.Entonces, cuando se notifican, se crea la tupla.Aqui se hace eso.
-- El valor queda finalmente con notificación y sin relacion de notificación.
-- PARAMETROS ENTRADA: xIDValor ID del valor a notificar
-- Modificacion: 15/04/2005. Lucas Fernández Pérez.
--   Con el cambio de ley, si el valor tiene finpevol>=30/06/2004 , se le graba el 10% de recargo,
--   y si es anterior a esa fecha, se graba el 20% (antes miraba el campo Recargo de la tabla configuración 
--   para grabar 20%, o lo dejaba como estaba (en 10%, pero con el cambio de ley se quedaba en 5%))
-- *****************************************************************************************************

/*DELPHI*/
CREATE OR REPLACE PROCEDURE NOTIFICACION_VALOR(xIDValor   IN INTEGER )
AS
xTipoRecargo float;
xNif       	 CHAR(10);
xFinPeVol    date;
mPrincipal	 float default 0;

BEGIN

  SELECT NIF,FIN_PE_VOL INTO xNIF, xFinPeVol FROM VALORES WHERE ID=xIDValor;

  --Nueva Ley General Tributaria 58/2003 de 18 de Diciembre del 2003
  --Según la Disposición transitoria primera dice: 1. Lo dispuesto en el artículo 28 de esta ley se aplicará
  --a las deudas tributarias cuyo período ejecutivo se inicie a partir de la entrada en vigor de la misma.
  if Trunc(xFinPeVol,'dd')<to_date('30/06/2004','dd/mm/yyyy') then
    xTipoRecargo:=0.2;
  else
    xTipoRecargo:=0.1;
  end if;

  --me devuelve el principal de la deuda en ejecutiva, ya que si ha habido
  --entregas a cuenta en voluntaria y luego pasamos a ejecutiva el recibo, el recargo se
  --tiene que calcular sobre el principal del valor menos la suma de las entregas a cuenta
  --en voluntaria
  mPrincipal:=DameIngresosVoluntaria(xIDValor);
	
  -- con el and ENTREGAS_ANTESDEL_CARGO <= Principal controlamos lo ingresado fuera
  -- de plazo, que si da para cubrir el 100% del principal este recargo no podrá
  -- incrementarse al 20%
  UPDATE VALORES SET ORDEN_APREMIO=ID,
     RECARGO=DECODE(ENTREGAS_A_CUENTA,0,ROUND(CUOTA_INICIAL*xTipoRecargo,2),ROUND(mPrincipal*xTipoRecargo,2))
  WHERE ID=xIDValor
  and ENTREGAS_ANTESDEL_CARGO <= Principal;

  -- Inserto una notificacion para este valor
  INSERT INTO NOTIFICACIONES(VALOR,N_ENVIOS,TIPO_NOTI,NIF,F_1INTENTO,N_ORDEN)
  VALUES (xIDValor,1,'000',xNif,SYSDATE,xIDValor);

END;
/

--
--
-- Primera Notificacion. Para valores solamente.
--
--

-- Se considera que si un nif tiene:
--	6 '9' seguidos
--	8 espacios en blanco
-- se trata de un nif que agrupa a varias personas distintas, por lo que no es un
-- nif individual que identifica a un unico contribuyente.
CREATE OR REPLACE FUNCTION ES_NIF_INDIVIDUAL(
		xNIF IN CHAR
)
RETURN BOOLEAN
AS
BEGIN

-- Nueves  	     '123456'
   IF INSTR(xNIF,'999999')<> 0 THEN
	return (false);

-- Espacios en blanco '12345678'
   ELSIF  INSTR(xNIF, '        ')<> 0 THEN
	return (false);

   END IF;
   return (true);
END;
/

-- Realiza la notificación de apremio de un cargo de un ayuntamiento y arrastra del resto
-- de deudas del contribuyente no notificadas.
-- Los valores del cargo que esten en ejecutiva, sin relacion de apremio, sin
-- notificar, ingresar, y sin dar de baja, se enlazan a una sola relación de notificación
-- de apremio que se crea, y se crea asimismo una notificación vacía para cada uno.
-- Los valores se agruparán en impresos dependiendo de cuantos recibos puedan entrar en un
--    impreso, y se crea una carta de pago por cada impreso.
--
--
--	Hay que generar las notificaciones de solo las deudas que esten sin notificar
--	pero hay que generar la carta de pago (en funcion de la configuracion)
--	de todas las deudas del contribuyentes esten notificado o no, esten en el cargo o no
--
--	Tambien hay que tener en cuenta que en funcion del parametro xCostas hay que generar
--	las costas por adelantado. Esto se hace en un proceso aparte, CURSOR cGrabarCostas
--	porque cuando estamos insertando las notificaciones no sabemos cuanto importe le
--	corresponde a cada recibo
--
/*DELPHI*/
--
-- Procedimiento Principal para generar la providencia de apremio. De todos los cursores
-- declarados obtengo el conjunto de NIF a los que se les va a hacer la notificacion
-- Creado: 17/06/2002 Agustín León Robles.
--

--
-- Modificado 16/09/2003: Agustín León Robles.
--		Se cambia en "if PKNotificaciones.xNotificaciones > 0" por "if PKNotificaciones.xNumRecibos > 0"
--
-- Modificado: 12-05-2004. Agustín León Robles.
--		Los propuestos de baja tampoco se genera notificación. 
-- Modificado: 01-06-2004. Agustín León Robles.
--		Marcamos el Cargo como que se ha apremiado, para controlar que solo se genere notificaciones de aquellos recibos
--		que aun estando en ejecutiva su cargo tiene que estar providenciado de apremio
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren 
--  							notificar los propuestos de baja o no.
-- Modificado: 06/09/2004. Agustín León Robles. Se amplia al resto de opciones para grabar en el campo Apremiado de la tabla
--								de Cargos
-- Modificado: 01/10/2004. Gloria Maria Calle Hernandez. Se Añade parametro Padron para la notificacion de Apremio por conceptos
-- 								y fechas para las liquidaciones. Reestructurado el procedimiento usando cursores dinamicos.
-- Modificado: 26/10/2004. Gloria Maria Calle Hernandez. Se cambia el filtro para el modo 4, en lugar de fecha de cargo se filtra
--								por fecha de emisión de las liquidaciones.
CREATE OR REPLACE PROCEDURE NOTIFICACION_DE_APREMIO
		(xAYTO						IN 	char,
		xPadron						IN	char,
	 	xYear						IN	char,
	 	xFechaDesde 				IN 	date,
	 	xFechaHasta 				IN	date,
	 	xGenCartasPago				IN	char,
	 	xIncluirTodoslosValores		IN 	char,
    	xIncluirPropuBaja 			IN  char,
	 	xMODO						IN 	char)
AS

  -- Variables para crear la sentencia 
  TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type 
  vCURSOR 	   	     tCURSOR;     -- declare cursor variable 
  vSENTENCIA		 VARCHAR2(3000)	 	DEFAULT 'SELECT NIF FROM VALORES';
  vNIF			 	 VARCHAR2(10);

  xZona 	char(2);
  mNumero 	char(10);
  xCargo	char(10);

BEGIN

	PKNotificaciones.xGenerarCartasPago:= xGenCartasPago;
	PKNotificaciones.IncluirTodoslosValores:= xIncluirTodoslosValores;

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	SELECT TIPO_ENTIDAD,N_RECIBOS_NOTI
	  into PKNotificaciones.xEntidadPublica,PKNotificaciones.xMaximoPermitido
	  FROM CONFIGURACION WHERE ZONA=xZONA;

	DAME_RELACION(mNumero);

	IF xMODO='3' THEN

    	--Filtro diferencial de la sentencia: Deudas de un CARGO/S agrupadas por NIF 
    	vSentencia:= vSentencia||'  WHERE N_CARGO IN (SELECT CARGO FROM TMP_LISTACARGOS WHERE SESIONID=GETSID())';

		--con esto Marcamos el Cargo como que se ha apremiado, para controlar que solo se genere notificaciones de aquellos recibos
		--que aun estando en ejecutiva su cargo tiene que estar providenciado de apremio
		update Cargos set Apremiado='S' where Cargo in (SELECT CARGO FROM TMP_LISTACARGOS WHERE SESIONID=GETSID());
	
		begin
			SELECT CARGO into xCargo FROM TMP_LISTACARGOS WHERE SESIONID=GETSID();
		exception
			when too_many_rows then
				xCargo:=null;
		end;
	
	ELSIF xMODO='2' THEN

    	--Filtro diferencial de la sentencia: Deudas de un intervalo de fechas de cargo por conceptos o padrones agrupadas por NIF 
    	vSentencia:= vSentencia||'  WHERE F_CARGO BETWEEN trunc(to_date('''||xFechaDesde||'''),''dd'')'||
					             '  	   		      AND trunc(to_date('''||xFechaHasta||'''),''dd'')';

		--con esto Marcamos el Cargo como que se ha apremiado, para controlar que solo se genere notificaciones de aquellos recibos
		--que aun estando en ejecutiva su cargo tiene que estar providenciado de apremio
		update Cargos set Apremiado='S' where trunc(F_Cargo,'dd') BETWEEN trunc(xFechaDesde,'dd') AND Trunc(xFechaHasta,'dd');
	
	ELSIF xMODO='1' THEN

    	--Filtro diferencial de la sentencia: Deudas de un Año de emision agrupadas por NIF  
    	vSentencia:= vSentencia||'	 WHERE YEAR='''||xYear||'''';
	    
		--con esto Marcamos el Cargo como que se ha apremiado, para controlar que solo se genere notificaciones de aquellos recibos
		--que aun estando en ejecutiva su cargo tiene que estar providenciado de apremio
		update Cargos set Apremiado='S' where to_char(F_Cargo,'yyyy')=xYEAR;
		
	ELSE
    	--Filtro diferencial de la sentencia: Deudas de un intervalo de fechas de emisión y concepto agrupadas por NIF 
    	vSentencia:= vSentencia||'	 WHERE PADRON='''||xPadron||''''||
					 			 '     AND TIPO_DE_OBJETO=''L'' AND ID IN (SELECT IDVALOR FROM LIQUIDACIONES '||
								 '                                          WHERE CONCEPTO='''||xPadron||''''||
					 			 '     AND trunc(F_LIQUIDACION,''dd'') BETWEEN trunc(to_date('''||xFechaDesde||'''),''dd'')'||
					 			 '  	   		                     AND trunc(to_date('''||xFechaHasta||'''),''dd''))';
					 
		--con esto Marcamos el Cargo como que se ha apremiado, para controlar que solo se genere notificaciones de aquellos recibos
		--que aun estando en ejecutiva su cargo tiene que estar providenciado de apremio
		update Cargos set Apremiado='S' 
		 where Cargo in (SELECT distinct N_Cargo FROM VALORES 
		 	   		 	  WHERE Padron=xPadron and tipo_de_objeto='L' 
						    AND F_CARGO BETWEEN to_date(xFechaDesde,'dd/mm/yyyy') AND to_date(xFechaHasta,'dd/mm/yyyy')
							AND AYTO LIKE Decode(PKNotificaciones.xEntidadPublica,'X',xAyto,'%') 
							AND DECODE(FECHA_PROPUESTA_BAJA,NULL,'N','S') LIKE Decode(xIncluirPropuBaja,'N','N','%')
							AND VOL_EJE='E' AND RELACION_APREMIO IS NULL 
							AND NOTIFICADO='N' AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL);
	END IF; 
	
	INSERT INTO RELACIONES_NOTI
		   (RELACION,FECHA,CARGO,AYTO,USUARIO,ZONA,SUFIJO,YEAR,REMESA)
	VALUES (mNumero,sysdate,xCargo,xAyto,USER,xZona,'000','00','00');


	--es el numero que nos servira posteriormente para grabar los acuses de recibo
	PKNotificaciones.xN_ORDEN:=1;
	PKNotificaciones.xCuantos:=0;

	-- Obtengo un código de operación.
	CODIGO_OPERACION(PKNotificaciones.xCodOpe);


	--Terminamos de montar el WHERE de la sentencia: 
	 -- diferenciando si estamos trabajando con multiples municipios y filtrando por Ayto 
	 -- diferenciando si queremos incluir las propuestas de baja o no 
	 -- tomando únicamente aquellos q estén sin notificar y pendientes de cobro 
	 -- agrupando por NIF  
    IF PKNotificaciones.xEntidadPublica='X' THEN
	   vSentencia:= vSentencia||'  AND AYTO LIKE '''||xAyto||'''';
    END IF;

	vSentencia:= vSentencia||'     AND VOL_EJE=''E'''||
				  			 '	   AND RELACION_APREMIO IS NULL'||
				  			 '	   AND NOTIFICADO=''N'''||
   				  			 '	   AND F_INGRESO IS NULL'||
				  			 '	   AND FECHA_DE_BAJA IS NULL'||
				  			 '	   AND F_SUSPENSION IS NULL';

	IF (xIncluirPropuBaja='N') THEN
        vSentencia:= vSentencia||' AND FECHA_PROPUESTA_BAJA IS NULL';
	END IF;

	vSentencia:= vSentencia||'   GROUP BY NIF';
   
    --Abrimos cursor...   
    OPEN vCURSOR FOR vSENTENCIA;
    LOOP
   	   FETCH vCURSOR INTO vNIF;
	   EXIT WHEN vCURSOR%NOTFOUND;

	   PKNotificaciones.xNotificaciones:=0;
	   PKNotificaciones.xNumRecibos:=0;

	   PKNotificaciones.AllRecibosNotificacion(vNIF,xAyto,mNumero,xIncluirPropuBaja);

	   -- Siguiendo con el mismo ejemplo anterior, los 2 recibos restantes
	   -- se generan las cartas de pago, y sus notificaciones indicarán
	   -- que hay 2 recibos en el mismo. Esta parte se hace despues del cursor
	   -- Introduzco los últimos del impreso.
	   -- Creo una nueva carta de pago y le meto los recibos del impreso
	   if PKNotificaciones.xNumRecibos > 0 then
	  	  PKNotificaciones.AddNotiCartaPago(PKNotificaciones.xNotificaciones,mNumero);
	   end if;

	END LOOP;

  CLOSE vCURSOR;
  
-- Esto es para grabar cuantos recibos contiene la relacion
	UPDATE RELACIONES_NOTI SET RECIBOS=PKNotificaciones.xCuantos WHERE RELACION=mNumero;

	PKNotificaciones.AddCostaNotiRelacion(mNumero);

END;
/

--
--
-- Segunda Notificacion. Para valores solamente. 2 Procedimientos.
--
--
/********************************************************************************************/
-- Genera la segunda notificación para los valores de un cargo (xQueEligo='C') o para un
-- número de relacion de apremio (xQueEligo = 'P').
-- Trata los valores del cargo o relacion en ejecutiva, sin enviar al bop, Notificado='N',
-- ingresar, dar de baja, y con acuse de recibo de un tipo determinado de Desconocido/Ausente
-- que se introduce en la tabla tmp_notifi desde DELPHI.
-- Crea una nueva relacion de apremio y estos valores y sus notificaciones apuntaran a ella.
-- Marca esas notificaciones como de segunda notificación.
-- Es decir, las notificaciones de un cargo o relacion con acuse, pero de Desconocido/Ausente.
-- Genera nuevas cartas de pago, teniendo en cuenta la posibilidad de que varios recibos
-- estén en la misma carta de pago por estar en el mismo impreso.
-- Actualiza el número de orden de los valores y notificaciones para la nueva relación.
-- Modificado: 26-03-2002. Lucas Fernández Pérez.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 22-03-2004. Lucas Fernández Pérez. Se optimiza el cursor de grupo quitando
--	una comprobación (V.RELACION_APREMIO=xCodigo) en el caso de que xQueEligo='P'
/*********************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE SEGUNDA_NOTI(
              xQueEligo  IN CHAR,
		  xCodigo    IN CHAR,
              xFechaNoti IN DATE,
		  xAyto      IN CHAR,
		  xSufijo	 IN CHAR,
		  xYear	 IN CHAR,
		  xRemesa	 IN CHAR)

AS
mNumero CHAR(10);
xCuantos INTEGER;
xCargo char(10);
xCodAyto char(3);
xZona char(2);
xNoHayDatos EXCEPTION;  -- no hay ningun valor para generar otro relacion.
				-- Esta excepción se trata desde Delphi

xNIF 			CHAR(10);
xContador 		INTEGER;
xN_ORDEN 		INTEGER;
xContadorRecibos	INTEGER;
xMaximoPermitido	INTEGER;
xResto		INTEGER;
xNumeroObjetos	INTEGER;
xCodOpe		INTEGER;


-- Selecciona todos los valores de una relacion o de un cargo (segun el parámetro
-- xQueEligo) que no esten enviados al bop y tengan acuse de recibo de un tipo determinado,
-- agrupandolos por nif, para poder poner varios valores en un mismo impreso.
CURSOR CGRUPO IS
	SELECT count(*) AS CUANTOS,V.NIF FROM VALORES V, CONTRIBUYENTES C
	WHERE V.NIF=C.NIF
		AND( (xQueEligo='C' -- por cargo
			AND V.AYTO = xAyto
			AND V.N_CARGO = xCodigo
			AND RELACION_APREMIO IS NOT NULL
			AND V.ID IN (select valor from notificaciones
		                  where f_envio_bop is null and tipo_noti<>'VOL' and last_acuse in
                        		(select codigo from tmp_notifi where usuario=user)
					)
		     )
		     OR
		     (xQueEligo='P' -- por relacion de apremio
			AND V.ID IN (select valor from notificaciones
                  		where n_relacion=xCodigo and last_acuse in
                        		(select codigo from tmp_notifi where usuario=user)
						and f_envio_bop is null
				    )
		     )
		)
	    	AND V.VOL_EJE='E'
	      AND V.NOTIFICADO='N'
      	AND V.F_INGRESO IS NULL
	      AND V.FECHA_DE_BAJA IS NULL
	GROUP BY V.NIF;

-- Una vez que se tiene un nif y se sabe cuantos recibos hay del mismo, se recorren estos uno
-- a uno para ir actualizando su n_orden y relacion de apremio.
CURSOR cNotificacion IS
	SELECT ID FROM VALORES V
	WHERE NIF=xNIF
		AND( (xQueEligo='C' -- por cargo
			AND AYTO = xAyto
			AND N_CARGO = xCodigo
			AND RELACION_APREMIO IS NOT NULL
			AND ID IN (select valor from notificaciones
		                  where f_envio_bop is null and tipo_noti<>'VOL' and last_acuse in
                        		(select codigo from tmp_notifi where usuario=user)
					)
		     )
		     OR
		     (xQueEligo='P' -- por relacion de apremio
			AND ID IN (select valor from notificaciones
                  		where valor=v.id and n_relacion=xCodigo and last_acuse in
                        		(select codigo from tmp_notifi where usuario=user)
						and f_envio_bop is null
					)
		     )
		)
	    	AND VOL_EJE='E'
	      AND NOTIFICADO='N'
      	AND F_INGRESO IS NULL
	      AND FECHA_DE_BAJA IS NULL
FOR UPDATE OF RELACION_APREMIO,RECARGO,ORDEN_APREMIO,CODIGO_OPERACION;

BEGIN

   -- comprobar primero que hay algo que generar
   IF (xQueEligo='C') then
      select count(*) into xCuantos from VALORES
      WHERE N_CARGO=xCodigo
		AND AYTO=xAyto
		AND RELACION_APREMIO IS NOT NULL
		AND ID IN (select valor from notificaciones
	                  where f_envio_bop is null and tipo_noti<>'VOL' and last_acuse in
                       		(select codigo from tmp_notifi where usuario=user)
				)
		AND VOL_EJE='E'
		AND NOTIFICADO='N'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL;
   else
	select count(*) into xCuantos from VALORES
	      WHERE RELACION_APREMIO=xCodigo
		AND ID IN (select valor from notificaciones
                 		where n_relacion=xCodigo and last_acuse in
                       		(select codigo from tmp_notifi where usuario=user)
					and f_envio_bop is null
				)
		AND VOL_EJE='E'
		AND NOTIFICADO='N'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL;
   end if;

   if xCuantos=0 then
	RAISE xNoHayDatos;
   end if;

   xCuantos:=0;

   select zona into xZona from usuarios where usuario=user;

   DAME_RELACION(mNumero);

   IF (xQueEligo='P') THEN
      SELECT cargo,ayto into xCargo,xCodAyto
      FROM relaciones_noti
	WHERE relacion=xCodigo and zona=xZona;
   ELSE
	xCargo:=xCodigo;
	xCodAyto:=xAyto;
   END IF;

   -- Genero una nueva relacion de notificaciones.
   INSERT INTO RELACIONES_NOTI
        (RELACION,FECHA,CARGO,AYTO,USUARIO,ZONA,SUFIJO,YEAR,REMESA)
   VALUES (mNumero,xFechaNoti,xCargo,xCodAyto,USER,xZona,xSufijo,xYear,xRemesa);

   -- El Flag N_RECIBOS_NOTI indica cuantos recibos cogen en un impreso de notificación
   SELECT N_RECIBOS_NOTI INTO xMaximoPermitido FROM CONFIGURACION
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   xN_ORDEN:=1;


   FOR v_NIF IN CGRUPO LOOP

	xNIF:=v_NIF.NIF;
	xContador:=0;
	xContadorRecibos:=v_NIF.CUANTOS;
	CODIGO_OPERACION(xCodOpe); -- Obtengo un código de operación.

	-- Si hay mas recibos de los que cogen en un impreso, miro cuantos entran en el último
	-- impreso, porque en la notificación se pone el número de recibos que tiene el impreso.

	-- EJEMPLO: hay 10 recibos y en el impreso cogen 4. Los 8 primeros recibos estarán en
	-- 2 impresos distintos, indicando sus notificaciones que hay 4 recibos en el impreso.
	-- Los 2 recibos restantes estaran en un tercer impreso, y sus notificaciones indicarán
	-- que hay 2 recibos en el mismo.
	IF v_NIF.CUANTOS > xMaximoPermitido THEN
         xResto:=MOD(v_NIF.CUANTOS,xMaximoPermitido);
   	END IF;

	for v_Noti IN cNotificacion loop

	   -- Para rellenar el campo NUMERO_OBJETOS de la notificación hay que calcular
	   -- cuantos recibos entran en el impreso en el que se encuadra el recibo actual.
	   IF NOT ES_NIF_INDIVIDUAL(xNIF) THEN -- Si el nif agrupa a varias personas, cada una
							   -- irá en un impreso distinto.
		xNumeroObjetos:=1;

	   ELSIF v_NIF.CUANTOS > xMaximoPermitido THEN -- Si hay mas recibos de los permitidos
	   	xContadorRecibos:=xContadorRecibos-1;
	   	IF xContadorRecibos < xResto THEN
		   -- Son los recibos restantes (no se completa el impreso)
		   xNumeroObjetos:=xResto;
	   	ELSE -- El recibo estará en un impreso totalmente relleno.
		   xNumeroObjetos:=xMaximoPermitido;
	   	END IF;
	   ELSE
	      xNumeroObjetos:=v_NIF.CUANTOS;
   	   END IF;

	   IF xContador=xMaximoPermitido THEN
	  	xN_ORDEN:=xN_ORDEN+1;
		xContador:=0;
		PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
		PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
		CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   END IF;
	   xContador:=xContador+1;

	   UPDATE VALORES SET RELACION_APREMIO=mNumero,ORDEN_APREMIO=xN_ORDEN,
			CODIGO_OPERACION=xCodOpe
	   where current of cNotificacion;

	   xCuantos:=xCuantos + 1;

	   UPDATE NOTIFICACIONES SET F_2INTENTO=xFechaNoti,
				  F_INTENTO=xFechaNoti,
		              N_ENVIOS=N_ENVIOS + 1 ,
				  ID_COSTAS=NULL,
				  N_RELACION=mNumero,
				  N_ORDEN=xN_ORDEN,
				  NUMERO_OBJETOS=xNumeroObjetos
	   WHERE VALOR= v_NOTI.ID and Tipo_noti<>'VOL';

	   IF NOT ES_NIF_INDIVIDUAL(xNIF) THEN -- Si es individual aunque no lo parezca.
		xN_ORDEN:=xN_ORDEN+1;
		xContador:=0;
		PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
		PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
	   	CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   END IF;

	end loop;

      IF ES_NIF_INDIVIDUAL(xNIF) THEN -- Si es individual el NIF, no se imprimio la carta.
	   -- Introduzco los últimos del impreso.
	   PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
	   PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
	   CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   xN_ORDEN:=xN_ORDEN+1;
	END IF;

   END LOOP;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCuantos WHERE RELACION=mNumero;

END;
/

/********************************************************************************************/
-- Genera la segunda notificación para los valores de un cargo o número de relacion de apremio
-- Es igual que SEGUNDA_NOTI, salvo que tiene en cuenta las notificaciones SIN
-- acuse de recibo, mientras que SEGUNDA_NOTI tenia en cuenta las notificaciones con acuse
-- de recibo de un tipo determinado.
-- Marca esas notificaciones de un cargo o relacion sin acuse como de segunda notificación.
-- Genera nuevas cartas de pago, teniendo en cuenta la posibilidad de que varios recibos
-- estén en la misma carta de pago por estar en el mismo impreso.
-- Actualiza el número de orden de los valores y notificaciones para la nueva relación.
-- Modificado: 26-03-2002. Lucas Fernández Pérez.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 22-03-2004. Lucas Fernández Pérez. Se optimiza el cursor de grupo quitando
--	una comprobación (V.RELACION_APREMIO=xCodigo) en el caso de que xQueEligo='P'
/********************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE SEGUNDA_ACUSE_NOTI(
              xQueEligo  IN CHAR,
		  xCodigo    IN CHAR,
              xFechaNoti IN DATE,
		  xAyto      IN CHAR,
		  xSufijo	 IN CHAR,
		  xYear	 IN CHAR,
		  xRemesa	 IN CHAR)

AS
mNumero CHAR(10);
xCuantos INTEGER;
xCargo char(10);
xCodAyto char(3);
xZona char(2);
xNoHayDatos EXCEPTION;  -- no hay ningun valor para generar otro relacion.
				-- Esta excepción se trata desde Delphi

xNIF 			CHAR(10);
xContador 		INTEGER;
xN_ORDEN 		INTEGER;
xContadorRecibos	INTEGER;
xMaximoPermitido	INTEGER;
xResto		INTEGER;
xNumeroObjetos	INTEGER;
xCodOpe		INTEGER;


-- Selecciona todos los valores de una relacion o de un cargo (segun el parámetro
-- xQueEligo) que no esten enviados al bop y tengan un acuse de recibo determinado,
-- agrupandolos por nif, para poder poner varios valores en un mismo impreso.
CURSOR CGRUPO IS
	SELECT count(*) AS CUANTOS,V.NIF FROM VALORES V, CONTRIBUYENTES C
	WHERE V.NIF=C.NIF
		AND( (xQueEligo='C' -- por cargo
			AND V.AYTO = xAyto
			AND V.N_CARGO = xCodigo
			AND RELACION_APREMIO IS NOT NULL
			AND V.ID IN (select valor from notificaciones
                  		where f_envio_bop is null and last_acuse IS NULL
					and tipo_noti<>'VOL')
		     )
		     OR
		     (xQueEligo='P' -- por relacion de apremio
			AND V.ID IN (select valor from notificaciones
		                  where n_relacion=xCodigo AND
						f_envio_bop is null and last_acuse IS NULL)
		     )
		)
	    	AND V.VOL_EJE='E'
	      AND V.NOTIFICADO='N'
      	AND V.F_INGRESO IS NULL
	      AND V.FECHA_DE_BAJA IS NULL
	GROUP BY V.NOMBRE, V.NIF, C.CODIGO_POSTAL
	ORDER BY C.CODIGO_POSTAL,V.NOMBRE;

-- Una vez que se tiene un nif y se sabe cuantos recibos hay del mismo, se recorren estos uno
-- a uno para ir actualizando su n_orden y relacion de apremio.
CURSOR cNotificacion IS
	SELECT ID FROM VALORES V
	WHERE NIF=xNIF
		AND( (xQueEligo='C' -- por cargo
			AND AYTO = xAyto
			AND N_CARGO = xCodigo
			AND RELACION_APREMIO IS NOT NULL
			AND ID IN (select valor from notificaciones
                  		where f_envio_bop is null and last_acuse IS NULL
					and tipo_noti<>'VOL')
		     )
		     OR
		     (xQueEligo='P' -- por relacion de apremio
			AND ID IN (select valor from notificaciones
		                  where valor=v.id and n_relacion=xCodigo AND
						f_envio_bop is null and last_acuse IS NULL)
		     )
		)
	    	AND VOL_EJE='E'
	      AND NOTIFICADO='N'
      	AND F_INGRESO IS NULL
	      AND FECHA_DE_BAJA IS NULL
FOR UPDATE OF RELACION_APREMIO,RECARGO,ORDEN_APREMIO,CODIGO_OPERACION;

BEGIN

   -- comprobar primero que hay algo que generar
   IF (xQueEligo='C') then
      select count(*) into xCuantos from VALORES
      WHERE N_CARGO=xCodigo
		AND AYTO=xAyto
		AND RELACION_APREMIO IS NOT NULL
		AND ID IN (select valor from notificaciones
                  where f_envio_bop is null and last_acuse IS NULL
			and tipo_noti<>'VOL' )
		AND VOL_EJE='E'
		AND NOTIFICADO='N'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL;
   else
	select count(*) into xCuantos from VALORES
	      WHERE RELACION_APREMIO=xCodigo
		AND ID IN (select valor from notificaciones
                  where n_relacion=xCodigo AND f_envio_bop is null and last_acuse IS NULL)
		AND VOL_EJE='E'
		AND NOTIFICADO='N'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL;
   end if;

   if xCuantos=0 then
	RAISE xNoHayDatos;
   end if;

   xCuantos:=0;

   select zona into xZona from usuarios where usuario=user;

   DAME_RELACION(mNumero);

   IF (xQueEligo='P') THEN
      SELECT cargo,ayto into xCargo,xCodAyto
      FROM relaciones_noti
	WHERE relacion=xCodigo and zona=xZona;
   ELSE
	xCargo:=xCodigo;
	xCodAyto:=xAyto;
   END IF;

   -- Genero una nueva relacion de notificaciones.
   INSERT INTO RELACIONES_NOTI
        (RELACION,FECHA,CARGO,AYTO,USUARIO,ZONA,SUFIJO,YEAR,REMESA)
   VALUES (mNumero,xFechaNoti,xCargo,xCodAyto,USER,xZona,xSufijo,xYear,xRemesa);

   -- El Flag N_RECIBOS_NOTI indica cuantos recibos cogen en un impreso de notificación
   SELECT N_RECIBOS_NOTI INTO xMaximoPermitido FROM CONFIGURACION
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   xN_ORDEN:=1;


   FOR v_NIF IN CGRUPO LOOP

	xNIF:=v_NIF.NIF;
	xContador:=0;
	xContadorRecibos:=v_NIF.CUANTOS;
	CODIGO_OPERACION(xCodOpe); -- Obtengo un código de operación.

	-- Si hay mas recibos de los que cogen en un impreso, miro cuantos entran en el último
	-- impreso, porque en la notificación se pone el número de recibos que tiene el impreso.

	-- EJEMPLO: hay 10 recibos y en el impreso cogen 4. Los 8 primeros recibos estarán en
	-- 2 impresos distintos, indicando sus notificaciones que hay 4 recibos en el impreso.
	-- Los 2 recibos restantes estaran en un tercer impreso, y sus notificaciones indicarán
	-- que hay 2 recibos en el mismo.
	IF v_NIF.CUANTOS > xMaximoPermitido THEN
         xResto:=MOD(v_NIF.CUANTOS,xMaximoPermitido);
   	END IF;

	for v_Noti IN cNotificacion loop

	   -- Para rellenar el campo NUMERO_OBJETOS de la notificación hay que calcular
	   -- cuantos recibos entran en el impreso en el que se encuadra el recibo actual.
	   IF NOT ES_NIF_INDIVIDUAL(xNIF) THEN -- Si el nif agrupa a varias personas, cada una
							   -- irá en un impreso distinto.
		xNumeroObjetos:=1;

	   ELSIF v_NIF.CUANTOS > xMaximoPermitido THEN -- Si hay mas recibos de los permitidos
	   	xContadorRecibos:=xContadorRecibos-1;
	   	IF xContadorRecibos < xResto THEN
		   -- Son los recibos restantes (no se completa el impreso)
		   xNumeroObjetos:=xResto;
	   	ELSE -- El recibo estará en un impreso totalmente relleno.
		   xNumeroObjetos:=xMaximoPermitido;
	   	END IF;
	   ELSE
	      xNumeroObjetos:=v_NIF.CUANTOS;
   	   END IF;

	   IF xContador=xMaximoPermitido THEN
	  	xN_ORDEN:=xN_ORDEN+1;
		xContador:=0;
		PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
		PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
		CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   END IF;
	   xContador:=xContador+1;

	   UPDATE VALORES SET RELACION_APREMIO=mNumero,ORDEN_APREMIO=xN_ORDEN,
			CODIGO_OPERACION=xCodOpe
	   where current of cNotificacion;

	   xCuantos:=xCuantos + 1;

	   UPDATE NOTIFICACIONES SET F_2INTENTO=xFechaNoti,
				  F_INTENTO=xFechaNoti,
		              N_ENVIOS=N_ENVIOS + 1 ,
				  ID_COSTAS=NULL,
				  N_RELACION=mNumero,
				  N_ORDEN=xN_ORDEN,
				  NUMERO_OBJETOS=xNumeroObjetos
	   WHERE VALOR= v_NOTI.ID and tipo_noti<>'VOL';

	   IF NOT ES_NIF_INDIVIDUAL(xNIF) THEN -- Si es individual aunque no lo parezca.
		xN_ORDEN:=xN_ORDEN+1;
		xContador:=0;
		PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
		PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
	   	CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   END IF;

	end loop;

      IF ES_NIF_INDIVIDUAL(xNIF) THEN -- Si es individual el NIF, no se imprimio la carta.
	   -- Introduzco los últimos del impreso.
	   PkCartaPagoBanco.NewCartaPago; -- Creo una nueva carta de pago y le meto
	   PkCartaPagoBanco.AddReciboSeleccionados(xCodOpe,mNumero); -- los recibos del impreso
	   CODIGO_OPERACION(xCodOpe); -- Obtengo un nuevo código de operación.
	   xN_ORDEN:=xN_ORDEN+1;
	END IF;

   END LOOP;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCuantos WHERE RELACION=mNumero;

END;
/
/********************************************************************************************/
-- Genera las segundas o posteriores notificaciones para UN SOLO VALOR O EXPEDIENTE
-- Nunca podran tener costas estas notificaciones, puesto que se considera que
-- estan en el mismo papel de la primera notificacion.
/********************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE SEGUNDA_NOTI_GENERAL(
		  xidNoti		IN CHAR,  -- id de la Notificacion
              xFechaNoti 	IN DATE)  -- Fecha de la Notificación.

AS
BEGIN


	UPDATE NOTIFICACIONES
	SET F_2INTENTO=xFechaNoti, F_INTENTO=xFechaNoti, N_ENVIOS=N_ENVIOS + 1, ID_COSTAS=NULL
	WHERE Id = xidNoti;


END;
/

--
--
-- Pase al B.O.P. Son 8 procedimientos (4 para valores y 4 para expedientes)
--
--

/********************************************************************************************/
-- Envio de notificaciones de valores al B.O.P. Sin filtro de acuse.
-- Crea una nueva relacion de notificaciones, donde apuntarán los valores de una
-- relacion anterior (xTODO='N') o bien todos los valores (xTODO='S') que no estan dados
-- de baja ni suspensos y Notificado='N' y no estan enviados al BOP y SI tienen segundo
-- acuse de recibo.
-- A las notificaciones correspondientes a esos valores se les introduce la FECHA_ENVIO_BOP
-- Modificado 25/6/2002. Agustin Leon Robles.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 28/04/2003. Lucas Fernández Pérez. Se podrán grabar acuses sobre valores 
-- enviados al BOP, por lo que los números de orden en el caso de "Todas las relaciones"
-- podrían solaparse (podrían ser iguales, aunque provenían de distinta relación), 
-- y al grabar un acuse lo grabaríamos de valores que no se debiera.
-- Se cambia por lo tanto el número de orden para distinguir univocamente los valores.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP los valores
-- 	de la ZONA del usuario, antes enviaba todos los valores.
-- Modificado: 22/06/2004. Mª del Carmen Junco Gómez. Las propuestas de baja no han de salir
-- en la publicación.
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren publicar
--  							los propuestos de baja o no.
/********************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE NUMERO_APREMIO_BOP
	(xRELACION		   IN CHAR,
     xFECHAENVIO 	   IN DATE,
     xIncluirPropuBaja IN CHAR,
     xTODO 			   IN CHAR)
AS
	mNUMERO 		CHAR(10);
    mCUANTOSRECIBOS INTEGER;
    xZONA 			CHAR(2);

   	CURSOR C1 IS
	   SELECT ID FROM VALORES
	   WHERE RELACION_APREMIO = mNUMERO;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   DAME_RELACION(MNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,USUARIO,ZONA)
   VALUES
	(MNUMERO,xFECHAENVIO,'P',USER,xZONA);

	--los recibos ingresados también salen en la publicación
   IF xTODO='N' THEN
       UPDATE VALORES SET RELACION_APREMIO=MNUMERO
       WHERE RELACION_APREMIO=xRELACION AND FECHA_DE_BAJA IS NULL AND
  		 F_SUSPENSION IS NULL 
		 AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		 )
  		 AND ID IN (SELECT VALOR FROM NOTIFICACIONES
           		WHERE N_RELACION=xRELACION AND NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND
           			ACUSE2 IS NOT NULL);
   ELSE --Ej: Convierte 2003/00015 nº orden 37 en el nº de orden 200301537
       UPDATE VALORES SET RELACION_APREMIO=MNUMERO,
       	  ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
       WHERE FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL 
		  AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
 		  )
          AND ID IN (SELECT VALOR FROM NOTIFICACIONES
			  WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND ACUSE2 IS NOT NULL
					AND TIPO_NOTI<>'VOL')
		  AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=
		  						(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER));
   END IF;

   FOR v_C1 IN C1 LOOP
      UPDATE NOTIFICACIONES SET N_RELACION=MNUMERO,F_ENVIO_BOP=xFECHAENVIO,
       		N_ORDEN=DECODE(xTODO,'N',N_ORDEN,
       	  		TO_NUMBER(SUBSTR(N_RELACION,1,4)||SUBSTR(N_RELACION,8,3)||to_char(N_ORDEN)))
      WHERE VALOR=v_C1.ID AND TIPO_NOTI<>'VOL';
   END LOOP;


   SELECT COUNT(ID) INTO MCUANTOSRECIBOS FROM VALORES
   WHERE RELACION_APREMIO=MNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=MCUANTOSRECIBOS
   WHERE RELACION=MNUMERO;

END;
/

/*******************************************************************************************/
-- Envio de notificaciones de valores al B.O.P.  Filtro de segundo acuse.
-- Es muy similar a NUMERO_APREMIO_BOP, con la unica diferencia de que el segundo acuse
-- de recibo lo filtra. Los tipos posibles de acuse los mete DELPHI en la tabla TMP_BOP.
-- Pone Fecha de envio a las notificaciones, apuntando a una nueva relacion de notificaciones
-- y hace apuntar a los valores a esa relacion de notificaciones.
-- Modificado 25/6/2002. Agustin Leon Robles.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 28/04/2003. Lucas Fernández Pérez. Se podrán grabar acuses sobre valores 
-- enviados al BOP, por lo que los números de orden en el caso de "Todas las relaciones"
-- podrían solaparse (podrían ser iguales, aunque provenían de distinta relación), 
-- y al grabar un acuse lo grabaríamos de valores que no se debiera.
-- Se cambia por lo tanto el número de orden para distinguir univocamente los valores.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP los valores
-- 	de la ZONA del usuario, antes enviaba todos los valores.
-- 22/06/2004. Mª del Carmen Junco Gómez. Los propuestos de baja no han de entrar en la publicación.
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren publicar
--  							los propuestos de baja o no.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ESPECIAL_SEGUNDA_BOP(
     xRELACION	IN	CHAR,
     xFECHAENVIO IN 	DATE,
     xIncluirPropuBaja IN CHAR,
     xTODO 	IN 	CHAR
)
AS
	MNUMERO 		CHAR(10);
    	MCUANTOSRECIBOS	INTEGER;
    	xZONA 		CHAR(2);
   	CURSOR C1 IS
	   SELECT ID FROM VALORES
	   WHERE RELACION_APREMIO = MNUMERO;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(MNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,USUARIO,ZONA)
   VALUES
	(MNUMERO,xFECHAENVIO,'P',USER,xZONA);

	--los recibos ingresados tambien salen en la publicación
   IF xTODO='N' THEN
  	UPDATE VALORES SET RELACION_APREMIO=MNUMERO
  	WHERE RELACION_APREMIO=xRELACION AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL 
		  AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
 		  )
		  AND ID IN (SELECT VALOR FROM NOTIFICACIONES
           						  WHERE N_RELACION=xRELACION AND NOTIFICADO='N' AND
								  F_ENVIO_BOP IS NULL AND
								  ACUSE2 IN (SELECT CODIGO FROM TMP_BOP
										 WHERE USUARIO=USER));
   ELSE 
  	UPDATE VALORES SET RELACION_APREMIO=MNUMERO,
       	  ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
  	WHERE FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL 
		AND(
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
  		AND ID IN (SELECT VALOR FROM NOTIFICACIONES
            	 WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND TIPO_NOTI<>'VOL' AND
				 ACUSE2 IN (SELECT CODIGO FROM TMP_BOP
						WHERE USUARIO=USER))
	    AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=
		  						(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER));
   END IF;

   FOR v_C1 IN C1 LOOP
    	UPDATE NOTIFICACIONES SET N_RELACION=MNUMERO,F_ENVIO_BOP=xFECHAENVIO,
       		N_ORDEN=DECODE(xTODO,'N',N_ORDEN,
       	  		TO_NUMBER(SUBSTR(N_RELACION,1,4)||SUBSTR(N_RELACION,8,3)||to_char(N_ORDEN)))
      WHERE VALOR=v_C1.ID AND TIPO_NOTI<>'VOL';
   END LOOP;

   SELECT COUNT(ID) INTO MCUANTOSRECIBOS FROM VALORES
   WHERE RELACION_APREMIO=MNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=MCUANTOSRECIBOS
   WHERE RELACION=MNUMERO;

END;
/

/******************************************************************************************/
-- Envio de notificaciones de valores al B.O.P. Filtro de Primer Acuse.
-- Es muy similar a NUMERO_APREMIO_BOP, Y ESPECIAL_SEGUNDA_BOP con la unica diferencia
-- de que realiza filtro sobre el tipo del PRIMER ACUSE de recibo
-- Los tipos posibles de acuse los mete DELPHI en la tabla TMP_BOP.
-- Modificado 25/6/2002. Agustin Leon Robles.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 28/04/2003. Lucas Fernández Pérez. Se podrán grabar acuses sobre valores 
-- enviados al BOP, por lo que los números de orden en el caso de "Todas las relaciones"
-- podrían solaparse (podrían ser iguales, aunque provenían de distinta relación), 
-- y al grabar un acuse lo grabaríamos de valores que no se debiera.
-- Se cambia por lo tanto el número de orden para distinguir univocamente los valores.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP los valores
-- 	de la ZONA del usuario, antes enviaba todos los valores.
-- Modificado: 22/06/2004. Mª del Carmen Junco Gómez. Los propuestos de baja no han de entrar
-- en la publicación.
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren publicar
--  							los propuestos de baja o no.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ESPECIAL_BOP(
     xRELACION	IN	CHAR,
     xFECHAENVIO IN 	DATE,
     xIncluirPropuBaja IN CHAR,
     xTODO 	IN 	CHAR)
AS
	xNUMERO 	CHAR(10);
    	xCUANTOS 	INTEGER;
    	xZONA 	CHAR(2);
   	CURSOR C1 IS
	   SELECT ID FROM VALORES
	   WHERE RELACION_APREMIO = xNUMERO;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(xNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,USUARIO,ZONA)
   VALUES
	(xNUMERO,xFECHAENVIO,'P',USER,xZONA);

	--los recibos ingresados también salen en la publicación
   IF xTODO='N' THEN
   	UPDATE VALORES SET RELACION_APREMIO=xNUMERO
  	WHERE RELACION_APREMIO=xRELACION
  		AND FECHA_DE_BAJA IS NULL
  		AND F_SUSPENSION IS NULL
		AND(
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
  		AND ID IN (SELECT VALOR FROM NOTIFICACIONES
           						  WHERE N_RELACION=xRELACION AND NOTIFICADO='N' AND
								  F_ENVIO_BOP IS NULL AND
								  ACUSE1 IN (SELECT CODIGO FROM TMP_BOP
           									 WHERE RTRIM(USUARIO)=USER));
   ELSE 

  	UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
       	  ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
  	WHERE FECHA_DE_BAJA IS NULL
  		AND F_SUSPENSION IS NULL
		AND(
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
  		AND	ID IN (SELECT VALOR FROM NOTIFICACIONES
		       WHERE NOTIFICADO='N' AND F_ENVIO_BOP IS NULL AND TIPO_NOTI<>'VOL' AND
				 ACUSE1 IN (SELECT CODIGO FROM TMP_BOP
            				WHERE RTRIM(USUARIO)=USER))
		AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=
		  						(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER));

   END IF;

   FOR v_C1 IN C1 LOOP

    	UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFECHAENVIO,
       		N_ORDEN=DECODE(xTODO,'N',N_ORDEN,
       	  		TO_NUMBER(SUBSTR(N_RELACION,1,4)||SUBSTR(N_RELACION,8,3)||to_char(N_ORDEN)))
      		WHERE VALOR=v_C1.ID
      		AND TIPO_NOTI<>'VOL';

   END LOOP;

   SELECT COUNT(ID) INTO xCUANTOS FROM VALORES
   	WHERE RELACION_APREMIO=xNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCUANTOS
   	WHERE RELACION=xNUMERO;

END;
/

/******************************************************************************************/
-- Envio de notificaciones de valores al B.O.P. Sin Primer Acuse.
-- Pone fecha de envio al BOP a las notificaciones sin fecha de Primer Acuse anteriores a una
-- fecha sin dar de baja ni estar suspendidas ni enviadas ya al bop y con Notificado='N'
-- de una relacion o de todas las relaciones.
-- Las notificaciones apuntan a una nueva relacion y los valores tambien.
-- Modificado 25/6/2002. Agustin Leon Robles.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 28/04/2003. Lucas Fernández Pérez. Se podrán grabar acuses sobre valores 
-- enviados al BOP, por lo que los números de orden en el caso de "Todas las relaciones"
-- podrían solaparse (podrían ser iguales, aunque provenían de distinta relación), 
-- y al grabar un acuse lo grabaríamos de valores que no se debiera.
-- Se cambia por lo tanto el número de orden para distinguir univocamente los valores.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP los valores
-- 	de la ZONA del usuario, antes enviaba todos los valores.
-- Modificado: 22/06/2004. Mª del Carmen Junco Gómez. Los propuestos de baja no han de entrar
-- en la publicación.
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren publicar
--  							los propuestos de baja o no.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ESPECIAL_SINACUSE_BOP(
	 xRELACION         IN CHAR,
     xFECHAENVIO       IN DATE,
     xIncluirPropuBaja IN CHAR,
     xTODO             IN CHAR)
AS
	xNUMERO		CHAR(10);
    xCUANTOSRECIBOS 	INTEGER;
    xZONA 		CHAR(2);

   	CURSOR C1 IS
	   SELECT ID FROM VALORES
	   WHERE RELACION_APREMIO = xNUMERO;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(xNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,USUARIO,ZONA)
   VALUES
	(xNUMERO,xFECHAENVIO,'P',USER,xZONA);

	-- los recibos ingresados también salen en la publicación
   IF xTODO='N' THEN
  	UPDATE VALORES SET RELACION_APREMIO=xNUMERO
    	WHERE RELACION_APREMIO=xRELACION
    	AND FECHA_DE_BAJA IS NULL
    	AND F_SUSPENSION IS NULL 
		AND(
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
    	AND ID IN (SELECT VALOR FROM NOTIFICACIONES
           						  WHERE F_1ACUSE IS NULL AND N_RELACION=xRELACION AND
           							  NOTIFICADO='N' AND F_ENVIO_BOP IS NULL);
   ELSE
  	UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
       	  ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
    	WHERE FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL 
		AND(
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
    	AND ID IN (SELECT VALOR FROM NOTIFICACIONES
            	 WHERE F_1ACUSE IS NULL AND NOTIFICADO='N' AND F_ENVIO_BOP IS NULL
			 AND TIPO_NOTI<>'VOL')
	    AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=
							(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER));
			 
   END IF;

   FOR v_C1 IN C1 LOOP
    	UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFECHAENVIO,
       		N_ORDEN=DECODE(xTODO,'N',N_ORDEN,
       	  		TO_NUMBER(SUBSTR(N_RELACION,1,4)||SUBSTR(N_RELACION,8,3)||to_char(N_ORDEN)))
      WHERE VALOR=v_C1.ID AND TIPO_NOTI<>'VOL';
   END LOOP;

   SELECT COUNT(ID) INTO xCUANTOSRECIBOS FROM VALORES
   WHERE RELACION_APREMIO=xNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCUANTOSRECIBOS
   WHERE RELACION=xNUMERO;

END;
/

/*******************************************************************************************/
-- Envio de notificaciones de expedientes al B.O.P. Sin filtro de Acuse.
-- Crea una nueva relacion de notificaciones, donde apuntarán las notificaciones de una
-- relacion anterior (xTODO='N') o bien todas las notificaciones (xTODO='S')
-- de un TIPO DE EMBARGO, que no estan enviadas al BOP,  Notificado='N' ,
-- con la ultima notificacion anterior a una fecha, y con segundo acuse de recibo
-- A estas notificaciones se les introduce la FECHA_ENVIO_BOP
-- Es el equivalente a NUMERO_APREMIO_BOP para expedientes.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP 
-- 	los expedientes de la ZONA del usuario, antes enviaba todos los expedientes.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE APREMIO_BOP_EXPE(
	xRELACION		IN	CHAR,
      xFENVIO 		IN 	DATE,
      xTODO 		IN 	CHAR,
      xDESDE 		IN	DATE,
      xTipoEmbargo 	IN	CHAR)
AS
	xNUMERO	CHAR(10);
    	xCUANTOS 	INTEGER;
    	xID 		INTEGER;
    	xZONA 	CHAR(2);

	-- CURSOR PARA UNA RELACION DE EXPEDIENTES
	CURSOR UNARELA IS
         SELECT ID FROM NOTIFICACIONES
	   WHERE N_RELACION=xRELACION AND F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND
               ACUSE2 IS NOT NULL and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
      FOR UPDATE OF N_RELACION,F_ENVIO_BOP;

	-- CURSOR PARA TODAS LAS RELACIONES DE EXPEDIENTES
      CURSOR TODASRELA IS
    	   SELECT ID FROM NOTIFICACIONES 
         WHERE F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND ACUSE2 IS NOT NULL
		   and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
		   and TIPO_NOTI<>'VOL'
		   and N_RELACION IN (select relacion from relaciones_noti where zona=
		   							(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER))
      FOR UPDATE OF N_RELACION,F_ENVIO_BOP;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(xNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,TIPO_RELA,USUARIO,ZONA)
   VALUES
	(xNUMERO,xFENVIO,'P','1',USER,xZONA);

   IF xTODO='N' THEN
      FOR v_UNARELA IN UNARELA LOOP
         UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
         WHERE CURRENT OF UNARELA;
      END LOOP;
   ELSE
      FOR v_TODASRELA IN TODASRELA LOOP
         UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
         WHERE CURRENT OF TODASRELA;
      END LOOP;
   END IF;

   SELECT COUNT(ID) INTO xCUANTOS FROM NOTIFICACIONES
   WHERE N_RELACION=xNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCUANTOS
   WHERE RELACION=xNUMERO;

END;
/

/*******************************************************************************************/
-- Envio de notificaciones de expedientes al B.O.P. Filtro de Segundo Acuse.
-- Es similar al procedimiento APREMIO_BOP_EXPE, con la única diferencia de que este
-- procedimiento filtra el tipo del segundo acuse.
-- Pone Fecha de envio a las notificaciones, apuntando a una nueva relacion de notificaciones
-- Es el equivalente a ESPECIAL_SEGUNDA_BOP para expedientes.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP 
-- 	los expedientes de la ZONA del usuario, antes enviaba todos los expedientes.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ESPECIAL_SEGUNDA_EXPE(
	xRELACION		IN 	CHAR,
      xFENVIO 		IN 	DATE,
      xTODO 		IN 	CHAR,
      xDesde 		IN	DATE,
      xTipoEmbargo 	IN	CHAR
)
AS

	xNUMERO	CHAR(10);
    	xCUANTOS 	INTEGER;
    	xID 		INTEGER;
    	xZONA 	CHAR(2);

	CURSOR UNARELA IS
	   SELECT ID FROM NOTIFICACIONES
	   WHERE N_RELACION=xRELACION AND F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND
               ACUSE2 IN (SELECT CODIGO FROM TMP_BOP
                          WHERE USUARIO=USER)
	         and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
         FOR UPDATE OF N_RELACION,F_ENVIO_BOP;


	CURSOR TODASRELA IS
    	   SELECT ID FROM NOTIFICACIONES
         WHERE F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND ACUSE2 IN (SELECT CODIGO FROM TMP_BOP
								                     WHERE USUARIO=USER)
		   and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
		   AND TIPO_NOTI<>'VOL'
		   and N_RELACION IN (select relacion from relaciones_noti where zona=
		   							(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER))
         FOR UPDATE OF N_RELACION,F_ENVIO_BOP;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(xNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,TIPO_RELA,USUARIO,ZONA)
   VALUES
	(xNUMERO,xFENVIO,'P','1',USER,xZONA);

   IF xTODO='N' THEN
   	FOR v_UNARELA IN UNARELA LOOP
         UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
         WHERE CURRENT OF UNARELA;
   	END LOOP;
   ELSE
    	FOR v_TODASRELA IN TODASRELA LOOP
         UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
         WHERE CURRENT OF TODASRELA;
     	END LOOP;
   END IF;

   SELECT COUNT(ID) INTO xCUANTOS FROM NOTIFICACIONES
   WHERE N_RELACION=xNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCUANTOS
   WHERE RELACION=xNUMERO;

END;
/


/******************************************************************************************/
-- Envio de notificaciones de expedientes al B.O.P. Filtro de Primer Acuse.
-- Es muy similar a APREMIO_BOP_EXPE, Y ESPECIAL_SEGUNDA_EXPE con la unica diferencia
-- de que realiza filtro sobre el tipo del PRIMER ACUSE de recibo
-- Los tipos posibles de acuse los mete DELPHI en la tabla TMP_BOP.
-- Es el equivalente a ESPECIAL_BOP para expedientes.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP 
-- 	los expedientes de la ZONA del usuario, antes enviaba todos los expedientes.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ESPECIAL_BOP_EXPE(
	xRELACION		IN	CHAR,
      xFENVIO 		IN 	DATE,
      xTODO 		IN 	CHAR,
	xDesde 		IN	DATE,
	xTipoEmbargo 	IN	CHAR)
AS
xNUMERO	CHAR(10);
xCUANTOS 	INTEGER;
xID 		INTEGER;
xZONA	 	CHAR(2);

      CURSOR UNARELA IS
    	   SELECT ID FROM NOTIFICACIONES
	   WHERE N_RELACION=xRELACION AND F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND
               ACUSE1 IN (SELECT CODIGO FROM TMP_BOP
                          WHERE USUARIO=USER)
		   and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
	FOR UPDATE OF N_RELACION,F_ENVIO_BOP;


	CURSOR TODASRELA IS
    	   SELECT ID FROM NOTIFICACIONES
         WHERE F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND
         	   ACUSE1 IN (SELECT CODIGO FROM TMP_BOP
                          WHERE USUARIO=USER)
		   and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
		   AND TIPO_NOTI<>'VOL'
		   and N_RELACION IN (select relacion from relaciones_noti where zona=
		   							(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER))
      FOR UPDATE OF N_RELACION,F_ENVIO_BOP;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(xNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,TIPO_RELA,USUARIO,ZONA)
   VALUES
	(xNUMERO,xFENVIO,'P','1',USER,xZONA);

   IF xTODO='N' THEN
    	FOR v_UNARELA IN UNARELA LOOP
         UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
         WHERE CURRENT OF UNARELA;
      END LOOP;
   ELSE
   	FOR v_TODASRELA IN TODASRELA LOOP
         UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
         WHERE CURRENT OF TODASRELA;
   	END LOOP;
   END IF;

   SELECT COUNT(ID) INTO xCUANTOS FROM NOTIFICACIONES
   WHERE N_RELACION=xNUMERO;

   UPDATE RELACIONES_NOTI SET RECIBOS=xCUANTOS
   WHERE RELACION=xNUMERO;

END;
/

/******************************************************************************************/
-- Envio de notificaciones de expedientes al B.O.P. Sin Primer Acuse.
-- Pone fecha de envio al BOP a las notificaciones sin fecha de Primer Acuse anteriores a una
-- fecha de un tipo de embargo sin dar de baja ni estar suspendidas ni enviadas ya al bop
-- y con Notificado='N' de una relacion o de todas las relaciones.
-- Las notificaciones apuntan a una nueva relacion de notificaciones que se crea.
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: 07/05/2003. Lucas Fernández Pérez. Cuando xTodo='S', envía al BOP 
-- 	los expedientes de la ZONA del usuario, antes enviaba todos los expedientes.
/******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE SINACUSE_BOP_EXPE(
	xRELACION		IN	CHAR,
      xFENVIO 		IN 	DATE,
      xTODO 		IN 	CHAR,
	xDesde 		IN	DATE,
	xTipoEmbargo 	IN	CHAR)
AS

    	xNUMERO 	CHAR(10);
    	xCUANTOS 	INTEGER;
    	xID 		INTEGER;
    	xZONA 	CHAR(2);

	CURSOR UNARELA IS
    	   SELECT ID FROM NOTIFICACIONES
	   WHERE N_RELACION=xRELACION AND F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND
		   F_1ACUSE IS NULL and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
	FOR UPDATE OF N_RELACION,F_ENVIO_BOP;

	CURSOR TODASRELA IS
         SELECT ID FROM NOTIFICACIONES
         WHERE F_ENVIO_BOP IS NULL AND NOTIFICADO='N' AND F_1ACUSE IS NULL
		   and F_INTENTO<=xDesde and substr(tipo_noti,1,1)=xTipoEmbargo
		   AND TIPO_NOTI<>'VOL'
		   and N_RELACION IN (select relacion from relaciones_noti where zona=
		   							(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER))
      FOR UPDATE OF N_RELACION,F_ENVIO_BOP;

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS
   WHERE USUARIO=USER;

   DAME_RELACION(xNUMERO);

   INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,TIPO_RELA,USUARIO,ZONA)
   VALUES
	(xNUMERO,xFENVIO,'P','1',USER,xZONA);

   IF xTODO='N' THEN
      FOR v_UNARELA IN UNARELA LOOP
		UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
		WHERE CURRENT OF UNARELA;
      END LOOP;
   ELSE
    	FOR v_TODASRELA IN TODASRELA LOOP
		UPDATE NOTIFICACIONES SET N_RELACION=xNUMERO,F_ENVIO_BOP=xFENVIO
		WHERE CURRENT OF TODASRELA;
   	END LOOP;
   END IF;

   SELECT COUNT(ID) INTO xCUANTOS FROM NOTIFICACIONES WHERE N_RELACION=xNUMERO;
   UPDATE RELACIONES_NOTI SET RECIBOS=xCUANTOS WHERE RELACION=xNUMERO;
END;
/
--
-- Fin de procedimientos de pase al B.O.P.
--
-- Acuse de Recibo. Procedimientos llamados por WRITEACUSE
--

-- -------------------------------------------------------------------------------------
-- Inserta las costas de la notificación a un valor.
-- Modificado: 08/01/2004. Lucas Fernández Pérez.
--	Nuevo parámetro de salida xIDCostas con el id de la tabla costas_valores.
-- Modificado: 09/01/2004. Lucas Fernández Pérez. Antes insertar una costa negativa, 
-- 	revisa si el recibo queda con costas negativas, en cuyo caso no deja insertar la costa.
/*INTERNO*/
create or replace procedure ActualizaCostasAUnValor(
		xValor        	IN INTEGER,   -- ID del valor
		xNRecibos 		IN float,	  -- Numero de recibos de un mismo acuse
		xSiAnulo		IN char,      -- Indica si tengo que añadir una costa negativa,
									  --   solo se utiliza cuando se anule una notificacion
		xIDCostas		OUT INTEGER)  -- ID de la nueva costa creada
AS
xIMPORTE 	float;
xDescrip	CHAR(50);
xCuantos 	integer;
xCostasValor float;
xCostasIngre float;
BEGIN

	-- averiguar el importe actual de la costa de correos
	SELECT importe INTO xImporte FROM precio_correo WHERE TIPO='L';

	xIMPORTE:=ROUND(xIMPORTE/xNRECIBOS,2);

	if xSiAnulo='S' then
	
		-- Costas del valor
  		SELECT COSTAS INTO xCostasValor FROM VALORES WHERE ID=xvalor;

  		-- Costas ingresadas del valor
  		SELECT COUNT(*), SUM(COSTAS) INTO xCuantos,xCostasIngre FROM INGRESOS 
  		WHERE VALOR=xvalor;
		if xCuantos=0 then
  	  		xCostasIngre:=0;
		end if;

		-- Si las costas negativas que voy a insertar superan las costas pendientes, 
		--  no inserto las costas, porque el valor quedaría con importe de costas negativas.
 		if xImporte > (xCostasValor-xCostasIngre)  then
	   	  raise_application_error(-20004,'No se puede anular la costa, el recibo quedaría con costas negativas');
 		end if;

		xIMPORTE:=xIMPORTE*(-1);
		xDescrip:='ANULAR GASTOS DE CORREO MOD. ACUSE DE RECIBO';
	else
		xDescrip:='GASTOS AUTOMATICOS DE CORREO';
	end if;

	--put_costas_recibo graba en la tabla de valores la costa de correo
	PUT_COSTAS_RECIBO(xValor,xDescrip,xIMPORTE,sysdate, NULL,xIDCostas);

	-- Put_costas_recibo introduce en xIDCostas el ID de la nueva costa creada

END;
/

--
-- ACUSE DE RECIBO de un VALOR
--
-- Modificado: Agustín León Robles. 26/03/2003
--		Puede darse un caso en el que el recibo no tenga principal, entonces el recargo será 
--		sobre la cuota_inicial (ingresados fuera de plazo)
-- Modificado: 08/01/2004. Lucas Fernández Pérez.
--	Nuevo parámetro de salida xIDCostas con el id de la tabla costas_valores si se han
--		grabado costas o con valor NULL si no se han grabado costas.
--
/*INTERNO*/
create or replace procedure TR_VALO_BU
		(xValor        	IN INTEGER,  -- ID del valor
		xNRecibos 		IN float,	 -- Numero de recibos de un mismo acuse
		xSiempreCosta 	IN CHAR,     -- Indica si hay que introducir costas
		xNOTI         	IN CHAR,  	 -- Indica si es notificacion 'N' o 'S'
		xIDCostas		OUT INTEGER)
AS
xZona 		char(2);
xAyto			char(3);
xCostaAdelantado	char(1);
xConfig		integer;
mPrincipal		float;
xNIF			char(10);
begin

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	--Configuracion del recargo.
	--Configuracion de si hay costas por adelantado o no.
	--En el caso de que las haya, no hay que hacer nada con las costas
	SELECT RECARGO,COSTA_ADELANTADO INTO xCONFIG,xCostaAdelantado
			FROM CONFIGURACION WHERE ZONA=xZONA;


	xIDCostas:=NULL;
	--para grabar costas se tienen que dar 2 casos:
	-- 1) que no hay costa por adelantado
	-- 2) que en funcion de la configuracion haya que grabar costa
	if xCostaAdelantado='N' and xSiempreCosta='S' then
		ActualizaCostasAUnValor(xValor,xNRecibos,'N',xIDCostas);
	end if;


	--me devuelve el principal de la deuda en ejecutiva, ya que si ha habido
	--entregas a cuenta en voluntaria y luego pasamos a ejecutiva el recibo,
	--el recargo se tiene que calcular sobre el principal del valor menos la suma
	--de las entregas a cuenta en voluntaria
	--Puede darse un caso en el que el recibo no tenga principal, entonces el recargo será 
	--sobre la cuota_inicial (ingresados fuera de plazo)
	mPrincipal:=DameIngresosVoluntaria(xValor);

	if xNoti='S' then

		-- Si pago el total del principal antes del cargo, cuando se notifique
		-- no se pondrá el 20% de recargo seguirá con el 10%
	      update valores set RECARGO=DECODE(mPrincipal,0,ROUND((CUOTA_INICIAL*20/100),2),ROUND((mPrincipal*20/100),2))
	      	where id=xValor
	      	and ENTREGAS_ANTESDEL_CARGO <= Principal
		return NIF,AYTO into xNIF,xAYTO;

	      APREMIADOS_A_EXPEDIENTE(xNIF, xAYTO, xZONA);
	else

		--xCONFIG=0: 20% de recargo al momento de emitir la providencia
		--xCONFIG=1: 20% de recargo cuando llegue el acuse de recibo

		if mPrincipal=0 then
			UPDATE VALORES SET
				RECARGO=DECODE(xCONFIG,0,RECARGO,ROUND((CUOTA_INICIAL*10/100),2)),
				DEMORA_PENDIENTE=0 -- Se le eliminan los intereses que pudiera tener
			WHERE ID = xValor
			and ENTREGAS_ANTESDEL_CARGO <= Principal;
		ELSE
			UPDATE VALORES SET
				RECARGO=DECODE(xCONFIG,0,RECARGO,ROUND((mPrincipal*10/100),2)),
				DEMORA_PENDIENTE=0 -- Se le eliminan los intereses que pudiera tener
			WHERE ID = xValor
			and ENTREGAS_ANTESDEL_CARGO <= Principal;

		end if;

	end if;

end;
/


-- Para el ACUSE de Recibo de un EXPEDIENTE
/*******************************************************************************************/
-- Actualiza la tabla de EMBARGOS_INMUEBLES (xTipo = 401-402-407-408)
-- o EMBARGOS_AUTOS (801-802-807-808) poniendo los campos NOTI_EMBARGO o NOTI_SUBASTA del
-- embargo xIDEmbargo a 'S' si todas las notificaciones del expediente xIDExpe
-- para el embargo xIDEmbargo estan notificadas (Notificado='S').

-- Modificado 29-04-2002. Lucas Fernández Pérez. Actualiza tambien EMBARGOS_SALARIOS
--	(xTipo='302') poniendo el campo NOTIFICADO a 'S' si todas las notificaciones a la empresa
-- 	 estan notificadas (Notificado='S')
/*******************************************************************************************/
/*INTERNO*/
CREATE OR REPLACE PROCEDURE TERCEROS_NOTI(
        xTipo      IN char,
        xIDExpe    IN INTEGER,
        xIDEmbargo IN INTEGER)

AS
   xCuantos integer;
   xNoti char(1);
BEGIN

   -- En las notificaciones a la empresa en embargo de salarios
   --  comprobar si ya se ha notificado a todos, para comunicarselo a la tabla
   --  de embargos de salarios
   IF xTipo='302' THEN

	--puede ocurrir que las notificaciones sean de un embargo y luego se pasen a otro embargo
	begin
		select NOTIFICADO INTO xNoti from EMBARGOS_SALARIOS where ID=xIDEmbargo;
	exception
		when no_data_found then
			xNoti:='X'; -- Indico que no existe el embargo de inmuebles
	end;

	-- Miro cuantos faltan por notificar del embargo
	SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES
		WHERE EXPEDIENTE=xIDEXPE
		AND ID_EMBARGOS=xIDEmbargo
		AND NOTIFICADO='N'
		AND TIPO_NOTI='302';

      -- si el embargo no esta marcado como notificado y todas las notificaciones estan a 'S'
      if (xNoti='N') and (xCuantos=0) then

		-- no faltan documentos por notificar, lo indico en el embargo.
		UPDATE EMBARGOS_SALARIOS set NOTIFICADO='S' where ID=xIDEmbargo;

		-- AVISAR DEL HECHO
		-- El triger que se lanza (T_NotiTercerosExpe) necesita saber el IDEMBARGO.
	   	-- Se indica ese IDEMBARGO mediante la tabla de Usuarios
		UPDATE USUARIOS SET LAST_NUMERO=xIDEMBARGO WHERE USUARIO=USER;
		UPDATE expedientes set aviso='010',f_aviso=SYSDATE where ID=xIDExpe;

	-- Si el embargo esta marcado como notificado pero tiene algo por notificar
      elsif (xNoti='S') and (xCuantos>0) then

		-- falta alguno por notificar
		UPDATE EMBARGOS_SALARIOS set NOTIFICADO='N' where ID=xIDEmbargo;

		-- AVISAR DEL HECHO
		UPDATE expedientes set aviso='011',f_aviso=SYSDATE where ID=xIDExpe;

      end if;-- del if xNoti
   END IF;

   -- En el caso de que haya que notificar a los terceros del expediente
   --  comprobar si ya se ha notificado a todos, para comunicarselo a la tabla
   --  de embargos de inmuebles
   IF (xTipo='401' OR xTipo='402') THEN

	--puede ocurrir que las notificaciones sean de un embargo y luego se pasen a otro embargo
	begin
		select NOTI_EMBARGO INTO xNoti from EMBARGOS_INMUEBLES where ID=xIDEmbargo;
	exception
		when no_data_found then
			xNoti:='X'; -- Indico que no existe el embargo de inmuebles
	end;

	-- Miro cuantos faltan por notificar del embargo
	SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES
		WHERE EXPEDIENTE=xIDEXPE
		AND ID_EMBARGOS=xIDEmbargo
		AND NOTIFICADO='N'
		AND (TIPO_NOTI='401' or TIPO_NOTI='402');

      -- si el embargo no esta marcado como notificado y todas las notificaciones estan a 'S'
      if (xNoti='N') and (xCuantos=0) then

		-- no faltan documentos por notificar, lo indico en el embargo.
		UPDATE EMBARGOS_INMUEBLES set NOTI_EMBARGO='S' where ID=xIDEmbargo;

		-- AVISAR DEL HECHO
		-- El triger que se lanza (T_NotiTercerosExpe) necesita saber el IDEMBARGO.
	   	-- Se indica ese IDEMBARGO mediante la tabla de Usuarios
		UPDATE USUARIOS SET LAST_NUMERO=xIDEMBARGO WHERE USUARIO=USER;
		UPDATE expedientes set aviso='010',f_aviso=SYSDATE where ID=xIDExpe;

	-- Si el embargo esta marcado como notificado pero tiene algo por notificar
      elsif (xNoti='S') and (xCuantos>0) then

		-- falta alguno por notificar
		UPDATE EMBARGOS_INMUEBLES set NOTI_EMBARGO='N' where ID=xIDEmbargo;

		-- AVISAR DEL HECHO
		UPDATE expedientes set aviso='011',f_aviso=SYSDATE where ID=xIDExpe;

      end if;-- del if xNoti
   END IF;


   -- notificacion de la FECHA DE LA SUBASTA de embargos de inmuebles
   IF (xTipo='407' OR xTipo='408') then

	--puede ocurrir que las notificaciones sean de un embargo y luego se pasen a otro embargo
	begin
	      select NOTI_SUBASTA INTO xNOTI from EMBARGOS_INMUEBLES where ID=xIDEmbargo;
	exception
		when no_data_found then
			xNoti:='X'; -- Indico que no existe el embargo de inmuebles
	end;

      SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES
      WHERE EXPEDIENTE=xIDEXPE
           AND ID_EMBARGOS=xIDEmbargo
           AND NOTIFICADO='N'
           AND (TIPO_NOTI='407' or TIPO_NOTI='408');

	-- Si el embargo no indica que estan todos notificados y realmente estan todos notificados
      IF (xNOTI='N') AND (xCuantos=0) THEN

         -- indico en el expediente que estan todos notificados
         update EMBARGOS_INMUEBLES set NOTI_SUBASTA='S' where ID=xIDEmbargo;
         update expedientes set aviso='012',f_aviso=SYSDATE where ID=xIDExpe; --AVISAR EL HECHO

	-- Si el embargo indica que estan todos notificados y realmente no estan todos notificados
      ELSIF (xNOTI='S') AND (xCuantos>0) THEN
         -- indico en el expediente que no todos estan notificados
         update EMBARGOS_INMUEBLES set NOTI_SUBASTA='N' where ID=xIDEmbargo;

         update expedientes set aviso='011',f_aviso=SYSDATE where ID=xIDExpe;--AVISAR EL HECHO
      END IF; -- del if xNoti

   END IF;

   -- En el caso de que haya que notificar a los terceros del expediente
   --   comprobar si ya se ha notificado a todos, para comunicarselo a la tabla
   --   de embargos de AUTOS
   IF (xTipo='801' OR xTipo='802') THEN

	--puede ocurrir que las notificaciones sean de un embargo y luego se pasen a otro embargo
	begin
		select NOTI_EMBARGO INTO xNoti from EMBARGOS_AUTOS where ID=xIDEmbargo;
	exception
		when no_data_found then
			xNoti:='X'; -- Indico que no existe el embargo de inmuebles
	end;

	--Averiguar cuantas notificaciones hay
	SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES
		WHERE EXPEDIENTE=xIDEXPE
		AND ID_EMBARGOS=xIDEmbargo
		AND NOTIFICADO='N'
		AND (TIPO_NOTI='801' or TIPO_NOTI='802');

	-- Si el embargo indica que no estan todos notificados y realmente estan todos notificados
      if (xNoti='N') and (xCuantos=0) then

         -- indico en el expediente que estan todos notificados
  	   UPDATE EMBARGOS_AUTOS set NOTI_EMBARGO='S' where ID=xIDEmbargo;

	   -- AVISAR DEL HECHO
	   -- El triger que se lanza (T_NotiTercerosExpe) necesita saber el IDEMBARGO.
	   -- Se indica ese IDEMBARGO mediante la tabla de Usuarios
	   UPDATE USUARIOS SET LAST_NUMERO=xIDEMBARGO WHERE USUARIO=USER;
	   UPDATE expedientes set aviso='010',f_aviso=SYSDATE where ID=xIDExpe;

	-- Si el embargo indica que estan todos notificados y realmente no estan todos notificados
      elsif (xNoti='S') and (xCuantos>0) then

         -- indico en el expediente que no todos estan notificados
	   UPDATE EMBARGOS_AUTOS set NOTI_EMBARGO='N' where ID=xIDEmbargo;

	   UPDATE expedientes set aviso='011',f_aviso=SYSDATE where ID=xIDExpe;--AVISAR DEL HECHO

      END IF;-- del if xNoti

   END IF;

   -- notificacion de la FECHA DE LA SUBASTA de embargos de vehiculos
   IF (xTipo='807' OR xTipo='808') then

	--puede ocurrir que las notificaciones sean de un embargo y luego se pasen a otro embargo
	begin
	      select NOTI_SUBASTA INTO xNOTI from EMBARGOS_AUTOS where ID=xIDEmbargo;
	exception
		when no_data_found then
			xNoti:='X'; -- Indico que no existe el embargo de inmuebles
	end;

         -- comprobar cuantas hay no notificadas
      SELECT COUNT(*) INTO xCuantos FROM NOTIFICACIONES
      WHERE EXPEDIENTE=xIDEXPE
            AND ID_EMBARGOS=xIDEmbargo
            AND NOTIFICADO='N'
            AND (TIPO_NOTI='807' or TIPO_NOTI='808');

	-- Si el embargo no indica que estan todos notificados y realmente estan todos notificados
      IF (xNOTI='N') and (xCuantos=0) THEN

         -- indico en el expediente que todos estan notificados
         update EMBARGOS_AUTOS set NOTI_SUBASTA='S' where ID=xIDEmbargo;
         update expedientes set aviso='012',f_aviso=SYSDATE where ID=xIDExpe;--AVISAR DEL HECHO

	-- Si el embargo indica que estan todos notificados y realmente no estan todos notificados
      ELSIF (xNOTI='S') and (xCuantos>0) THEN

         -- indico en el expediente que no todos estan notificados
         update EMBARGOS_AUTOS set NOTI_SUBASTA='N' where ID=xIDEmbargo;
         update expedientes set aviso='011',f_aviso=SYSDATE where ID=xIDExpe;--AVISAR DEL HECHO

      END IF; -- del if xNoti

   END IF;

End;
/

-- Para el ACUSE de Recibo de un EXPEDIENTE
--
-- Modificado: 09/01/2004. Lucas Fernández Pérez. Antes de borrar una costa, revisa si 
-- 	algun recibo tiene parte de esa costa ingresada, en cuyo caso no deja borrarla.
--
CREATE OR REPLACE PROCEDURE Pon_Costa(
	xTipoNoti 		IN char,    -- Tipo de Acuse
	xIdNoti  		IN integer, -- ID de la Notificacion
	xIdExpe   		IN integer, -- ID del Expediente
	xNIF      		IN char,
	xIDTercero 		IN integer,
	xSiempreCosta 	IN CHAR,  	-- Indica si hay que introducir costas en la notificacion
	xSiAnulo		IN char,    -- Indica si tengo que añadir una costa negativa,
						-- solo se utiliza cuando se anule una notificacion
	xIdCostas 		IN integer, -- Indica si hay costas en la notificacion
	xIDCostasNEW 	OUT INTEGER)-- Nuevo ID de la costa si se genero la misma
AS
   xTexto char(500);
   xAviso char(50);
   xCuanto float default 0;
   xNIFExpe char(10);
   xEs_Empresa boolean;
   CONTADOR INTEGER;
   xContinuar boolean;
   xCostaAdelantado char(1);
   xCuantos	integer;
   xCostasValor	float;
   xCostasIngre float;
   CURSOR cBorraCosta IS select valor,importe
		             from costas_valores
			       where codigo_operacion=xIdCostas;

   CURSOR cTrabajos IS select cif_empresa from salarios where idexpe=xIDExpe;

BEGIN

	--estoy anulando el acuse
	if xSiAnulo='S' then

		-- Recorro en costas_valores la costa que se sumo a cada valor y se lo descuento
		FOR vBORRACOSTA IN cBorraCosta LOOP
		
	       -- Costas del valor
  	       SELECT COSTAS INTO xCostasValor FROM VALORES WHERE ID=vBorraCosta.valor;

  	       -- Costas ingresadas del valor
  	       SELECT COUNT(*), SUM(COSTAS) INTO xCuantos,xCostasIngre FROM INGRESOS 
  		       WHERE VALOR=vBorraCosta.valor;
	       if xCuantos=0 then
  	         xCostasIngre:=0;
	       end if;
	       
		   -- Si las costas que voy a borrar superan las costas pendientes, no dejo
		   --  borrarlas, porque en los ingresos del valor hay importe de costas 
		   --  correspondientes a estas que intento borrar.
 		   if vBorraCosta.Importe > (xCostasValor-xCostasIngre)  then
	          raise_application_error(-20004,'No se puede borrar la costa del valor ID '
	          		||vBorraCosta.valor||', está parcialmente ingresada');
 	       end if;
		
		   update valores set costas=costas-vBORRACOSTA.Importe where id=vBORRACOSTA.Valor;
			
		END LOOP;

		-- Se borran las costas a valores de esa notificacion
		delete from costas_valores where codigo_operacion=xIdCostas;

		delete from seguimiento where id_costas=xIdCostas;

		return;
	end if;

	--Configuracion de si hay costas por adelantado o no.
	--En el caso de que las haya, no hay que hacer nada con las costas
	SELECT COSTA_ADELANTADO INTO xCostaAdelantado
		FROM CONFIGURACION WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

-------------------------------------------------------------------------------------------
--  25/7/2002: de momento no se va activar la opcion de costa por adelantado, siempre se va
--  		a grabar la costa cuando llegue el acuse
--
--
	--para grabar costas se tienen que dar 2 casos:
	-- 1) que no hay costa por adelantado
	-- 2) que en funcion de la configuracion haya que grabar costa
--	if xCostaAdelantado='S' or xSiempreCosta='N' then
--		return;
--	end if;

--el if que hay aqui debajo habria que quitarlo por el de aqui encima, cuando se quiera activar
--la opcion de costa por adelantado.


	if xCostaAdelantado='N' then
		if xSiempreCosta='N' then
			return;
		end if;
	end if;

	select importe into xCuanto from precio_correo where tipo='L';

	select CORTO into xAviso from tipo_notificacion where tipo=xTipoNoti;

	SELECT count(*) into CONTADOR
	FROM TIPO_TERCERO
	WHERE RELACION IN (SELECT RELACION FROM TERCEROS WHERE ID=xIDTercero);

	-- Notificación del tercero del expediente.
	IF CONTADOR > 0 THEN

		--Esto es para aumentar informacion en el aviso
		SELECT DESCRIPCION INTO xTexto
		FROM TIPO_TERCERO
		WHERE RELACION IN (SELECT RELACION FROM TERCEROS WHERE ID=xIDTercero);

		xAviso := substr(xAviso, 1, 30) ||' '|| substr(RTrim(xTexto), 1, 19);

		--si no lo encuentra puede ser la notificacion del deudor del expediente
		--o la empresa
	ELSE

		--Compruebo si es la empresa
		xEs_Empresa:=false;
		xContinuar:=true;
		FOR v_Trabajo IN CTRABAJOS LOOP

			-- no es la empresa
			if ((v_Trabajo.cif_empresa<>xNIF) and (xContinuar=True) ) then
				xEs_Empresa:=false;
			else
				xEs_Empresa:=true;
				xContinuar:=false;
			end if;

		END LOOP;

		-- Si no es la empresa, miro si es el deudor
		IF xEs_Empresa=false THEN
			begin
				select deudor into xNIFExpe from expedientes where Id=xIDExpe;
				if xNIFExpe<>xNIF then -- no añado la costa
					return;
				end if;

			exception
				WHEN NO_DATA_FOUND THEN -- no añado la costa
				return;
			end;
		END IF;

	END IF;

	-- Añade la costa al expediente
	ADD_COSTA_EXPE(xIdExpe,xCuanto,xAviso,xIDCostasNEW);

END;
/


/*******************************************************************************************/
-- ACUSE DE RECIBOS. PARA NOTIFICACIONES DE VALORES Y EXPEDIENTES.
/*******************************************************************************************/
-- Parametros:
--		xID: Id de Notificaciones
--		xRefID: ID de Valores o ID de Expedientes
--		xFRecibi: Fecha del Recibi
--		xAcuse: Código de Acuse de Recibo
--		xTercero: Datos para el tipo de acuse TERCERO
--		xTipo: 1-El interesado, 2-Un tercero, 3-Rehusado, 4-Desconocido, 5-Ausente
--		ValorExpe: 'V'-Valores o 'E':Expedientes
--		xReferencia: Referencia donde esta el acuse

-- modificacion: 19 de Noviembre 2001 Agustin Leon Robles
--		     Un valor tiene que estar pendiente de cobro para que se le pueda
--		     grabar el 20% de recargo y sus costas. Sino solo se grabará la fecha
--		     de notificacion.
-- modificacion: 21 de Noviembre de 2001 Lucas Fernandez.
--		     A un expediente cerrado no se le pueden cobrar costas.
-- modificacion: 16/07/2002 Lucas Fernández Pérez. Las costas por adelantado no pueden borrarse.
-- modificacion: 06/11/2002 Lucas Fernández Pérez. Falla al grabar acuses de segundas notificac.
-- 			Si estamos en 2ª notificacion, fLastAcuse puede apuntar al acuse de
--			1ª notificación, y entra en el if, cuando realmente no tiene acuse la notific.
-- 			Se cambia la condición para evitar que entre si no tiene acuse la 2ª Notif.
--			Ya no se mira F_LASTACUSE, sino F_1Acuse y F_2Acuse
-- Modificado: 28/04/2003 Lucas Fernández Pérez.
-- 	Ahora permite grabar el acuse si el valor/expediente está enviado al BOP
-- Modificado: 08/01/2004. Lucas Fernández Pérez.
--  Al grabar un acuse de un recibo pendiente o expediente abierto, 
--   rellena el campo ID_COSTAS en la tabla de NOTIFICACIONES si estaba vacío 
--   (es decir, si no hay costas por adelantado en los valores)
--DELPHI
--
CREATE OR REPLACE PROCEDURE APLICARWRITEACUSE(
         xID          IN INTEGER,
         xRefID       IN INTEGER,
         xFRecibi     IN DATE,
         xAcuse       IN CHAR,
         xTercero     IN VARCHAR,
         xTipo        IN CHAR,
         ValorExpe    IN CHAR,
	   xReferencia  IN VARCHAR)

AS

    xNoti 			char(1);
    xSiempreCosta 	char(1);
    xEnvios 		INTEGER;
    xIDEmbargo 		INTEGER;
    xTipoNoti 		char(3);
    xNIF 			char(10);
    xF_Publi		date;
    xIDTercero 		integer;
    xFBaja			date;
    xFIngreso		date;
    xEstado			char(1);
    xNRecibos 		float;
    xIDCostasNEW		integer;
    xF_1Acuse		date;
    xF_2Acuse		date;

BEGIN

	-- ver qué envio es este, si es el primero o el segundo
	SELECT N_ENVIOS,TIPO_NOTI,ID_EMBARGOS,NIF,ID_TERCERO,NUMERO_OBJETOS,
			F_PUBLICACION,F_1ACUSE,F_2ACUSE

	INTO xEnvios,xTipoNoti,xIDEmbargo,xNIF,xIDTercero,xNRecibos,
				xF_Publi,xF_1Acuse,xF_2Acuse

	FROM NOTIFICACIONES WHERE ID=xID;

	-- Si está publicado, no acepta modificar la Notificacion
	IF xF_Publi IS NOT NULL THEN
		RETURN;
	END IF;

	-- Si se va a modificar solo la fecha se actualiza en valores y en notificaciones
	if ((xEnvios=1 AND xF_1Acuse is not null) or
	    (xEnvios>1 AND xF_2Acuse is not null)) then

		IF ValorExpe='V' then
			UPDATE VALORES SET F_NOTIFICACION=xFRECIBI WHERE ID=xRefID;
		end if;

		UPDATE notificaciones Set
			F_1ACUSE=DECODE(xEnvios,1,xFRecibi,F_1ACUSE),
			TERCERO_1NOTIFI=DECODE(xEnvios,1,xTercero,TERCERO_1NOTIFI),

			F_2ACUSE=DECODE(xEnvios,1,F_2ACUSE,xFRecibi),
			TERCERO_2NOTIFI=DECODE(xEnvios,1,TERCERO_2NOTIFI,xTercero),

			F_NOTIFICACION=xFRecibi, F_LAST_ACUSE=xFRecibi,
			Referencia=xReferencia

	      WHERE id=xID;

		RETURN;
	end if;

	--xNoti: si el acuse de recibo elegido es del tipo notificado o no
	--xSiempreCosta: si se inserta siempre una costa o no, independientemente de si es
	--               notificado o no
	Select notificado,costa into xNoti,xSiempreCosta from tipo_acuses where tipo=xTipo;

	xIDCostasNEW:=NULL;
	--Acuses de recibo de una notificacion de un valor
	IF ValorExpe='V' then

		UPDATE VALORES SET NOTIFICADO=xNOTI,F_NOTIFICACION=xFRECIBI
		WHERE ID=xRefID
		RETURN F_INGRESO,FECHA_DE_BAJA INTO xFIngreso,xFBaja;

		--tiene que estar el valor pendiente de cobro
		--para que introduzca el 20% de recargo y sus costas
		if xFIngreso is null and xFBaja is null then
			Tr_valo_bu(xRefID,xNRecibos,xSiempreCosta,xNoti,xIDCostasNEW);
		end if;

	END IF;

	-- Primer intento
	IF xEnvios=1 THEN
		UPDATE notificaciones Set
			F_1ACUSE=xFRecibi,ACUSE1=xAcuse,TERCERO_1NOTIFI=xTercero,
			NOTIFICADO=xNoti,F_NOTIFICACION=xFRecibi,
			F_LAST_ACUSE=xFRecibi,LAST_ACUSE=xAcuse, 
			ID_COSTAS=DECODE(ID_COSTAS,NULL,xIDCostasNEW, ID_COSTAS),
			Referencia=xReferencia
      	WHERE id=xID;

	ELSE  --segundo intento

		UPDATE notificaciones Set
			F_2ACUSE=xFRecibi, ACUSE2=xAcuse,TERCERO_2NOTIFI=xTercero,
			NOTIFICADO=xNoti,F_NOTIFICACION=xFRecibi,
			F_LAST_ACUSE=xFRecibi,LAST_ACUSE=xAcuse, 
			ID_COSTAS=DECODE(ID_COSTAS,NULL,xIDCostasNEW, ID_COSTAS),
			Referencia=xReferencia
	      WHERE id=xID;
	END IF;


	--acuses de recibo de una notificacion de un expediente
	IF ValorExpe='E' Then

		-- Actualiza los campos NOTI_EMBARGO y NOTI_SUBASTA de posibles embargos
		-- de inmuebles o vehículos que tenga el expediente.
		TERCEROS_NOTI(xTipoNoti,xRefID,xIDEmbargo);

		SELECT IS_LIVE INTO xEstado FROM EXPEDIENTES WHERE ID=xRefID;

		-- Si el expediente está cerrado, no introducimos más costas.
		if xEstado='S' then

			PON_COSTA(xTipoNoti,xID,xRefID,xNIF,xIDTercero,xSiempreCosta,
					'N',0,xIDCostasNEW);

			UPDATE notificaciones Set ID_COSTAS=xIDCostasNEW WHERE id=xID;

		end if;

		-- Actualizo los valores vivos del expediente para que su f_last_anoti
		-- apunte a la ultima notificación positiva del expediente
		NotiSetLastValid(xRefID);

	END IF; -- ValorExpe


END;
/

/*******************************************************************************************/
-- 20/3/2002 Lucas Fernández Pérez.
-- El anterior writeacuse se baja un nivel y se renombra a APLICARWRITEACUSE.
-- El nuevo writeacuse llama a APLICARWRITEACUSE, con una nueva opción: si el acuse
-- es sobre un recibo que está en un impreso junto con otros, hace una llamada
-- a APLICARWRITEACUSE por cada recibo, para grabar el acuse a todos los recibos del impreso.
--
-- Parametros:
--		xID: Id de Notificaciones
--		xRefID: ID de Valores o ID de Expedientes
--		xFRecibi: Fecha del Recibi
--		xAcuse: Código de Acuse de Recibo
--		xTercero: Datos para el tipo de acuse TERCERO
--		xTipo: 1-El interesado, 2-Un tercero, 3-Rehusado, 4-Desconocido, 5-Ausente
--		ValorExpe: 'V'-Valores o 'E':Expedientes
--		xReferencia: Referencia donde esta el acuse
CREATE OR REPLACE PROCEDURE WRITEACUSE(
         xID          IN INTEGER,
         xRefID       IN INTEGER,
         xFRecibi     IN DATE,
         xAcuse       IN CHAR,
         xTercero     IN VARCHAR,
         xTipo        IN CHAR,
         ValorExpe    IN CHAR,
	   xReferencia  IN VARCHAR)

AS
   xRELACION 	CHAR(10);
   xNORDEN		INTEGER;

   CURSOR cNoti IS SELECT ID,VALOR FROM NOTIFICACIONES
		WHERE N_RELACION=xRELACION AND N_ORDEN=xNORDEN;
BEGIN


	SELECT N_RELACION,N_ORDEN INTO xRELACION, xNORDEN FROM NOTIFICACIONES WHERE ID=xID;

	--esto ocurre cuando se graban acuses de recibo sin haber generado la relacion antes,
	--normalmente cuando hay que meter acuses de recibo anteriores a la instalacion de la
	--aplicacion.
	--Tambien cuando sean acuses de recibo de expedientes
	IF xRELACION IS NULL OR ValorExpe='E' THEN
		APLICARWRITEACUSE(xID,xRefID,xFRecibi,xAcuse,xTercero,xTipo,ValorExpe,xReferencia);
	ELSE
		-- Si estoy grabando el acuse de un valor, y éste se encuentra en un impreso
		-- junto con otros valores, también tendré que grabar el acuse de los otros valores
		-- El cursor recorre todas las notificaciones del impreso
		FOR v_Noti IN cNoti LOOP
			APLICARWRITEACUSE(v_Noti.ID,v_Noti.VALOR,
					xFRecibi,xAcuse,xTercero,xTipo,ValorExpe,xReferencia);
	   	END LOOP;
	END IF;

END;
/

-- ----------------------------------------------------------------------------------------
-- Parametros:
--		xID: Id de Notificaciones
--		xRefID: ID de Valores o ID de Expedientes
--		xFRecibi: Fecha del Recibi
--		ValorExpe: 'V'-Valores o 'E':Expedientes
-- Modificacion: 16/7/2002 Lucas Fernández Pérez. Las costas por adelantado no pueden borrarse.
--
-- Modificacion: 26/03/2003 Agustín León Robles.
--		Puede darse un caso en el que el recibo no tenga principal, entonces el recargo será 
--		sobre la cuota_inicial (ingresados fuera de plazo)
-- Modificado: 28/04/2003 Lucas Fernández Pérez.
-- 	Ahora permite anular el acuse si el valor/expediente está enviado al BOP
--
-- Modificado: 18/06/2003. Lucas Fernández Pérez.
--	Cuando desagrupa de un expediente, aminora el campo RECIBOS o CUANTOS_R_SUSPEN 
--	dependiendo de si el recibo que se desagrupa estaba suspendido o no
-- Modificado: 08/01/2004. Lucas Fernández Pérez.
--  Al anular un acuse de un recibo pendiente o expediente abierto, 
--   pone el campo ID_COSTAS=Null en la tabla de NOTIFICACIONES.
--Modificación: 25/01/2005. Lucas Fernandez Perez. Se eliminan los campos FICHERO-IMAGEN e IMAGEN 
-- de la tabla NOTIFICACIONES. 
--
CREATE OR REPLACE PROCEDURE APLICARANULAACUSE(
         xID          IN INTEGER,
         xRefID       IN INTEGER,
         ValorExpe    IN CHAR)
AS
    xIDExpe		INTEGER;
    xEnvios 	INTEGER;
    xPuedoBorrarCostas	Boolean default true;
    xF_Publicacion DATE;
    xIdCostas 	integer;
    xFBaja		date;
    xFIngreso	date;
    xFSuspension date;
    xEstado		char(1);
    xIDCostasNEW  INTEGER;
    xTipoNoti 	char(3);
    xIDEmbargo	INTEGER;
    xCostaAdelantado char(1);
    xZona		char(2);
    xConfig		integer;
    xNRecibos	float;
    xLastAcuse	char(4);
    xTipo		char(1);
    xSiempreCosta char(1);
    mPrincipal	float;
    xIDCostaNull char(1);
BEGIN

	-- ver qué envio es este, si es el primero o el segundo
	SELECT N_ENVIOS,EXPEDIENTE,ID_COSTAS,NUMERO_OBJETOS,LAST_ACUSE,
		F_PUBLICACION,TIPO_NOTI,ID_EMBARGOS

	INTO xEnvios,xIDExpe,xIdCostas,xNRecibos,xLastAcuse,
		xF_Publicacion,xTipoNoti,xIDEmbargo

	FROM NOTIFICACIONES WHERE ID=xID;

	-- Si esta publicado, no anula la Notificacion
	IF xF_Publicacion IS NOT NULL THEN
		RETURN;
	END IF;


	if xLastAcuse='0101' then
		xTipo:='1';
	elsif xLastAcuse='0102' then
		xTipo:='2';
	elsif xLastAcuse='0201' then
		xTipo:='3';
	elsif substr(xLastAcuse,1,2)='03' then
		xTipo:='4';
	elsif substr(xLastAcuse,1,2)='04' then
		xTipo:='5';
	else  --en el caso de no tener acuse sera del tipo de ausente
		--esto se puede dar cuando se meten notificaciones anteriores a la instalacion
		--del programa
		xTipo:='5';
	end if;

	--xSiempreCosta: si se inserta siempre una costa o no, independientemente de si es
	--               notificado o no
	Select costa into xSiempreCosta from tipo_acuses where Tipo=xTipo;

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	--Configuracion del recargo.
	--Configuracion de si hay costas por adelantado o no.
	--En el caso de que las haya, no hay que hacer nada con las costas
	SELECT RECARGO,COSTA_ADELANTADO INTO xCONFIG,xCostaAdelantado
			FROM CONFIGURACION WHERE ZONA=xZONA;

	xIDCostaNull:='N';
	IF ValorExpe='V' Then

		UPDATE VALORES SET NOTIFICADO='N',F_NOTIFICACION=NULL
		WHERE ID=xRefID
		RETURN F_INGRESO,FECHA_DE_BAJA,F_SUSPENSION,EXPEDIENTE 
		INTO xFIngreso,xFBaja,xFSuspension,xIDExpe;

		--tiene que estar el valor pendiente de cobro para anular las costas y recargos
		if xFIngreso is null and xFBaja is null then

			--para eliminar las costas se tienen que dar 2 casos:
			-- 1) que no haya costa por adelantado
			-- 2) que en funcion de la configuracion haya grabado costa
			if xCostaAdelantado='N' and xSiempreCosta='S' then
				ActualizaCostasAUnValor(xRefID,xNRecibos,'S',xIDCostasNEW);
				xIDCostaNull:='S'; -- Indica que ponga id_costas=null en notificaciones
			end if;

			--me devuelve el principal de la deuda en ejecutiva, ya que si ha habido
			--entregas a cuenta en voluntaria y luego pasamos a ejecutiva el recibo,
			--el recargo se tiene que calcular sobre el principal del valor menos la suma
			--de las entregas a cuenta en voluntaria
			--Puede darse un caso en el que el recibo no tenga principal, entonces el recargo será 
			--sobre la cuota_inicial (ingresados fuera de plazo)
			mPrincipal:=DameIngresosVoluntaria(xRefID);

			--xCONFIG=0: 20% de recargo al momento de emitir la providencia
			--xCONFIG=1: 20% de recargo cuando llegue el acuse de recibo
			IF mPrincipal=0 THEN
				UPDATE VALORES SET
					EXPEDIENTE=NULL,F_IN_EXPEDIENTE=NULL,
					RECARGO=DECODE(xCONFIG,0,RECARGO,ROUND((CUOTA_INICIAL*10/100),2)),
					DEMORA_PENDIENTE=0 -- Se le eliminan los intereses que pudiera tener
				WHERE ID = xRefID
				and ENTREGAS_ANTESDEL_CARGO <= Principal;
			ELSE
				UPDATE VALORES SET
					EXPEDIENTE=NULL,F_IN_EXPEDIENTE=NULL,
					RECARGO=DECODE(xCONFIG,0,RECARGO,ROUND((mPrincipal*10/100),2)),
					DEMORA_PENDIENTE=0 -- Se le eliminan los intereses que pudiera tener
				WHERE ID = xRefID
				and ENTREGAS_ANTESDEL_CARGO <= Principal;
			END IF;

			IF xFSuspension IS NULL THEN --Actualizamos el contador de recibos del expediente
				UPDATE EXPEDIENTES SET RECIBOS=RECIBOS-1
					WHERE ID=xIDExpe AND F_INGRESO IS NULL AND F_ANULACION IS NULL;
			ELSE --Actualizamos el contador de recibos SUSPENDIDOS del expediente
				UPDATE EXPEDIENTES SET CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN-1
					WHERE ID=xIDExpe AND F_INGRESO IS NULL AND F_ANULACION IS NULL;
			END IF;

		end if;

	ELSE -- Expedientes

		SELECT IS_LIVE INTO xEstado FROM EXPEDIENTES WHERE ID=xIdExpe;

		-- Si el expediente está cerrado, no introducimos más costas.
		if xEstado='S' then
			PON_COSTA(NULL,xID,NULL,NULL,NULL,'N','S',xIdCostas,xIDCostasNEW);
			xIDCostaNull:='S'; -- Indica que ponga id_costas=null en la tabla notificaciones
		end if;

	END IF; -- ValorExpe


	IF xEnvios=1 THEN
		
		UPDATE notificaciones Set
			F_1ACUSE= NULL, ACUSE1= NULL, TERCERO_1NOTIFI = NULL,
			NOTIFICADO = 'N', F_NOTIFICACION = NULL,
			F_LAST_ACUSE = NULL,LAST_ACUSE  = NULL, 
			ID_COSTAS=DECODE(xIDCostaNull,'S',NULL,ID_COSTAS),
			REFERENCIA = NULL
		WHERE id=xID;

	ELSE
		UPDATE notificaciones Set
			F_2ACUSE=NULL, ACUSE2=NULL, TERCERO_2NOTIFI=NULL,
			NOTIFICADO='N', F_NOTIFICACION=F_1ACUSE,
			F_LAST_ACUSE=F_1ACUSE,	LAST_ACUSE=Acuse1, 
			ID_COSTAS=DECODE(xIDCostaNull,'S',NULL,ID_COSTAS),
			Referencia=NULL
		WHERE id=xID;
		
	END IF;

	-- Si la anulacion es de una notificacion sobre un expediente
	IF ValorExpe='E' Then

		-- Actualiza los campos NOTI_EMBARGO y NOTI_SUBASTA
		-- de posibles embargos de inmuebles
		-- o vehículos que tenga el expediente.
		TERCEROS_NOTI(xTipoNoti,xRefID,xIDEmbargo);

		-- Actualizo los valores vivos del expediente para que su f_last_anoti
		-- apunte a la ultima notificación positiva del expediente
		NotiSetLastValid(xRefID);
	end if;

END;
/
-- -----------------------------------------------------------------------------------------
-- 20/3/2002 Lucas Fernández Pérez.
-- El anterior ANULAACUSE se baja un nivel y se renombra a APLICARANULAACUSE.
-- El nuevo anulaacuse llama a APLICARANULAACUSE, con una nueva opción: si el acuse
-- es sobre un recibo que está en un impreso junto con otros, hace una llamada
-- a APLICARANULAACUSE por cada recibo, para anular el acuse a todos los recibos del impreso.
--
--	Modificado: 12 de Septiembre de 2002. Agustin Leon Robles.
--				Si se anula una notificacion antigua a la instalacion de la aplicacion
--				da error, porque no hay datos en la tabla de notificaciones.
--
CREATE OR REPLACE PROCEDURE ANULAACUSE(
         xID          IN INTEGER,
         xRefID       IN INTEGER,
         ValorExpe    IN CHAR)
AS
	xRELACION  CHAR(10);
	xNORDEN	   INTEGER;

	CURSOR cNoti IS SELECT ID,VALOR FROM NOTIFICACIONES
	WHERE N_RELACION=xRELACION AND N_ORDEN=xNORDEN;
BEGIN

	begin
		SELECT N_RELACION,N_ORDEN INTO xRELACION, xNORDEN FROM NOTIFICACIONES WHERE ID=xID;
	exception
		when no_data_found then
			begin
				UPDATE VALORES SET NOTIFICADO='N',F_NOTIFICACION=NULL	where ID=xRefID;
				return;
			end;
	end;

	IF xRELACION IS NULL OR ValorExpe='E' THEN
		APLICARANULAACUSE(xID,xRefID,ValorExpe);
	ELSE
		--El cursor recorre todas las notificaciones del impreso
		FOR v_Noti IN cNoti LOOP
			APLICARANULAACUSE(v_Noti.ID,v_Noti.VALOR,ValorExpe);
		END LOOP;
	END IF;

END;
/

-- ----------------------------------------------------------------------------------------
-- 25/01/2005 Lucas Fernández Pérez
-- Creación de una tupla vacía en Imagenes_Noti para meter un de acuse de notificación, 
-- y enlace de las notificaciones de esa relacion y número de orden a la tupla nueva
--
CREATE OR REPLACE PROCEDURE ADD_IMAGENES_NOTI(
	xAYTO   	IN CHAR,
	xVOL_EJE    IN CHAR,
	xN_RELACION IN CHAR,
	xN_ORDEN    IN INTEGER,
	xN_ENVIOS   IN INTEGER,
	xID     	OUT INTEGER)
AS
BEGIN

  Insert Into IMAGENES_NOTI (AYTO) VALUES (xAYTO)	RETURNING ID INTO xID;
  
  if xVOL_EJE='EJE' then
  
    if xN_RELACION IS null then
      UPDATE NOTIFICACIONES SET 
         ID_IMAGEN_ACUSE1=DECODE(xN_ENVIOS,1,xID,ID_IMAGEN_ACUSE1),
         ID_IMAGEN_ACUSE2=DECODE(xN_ENVIOS,1,ID_IMAGEN_ACUSE2,xID)
      WHERE N_RELACION IS NULL AND N_ORDEN=xN_ORDEN AND TIPO_NOTI<>'VOL';
    else
      UPDATE NOTIFICACIONES SET 
         ID_IMAGEN_ACUSE1=DECODE(xN_ENVIOS,1,xID,ID_IMAGEN_ACUSE1),
         ID_IMAGEN_ACUSE2=DECODE(xN_ENVIOS,1,ID_IMAGEN_ACUSE2,xID)
      WHERE N_RELACION=xN_RELACION AND N_ORDEN=xN_ORDEN AND TIPO_NOTI<>'VOL';
    end if;
    
   elsif xVOL_EJE='VOL' then
   
    if xN_RELACION IS null then
      UPDATE NOTIFICACIONES SET 
         ID_IMAGEN_ACUSE1=DECODE(xN_ENVIOS,1,xID,ID_IMAGEN_ACUSE1),
         ID_IMAGEN_ACUSE2=DECODE(xN_ENVIOS,1,ID_IMAGEN_ACUSE2,xID)
      WHERE N_RELACION IS NULL AND N_ORDEN=xN_ORDEN AND TIPO_NOTI='VOL';
    else
      UPDATE NOTIFICACIONES SET 
         ID_IMAGEN_ACUSE1=DECODE(xN_ENVIOS,1,xID,ID_IMAGEN_ACUSE1),
         ID_IMAGEN_ACUSE2=DECODE(xN_ENVIOS,1,ID_IMAGEN_ACUSE2,xID)
      WHERE N_RELACION=xN_RELACION AND N_ORDEN=xN_ORDEN AND TIPO_NOTI='VOL';
    end if;

   end if;
  
END;
/

-- ----------------------------------------------------------------------------------------
-- Parametros:
--		xIDExpe: Id del Expediente
--
-- En las notificaciones de expedientes, actualizaremos el campo f_notificacion de la
-- tabla valores siempre que la notificación sea positiva. Lo que nos interesa saber es
-- la última fecha de notificación valida, debido a la prescripción, las deudas prescriven
-- a partir de cuatro años sin actuar la administración sin conocimiento del sujeto pasivo,
-- cuenta simepre a partir de esta última notificación válida.
--
-- Cuando una notificación pasa a ser de notificada a no notificada
-- tenemos que recuperar la última fecha de notificación válida
--
-- Los valores que esten vivos en el expediente despues de una notificación al expediente
-- serán marcados todos con la fecha de la notificación
--
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
--
-- Modificado: 17-02-2005. Lucas Fernández Pérez. Cambia la lógica del campo F_LASTNOTI. 
--  Ahora lo que muestra para un valor es la fecha de la última notificación positiva del expediente 
--  en que se encuentre. Antes, cuando se reponía una notificación y se llamaba a este procedimiento, 
--  podía poner en el campo la fecha de notificación positiva del valor. Ahora solo se pone fecha de 
--  notificación positiva de EXPEDIENTES.

CREATE OR REPLACE PROCEDURE NotiSetLastValid(
	xIDExpe IN INTEGER)

AS
xFNOTI  DATE;

BEGIN

-- buscar la notificación de expediente válida más reciente
SELECT MAX(F_NOTIFICACION) INTO xFNOTI FROM NOTIFICACIONES
	WHERE EXPEDIENTE=xIDExpe
	AND NOTIFICADO='S';

-- Sólo actualizamos cuando el valor esté vivo, si está pagado o anulado no hacemos nada
UPDATE VALORES SET F_LAST_NOTI=xFNOTI
	WHERE EXPEDIENTE=xIDExpe
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL;

END;
/

--
-- Fin de los ACUSES DE RECIBO
--

/*******************************************************************************
Acción: Poner fecha de publicación. Relación de Valores.
MODIFICACIÓN: 24/09/2001 M. Carmen Junco Gómez. Adaptación al Euro.
*******************************************************************************/
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
-- Modificado: Agustín León Robles. 26/03/2003
--		Puede darse un caso en el que el recibo no tenga principal, entonces el recargo será 
--		sobre la cuota_inicial (ingresados fuera de plazo)
-- Modificado: Agustín León Robles. 23/04/2003
--		Solo inserta en Costas_Valores si el importe de la costa es mayor que 0.
-- Modificado: 28/04/2003 Lucas Fernández Pérez.
-- 	Algún valor podría estar ya notificado, en cuyo caso no se actualiza la f.notificación
-- Modificado: 08/01/2004 Lucas Fernández Pérez.
--  Actualiza el campo ID_COSTAS en la tabla de NOTIFICACIONES si xImpo>0
--

/*DELPHI*/
CREATE OR REPLACE PROCEDURE PON_FECHA_BOP(
	xRELA 		IN	CHAR,
      xFPUBLICACION 	IN 	DATE,
      xIMPO 		IN 	FLOAT)
AS
   xIDCOSTAS INTEGER;
   xTEXTO CHAR(50) DEFAULT 'GASTOS AUTOMATICOS PUBLICAR EN EL B.O.P.';
   xZONA CHAR(2);
   mPrincipal float default 0;
   xUpdateCostas char(1);

   CURSOR CPublicacion IS
      SELECT ID,NIF,AYTO,F_INGRESO FROM VALORES
      WHERE RELACION_APREMIO=xRELA AND FECHA_DE_BAJA IS NULL 
   	      FOR UPDATE OF RECARGO,COSTAS,NOTIFICADO,F_NOTIFICACION;

BEGIN

  SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

  FOR vVALORPublica IN cPublicacion LOOP

	xUpdateCostas:='N';
	if vVALORPublica.F_INGRESO IS Null then

		--en el caso de que el recibo este ingresado no se pone costa de correo,
		--solo se graba la fecha de publicacion
		if xIMPO > 0 then
			INSERT INTO COSTAS_VALORES (VALOR,CONCEPTO,IMPORTE,FECHA)
			VALUES (vVALORPublica.ID,xTEXTO,ROUND(xIMPO,2),xFPUBLICACION)
			RETURNING ID INTO xIDCostas;
			xUpdateCostas:='S';
		end if;

		--me devuelve el principal de la deuda en ejecutiva, ya que si ha habido
		--entregas a cuenta en voluntaria y luego pasamos a ejecutiva el recibo, el recargo se
		--tiene que calcular sobre el principal del valor menos la suma de
		--las entregas a cuenta en voluntaria
		--Puede darse un caso en el que el recibo no tenga principal, entonces el recargo será 
		--sobre la cuota_inicial (ingresados fuera de plazo)
		mPrincipal:=DameIngresosVoluntaria(vVALORPublica.ID);

    	-- F_NOTIFICACION SERÁ LA DE PUBLICACION si no estaba anteriormente notificado
	      UPDATE VALORES SET 
					RECARGO=DECODE(mPrincipal,0,ROUND(CUOTA_INICIAL*20/100,2),ROUND(mPrincipal*20/100,2)),
					COSTAS=COSTAS+ROUND(xImpo,2),
					NOTIFICADO='S',
					F_NOTIFICACION=Decode(NOTIFICADO,'S',F_NOTIFICACION,xFPUBLICACION)
      	WHERE CURRENT OF CPublicacion;

		APREMIADOS_A_EXPEDIENTE(vVALORPublica.NIF,vVALORPublica.AYTO, xZONA);
	else
    	-- F_NOTIFICACION SERÁ LA DE PUBLICACION si no estaba anteriormente notificado
	      UPDATE VALORES SET NOTIFICADO='S',
		  F_NOTIFICACION=Decode(NOTIFICADO,'S',F_NOTIFICACION,xFPUBLICACION)
      	WHERE CURRENT OF CPublicacion;
	end if;

    UPDATE NOTIFICACIONES SET 
      	F_NOTIFICACION=Decode(NOTIFICADO,'S',F_NOTIFICACION,xFPUBLICACION),
		F_PUBLICACION=xFPUBLICACION, NOTIFICADO='S',
		ID_COSTAS=DECODE(xUpdateCostas,'S',xIDCostas,ID_COSTAS)
    WHERE VALOR=vVALORPublica.ID AND TIPO_NOTI<>'VOL';

  END LOOP;

END;
/

-- *******************************************************************************
-- Acción: Poner fecha de publicación. Relación de Expedientes.
-- MODIFICACIÓN: 24/09/2001 M. Carmen Junco Gómez. Adaptación al Euro.
-- *******************************************************************************
-- Modificado: 28/04/2003 Lucas Fernández Pérez.
-- 	Algún exped. podría estar ya notificado, en cuyo caso no se actualiza la f.notificación
-- Modificado: 01/03/2004 Gloria Maria Calle Hernandez.
-- Sacado Expediente is not null del cursor para hacer comparacion dentro del cursor y hacer 
-- mas rapida la ejecucion del procedimiento
--
-- Modificado: 17/02/2005 Lucas Fernández Pérez.
--   Llamada a Noti_SetLastValid para poner en los valores del expediente, en el campo F_LASTNOTI 
--   la última fecha de notificación positiva del expediente de esos valores.
--
--DELPHI
CREATE OR REPLACE PROCEDURE PON_FECHA_BOP_EXPE(
	xRELA			IN CHAR,
      xFPUBLICACION 	IN DATE,
      xIMPO 		IN FLOAT)
AS
    	xCODOPERACION 	INTEGER default 0;
   	CURSOR CPublica IS
	   SELECT ID,EXPEDIENTE,TIPO_NOTI,ID_EMBARGOS FROM NOTIFICACIONES
	   WHERE N_RELACION=xRELA 
	   FOR UPDATE OF F_PUBLICACION,NOTIFICADO, F_NOTIFICACION,ID_COSTAS;

BEGIN

   FOR vPublica IN CPublica LOOP

     IF vPublica.Expediente is not null THEN
	    ADD_COSTA_EXPE(vPublica.EXPEDIENTE,xIMPO,'COSTA DE PUBLICACION EN B.O.P. DE EXPEDIENTES',
					   xCODOPERACION);

	    --si es 0 significa que el expediente estaba pagado, entonces no hay costa de correos
	    if xCODOPERACION=0 then
		   UPDATE NOTIFICACIONES SET F_PUBLICACION=xFPUBLICACION,NOTIFICADO='S',
				  F_NOTIFICACION=Decode(NOTIFICADO,'S',F_NOTIFICACION,xFPUBLICACION)
	        WHERE CURRENT OF CPublica;
	    else
	       UPDATE NOTIFICACIONES SET F_PUBLICACION=xFPUBLICACION,NOTIFICADO='S',
                  ID_COSTAS=xCODOPERACION,
				  F_NOTIFICACION=Decode(NOTIFICADO,'S',F_NOTIFICACION,xFPUBLICACION)
	        WHERE CURRENT OF CPublica;
	    end if;

	    --si se trata de alguna notificacion hay que actualizar en las tablas de embargos
	    TERCEROS_NOTI(vPublica.TIPO_NOTI,vPublica.EXPEDIENTE,vPublica.ID_EMBARGOS);
	    
	    -- Pone en los valores del expediente (F_LASTNOTI) la última f_notificación positiva del expediente.
	    NotiSetLastValid(vPublica.EXPEDIENTE);
	 END IF;

   END LOOP;

END;
/

/****************************************************************************************/
-- Añade una notificacion a un expediente
/*BASE*/
CREATE OR REPLACE PROCEDURE Add_Notificaciones_expe(
        xIdExpe   IN Integer,
        xTipo     IN Char,
        xID       IN Integer,
        xNIF      IN Char,
        xRELACION IN Char)

AS

xComo integer;
xRela char(10) default null;
xComent varchar(90);
xDESCRIP varchar(30) default null;
xCONT INTEGER;
xLast Integer;
xZona char(2);
CONTADOR INTEGER;

BEGIN

   select zona into xZona from usuarios where usuario=user;
   Select RELACIONES_EXPE Into xComo from configuracion
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   -- Relacion Semanal
   If (xComo=1) Then

      -- Comprobar si hay una relaci¢n con la fecha de hoy.
      -- En caso contrario añadir una nueva relacion de tipo de expedientes

      select count(*) into CONTADOR FROM RELACIONES_NOTI
         where TO_CHAR(fecha,'IW')=TO_CHAR(sysdate,'IW')
         and F_Year(fecha)=F_Year(sysdate)
         and tipo_Rela='1'
	   AND TIPO_NOTI='C';

	IF (contador > 0) THEN

         select RELACION into xRela FROM RELACIONES_NOTI
         where TO_CHAR(fecha,'IW')=TO_CHAR(sysdate,'IW')
         and F_Year(fecha)=F_Year(sysdate)
         and tipo_Rela='1' AND TIPO_NOTI='C';

      ELSE

         DAME_RELACION(xRela);
         INSERT INTO RELACIONES_NOTI
            (RELACION,FECHA, USUARIO, TIPO_RELA, ZONA)
         VALUES (xRela, SYSDATE , USER, '1', xZona );

      END IF;

   ELSE
      -- relación que la genera el usuario a su gusto
      SELECT COUNT(*) INTO CONTADOR FROM DATOSPERR WHERE LAST_RELACION IS NOT NULL;
      if (CONTADOR>0) then
         select last_relacion into xRela from datosperR;
      end if;
   END IF;

   -- Aqui ya tenemos en xRela la relación sobre la que va a ir la notificacion.

   -- INSERTAMOS LA NOTIFICACION
   IF (xRELACION <> 'QQ') THEN
	SELECT LAST_TAREA INTO xLast from USUARIOS WHERE USUARIO=USER; -- Lee ID Tercero

      -- Tiene un parametro mas para poder identificar univocamente al tercero
	--EL CAMPO N_ORDEN SE RELLENA EN UN TRIGGER T_NEWNOTI, CUANDO ES DE NOTIFICACIONES
	--DE VALORES SE PONE EL ID DE LA TABLA DE VALORES Y CUANDO ES NOTIFICACIONES
	--DE EXPEDIENTES SE PONE EL ID DE TABLA DE NOTIFICACIONES
      INSERT INTO NOTIFICACIONES
		(EXPEDIENTE,N_ENVIOS,TIPO_NOTI,NIF,
		F_1INTENTO,F_INTENTO,N_RELACION,ID_EMBARGOS,ID_TERCERO)
      VALUES (xIdExpe, 1, xTipo, xNIF,
		SYSDATE, SYSDATE, xRela, xID, xLast);

   ELSE -- No es a un tercero, sino al titular
	INSERT INTO NOTIFICACIONES
		(EXPEDIENTE,N_ENVIOS,TIPO_NOTI,NIF,
		F_1INTENTO,F_INTENTO,N_RELACION,ID_EMBARGOS)
	VALUES (xIdExpe, 1, xTipo, xNIF,
		SYSDATE, SYSDATE, xRela, xID);
   END IF;

   -- Notificacion insertada apuntando a la relación.

   -- para insertar en el seguimiento el titulo de la notificacion
   SELECT TEXTO INTO xComent FROM TIPO_NOTIFICACION WHERE TIPO=xTIPO;

   IF (xRELACION <> 'QQ') THEN
      SELECT DESCRIPCION INTO xDESCRIP
      FROM TIPO_TERCERO
      WHERE RELACION IN (SELECT RELACION FROM TERCEROS WHERE ID=xLast);
   END IF;

   IF (xDescrip is not null) then
      xCOMENT:=SubStr(xCOMENT, 1, 55) || ' ' || RTRIM(xDESCRIP);
   END IF;

   PkSeguimiento.NotaInformativa(xIdExpe, xComent, xID);

END;
/

/***************************************************************************************
Acción: Pasar un cargo a ejecutiva

Modificación: 14/06/2002 Antonio Pérez Caballero
			  No pasaran los recibos suspendidos, por causas como fraccionamiento.
Modificacion: 25/10/2002 Agustín León Robles
			  Se debe de providencias de apremio todos los recibos que estuvieran 
			  pendientes de cobro a la fecha del final del periodo voluntario, 
			  porque normalmente el pase a ejecutiva se hace con días de retraso, 
			  entonces en este intervalo se pueden haber cobrado recibos con el 10%
			  a anularse. Los recibos suspendidos si se quedan en voluntaria.
Modificacion: 30/10/2002 Lucas Fernanández Pérez.
 			  Si los recibos tienen notificaciones en voluntaria pasan a ejecutiva 
 			  sólo si NOTIFICADO='S'  y se haya pasado el final del periodo voluntario.
Modificación: 22/04/2003 Mª Carmen Junco Gómez. Se añade como parámetro la fecha de
			  vencimiento del periodo voluntario. 
Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
Modificacion: 19/10/2004 Agustín León Robles. Los valores propuestos de baja no se pasan a ejecutiva
DELPHI
Modificacion: 21/10/2004 Gloria María Calle Hernández. Se añade parámetro PADRON, para el pase
				de voluntaria a ejecutiva del barrido de liquidaciones por concepto y fechas. Desde Delphi 
				si se trata de un pase de liquidaciones envía el código de PADRON correspondiente
				si se trata de un pase de un cargo envía este código nulo.
*****************************************************************************************/
CREATE OR REPLACE PROCEDURE PASE_A_EJECUTIVA(
        xCARGO	IN	CHAR,
        xPADRON IN  CHAR,
        xAyto  	IN	CHAR,
        xFProvi IN	DATE,
        xFVenci	IN	DATE)
AS

CURSOR cPaseEjecutiva IS
  SELECT ID FROM VALORES
	WHERE N_CARGO=xCARGO
	AND PADRON=decode(xPadron,NULL,PADRON,xPadron)
	AND AYTO=xAYTO
	AND VOL_EJE='V'
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL
	AND FECHA_PROPUESTA_BAJA IS NULL
	AND CUOTA_INICIAL > 0
	AND ENTREGAS_A_CUENTA > 0
	AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES)
	AND FIN_PE_VOL<TRUNC(xFVenci,'DD')
FOR UPDATE OF RECARGO,VOL_EJE,F_APREMIO;

xPRINCIPAL	FLOAT	DEFAULT 0;
xRECARGO  	FLOAT DEFAULT 0;
xCOSTAS  	FLOAT DEFAULT 0;
xDEMORA  	FLOAT DEFAULT 0;
xFinPeVol	date;
xNOTIFICADO	CHAR(1);
BEGIN


	--para saber el final del periodo voluntario del cargo
	select min(fin_pe_vol) into xFinPeVol from valores WHERE N_CARGO=xCARGO
		AND AYTO=xAYTO
  	AND PADRON=decode(xPadron,NULL,PADRON,xPadron)
		AND VOL_EJE='V'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND FECHA_PROPUESTA_BAJA IS NULL
		AND CUOTA_INICIAL > 0
		AND ENTREGAS_A_CUENTA=0
		AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES);

	-- Los valores de los organismos que no pueden ser embargados
	-- se siguen dejando en voluntaria
	UPDATE VALORES v
		SET VOL_EJE='E',RECARGO=ROUND(CUOTA_INICIAL*5/100, 2),
		F_APREMIO=TRUNC(xFProvi,'dd')
	WHERE N_CARGO=xCARGO
	AND PADRON=decode(xPadron,NULL,PADRON,xPadron)
	AND AYTO=xAYTO
	AND VOL_EJE='V'
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL
	AND FECHA_PROPUESTA_BAJA IS NULL
	AND CUOTA_INICIAL > 0
	AND ENTREGAS_A_CUENTA=0
	AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES)
	AND ID NOT IN (SELECT VALOR FROM NOTIFICACIONES WHERE VALOR=v.ID AND
				TIPO_NOTI='VOL' AND NOTIFICADO='N')
	AND FIN_PE_VOL<TRUNC(xFVenci,'DD');

	-- Aquellos que se ingresaran, anularan con fecha despues del final
	-- del periodo voluntario tambien se deben de providenciar de apremio,
	-- pero deben de ser valores que ya esten en ejecutiva, porque puede ocurrir que vengan
	-- disco de cobro del C60 o de domiciliaciones con posterioridad a la fecha del final
	-- del periodo voluntario
	xFinPeVol:=xFinPeVol+1;

	UPDATE VALORES SET F_APREMIO=TRUNC(xFProvi,'dd')
	WHERE N_CARGO=xCARGO
 	AND PADRON=decode(xPadron,NULL,PADRON,xPadron)
	AND AYTO=xAYTO
	AND VOL_EJE='E'
	AND (F_INGRESO >= xFinPeVol or FECHA_DE_BAJA >= xFinPeVol)
	AND CUOTA_INICIAL > 0;


	-- Los insolventes proponerlos para baja
	UPDATE VALORES SET PROPU_INSOLVENTE='S'
	WHERE N_CARGO=xCARGO
	AND PADRON=decode(xPadron,NULL,PADRON,xPadron)
	AND AYTO=xAYTO
	AND VOL_EJE='E'
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND NIF IN (SELECT NIF FROM INSOLVENTES);


	--Los que tienen entregas a cuenta se calcula el recargo sobre el principal pendiente
	FOR xPaseEjecutiva IN cPaseEjecutiva loop

		BEGIN
			SELECT NOTIFICADO INTO xNOTIFICADO FROM NOTIFICACIONES
				WHERE VALOR=xPaseEjecutiva.ID AND TIPO_NOTI='VOL';
		EXCEPTION
			--no habria registros en la tabla de notificaciones
			--cuando fuera un cargo de recibos
			WHEN NO_DATA_FOUND THEN
				xNOTIFICADO:='S';
		END;


		IF xNOTIFICADO='S' THEN

			pkIngresos.GET_INGRESADO(xPaseEjecutiva.ID, xPRINCIPAL, xRECARGO,
						xCOSTAS, xDEMORA);

			update valores set recargo=ROUND((PRINCIPAL-xPrincipal)*5/100, 2),
						VOL_EJE='E',F_APREMIO=TRUNC(xFProvi,'dd')
			where current of cPaseEjecutiva;
		END IF;

	end loop;

END;
/

-- ******************************************************************************************************
-- Autor: 29 de Mayo de 2002. Agustin Leon Robles.
-- Acción:Rellena las tablas temporales para imprimir las cartas de pago de una
-- 	 relacion de apremio
-- MODIFICACIÓN: 04/11/2002 M. Carmen Junco Gómez. Se introducen y se rellenan nuevos
-- 		  campos en la tabla temporal tmpdeudasvivas.
-- MODIFICACIÓN: 03/02/2003 M. Carmen Junco Gómez. Se cambia el pendiente fijo para quitarle
-- 		  las entregas a cuenta.
-- MODIFICACIÓN: 01/04/2003 M. Carmen Junco Gómez. Se añade el campo CUOTA_INICIAL a la 
--           tabla TMPDEUDASVIVAS.
-- Modificado: 22/07/2003 Lucas Fernández Pérez. Se añaden los campos NOTIFICADO 
--			 y F_NOTIFICACION a la tabla TMPDEUDASVIVAS.
-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- Modificado: 12/07/2004. Lucas Fernández Pérez. Si era un cargo antiguo ponía xRECARGO20=xRECARGO20*2;	
--			Eso es incorrecto. No es lo mismo el 20% del principal que 2 * 10%(truncado)de principal
-- Modificado: 21/07/2004. Lucas Fernández Pérez. 
-- Antes xDeuda = principal+recargo+costas+demora y ahora se añade +demora_pendiente
-- *******************************************************************************************************
CREATE OR REPLACE PROCEDURE NotifiRellenaCartasPago
			(xIdCartaPago IN integer,
			 xValor IN float,
			 xNIF out char)
AS
xEntregasACuenta  	float;
xDESCRIPCION 		VARCHAR(50);
xNOMBRE				char(40);
xAYTO				char(3);
xPADRON				char(6);
xYEAR				char(4);
xPERIODO			char(2);
xRECIBO				integer;
xCUOTA_INICIAL		float;
xPRINCIPAL			float;
xRECARGO			float;
xRECARGO20			float;
xCOSTAS				float;
xCostasFijas		float;
xDEMORA				float;
xDEUDA				float;
xDEMORA_PENDIENTE	float;
xPENDIENTE			float;
xPENDIFIJO			float;
xENTREGAS_A_CUENTA	float;
xOBJETO_TRIBUTARIO 	varchar2(1024);
xFIN_PE_VOL			date;
xF_APREMIO			date;
xOrden_Apremio		integer;
xRelacion_Apremio 	char(10);
xTIPO_DE_OBJETO		char(1);
xDOM_TRIBUTARIO		varchar2(60);
xCLAVE_CONCEPTO  	varchar2(30);
xCLAVE_EXTERNA		varchar2(20);
xFUERAPLAZO			float default 0;
xNOTIFICADO			char(1);
xF_NOTIFICACION		date;
BEGIN

	begin
		SELECT IMPORTE INTO xCOSTASFIJAS FROM PRECIO_CORREO WHERE TIPO='L';
	Exception
		When no_data_found then
			xCOSTASFIJAS:=0;
	end;

	SELECT NIF,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,CUOTA_INICIAL,
	   PRINCIPAL,RECARGO,ROUND((PRINCIPAL*10)/100,2),COSTAS,DEMORA,
	   (PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE),DEMORA_PENDIENTE,
	   (PRINCIPAL + RECARGO + COSTAS + DEMORA - ENTREGAS_A_CUENTA + DEMORA_PENDIENTE),
	   ROUND(PRINCIPAL+ROUND((PRINCIPAL*10)/100,2)+xCOSTASFIJAS +DEMORA 
	   - ENTREGAS_A_CUENTA + DEMORA_PENDIENTE,2),NOTIFICADO,F_NOTIFICACION,
	   OBJETO_TRIBUTARIO,FIN_PE_VOL,F_APREMIO,ORDEN_APREMIO,RELACION_APREMIO,
	   TIPO_DE_OBJETO,DOM_TRIBUTARIO,CLAVE_EXTERNA,ENTREGAS_ANTESDEL_CARGO,ENTREGAS_A_CUENTA

	into xNIF,xNOMBRE,xAYTO,xPADRON,xYEAR,xPERIODO,xRECIBO,xCLAVE_CONCEPTO,xCUOTA_INICIAL,
			xPRINCIPAL,xRECARGO,xRECARGO20,xCOSTAS,xDEMORA,
			xDEUDA,xDEMORA_PENDIENTE,
			xPENDIENTE,
			xPENDIFIJO,xNOTIFICADO,xF_NOTIFICACION,
			xOBJETO_TRIBUTARIO,xFIN_PE_VOL,xF_APREMIO,xORDEN_APREMIO,xRELACION_APREMIO,
			xTIPO_DE_OBJETO,xDOM_TRIBUTARIO,xCLAVE_EXTERNA,xFUERAPLAZO,xENTREGAS_A_CUENTA

	FROM VALORES WHERE ID=xValor;


	--si el final del periodo voluntario es anterior a la entrada en vigor de la Nueva Ley General Tributaria
	--incrementamos otro 10 % de recargo, para tener el 20% total
	if Trunc(xFIN_PE_VOL,'dd') < To_Date('30/06/2004','dd/mm/yyyy') then
		
		xRECARGO20:=ROUND((xPRINCIPAL*20)/100,2);
		
		xPENDIFIJO:= ROUND( xPRINCIPAL + ROUND((xPRINCIPAL*20)/100,2) + xCOSTASFIJAS + xDEMORA - xENTREGAS_A_CUENTA + xDEMORA_PENDIENTE,2);
		
	end if;
	
	-- Leer la descripción del concepto en función de su código
	SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS WHERE CONCEPTO=xPADRON;

	-- Relación de entregas a cuenta
	PkwtDocIngreso.wtEntregasDeUnValor(xValor,xEntregasACuenta);

	-- Insertar una deuda en el temporal
	INSERT INTO TmpDeudasVivas
        	(xID,DNI_DEUDOR,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
		CUOTA_INICIAL,PRINCIPAL,RECARGO,RECARGO20,COSTAS,COSTASFIJAS,DEMORA,
		FUERA_PLAZO_JUNTA,DEUDA,DEMORA_PENDIENTE,PENDIENTE,PENDIFIJO,ENTREGAS_A_CUENTA,
		OBJETO_TRIBUTARIO,xRECILIQUI,DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,NOTIFICADO,
		F_NOTIFICACION,F_APREMIO,ORDEN_APREMIO,RELACION_APREMIO,CLAVE_EXTERNA,IDCARTAPAGOBANCO)
	VALUES
	  	(xValor,xNIF,xNOMBRE,xAYTO,xPADRON,xYEAR,xPERIODO,xRECIBO,xCLAVE_CONCEPTO,
		xCUOTA_INICIAL,xPRINCIPAL,xRECARGO,xRECARGO20,xCOSTAS,xCOSTASFIJAS,xDEMORA, 
		xFUERAPLAZO,xDEUDA,xDEMORA_PENDIENTE,xPENDIENTE,xPENDIFIJO,xEntregasACuenta,
		xOBJETO_TRIBUTARIO,DECODE(xTIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION'),
		xDESCRIPCION, xDOM_TRIBUTARIO, xFIN_PE_VOL,xNOTIFICADO,xF_NOTIFICACION,xF_APREMIO,
		xORDEN_APREMIO,xRELACION_APREMIO,xCLAVE_EXTERNA,xIdCartaPago);

END;
/

-- *****************************************************************************************
-- Autor: 10/03/2003. Mª del Carmen Junco Gómez.
-- Acción:Rellena las tablas temporales para imprimir relaciones de apremio que se generaron
--        sin cartas de pago.
-- Modificado: 22/07/2003 Lucas Fernández Pérez. Se añaden los campos NOTIFICADO 
--			 y F_NOTIFICACION a la tabla TMPDEUDASVIVAS.
-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- Modificado: 22/07/2004. Lucas Fernández Pérez. 
-- Antes xDeuda = principal+recargo+costas+demora y ahora se añade +demora_pendiente
-- *****************************************************************************************
CREATE OR REPLACE PROCEDURE NotifiRellenaRelacion
		(xRelacion 		IN CHAR)
AS
xCostasFijas	 float default 0;
xDESCRIPCION	 VARCHAR(50);
xEntregasACuenta float default 0;
xIDCARTAPAGO	 INTEGER DEFAULT 0; --nos inventamos un número correlativo de id de carta de pago
			                        -- para poder hacer el join entre tmpdeudasvivas y tmpdeudordpostales.
xZONA			 CHAR(2);
xNOMBRE 		 CHAR(40);
xDOMI 			 VARCHAR(50);
xCODPOSTAL 		 CHAR(5);
xPOBLACION 		 VARCHAR(35);
xPROVINCIA 		 VARCHAR(35);
xAYUNTA 		 VARCHAR(50);
xEMPRESA 		 VARCHAR(80);
xDIRECCION		 VARCHAR(100);
xCIF 			 CHAR(10);
xPOBLADATOSPER 	 VARCHAR(50);
xEXPEDIENTE		 CHAR(10);
xTipoRecargo	 integer;
		
CURSOR cVALORES IS Select V.ID, V.Nombre,V.Ayto, V.Year, V.Recibo, V.F_Apremio, V.Padron, V.Periodo,
        V.Objeto_tributario, V.Tipo_de_objeto, V.Principal, V.Recargo, v.Costas, 
        V.Demora, V.demora_pendiente, V.Dom_tributario, V.Clave_concepto, V.Fin_pe_vol,
        V.orden_apremio, V.Relacion_apremio,V.Notificado,V.F_Notificacion,
        C.Nif, C.via, C.calle, C.numero, C.escalera, C.planta, C.piso,
        C.Codigo_postal, C.Poblacion, C.Provincia
		from Importe_Valores V, Contribuyentes C
		where C.Nif=V.Nif
        	  AND V.Relacion_Apremio=xRelacion
        	  AND VOL_EJE='E'
        	  AND NOTIFICADO='N' AND F_INGRESO IS NULL
        	  AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;

BEGIN
    

	-- Primero borra todos los datos de las tablas temporales que va a rellenar.
	DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID;
	DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
	DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;
	
	select importe into xCostasFijas from precio_correo where tipo='L';

	for vValores in cValores loop	   	
	
		--si el final del periodo voluntario es anterior a la entrada en vigor de la Nueva Ley General Tributaria
		--se aplica el 20% de recargo sino se aplica el 10% de recargo
		if Trunc(vValores.Fin_pe_vol,'dd') >= To_Date('30/06/2004','dd/mm/yyyy') then
			xTipoRecargo:=20;
		else
			xTipoRecargo:=10;
		end if;
		
		xIDCARTAPAGO:=xIDCARTAPAGO+1;

		-- Leer la descripción del concepto en función de su código
		SELECT DESCRIPCION INTO xDESCRIPCION FROM CONCEPTOS WHERE CONCEPTO=vVALORES.PADRON;
	   
		-- Relación de entregas a cuenta
		PkwtDocIngreso.wtEntregasDeUnValor(vVALORES.ID,xEntregasACuenta);

		-- Insertamos datos en TMPDEUDASVIVAS
		INSERT INTO TmpDeudasVivas
        	(xID,DNI_DEUDOR,NOMBRE,AYTO,PADRON,YEAR,PERIODO,RECIBO,CLAVE_CONCEPTO,
			PRINCIPAL,RECARGO,RECARGO20,COSTAS,COSTASFIJAS,DEMORA,
			DEUDA,DEMORA_PENDIENTE,PENDIENTE,PENDIFIJO,ENTREGAS_A_CUENTA,
			OBJETO_TRIBUTARIO,xRECILIQUI,DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,NOTIFICADO,
			F_NOTIFICACION,F_APREMIO,ORDEN_APREMIO,RELACION_APREMIO,IDCARTAPAGOBANCO)
		VALUES
	  		(vVALORES.ID,vVALORES.NIF,vVALORES.NOMBRE,vVALORES.AYTO,vVALORES.PADRON,vVALORES.YEAR,
	  		vVALORES.PERIODO,vVALORES.RECIBO,vVALORES.CLAVE_CONCEPTO,
			vVALORES.PRINCIPAL,vVALORES.RECARGO,ROUND((vVALORES.PRINCIPAL*xTipoRecargo)/100,2),
			vVALORES.COSTAS,xCOSTASFIJAS,vVALORES.DEMORA,
			vVALORES.PRINCIPAL+vVALORES.RECARGO+vVALORES.COSTAS+vVALORES.DEMORA+vVALORES.DEMORA_PENDIENTE,
			vVALORES.DEMORA_PENDIENTE,
			vVALORES.PRINCIPAL + vVALORES.RECARGO + vVALORES.COSTAS + vVALORES.DEMORA - xEntregasACuenta + 
			vVALORES.DEMORA_PENDIENTE,
			ROUND(vVALORES.PRINCIPAL+ROUND((vVALORES.PRINCIPAL*xTipoRecargo)/100,2)+xCOSTASFIJAS + vVALORES.DEMORA - 
			xEntregasACuenta + vVALORES.DEMORA_PENDIENTE,2),
			xEntregasACuenta,
			vVALORES.OBJETO_TRIBUTARIO,DECODE(vVALORES.TIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION'),
			xDESCRIPCION, vVALORES.DOM_TRIBUTARIO, vVALORES.FIN_PE_VOL,vVALORES.NOTIFICADO,
			vVALORES.F_NOTIFICACION,vVALORES.F_APREMIO,vVALORES.ORDEN_APREMIO,
			vVALORES.RELACION_APREMIO,xIDCARTAPAGO);

	
		--Insertamos datos en TMPDEUDORDPOSTALES
	   
		-- Averiguar la zona del usuario
		SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

		-- datos postales del ayuntamiento para la cabecera
		SELECT AYUNTAMIENTO,NOMBRE,DIRECCION,CIF,POBLACION
		INTO xAYUNTA,xEMPRESA,xDIRECCION,xCIF,xPOBLADATOSPER
		FROM ZONAS WHERE ZONA=xZONA;

		-- Leer los datos postales del deudor
		SELECT NOMBRE,VIA||' '||CALLE||' '||NUMERO||' '||ESCALERA||' '||PLANTA||' '||PISO,
              CODIGO_POSTAL,POBLACION,PROVINCIA
		INTO  xNOMBRE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA
		FROM CONTRIBUYENTES WHERE NIF=vVALORES.NIF;       

		-- Insertar los datos postales en la tabla temporal.
		Insert into TmpDeudorDPostales 
        	(NIFEXPE,NOMBREEXPE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,
        	xCIF,xPOBLADATOSPER,IMPORTE,IDCARTAPAGOBANCO)
		Values (vVALORES.NIF,xNOMBRE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,
        	xCIF,xPOBLADATOSPER,
        	ROUND(vVALORES.PRINCIPAL+ROUND((vVALORES.PRINCIPAL*xTipoRecargo)/100,2)+xCOSTASFIJAS + vVALORES.DEMORA - 
			xEntregasACuenta + vVALORES.DEMORA_PENDIENTE,2),xIDCARTAPAGO);

	end loop;

END;
/



/****************************************************************************************
Acción: Calcular los intereses de demora a la fecha de emision de las cartas de pago
        de la providencia de apremio
Autor: 20/06/2002 Agustin Leon Robles
MODIFICACIÓN: 27/08/2002. Agustin Leon Robles: Devuelve como parametro el importe de los 
              intereses de demora.
MODIFICACIÓN: 17/10/2002. Agustin Leon Robles: Devuelve como parametro el importe de las 
              costas.
MODIFICACIÓN: 23/04/2003. Lucas Fernández Pérez: El update de la tabla Valores antes lo 
              hacía por ID sólo, y funcionaba mal cuando se trataba de reimprimir una 
              relacion, porque recibos notificados en ejecutiva NO PENDIENTES
              se les metía demora nuevamente (salían recibos ingresados y con demora 
              pendiente).
              Ahora, para cambiar la demora_pendiente, el recibo ha de estar PENDIENTE 
              de cobro.
MODIFICACIÓN: 03/06/2003. Mª del Carmen Junco Gómez: Se añade una nueva opción de 
			  configuración (DEMORA_ANTES_NOTI) que indica si se va a calcular o no 
			  demora para el valor antes incluso de haberlo notificado. 
MODIFICADO: 06/05/2004. Lucas Fernández Pérez. 
	Calcula los intereses llamando a INT_ENTREGAS además de a CAL_DEMORA.
	(antes solo llamaba a CAL_DEMORA con todo el principal del valor)
Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
Modificacion: 27/08/2004 Lucas Fernández Pérez. Se añade el parámetro xRecargo.
Modificacion: 02/09/2004 Lucas Fernández Pérez. Se añaden los parámetros xFIngreso, xFBaja y xFSuspension, para 
						evitar imprimir cartas de pago con algún recibo ingresado, anulado o suspendido.
			
	Este procedimiento es llamado desde los procedimientos NotifiGeneraCartasPago e 
	ImprimeCartaPago para calcular el interés a la fecha de emisión de la carta de pago,
	así como el recargo y costas actuales del valor, con el objetivo de imprimir 
	la notificación de apremio y el recordatorio de deudas de expedientes, respectivamente,
	si entre la creación de la carta de pago y la impresión no han surgido incidencias.
	Graba el interés en VALORES, y los procedimientos que llaman a este grabaran la
	demora en la tabla RECIBOSCARTAPAGOBANCO, puesto que al generarse no se calcula.

****************************************************************************************/
CREATE OR REPLACE PROCEDURE InteresProvidencia
				(xValor       in integer,
				xFecha 	      in date,
				xInteres      out float,
				xRecargo      out float,
				xCostas	      out float,
				xFIngreso     out date,
				xFBaja        out date,
				xFSuspension  out date)
AS
xFinPeVol 		date;
xTipoTributo 	char(2);
xPrincipal		float default 0;
xNotificado		char(1);
xVol_Eje		char(1);
xSiDemora		char(1);
xPrinING		float;
xPrinPen		float;
xDemora_VA		float;
SiCalculo		boolean default False;
BEGIN

	select Fin_Pe_Vol,TIPO_DE_TRIBUTO,principal,notificado,vol_eje,recargo,costas,f_ingreso,fecha_de_baja,f_suspension
			into xFinPeVol,xTipoTributo,xPrincipal,xNotificado,xVol_Eje,xRecargo,xCostas,xFIngreso,xFBaja,xFSuspension
			from valores where id=xValor;
			
	-- Si el valor esta ingresado, anulado o suspendido termina el procedimiento.
	if ( (xFIngreso is not null) or (xFBaja is not null) or (xFSuspension is not null)) then
		return;
	end if;
	
	xInteres:=0;
	
	-- recoger si hay que calcular la demora aunque el valor no esté notificado
	SELECT DEMORA_ANTES_NOTI INTO xSiDemora FROM CONFIGURACION 
	WHERE ZONA IN (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);
	
			
	if xVOL_EJE='E' then
    
		if Trunc(xFinPeVol,'dd') < to_date('30/06/2004','dd/mm/yyyy') then
		
			if ( (xSiDemora='S') OR (xSiDemora='N' and xNotificado='S') ) then              
				SiCalculo:=True;
			end if;
			
		else
		
			if xNotificado='S' then
				SiCalculo:=True;
			end if;
		
		end if;
	   
	end if;
	
	
	if SiCalculo then
	
		SELECT SUM(PRINCIPAL) INTO xPrinING FROM INGRESOS where VALOR=xValor;
		
		IF xPrinING IS NULL THEN
			xPrinING:=0;
		END IF;
		
		xPrinPen := xPrincipal - xPrinING;          
          
		-- DEVUELVE LOS INTERESES QUE HABRIA QUE COBRAR INCLUIDO 
		--  DE LAS ENTREGAS A LAS QUE NO SE LES HAYA COBRADO
		if xPrinING>0 then 
			INT_ENTREGAS(xValor,xFinPeVol,xTipoTributo,xDEMORA_VA);
		else
			xDEMORA_VA:=0;
		end if;
		                     
		Cal_Demora(xFecha, xFinPeVol, xTipoTributo, xPrinPen, xInteres);
		  
		xINTERES := xINTERES + xDEMORA_VA;

		update VALORES set DEMORA_PENDIENTE = ROUND(xInteres,2) where ID=xValor
		and F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
		
	end if;
END;
/

-- *****************************************************************************************
-- Acción: Rellena las tablas temporales para imprimir las cartas de pago de una relacion 
--         de apremio
-- 
-- Autor: 29 de Mayo de 2002. Agustin Leon Robles.
-- 
-- Modificado: 27 de Agosto de 2002. Agustin Leon Robles.
-- 		Se reajusta el importe de la demora en este momento, porque desde
-- 		que se generan las cartas de pago hasta cuando se imprimen puede
-- 		variar los intereses de demora
-- 
-- Modificado: 17 de Octubre de 2002. Agustin Leon Robles.
-- 		Se reajusta el importe de las costas porque cuando se graba en la tabla
-- 					reciboscartapagobanco se graban sin costas entonces se
-- 					actualiza en este momento.
-- 					
-- MODIFICACIÓN: 03/02/2003 M. Carmen Junco Gómez. El importe que se utiliza para el código
-- 	    de barras utilizará un recargo fijo del 20%. 
-- 	    
-- MODIFICACIÓN: 03/06/2003 Mª del Carmen Junco Gómez. Se calculan los dígitos para Cuaderno 60
-- 		      modalidad 1 y el código de barras modalidad 1 para que no lo tengan
-- 		      que hacer en Ateco.
-- Modificacion: 30/06/2003. Agustín León Robles. En el caso de que las cartas de pago
-- 			tuvieran como fecha tope el sabado o el domingo se pasarían a lunes
-- 			
-- Modificado: 02/07/2003. Lucas Fernández Pérez. La remesa para el cuaderno 60 modalidad 1
-- 			 se toma del campo REMESA_MOD1 de la tabla CONFIGURACION (antes era siempre 01).
-- 
-- Modificado: 16/07/2003. Lucas Fernández Pérez. Se podría imprimir la relacion cuando
--		los recibos ya están en diligencia de embargos, por lo que recalculaba los importes
--		y ajustaba los intereses de los recibos, hecho que llevaba a error, puesto que un 
--		recibo en diligencia de embargo tiene bloqueado el cambio de importes. 
--		Se evita esto con una comprobación previa en la que nos salimos del procedure 
--		si algún recibo de la relación tiene fecha de diligencia.
--
-- Modificacion: 21/07/2003. Agustín León Robles. Se ha cambiado la sentencia:
--				to_char(sysdate+xDias,'D') por la siguiente: to_char(sysdate+xDias,'Day') 
-- Modificado: 18/03/2004. Lucas Fernández Pérez. Nuevo Parámetro xCodPostal: 
--   'T' -> Muestra las cartas de pago de TODOS los codigos postales
--	 'I' -> Incluir solo codigos postales de la tabla TMP_CODIGOSPOSTALES
--	 'E' -> Todos los codigos postales excluyendo los de la tabla TMP_CODIGOSPOSTALES

-- Modificacion: 14/06/2004. Agustín León Robles. En funcion de la configuracion del tipo de empresa
-- que lleva la gestión de la recaudacion se mirará los datos de la emisora o bien a traves de la zona del usuario
-- o si es una empresa privada la que lleva la gestión se mirará en base a la zona del municipio de los recibos.

-- Modificado: 07/07/2004. Lucas Fernández Pérez. Nuevo Parámetro xNIFConsulta: 
--	xNIFConsulta= null -> Hay que generar toda la relacion
--  xNIFConsulta<>null -> Solo se genera información para el NIF indicado. Se llama desde visualizar relaciones de notif.

-- Modificado: 27/08/2004-02/09/2004. Lucas Fernández Pérez. 
--	Este procedimiento se llama desde la impresión de relaciones de notificaciones de apremio desde DELPHI
--  El proceso de notificacion es el siguiente:
--   1º se crean las cartas de pago cuando se crea la relacion de apremio.
--   2º se llama a este procedimiento para rellenar las tablas temporales e imprimir las cartas de pago.

-- Entre el paso 1 y el paso 2 puede pasar tiempo. Y los importes pueden cambiar. Cuando se ingrese la carta de pago,
--	se reajusta el recargo,costas y demora a la que había en el momento de crear la carta de pago (paso 1). 
-- Pero ese momento no es el momento de la impresión (paso 2), por lo que tenemos que asegurarnos de que el recargo,
--  las costas y la demora no varían entre los pasos 1 y 2. La demora se reajusta a la fecha del paso 1, mientras 
--  que se hace necesario comprobar que el recargo y las costas no han variado.También hay que comprobar que ningún
--	recibo de la carta de pago se haya ingresado, anulado o suspendido.

-- Por esto se comprueba que el recargo/costas no hayan aumentado o disminuido, que el importe pendiente
--  de recargo/costas no haya variado entre el paso 1 y el paso 2, y que ningún recibo se haya ingresado o anulado
--	o suspendido. Si hay algun cambio, no se imprime la carta de pago y se guarda en la tabla TMP_INFORME_EXPE el error.
--  Tambien se comprueba que el valor no esté en un expediente con diligencia de embargo, en cuyo caso antes 
--	abortaba el proceso, y ahora simplemente no imprime esa carta de pago y la anota como incidencia.
--
-- Modificado: 08/09/2004. Agustín León Robles.
-- Puede ocurrir que cuando se emita la carta de pago en banco algunos conceptos vayan con 
-- la misma emisora que la de voluntaria.
-- Por ejemplo en Catoure tienen varios municipios que para el concepto de Basura quieren que
-- vaya a la emisora de la Mancomunidad, pero para el resto de conceptos vaya a la del ayuntamiento
--
-- Modificado: 15/04/2005. Agustín León Robles.
-- Se quita el trozo de codigo buscar en la tabla de rela_apli_bancos, ya que en catoure se han pasado los conceptos de la 
-- mancomunidad a otro codigo de municipio
-- *********************************************************************************************************
CREATE OR REPLACE PROCEDURE NotifiGeneraCartasPago
		(xRelacion 		IN CHAR,
		 xCodPostal		IN CHAR,
		 xNIFConsulta	IN CHAR)
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
xInteres 		FLOAT default 0;
xRecargo		float default 0;
xCostas			float default 0;
xRecargoIngre	float default 0;
xCostasIngre	float default 0;
xIdCartaPago 	float;
xNIF			char(10);
xFecha			date default null;
xDiaSemana 		varchar2(15);
xFDili			date;
xCuantos		integer;
varPublicoPrivado 	VARCHAR(1);
xAyto			char(3);
xIDExpe			integer;
xExpediente		char(10);
xCodigoSalida   char(1);
xContinuar		boolean;
xFIngreso		date;
xFBaja			date;
xFSuspension	date;
xConcepto		char(6);


TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
vCURSOR    	 	tCURSOR;     -- declare cursor variable
vSENTENCIA		VARCHAR2(2000);


--relacion de valores de una carta de pago
CURSOR cCartasPagoNoti IS 
	SELECT R.VALOR,R.RECARGO,R.COSTAS,R.RECARGOVALOR,R.COSTASVALOR,V.NIF,V.EXPEDIENTE,C.NOMBRE,V.AYTO,V.PADRON
		FROM RECIBOSCARTAPAGOBANCO R, VALORES V, CONTRIBUYENTES C
		WHERE R.VALOR=V.ID AND V.NIF=C.NIF AND R.cartapagobanco=xIdCartaPago
		for update of R.DEMORA;

CURSOR cValoresRelacion is
		select v.id,v.expediente,v.Ayto FROM RECIBOSCARTAPAGOBANCO R, VALORES V
		WHERE R.VALOR=V.ID AND R.N_RELACION=xRelacion;

BEGIN
    
    -- Primero borra todos los datos de las tablas temporales que va a rellenar.
    DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID;
    DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
    DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;
    
	-- Tabla que almacenará posibles incidencias de la impresión.
	DELETE FROM TMP_INFORME_EXPE WHERE USUARIO=UID;

    IF xNIFConsulta is null THEN -- Si no hay NIF indicado, se hace de toda la relación 
	
	  if xCodPostal='T' then
	
		vSENTENCIA:='select cartapagobanco FROM RECIBOSCARTAPAGOBANCO WHERE '||
   				'N_RELACION=:xRelacion group by cartapagobanco';
   				
	  elsif xCodPostal='I' then
	
		vSENTENCIA:='select cartapagobanco FROM RECIBOSCARTAPAGOBANCO R, VALORES V, '||
   				' CONTRIBUYENTES C WHERE R.VALOR=V.ID AND V.NIF=C.NIF AND C.CODIGO_POSTAL'||
   				' IN (SELECT CODIGO_POSTAL FROM TMP_CODIGOSPOSTALES WHERE USUARIO=USER)'||
   				' AND R.N_RELACION=:xRelacion group by cartapagobanco';
   				
	  else -- xCodPostal='E'

		vSENTENCIA:='select cartapagobanco FROM RECIBOSCARTAPAGOBANCO R, VALORES V, '||
   				' CONTRIBUYENTES C WHERE R.VALOR=V.ID AND V.NIF=C.NIF AND C.CODIGO_POSTAL'||
   				' NOT IN (SELECT CODIGO_POSTAL FROM TMP_CODIGOSPOSTALES WHERE USUARIO=USER)'||
   				' AND R.N_RELACION=:xRelacion group by cartapagobanco';
   				
	  end if;
	
    ELSE -- xNIFConsulta <> null , solo rellena datos del nif indicado.
    
	  vSENTENCIA:='select cartapagobanco FROM RECIBOSCARTAPAGOBANCO R, VALORES V '||
  				' WHERE R.VALOR=V.ID AND V.NIF='''||xNIFConsulta||''''||
   				' AND R.N_RELACION=:xRelacion group by cartapagobanco';
    
    END IF; 				
  
   --Asignar consulta a cursor, abrirlo y recorrerlo
    OPEN vCURSOR FOR vSENTENCIA USING xRelacion;
    LOOP
   	    FETCH vCURSOR INTO xIDCartaPago;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

		--para el calculo de intereses a la fecha de emision de la cartas de pago
		--solo se hace la primera vez ya que todas las cartas de pago de la misma
		--relacion de apremio tiene la misma fecha de emision
		if xFecha is null then
			select f_creacion into xFecha from cartapagobanco where id=xIdCartaPago;
		end if;

		xContinuar:=True;

		for vNoti in cCartasPagoNoti loop

		  IF xContinuar=TRUE THEN -- Si una carta de pago tiene varios recibos, con uno que esté mal, ya no se evalua el resto
		  	
		  	xExpediente:=NULL;
		  	
		  	if vNoti.Expediente is not null then -- El recibo tiene expediente
		
				select fecha_diligencia, expediente into xFDili, xExpediente from expedientes where id=vNoti.Expediente;
			
				if xFDili is not null then -- Si el expediente tiene fecha de diligencia, salimos.
					xCodigoSalida:='8'; 
					xContinuar:=False;
				end if;
			
	  		end if;
	  		
	  		IF xContinuar=True THEN

				--se recoge el código de municipio para luego coger los datos de la emisora en funcion del municipio
				--esto solo servirá para la gestion de empresas privadas, ya que solo podran seleccionar recibos 
				--de un unico municipio, este control se hace desde Delphi
	  			xAyto:=vNoti.AYTO;
	  			xConcepto:=vNoti.PADRON;
	   

  				-- Calculamos los intereses de demora a la fecha de emision de la carta de pago, grabandolos en VALORES. 
				-- Devuelve también el recargo y costas que tiene el valor, y si está ingresado, anulado o suspendido.
				InteresProvidencia(vNoti.Valor,xFecha,xInteres,xRecargo,xCostas,xFIngreso,xFBaja,xFSuspension);
			
				IF xFIngreso IS NOT NULL THEN -- Comprobacion "1": El valor está ingresado
					xCodigoSalida:='1'; 
					xContinuar:=False;
		
				ELSIF xFBaja IS NOT NULL THEN -- Comprobacion "2": El valor está anulado
					xCodigoSalida:='2'; 
					xContinuar:=False;
		
				ELSIF xFSuspension IS NOT NULL THEN -- Comprobacion "3": El valor está suspendido
					xCodigoSalida:='3'; 
					xContinuar:=False;
			
				ELSE -- El recibo no está ingresado ni anulado ni suspendido. Se mira que los importes no hayan cambiado.

					-- xRecargo/xCostas tiene el recargo/costas del valor. xRecargoIngre/xCostasIngre las ingresadas. 
					-- De ahí saco el importe pendiente de recargo/costas. Si no coincide con los campos recargo/costas 
					-- de reciboscartapagobanco, anota la incidencia y termina el procedimiento.
					-- Del mismo modo, si el campo xRecargo/xCostas del valor no coincide con los campos 
					-- recargovalor/costasvalor de reciboscartapagobanco, anota la incidencia y termina el procedimiento.
					SELECT SUM(RECARGO),SUM(COSTAS),COUNT(*) into xRecargoIngre, xCostasIngre, xCuantos 
					FROM INGRESOS WHERE VALOR=vNoti.Valor;
		
					IF xCuantos=0 THEN
						xRecargoIngre:=0;
						xCostasIngre:=0;
					END IF;
		
					-- Comprobacion "4": El recargo del valor debe ser el mismo ahora que cuando se creo la c.pago
					IF xRecargo<>vNoti.RECARGOVALOR THEN 
						xCodigoSalida:='4'; 
						xContinuar:=False;
					-- Comprob."5": El recargo pendiente del valor debe ser el mismo ahora que cuando se creo la c.pago
					ELSIF (xRecargo-xRecargoIngre)<>vNoti.RECARGO THEN 
						xCodigoSalida:='5'; 
						xContinuar:=False;
					-- Comprob."6": Las costas del valor deben ser las mismas ahora que cuando se creo la carta de pago
					ELSIF xCostas<>vNoti.COSTASVALOR THEN 
						xCodigoSalida:='6'; 
						xContinuar:=False;
					-- Comprob."7": Las costas pendientes deben ser las mismas ahora que cuando se creo la carta de pago
					ELSIF (xCostas-xCostasIngre)<>vNoti.COSTAS THEN 
						xCodigoSalida:='7'; 
						xContinuar:=False;
					END IF;
					
				END IF; -- else -> valor sin ingresar ni anular ni suspender
				
				IF xContinuar=True THEN 
			
					--insertamos en TMPDEUDASVIVAS y en TmpEntregasValor
					NotifiRellenaCartasPago(xIdCartaPago,vNoti.Valor, xNIF);

    				--se graba el importe de la demora en este momento, porque cuando se generan las cartas de pago 
	    			-- se graba el principal/recargo/costas pendientes, pero no se calcula la demora pendiente.
					update RECIBOSCARTAPAGOBANCO set demora=round(xInteres,2)
					where current of cCartasPagoNoti;
			
				END IF;
			
			END IF; --If xContinuar=true por no tener diligencia de embargo
			
			IF xContinuar=False THEN 
				-- Algo ha cambiado entre que se generó la carta de pago y que se imprime ahora.
				insert into TMP_INFORME_EXPE(USUARIO,ID,RECIBOS,EXPEDIENTE,DEUDOR,NOMBRE,F_APERTURA,EMBARGO,PENDIENTE) 
				VALUES 
				(UID,vNoti.Valor,vNoti.Expediente,xExpediente,vNoti.NIF,vNoti.NOMBRE,sysdate,xCodigoSalida,xIDCartaPago);
				
				-- Si una carta de pago tiene varios recibos, al fallar uno hay que borrar el resto de las tablas temporales.	
				DELETE FROM TMPENTREGASVALOR WHERE USUARIO=UID AND XID IN 
					(SELECT XID FROM TMPDEUDASVIVAS WHERE USUARIO=UID AND IDCARTAPAGOBANCO=xIdCartaPago);
				
				DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID AND IDCARTAPAGOBANCO=xIdCartaPago;
				
			END IF;
			
		  END IF; -- if xContinuar=TRUE Si una carta de pago tiene varios recibos, con uno malo, ya no se mira el resto
				
		end loop;

		IF xContinuar=True THEN 
			--insertamos los datos postales de la carta de pago
			PkwtDocIngreso.wtDatosPostalesDeudor(xNIF, 0, 'N');


			--se accede a la tabla de configuracion para recoger los datos de la emisora,
			--sufijo y dias de vencimiento para pagar en el BANCO POR CORREO
		
			--Tambien se recoge el tipo de empresa que tiene la gestion de la recaudacion:
			--Ayuntamientos pequeños (A).
			--Ayuntamientos grandes (G): pueden tener mas de un alcalde por distrito, tesorero, etc.
			--Entidades SupraMunicipales (S): Mancomunidades y Diputaciones.
			--Comunidades Autonomas o Administración Central (C).
			--Modo de funcionamiento ASP X
			select EMISORA,SUFIJO,DIAS_ASUSTA,REMESA_MOD1,TIPO_ENTIDAD into xEmisora,xSufijo,xDias,xRemesa,varPublicoPrivado
			from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

		
			--Si es una empresa privada se los datos se toman en funcion del municipio de los recibos
			--Solo podran seleccionar recibos de un unico municipio, este control se hace desde Delphi	
			if varPublicoPrivado='X' then
					
				select EMISORA,SUFIJO,DIAS_ASUSTA into xEmisora,xSufijo,xDias
				from configuracion WHERE ZONA=(SELECT ZONA FROM MUNICIPIOS WHERE AYTO=xAyto);		
				
	
			end if;
		
		
			--averiguamos el importe de la carta de pago porque interviene en el
			--calculo del digito de control

			--Como son cartas masivas hay que sumar los valores pero que corresponde a una
			--carta de pago, no se puede hacer por NIF porque puede que un contribuyente
			--al tener 2 notificaciones tiene 2 cartas de pago.
	
			select sum(PRINCIPAL+RECARGO20+COSTAS+DEMORA-ENTREGAS_A_CUENTA+DEMORA_PENDIENTE)
			into xImpor from TmpDeudasVivas
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
			
		END IF; -- if xContinuar=true

	end loop;
	
	CLOSE vCURSOR;

END;
/



--
-- Pone la fecha de envio al BOP, en caso de no tener una tupla en la tabla
-- de notificaciones se la inserta
--
-- 16/06/2002 Antonio Pérez Caballero
--
-- Modificado: 29-10-2002. Lucas Fernández Pérez. Se filtran los accesos a la tabla de
--		Notificaciones para que no entren en el calculo las notificaciones en voluntaria.
--
-- Modificado: 05/04/2004. Agustín León Robles. Se graba el numero de orden
CREATE OR REPLACE PROCEDURE BOP_SetFechaEnvio(
	xIDValor 	IN INTEGER,
	xNIF	    	IN Char,
	xNuRela	IN Char,
	xFechaEnvio	IN DATE)
AS
BEGIN

	UPDATE NOTIFICACIONES SET N_RELACION=xNuRela,F_ENVIO_BOP=xFechaEnvio,
			N_ORDEN=TO_NUMBER(SUBSTR(N_RELACION,1,4)||SUBSTR(N_RELACION,8,3)||to_char(N_ORDEN))
	Where Valor=xIDValor AND TIPO_NOTI<>'VOL';

	IF SQL%NOTFOUND THEN
   	INSERT INTO NOTIFICACIONES
			(VALOR,N_ENVIOS,TIPO_NOTI,NIF,N_RELACION,F_ENVIO_BOP,N_ORDEN)
		VALUES
			(xIDValor,1,'000',xNIF,xNuRela,xFechaEnvio,xIDValor);
	END IF;

END;
/

--
-- Poder mandar a publicar los valores de todo un año que no estén notificados
-- Todos los valores de un cargo o conjunto de cargos
-- Todos los valores de una fecha de cargo hasta otra fecha de cargo
-- Esta opción está indicada para aquellas recaudaciones que tienen un cierto atraso.
--
-- Controla el tipo de organización si es una privada 'X' tiene que ser ayto a ayto
-- no se pueden agrupar todas las de un deudor, hay que señirse al ámbito de actuación
--
-- 16/06/2002 Antonio Pérez Caballero.
--
-- Modificado: 05/04/2004. Agustín León Robles. Se pone en todos los cursores la condicion Vol_Eje='E'.
-- Modificado: 19/04/2004. Agustín León Robles. Sólo se publicaran los valores que esten desconocidos o ausentes.
-- Modificado: 22/06/2004. Mª del Carmen Junco Gómez. No han de entrar en la publicación los propuestos de baja.
-- Modificado: 06/09/2004. Lucas Fernandez Pérez.Nuevo parámetro xIncluirPropuBaja que indica si se quieren publicar
--  							los propuestos de baja o no.
-- Modificado: 06/09/2004. Agustín León Robles. Si xModo es igual a 3 no se modificaba el Orden_Apremio en valores.
CREATE OR REPLACE PROCEDURE BOP_PublicarEspecial
	(xAYTO	IN 	Char,
	xYear		IN	CHAR,
	xFechaDesde IN    DATE,
	xFechaHasta IN	DATE,
    xFechaEnvio IN 	DATE,
    xIncluirPropuBaja IN CHAR,
	xMODO		IN 	Char)
AS

xNUMERO 		CHAR(10);
xCuantosRecibos 	INTEGER;
xZONA 		CHAR(2);
varPublicoPrivado CHAR(1);

-- Todos los valores no notificados de un CARGO o conjunto de cargos xMODO='3'

CURSOR NoNotificadoAytoByCargo IS
	SELECT ID,NIF FROM VALORES
	WHERE AYTO=xAYTO
		AND N_CARGO IN (SELECT CARGO FROM TMP_LISTACARGOS WHERE SESIONID=GETSID())
		AND VOL_EJE='E'
		AND NOTIFICADO='N'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
		and ENTREGAS_ANTESDEL_CARGO <= Principal
		AND ID IN (SELECT VALOR FROM NOTIFICACIONES WHERE SUBSTR(LAST_ACUSE,1,2) IN ('03','04') 
		and f_envio_bop is null and f_publicacion is null)
	FOR UPDATE OF RELACION_APREMIO;

-- Todos los valores no notificados de un AÑO xMODO='1'

CURSOR NoNotificadoAytoByYear IS
	SELECT ID,NIF FROM VALORES
	WHERE AYTO=xAYTO
		AND Year=xYear
		AND VOL_EJE='E'
		AND NOTIFICADO='N'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
		and ENTREGAS_ANTESDEL_CARGO <= Principal
		AND ID IN (SELECT VALOR FROM NOTIFICACIONES WHERE SUBSTR(LAST_ACUSE,1,2) IN ('03','04') 
		and f_envio_bop is null and f_publicacion is null)
	FOR UPDATE OF RELACION_APREMIO;

-- Todos los valores no notificados de un Fecha de cargo hasta otra xMODO='2'

CURSOR NoNotificadoAytoByCargoBetween IS
	SELECT ID,NIF FROM VALORES
	WHERE AYTO=xAYTO
		AND NOTIFICADO='N'
		AND VOL_EJE='E'
		AND F_CARGO BETWEEN xFechaDesde AND xFechaHasta
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
		and ENTREGAS_ANTESDEL_CARGO <= Principal
		AND ID IN (SELECT VALOR FROM NOTIFICACIONES WHERE SUBSTR(LAST_ACUSE,1,2) IN ('03','04') 
		and f_envio_bop is null and f_publicacion is null)
	FOR UPDATE OF RELACION_APREMIO;

-- Todos los valores no notificados de un AÑO xMODO='1'

CURSOR NoNotificadoByYear IS
	SELECT ID,NIF FROM VALORES
	WHERE Year=xYear
		AND NOTIFICADO='N'
		AND VOL_EJE='E'
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
		and ENTREGAS_ANTESDEL_CARGO <= Principal
		AND ID IN (SELECT VALOR FROM NOTIFICACIONES WHERE SUBSTR(LAST_ACUSE,1,2) IN ('03','04') 
		and f_envio_bop is null and f_publicacion is null)
	FOR UPDATE OF RELACION_APREMIO;

-- Todos los valores no notificados de un Fecha de cargo hasta otra xMODO='2'

CURSOR NoNotificadoByCargoBetween IS
	SELECT ID,NIF FROM VALORES
	WHERE NOTIFICADO='N'
		AND VOL_EJE='E'
		AND F_CARGO BETWEEN xFechaDesde AND xFechaHasta
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND (
			(xIncluirPropuBaja='N' AND FECHA_PROPUESTA_BAJA IS NULL)
			or 
			(xIncluirPropuBaja='S')
		)
		and ENTREGAS_ANTESDEL_CARGO <= Principal
		AND ID IN (SELECT VALOR FROM NOTIFICACIONES WHERE SUBSTR(LAST_ACUSE,1,2) IN ('03','04') 
		and f_envio_bop is null and f_publicacion is null)
	FOR UPDATE OF RELACION_APREMIO;


BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   SELECT TIPO_ENTIDAD into varPublicoPrivado FROM CONFIGURACION WHERE ZONA=xZONA;

   DAME_RELACION(xNUMERO);

-- Insertar la relación

   INSERT INTO RELACIONES_NOTI
   	(RELACION, FECHA, TIPO_NOTI, USUARIO, ZONA)
   VALUES
	(xNUMERO, Trunc(xFECHAENVIO,'DD'), 'P', USER, xZONA);

xCuantosRecibos:=0;

-- Por cargos siempre es en función del ayuntamiento

IF xMODO='3' THEN


   SELECT COUNT(*) INTO xCuantosRecibos FROM TMP_LISTACARGOS
		WHERE SESIONID=GETSID();

-- Si no se elige cargo alguno nos salimos

   IF xCuantosRecibos = 0 THEN
      RETURN;
   END IF;

   xCuantosRecibos:=0;

   FOR v_NoNotificado IN NoNotificadoAytoByCargo LOOP

		UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
						ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
		WHERE CURRENT OF NoNotificadoAytoByCargo;

		BOP_SetFechaEnvio(v_NoNotificado.ID, v_NoNotificado.NIF, xNUMERO, Trunc(xFECHAENVIO,'DD'));

		xCuantosRecibos:=xCuantosRecibos+1;

   END LOOP;

END IF;

-- Todo lo pendiente de notificar de un año en función de un ayuntamiento

IF xMODO='1' AND varPublicoPrivado='X' THEN

   FOR v_NoNotificado IN NoNotificadoAytoByYear LOOP

	UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
				ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
		WHERE CURRENT OF NoNotificadoAytoByYear;

	BOP_SetFechaEnvio(v_NoNotificado.ID, v_NoNotificado.NIF, xNUMERO, Trunc(xFECHAENVIO,'DD'));

	xCuantosRecibos:=xCuantosRecibos+1;

   END LOOP;

END IF;

-- Todo lo pendiente de notificar de una fecha de cargo hasta otra por ayuntamiento

IF xMODO='2' AND varPublicoPrivado='X' THEN

   FOR v_NoNotificado IN NoNotificadoAytoByCargoBetween LOOP

	UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
				ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
		WHERE CURRENT OF NoNotificadoAytoByCargoBetween;

	BOP_SetFechaEnvio(v_NoNotificado.ID, v_NoNotificado.NIF, xNUMERO, Trunc(xFECHAENVIO,'DD'));

	xCuantosRecibos:=xCuantosRecibos+1;

   END LOOP;

END IF;


IF xMODO='1' AND varPublicoPrivado<>'X' THEN

   FOR v_NoNotificado IN NoNotificadoByYear LOOP

	UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
				ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
	WHERE CURRENT OF NoNotificadoByYear;

	BOP_SetFechaEnvio(v_NoNotificado.ID, v_NoNotificado.NIF, xNUMERO, Trunc(xFECHAENVIO,'DD'));

	xCuantosRecibos:=xCuantosRecibos+1;

   END LOOP;

END IF;


IF xMODO='2' AND varPublicoPrivado<>'X' THEN

   FOR v_NoNotificado IN NoNotificadoByCargoBetween LOOP

	UPDATE VALORES SET RELACION_APREMIO=xNUMERO,
				ORDEN_APREMIO=TO_NUMBER(SUBSTR(RELACION_APREMIO,1,4)||
       	  				SUBSTR(RELACION_APREMIO,8,3)||to_char(ORDEN_APREMIO))
	WHERE CURRENT OF NoNotificadoByCargoBetween;

	BOP_SetFechaEnvio(v_NoNotificado.ID, v_NoNotificado.NIF, xNUMERO, Trunc(xFECHAENVIO,'DD'));

	xCuantosRecibos:=xCuantosRecibos+1;

   END LOOP;

END IF;

if xCuantosRecibos=0 then

-- Si no se ha habido datos borrar la relación
   Delete from RELACIONES_NOTI WHERE RELACION=xNUMERO;

else

-- Indicar el número de tuplas afectadas
   UPDATE RELACIONES_NOTI SET RECIBOS=xCuantosRecibos
   	WHERE RELACION=xNUMERO;

end if;

END;
/

--
-- 10 Septiembre 2002 Antonio Pérez Caballero
-- Poder anular una notificación de una relación de correos.
-- Existe la posibilidad de que cuando las bases de datos estan inicialmente muy mal
-- los DNI's. Podría darse el caso de que existan multiples deudores con un mismo DNI
-- cuando se saquen las notificaciones se den cuenta de este hecho y que manualmente se
-- actualicen los deudores. En esta situación hay que anular la notificación de la relación
-- para acontinuación emitir dos o más notificaciones a cada uno deudores reales.
--
-- 17 Septiembre 2002. Agustín León Robles
--		No actualizaba las costas en la tabla de valores, una vez que se borraba de costas
-- Modificado: 09/01/2004. Lucas Fernández Pérez.
-- 		Protección previa al borrado. Se añade el nuevo parámetro xError:
--		 	xError=0 -> Se borra la notificación.
-- 			xError=1 -> La notificación no se borra porque alguno de los recibos tienen 
--					 parte de las costas de la notificación ingresadas.
-- 		Para llamar a este procedimiento, delphi filtra que la notificación este sin acuse,
--			por lo que la única posibilidad de que tenga costas el valor es 
--			que se pusieran por adelantado.Siempre son notificaciones a valores sin publicar.
--DELPHI		
CREATE OR REPLACE PROCEDURE NotificaDel(
	      xRela   IN CHAR,
	      xNumero IN INTEGER,
	      xError  OUT CHAR)
AS

xCOSTAS				FLOAT DEFAULT 0;
xCuantos 			INTEGER;
xCostasIngre 		FLOAT;
xCostasPendientes 	FLOAT;
xCostasNoti			FLOAT;


CURSOR cValores IS SELECT ID,COSTAS FROM VALORES WHERE RELACION_APREMIO=xRela
			AND ORDEN_APREMIO=xNumero
			AND F_NOTIFICACION IS NULL
	FOR UPDATE OF RELACION_APREMIO,ORDEN_APREMIO,COSTAS;
BEGIN

    xError:=0;
    
	FOR vValo in cValores LOOP
	
	  -- Costas ingresadas del valor
  	  SELECT COUNT(*), SUM(COSTAS) INTO xCuantos,xCostasIngre 
  	   FROM INGRESOS WHERE VALOR=vValo.ID;
      if xCuantos=0 then
  	    xCostasIngre:=0;
      end if;

  	  -- Costas del valor - costas ingresadas = Costas pendientes del valor
      xCostasPendientes:=vValo.Costas-xCostasIngre; 

  	  -- Costas del valor correspondientes a la notificacion
      SELECT COUNT(*),SUM(IMPORTE) INTO xCuantos, xCostasNoti FROM COSTAS_VALORES 
      WHERE ID in (select ID_COSTAS from notificaciones
      				where valor=vValo.ID and N_RELACION=xRela and N_ORDEN=xNumero);
  	  if xCuantos=0 then
  	     xCostasNoti:=0;
  	  end if;
  
  	  -- si el pendiente de costas del valor es menor que las costas asociadas a la 
  	  -- notificación es porque parte de estas costas del valor ya se han ingresado. 
  	  -- No borro esas costas, y no se permite el borrado de la notificación
  	  if xCostasNoti>xCostasPendientes then
  	    xError:=1;
  	    RETURN;
      end if;

    END LOOP;
    
  	-- Borrar las costas
	Delete from costas_valores where ID in 
		(select ID_COSTAS from notificaciones where N_RELACION=xRela and N_ORDEN=xNumero);

	-- Borrar las notificaciones de apremio
   	Delete from notificaciones where N_RELACION=xRela and N_ORDEN=xNumero;

	FOR vValores in cValores LOOP

		SELECT SUM(IMPORTE) INTO xCOSTAS FROM COSTAS_VALORES WHERE VALOR=vValores.ID;

		if xCostas is null then
			xCostas:=0;
		end if;

		UPDATE VALORES SET RELACION_APREMIO=Null,ORDEN_APREMIO=Null,costas=xCostas
			where current of cValores;

	END LOOP;

END;
/

-- ***************************************************************************************************************
-- 		  	 		
-- 04/06/2004. Lucas Fernández Pérez.
-- Generación de providencia de embargo a los valores. 
-- Graba la fecha de providencia de embargo a los valores de un ayto con acuse positivo anteriores a una fecha.
-- 		  	 		
-- Modificado: 08 Junio 2004. Agustín León Robles
--		Se les pone más condiciones para hacer los update 
-- Modificado: 28 Junio 2004. Agustín León Robles.
--		Se cambia en vez de 10 días para la publicación se pone a 15 días. Nueva Ley General Tributaria 58/2003
CREATE OR REPLACE PROCEDURE GenProviEmbargo(
									xAYTO IN CHAR, 
									xFechaHasta IN DATE,
									xFechaProvi IN DATE)
AS
BEGIN

	-- Pone fecha de providencia de embargo a los valores del ayto que no tienen ya fecha de providencia anterior
	--  y que estan notificados positivamente con fecha anterior a xFecha o a (xFecha-10 dias si estan publicados)
	UPDATE VALORES V SET F_PROVI_EMBARGO=TRUNC(xFechaProvi,'DD')
	WHERE AYTO=xAYTO AND VOL_EJE='E' 
			AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL AND FECHA_PROPUESTA_BAJA IS NULL
			AND F_PROVI_EMBARGO IS NULL
			AND ID IN 
			(
		  		SELECT N.VALOR FROM NOTIFICACIONES N WHERE VALOR=V.ID AND TIPO_NOTI='000' AND NOTIFICADO='S' 
				AND F_NOTIFICACION<= DECODE(F_PUBLICACION,NULL,xFechaHasta,xFechaHasta-15)
			);

END;
/

/****************************************************************************************/
COMMIT;
/********************************************************************/
