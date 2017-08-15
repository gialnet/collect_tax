-- -----------------------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.Rounds al insertar-modificar en tablas
-- -----------------------------------------------------------------

/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE CONCEPTO_INSERTA (
	xTipo			in	char,
	xAyto			in    char,
	xConcepto		in	Char,
	xReca1		in	Char,
	xReca2		in	Char,
	xReca3		in	Char,
	xReca4		in	Char,
	xReca5		in	Char,
	xReca6		in	Char,
	xReca7		in	Char
)
AS
BEGIN
   IF xTipo='I' THEN
      INSERT INTO CONCEPTOS_TITULOS (AYTO,CONCEPTO,
		RECA1,RECA2,RECA3,RECA4,RECA5,RECA6,RECA7)
      VALUES (xAYTO,xCONCEPTO,xRECA1,xRECA2,xRECA3,xRECA4,xRECA5,xRECA6,xRECA7);
   ELSE
      UPDATE CONCEPTOS_TITULOS SET RECA1=xRECA1,RECA2=xRECA2,
		 RECA3=xRECA3,RECA4=xRECA4,RECA5=xRECA5,RECA6=xRECA6,RECA7=xRECA7
      WHERE AYTO=xAYTO AND CONCEPTO=xCONCEPTO;
   END IF;
END;
/

/*****************************************************************************************/


CREATE OR REPLACE PROCEDURE ADDMODSUCURSALES(
	xMODO	     IN	 	CHAR,
	xID 	     IN OUT		INTEGER,
	xENTIDAD   IN OUT		CHAR,
	xOFICINA   IN		CHAR,
	xDIRE      IN		CHAR,
	xPOBLA     IN		CHAR,
	xPOSTAL    IN		CHAR
)
AS

BEGIN
IF xMODO='I' THEN
   INSERT INTO SUCURSALES
     (ENTIDAD,OFICINA,DIRECCION,POBLACION,CODPOSTAL) 
   VALUES 
     (SUBSTR(xENTIDAD,1,4),SUBSTR(xOFICINA,1,4),SUBSTR(xDIRE,1,50),SUBSTR(xPOBLA,1,50),
	SUBSTR(xPOSTAL,1,5));

   SELECT LAST_NUMERO INTO xID FROM USUARIOS WHERE USUARIO=USER;
ELSE
  UPDATE SUCURSALES SET ENTIDAD=SUBSTR(xENTIDAD,1,4),OFICINA=SUBSTR(xOFICINA,1,4),
         DIRECCION=SUBSTR(xDIRE,1,50),POBLACION=SUBSTR(xPOBLA,1,50),
	   CODPOSTAL=SUBSTR(xPOSTAL,1,5)
  WHERE ID=xID;
END IF;

END;
/

/*******************************************************************************************
MODIFICACIÓN: 01/10/2002 M. Carmen Junco Gómez. Indicamos si la cuenta pertenece o no a un
		  Organismo Externo.
Modificado: 07/10/2002 Agustin Leon Robles. Nuevo parametro para saber si es una cuenta
		de reguralizacion de entregas a cuenta no aplicadas.
DELPHI
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE CUENT_SERVICIO(
	xENTIDAD 		IN		CHAR,
	xID 			IN 		INT,
	xOFICINA 		IN		CHAR,
	xDC 			IN		CHAR,
	xCUENTA 		IN		CHAR,
	xDIRE 		IN		VARCHAR,
	xPOBLA 		IN		VARCHAR,
	xPOSTAL 		IN		CHAR,
	xEXTERNO		IN		CHAR,
	xREGULARIZACION	IN 		CHAR,
	xZONA			IN		CHAR)
AS

BEGIN

IF xID=0 THEN
   INSERT INTO CUENTAS_SERVICIO
      (ENTIDAD,OFICINA,DC,CUENTA,DIRECCION,POBLACION,
       CODPOSTAL,SALDO,ORGANISMO_EXT,REGULARIZACION,ZONA)
   VALUES
      (xENTIDAD,xOFICINA,xDC,xCUENTA,xDIRE,xPOBLA,xPOSTAL, 0, xEXTERNO, xREGULARIZACION,xZONA);

ELSE
   UPDATE CUENTAS_SERVICIO SET ENTIDAD=xENTIDAD,OFICINA=xOFICINA,
          DC=xDC,CUENTA=xCUENTA,DIRECCION=xDIRE,
	    POBLACION=xPOBLA,CODPOSTAL=xPOSTAL,
	    ORGANISMO_EXT=xEXTERNO,REGULARIZACION=xREGULARIZACION,ZONA=xZONA
   WHERE ID=xID;
END IF;

END;
/

/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE ADDMOD_VEHI(
		xID        IN INTEGER,
	      xNIF       IN CHAR,
	      xMATRICULA IN CHAR,
		xMARCA     IN CHAR,
		xMODELO    IN CHAR)

AS
BEGIN

   IF (xID=0) THEN
	INSERT INTO VEHICULOSR(NIF,MARCA,MODELO,MATRICULA)
	VALUES(xNIF,xMARCA,xMODELO,xMATRICULA);
   ELSE
	UPDATE VEHICULOSR SET MATRICULA=xMATRICULA,
			MARCA=xMARCA,MODELO=xMODELO
      WHERE ID=xID;
   END IF;
END;
/

/*****************************************************************************************/



--
--
-- Modificado: 22 de Mayo de 2002: Agustin Leon Robles. Se le añade la opcion para modificar
--		recibos por grupos
--
CREATE OR REPLACE PROCEDURE CHG_DATOS_VALOR (
			xID       	IN    INTEGER,
		      xNIF      	IN    CHAR, 
		      xNOMBRE   	IN    CHAR,
			xGrupo	IN	integer)
AS
BEGIN

	if xGrupo=0 then
		UPDATE VALORES SET NIF=xNIF,NOMBRE=xNOMBRE WHERE ID=xID;
	else
		UPDATE VALORES SET NIF=xNIF,NOMBRE=xNOMBRE WHERE Codigo_Operacion=xGrupo;
	end if;

END;
/


/*****************************************************************************************/

CREATE OR REPLACE PROCEDURE CODIGO_OPERACION(mOperacion OUT INTEGER)
AS
BEGIN

SELECT GENCodOpeValres.NEXTVAL INTO mOperacion FROM DUAL;

UPDATE USUARIOS SET CODIGO_OPERACION=mOperacion WHERE USUARIO=USER; 

END;
/

/*****************************************************************************************/

/*para modificar las fechas de un cargo*/
CREATE OR REPLACE PROCEDURE MODIFICACARGOS(
	 xID		IN	INTEGER,
       xCARGO     IN    CHAR,
       xAYTO      IN	CHAR,
       xFCARGO    IN	DATE,
       xFIN       IN	DATE,
       xFAPREMIO  IN	DATE)
AS
xPADRON	CHAR(6);
xYEAR		CHAR(4);
xPERIODO	CHAR(2);
xTIPO_DE_OBJETO	CHAR(1);
xYEAR_CONTRAIDO	CHAR(4);
BEGIN

	UPDATE CARGOS SET F_CARGO=xFCARGO 
	WHERE CARGO=xCARGO and AYTO=xAYTO;

	UPDATE DESGLOSE_CARGOS SET 
				INI_PER_VOLUN=xFIN-60, 
			      FIN_PER_VOLUN=xFIN
	WHERE ID=xID
	RETURNING PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,YEAR_CONTRAIDO
	INTO xPADRON,xYEAR,xPERIODO,xTIPO_DE_OBJETO,xYEAR_CONTRAIDO;

	UPDATE VALORES SET F_CARGO=xFCARGO,
				FIN_PE_VOL=xFIN,
				F_APREMIO=xFAPREMIO
	WHERE N_CARGO=xCARGO and AYTO=xAYTO
		AND PADRON=xPADRON
		AND YEAR=xYEAR
		AND PERIODO=xPERIODO
		AND TIPO_DE_OBJETO=xTIPO_DE_OBJETO
		AND YEAR_CONTRAIDO=xYEAR_CONTRAIDO;

END;
/


/*****************************************************************************************/

CREATE OR REPLACE FUNCTION DAME_NUMEROS(
    	xYEAR  IN  char, 
	xNum   IN  integer)
RETURN VARCHAR2
AS
BEGIN

/* anteriormente se devolvía este valor; se quita al incrementar dos veces el número: una
   vez antes de llamar a esta función, y otra aquí dentro */

   /*RETURN xYear || '/' || LPAD(xNum+1,5,'0');*/


   RETURN xYEAR || '/' || LPAD(xNum,5,'0');

END;
/

/********************************************************************/

-- **Insertar valores manualmente**
-- El parametro xTipo puede tener el valor 'XX' recibo grabado manualmente, 
-- que se graba el el campo CODIGO_DE_BAJA de la tabla VALORES
-- por razones de copmpatibilidad con versiones anteriores
-- para otros usos como puede ser altas de una liquidación en voluntaria este campo 
-- debe estar a nulo.
-- Última modificación: 04/08/2001 Antonio Pérez Caballero
-- Ultima modificación: 07/02/2002 Agustin Leon Robles

-- Ultima modificación: 26/01/2004 Agustin Leon Robles
-- Para el cargo se toma en cuenta el campo cuota inicial en vez del principal
CREATE OR REPLACE PROCEDURE INSERTAVALORES(
	xPadron 		IN		char,
	xYear 			IN		char,
	xPeri 			IN		char,
	xRecibo 		IN		char,
	xDNI 			IN		char,
	xNombre 		IN		varchar,
	xFCargo 		IN		date,
	xNumCargo 		IN		char,
    xAYTO			IN		CHAR,
	xInicio			IN		date,
	xFin 			IN		date,
	xF_NOTIFI 		IN		date, 
	xNoti 			IN		char,
	xCertifi 		IN		char,
	xDomicilio 		IN		varchar,
	xTipo 			IN		char,
	xTipo_Objeto	IN		char,
	xObjeto 		IN		varchar,
	xContraido 		IN		char,
	xCuotaInicial	IN		float,
	xPrincipal 		IN		float,
	xRecargo 		IN		float,
	xCostas 		IN		float,
	xDemora 		IN		float,
	xVol_Eje 		IN		char,
	xFProvi 		IN 		date,
	xSiFecha 		IN		char,
	xCLAVE_CONCEPTO IN		CHAR,
	xCLAVE_RECIBO	IN		INTEGER,
      xVALOR		OUT		INTEGER)
AS
   xZONA		CHAR(2);
   xTIPO_TRIBUTO  CHAR(2);
   xFechaCargo	date;
BEGIN

	select zona into xZona from municipios where ayto=xAyto;

	BEGIN
		SELECT TIPO_TRIBUTO INTO xTIPO_TRIBUTO FROM CONTADOR_CONCEPTOS 
			WHERE MUNICIPIO=xAYTO AND CONCEPTO=xPadron;
	EXCEPTION
		When no_data_found then
			xTIPO_TRIBUTO:=NULL;
	END;
		

	UPDATE CARGOS SET RECIBOS=RECIBOS+1,TOTAL_CARGO=TOTAL_CARGO+ROUND(xCuotaInicial,2)
	where cargo=xNumCargo AND ayto=xAYTO 
	return F_Cargo into xFechaCargo;

	--si no existe el cargo lo creamos
	IF SQL%NOTFOUND THEN

		-- insertamos el cargo
		Insert Into cargos (CARGO,AYTO,RECIBOS,TOTAL_CARGO,APREMIADO,VOL_EJE,F_CARGO)
		values (xNumCargo,xAyto,1,ROUND(xCuotaInicial,2),xNoti,xVol_Eje,xFCargo);

		xFechaCargo:=xFCargo;
	END IF;

	INSERT INTO VALORES 
		(PADRON,YEAR,PERIODO,RECIBO,NIF,NOMBRE,F_CARGO,N_CARGO,FIN_PE_VOL,
		F_APREMIO,CERT_DESCUBIERTO,DOM_TRIBUTARIO,
		CODIGO_DE_BAJA,TIPO_DE_OBJETO,OBJETO_TRIBUTARIO,YEAR_CONTRAIDO,
		CUOTA_INICIAL,PRINCIPAL,RECARGO,COSTAS,DEMORA_PENDIENTE,VOL_EJE,
		AYTO,CLAVE_CONCEPTO,CLAVE_RECIBO,TIPO_DE_TRIBUTO,NOTIFICADO,F_NOTIFICACION)
	VALUES 
		(xPadron,xYear,xPeri,xRecibo,xDNI,xNombre,xFechaCargo,xNumCargo,xFin,
		DECODE(xSiFecha,'N',NULL,xFProvi),
		xCertifi,xDomicilio,xTipo,xTipo_Objeto,xObjeto,xContraido,
		ROUND(xCuotaInicial,2),ROUND(xPrincipal,2),ROUND(xRecargo,2),ROUND(xCostas,2),
		ROUND(xDemora,2),xVol_Eje,xAYTO,xCLAVE_CONCEPTO,
		DECODE(xCLAVE_RECIBO,0,NULL,xCLAVE_RECIBO),
		xTIPO_TRIBUTO,xNOTI, DECODE(xNOTI,'S',xF_NOTIFI, NULL) )
	RETURNING ID INTO xVALOR;
	

	UPDATE DESGLOSE_CARGOS SET RECIBOS=RECIBOS+1,
				TOTAL_CARGO=TOTAL_CARGO+ROUND(xCuotaInicial,2)
	
	WHERE CARGO=xNumCargo AND AYTO=xAyto 
			AND PADRON=xPADRON AND YEAR=xYEAR 
			AND PERIODO=xPERI AND TIPO_DE_OBJETO=xTIPO_OBJETO 
			AND YEAR_CONTRAIDO=xCONTRAIDO;

	--si no existe el desglose lo creamos
	IF SQL%NOTFOUND THEN

		-- si se trata de una liquidacion no se insertan fechas
		INSERT INTO DESGLOSE_CARGOS (CARGO,AYTO,PADRON,YEAR,PERIODO,TIPO_DE_OBJETO,
			YEAR_CONTRAIDO,RECIBOS,TOTAL_CARGO,INI_PER_VOLUN,FIN_PER_VOLUN)

		VALUES (xNumCargo,xAyto,xPadron,xYear,xPeri,xTipo_Objeto,xContraido,1,
			ROUND(xCuotaInicial,2),
			DECODE(xTipo_Objeto,'R',xInicio,NULL),	
			DECODE(xTipo_Objeto,'R',xFin,NULL));
	END IF;

END;
/



/********************************************************************/


-- MODIFICAR VALORES MANUALMENTE 
-- Ultima modificación: 07/02/2002 Agustin Leon Robles
CREATE OR REPLACE PROCEDURE MODIFICAVALORES(
	xID				IN		INTEGER,
	xDNI 				IN		char,
	xNombre 			IN		char,
	xFin 				IN		date,
	xF_NOTIFI 			IN		date, 
	xNoti 			IN		char,
	xCertifi 			IN		char,
	xDomicilio 			IN		char,
	xTipo 			IN		char,
	xObjeto 			IN		char,
	xCuotaInicial 		IN		float,
	xPrincipal 			IN 		float,
	xRecargo 			IN		float,
	xCostas 			IN		float,
	xDemora 			IN		float,
	xVol_Eje 			IN		char,
	xFProvi 			IN 		date,
	xSiFecha 			IN		char,
	xCLAVE_CONCEPTO   	IN		CHAR)
AS
xPrincipalAnterior	float default 0;
xCargo			char(10);
xAyto				char(3);
xPadron			char(6);
xYear				char(4);
xPeri				char(2);
xTipoObjeto			char(1);
xContraido			char(4);
BEGIN

	
	select principal,n_cargo,Ayto,padron,year,periodo,tipo_de_objeto,year_contraido
		into xPrincipalAnterior,xCargo,xAyto,xPadron,xYear,xPeri,xTipoObjeto,xContraido
		from valores where ID=xID;

	Update valores set NIF=xDNI,NOMBRE=xNombre,
   			      FIN_PE_VOL=xFin,F_APREMIO=DECODE(xSiFecha,'N',NULL,xFProvi),
			      CERT_DESCUBIERTO=xCertifi,
			      DOM_TRIBUTARIO=xDomicilio,CODIGO_DE_BAJA=xTipo,
                        OBJETO_TRIBUTARIO=xObjeto,
                        CUOTA_INICIAL=ROUND(xCuotaInicial,2),PRINCIPAL=ROUND(xPrincipal,2),
                        RECARGO=ROUND(xRecargo,2),COSTAS=ROUND(xCostas,2),
				DEMORA_PENDIENTE=ROUND(xDemora,2),
                        VOL_EJE=xVol_Eje,CLAVE_CONCEPTO=xCLAVE_CONCEPTO,
                        NOTIFICADO=xNoti,
				F_NOTIFICACION=DECODE(xNoti,'S',xF_NOTIFI,NULL)
	where ID=xID;

	update cargos set Total_cargo=Total_cargo - xPrincipalAnterior + xPrincipal
			where cargo=xCargo and ayto=xAyto;

	update desglose_cargos set Total_cargo=Total_cargo - xPrincipalAnterior + xPrincipal
			WHERE CARGO=xCargo AND AYTO=xAyto 
			AND PADRON=xPADRON AND YEAR=xYEAR 
			AND PERIODO=xPERI AND TIPO_DE_OBJETO=xTipoObjeto
			AND YEAR_CONTRAIDO=xContraido;


END;
/

--
-- borrar valores manualmente 
--  Ultima modificacion: 07/02/2002 Agustin Leon Robles
CREATE OR REPLACE PROCEDURE borrar_valores(
	xID			IN	INTEGER,
      xCARGO		IN	CHAR,
	xAYTO			IN	CHAR,
	xPADRON		IN	CHAR,
	xYEAR			IN	CHAR,
	xPERI			IN	CHAR,
	xTIPO_OBJETO 	IN 	CHAR,
	xCONTRAIDO		IN	CHAR,
	xERROR		OUT	INTEGER)
AS

xCONT 	INTEGER;
xPRINCIPAL	FLOAT;

BEGIN

  SELECT COUNT(*) INTO xCONT FROM INGRESOS WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=1;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM BAJAS WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=2;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM DESCRIPCION_BAJA WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=2;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM SUSPENSIONES_VALORES WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=3;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM PLAZOS_FRAC WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=4;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM NOTIFICACIONES WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=5;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM ACUMULAR_DETALLE WHERE IDVALOR=xID;

  IF xCONT>0 THEN
     xERROR:=6;
     RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM INCIDENCIASR WHERE VALOR=xID;

  IF xCONT>0 THEN
     xERROR:=7;
     RETURN;
  END IF;

  xERROR:=0;

  delete from historia_valores where VALOR=xID;

  delete from costas_valores where VALOR=xID;
  
  delete from DESGLOSE_valores where VALOR=xID;

  SELECT PRINCIPAL INTO xPrincipal FROM VALORES where ID=xID;

  delete from valores where ID=xID;


  UPDATE CARGOS SET RECIBOS=RECIBOS-1,TOTAL_CARGO=TOTAL_CARGO-xPrincipal
     where cargo=xCARGO AND AYTO=xAYTO;

  --se borraria en el caso de que no tengamos recibos
  DELETE FROM CARGOS WHERE cargo=xCARGO AND AYTO=xAYTO AND RECIBOS<=0;

  --si se ha borrado en cargos, directamente se borra en el desglose del cargo
  IF SQL%FOUND THEN
      DELETE FROM DESGLOSE_CARGOS WHERE CARGO=xCargo AND AYTO=xAYTO;
	RETURN;
  END IF;


  UPDATE DESGLOSE_CARGOS SET RECIBOS=RECIBOS-1,TOTAL_CARGO=TOTAL_CARGO-xPrincipal
     WHERE CARGO=xCargo AND AYTO=xAYTO AND PADRON=xPADRON AND YEAR=xYEAR AND
	     PERIODO=xPERI AND TIPO_DE_OBJETO=xTIPO_OBJETO AND YEAR_CONTRAIDO=xCONTRAIDO;

  DELETE FROM DESGLOSE_CARGOS WHERE CARGO=xCargo AND AYTO=xAYTO AND 
	     PADRON=xPADRON AND YEAR=xYEAR AND PERIODO=xPERI AND 
	     TIPO_DE_OBJETO=xTIPO_OBJETO AND YEAR_CONTRAIDO=xCONTRAIDO AND RECIBOS<=0;   

END;
/


/********************************************************************
 Rellena la tabla temporal sobre el informe de desglose de valores.
 MODIFICADO: 18/03/2005. Gloria María Calle Hernandez. Con sursores dinámicos fallaba al motar la consulta
 		sobre el pendiente de cobro, pues si tres veces se hace referencia en la consulta al parámetro
 		xFechaDesde, tres veces habría q pasarselo al cursor dinamico al abrirlo... Entonces montada
 		por completo desde Delphi.
 MODIFICADO: 19/04/2005. Gloria María Calle Hernandez. Cuando es un informe de bajas toma el importe dado 
 		de baja para calcular los importes de desglose proporcionalmente.
 MODIFICADO: 19/05/2005. Lucas Fernández Pérez. Nuevo campo AYTO en la tabla TMP_DESGLOSE_VALORES
*********************************************************************/
CREATE OR REPLACE PROCEDURE FILL_TMP_DESGLOSE_VALORES  (
	   xSentencia		CHAR,
	   xTipoInforme		CHAR,
  	   xFDesde	  		DATE,
	   xFHasta	  		DATE)
AS
  -- Variables para crear la sentencia
  TYPE tCURSOR IS REF CURSOR;  -- define REF CURSOR type
  vCURSOR    	 	  tCURSOR; -- declare cursor variable
  TYPE tReg IS RECORD (
       VALOR   		    INTEGER,
       AYTO             CHAR(3),
	   PADRON			CHAR(6),
	   YEAR				CHAR(4),
	   PERIODO			CHAR(2),
	   RECIBO			INTEGER,
	   NIF		  		CHAR(10),
	   NOMBRE			CHAR(40),
	   TIPO_DE_OBJETO	CHAR(1),
	   FECHA			DATE,
	   VOL_EJE			CHAR(1),
	   IMPORTE			FLOAT,
	   PRINCIPAL		FLOAT,
	   RECARGO			FLOAT,
	   COSTAS			FLOAT,
	   DEMORA			FLOAT);
  vREG 				  tReg;
    
  vSumPrincipal		  FLOAT;
  vSumRecargo		  FLOAT;
  vSumCostas		  FLOAT;
  vSumDemora		  FLOAT;
  vPrincipal		  FLOAT;
  vRecargo		  	  FLOAT;
  vCostas		  	  FLOAT;
  vDemora		  	  FLOAT;
  vTotal			  FLOAT;
  vSUMTotal			  FLOAT;
 
  vSI_PROPORCIONAL1		CHAR(1);
  vIMPORTE1				FLOAT;
  vSI_PROPORCIONAL2		CHAR(1);
  vIMPORTE2				FLOAT;
  vSI_PROPORCIONAL3		CHAR(1);
  vIMPORTE3				FLOAT;
  vSI_PROPORCIONAL4		CHAR(1);
  vIMPORTE4				FLOAT;
  vSI_PROPORCIONAL5		CHAR(1);
  vIMPORTE5				FLOAT;
  vSI_PROPORCIONAL6		CHAR(1);
  vIMPORTE6				FLOAT;
  vSI_PROPORCIONAL7		CHAR(1);
  vIMPORTE7				FLOAT;

BEGIN

   DELETE TMP_DESGLOSE_VALORES WHERE USUARIO=USER;
   
   --Asignar consulta a cursor, abrirlo y recorrerlo 
   IF (xTipoInforme='P') then
       OPEN vCURSOR FOR xSENTENCIA;
   ELSE
       OPEN vCURSOR FOR xSENTENCIA USING xFDesde,xFHasta;
   END IF;
   	   
   LOOP
   	    FETCH vCURSOR INTO vReg;
   	   	EXIT WHEN vCURSOR%NOTFOUND;

		vSumPrincipal:= 0;
		vSumRecargo:= 0;
		vSumCostas:= 0;
		vSumDemora:= 0;

        IF xTipoInforme='P' THEN --pendiente de cobro 
	 	   BEGIN
		   	  select sum(principal) as vSumPrincipal,sum(recargo) as vSumRecargo,
			         sum(costas) as sumcostas,sum(demora) as sumdemora
				into vSumPrincipal, vSumRecargo, vSumCostas, vSumDemora
				from ingresos 
			   where VALOR=vReg.VALOR and PARCIAL_O_COBRO='P' and trunc(fecha,'dd')<=xFDesde;
		   EXCEPTION
			   WHEN NO_DATA_FOUND THEN
			   		vSumPrincipal:= 0;
					vSumRecargo:= 0;
					vSumCostas:= 0;
					vSumDemora:= 0;
		   END;
	    ELSIF xTipoInforme='B' THEN --dado de baja
	 	   BEGIN
		   	  select sum(principal) as vSumPrincipal,sum(recargo) as vSumRecargo,
			         sum(costas) as sumcostas,sum(demora) as sumdemora
				into vSumPrincipal, vSumRecargo, vSumCostas, vSumDemora
				from importe_bajas
			   where VALOR=vReg.VALOR and Tipo_baja='BA' and trunc(fecha,'dd')<=xFDesde;
		   EXCEPTION
			   WHEN NO_DATA_FOUND THEN
			   		vSumPrincipal:= 0;
					vSumRecargo:= 0;
					vSumCostas:= 0;
					vSumDemora:= 0;
		   END;
		END IF;

        vPRINCIPAL:= vReg.PRINCIPAL-vSumPrincipal;
        vRECARGO:= vReg.RECARGO-vSumRecargo;
        vDEMORA:= vReg.DEMORA-vSumDemora;
        vCOSTAS:= vReg.COSTAS-vSumCostas;

		BEGIN
			SELECT SI_PROPORCIONAL1,IMPORTE1,SI_PROPORCIONAL2,IMPORTE2,SI_PROPORCIONAL3,IMPORTE3,
				   SI_PROPORCIONAL4,IMPORTE4,SI_PROPORCIONAL5,IMPORTE5,SI_PROPORCIONAL6,IMPORTE6,
				   SI_PROPORCIONAL7,IMPORTE7
			  INTO vSI_PROPORCIONAL1,vIMPORTE1,vSI_PROPORCIONAL2,vIMPORTE2,vSI_PROPORCIONAL3,vIMPORTE3,
				   vSI_PROPORCIONAL4,vIMPORTE4,vSI_PROPORCIONAL5,vIMPORTE5,vSI_PROPORCIONAL6,vIMPORTE6,
				   vSI_PROPORCIONAL7,vIMPORTE7
			  FROM DESGLOSE_VALORES WHERE VALOR=vReg.VALOR;
		EXCEPTION
			  WHEN NO_DATA_FOUND THEN
			  	   vSI_PROPORCIONAL1:= null;
			  	   vIMPORTE1:= 0;
			  	   vSI_PROPORCIONAL2:= null;
			  	   vIMPORTE2:= 0;
			  	   vSI_PROPORCIONAL3:= null;
			  	   vIMPORTE3:= 0;
			  	   vSI_PROPORCIONAL4:= null;
			  	   vIMPORTE4:= 0;
			  	   vSI_PROPORCIONAL5:= null;
			  	   vIMPORTE5:= 0;
			  	   vSI_PROPORCIONAL6:= null;
			  	   vIMPORTE6:= 0;
			  	   vSI_PROPORCIONAL7:= null;
			  	   vIMPORTE7:= 0;
		END;

		vSUMTotal:= 0;
   		IF (vSI_PROPORCIONAL1='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE1;
		END IF;
   		IF (vSI_PROPORCIONAL2='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE2;
		END IF;
   		IF (vSI_PROPORCIONAL3='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE3;
		END IF;
   		IF (vSI_PROPORCIONAL4='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE4;
		END IF;
   		IF (vSI_PROPORCIONAL5='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE5;
		END IF;
   		IF (vSI_PROPORCIONAL6='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE6;
		END IF;
   		IF (vSI_PROPORCIONAL7='S') THEN
		    vSUMTotal:= vSUMTotal+vIMPORTE7;
		END IF;

   		IF (xTipoInforme='P' AND vPRINCIPAL>0 OR xTipoInforme='I' OR xTipoInforme='B') AND 
		    vSUMTotal > 0 THEN
   		   vIMPORTE1:=(vImporte1*vPRINCIPAL) / vSUMTOTAL;
      	   vIMPORTE2:=(vImporte2*vPRINCIPAL) / vSUMTOTAL;
      	   vIMPORTE3:=(vImporte3*vPRINCIPAL) / vSUMTOTAL;
      	   vIMPORTE4:=(vImporte4*vPRINCIPAL) / vSUMTOTAL;
      	   vIMPORTE5:=(vImporte5*vPRINCIPAL) / vSUMTOTAL;
      	   vIMPORTE6:=(vImporte6*vPRINCIPAL) / vSUMTOTAL;
      	   vIMPORTE7:=(vImporte7*vPRINCIPAL) / vSUMTOTAL;
   		END IF;
		
		
		BEGIN
		   INSERT INTO TMP_DESGLOSE_VALORES (USUARIO,AYTO,PADRON,YEAR,PERIODO,RECIBO,NIF,NOMBRE,VOL_EJE,TIPO_DE_OBJETO,
			   							  F_INGRESO,F_BAJA,PRINCIPAL,RECARGO,DEMORA,COSTAS,TOTAL,
										  IMPORTE1,IMPORTE2,IMPORTE3,IMPORTE4,IMPORTE5,IMPORTE6,IMPORTE7)
		   VALUES (USER,vReg.AYTO,vReg.PADRON,vReg.YEAR,vReg.PERIODO,vReg.RECIBO,vReg.NIF,vReg.NOMBRE,vReg.VOL_EJE,vReg.TIPO_DE_OBJETO,
  		 	    DECODE(xTipoInforme,'B',null,vReg.FECHA),DECODE(xTipoInforme,'B',vReg.FECHA,null),
				vPRINCIPAL,vRECARGO,vDEMORA,vCOSTAS,vReg.IMPORTE,
				vIMPORTE1,vIMPORTE2,vIMPORTE3,vIMPORTE4,vIMPORTE5,vIMPORTE6,vIMPORTE7);
		EXCEPTION
		   WHEN OTHERS THEN
		   		NULL;
		END;

  END LOOP;

END;
/

/********************************************************************/
COMMIT;
/********************************************************************/
