
/********************************************************************/
CREATE OR REPLACE TRIGGER T_INS_LIQUIDACIONESR
BEFORE INSERT ON LIQUIDACIONESR
FOR EACH ROW

BEGIN

   SELECT GENERLIQUIDR.NEXTVAL INTO :NEW.ID FROM DUAL;

END;
/



-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fern�ndez P�rez
-- No se han realizado cambios.
-- -----------------------------------------------------
/*----------------------------------------------------------------*/
/* Creaci�n: Enero - 2.001  AUTOR: Lucas Fern�ndez P�rez		*/
/* �ltima Modificaci�n: 10-10-2001  Lucas Fern�ndez P�rez		*/
/*----------------------------------------------------------------*/
/* 	Envio de LIQUIDACIONES a la Cola de Trabajos 			*/
/* ---------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE SubmitCreaLiquidacion(
	xFechaCreacion	IN Date,
	xFechaInicio 	IN LIQUIDACIONESR.FECHA_INICIO%TYPE,
	xFechaFin		IN LIQUIDACIONESR.FECHA_FIN%TYPE,
	xAyuntamiento  	IN LIQUIDACIONESR.AYTO%TYPE)

AS
	xTrabajo BINARY_INTEGER;

BEGIN

	DBMS_JOB.submit(xTrabajo,'CreaLiquidacion(1);',
				xFechaCreacion, Null, False);

	INSERT INTO TRABAJOS_USUARIOS
		 (N_TRABAJO, TRABAJO, USUARIO, F_INICIO,
			PARAM_DATE1, PARAM_DATE2, PARAM_CHAR1, CICLICO)
	VALUES (xTrabajo,'CreaLiquidacion(1);', USER, xFechaCreacion,
			 xFechaInicio, xFechaFin, xAyuntamiento, 'NULL');


END;
/


--
-- Antonio P�rez Caballero
-- 17/12/2002
--
-- Rellena los datos de resumen de cabecera de la liquidaci�n a partir
-- de los resumenes de los conceptos
--
CREATE OR REPLACE PROCEDURE LiquiSetCabecera(xFecha IN Date, xIDLiq IN INTEGER)
as

cursor cLiqui is Select ayto,sum(Ingresos) as SumIngresos,
	sum(Premio) as SumPremio ,sum(Dto) as SumDto, sum(RECARGO_OE) as SumROE
	from LIQUIDR_CTO_RESUMEN
	where IDLIQ=xIDLiq
	AND fecha=xFecha
	group by ayto;

begin


for v_cLiqui In cLiqui Loop

	Update LIQUIDACIONESR Set ingresos=v_cLiqui.SumIngresos,
			premio=v_cLiqui.SumPremio,dto=v_cLiqui.SumDto,
			RECARGO_OE=v_cLiqui.SumROE
		   where ID=xIDLiq
		   AND fecha=xFecha;

end loop;

end;
/

/*------------------------------------------------------------------*/
/* Creaci�n: Enero - 2.001  AUTOR: Lucas Fern�ndez P�rez			*/
/* Modificaci�n: 10-10-2001  Lucas Fern�ndez P�rez					*/
/* �ltima Modificaci�n: 16-10-2001  Adaptaci�n al Euro. Lucas F.P.	*/
/*------------------------------------------------------------------*/
/*		LIQUIDACION PARA UN MUNICIPIO							 	*/
/* -----------------------------------------------------------------*/
/* Para el calculo de los valores se tienen en cuenta		 		*/
/*	los ingresos/bajas no liquidados pero s� datados				*/
/*	que se encuentren entre las fechas de la liquidaci�n	 		*/
/* Se buscar� en MUNICIPIOS el porcentaje de comisi�n a aplicar 	*/
/*	para cada tipo de ingreso/baja				 					*/
/* S�lo es llamado desde el procedimiento CREALIQUIDACI�N			*/
/* -----------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE LiquidaUnAyto(
	xFechaInicio 	IN LIQUIDACIONESR.FECHA_INICIO%TYPE,
	xFechaFin		IN LIQUIDACIONESR.FECHA_FIN%TYPE,
	xAyuntamiento  	IN LIQUIDACIONESR.AYTO%TYPE)

AS

xID					LIQUIDACIONESR.ID%TYPE;
xN_Ingre	 		integer default 0;
xN_Bajas 			integer default 0;
xFInicio			date;
xFFin				date;

begin


xFInicio:=Trunc(xFechaInicio,'DD');
xFFin:=Trunc(xFechaFin,'DD');
-- -------------------------------------------
--  INGRESOS

	SELECT COUNT(*) INTO xN_Ingre FROM INGRESOS
	WHERE AYTO=xAyuntamiento
		AND LIQUIDACION IS NULL
		AND Trunc(FECHA,'DD') BETWEEN xFInicio AND xFFin
		AND NUMERO_DE_DATA IS NOT NULL;

-- -------------------------------------------
--  BAJAS

	SELECT COUNT(*) INTO xN_Bajas FROM BAJAS
	WHERE AYTO=xAyuntamiento
		AND LIQUIDACION IS NULL
		AND Trunc(FECHA,'DD') BETWEEN xFInicio AND xFFin
		AND NUMERO_DE_DATA IS NOT NULL;

-- -------------------------------------------------------------------------------
	-- Solamente si hay alg�n ingreso o baja en la liquidaci�n, creo la liquidaci�n

	IF ((xN_Ingre+xN_Bajas)>0) THEN

	  INSERT INTO LIQUIDACIONESR (AYTO, FECHA_INICIO, FECHA_FIN)
	  VALUES ( xAyuntamiento, xFInicio, xFFin)
	  RETURN ID INTO xID;

	END IF;

-- MODIFICACION DE LAS TABLAS DE INGRESOS Y DE BAJAS

-- Se pone en el campo 'liquidacion' de los ingresos liquidados el n�mero de liquidaci�n

	IF xN_Ingre>0 THEN -- Si hay ingresos en la liquidacion

	  UPDATE INGRESOS SET LIQUIDACION=xID,F_LIQUIDACION=SYSDATE
	  WHERE AYTO=xAyuntamiento
		AND LIQUIDACION IS NULL
		AND Trunc(FECHA,'DD') BETWEEN xFInicio AND xFFin
		AND NUMERO_DE_DATA IS NOT NULL;

	END IF;

-- Se pone en el campo 'liquidacion' de las bajas liquidadas el n�mero de liquidaci�n

	IF xN_Bajas>0 THEN -- Si hay bajas en la liquidaci�n

	  UPDATE BAJAS SET LIQUIDACION=xID,F_LIQUIDACION=SYSDATE
	  WHERE AYTO=xAyuntamiento
		AND LIQUIDACION IS NULL
		AND Trunc(FECHA,'DD') BETWEEN xFInicio AND xFFin
		AND NUMERO_DE_DATA IS NOT NULL;

	END IF;

	IF ((xN_Ingre+xN_Bajas)>0) THEN

	  -- Desglosar la liquidaci�n segun concepto, a�o y periodo.
	  -- Adem�s se usa para poder gestionar los anticipos
	  PkLiquiROE.xIDLiqui:=xID;
	  PkLiquiROE.MAIN;

	  -- Actualizar los anticipos y descuentos con los nuevos ingresos liquidados
	  -- El anticipo se calcular� desde la �ltima fecha calculada hasta la fecha de fin de
	  --	esta liquidaci�n
	  --PkLiquiROE.ActualizarAnticipos(xID, xFechaFin);

	  -- funci�n sobrecargada para la diputaci�n de Granada a�o 2002
	  PkLiquiROE.ActualizarAnticipos(to_char(xFechaInicio,'yyyy'), xAyuntamiento, xID);

	  -- Rellena la cabecera de la liquidaci�n, con los totales de la liquidaci�n
	  -- partiendo del resumen de conceptos
	  LiquiSetCabecera(TRUNC(SYSDATE,'DD'), xID);

	END IF;

END;
/

/*----------------------------------------------------------------*/
/* Creaci�n: Enero - 2.001  AUTOR: Lucas Fern�ndez P�rez		*/
/* �ltima Modificaci�n: 10-10-2001  Lucas Fern�ndez P�rez		*/
/*----------------------------------------------------------------*/
/*		GENERACI�N DE LIQUIDACIONES A MUNICIPIOS		 	*/
/*----------------------------------------------------------------*/
/* Genera una liquidaci�n sobre un periodo de tiempo para un 	*/
/* municipio concreto o para todos (si el valor xAyuntamiento=-1)	*/
/* S�lo es lanzado por la B.D. , es un trabajo de la B.D. 		*/
/* Este trabajo lo mete en la B.D. el proc. SubmitCreaLiquidacion */
/*----------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE CreaLiquidacion
(xNada IN Int)

AS
	xFechaInicio 	LIQUIDACIONESR.FECHA_INICIO%TYPE;
	xFechaFin		LIQUIDACIONESR.FECHA_FIN%TYPE;
	xAyuntamiento  	LIQUIDACIONESR.AYTO%TYPE;
	xN_Trabajo		TRABAJOS_USUARIOS.N_TRABAJO%TYPE;
	xCiclico		TRABAJOS_USUARIOS.CICLICO%TYPE;

CURSOR cMUNICIPIOS IS SELECT AYTO FROM MUNICIPIOS WHERE TIPO_CLI='LOC';

BEGIN

	/* Se busca la tarea a ejecutar en la tabla trabajos_usuarios */
	/* El orden de ejecucion de las tareas de la tabla es :
		1�: Nivel de Prioridad (0 m�xima, 9 m�nima)
		2�: Fecha de disparo de la tarea
		3�: Identificador de tarea (para casos de igual prioridad y fecha)

		Para esto se hacen dos joins entre la tabla de trabajos_usuarios y la de
	trabajos pendientes de la BD.
		- El primero es para que salga una sola tupla m�nima y no el minimo para cada
			trabajo.
		- El segundo es para que no devuelva como minima una tupla no real creada
			por el join.
	Este select devuelve una �nica tupla.
	*/
  SELECT T.N_TRABAJO, T.PARAM_DATE1, T.PARAM_DATE2, RTRIM(T.PARAM_CHAR1), T.CICLICO
	INTO xN_Trabajo, xFechaInicio, xFechaFin ,xAyuntamiento, xCiclico
	FROM TRABAJOS_USUARIOS T, USER_JOBS U
	WHERE T.N_TRABAJO=U.JOB AND
		(T.PRIORIDAD||TO_CHAR(U.NEXT_DATE,'yyyy/mm/dd, hh24:mi:ss')||T.N_TRABAJO)
	IN (SELECT
		MIN(T2.PRIORIDAD||TO_CHAR(U2.NEXT_DATE,'yyyy/mm/dd, hh24:mi:ss')||T2.N_TRABAJO)
			FROM TRABAJOS_USUARIOS T2, USER_JOBS U2
			WHERE T2.N_TRABAJO=U2.JOB AND T2.TRABAJO='CreaLiquidacion(1);');

  IF (xAyuntamiento='-1') THEN /* Se han de liquidar todos los municipios */

    -- Se amortizan los intereses de los anticipos

	PkAmortizaciones.AmortizarAnticipos(xFechaInicio, xFechaFin);

	FOR v_MUN IN cMUNICIPIOS LOOP

		LiquidaUnAyto(xFechaInicio,xFechaFin, v_MUN.AYTO);

	END LOOP;

  ELSE

  	-- amortizar un s�lo ayuntamiento
	PkAmortizaciones.AmortizarAnticiposAyto(xAyuntamiento, xFechaInicio,xFechaFin);

	LiquidaUnAyto(xFechaInicio, xFechaFin, xAyuntamiento);

  END IF;


  /* Se elimina la tupla de parametros de la tarea si esta no es ciclica */
  IF (xCiclico='NULL') THEN	/* Si no cicla, se elimina la informaci�n de trabajos_usuarios */

	DELETE FROM TRABAJOS_USUARIOS  WHERE N_TRABAJO=xN_Trabajo;

  ELSE /* Si cicla, se rebaja la prioridad de la tarea en TRABAJOS_USUARIOS */

	UPDATE TRABAJOS_USUARIOS SET PRIORIDAD='9' WHERE N_TRABAJO=xN_Trabajo;

  END IF;



END;
/