-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------
/*SELECT TO_CHAR(FECHA,'DD-MM-YYYY HH24:MI:SS'),ID FROM BITACORAS
WHERE IDEXPE=1075
AND FECHA<=TO_DATE('03-05-2001 21:00:00','DD-MM-YYYY HH24:MI:SS')*/

-- Suspender un tramite por un tiempo determinado, para poder emitir un documento de pago
-- en ejecutiva con un vencimiento de pago en entidad fianciera.
-- Idea sugerida por el CEMI del Ayuntamiento de Málaga.
--
-- El procedimiento llamador tiene que comprobar que el expediente esta en estado correcto
-- para poder pasar a esta situación.
--
-- Antonio Pérez Caballero 10 de Mayo de 2001
-- Modificado: 02/09/2004. Lucas Fernández Pérez.
-- Para poder suspender temporalmente un expediente, debe tener recibos pendientes. 
--

CREATE OR REPLACE PROCEDURE ASUSTA_VIEJAS(
		xIDEXPE  IN INTEGER,
		xPLAZO   IN DATE,
		xTramite IN CHAR)
AS
   xCADENA CHAR(5);
   xLETRA  CHAR(1);
   ENVIADO_YA EXCEPTION;
   xCONTADOR INTEGER;
BEGIN


	-- Para poder suspender temporalmenteun expediente, debe tener recibos pendientes. 
	SELECT COUNT(*) INTO xCONTADOR 
	FROM VALORES 
	WHERE Expediente=xIDExpe
		  AND F_INGRESO IS NULL 
		  AND FECHA_DE_BAJA IS NULL
		  AND F_SUSPENSION IS NULL;
	
	IF xCONTADOR=0 THEN
		RETURN;
	END IF;

   /* Lo que se pretende es que se envie un documento al deudor indicando su deuda
	y que puede abonarla en una entidad financiera hasta una fecha determinada.

      Tenemos que controlar que no entre un expediente dos veces en este proceso pues nunca
      acabaríamos con los trámites de embargo y prescribiría.
      Para este fin lo que hacemos es que tenemos una cadena de caracteres almacenada
      en el campo DOCVENCIMIENTO que inicialmente tiene el valor 'CSIVO'. Cuando el
      expediente pasa por un tramite pondremos el valor del tramite a 'X' con lo cual ya no
      se volverá a imprimir el documento para un mismo expediente en un mismo trámite.
	Por ejemplo, si un expediente se encuentra en el pendiente de Salarios y su cadena
	es 'CSIVO', entonces al suspenderlo temporalmente se cambiaría la cadena por 'CXIVO'.
	Si ha pasado ya por cuentas la cadena sería la siguiente: 'XXIVO';
  */

   SELECT DOCVENCIMIENTO INTO xCADENA
   FROM EXPEDIENTES
   WHERE ID=xIDEXPE;

   IF xTRAMITE='1' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,1,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN
	   RAISE ENVIADO_YA;
	ELSE
         xCADENA:='X' || SUBSTR(xCADENA,2,4);
         UPDATE EXPEDIENTES SET EMBARGO_1='S', F_EMBARGO_CUENTAS=xPLAZO, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE
	         AND EMBARGO_1='P'
	         AND SUBSTR(DOCVENCIMIENTO,1,1)='C';
	END IF;
   END IF;

   IF xTRAMITE='3' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,2,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN
	   RAISE ENVIADO_YA;
	ELSE
         xCADENA:=SUBSTR(xCADENA,1,1) || 'X' || SUBSTR(xCADENA,3,3);
         UPDATE EXPEDIENTES SET EMBARGO_3='S', F_EMBARGO_SALARIOS=xPLAZO, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE
   	      AND EMBARGO_3='P'
	      AND SUBSTR(DOCVENCIMIENTO,2,1)='S';
	END IF;
   END IF;

   IF xTRAMITE='4' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,3,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN
	   RAISE ENVIADO_YA;
	ELSE
         xCADENA:=SUBSTR(xCADENA,1,2) || 'X' || SUBSTR(xCADENA,4,2);
         UPDATE EXPEDIENTES SET EMBARGO_4='S', F_EMBARGO_INMUEBLES=xPLAZO, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE
	      AND EMBARGO_4='P'
 	      AND SUBSTR(DOCVENCIMIENTO,3,1)='I';
	END IF;
   END IF;

   IF xTRAMITE='8' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,4,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN
	   RAISE ENVIADO_YA;
	ELSE
         xCADENA:=SUBSTR(xCADENA,1,3) || 'X' || SUBSTR(xCADENA,5,1);
         UPDATE EXPEDIENTES SET EMBARGO_8='S', F_EMBARGO_VEHICULOS=xPLAZO, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE
	      AND EMBARGO_8='P'
	      AND SUBSTR(DOCVENCIMIENTO,4,1)='V';
	END IF;
   END IF;

   IF xTRAMITE='X' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,5,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN
	   RAISE ENVIADO_YA;
	ELSE
         xCADENA:=SUBSTR(xCADENA,1,4) || 'X';
         UPDATE EXPEDIENTES SET EMBARGO_X='S', F_EMBARGO_OTROS=xPLAZO, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE
  	      AND EMBARGO_X='P'
	      AND SUBSTR(DOCVENCIMIENTO,5,1)='O';
	END IF;
   END IF;

END;
/


/******************************************************************************************
Autor: M. Carmen Junco Gomez.
Fecha: 10/08/2001

Acción: Si estamos en el pendiente de salarios,inmuebles o vehículos y deseamos suspender
        temporalmente más de un expediente a la vez, indicamos el número de lote que engloba
	  al conjunto de expedientes que se quieren suspender y, para cada uno de ellos
	  llamamos al procedimiento ASUSTA_VIEJAS.Tambien se puede suspender todo lo pendiente.

MODIFICACIÓN: 25/1/2002. Lucas Fernández Pérez. Indicar número de Lote y no entre fechas para
	        el embargo de salarios e inmuebles.
MODIFICACIÓN: 18/02/2002 M. Carmen Junco Gomez. Indicar número de Lote también para el
		  embargo de Vehículos.
MODIFICACIÓN: 12/07/2002 Lucas Fernández Pérez. Tambien se puede suspender
			todo lo pendiente de un trámite si xNLote='N'.
MODIFICACION: 30/12/2002 Lucas Fernández Pérez. Suspensión de expedientes en embargo
				de cuentas.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ASUSTAVIEJAS_MULTIPLE(
		xZONA		IN	CHAR,
		xDESDE	IN	DATE,
		xHASTA	IN	DATE,
		xPLAZO      IN    DATE,
		xTRAMITE	IN	CHAR,
		xNLote	IN 	CHAR)
AS

   -- AsustaViejas para los expedientes de un LOTE o ENTRE FECHAS de un tramite.
   CURSOR CCUENTAS IS SELECT ID FROM NEXT_RELA_CUENTAS WHERE ZONA=xZONA AND
			F_EMBARGO_CUENTAS BETWEEN xDESDE AND xHASTA;
   CURSOR CSALARIOS IS SELECT ID FROM NEXT_RELA_SALARIOS WHERE ZONA=xZONA AND
			LOTE_3= xNLote;
   CURSOR CINMUEBLES IS SELECT ID FROM NEXT_RELA_INMUEBLES WHERE ZONA=xZONA AND
			LOTE_4= xNLote;
   CURSOR CAUTOS IS SELECT ID FROM NEXT_RELA_AUTOS WHERE ZONA=xZONA AND
			LOTE_8=xNLote;
   CURSOR COTROS IS SELECT ID FROM NEXT_RELA_OTROS WHERE ZONA=xZONA AND
			F_EMBARGO_OTROS BETWEEN xDESDE AND xHASTA;

   -- AsustaViejas para TODOS los expedientes de un tramite, no solo los de un lote o fecha.
   CURSOR CCUENTASTODOS IS SELECT ID FROM NEXT_RELA_CUENTAS WHERE ZONA=xZONA;

   CURSOR CSALARIOSTODOS IS SELECT ID FROM NEXT_RELA_SALARIOS WHERE ZONA=xZONA;

   CURSOR CINMUEBLESTODOS IS SELECT ID FROM NEXT_RELA_INMUEBLES WHERE ZONA=xZONA;

   CURSOR CAUTOSTODOS IS SELECT ID FROM NEXT_RELA_AUTOS WHERE ZONA=xZONA;

BEGIN

   IF xTRAMITE='1' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.

	   FOR v_cursor IN CCUENTASTODOS LOOP
	      ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'1');
         END LOOP;

	else -- Los expedientes entre fechas

	   FOR v_cursor IN CCUENTAS LOOP
	      ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'1');
         END LOOP;

	end if;

   ELSIF xTRAMITE='3' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.

	   FOR v_cursor IN CSALARIOSTODOS LOOP
	      ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'3');
         END LOOP;

	else -- Los expedientes de un LOTE

	   FOR v_cursor IN CSALARIOS LOOP
	      ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'3');
         END LOOP;

	end if;

   ELSIF xTRAMITE='4' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.
         FOR v_cursor IN CINMUEBLESTODOS LOOP
            ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'4');
         END LOOP;
	else -- Los expedientes de un LOTE
         FOR v_cursor IN CINMUEBLES LOOP
            ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'4');
         END LOOP;
	end if;

   ELSIF xTRAMITE='8' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.
         FOR v_cursor IN CAUTOSTODOS LOOP
            ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'8');
         END LOOP;
	else -- Los expedientes de un LOTE
         FOR v_cursor IN CAUTOS LOOP
            ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'8');
         END LOOP;
	end if;

   ELSE
	FOR v_cursor IN COTROS
	LOOP
	   ASUSTA_VIEJAS(v_cursor.ID,xPLAZO,'X');
	END LOOP;
   END IF;

END;
/

-- Una vez que se haya suspendido un tramite por un tiempo determinado, poder quitar esta
-- suspension porque nos hayamos equivocado

-- Realizado por: Agustin Leon Robles 2 de Octubre de 2001

CREATE OR REPLACE PROCEDURE QUITAR_ASUSTA_VIEJAS(
		xIDEXPE  IN INTEGER,
		xTramite IN CHAR)
AS
   xCADENA CHAR(5);
   xLETRA  CHAR(1);
BEGIN

   SELECT DOCVENCIMIENTO INTO xCADENA FROM EXPEDIENTES WHERE ID=xIDEXPE;

   IF xTRAMITE='1' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,1,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN

         xCADENA:='C' || SUBSTR(xCADENA,2,4);

         UPDATE EXPEDIENTES SET EMBARGO_1='P', F_EMBARGO_CUENTAS=SYSDATE, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE AND EMBARGO_1='S';

	END IF;
   END IF;

   IF xTRAMITE='3' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,2,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN

         xCADENA:=SUBSTR(xCADENA,1,1) || 'S' || SUBSTR(xCADENA,3,3);

         UPDATE EXPEDIENTES SET EMBARGO_3='P', F_EMBARGO_SALARIOS=SYSDATE, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE AND EMBARGO_3='S';

	END IF;
   END IF;

   IF xTRAMITE='4' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,3,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN

         xCADENA:=SUBSTR(xCADENA,1,2) || 'I' || SUBSTR(xCADENA,4,2);

         UPDATE EXPEDIENTES SET EMBARGO_4='P', F_EMBARGO_INMUEBLES=SYSDATE, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE AND EMBARGO_4='S';

	END IF;
   END IF;

   IF xTRAMITE='8' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,4,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN

         xCADENA:=SUBSTR(xCADENA,1,3) || 'V' || SUBSTR(xCADENA,5,1);

         UPDATE EXPEDIENTES SET EMBARGO_8='P', F_EMBARGO_VEHICULOS=SYSDATE, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE AND EMBARGO_8='S';

	END IF;
   END IF;

   IF xTRAMITE='X' THEN
      SELECT SUBSTR(DOCVENCIMIENTO,5,1) INTO xLETRA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	IF xLETRA='X' THEN

         xCADENA:=SUBSTR(xCADENA,1,4) || 'O';

         UPDATE EXPEDIENTES SET EMBARGO_X='P', F_EMBARGO_OTROS=SYSDATE, DOCVENCIMIENTO=xCADENA
         WHERE ID=xIDEXPE AND EMBARGO_X='S';
	END IF;
   END IF;

END;
/


-- ******************************************************************************************
-- Autor: Lucas Fernández Pérez
-- Fecha: 18/07/2002
--
-- Acción: Si estamos en salarios,inmuebles o vehículos y deseamos quitar la suspension
--         temporal de más de un expediente a la vez, indicamos el número de lote que engloba
-- 	  al conjunto de expedientes (o todos los expedientes) que se quieren procesar y,
-- 	  para cada uno de ellos llamamos al procedimiento QUITAR_ASUSTA_VIEJAS.
-- MODIFICACION: 30/12/2002 Lucas Fernández Pérez. Tratamiento de expedientes en embargo
--				de cuentas.
-- *******************************************************************************************/

CREATE OR REPLACE PROCEDURE QUITARASUSTAVIEJAS_MULTIPLE(
		xZONA		IN	CHAR,
		xTRAMITE	IN	CHAR,
		xDESDE	IN	DATE,
		xHASTA	IN	DATE,
		xPLAZO      IN    DATE,
		xNLote	IN 	CHAR)
AS

   -- QuitarAsustaViejas para los expedientes de un LOTE o ENTRE FECHAS de un tramite.
   CURSOR CCUENTAS IS SELECT ID FROM CUENTAS_SUSPENDIDAS WHERE ZONA=xZONA AND
			F_EMBARGO_CUENTAS BETWEEN xDESDE AND xHASTA;
   CURSOR CSALARIOS IS SELECT ID FROM SALARIOS_SUSPENDIDOS WHERE ZONA=xZONA AND
			LOTE_3= xNLote;
   CURSOR CINMUEBLES IS SELECT ID FROM INMUEBLES_SUSPENDIDOS WHERE ZONA=xZONA AND
			LOTE_4= xNLote;
   CURSOR CAUTOS IS SELECT ID FROM AUTOS_SUSPENDIDOS WHERE ZONA=xZONA AND
			LOTE_8=xNLote;
   CURSOR COTROS IS SELECT ID FROM OTROS_SUSPENDIDOS WHERE ZONA=xZONA AND
			F_EMBARGO_OTROS BETWEEN xDESDE AND xHASTA;

   -- QuitarAsustaViejas para TODOS los expedientes de un tramite, no solo los de un lote.
   CURSOR CCUENTASTODOS IS SELECT ID FROM CUENTAS_SUSPENDIDAS WHERE ZONA=xZONA;

   CURSOR CSALARIOSTODOS IS SELECT ID FROM SALARIOS_SUSPENDIDOS WHERE ZONA=xZONA;

   CURSOR CINMUEBLESTODOS IS SELECT ID FROM INMUEBLES_SUSPENDIDOS WHERE ZONA=xZONA;

   CURSOR CAUTOSTODOS IS SELECT ID FROM AUTOS_SUSPENDIDOS WHERE ZONA=xZONA;

BEGIN

   IF xTRAMITE='1' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.

	   FOR v_cursor IN CCUENTASTODOS LOOP
	      QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'1');
         END LOOP;

	else -- Los expedientes entre fechas

	   FOR v_cursor IN CCUENTAS LOOP
	      QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'1');
         END LOOP;

	end if;

   ELSIF xTRAMITE='3' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.

	   FOR v_cursor IN CSALARIOSTODOS LOOP
	      QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'3');
         END LOOP;

	else -- Los expedientes de un LOTE

	   FOR v_cursor IN CSALARIOS LOOP
	      QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'3');
         END LOOP;

	end if;

   ELSIF xTRAMITE='4' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.
         FOR v_cursor IN CINMUEBLESTODOS LOOP
            QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'4');
         END LOOP;
	else -- Los expedientes de un LOTE
         FOR v_cursor IN CINMUEBLES LOOP
            QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'4');
         END LOOP;
	end if;

   ELSIF xTRAMITE='8' THEN

	if xNLote='N' then -- Todos los expedientes Pendientes del tramite.
         FOR v_cursor IN CAUTOSTODOS LOOP
            QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'8');
         END LOOP;
	else -- Los expedientes de un LOTE
         FOR v_cursor IN CAUTOS LOOP
            QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'8');
         END LOOP;
	end if;

   ELSE
	FOR v_cursor IN COTROS
	LOOP
	   QUITAR_ASUSTA_VIEJAS(v_cursor.ID,'X');
	END LOOP;
   END IF;

END;
/


/*************************************************************************************/

-- Levantar la suspensión por documento de pago en banco con vencimiento
-- FRECUENCIA DE EJECUCIÓN DIARIA

CREATE OR REPLACE PROCEDURE JOB_LEVANTA_SUSTO
AS
CURSOR CEXPESUSPEN IS SELECT * FROM EXPEDIENTES WHERE 
	   (EMBARGO_1='S' AND TRUNC(SYSDATE,'DD') >= TRUNC(F_EMBARGO_CUENTAS,'DD'))
	   or 
	   (EMBARGO_3='S' AND TRUNC(SYSDATE,'DD') >= TRUNC(F_EMBARGO_SALARIOS,'DD'))
	   or 
	   (EMBARGO_4='S' AND TRUNC(SYSDATE,'DD') >= TRUNC(F_EMBARGO_INMUEBLES,'DD'))
	   or 
	   (EMBARGO_8='S' AND TRUNC(SYSDATE,'DD') >= TRUNC(F_EMBARGO_VEHICULOS,'DD'))
	   or 
	   (EMBARGO_X='S' AND TRUNC(SYSDATE,'DD') >= TRUNC(F_EMBARGO_OTROS,'DD'))
	   ;

BEGIN

   FOR v_Expe IN CEXPESUSPEN LOOP
	QUITAR_ASUSTA_VIEJAS(v_Expe.ID,v_Expe.Embargo);
   END LOOP;
END;
/


/**************************************************************************************/

--Autor: 17/02/2004 Mª del Carmen Junco Gómez.
--procedimiento para la generación de las cartas de pago asociadas
--a los expedientes que se van a suspender temporalmente en los distintos tipos
--de trámites
--Modificado: 24/05/2004 Lucas Fernández Pérez. Se ordenan los cursores por ID para que
-- el orden en que se muestran las cartas de pago coincida con el orden por id de la tabla.
-- De este modo coincide el informe de cartas de pago con el recordatorio (en word).

CREATE OR REPLACE PROCEDURE SuspenNewCartasPago
		(xIDEXPE  IN INT,
		 xEMBARGO IN CHAR,					
		 xLOTE    IN CHAR,
		 xDESDE   IN DATE,
		 xHASTA   IN DATE,				
		 xZONA	  IN CHAR)
AS
	CURSOR cCUENTAS_TODOS IS
		SELECT ID FROM NEXT_RELA_CUENTAS WHERE ZONA=xZONA ORDER BY ID;
		
	CURSOR cCUENTAS_FECHAS IS
		SELECT ID FROM NEXT_RELA_CUENTAS WHERE F_EMBARGO_CUENTAS BETWEEN xDESDE AND xHASTA
		AND ZONA=xZONA ORDER BY ID;		
		
	CURSOR cSALARIOS_TODOS IS
		SELECT ID FROM NEXT_RELA_SALARIOS WHERE ZONA=xZONA ORDER BY ID;
		
	CURSOR cSALARIOS_LOTE IS
		SELECT ID FROM NEXT_RELA_SALARIOS WHERE LOTE_3=xLOTE AND ZONA=xZONA ORDER BY ID;
		
	CURSOR cINMU_TODOS IS
		SELECT ID FROM NEXT_RELA_INMUEBLES WHERE ZONA=xZONA ORDER BY ID;
		
	CURSOR cINMU_LOTE IS
		SELECT ID FROM NEXT_RELA_INMUEBLES WHERE LOTE_4=xLOTE AND ZONA=xZONA ORDER BY ID;
		
	CURSOR cAUTOS_TODOS IS
		SELECT ID FROM NEXT_RELA_AUTOS WHERE ZONA=xZONA ORDER BY ID;
		
	CURSOR cAUTOS_LOTE IS
		SELECT ID FROM NEXT_RELA_AUTOS WHERE LOTE_8=xLOTE AND ZONA=xZONA ORDER BY ID;
		
BEGIN

	IF xEMBARGO='1' THEN
	
		IF xIDEXPE=-1 THEN --entre fechas
			FOR vCUENTAS IN cCUENTAS_FECHAS
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vCUENTAS.ID);		
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los pendientes
			FOR vCUENTAS IN cCUENTAS_TODOS
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vCUENTAS.ID);		
			END LOOP;
		
		ELSE --un expediente concreto
			NEWCARTAPAGOEXPEDIENTE (xIDEXPE);		
			
		END IF;
	
	ELSIF xEMBARGO='3' THEN
	
		IF xIDEXPE=-1 THEN  --un lote
			FOR vSALARIOS IN cSALARIOS_LOTE
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vSALARIOS.ID);
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los pendientes
			FOR vSALARIOS IN cSALARIOS_TODOS
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vSALARIOS.ID);
			END LOOP;
			
		ELSE --un expediente concreto
			NEWCARTAPAGOEXPEDIENTE(xIDEXPE);
			
		END IF; 
		
	ELSIF xEMBARGO='4' THEN
	
		IF xIDEXPE=-1 THEN  --un lote
			FOR vINMU IN cINMU_LOTE
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vINMU.ID);
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los pendientes
			FOR vINMU IN cINMU_TODOS
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vINMU.ID);
			END LOOP;
			
		ELSE --un expediente concreto
			NEWCARTAPAGOEXPEDIENTE(xIDEXPE);
			
		END IF; 
		
	ELSIF xEMBARGO='8' THEN
	
		IF xIDEXPE=-1 THEN  --un lote
			FOR vAUTOS IN cAUTOS_LOTE
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vAUTOS.ID);
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los pendientes
			FOR vAUTOS IN cAUTOS_TODOS
			LOOP
				NEWCARTAPAGOEXPEDIENTE (vAUTOS.ID);
			END LOOP;
			
		ELSE --un expediente concreto
			NEWCARTAPAGOEXPEDIENTE(xIDEXPE);
			
		END IF; 
	
	END IF;
	
END;
/

/**************************************************************************************/

--Autor: 17/02/2004 Mª del Carmen Junco Gómez.
--procedimiento para la impresión de las cartas de pago (o informes de débitos)
--asociadas a los expedientes suspendidos temporalmente en los distintos tipos
--de trámites. 
-- Se llama únicamente cuando se pide una impresión de suspensiones temporales de expedientes, 
--  (asusta viejas) desde embargo de cuentas, salarios, inmuebles y vehículos.
--
-- Modificado: 27/08/2004. Lucas Fernández Pérez. Se limpia la tabla que almacena posibles incidencias de la impresión.
--
CREATE OR REPLACE PROCEDURE SuspenImprimeCartasPago
		(xIDEXPE  IN INTEGER,
		 xEMBARGO IN CHAR,					
		 xLOTE    IN CHAR,
		 xDESDE   IN DATE,
		 xHASTA   IN DATE,				
		 xZONA	  IN CHAR)
AS
	xIDCARTAPAGO	INT;
	
	CURSOR cCUENTAS_TODOS IS
		SELECT ID FROM CUENTAS_SUSPENDIDAS WHERE ZONA=xZONA;
		
	CURSOR cCUENTAS_FECHAS IS
		SELECT ID FROM CUENTAS_SUSPENDIDAS WHERE F_EMBARGO_CUENTAS BETWEEN xDESDE AND xHASTA
		AND ZONA=xZONA;	
		
	CURSOR cSALARIOS_TODOS IS
		SELECT ID FROM SALARIOS_SUSPENDIDOS WHERE ZONA=xZONA;
		
	CURSOR cSALARIOS_LOTE IS
		SELECT ID FROM SALARIOS_SUSPENDIDOS WHERE LOTE_3=xLOTE AND ZONA=xZONA;
		
	CURSOR cINMU_TODOS IS
		SELECT ID FROM INMUEBLES_SUSPENDIDOS WHERE ZONA=xZONA;
		
	CURSOR cINMU_LOTE IS
		SELECT ID FROM INMUEBLES_SUSPENDIDOS WHERE LOTE_4=xLOTE AND ZONA=xZONA;
		
	CURSOR cAUTOS_TODOS IS
		SELECT ID FROM AUTOS_SUSPENDIDOS WHERE ZONA=xZONA;
		
	CURSOR cAUTOS_LOTE IS 
		SELECT ID FROM AUTOS_SUSPENDIDOS WHERE LOTE_8=xLOTE AND ZONA=xZONA;
		
BEGIN

	-- Primero borra todos los datos de las tablas temporales que va a rellenar.
	DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID;
	DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
	DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;
	
	-- Tabla que almacenará posibles incidencias de la impresión.
	DELETE FROM TMP_INFORME_EXPE WHERE USUARIO=UID;
	
	IF xEMBARGO='1' THEN
	
		IF xIDEXPE=-1 THEN  --entre fechas
			FOR vCUENTAS IN cCUENTAS_FECHAS 
			LOOP
			
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vCUENTAS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vCUENTAS.ID);
				END IF;	
			
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los expedientes
			FOR vCUENTAS IN cCUENTAS_TODOS
			LOOP
		
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vCUENTAS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vCUENTAS.ID);
				END IF;
			
			END LOOP;
			
		ELSE --expediente seleccionado
			SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
			WHERE ID_EXPE=xIDEXPE AND DESCRIPCION LIKE 'Suspensión temporal%';
			
			IF (xIDCARTAPAGO IS NOT NULL) THEN			
				ImprimeCartaPago(xIDCARTAPAGO,xIDEXPE);
			END IF;
			
		END IF;
		
	ELSIF xEMBARGO='3' THEN
	
		IF xIDEXPE=-1 THEN  --por número de lote
			FOR vSALARIOS IN cSALARIOS_LOTE 
			LOOP
			
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vSALARIOS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vSALARIOS.ID);
				END IF;	
			
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los expedientes
			FOR vSALARIOS IN cSALARIOS_TODOS
			LOOP
		
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vSALARIOS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vSALARIOS.ID);
				END IF;
			
			END LOOP;
			
		ELSE --expediente seleccionado
			SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
			WHERE ID_EXPE=xIDEXPE AND DESCRIPCION LIKE 'Suspensión temporal%';
			
			IF (xIDCARTAPAGO IS NOT NULL) THEN			
				ImprimeCartaPago(xIDCARTAPAGO,xIDEXPE);
			END IF;
			
		END IF;
		
	ELSIF xEMBARGO='4' THEN
	
		IF xIDEXPE=-1 THEN  --por número de lote
			FOR vINMU IN cINMU_LOTE 
			LOOP
			
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vINMU.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vINMU.ID);
				END IF;	
			
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los expedientes
			FOR vINMU IN cINMU_TODOS
			LOOP
		
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vINMU.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vINMU.ID);
				END IF;
			
			END LOOP;
			
		ELSE --expediente seleccionado
			SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
			WHERE ID_EXPE=xIDEXPE AND DESCRIPCION LIKE 'Suspensión temporal%';
			
			IF (xIDCARTAPAGO IS NOT NULL) THEN			
				ImprimeCartaPago(xIDCARTAPAGO,xIDEXPE);
			END IF;
			
		END IF;
		
	ELSIF xEMBARGO='8' THEN
	
		IF xIDEXPE=-1 THEN  --por número de lote
			FOR vAUTOS IN cAUTOS_LOTE 
			LOOP
			
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vAUTOS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vAUTOS.ID);
				END IF;	
			
			END LOOP;
			
		ELSIF xIDEXPE=-2 THEN --todos los expedientes
			FOR vAUTOS IN cAUTOS_TODOS
			LOOP
		
				SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
				WHERE ID_EXPE=vAUTOS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
				IF (xIDCARTAPAGO IS NOT NULL) THEN			
					ImprimeCartaPago(xIDCARTAPAGO,vAUTOS.ID);
				END IF;
			
			END LOOP;
			
		ELSE --expediente seleccionado
			SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
			WHERE ID_EXPE=xIDEXPE AND DESCRIPCION LIKE 'Suspensión temporal%';
			
			IF (xIDCARTAPAGO IS NOT NULL) THEN			
				ImprimeCartaPago(xIDCARTAPAGO,xIDEXPE);
			END IF;
			
		END IF;
		
	END IF;
END;
/
