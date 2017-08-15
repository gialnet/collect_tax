-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- MODIFICACIÓN: 05/06/2002 M. Carmen Junco Gómez. Se modifica para tener dos
-- contadores independientes: uno para ingresos y otro para bajas
-- -----------------------------------------------------
CREATE OR REPLACE PROCEDURE Dame_Contadores (mZona IN char,
							   mTIPO IN CHAR)
AS
BEGIN  

   if mTIPO='I' then
      -- data de ingresos
      UPDATE ZONAS SET NUMERO_DATA=NUMERO_DATA+1 WHERE ZONA=mZONA;
   else
      UPDATE ZONAS SET NUMERO_DATA_BAJA=NUMERO_DATA_BAJA+1 WHERE ZONA=mZONA;
   end if;
END;
/

/***********************************************************************/

-- Modificado 27/12/2001 Agustin Leon Robles. Se ha cambiado el parametro de xError a solo OUT
-- MODIFICACIÓN: 05/06/2002 M. Carmen Junco Gómez. Nueva llamada a dame_contadores.

-- Modificado: 03/10/2002 Agustin Leon Robles. Los ingresos de otros organismos se datan pero
--	no suman en el total de nuestros ingresos ya que se han ingresado	en otros organismos.
--    También se utiliza este mecanismo de forma transitoria para solventar el problema de los
--    ingresos a cuenta no aplicados por la Diputacion de Granada.
CREATE OR REPLACE PROCEDURE CREA_DATAS_INGRE(
	      xVolEje IN CHAR,
	      xFECHA1 IN DATE,
	      xFECHA2 IN DATE,
	      xERROR  OUT INTEGER)
AS

   xZONA char(2);
   xNUMERO CHAR(10);
   xCONT INT DEFAULT 0;
   xPRINCIPAL FLOAT DEFAULT 0;
   xRECARGO FLOAT DEFAULT 0;
   xCOSTAS FLOAT DEFAULT 0;
   xDEMORA FLOAT DEFAULT 0;
   xRECARGO_O_E FLOAT DEFAULT 0;
   xID INTEGER;
   xNUM INT DEFAULT 0;
   xYEAR CHAR(4);

BEGIN

   xERROR:=0;

   -- Averiguar la zona del usuario
   select zona into xZona from usuarios where usuario=user;

   -- Comprobar si hay ingresos datados previa entre el rango de fechas
   -- indicado para la zona del usuario

   SELECT COUNT(*) INTO xCONT FROM DATAS_INGRESOS
   	WHERE FECHA_HASTA >= xFECHA1 
		AND ZONA=xZONA 
		AND VOL_EJE=xVolEje;

   IF (xCONT <> 0) THEN
      xERROR:=1;  -- FECHAS SOLAPADAS 
	RETURN;
   END IF;


   -- si no se han solapado el rango de fechas
   SELECT SUM(PRINCIPAL), SUM(RECARGO), SUM(COSTAS), SUM(DEMORA), SUM(RECARGO_O_E)
         INTO xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA, xRECARGO_O_E
   FROM INGRESOS
         	WHERE NUMERO_DE_DATA IS NULL 
		AND ZONA=xZONA 
		AND FECHA BETWEEN xFECHA1 AND xFECHA2 
		and Vol_Eje=xVolEje and ORGANISMO_EXT NOT IN ('S','A');

   --no hay ingresos que datar en estas fechas
   if xPRINCIPAL is null then
	return;
   end if;

   --para generar el contador de data por cada zona
   DAME_CONTADORES(xZona,'I');

   SELECT LAST_TAREA,YYEAR INTO xNUM,xYEAR FROM USUARIOS WHERE USUARIO=USER;

   xNumero:=DAME_NUMEROS(xYEAR,xNUM);

   INSERT INTO DATAS_INGRESOS(ZONA,NUMERO_DE_DATA,FECHA_DESDE,
                FECHA_HASTA,PRINCIPAL,RECARGO_O_E,RECARGO,COSTAS,DEMORA,
                FECHA,USUARIO,VOL_EJE)

   VALUES(xZONA,xNUMERO,xFECHA1,xFECHA2,xPRINCIPAL,xRECARGO_O_E,
		    xRECARGO,xCOSTAS,xDEMORA,SYSDATE,USER,xVolEje)

   RETURN ID into xID;

   --Los ingresos de otros organismos se datan pero no suman en el total de nuestros 
   --ingresos ya que se han ingresado en otros organismos
   UPDATE INGRESOS SET NUMERO_DE_DATA=xID
         	WHERE ZONA=xZONA 
		AND NUMERO_DE_DATA IS NULL 
		AND FECHA BETWEEN xFECHA1 AND xFECHA2 
		and Vol_Eje=xVolEje;

END;
/

/***********************************************************************/
-- Modificado 27/12/2001 Agustin Leon Robles. Se ha cambiado el parametro de xError a solo OUT
CREATE OR REPLACE PROCEDURE LanzaDatasIngresos(
		 xFECHA1 IN DATE,
		 xFECHA2 IN DATE,
		 xERROR  OUT INTEGER)
AS
BEGIN
     CREA_DATAS_INGRE('E',xFecha1,xFecha2,xError);
     CREA_DATAS_INGRE('V',xFecha1,xFecha2,xError);
END;
/

/***********************************************************************/
-- Modificado 27/12/2001 Agustin Leon Robles. Se ha cambiado el parametro de xError a solo OUT
--				 Tambien se ha cambiado el cursor por uno implicito
-- MODIFICACIÓN: 05/06/2002 M. Carmen Junco Gómez. Nueva llamada a dame_contadores.
CREATE OR REPLACE PROCEDURE CREA_DATAS_BAJAS(
       xFECHA1 IN DATE,
       xFECHA2 IN DATE,
       xERROR  OUT INTEGER)

AS
   
   xZONA char(2);
   xID INTEGER;
   xNUM INTEGER DEFAULT 0;
   xYEAR CHAR(4);
   xNUMERO CHAR(10);

   CURSOR cBajas IS SELECT SUM(PRINCIPAL) AS PRINCIPAL, SUM(RECARGO) AS RECARGO, 
			SUM(COSTAS) AS COSTAS, SUM(DEMORA) AS DEMORA,
                SUM(RECARGO_O_E) AS RECARGO_O_E,VOL_EJE,TIPO_BAJA 
		    FROM BAJAS
                WHERE NUMERO_DE_DATA IS NULL AND ZONA=xZONA
				AND FECHA BETWEEN xFECHA1 AND xFECHA2
				AND TIPO_BAJA<>'BN'
                GROUP BY VOL_EJE,TIPO_BAJA;


BEGIN

	select zona into xZona from usuarios where usuario=user;

	FOR v_Bajas IN cBajas LOOP

		--para generar los contadores
		DAME_CONTADORES(xZona,'B');

		SELECT LAST_TAREA,YYEAR INTO xNUM,xYEAR FROM USUARIOS WHERE USUARIO=USER;

		xNUMERO:=DAME_NUMEROS(xYEAR,xNUM);

		INSERT INTO DATAS_BAJAS(ZONA,NUMERO_DE_DATA,FECHA_DESDE,
			FECHA_HASTA,PRINCIPAL,RECARGO_O_E,RECARGO,COSTAS,DEMORA,
			TIPO_BAJA,USUARIO,VOL_EJE)

		VALUES(xZONA,xNUMERO,xFECHA1,xFECHA2,v_Bajas.PRINCIPAL,
			v_Bajas.RECARGO_O_E,v_Bajas.RECARGO,v_Bajas.COSTAS,v_Bajas.DEMORA,
			v_Bajas.TIPO_BAJA,USER,v_Bajas.VOL_EJE)
		RETURN ID INTO xID;

		UPDATE BAJAS SET NUMERO_DE_DATA=xID
		WHERE ZONA=xZONA AND NUMERO_DE_DATA IS NULL
			AND FECHA BETWEEN xFECHA1 AND xFECHA2
			AND TIPO_BAJA=v_Bajas.TIPO_BAJA and VOL_EJE=v_Bajas.VOL_EJE;
	END LOOP;
END;
/

/****************************************************************************/
COMMIT;
/********************************************************************/
