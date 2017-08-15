-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------

-- **********************************************************************

-- Este procedimiento no tenía parámetros, pero se ha tenido que
--   añadir uno para que desde delphi sea visible dicho procedimiento 

-- Modificado: 14-04-2003. Lucas Fernández Pérez. Se cambian los cursores y se inserta
-- mas información en la tabla de estadísticas (estado dentro del embargo, cantidad...)

CREATE OR REPLACE PROCEDURE DATOS_ESTADISTICOS(NUM INTEGER)
AS

xZONA 	 CHAR(2);
xUsuario	TRABAJOS_USUARIOS.USUARIO%TYPE;
xCiclico	TRABAJOS_USUARIOS.CICLICO%TYPE;
xN_Trabajo  TRABAJOS_USUARIOS.N_TRABAJO%TYPE;

xEmbargo CHAR(14);
xEstado  VARCHAR(20);

-- -------   MODALIDAD: PENDIENTES -----------------
-- VALORES EN VOLUNTARIA 
CURSOR CVOLUN IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
        FROM VALORES V
        WHERE VOL_EJE='V'
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        GROUP BY AYTO,V.YEAR;

-- VALORES EN EJECUTIVA SIN NOTIFICAR
CURSOR C_EJE_SIN_NOTI IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
        FROM VALORES 
        WHERE VOL_EJE='E'
        AND NOTIFICADO='N'
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        GROUP BY AYTO,YEAR;

-- VALORES EN EJECUTIVA NOTIFICADOS Y SIN EXPEDIENTES
CURSOR C_EJE_NOTI_SIN_EXPE IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
        FROM VALORES 
        WHERE VOL_EJE='E'
        AND EXPEDIENTE IS NULL
        AND NOTIFICADO='S'
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        GROUP BY AYTO,YEAR;

-- VALORES EN EJECUTIVA NOTIFICADOS Y CON EXPEDIENTES 
CURSOR CEXPE IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL,V.AYTO, V.YEAR, 
        	EMBARGO, ESTA_EMBARGO
        FROM VALORES V, EXPEDIENTES E
        WHERE V.EXPEDIENTE=E.ID 
        AND V.VOL_EJE='E'
        AND V.F_INGRESO IS NULL
        AND V.FECHA_DE_BAJA IS NULL
        GROUP BY V.AYTO,V.YEAR,EMBARGO,ESTA_EMBARGO;

        
-- -------   MODALIDAD: SUSPENDIDOS -----------------
-- SUSPENDIDOS - > VALORES EN VOLUNTARIA 
CURSOR CSUSPENVOLUN IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
        FROM VALORES V
        WHERE VOL_EJE='V'
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        AND F_SUSPENSION IS NOT NULL
        GROUP BY AYTO,V.YEAR;

-- SUSPENDIDOS - > VALORES EN EJECUTIVA SIN NOTIFICAR
CURSOR CSUSPEN_EJE_SIN_NOTI IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
        FROM VALORES 
        WHERE VOL_EJE='E'
        AND NOTIFICADO='N'
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        AND F_SUSPENSION IS NOT NULL
        GROUP BY AYTO,YEAR;

-- SUSPENDIDOS - > VALORES EN EJECUTIVA NOTIFICADOS Y SIN EXPEDIENTES
CURSOR CSUSPEN_EJE_NOTI_SIN_EXPE IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
        FROM VALORES 
        WHERE VOL_EJE='E'
        AND EXPEDIENTE IS NULL
        AND NOTIFICADO='S'
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        AND F_SUSPENSION IS NOT NULL
        GROUP BY AYTO,YEAR;

-- SUSPENDIDOS - > VALORES EN EJECUTIVA NOTIFICADOS Y CON EXPEDIENTES 
CURSOR CSUSPENEXPE IS
        SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL,V.AYTO, V.YEAR, 
        	EMBARGO, ESTA_EMBARGO
        FROM VALORES V, EXPEDIENTES E
        WHERE V.EXPEDIENTE=E.ID 
        AND V.VOL_EJE='E'
        AND V.F_INGRESO IS NULL
        AND V.FECHA_DE_BAJA IS NULL
        AND V.F_SUSPENSION IS NOT NULL
        GROUP BY V.AYTO,V.YEAR,EMBARGO,ESTA_EMBARGO;

-- -------   OTRAS MODALIDADES -----------------
-- Valores prescritos importes por años
CURSOR vPrescritos IS
		SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO, YEAR
		FROM VALORES V
		WHERE VOL_EJE='E'
		AND FIN_PE_VOL <=ADD_MONTHS(sysdate,-48)
		AND (F_NOTIFICACION<=ADD_MONTHS(sysdate,-48) OR F_NOTIFICACION IS NULL)
		AND (EXPEDIENTE IS NULL OR EXPEDIENTE NOT IN 
				(SELECT EXPEDIENTE FROM NOTIFICACIONES WHERE EXPEDIENTE=V.EXPEDIENTE AND 
						  (F_1ACUSE >=ADD_MONTHS(sysdate,-48) or
						   F_2ACUSE >=ADD_MONTHS(sysdate,-48) or	 
						   f_publicacion>=ADD_MONTHS(sysdate,-48)
						   )
				)
			)
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		GROUP BY AYTO,YEAR;

-- Valores en ejecutiva sin notificar no prescritos
CURSOR SinNotiNoPres IS
		SELECT COUNT(*) AS CUANTOS, SUM(PRINCIPAL) AS PRINCIPAL, AYTO
		FROM VALORES
		WHERE VOL_EJE='E'
		AND NOTIFICADO='N'
		AND FIN_PE_VOL >=ADD_MONTHS(sysdate,-48)
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		GROUP BY AYTO;


BEGIN

-- Busco el trabajo que se ha lanzado de la tabla de trabajos_usuarios 

begin

 SELECT T.N_TRABAJO, T.CICLICO
	INTO xN_Trabajo, xCiclico
	FROM TRABAJOS_USUARIOS T, USER_JOBS U
	WHERE T.N_TRABAJO=U.JOB AND
		(T.PRIORIDAD||TO_CHAR(U.NEXT_DATE,'yyyy/mm/dd, hh24:mi:ss')||T.N_TRABAJO)
	IN (SELECT
		MIN(T2.PRIORIDAD||TO_CHAR(U2.NEXT_DATE,'yyyy/mm/dd, hh24:mi:ss')||T2.N_TRABAJO)
			FROM TRABAJOS_USUARIOS T2, USER_JOBS U2
			WHERE T2.N_TRABAJO=U2.JOB AND T2.TRABAJO='DATOS_ESTADISTICOS(1);');
	Exception
	   When no_data_found then
		null;
   end;


-- He obtenido el código del trabajo que se ha lanzado 
  DELETE FROM ESTADISTICAS WHERE ANNE IS NOT NULL;

-- ---------------------------------------------------------------------- 
-- FUNCIONES PARA VER EL TOTAL DEL PENDIENTE DE LA RECAUDACIÓN 
-- VALORES EN VOLUNTARIA
  FOR v_Valo IN CVOLUN LOOP

  	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;

	INSERT INTO ESTADISTICAS
	    (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (v_Valo.Year,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'PENDIENTES','VOLUNTARIA','VOLUNTARIA','VOLUNTARIA','SIN NOTIFICAR');

  END LOOP;

  
-- VALORES EN EJECUTIVA PENDIENTES DE NOTIFICAR
  FOR v_Valo IN C_EJE_SIN_NOTI LOOP

	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;

   	INSERT INTO ESTADISTICAS
        (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (v_Valo.Year,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'PENDIENTES','EJECUTIVA','SIN NOTIFICAR','SIN NOTIFICAR','SIN NOTIFICAR');

  END LOOP;

  
-- VALORES EN EJECUTIVA NOTIFICADOS Y SIN EXPEDIENTES
  FOR v_Valo IN C_EJE_NOTI_SIN_EXPE LOOP

  	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;

   	INSERT INTO ESTADISTICAS
        (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (v_Valo.Year,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'PENDIENTES','EJECUTIVA','N.SIN EXPEDIENTE','SIN EXPEDIENTE','NOTIFICADO');
  END LOOP;


-- VALORES EN EXPEDIENTE AGRUPADOS POR TRAMITES Y ESTADO DENTRO DEL TRÁMITE
  FOR v_Valo IN CEXPE LOOP

  	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;

  	IF v_Valo.EMBARGO='0' THEN
  		xEmbargo:='SIN TRAMITE';
  	ELSIF v_Valo.EMBARGO='1' THEN
  		xEmbargo:='CUENTAS';
  	ELSIF v_Valo.EMBARGO='3' THEN
  		xEmbargo:='SALARIOS';
  	ELSIF v_Valo.EMBARGO='4' THEN
  		xEmbargo:='INMUEBLES';
  	ELSIF v_Valo.EMBARGO='8' THEN
  		xEmbargo:='VEHICULOS';
  	ELSIF v_Valo.EMBARGO='X' THEN
  		xEmbargo:='OTROS';
  	END IF;
  		
  	IF v_Valo.ESTA_EMBARGO='P' THEN
  		xEstado:='PENDIENTE';
  	ELSIF v_Valo.ESTA_EMBARGO='O' THEN
  		xEstado:='ABIERTO';
  	ELSIF v_Valo.ESTA_EMBARGO='C' THEN
  		xEstado:='CERRADO';
  	ELSIF v_Valo.ESTA_EMBARGO='L' THEN
  		xEstado:='LEVANTADO';
  	END IF;
  		
   	INSERT INTO ESTADISTICAS 
   	(ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,ESTADO,NOTIFICADO)
   	VALUES
        (v_Valo.YEAR,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'PENDIENTES','EJECUTIVA','EXPEDIENTES',xEmbargo,xEstado,'NOTIFICADO');

  END LOOP;
  

-- ---------------------------------------------------------------------- 
-- FUNCIONES PARA VER EL TOTAL SUSPENDIDO DE LA RECAUDACIÓN 
-- Los cuatro cursores son iguales que para el pendiente, con la única condición añadida
-- de que f_suspension is not null. Lo que se hace con los 4 cursores es exactamente igual
-- que lo que se hace para los 4 cursores de la modalidad de PENDIENTES.
--
-- SUSPENDIDOS -> VALORES EN VOLUNTARIA 
  FOR v_Valo IN CSUSPENVOLUN LOOP
  	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;
	INSERT INTO ESTADISTICAS
	    (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (v_Valo.Year,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'SUSPENDIDOS','VOLUNTARIA','VOLUNTARIA','VOLUNTARIA','SIN NOTIFICAR');
  END LOOP;
  
-- SUSPENDIDOS -> VALORES EN EJECUTIVA PENDIENTES DE NOTIFICAR
  FOR v_Valo IN CSUSPEN_EJE_SIN_NOTI LOOP
	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;
   	INSERT INTO ESTADISTICAS
        (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (v_Valo.Year,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'SUSPENDIDOS','EJECUTIVA','SIN NOTIFICAR','SIN NOTIFICAR','SIN NOTIFICAR');

  END LOOP;

-- SUSPENDIDOS -> VALORES EN EJECUTIVA NOTIFICADOS Y SIN EXPEDIENTES
  FOR v_Valo IN CSUSPEN_EJE_NOTI_SIN_EXPE LOOP
 	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;
   	INSERT INTO ESTADISTICAS
        (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (v_Valo.Year,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'SUSPENDIDOS','EJECUTIVA','N.SIN EXPEDIENTE','SIN EXPEDIENTE','NOTIFICADO');
  END LOOP;

-- SUSPENDIDOS -> VALORES EN EXPEDIENTE AGRUPADOS POR TRAMITES Y ESTADO DENTRO DEL TRÁMITE
  FOR v_Valo IN CSUSPENEXPE LOOP
  	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_Valo.AYTO;

  	IF v_Valo.EMBARGO='0' THEN
  		xEmbargo:='SIN TRAMITE';
  	ELSIF v_Valo.EMBARGO='1' THEN
  		xEmbargo:='CUENTAS';
  	ELSIF v_Valo.EMBARGO='3' THEN
  		xEmbargo:='SALARIOS';
  	ELSIF v_Valo.EMBARGO='4' THEN
  		xEmbargo:='INMUEBLES';
  	ELSIF v_Valo.EMBARGO='8' THEN
  		xEmbargo:='VEHICULOS';
  	ELSIF v_Valo.EMBARGO='X' THEN
  		xEmbargo:='OTROS';
  	END IF;
  		
  	IF v_Valo.ESTA_EMBARGO='P' THEN
  		xEstado:='PENDIENTE';
  	ELSIF v_Valo.ESTA_EMBARGO='O' THEN
  		xEstado:='ABIERTO';
  	ELSIF v_Valo.ESTA_EMBARGO='C' THEN
  		xEstado:='CERRADO';
  	ELSIF v_Valo.ESTA_EMBARGO='L' THEN
  		xEstado:='LEVANTADO';
  	END IF;
  		
   	INSERT INTO ESTADISTICAS 
   	(ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,MODALIDAD,VOL_EJE,GRUPO,TIPO,ESTADO,NOTIFICADO)
   	VALUES
        (v_Valo.YEAR,v_Valo.Principal,0,v_Valo.Cuantos,xZONA,v_Valo.AYTO,
        	'SUSPENDIDOS','EJECUTIVA','EXPEDIENTES',xEmbargo,xEstado,'NOTIFICADO');

  END LOOP;

-- ---------------------------------------------------------------------- 
-- RESTO DE FUNCIONES 
-- Valores prescritos agrupados por años
FOR V_vPrescritos IN vPrescritos LOOP

   SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=V_vPrescritos.AYTO;

   INSERT INTO ESTADISTICAS
        (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,VOL_EJE,MODALIDAD,GRUPO,TIPO,NOTIFICADO)
   VALUES
        (V_vPrescritos.Year,V_vPrescritos.Principal,0,V_vPrescritos.Cuantos,xZONA,
        V_vPrescritos.AYTO,'EJECUTIVA','PRESCRITOS','PRESCRITOS','PRESCRITOS','NOTIFICADO');

END LOOP;


-- Suma total de deudas sin notificar no prescritas por ayto.
-- de utilidad para hacer los cálculos de cuanto nos va a costar notificar estos valores.
  FOR v_SinNotiNoPres IN SinNotiNoPres LOOP

  	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_SinNotiNoPres.AYTO;

   	INSERT INTO ESTADISTICAS
        (ANNE,Principal,Recargo,Cuantos,ZONA,AYTO,VOL_EJE,MODALIDAD,GRUPO,TIPO,NOTIFICADO)
   	VALUES
        (to_char(sysdate,'YYYY'),v_SinNotiNoPres.Principal,0,v_SinNotiNoPres.Cuantos,xZONA,
        v_SinNotiNoPres.AYTO,
        'EJECUTIVA','BUENOSINNOTI','BUENOSINNOTI','BUENOSINNOTI','NOTIFICADO');

  END LOOP;


-- ACTUALIZAR LA FECHA DE CREACION Y EL USUARIO 
  UPDATE DATOSPERR SET F_GRAFICOS_PENTE=SYSDATE,
       		  USUARIO_GRAFI_PE=USER
  WHERE EMPRESA IS NOT NULL;

-- Mantenimiento de la tabla trabajos_usuarios 
  -- Si la tarea no cicla, se elimina la información de trabajos_usuarios 
  IF (xCiclico='NULL') THEN 
	DELETE FROM TRABAJOS_USUARIOS WHERE N_TRABAJO=xN_Trabajo;
  ELSE -- Si cicla, se rebaja la prioridad de la tarea en TRABAJOS_USUARIOS 
	UPDATE TRABAJOS_USUARIOS SET PRIORIDAD='9' WHERE N_TRABAJO=xN_Trabajo;
  END IF;

END;
/


/*******************************************************************************************
Acción: Inserta en una tabla temporal los datos necesarios para el Gráfico de ingresos por
        entidades
Autor: 07/09/2001 M. Carmen Junco Gómez
MODIFICACIÓN: 12/12/2002 M. Carmen Junco Gómez. No se han de seleccionar ingresos de la
 			  Junta (Organismo_Ext='A')
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE GRAFICO_ENTIDADES_BANCARIAS(
		xDESDE   IN DATE,
		xHASTA   IN DATE,
		xVOL_EJE IN CHAR)
AS
   xMEDIA     FLOAT;
   xPRINCIPAL FLOAT;
   xCONTADOR  INTEGER;
   xUID	  INTEGER;

   CURSOR C1 IS SELECT C.ENTIDAD,SUM(PRINCIPAL) AS SUMA
                FROM INGRESOS I,CUENTAS_SERVICIO C
		    	WHERE I.CUENTA=C.ID AND I.CUENTA IS NOT NULL AND
		    	I.FECHA BETWEEN xDESDE AND xHASTA
		    	AND I.ORGANISMO_EXT<>'A'
		    	GROUP BY C.ENTIDAD;
   CURSOR C2 IS SELECT C.ENTIDAD,SUM(PRINCIPAL) AS SUMA
                FROM INGRESOS I,CUENTAS_SERVICIO C
		    	WHERE I.CUENTA=C.ID AND I.CUENTA IS NOT NULL AND
		    	I.FECHA BETWEEN xDESDE AND xHASTA AND I.VOL_EJE=xVOL_EJE
		    	AND I.ORGANISMO_EXT<>'A'
		    	GROUP BY C.ENTIDAD;

BEGIN

   SELECT UID INTO xUID FROM DUAL;

   --borramos de la tabla temporal GRAFICO_ENTIDADES
   DELETE FROM GRAFICO_ENTIDADES WHERE USUARIO=xUID;

   --si el número de entidades distintas es igual o menor a 7 las introducimos todas

   IF ((xVOL_EJE='V') OR (xVOL_EJE='E')) THEN
      SELECT COUNT(DISTINCT(C.ENTIDAD)) INTO xCONTADOR
      FROM INGRESOS I,CUENTAS_SERVICIO C
      WHERE I.CUENTA=C.ID AND I.CUENTA IS NOT NULL AND I.VOL_EJE=xVOL_EJE
      		AND I.ORGANISMO_EXT<>'A';
   ELSE
      SELECT COUNT(DISTINCT(C.ENTIDAD)) INTO xCONTADOR
      FROM INGRESOS I,CUENTAS_SERVICIO C
      WHERE I.CUENTA=C.ID AND I.CUENTA IS NOT NULL AND I.ORGANISMO_EXT<>'A';
   END IF;

   IF (xCONTADOR<8) THEN

      IF ((xVOL_EJE='V') OR (xVOL_EJE='E')) THEN
         FOR v2 IN C2
	   LOOP
	      INSERT INTO GRAFICO_ENTIDADES (USUARIO,ENTIDAD,SUMPRINCIPAL)
	      VALUES (xUID,v2.ENTIDAD,v2.SUMA);
	   END LOOP;
      ELSE
         FOR v1 IN C1
         LOOP
	      INSERT INTO GRAFICO_ENTIDADES (USUARIO,ENTIDAD,SUMPRINCIPAL)
		VALUES (xUID,v1.ENTIDAD,v1.SUMA);
         END LOOP;
      END IF;

   ELSE  --hay mas de siete entidades diferentes; calculamos la media y agrupamos en OTROS

      xMEDIA:=0;
      xPRINCIPAL:=0;

      --primero calculamos la media de ingresos

      IF ((xVOL_EJE='V') OR (xVOL_EJE='E')) THEN
         SELECT AVG(SUM(PRINCIPAL)) INTO xMEDIA
         FROM INGRESOS I,CUENTAS_SERVICIO C
	     WHERE I.CUENTA=C.ID AND I.CUENTA IS NOT NULL AND
   	     I.VOL_EJE=xVOL_EJE AND I.ORGANISMO_EXT<>'A'
	     GROUP BY C.ENTIDAD;
      ELSE
         SELECT AVG(SUM(PRINCIPAL)) INTO xMEDIA
         FROM INGRESOS I,CUENTAS_SERVICIO C
	     WHERE I.CUENTA=C.ID AND I.CUENTA IS NOT NULL AND I.ORGANISMO_EXT<>'A'
	     GROUP BY C.ENTIDAD;
      END IF;

      /* sumamos los principales de aquellos grupos de recibos de entidades
         cuya suma no supere la media/1.5, y los agrupamos en OTROS */

      IF ((xVOL_EJE='V') OR (xVOL_EJE='E')) THEN
         FOR v2 IN C2
	   LOOP
            IF v2.SUMA<(xMEDIA/1.5) THEN
               xPRINCIPAL:=xPRINCIPAL+v2.SUMA;
	      ELSE  /* insertamos la entidad de forma individual al superar el baremo */
	         INSERT INTO GRAFICO_ENTIDADES (USUARIO,ENTIDAD,SUMPRINCIPAL)
		   VALUES (xUID,v2.ENTIDAD,v2.SUMA);
            END IF;
	   END LOOP;
      ELSE
         FOR v1 IN C1
         LOOP
            IF v1.SUMA<(xMEDIA/1.5) THEN
               xPRINCIPAL:=xPRINCIPAL+v1.SUMA;
	      ELSE  /* insertamos la entidad de forma individual al superar el baremo */
	         INSERT INTO GRAFICO_ENTIDADES (USUARIO,ENTIDAD,SUMPRINCIPAL)
		   VALUES (xUID,v1.ENTIDAD,v1.SUMA);
            END IF;
         END LOOP;
      END IF;

      /* insertamos la agrupacion de las entidades cuyas sumas no superan la media */
      INSERT INTO GRAFICO_ENTIDADES (USUARIO,ENTIDAD,SUMPRINCIPAL)
      VALUES (xUID,'OTROS',xPRINCIPAL);

   END IF;  /* xCONTADOR<8 */

END;
/


/******************************************************************/
COMMIT;
/********************************************************************/
