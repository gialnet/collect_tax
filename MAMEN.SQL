CREATE OR REPLACE PROCEDURE Arreglar_fin_pe_vol
AS
    xNoti 			 char(1);
	xDIA             INTEGER;
	xMES             INTEGER;
	xYEAR            INTEGER;
	NDIA             INTEGER;
	NMES             INTEGER;
	NYEAR            INTEGER;
	xFECHA_CAD       CHAR(19);
	xIDNOTI			 INTEGER;

	cursor c1 is select * from liquidaciones where f_notificacion is not null;

BEGIN

   FOR v1 IN C1
   LOOP

      NDIA:=DAYOFMONTH(v1.F_NOTIFICACION);
      NMES:=MONTH(v1.F_NOTIFICACION);
      NYEAR:=F_YEAR(v1.F_NOTIFICACION);
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
      xFECHA_CAD:= xDia||'/'||xMes||'/'||xYear;

      -- por defecto
      xNOTI:='N';

      begin
         select ID,NOTIFICADO INTO xIDNOTI,xNOTI from notificaciones
		 where valor=v1.IDVALOR AND TIPO_NOTI='VOL';
		 Exception
		 	When no_data_found then
		 		xIDNOTI:=0;
	  end;

	  -- si existe la notificación del valor, actualizamos la fecha del final
	  -- del periodo voluntario en VALORES, pero sólo si la notificación
	  -- fue positiva

      IF (xIDNOTI>0) THEN
	     -- si el valor no tiene FIN_PE_VOL, se pone el calculado;
	     -- si tiene y la notificación es negativa se deja la fecha que tuviera;
	     -- si tiene y la notificación es positiva se cambia por la fecha calculada;
	     IF (xNOTI='S') THEN
	        UPDATE VALORES SET FIN_PE_VOL=TO_DATE(xFECHA_CAD,'dd/mm/yyyy')
	        WHERE ID=v1.IDVALOR;
	     END IF;

      END IF;


      -- Para la tabla de LIQUIDACIONES
      IF (xNOTI='S') THEN
         UPDATE LIQUIDACIONES SET F_FIN_PE_VOL=TO_DATE(xFECHA_CAD,'dd/mm/yyyy')
	     WHERE ID=v1.ID;
      END IF;

   END LOOP;

END;
/


/*******************************************************************************************/

create or replace procedure InsertarDesgloseSoportes as
   xID integer;   
   cursor c1 is select id from histo_soportes where id not in 
	   			(select id_histo_soportes from desglose_histo_soportes)
				and id in 
				(select distinct id_histo_soportes from incidencias_c60); 
				
   cursor c2 is select municipio,padron,year,periodo,rtrim(modalidad) as modalidad,
   				sum(importe) AS IMPORTE,count(*) AS CUANTOS       			
      			from incidencias_c60
	  			where id_histo_soportes=xID
      			group by municipio,padron,year,periodo,modalidad;
begin
   for v1 in c1
   loop
      xID:=v1.ID;
      for v2 in c2
      loop
         if (v2.MODALIDAD='MOD1') then
            insert into desglose_histo_soportes
            	(id_histo_soportes,modalidad,municipio,
                 padron,year,periodo,importe,ncobros,aplicado)
            values 
                (xID,'MOD1',v2.Municipio,v2.Padron,v2.Year,v2.Periodo,
                 v2.Importe,v2.Cuantos,'S'); 
         elsif (v2.MODALIDAD='MOD2CP') then
            insert into desglose_histo_soportes
            	(id_histo_soportes,modalidad,importe,ncobros,aplicado)
            values
                (xID,'MOD2CP',v2.Importe,v2.Cuantos,'S');
         end if;
      end loop;
   end loop;
end;
/

/*******************************************************************************************************************/

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
		
CURSOR cVALORES IS Select V.ID, V.Nombre,V.Ayto, V.Year, V.Recibo, V.F_Apremio, V.Padron, V.Periodo,
        V.Objeto_tributario, V.Tipo_de_objeto, V.Principal, V.Recargo, v.Costas, 
        V.Demora, V.demora_pendiente, V.Dom_tributario, V.Clave_concepto, V.Fin_pe_vol,
        V.orden_apremio, V.Relacion_apremio,
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
		OBJETO_TRIBUTARIO,xRECILIQUI,DESCRIPCION,DOM_TRIBUTARIO,FIN_PE_VOL,
		F_APREMIO,ORDEN_APREMIO,RELACION_APREMIO,IDCARTAPAGOBANCO)
	   VALUES
	  	(vVALORES.ID,vVALORES.NIF,vVALORES.NOMBRE,vVALORES.AYTO,vVALORES.PADRON,vVALORES.YEAR,
	  	vVALORES.PERIODO,vVALORES.RECIBO,vVALORES.CLAVE_CONCEPTO,
		vVALORES.PRINCIPAL,vVALORES.RECARGO,ROUND((vVALORES.PRINCIPAL*20)/100,2),
		vVALORES.COSTAS,xCOSTASFIJAS,vVALORES.DEMORA,
		vVALORES.PRINCIPAL+vVALORES.RECARGO+vVALORES.COSTAS+vVALORES.DEMORA,
		vVALORES.DEMORA_PENDIENTE,
		vVALORES.PRINCIPAL + vVALORES.RECARGO + vVALORES.COSTAS + vVALORES.DEMORA - xEntregasACuenta + 
		vVALORES.DEMORA_PENDIENTE,
		ROUND(vVALORES.PRINCIPAL+ROUND((vVALORES.PRINCIPAL*20)/100,2)+xCOSTASFIJAS + vVALORES.DEMORA - 
		xEntregasACuenta + vVALORES.DEMORA_PENDIENTE,2),
		xEntregasACuenta,
		vVALORES.OBJETO_TRIBUTARIO,DECODE(vVALORES.TIPO_DE_OBJETO,'R','RECIBO','LIQUIDACION'),
		xDESCRIPCION, vVALORES.DOM_TRIBUTARIO, vVALORES.FIN_PE_VOL,vVALORES.F_APREMIO,vVALORES.ORDEN_APREMIO,
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
        xCIF,xPOBLADATOSPER,IDCARTAPAGOBANCO)
       Values (vVALORES.NIF,xNOMBRE,xDOMI,xCODPOSTAL,xPOBLACION,xPROVINCIA,xAYUNTA,xEMPRESA,xDIRECCION,
        xCIF,xPOBLADATOSPER,xIDCARTAPAGO);

	end loop;

END;
/

/**************************************************************************************************************/
/* procedimiento para arreglar un problema de Salobreña: se desactivó la opción de pase automático para grabar
   los acuses de recibo de las liquidaciones y no se ha actualizado en valores ni en notificaciones */

CREATE OR REPLACE PROCEDURE GRABAR_ACUSES_VOL AS   

	xNoti 			char(1);
    xEnvios 		INTEGER;
    xF_Envio		date;
    xF_Publi		date;

    CURSOR C1 IS SELECT L.ID,N.ID AS IDNOTI,L.IDVALOR,L.F_NOTIFICACION,L.F_FIN_PE_VOL 
   			    FROM LIQUIDACIONES L,NOTIFICACIONES N
				WHERE L.IDVALOR=N.VALOR AND L.F_NOTIFICACION IS NOT NULL AND N.TIPO_NOTI='VOL' AND  
					  L.NUMERO_DE_CARGO='2003/00008';
BEGIN

   FOR v1 IN C1
   LOOP
      -- ver qué envio es este, si es el primero o el segundo
	  SELECT N_ENVIOS,F_ENVIO_BOP,F_PUBLICACION
	  INTO xEnvios,xF_Envio,xF_Publi
	  FROM NOTIFICACIONES WHERE ID=v1.IDNOTI;

	  -- Si esta enviado al BOP o publicado, no acepta modificar la Notificacion

	  IF (xF_ENVIO IS NOT NULL OR xF_Publi IS NOT NULL) THEN
		 RETURN;
	  END IF;

	  --xNoti: si el acuse de recibo elegido es del tipo notificado o no
	  Select notificado into xNoti from tipo_acuses where tipo='1';

	  -- Primer intento
	  IF xEnvios=1 THEN
		UPDATE notificaciones Set
			F_1ACUSE=v1.F_NOTIFICACION,ACUSE1='0101',TERCERO_1NOTIFI='',
			NOTIFICADO=xNoti,F_NOTIFICACION=v1.F_NOTIFICACION,
			F_LAST_ACUSE=v1.F_NOTIFICACION,LAST_ACUSE='0101',
			Referencia=''
      	WHERE id=v1.IDNOTI;

	ELSE  --segundo intento

		UPDATE notificaciones Set
			F_2ACUSE=v1.F_NOTIFICACION, ACUSE2='0101',TERCERO_2NOTIFI='',
			NOTIFICADO=xNoti,F_NOTIFICACION=v1.F_NOTIFICACION,
			F_LAST_ACUSE=v1.F_NOTIFICACION,LAST_ACUSE='0101',
			Referencia=''
	      WHERE id=v1.IDNOTI;
	END IF;

	-- si el valor no tiene FIN_PE_VOL, se pone el calculado;
	-- si tiene y la notificación es negativa se deja la fecha que tuviera;
	-- si tiene y la notificación es positiva se cambia por la fecha calculada;
	IF (xNOTI='N') THEN
	   UPDATE VALORES SET
	      FIN_PE_VOL=DECODE(FIN_PE_VOL,NULL,TO_DATE(v1.F_FIN_PE_VOL,'dd/mm/yyyy'),FIN_PE_VOL)
   	   WHERE ID=v1.IDVALOR;
	ELSE
	   UPDATE VALORES SET FIN_PE_VOL=TO_DATE(v1.F_FIN_PE_VOL,'dd/mm/yyyy')
	   WHERE ID=v1.IDVALOR;
	END IF;

      
   END LOOP;
END;
/


/**************************************************************************************/
						/* PROPUESTAS DE BAJA POR ZONAS */
/**************************************************************************************/

CREATE TABLE PROPUESTAS_BAJA(
	IDVALOR INTEGER NOT NULL,
	ZONA	CHAR(2) NOT NULL,						
	CONSTRAINT CIDVALORES
	FOREIGN KEY(IDVALOR)
	REFERENCES VALORES(ID),
	CONSTRAINT CZONAS
	FOREIGN KEY(ZONA)
	REFERENCES ZONAS(ZONA),
	PRIMARY KEY (IDVALOR,ZONA)
)TABLESPACE RECA;
CREATE PUBLIC SYNONYM PROPUESTAS_BAJA FOR .PROPUESTAS_BAJA;

INSERT INTO PROPUESTAS_BAJA SELECT ID,'00' FROM VALORES 
WHERE AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA='00')
AND PROPU_INSOLVENTE='S' AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL;

TRIGGER T_UPDVALORES_PROPUBAJA;
PROCEDURE PUNTEO_A_VALORES;
PROCEDURE PREPARA_PROPU_BAJAS_REFE;
PROCEDURE REPONER_VALOR_CREDITO;
PROCEDURE REPONER_CREDITO;
/**************************************************************************************/

CREATE OR REPLACE PROCEDURE PENDIENTES AS
	  xVIA               CHAR(2);
      xCALLE             VARCHAR(30);
      xNUMERO            CHAR(5);
      xESCALERA          CHAR(2);
      xPLANTA            CHAR(3);
      xPISO              CHAR(2);
      xPOBLACION         VARCHAR(35);
      xPROVINCIA         VARCHAR(35);
      xCODIGO_POSTAL     CHAR(5);
      oPRINCIPAL 		 FLOAT;
	  oRECARGO 			 FLOAT;
	  oCOSTAS 		     FLOAT;
	  oDEMORA 		     FLOAT;
	  oTOTAL	 	     FLOAT;
	  CURSOR C1 IS SELECT * FROM VALORES WHERE F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL
	  AND F_SUSPENSION IS NULL AND VOL_EJE='E';
BEGIN

	FOR v1 IN C1
	LOOP
	   SELECT VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,CODIGO_POSTAL
	   INTO xVIA,xCALLE,xNUMERO,xESCALERA,xPLANTA,xPISO,xPOBLACION,XPROVINCIA,xCODIGO_POSTAL
	   FROM CONTRIBUYENTES WHERE NIF=v1.NIF;
	   
	   PkIngresos.GET_PENDIENTE(v1.ID,oPRINCIPAL,oRECARGO,oCOSTAS,oDEMORA,
	   oTOTAL);
	   
	   INSERT INTO NOTIFI
	   		(PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,AYTO,NIF,NOMBRE,
	         VIA,CALLE,NUMERO,ESCALERA,PLANTA,PISO,POBLACION,PROVINCIA,
             CODIGO_POSTAL,CLAVE_CONCEPTO,YEAR_CONTRAIDO,FIN_PE_VOL,	
             PRINCIPAL,RECARGO,COSTAS,DEMORA,TOTAL,TIPO_DE_TRIBUTO,
	         DOM_TRIBUTARIO,OBJETO_TRIBUTARIO)
	   VALUES
	   		(v1.PADRON,v1.YEAR,v1.PERIODO,v1.RECIBO,v1.TIPO_DE_OBJETO,v1.AYTO,v1.NIF,
	   		v1.NOMBRE,xVIA,xCALLE,xNUMERO,xESCALERA,xPLANTA,xPISO,xPOBLACION,
	   		xPROVINCIA,xCODIGO_POSTAL,v1.CLAVE_CONCEPTO,v1.YEAR_CONTRAIDO,
	   		v1.FIN_PE_VOL,oPRINCIPAL,oRECARGO,oCOSTAS,oDEMORA,oTOTAL,v1.TIPO_DE_TRIBUTO,
	   		v1.DOM_TRIBUTARIO,v1.OBJETO_TRIBUTARIO);
	END LOOP;

END;
/


/**************************************************************************************/

SELECT id_histo_soportes,municipio,padron,year,periodo,count(*),SUM(IMPORTE)
FROM INCIDENCIAS_C60 WHERE ESTADO='CO' AND MODALIDAD='MOD1'
GROUP BY ID_HISTO_SOPORTES,MUNICIPIO,PADRON,YEAR,PERIODO;

SELECT ZONA FROM ZONAS_USUARIO WHERE USUARIO IN (SELECT USUARIO FROM 
HISTO_SOPORTES WHERE ID=70);

-- Habrá que modificar y ejecutar el procedimiento por cada valor diferente 
-- conseguido de la anterior consulta.

CREATE OR REPLACE PROCEDURE INSERTAINGRESOSINDEBIDOS AS
   xCODOPE INTEGER;
   xVALOR INTEGER;   
   xID INTEGER;
   xFECHA DATE;
   CURSOR C1 IS SELECT * FROM INCIDENCIAS_C60 WHERE ID_HISTO_SOPORTES=70 AND
   			    ESTADO='CO' AND MODALIDAD='MOD1' AND MUNICIPIO='XXX' AND 
   			    PADRON='000001' AND YEAR='2002' AND PERIODO='01';           
BEGIN
   CODIGO_OPERACION(xCodOpe);
   
   SELECT FECHA INTO xFECHA FROM HISTO_SOPORTES WHERE ID=70;
   
   INSERT INTO INGRESOS_INDEBIDOS (CODIGO_OPERACION,FECHA_PROCESO,IMPORTE,ZONA,C60MOD1)
   VALUES (xCODOPE,xFECHA,140.24,'00','S')
   RETURNING ID INTO xID;
   
   FOR v1 IN C1
   LOOP      
      IF v1.MUNICIPIO<>'XXX' THEN
         SELECT ID INTO xVALOR FROM VALORES WHERE AYTO=v1.MUNICIPIO AND PADRON=v1.PADRON AND
         YEAR=v1.YEAR AND PERIODO=v1.PERIODO AND RECIBO=v1.RECIBO;
      ELSE
         SELECT ID INTO xVALOR FROM VALORES WHERE PADRON=v1.PADRON AND
         YEAR=v1.YEAR AND PERIODO=v1.PERIODO AND RECIBO=v1.RECIBO;
      END IF;
      
      INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES)
	  VALUES (xID,xVALOR,v1.IMPORTE,'S');		
   END LOOP;
   
END;
/

DROP PROCEDURE INSERTAINGRESOSINDEBIDOS;

SELECT * FROM INGRESOS_INDEBIDOS ORDER BY ID DESC;

SELECT * FROM INCIDENCIASR WHERE ID_ING_INDE=XXX;

/**************************************************************************************/

SELECT id_histo_soportes,municipio,padron,year,periodo,count(*),SUM(IMPORTE)
FROM INCIDENCIAS_C60 WHERE ESTADO='CO' AND MODALIDAD='MOD2LI'
GROUP BY ID_HISTO_SOPORTES,MUNICIPIO,PADRON,YEAR,PERIODO;

SELECT ZONA FROM ZONAS_USUARIO WHERE USUARIO IN (SELECT USUARIO FROM 
HISTO_SOPORTES WHERE ID=463);

-- Habrá que modificar y ejecutar el procedimiento por cada valor diferente 
-- conseguido de la anterior consulta.

CREATE OR REPLACE PROCEDURE INSERTAINGRESOSINDEBIDOS AS
   xCODOPE INTEGER;
   xVALOR INTEGER;   
   xID INTEGER;
   xFECHA DATE;
   CURSOR C1 IS SELECT * FROM INCIDENCIAS_C60 WHERE ID_HISTO_SOPORTES=463 AND
   			    ESTADO='CO' AND MODALIDAD='MOD2LI' AND MUNICIPIO='148' AND 
   			    PADRON='000064' AND YEAR='2003';           
BEGIN
   CODIGO_OPERACION(xCodOpe);
   
   SELECT FECHA INTO xFECHA FROM HISTO_SOPORTES WHERE ID=463;
   
   INSERT INTO INGRESOS_INDEBIDOS (CODIGO_OPERACION,FECHA_PROCESO,IMPORTE,ZONA,C60LIQUIDACIONES)
   VALUES (xCODOPE,xFECHA,0,'00','S')
   RETURNING ID INTO xID;
   
   FOR v1 IN C1
   LOOP      
      IF v1.MUNICIPIO<>'XXX' THEN
         SELECT ID INTO xVALOR FROM VALORES WHERE AYTO=v1.MUNICIPIO AND PADRON=v1.PADRON AND
         YEAR=v1.YEAR AND RECIBO=v1.RECIBO;
      ELSE
         SELECT ID INTO xVALOR FROM VALORES WHERE PADRON=v1.PADRON AND
         YEAR=v1.YEAR AND RECIBO=v1.RECIBO;
      END IF;
      
      INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES)
	  VALUES (xID,xVALOR,v1.IMPORTE,'S');		
   END LOOP;
   
END;
/

DROP PROCEDURE INSERTAINGRESOSINDEBIDOS;

SELECT * FROM INGRESOS_INDEBIDOS ORDER BY ID DESC;

SELECT * FROM INCIDENCIASR WHERE ID_ING_INDE=XXX;

/**************************************************************************************/
-- Las bajas de la zona 01 que no están datadas tendrían que ser verdaderamente 
-- propuestas de baja. Se van a reponer y a proponer de baja por número de cargo

CREATE OR REPLACE PROCEDURE REPONER_BAJAS_ZONA01 AS
	xERROR INTEGER;
	CURSOR C1 IS select VALOR from bajas where zona='01' and numero_de_data is null
				 and tipo_baja<>'BN';
BEGIN
	FOR V1 IN C1
	LOOP
	    REPON_BAJA(V1.VALOR,xERROR); 
		UPDATE VALORES SET FECHA_PROPUESTA_BAJA=TRUNC(SYSDATE),
						   PROPU_INSOLVENTE='V',
						   CODIGO_DE_BAJA='BA'
		WHERE ID=V1.VALOR;		
	END LOOP;
END;
/

/*************************************************************************************/
--procedimiento para rellenar una tabla temporal con lo pendiente a 31 de diciembre de 2003

CREATE TABLE TEMP(
	ID                       INTEGER       NOT NULL, 
  	PADRON                   CHAR (6)      NOT NULL, 
  	YEAR                     CHAR (4)      NOT NULL, 
  	PERIODO                  CHAR (2)      DEFAULT '00' NOT NULL, 
  	RECIBO                   INTEGER       NOT NULL, 
  	TIPO_DE_OBJETO           CHAR (1)      NOT NULL, 
  	AYTO                     CHAR (3)      NOT NULL, 
  	NIF                      CHAR (10), 
  	NOMBRE                   VARCHAR2 (40), 
  	N_CARGO                  CHAR (10), 
  	CLAVE_CONCEPTO           VARCHAR2 (30), 
  	F_APREMIO                DATE, 
  	RELACION_APREMIO         CHAR (10), 
    ORDEN_APREMIO            INTEGER, 
    PRINCIPAL                FLOAT         DEFAULT 0, 
    RECARGO                  FLOAT         DEFAULT 0, 
    COSTAS                   FLOAT         DEFAULT 0, 
    DEMORA                   FLOAT         DEFAULT 0, 
    RECARGO_O_E              FLOAT         DEFAULT 0, 
    DEMORA_PENDIENTE         FLOAT         DEFAULT 0, 
    ENTREGAS_A_CUENTA        FLOAT         DEFAULT 0, 
    PENDIENTE				 FLOAT		   DEFAULT 0,
    NOTIFICADO               CHAR (1)      DEFAULT 'N', 
    F_NOTIFICACION           DATE, 
    FECHA_PROPUESTA_BAJA     DATE, 
    F_SUSPENSION             DATE,   
    VOL_EJE                  CHAR (1)      DEFAULT 'E'
);
   
     
  

CREATE OR REPLACE PROCEDURE PRUEBA (xYEAR IN CHAR)
AS
	xFechaIni	DATE;
  	xCadena 	Char(30);
	CURSOR C1 IS SELECT ID,PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,AYTO,NIF,NOMBRE,N_CARGO, 
  						CLAVE_CONCEPTO,F_APREMIO,RELACION_APREMIO,ORDEN_APREMIO,PRINCIPAL, 
    					RECARGO,COSTAS,DEMORA_PENDIENTE,ENTREGAS_A_CUENTA,NOTIFICADO, 
    					F_NOTIFICACION,FECHA_PROPUESTA_BAJA,F_SUSPENSION,VOL_EJE
    			 FROM VALORES
    			 WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        		 AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
        		 AND F_CARGO < xFechaIni;
BEGIN

	xCadena:='01/01/'||xYear||' 00:00:00';
  	xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  	-- Pendiente al 1 de enero.
  	FOR v1 IN C1
  	LOOP
  		INSERT INTO TEMP
  			(ID,PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,AYTO,NIF,NOMBRE,N_CARGO, 
  			 CLAVE_CONCEPTO,F_APREMIO,RELACION_APREMIO,ORDEN_APREMIO,PRINCIPAL, 
    		 RECARGO,COSTAS,DEMORA_PENDIENTE,ENTREGAS_A_CUENTA,NOTIFICADO, 
    		 F_NOTIFICACION,FECHA_PROPUESTA_BAJA,F_SUSPENSION,VOL_EJE)
    	VALUES
    		(v1.ID,v1.PADRON,v1.YEAR,v1.PERIODO,v1.RECIBO,v1.TIPO_DE_OBJETO,v1.AYTO,v1.NIF,
    		 v1.NOMBRE,v1.N_CARGO,v1.CLAVE_CONCEPTO,v1.F_APREMIO,v1.RELACION_APREMIO,v1.ORDEN_APREMIO,
    		 v1.PRINCIPAL,v1.RECARGO,v1.COSTAS,v1.DEMORA_PENDIENTE,v1.ENTREGAS_A_CUENTA,v1.NOTIFICADO, 
    		 v1.F_NOTIFICACION,v1.FECHA_PROPUESTA_BAJA,v1.F_SUSPENSION,v1.VOL_EJE);
  	END LOOP; 	
  	
  	
END;
/


CREATE OR REPLACE PROCEDURE PENDIENTE AS
	mPENDIENTE FLOAT;
	CURSOR C1 IS SELECT ID FROM TEMP FOR UPDATE OF PENDIENTE;
BEGIN
	FOR v1 IN C1
	LOOP
		SELECT PENDIENTE INTO mPENDIENTE FROM IMPORTE_VALORES WHERE ID=v1.ID;
		UPDATE TEMP SET PENDIENTE=mPENDIENTE
		WHERE CURRENT OF C1;
	END LOOP;
END;
/

/*******************************************************************************************************/
--GENERAR RELACION PARA EL BOP DE UNOS VALORES DETERMINADOS (TORREJON)
CREATE OR REPLACE PROCEDURE VALORES_AL_BOP(	
     xFECHAENVIO 	IN 	DATE)
     
AS	
	mNUMERO 		CHAR(10);
	mORDEN			INTEGER;
    mCUANTOSRECIBOS INTEGER;
    xZONA 			CHAR(2);
    
    xIDNOTI			INTEGER;
    xRELA			CHAR(10);
    xORDEN			INTEGER;
    xORDEN2			INTEGER;
    xNIF			CHAR(10);
        
   	CURSOR C1 IS
	   SELECT ID,NIF FROM VALORES WHERE ID IN (SELECT ID FROM TEMPBOP)
	   		  AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;	   

BEGIN

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	DAME_RELACION(mNUMERO);

	INSERT INTO RELACIONES_NOTI
   	(RELACION,FECHA,TIPO_NOTI,USUARIO,ZONA)
	VALUES
	(mNUMERO,xFECHAENVIO,'P',USER,xZONA);
	
	mORDEN:=0;
	xORDEN:=0;
	
	FOR v1 IN C1
	LOOP
		SELECT MAX(ID) INTO xIDNOTI FROM NOTIFICACIONES WHERE VALOR=v1.ID;
		IF (xIDNOTI IS NOT NULL) THEN
			SELECT N_RELACION,N_ORDEN INTO xRELA,xORDEN2 FROM NOTIFICACIONES
			WHERE ID=xIDNOTI;
			IF (xRELA IS NOT NULL) THEN
				mORDEN:=TO_NUMBER(SUBSTR(xRELA,1,4)||
       	  				SUBSTR(xRELA,8,3)||to_char(xORDEN2));			
			ELSE
				xORDEN:=xORDEN+1;
				mORDEN:=xORDEN;				
			END IF;
		ELSE
			xORDEN:=xORDEN+1;
			mORDEN:=xORDEN;
		END IF;
		UPDATE VALORES SET RELACION_APREMIO=mNUMERO,ORDEN_APREMIO=mORDEN
		WHERE ID=v1.ID;
		
		IF (xIDNOTI IS NOT NULL) THEN
			UPDATE NOTIFICACIONES SET N_RELACION=mNUMERO,F_ENVIO_BOP=xFECHAENVIO,
									  N_ORDEN=mORDEN
			WHERE ID=xIDNOTI;
		ELSE		
			INSERT INTO NOTIFICACIONES
            (VALOR,N_ENVIOS,TIPO_NOTI,NIF,N_RELACION,N_ORDEN,F_ENVIO_BOP)
			VALUES
			(v1.ID,1,'000',v1.NIF,mNUMERO,mORDEN,xFechaEnvio);
		END IF;
		
	END LOOP;
   
	SELECT COUNT(ID) INTO MCUANTOSRECIBOS FROM VALORES
	WHERE RELACION_APREMIO=mNUMERO;

	UPDATE RELACIONES_NOTI SET RECIBOS=MCUANTOSRECIBOS
	WHERE RELACION=mNUMERO;

END;
/
/*******************************************************************************************************/
CREATE OR REPLACE PROCEDURE NEWCARTAPAGOEXPEDIENTE 
	(xIDEXPE	IN	INTEGER)
AS
	xTramite		char(1);
BEGIN

	REFRESHEXPE(xIDEXPE); -- REFRESCO LOS INTERESES DEL EXPEDIENTE
	
	NewCartaPago(xIDExpe);
	
	select embargo into xTramite from expedientes where id=xIDExpe;
	PkSeguimiento.AnotaCartaPago
			(xIDExpe,
			'Suspensión temporal, Emisión de carta de pago número: '||
			PkCartaPagoBanco.VarCartaPagoBanco,
			xTramite,
			PkCartaPagoBanco.VarCartaPagoBanco);	
END;
/

/*******************************************************************************************************/

CREATE OR REPLACE PROCEDURE SuspenImprimeCartasPago
		(xTramite	IN	CHAR,
		 xZONA		IN	CHAR)
AS
	xIDCARTAPAGO	INT;
	
	CURSOR cCUENTAS IS
		SELECT ID FROM CUENTAS_SUSPENDIDAS WHERE ZONA=xZONA;
BEGIN

	-- Primero borra todos los datos de las tablas temporales que va a rellenar.
	DELETE FROM TMPDEUDASVIVAS WHERE USUARIO=UID;
	DELETE FROM TmpEntregasValor WHERE USUARIO=UID;
	DELETE FROM TMPDEUDORDPOSTALES WHERE USUARIO=UID;
	
	IF xTRAMITE='1' THEN
		FOR vCUENTAS IN cCUENTAS
		LOOP
		
			SELECT MAX(ID_CARTA_PAGO) INTO xIDCARTAPAGO FROM SEGUIMIENTO
			WHERE ID_EXPE=vCUENTAS.ID AND DESCRIPCION LIKE 'Suspensión temporal%';
			
			IF (xIDCARTAPAGO IS NOT NULL) THEN			
				ImprimeCartaPago(xIDCARTAPAGO);
			END IF;
			
		END LOOP;
	END IF;
END;
/

/*******************************************************************************************************/

CREATE OR REPLACE PROCEDURE ImprimeCartaPago
		(xIDCARTAPAGO	IN INT)
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
	xCostas			float default 0;	
	xNIF			char(10);
	xFecha			date default null;
	xDiaSemana 		varchar2(15);
	xFDili			date;
	xCuantos		integer;		

		
CURSOR cRECIBOS IS		
		SELECT * FROM RECIBOSCARTAPAGOBANCO WHERE CARTAPAGOBANCO=xIdCartaPago
		FOR UPDATE OF DEMORA,COSTAS;		
BEGIN	
			
		--para el calculo de intereses a la fecha de emision de la cartas de pago
		SELECT F_CREACION INTO xFECHA FROM CARTAPAGOBANCO WHERE ID=xIDCARTAPAGO;
			
		FOR vRECIBOS IN cRECIBOS
		LOOP
			
			--calculamos los intereses de demora a la fecha de emision
			--de las cartas de pago
			InteresProvidencia(vRECIBOS.Valor,xFecha,xInteres,xCostas);

			--insertamos en TMPDEUDASVIVAS y en TmpEntregasValor
			NotifiRellenaCartasPago(xIdCartaPago,vRECIBOS.Valor, xNIF);

			--se reajusta el importe de la demora en este momento, porque desde
			--que se generan las cartas de pago hasta cuando se imprimen puede
			--variar los intereses de demora
			--tambien se actualizan las costas
			update RECIBOSCARTAPAGOBANCO set demora=round(xInteres,2),costas=xCostas
			where current of cRECIBOS;
			
		END LOOP;		
		
		--insertamos los datos postales de la carta de pago
		PkwtDocIngreso.wtDatosPostalesDeudor(xNIF, 0, 'N');


		--se accede a la tabla de configuracion para recoger los datos de la emisora,
		--sufijo y dias de vencimiento para pagar en el BANCO POR CORREO
		select EMISORA,SUFIJO,DIAS_ASUSTA,REMESA_MOD1 into xEmisora,xSufijo,xDias,xRemesa
		from configuracion WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

		--averiguamos el importe de la carta de pago porque interviene en el
		--calculo del digito de control		

		select sum(PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS_A_CUENTA+DEMORA_PENDIENTE)
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

END;
/

/*******************************************************************************************************/

CREATE OR REPLACE PROCEDURE MAMEN 
AS
	xCODOPE INTEGER;	
BEGIN

   CODIGO_OPERACION(xCodOpe);  

	PkIngresos.WRITE_INGRESO(108690,'INGRESADO EN LA VENTANILLA DEL BANCO','VB','22/03/2004',12.62,0,0,0,xCodOpe,
	'C','22/03/2004','2038','9627','PB','0');
	
END;
/

/*********************************************************************************************************/
CREATE OR REPLACE PROCEDURE MAMEN
AS
	xCodOpeCartas INTEGER;
	xENCONTRADO	CHAR(1);
BEGIN
	CODIGO_OPERACION(xCodOpeCartas);   
	IngresosBancoCartaPago(16940,1,42,'18/03/2004','24/03/2004','073','2038','9627','PB',xCodOpeCartas,xENCONTRADO);	
END;
/;


/*******************************************************************************************************/

CREATE TABLE NADA (
	ID INTEGER,
	PADRON CHAR(6),
	YEAR CHAR(4),
	PERIODO CHAR(2),
	RECIBO INTEGER,
	CLAVE_CONCEPTO VARCHAR2(30),
	PRINCIPAL	FLOAT,	
	NIF CHAR(10),
	NOMBRE VARCHAR2(40),
	DOMICILIO VARCHAR2(100),
	CP CHAR(5),
	POBLACION VARCHAR2(35),
	PROVINCIA VARCHAR2(35)	
);

CREATE OR REPLACE PROCEDURE MAMEN
AS
	xNOMBRE VARCHAR2(40);
	xDOMICILIO VARCHAR2(100);
	xCP CHAR(5);
	xPOBLACION VARCHAR2(35);
	xPROVINCIA VARCHAR2(35);
	xEXPEDIENTE INTEGER;
	
	CURSOR C1 IS select id,padron,year,periodo,recibo,clave_concepto,principal,nif
					 from valores where relacion_apremio='2004/00021';
BEGIN

	FOR v1 IN C1
	LOOP
	
		SELECT nombre,via||' '||calle||' '||numero||' '||escalera||' '||planta||' '||piso as dom_fiscal,
		codigo_postal,poblacion,provincia into xNombre, xDomicilio,xCP,xPoblacion,xProvincia
		FROM CONTRIBUYENTES WHERE NIF=v1.NIF;
		
		INSERT INTO NADA VALUES (v1.ID,v1.PADRON,v1.YEAR,v1.PERIODO,v1.RECIBO,v1.CLAVE_CONCEPTO,v1.PRINCIPAL,
		v1.NIF,xNOMBRE,xDOMICILIO,xCP,xPOBLACION,xPROVINCIA);
		
	END LOOP;
	
	
END;
/


CREATE OR REPLACE PROCEDURE MAMEN
AS
	XCONTADOR INTEGER;
	CURSOR C1 IS SELECT NIF,YEAR,RECIBO FROM BOCAM;
BEGIN
	FOR v1 IN C1 
	LOOP
		xCONTADOR:=0;
		SELECT COUNT(*) INTO xCONTADOR FROM NADA WHERE TRIM(NIF)=v1.NIF AND YEAR=v1.YEAR AND RECIBO=v1.RECIBO;
		UPDATE NADA SET CONTADOR=xCONTADOR WHERE TRIM(NIF)=v1.NIF AND YEAR=v1.YEAR AND RECIBO=v1.RECIBO;
	END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE MAMEN
AS
	xID INTEGER;
	CURSOR C1 IS SELECT * FROM BOCAM;
BEGIN
	FOR v1 IN C1
	LOOP
		begin		
			SELECT ID INTO xID FROM VALORES WHERE YEAR=v1.YEAR AND RECIBO=v1.RECIBO AND TRIM(NIF)=TRIM(v1.NIF);
			Exception
				When no_data_found then
					xID:=0;
		end;
		UPDATE BOCAM SET IDVALOR=xID WHERE YEAR=v1.YEAR AND RECIBO=v1.RECIBO AND TRIM(NIF)=TRIM(v1.NIF);
	END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE MAMEN
AS
	xID INTEGER;
	CURSOR C1 IS SELECT * FROM BOCAM where idvalor=0;
BEGIN
	FOR v1 IN C1
	LOOP
		begin		
			SELECT ID INTO xID FROM VALORES WHERE YEAR=v1.YEAR AND RECIBO=v1.RECIBO AND TRIM(NIF) LIKE '%'||TRIM(v1.NIF)||'%';
			Exception
				When no_data_found then
					xID:=0;
		end;
		UPDATE BOCAM SET IDVALOR=xID WHERE YEAR=v1.YEAR AND RECIBO=v1.RECIBO AND TRIM(NIF) LIKE '%'||TRIM(v1.NIF)||'%';
	END LOOP;
END;
/

/************************************************************************************************/

CREATE OR REPLACE PROCEDURE MAMEN AS
	CURSOR C1 IS SELECT ID FROM EXPEDIENTES WHERE DEUDOR IN (SELECT NIF FROM CONFLICTIVO);
BEGIN
	FOR v1 IN C1
	LOOP
		PkSeguimiento.NotaInformativa(v1.ID,'TITULARIDAD CONFLICTIVA EN EL REG. CENTRAL DE LA PROPIEDAD');
	END LOOP;
END;
/

CREATE OR REPLACE PROCEDURE MAMEN AS
	CURSOR C1 IS SELECT ID FROM EXPEDIENTES WHERE DEUDOR IN (SELECT NIF FROM SINFINCA);
BEGIN
	FOR v1 IN C1
	LOOP
		PkSeguimiento.NotaInformativa(v1.ID,'SIN FINCA EN EL REG. CENTRAL DE LA PROPIEDAD');
	END LOOP;
END;
/


/*************************************************************************************************/

valores que no se han podido desagrupar
(92980,179705,176856,235058,235315,250394,257626,246711,240796,235637)

/* desagrupación de valores dentro de embargos con diligencia pero con retención cero */

CREATE OR REPLACE PROCEDURE MAMEN 
AS

	xVALOR INTEGER;
	xERROR INTEGER;
	xIDExpe      INT;
	xFEntrada    DATE;
  	xFIngreso	 DATE;
  	xFBaja	 DATE;
  	xFSuspension DATE;
  	xEstado	 Expedientes.Estado%Type;
  	xClaveValor	 varchar(50);


	CURSOR C1 IS SELECT ID FROM VALORES WHERE ID IN 
	(77072,190382,191572,235183,236056,236057,236108,236109,237023,238283,238284,272545);
	
BEGIN
	FOR v1 IN C1
	LOOP

		xVALOR:=v1.ID;
	
  		SELECT AYTO||'-'||PADRON||'-'||YEAR||'-'||PERIODO||'-'||RECIBO,EXPEDIENTE,F_IN_EXPEDIENTE,
			F_INGRESO,FECHA_DE_BAJA,F_SUSPENSION
  		INTO xClaveValor,xIDExpe,xFEntrada,xFIngreso,xFBaja,xFSuspension FROM VALORES
  		WHERE ID=xVALOR;

  		-- si el valor esta ingresado o anulado nos salimos sin hacer nada
  		IF (xFIngreso is not null) or (xFBaja is not null) THEN
		   	xError:=1;
		   	RETURN;
  		END IF;

  		-- Si el expediente está fraccionado no se puede desagrupar
  		SELECT Estado INTO xEstado FROM EXPEDIENTES WHERE ID=xIDExpe;
  		-- si el valor esta suspendido y el expediente tambien no se puede desagrupar, 
  		-- porque esta en un fraccionamiento. Si el valor esta suspendido pero no hay un 
  		-- fraccionamiento si se puede desagrupar
  		IF xFSuspension is not null AND xEstado='FRACCIO' THEN
		   	xError:=2;
			RETURN;
  		END IF;  

  		-- Desagrupar el valor
  		UPDATE VALORES SET EXPEDIENTE=NULL,F_IN_EXPEDIENTE=NULL,ID_INMUEBLES=NULL,EN_INMUEBLES='N'
  		WHERE ID=xVALOR;

		if xFSuspension is null then --Actualizamos el contador de recibos del expediente
  
		  	UPDATE EXPEDIENTES SET RECIBOS=RECIBOS-1
			WHERE ID=xIDExpe
         		AND F_INGRESO IS NULL
         		AND F_ANULACION IS NULL;
         
  		Else 	--Actualizamos el contador de recibos suspendidos del expediente

   		UPDATE EXPEDIENTES SET CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN-1
			WHERE ID=xIDExpe
         	AND F_INGRESO IS NULL
         	AND F_ANULACION IS NULL;
  		end if;

  		DELCostaValorPasaAExpe(xIDExpe, xFEntrada, xVALOR, xError);

  		PkSeguimiento.NotaInformativa(xIDExpe, 'Se desagrupa el valor '|| To_Char(xVALOR)||
 			' ,Clave valor: '||Ltrim(RTrim(xClaveValor)));		
				
		INSERT INTO NADA VALUES (v1.ID,xERROR);
	END LOOP;
END;
/


/**************************************************************************************************/
CREATE TABLE MAMEN1 ( ID INTEGER,
							 IDEXPE INTEGER,
							 NOTIFICADO CHAR(1),
							 F_NOTIFICACION DATE,
							 IDNOTI	INTEGER,
							 NOTI CHAR(1));							 
							 
CREATE TABLE MAMEN2 ( ID INTEGER,
							 IDEXPE INTEGER,
							 NOTIFICADO CHAR(1),
							 F_NOTIFICACION DATE,
							 IDNOTI INTEGER,
							 NOTI CHAR(1));

CREATE OR REPLACE PROCEDURE MAMEN 
AS
	xID INTEGER;
	xACUSE CHAR(4);
	xNoti CHAR(1);
	CURSOR C1 IS SELECT ID,EXPEDIENTE,NOTIFICADO,F_NOTIFICACION FROM VALORES where
			vol_eje='E' and f_ingreso is null and fecha_de_baja is null and f_suspension is null and
			fecha_propuesta_baja is null;
BEGIN	

	FOR v1 IN C1 LOOP
		SELECT MAX(ID) INTO xID FROM NOTIFICACIONES WHERE VALOR=v1.ID;
		IF (xID IS NOT NULL) THEN
			begin
			   SELECT NOTIFICADO,LAST_ACUSE INTO xNOTI,xACUSE FROM NOTIFICACIONES WHERE ID=xID AND F_PUBLICACION IS NULL;
			   Exception
			   	When no_data_found then
			   		xACUSE:='';
			end;
			IF (xACUSE LIKE '04%') THEN
				INSERT INTO MAMEN1(ID,IDEXPE,NOTIFICADO,F_NOTIFICACION,IDNOTI,NOTI) 
				VALUES (v1.ID,v1.EXPEDIENTE,v1.NOTIFICADO,v1.F_NOTIFICACION,xID,xNOTI);
			ELSIF (xACUSE LIKE '03%') THEN
				INSERT INTO MAMEN2(ID,IDEXPE,NOTIFICADO,F_NOTIFICACION,IDNOTI,NOTI) 
				VALUES (v1.ID,v1.EXPEDIENTE,v1.NOTIFICADO,v1.F_NOTIFICACION,xID,xNOTI);
			END IF;
		END IF;
	END LOOP;
END;
/


CREATE OR REPLACE PROCEDURE MAMEN
AS
	CURSOR C1 IS SELECT VALOR,F_NOTIFICACION FROM NOTIFICACIONES WHERE ID IN (SELECT IDNOTI 
													FROM MAMEN2 WHERE F_NOTIFICACION IS NULL);
BEGIN
	FOR v1 IN C1
	LOOP
		UPDATE VALORES SET F_NOTIFICACION=v1.F_NOTIFICACION WHERE ID=v1.VALOR;
	END LOOP;
END;
/



/***************************************************************************************************/
CREATE OR REPLACE PROCEDURE MAMEN
AS
	XNOTI CHAR(1);
	XFECHA DATE;
	CURSOR C1 IS SELECT ID,IDNOTI FROM MAMEN1 WHERE IDEXPE IS NOT NULL AND NOTIFICADO='S';
BEGIN
	FOR v1 IN C1
	LOOP
		SELECT NOTIFICADO,F_NOTIFICACION INTO xNOTI,xFECHA FROM NOTIFICACIONES WHERE ID=v1.IDNOTI;
		UPDATE VALORES SET NOTIFICADO=xNOTI,F_NOTIFICACION=xFECHA WHERE ID=v1.ID;
		UPDATE MAMEN1 SET NOTIFICADO=xNOTI,F_NOTIFICACION=xFECHA WHERE ID=v1.ID;
	END LOOP;	
END;
/

/************************************************************************************************/
-- procedimiento para retroceder una publicación en el BOP
CREATE OR REPLACE PROCEDURE MAMEN (xRELACION CHAR)
AS
	xOLDRELACION CHAR(10);
	xOLDORDEN	INTEGER;
	xIDNOTI INTEGER;
	CURSOR C1 IS SELECT ID,RELACION_APREMIO,ORDEN_APREMIO FROM VALORES WHERE RELACION_APREMIO=xRELACION;
BEGIN
	FOR v1 IN C1 
	LOOP
		SELECT MAX(ID) INTO xIDNOTI FROM NOTIFICACIONES WHERE VALOR=v1.ID AND 
		N_RELACION=v1.RELACION_APREMIO AND N_ORDEN=v1.ORDEN_APREMIO;		
		
		IF ((v1.ORDEN_APREMIO IS NOT NULL) AND (xIDNOTI IS NOT NULL)) THEN
			xOLDRELACION:=SUBSTR(v1.ORDEN_APREMIO,1,4)||'/00'||SUBSTR(v1.ORDEN_APREMIO,5,3);
			xOLDORDEN:=SUBSTR(v1.ORDEN_APREMIO,8,LENGTH(v1.ORDEN_APREMIO));
			
			UPDATE NOTIFICACIONES SET N_RELACION=xOLDRELACION,F_ENVIO_BOP=NULL,
			N_ORDEN=xOLDORDEN WHERE ID=xIDNOTI;
			
			UPDATE VALORES SET RELACION_APREMIO=xOLDRELACION,ORDEN_APREMIO=xOLDORDEN
			WHERE ID=v1.ID;			
			
		END IF;
		
	END LOOP;
END;

/************************************************************************************************************/
CREATE OR REPLACE PROCEDURE MAMEN
AS
	xID INTEGER;
	xPRINCIPAL FLOAT;
	xRECARGO FLOAT;
	xCOSTAS FLOAT;
	xDEMORA FLOAT;
	xENTREGAS FLOAT;
	xPENDIENTE FLOAT;
	CURSOR C1 IS SELECT EXPEDIENTE FROM LIBRO1;
BEGIN
	FOR v1 IN C1
	LOOP
		BEGIN
			SELECT ID INTO xID FROM EXPEDIENTES WHERE TRIM(EXPEDIENTE)=TRIM(v1.EXPEDIENTE);
			EXCEPTION
				WHEN NO_DATA_FOUND THEN
					xID:=0;
		END;
		
		IF xID>0 THEN		
			select SUM(principal),SUM(recargo),SUM(demora+demora_pendiente),
	   	SUM(costas),SUM(entregas),SUM(pendiente)
	   	into xPRINCIPAL,xRECARGO,xDEMORA,xCOSTAS,xENTREGAS,xPENDIENTE
	   	from valoresexpe where Expediente=xID and f_ingreso is null 
	   	AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
	   
	   	UPDATE LIBRO1 set principal=xPRINCIPAL,
	   		 	 		  recargo=xRECARGO,
				 			  intereses=xDEMORA,
				 			  costas=xCOSTAS,
				 			  entregas=xENTREGAS,
				 			  pendiente=xPENDIENTE
			where expediente=v1.EXPEDIENTE;
		END IF;
	END LOOP;
END;
/


/*********************************************************************************/
/* procedimiento para recalcular la demora de los valores pendientes de unos expedientes determinados */
CREATE OR REPLACE PROCEDURE MAMEN
AS
	CURSOR C1 IS SELECT EXPEDIENTE FROM LIBRO1;	
BEGIN
	FOR v1 IN C1
	LOOP
		RecalculaDemoraExpe(v1.EXPEDIENTE,SYSDATE,'S','N');
	END LOOP;
END;
/

/*********************************************************************************/

/* procedimiento igual al anterior pero sin comprobar si se puede o no según diligencias y embargos */
DECLARE
	xINTERESES FLOAT;
	xDEUDA_TOTAL FLOAT;
BEGIN
	CALCDEMORA_EXPE(126, SYSDATE, 'S','N',xINTERESES, xDEUDA_TOTAL);	
END;
/*********************************************************************************/

CREATE OR REPLACE PROCEDURE MAMEN
AS
	xPRINCIPAL FLOAT;
	xRECARGO FLOAT;
	xINTERESES FLOAT;
	xCOSTAS FLOAT;
	xENTREGAS FLOAT;
	xPENDIENTE FLOAT;
	CURSOR C1 IS SELECT EXPEDIENTE FROM LIBRO1;	
BEGIN

	FOR v1 IN C1
	LOOP

		SELECT SUM(principal),SUM(recargo),SUM(costas),SUM(demora+demora_pendiente),SUM(entregas),
		SUM(pendiente) INTO xPRINCIPAL,xRECARGO,xCOSTAS,xINTERESES,xENTREGAS,xPENDIENTE
		from ValoresExpe where Expediente=v1.EXPEDIENTE
		and f_ingreso is null AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;
	
		UPDATE LIBRO1 SET PRINCIPAL=xPRINCIPAL,RECARGO=xRECARGO,COSTAS=xCOSTAS,INTERESES=xINTERESES,
		ENTREGAS=xENTREGAS,PENDIENTE=xPENDIENTE WHERE EXPEDIENTE=v1.EXPEDIENTE;
		
	END LOOP;
	
END;
/

/***********************************************************************************************************************************/
/* REQUENA: Poner el recargo al 10% */

declare
   xPendiente float;
	cursor c1 is select id,f_apremio from valores where f_apremio=to_date('05/07/2004') and recargo=ROUND(CUOTA_INICIAL*5/100, 2);
begin
   for v1 in c1
   loop
   	update valores set recargo=ROUND(CUOTA_INICIAL*10/100, 2) where id=v1.id;   	
   	update multas set estado_actual='EJ',fecha_estado_actual=v1.f_apremio where idvalor=v1.id; 
   end loop;
end;

/***********************************************************************************************************************************/
/* Cambiar fecha de ingreso de un disco Cuaderno 60 */
Tabla HISTO_SOPORTES			FECHA_INGRESO_APLICACION
Tabla VALORES					F_INGRESO
Tabla INGRESOS					MES,YEAR_INGRE,FECHA
Tabla MOV_CUENTAS				FECHA,HORA
Tabla INGRESOS_INDEBIDOS	FECHA

/************************************************************************************************************************************/
/* Intentar desagrupar valores suspendidos de expedientes dentro de un lote de salarios */
create table nada(id integer,idexpe integer,error integer)

declare
	xError integer;
	cursor c1 is select v.id,v.expediente 
					 from valores v, suspensiones_valores s where v.id=s.VALOR 
					 and expediente in (select idexpe from vwEmbargoSalarioDeudor where lote='20040826')
					 and f_ingreso is null;					 
begin
	for v1 in c1
	loop
		desagrupa_expe(v1.id,xError);
		insert into nada values (v1.id,v1.expediente,xError);
	end loop;
end;


drop table nada;

/* Intentar desagrupar valores propuestos de baja de expedientes dentro de un lote de salarios */
create table nada(id integer,idexpe integer,error integer)

declare
	xError integer;
	cursor c1 is select v.id,v.expediente 
					 from valores v, suspensiones_valores s where v.id=s.VALOR 
					 and expediente in (select idexpe from vwEmbargoSalarioDeudor where lote='20040826')
					 and f_ingreso is null;					 
begin
	for v1 in c1
	loop
		desagrupa_expe(v1.id,xError);
		insert into nada values (v1.id,v1.expediente,xError);
	end loop;
end;


drop table nada;