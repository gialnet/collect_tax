/*****************************************************************************************
Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
Se han realizado cambios.Round en insert/updates
Revisado el 18-12-2002. Lucas Fernández Pérez.
Cambios en las condiciones de las consultas para hacerlas homogéneas.
Modificado: 13-03-2003. Lucas Fernández Pérez. No proponía por insolvencia los recibos
que estuviesen en un expediente. Se cambia el update para que sí los proponga.
*****************************************************************************************/
CREATE OR REPLACE PROCEDURE ADD_INSOLVENTE(xNIF IN CHAR)
AS  
BEGIN   

   INSERT INTO INSOLVENTES (NIF,FECHA_INSOLVENTE)
   VALUES (xNIF, SYSDATE);
   
   UPDATE VALORES SET PROPU_INSOLVENTE='S' WHERE NIF=xNIF AND
   F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL;
	
END;
/

/******************************************************************************************
Rehabilita a un insolvente y todos sus creditos pendientes, tantos los que estan 
propuestos como los que estan ya en baja pero aún no han prescrito
Modificado: 13-03-2003. Lucas Fernández Pérez. No rehabilitaba los recibos
que estuviesen en un expediente. Se cambia el update para que sí los rehabilite.
******************************************************************************************/
CREATE OR REPLACE PROCEDURE DEL_INSOLVENTE(xNIF	IN CHAR)
AS

	xlistaDeNIF VARCHAR2(1024);
	xCUANTOS INT;		

	-- bajas de un deudor no prescritas
	CURSOR cNOPRESCRITOS IS
		SELECT ID,RECIBO from VALORES
		WHERE NIF IN (xlistaDeNIF)
		AND FECHA_DE_BAJA IS NOT NULL
		AND CODIGO_DE_BAJA='BI'
		AND FIN_PE_VOL >= ADD_MONTHS(SYSDATE,-48)
		FOR UPDATE OF PROPU_INSOLVENTE,FECHA_PROPUESTA_BAJA;

BEGIN  

   -- Se elimina el contribuyente de las insolvencias
   DELETE FROM INSOLVENTES WHERE NIF=xNIF;

   -- Se rehabilitan los créditos que tengamos en propuesta
   UPDATE VALORES SET PROPU_INSOLVENTE='N', FECHA_PROPUESTA_BAJA=NULL
   WHERE NIF=xNIF AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL;

   -- Buscamos los créditos que se han dado de baja pero que aún no están prescritos
   xlistaDeNIF:=ListaDeMotes(xNIF);
   FOR v_cNOPRESCRITOS IN cNOPRESCRITOS
   LOOP
      UPDATE VALORES SET PROPU_INSOLVENTE='R',FECHA_PROPUESTA_BAJA=TRUNC(SYSDATE,'DD')
	  WHERE CURRENT OF cNOPRESCRITOS;
   END LOOP;

END;
/


-- --------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ADD_INAPREMIABLE(xNIF IN CHAR)
AS
BEGIN
   INSERT INTO INAPREMIABLES (NIF,FECHA) VALUES (xNIF, SYSDATE);
END;
/
-- --------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DEL_INAPREMIABLE(xNIF IN CHAR)
AS
BEGIN
   DELETE FROM INAPREMIABLES WHERE NIF=xNIF;
END;
/

-- --------------------------------------------------------------------------------------
-- Cierra el expediente y pone todas sus variables en estado neutro.
-- Controla si hay algún trámite en marcha que realice el levantamiento.
-- 25/02/2002 Antonio Pérez Caballero
-- 18/03/2002 Agustin Leon Robles. No hacia levantamientos parciales de cuentas
--
CREATE OR REPLACE PROCEDURE BajasCerrarExpediente(xIDExpe IN INTEGER)
AS
xVivos			INT;
xSuspe			INT;
xEmbargo			Char(1);
BEGIN

	--Leer la traba que habia
	Select EMBARGO INTO xEmbargo from Expedientes where ID=xIDExpe;

	-- Contar las deudas vivas y los suspendidos
	RecibosVivosSuspen(xIDExpe, xVivos,	xSuspe);


	--Si ya no quedan mas recibos se anula el expediente
	IF xVivos=0 AND xSuspe=0 THEN
		UPDATE EXPEDIENTES SET 
			F_ANULACION=SYSDATE,ISOPEN='N',IS_LIVE='N',
			F_ESTADO=SYSDATE,ESTADO='ANULADO',TIPO_ANULACION='NO' 
      	WHERE ID=xIDExpe;

		-- Control del levantamiento de embargos
		-- Levantar los trámites si hubiera alguno en marcha
		LEVANTA_CHECK(xIDExpe, xEMBARGO);

		PkSeguimiento.NotaInformativa(xIDExpe, 
			'Se cierra el expediente al darse de baja una deuda');
	ELSE

		IF xEmbargo='1' THEN -- Diligencia en marcha
	     		CHECK_RETENIDO_LEVANTA(xIDExpe);
		END IF;

	END IF;

END;
/
-- --------------------------------------------------------------------------------------
-- Acción: Dar de baja un valor
-- Modificación: 19/02/2002 Antonio Pérez Caballero
-- Modificación: 25/02/2002 Antonio Pérez Caballero 
--              para que cierre el expediente si es el caso
-- Modificación: 02/12/2002 M. Carmen Junco Gómez. Se incorpora el campo ID de la BAJA en la 
--		  tabla descripcion_baja
-- Modificación: 19/03/2004. Lucas Fernández Pérez.
-- Si el valor está en un expediente se intentan quitar las costas al expediente que tenga.
--
-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- MODIFICACIÓN: 22/04/2005 M. Carmen Junco Gómez. Si se da de baja un valor con principal 
--	bonificado, la baja se tendrá que dar por el importe de la cuota_inicial. Comprobaremos
--	si principal<cuota_inicial; si es así y este principal coincide con el importe bonificado, 
-- se anulará la bonificación, igualando el principal a la cuota inicial y dando la baja.
-- -----------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE MAKE_BAJA(
      xID			IN	INTEGER,
      xTIPO 		IN 	CHAR,
      xFECHA 		IN 	DATE,
      xF_RESOLUCION 	IN 	DATE,
      xORGANISMO 		IN 	VARCHAR2,
      xDESCRIPCION 	IN 	VARCHAR2,
      xERROR 		OUT 	INTEGER)
AS

xPRINCIPAL 		FLOAT DEFAULT 0;
xPRINCIPAL_VALOR FLOAT DEFAULT 0;
xRECARGO_O_E 	FLOAT DEFAULT 0;
xRECARGO 		FLOAT DEFAULT 0;
xRECARGO_VALOR	FLOAT DEFAULT 0;
xCOSTAS 		FLOAT DEFAULT 0;
xCOSTASVALOR	FLOAT DEFAULT 0;
xDEMORA 		FLOAT DEFAULT 0;
xPOR_BONIFICACION	FLOAT DEFAULT 0;
xIMPORTE_BONIFICADO FLOAT DEFAULT 0;
xCARGO 			CHAR(10) ;
xCUOTA_INICIAL 	FLOAT DEFAULT 0;
xTOTAL_DEUDA 	FLOAT DEFAULT 0;
xCONTRA 		CHAR(4);
xID_BAJA 		INTEGER;
xZONA 			CHAR(2);
xAYTO 			CHAR(3);
xVOL_EJE 		CHAR(1);
xCONT 			INTEGER DEFAULT 0;
xSIN_RECARGO 	FLOAT DEFAULT 0;
xRECARGO_5	 	FLOAT DEFAULT 0;
xRECARGO_10 	FLOAT DEFAULT 0;
xRECARGO_20 	FLOAT DEFAULT 0;
xIDExpe 		INTEGER;
xFEXPE			DATE;
xMensaje		VARCHAR2(50);
xCUANTOS		INTEGER;

BEGIN

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	xERROR:=0;

	-- que no haya una data de bajas en la fecha de la baja que vamos a dar

	SELECT COUNT(*) INTO xCONT FROM DATAS_BAJAS
   WHERE FECHA_HASTA>=xFECHA AND ZONA=xZONA;

	IF xCONT <>0 THEN
   	xERROR:=1;
	ELSE		
		
		SELECT CUOTA_INICIAL,PRINCIPAL,IMPORTE_BONIFICADO,POR_BONIFICACION 
		INTO xCUOTA_INICIAL,xPRINCIPAL_VALOR,xIMPORTE_BONIFICADO,xPOR_BONIFICACION
		FROM VALORES WHERE ID=xID;
		
		IF ((xCUOTA_INICIAL>xPRINCIPAL_VALOR) AND (xPRINCIPAL_VALOR=xIMPORTE_BONIFICADO) AND (xPOR_BONIFICACION>0)) THEN
		
			-- si el valor está bonificado, tenemos que anular la bonificación e igualar el principal
			-- a la cuota inicial.			
			UPDATE VALORES SET PRINCIPAL=CUOTA_INICIAL,F_ANULACION_BONI=xFECHA
			WHERE ID=xID;			
		END IF;
	

		SELECT RECARGO,RECARGO_O_E,CUOTA_INICIAL,PRINCIPAL,N_CARGO,YEAR_CONTRAIDO,AYTO,VOL_EJE,
				 EXPEDIENTE,F_IN_EXPEDIENTE
		INTO xRECARGO_VALOR,xRECARGO_O_E,xCUOTA_INICIAL,xPRINCIPAL_VALOR,xCARGO,xCONTRA,xAYTO,xVOL_EJE,
			  xIDExpe,xFEXPE
		FROM VALORES WHERE ID=xID;
	

		PkIngresos.GET_PENDIENTE(xID,xPRINCIPAL,xRECARGO,xCOSTAS,xDEMORA,xTOTAL_DEUDA);
 
		-- Averiguar que porcentaje es el recargo sobre la cuota_inicial 5, 10% o 20%
		IF (xRecargo > 0) THEN

			if Round(xCuota_Inicial * 5 / 100, 2)= xRecargo_Valor then
				xRecargo_5:=xRecargo;
			elsif Round(xCuota_Inicial * 10 / 100, 2)= xRecargo_Valor then
				xRecargo_10:=xRecargo;
			else
				xRecargo_20:=xRecargo;
			end if;

		ELSE

			IF xVol_Eje='E' THEN
				xSin_Recargo:=xPrincipal;
			END IF;

		END IF;


   	INSERT INTO BAJAS(AYTO,ZONA,VALOR,CARGO,YEAR_CONTRAIDO,VOL_EJE,FECHA,MES,YEAR_BAJA,PRINCIPAL,
   		RECARGO_O_E,RECARGO,COSTAS,DEMORA,TIPO_BAJA,RECARGO_5,RECARGO_10,RECARGO_20,SIN_RECARGO)
   	VALUES(xAYTO,xZONA,xID,xCARGO,xCONTRA,xVOL_EJE,xFECHA,TO_CHAR(xFECHA, 'MM'),TO_CHAR(xFECHA,'YYYY'),
			ROUND(xPRINCIPAL,2),ROUND(xRECARGO_O_E,2),ROUND(xRECARGO,2),ROUND(xCOSTAS,2),ROUND(xDEMORA,2),xTIPO,
      	ROUND(xRECARGO_5,2),ROUND(xRECARGO_10,2),ROUND(xRECARGO_20,2),ROUND(xSIN_RECARGO,2))
   	RETURNING ID INTO xID_BAJA;

   	UPDATE VALORES SET FECHA_DE_BAJA=xFECHA, 
								 DEMORA_PENDIENTE=0 , 
								 IS_LIVE='N', 
								 CODIGO_DE_BAJA=xTIPO
   	WHERE ID=xID;

   	INSERT INTO DESCRIPCION_BAJA
			(BAJA,VALOR,F_RESOLUCION,ORGANISMO,DESCRIPCION_BAJA)
   	VALUES
			(xID_BAJA,xID,xF_RESOLUCION,xORGANISMO,xDESCRIPCION);

  		-- Si el valor que se da de baja pertenece a un expediente anotar en el seguimiento
  		IF xIDExpe IS NOT NULL THEN

    		-- Se intentan quitar las costas al expediente que tenga.
    		DELCostaValorPasaAExpe(xIDEXPE,xFEXPE,xID,xERROR);	
    		-- Tras hacer esto, y si no hubo error, las costas del valor han aminorado, y debe
    		--	ajustarse la costa dada de baja de la tabla BAJAS
    		if xERROR=0 then
	  			SELECT COSTAS INTO xCOSTASVALOR FROM VALORES WHERE ID=xID; -- Nuevas costas del valor
	  			SELECT COUNT(*), SUM(COSTAS) INTO xCUANTOS, xCOSTAS FROM INGRESOS WHERE VALOR=xID; 
	  			IF xCUANTOS=0 THEN
	  				xCOSTAS:=0;
	  			END IF;
	  			UPDATE BAJAS SET COSTAS=xCostasValor-xCostas WHERE ID=xID_BAJA;
			end if;

    		IF xTipo='BA' THEN
       		xMensaje:='baja';      
    		END IF;
    		IF xTipo='BR' THEN
       		xMensaje:='reposición a voluntaria';
    		END IF;
    		IF xTipo='BI' THEN
       		xMensaje:='insolvencia';
    		END IF;
    		IF xTipo='BP' THEN
       		xMensaje:='prescripción';
    		END IF;
    		IF xTipo='BO' THEN
       		xMensaje:='otros motivos';
    		END IF;

   		PkSeguimiento.NotaInformativa(xIDExpe,'Se da de baja el valor: '||xID|| ' causa: '||xMensaje );

   		BajasCerrarExpediente(xIDExpe);

  		END IF;

 	END IF;

END;
/

/******************************************************************************************
 Preparar una propuesta de bajas por referencia
 En primer lugar PROPU_INSOLVENTE ->N ->S que un sujeto pasivo está declarado insolvente
 y un valor pasa de voluntaria a ejecutiva
 cuando se realiza la propuesta, este procedimiento, FECHA_PROPUESTA_BAJA -> NULL -> Fecha
 en tercer lugar cuando se dé de baja se le pondrá una fecha de baja
 
MODIFICACIÓN: 26/05/2003 M. Carmen Junco Gómez. Se comprueba que el valor esté asociado
			  a la zona del usuario a través de la tabla propuestas_baja.
******************************************************************************************/
CREATE OR REPLACE PROCEDURE PREPARA_PROPU_BAJAS_REFE(
			xZONA		IN	CHAR,
			xFECHA	IN	DATE)
AS

-- De todos los valores propuestos como insolventes por algún usuario de la zona xZona,
-- bien al dar de alta un nuevo insolvente o al aceptar un cargo con valores de 
-- nif insolvente), que estén con PROPU_INSOLVENTE='S' y estén vivos y aún no tengan 
-- fecha de propuesta

CURSOR c_bajas_refe IS 
SELECT ID FROM VALORES 
	WHERE ID IN (SELECT IDVALOR FROM PROPUESTAS_BAJA WHERE ZONA=xZONA)
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND PROPU_INSOLVENTE='S'
	AND FECHA_PROPUESTA_BAJA IS NULL
	FOR UPDATE OF FECHA_PROPUESTA_BAJA;

BEGIN

   FOR v_cbajas IN c_bajas_refe LOOP
      UPDATE VALORES SET FECHA_PROPUESTA_BAJA=xFECHA WHERE CURRENT OF c_bajas_refe;      
   END LOOP;	

END;
/


-- --------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BAJAS_POR_INSOLVENCIA(
	xFECHA		IN	DATE,
	xF_RESOLUCION 	IN	DATE,
	xORGANISMO 		IN	VARCHAR2,
	xDESCRIPCION_BAJA IN	VARCHAR2,
	xTIPO 		IN	CHAR,
	xCODOPE		IN	INTEGER)
AS

   xERROR INTEGER;

   CURSOR CVALORES IS SELECT ID FROM VALORES WHERE CODIGO_OPERACION=xCODOPE;

BEGIN   

	FOR v_valores IN CVALORES
	LOOP
         MAKE_BAJA(v_valores.ID,xTIPO,xFECHA,xF_RESOLUCION,xORGANISMO,xDESCRIPCION_BAJA,xERROR);
	END LOOP;      	

END;
/
-- --------------------------------------------------------------------------------------
-- 21/02/2002 Antonio Pérez Caballero
--
-- Dar de baja o proponer un concepto año y periodo completo de un ayuntamiento
-- --------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BajasPadronCompleto(
	xFecha 		IN DATE,
	xF_RESOLUCION 	IN DATE,
	xORGANISMO  	IN VARCHAR2,
	xDESCRIPCION_BAJA IN VARCHAR2,
	xMUNICIPIO		IN CHAR,
	xPADRON 		IN CHAR,
	xYEAR 		IN CHAR,
	xPERIODO 		IN CHAR,
	xTIPO 		IN CHAR,
	xBajaPropu		IN Char)
AS

xError INTEGER;

CURSOR CVALORES IS 
	SELECT ID
	FROM VALORES 
	WHERE AYTO=xMUNICIPIO 
	AND PADRON=xPADRON 
	AND YEAR=xYEAR 
	AND PERIODO=xPERIODO 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL;
				  
BEGIN

   IF xBajaPropu='B' THEN

   	FOR vValores IN CVALORES LOOP

      	MAKE_BAJA(vValores.ID,xTIPO,xFECHA,xF_RESOLUCION,xORGANISMO,
                xDESCRIPCION_BAJA,xERROR);

   	END LOOP;

   ELSE

   	UPDATE VALORES SET PROPU_INSOLVENTE='V',
			    CODIGO_DE_BAJA=xTipo,
			    FECHA_PROPUESTA_BAJA=xFECHA
	WHERE AYTO=xMUNICIPIO 
		AND PADRON=xPADRON 
		AND YEAR=xYEAR 
		AND PERIODO=xPERIODO 
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL
		AND PROPU_INSOLVENTE='N';

   END IF;

END;
/


-- --------------------------------------------------------------------------------------
--
-- Crear una propuesta de baja de varios tipos, desde la pantalla de incobrables criterio 
--  valores.
--
CREATE OR REPLACE PROCEDURE PROPU_BAJAS_VARIOS(
         xZONA    		IN  CHAR,
	   	 xAYTO			IN  CHAR,
         xFecha   		IN  DATE,
	   	 xFPropuesta 	IN  DATE)
AS 

   CURSOR CVALORES IS 
      SELECT ID FROM VALORES 
      WHERE PROPU_INSOLVENTE='N' 
	AND FIN_PE_VOL<=xFECHA
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=xZONA)
	AND (F_NOTIFICACION <= xFECHA OR F_NOTIFICACION IS NULL)
   FOR UPDATE OF PROPU_INSOLVENTE,CODIGO_DE_BAJA,FECHA_PROPUESTA_BAJA;

   CURSOR CVAYTO IS
      SELECT ID FROM VALORES 
      WHERE PROPU_INSOLVENTE='N' 
	AND FIN_PE_VOL<=xFECHA
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND AYTO=xAYTO
	AND (F_NOTIFICACION <= xFECHA OR F_NOTIFICACION IS NULL)
   FOR UPDATE OF PROPU_INSOLVENTE,CODIGO_DE_BAJA,FECHA_PROPUESTA_BAJA;

BEGIN

   IF xAYTO='000' THEN -- todos los ayuntamientos de la zona 

      FOR v_valores IN CVALORES
      LOOP     
     
         UPDATE VALORES SET PROPU_INSOLVENTE='V',CODIGO_DE_BAJA='BP',
	   FECHA_PROPUESTA_BAJA=xFPropuesta
   	   WHERE current of CVALORES;

      END LOOP;

   ELSE -- un ayuntamiento en concreto 

      FOR v_valores IN CVAYTO
      LOOP     
     
         UPDATE VALORES SET PROPU_INSOLVENTE='V',CODIGO_DE_BAJA='BP',
	   FECHA_PROPUESTA_BAJA=xFPropuesta
   	   WHERE current of CVAYTO;

      END LOOP;

   END IF;

END;
/

/****************************************************************************************
Autor: 21/02/2002 Antonio Pérez Caballero
Acción: Proponer un valor para baja desde la pantalla de gestión de bajas.
Modificación: 16/06/2003 M. Carmen Junco Gómez. Se pondrá como fecha de propuesta
			  de baja la dada por el usuario desde la aplicación.
Modificación: 17/11/2004 Gloria Maria Calle Hernandez. Se añade actualización de la 
			  descripcion de la baja.
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE BajasPropuestaVarios(
			xIDValor 		IN INTEGER,
			xTipo    		IN CHAR,
			xDescripcion	IN CHAR,
			xFecha	 		IN DATE)
AS 
BEGIN
    
	UPDATE VALORES SET 
		   PROPU_INSOLVENTE='V',
		   CODIGO_DE_BAJA=xTipo,
		   FECHA_PROPUESTA_BAJA=TRUNC(xFecha,'DD')
	WHERE  ID=xIDValor
	  AND  F_INGRESO IS NULL 
	  AND  FECHA_DE_BAJA IS NULL
	  AND  PROPU_INSOLVENTE='N';
	
	UPDATE PROPUESTAS_BAJA SET
		   DESCRIPCION=xDescripcion
	 WHERE IDVALOR=xIDValor;

END;
/

/******************************************************************************************
25/02/2002 Antonio Pérez Caballero
Dar de baja un expediente por ser un expediente incobrable
Si el deudor no es insolvente lo declara como tal

Modificado: 08/01/2003. Lucas Fernández Pérez. 
Actualiza F_ESTADO y pone ESTADO='ANULADO' al anular el expediente
******************************************************************************************/
				 
CREATE OR REPLACE PROCEDURE BajasExpedienteIncoUno(
        xIDExpe IN INTEGER,
        xTipo   IN Char)

AS

   xEXPE char(10);
   xDNI char(10);
   xOBSERVA varchar(1000);
   xCONTADOR INTEGER;   

BEGIN  

   -- Los suspensos no se incluyen pues hay que darlos
   -- de baja en caso de no poder cobrar el expediente 
   UPDATE EXPEDIENTES SET F_ANULACION=TRUNC(SYSDATE,'DD'),TIPO_ANULACION='CI',
				  F_ESTADO = SYSDATE, ESTADO='ANULADO'
   WHERE ID=xIDExpe
   RETURNING EXPEDIENTE,DEUDOR INTO xEXPE,xDNI;

   -- Lo añadimos a la tabla de insolventes, solo en el caso en el que xTipo='BI' 
   IF (xTipo='BI') THEN

   	UPDATE VALORES SET PROPU_INSOLVENTE='S', FECHA_PROPUESTA_BAJA=TRUNC(SYSDATE,'DD'),
				CODIGO_DE_BAJA=xTipo, COD_INGRESO=NULL
   	WHERE EXPEDIENTE=xIDExpe AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL;

	-- comprobar que no sea haya declarado como insolvente anteriormente
      SELECT COUNT(*) INTO xCONTADOR FROM INSOLVENTES WHERE NIF=xDNI;

      IF (xCONTADOR=0) THEN
        xObserva:='ID. EXPEDIENTE: '|| xIDExpe ||'  Nº DE EXPEDIENTE: '|| xExpe ||
                  '  MOTIVO: Insolvencia.';

        INSERT INTO INSOLVENTES
		   (nif, fecha_insolvente, observaciones)
        VALUES 
           (xDNI,TRUNC(SYSDATE,'DD'),xObserva);                      
   
      END IF;
   ELSE
   
    	UPDATE VALORES SET PROPU_INSOLVENTE='V', FECHA_PROPUESTA_BAJA=TRUNC(SYSDATE,'DD'),
                      CODIGO_DE_BAJA=xTipo, COD_INGRESO=NULL
    	WHERE EXPEDIENTE=xIDExpe 
		AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND PROPU_INSOLVENTE='N';		

   END IF;


END;
/

-- --------------------------------------------------------------------------------------
--
-- 25/02/2002 Antonio Pérez Caballero 
-- Proceder a los expedientes incobrables de todos los expedientes de una zona
--
CREATE OR REPLACE PROCEDURE BajasExpedienteIncoTodos(xZONA IN CHAR, xTipo IN CHAR)
AS

-- Expedientes que se intentaron todas las trabas pero no se encontraron
-- datos de estas, sin cuentas , sin salarios, sin casas, etc.

CURSOR cEXPE IS 
	SELECT ID FROM Expedientes
	Where ZONA=xZONA
	AND NOCUENTAS='S'
	AND NOSALARIOS='S'
	AND NOINMUEBLES='S'
	AND NOAUTOS='S'
	AND NOOTROS='S'
    AND f_ingreso is null 
	AND f_anulacion is null 
	AND f_suspension is null;

BEGIN

   FOR  v_cEXPE IN cEXPE  LOOP

	BajasExpedienteIncoUno(v_cEXPE.ID, xTipo);
     
   END LOOP;
 
END;
/
-- --------------------------------------------------------------------------------------
-- Modificado: 08/01/2003. Lucas Fernández Pérez.
-- Sólo pone el expediente a estado 'ABIERTO' si estaba en estado 'ANULADO'
-- Modificado: 01/03/2004. Gloria Maria Calle Hernandez.
-- Sacado Expediente is not null del cursor para hacer comparacion dentro del cursor y hacer 
-- mas rapida la ejecucion del procedimiento
--
CREATE OR REPLACE PROCEDURE REPONER_TODO_CREDITO(
		xCODOPE IN INTEGER)
AS
    CURSOR CEXPE IS 
	SELECT EXPEDIENTE FROM VALORES 
	WHERE CODIGO_OPERACION=xCODOPE 
	GROUP BY EXPEDIENTE;
	

    CURSOR CVALORES IS 
	SELECT ID FROM VALORES 
	WHERE CODIGO_OPERACION=xCODOPE AND EXPEDIENTE IS NULL;

BEGIN

   FOR v_expe IN CEXPE
   LOOP
      IF (v_expe.EXPEDIENTE is not null) THEN
          UPDATE VALORES SET PROPU_INSOLVENTE='N',
				 FECHA_PROPUESTA_BAJA=NULL
           WHERE EXPEDIENTE=v_expe.EXPEDIENTE AND 
		  		 PROPU_INSOLVENTE='V';


          UPDATE EXPEDIENTES SET F_ANULACION=NULL, 
			     TIPO_ANULACION=NULL,
                 ESTADO=DECODE(ESTADO,'ANULADO','ABIERTO',ESTADO), 
		         F_ESTADO=SYSDATE
           WHERE ID=v_expe.EXPEDIENTE;
      END IF;
   END LOOP;


   FOR v_valor IN CVALORES
   LOOP   
      UPDATE VALORES SET PROPU_INSOLVENTE='N',
				 FECHA_PROPUESTA_BAJA=NULL
      WHERE ID=v_valor.ID AND PROPU_INSOLVENTE='V';
   END LOOP;

END;
/

-- --------------------------------------------------------------------------------------
-- Modificado: 08/01/2003. Lucas Fernández Pérez.
-- Sólo pone el expediente a estado 'ABIERTO' si estaba en estado 'ANULADO'
-- MODIFICACIÓN: 26/05/2003 M. Carmen Junco Gómez. Se quita la condición del 
-- update: ayto in (select ayto from municipios where zona=xZona), ya que para
-- torrejón y la zona='01' no existe el ayto='148'
-- también se quita la modificación de la zona del expediente: antes set zona=xZona;

CREATE OR REPLACE PROCEDURE REPONER_CREDITO (
	xZONA IN CHAR,
	xEXPE IN INTEGER)
AS

BEGIN

   UPDATE VALORES SET PROPU_INSOLVENTE='N', 
			    FECHA_PROPUESTA_BAJA=NULL
   WHERE EXPEDIENTE=xEXPE AND PROPU_INSOLVENTE='V';

   UPDATE EXPEDIENTES SET F_ANULACION=NULL,TIPO_ANULACION=NULL,F_ESTADO=SYSDATE,
                          ESTADO=DECODE(ESTADO,'ANULADO','ABIERTO',ESTADO)
   WHERE ID=xEXPE;

END;
/

-- --------------------------------------------------------------------------------------
--
-- último cambio 9 de Mayo 2002 Antonio Pérez Caballero
-- 
-- Para Torrejón de Ardoz se desactiva la zona pues hay una particularidad
-- que la empresa STT tiene asignada todos los recibos Zona=00 y el Ayto debe de procesar
-- bajas Zona=01

-- MODIFICACIÓN: 26/05/2003 M. Carmen Junco Gómez. Se quita la referencia a la zona
-- del usuario. 
CREATE OR REPLACE PROCEDURE REPONER_VALOR_CREDITO(
	xZONA	IN	CHAR,
    xID 	IN 	INTEGER)
AS

BEGIN

   UPDATE VALORES SET 
		PROPU_INSOLVENTE='N',
		FECHA_PROPUESTA_BAJA=NULL
   WHERE ID=xID AND PROPU_INSOLVENTE='V';     
	     

END;
/

/****************************************************************************************
Acción: repone la última baja asociada al valor con id=xID
MODIFICACIÓN: 02/12/2002 M. Carmen Junco Gómez. 
 		      No se estaba seleccionando la máxima baja asociada al valor, con lo cual
            el select podía devolver más de una tupla.
 		      Además se ha añadido en la descripción de la baja el ID de la BAJA.
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez.
			  	Al reponer la baja repondremos los intereses pendientes que tenía el valor
			  	en el momento de darlo de baja.
MODIFICACIÓN: 05/11/2003 Lucas Fernández Pérez. Pone IS_LIVE a 'X' si el recibo está suspendido 
			  	además de anulado (antes lo ponía 'S').
MODIFICACIÓN: 19/03/2004 Lucas Fernández Pérez. Si el valor está en un expediente anulado, le 
			  	quita la anulación al expediente.
MODIFICACIÓN: 22/04/2005 M. Carmen Junco Gómez. Si al dar la baja al valor se anuló una
				posible bonificación para igualar el principal a la cuota inicial, ahora habrá
				que reestablecer la bonificación
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE REPON_BAJA( 
	 xID		IN	INTEGER,
    xERROR 	OUT INTEGER)
AS
	xBAJA	INTEGER;
   xTIPO CHAR(2);
   xFECHA DATE;
   xRECARGO FLOAT DEFAULT 0;
   xDEMORA	FLOAT DEFAULT 0;
   xPOR_BONIFICACION FLOAT DEFAULT 0;
   xIMPORTE_BONIFICADO FLOAT DEFAULT 0;
   xF_ANULACION_BONI DATE;
   xZONA CHAR(2);
   xCONT INTEGER DEFAULT 0;
   xISLIVE CHAR(1);
   xIDEXPE INTEGER;

BEGIN

  	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

  	xERROR:=0;

  	SELECT COUNT(*) INTO xCONT FROM BAJAS
  	WHERE VALOR=xID AND NUMERO_DE_DATA IS NOT NULL;

  	IF xCONT>0 THEN
    	xERROR:=1;
  	ELSE

		-- El max es porque puede haber varias bajas sobre un valor:
		-- Una o mas bajas de aminoracion del principal, y una como maximo del valor.
		-- Ademas, la baja del valor será la última porque una vez hecha no se puede dar de baja
		-- por aminoracion de principal.

		SELECT MAX(ID) INTO xBAJA FROM BAJAS WHERE VALOR=xID;

		SELECT RECARGO,DEMORA,TIPO_BAJA,FECHA INTO xRECARGO,xDEMORA,xTIPO,xFECHA
		FROM BAJAS WHERE ID=xBAJA;
	
  		UPDATE VALORES SET FECHA_DE_BAJA=NULL,CODIGO_DE_BAJA=NULL,
			IS_LIVE=DECODE(F_SUSPENSION,NULL,'S','X'),
			RECARGO=DECODE(xTIPO,'BN',xRECARGO,RECARGO),DEMORA_PENDIENTE=xDEMORA
		WHERE ID=xID RETURNING EXPEDIENTE INTO xIDEXPE;
		
		-- Si el valor estaba bonificado y se anuló en el momento de la baja para igualar
		-- el importe principal a la cuota inicial, ahora tendremos que reponer la
		-- bonificación
		
		SELECT POR_BONIFICACION,IMPORTE_BONIFICADO,F_ANULACION_BONI 
		INTO xPOR_BONIFICACION,xIMPORTE_BONIFICADO,xF_ANULACION_BONI
		FROM VALORES WHERE ID=xID;
		
		IF ((xPOR_BONIFICACION>0) AND (TRUNC(xF_ANULACION_BONI)=TRUNC(xFECHA))) THEN
			UPDATE VALORES SET PRINCIPAL=IMPORTE_BONIFICADO,F_ANULACION_BONI=NULL
			WHERE ID=xID;
		END IF;

		-- Si el valor que se da de baja estaba en un expediente, y el expediente estaba 
		-- anulado, se repone la anulación del expediente.
		IF xIDEXPE IS NOT NULL THEN
	  		SELECT COUNT(*) INTO xCONT 
	  		FROM EXPEDIENTES WHERE ID=xIDEXPE AND F_ANULACION IS NOT NULL;
	  		if xCONT> 0 then
				ANULA_EXPE(xIDEXPE,1,SYSDATE);
	  		end if;
		END IF;
	
		DELETE FROM DESCRIPCION_BAJA WHERE BAJA=xBAJA;
		DELETE FROM BAJAS WHERE ID=xBAJA;
  	END IF;

END;
/

-- --------------------------------------------------------------------------------------
-- MODIFICACIÓN: 02/12/2002 M. Carmen Junco Gómez. Se incluye el campo ID de la BAJA en la 
--		  tabla descripcion_baja.
-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- --------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ANULAR_RECARGO(
	xVALOR 		IN	INT,
	xFECHA 		IN	DATE,
	xF_RESOLUCION 	IN	DATE,
	xORGANISMO 		IN	VARCHAR,
	xDESCRIPCION 	IN	VARCHAR,
   	xSiVoluntaria	IN	CHAR)
AS

 xID_BAJA		INTEGER;
 xRECARGO 		FLOAT DEFAULT 0;
 xCUOTA_INICIAL	FLOAT DEFAULT 0;
 xCARGO 		CHAR(10) ;
 xCONTRA 		CHAR(4);
 xZONA 		CHAR(2);
 xAYTO 		CHAR(3);
 xVOL_EJE 		CHAR(1);
 xMES 		CHAR(2);
 xYEAR_BAJA 	CHAR(4);
 xCONT 		INT DEFAULT 0;
 xSIN_RECARGO 	FLOAT DEFAULT 0;
 xRECARGO_5 	FLOAT DEFAULT 0;
 xRECARGO_10 	FLOAT DEFAULT 0;
 xRECARGO_20 	FLOAT DEFAULT 0;

BEGIN

   SELECT RECARGO,N_CARGO,YEAR_CONTRAIDO,AYTO,VOL_EJE,CUOTA_INICIAL
   	INTO xRECARGO,xCARGO,xCONTRA,xAYTO,xVOL_EJE,xCUOTA_INICIAL
   FROM VALORES 
   WHERE ID=xVALOR;

   -- formato de fecha a 01,02..12
   if month(xfecha) <= 9 then
	xMES:='0' || MONTH(xFECHA);
   else
    	xMES:=MONTH(xFECHA);
   end if;

   xMES:=to_char(xFecha,'mm');
   xYEAR_BAJA:=to_char(xFecha,'yyyy');

   
   -- Averiguar que porcentaje es el recargo sobre la cuota_inicial 10% o 20%
	IF (xRecargo > 0) THEN

		if Round(xCuota_Inicial * 5 / 100, 2)= xRecargo then
			xRecargo_5:=xRecargo;
		elsif Round(xCuota_Inicial * 10 / 100, 2)= xRecargo then
			xRecargo_10:=xRecargo;
		else
			xRecargo_20:=xRecargo;
		end if;	

	END IF;
   
   
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   INSERT INTO BAJAS
	(AYTO,ZONA,VALOR,CARGO,YEAR_CONTRAIDO,
     	VOL_EJE,FECHA,MES,YEAR_BAJA,RECARGO,TIPO_BAJA,RECARGO_5,RECARGO_10,RECARGO_20)
   VALUES
    	(xAYTO,xZONA,xVALOR,xCARGO,xCONTRA,xVOL_EJE,
     	xFECHA,xMES,xYEAR_BAJA,xRECARGO,'BN',xRECARGO_5, xRECARGO_10,xRECARGO_20)
   RETURNING ID INTO xID_BAJA;

   INSERT INTO DESCRIPCION_BAJA
    	(BAJA,VALOR,F_RESOLUCION,ORGANISMO,DESCRIPCION_BAJA)
   VALUES
      (xID_BAJA,xVALOR,xF_RESOLUCION,xORGANISMO,xDESCRIPCION);

   UPDATE USUARIOS SET TEXTO=xDESCRIPCION WHERE USUARIO=USER;

   IF xSiVoluntaria='S' then
	UPDATE VALORES SET RECARGO=0,VOL_EJE='V',F_APREMIO=NULL,DEMORA_PENDIENTE=0 
	WHERE ID=xVALOR;
   else
	UPDATE VALORES SET RECARGO=0 WHERE ID=xVALOR;
   end if;

END;
/

-- --------------------------------------------------------------------------------------
-- Autor: 18/09/2002 Antonio Pérez Caballero
-- Acción: Dar de baja el principal o parte de este.
--      Que un organismo externo nos informe despues de haber realizado el cargo que el 
--      sujeto pasivo ingreso en el organismo externo posteriormente a nuetro cargo y hay 
--      que aminorar el principal o dejar el principal a cero y continuar con recargo 
--      exclusivamente se añade un parámetro nuevo que es opcional importe de la baja xImpBaja.
-- Modificación: 02/12/2002 M. Carmen Junco Gómez. Se incluye el campo ID de la BAJA en 
--  				la tabla descripcion_baja.
-- --------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE ANULAR_Principal(
	xVALOR 		IN	INT,
	xFECHA 		IN	DATE,
	xF_RESOLUCION 	IN	DATE,
	xORGANISMO 		IN	VARCHAR,
	xDESCRIPCION 	IN	VARCHAR,
	xImpBaja		IN 	FLOAT)
AS

 xID_BAJA		INTEGER;
 xCARGO 		CHAR(10) ;
 xCONTRA 		CHAR(4);
 xZONA 		CHAR(2);
 xAYTO 		CHAR(3);
 xVOL_EJE 		CHAR(1);
 xMES 		CHAR(2);
 xYEAR_BAJA 	CHAR(4);
 xCONT 		INT DEFAULT 0;

xPRINCIPAL	 	FLOAT;
xRECARGO		FLOAT;
xCOSTAS 		FLOAT;
xDEMORA 		FLOAT;
xTOTAL_DEUDA 	FLOAT;

BEGIN

   -- Averiguar el Ayto, el Principal, etc.
   SELECT N_CARGO,YEAR_CONTRAIDO,AYTO,VOL_EJE
   	INTO xCARGO,xCONTRA,xAYTO,xVOL_EJE
   FROM VALORES 
   WHERE ID=xVALOR;


   -- Obtenemos el principal pendiente de cobro del valor.
   PkIngresos.GET_PENDIENTE(xValor,xPRINCIPAL,xRECARGO,xCOSTAS, xDEMORA, xTOTAL_DEUDA);

   -- No se puede dar de baja más principal del que hay pendiente
   IF xImpBaja > xPRINCIPAL THEN
   	RETURN;
   END IF;
 
   xMES:=to_char(xFecha,'mm');
   xYEAR_BAJA:=to_char(xFecha,'yyyy');

   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   -- Dar de baja el importe introducido

   INSERT INTO BAJAS
    	(AYTO,ZONA,VALOR,CARGO,YEAR_CONTRAIDO,VOL_EJE,FECHA,MES,YEAR_BAJA,PRINCIPAL,TIPO_BAJA)
   VALUES
    (xAYTO,xZONA,xVALOR,xCARGO,xCONTRA,xVOL_EJE,xFECHA,xMES,xYEAR_BAJA,xImpBaja,'BA')
   RETURNING ID INTO xID_BAJA;

   -- la descripción de la baja
   INSERT INTO DESCRIPCION_BAJA
      (BAJA, VALOR, F_RESOLUCION, ORGANISMO, DESCRIPCION_BAJA)
   VALUES
      (xID_BAJA, xVALOR, xF_RESOLUCION, xORGANISMO, xDESCRIPCION);

   -- ajustar el importe del principal en los valores
   UPDATE VALORES SET PRINCIPAL=PRINCIPAL-xImpBaja
	WHERE ID=xVALOR;

END;
/

-- *******************************************************************
COMMIT;
-- *******************************************************************
