--
-- Autor: Agustin Leon Robles. 04/10/2002. Grabar el numero de cuenta de cada municipio
--					para posteriormente cuando se hagan las liquidaciones saber
--					a que numero de cuenta hay que enviar el importe
--
create or replace procedure PutCuentaMunicipio(
				xAYTO		IN 	CHAR,
				xENTIDAD	IN	CHAR,
				xOFICINA 	IN	CHAR,
				xDC 		IN 	CHAR,
				xCUENTA	IN 	CHAR,
				xDIRECCION 	IN 	VARCHAR,
				xPOBLACION 	IN	VARCHAR,
				xCODPOSTAL 	IN	CHAR)
as
begin

	update municipios set ENTIDAD=xENTIDAD,OFICINA=xOFICINA,
					DC=xDC,CUENTA=xCUENTA,DIRECCION=xDIRECCION,
					POBLACION=xPOBLACION,CODPOSTAL=xCODPOSTAL
	where ayto=xAYTO;
end;
/


/******************************************************************************************
Autor: Lucas (enero 2001)
Acción: Procedimiento de INSERCION/MODIFICACION de MUNICIPIOS.
        Tiene asociado un trigger para añadir una nueva tupla en
  	  el historico de comisiones en el caso de que se modifique
	  algún porcentaje de comisión o fecha de inicio de vigencia de los mismos.
MODIFICACIÓN: 20/12/2002 Mª Carmen Junco Gómez. Se añade el campo CIF.
******************************************************************************************/

CREATE OR REPLACE PROCEDURE GESTAYTOS(
	xAyto          IN MUNICIPIOS.AYTO%TYPE,
	xFecha_Inicio  IN MUNICIPIOS.FECHA%TYPE,
	xZona          IN MUNICIPIOS.ZONA%TYPE,
	xNombre        IN MUNICIPIOS.NOMBRE%TYPE,
	xAlcalde       IN MUNICIPIOS.ALCALDE%TYPE,
	xSecretario    IN MUNICIPIOS.SECRETARIO%TYPE,
	xInterventor   IN MUNICIPIOS.INTERVENTOR%TYPE,
	xTesorero      IN MUNICIPIOS.TESORERO%TYPE,
	xCod_Postal    IN MUNICIPIOS.COD_POSTAL%TYPE,
	xCIF		   IN MUNICIPIOS.CIF%TYPE,
	xTipo_Cli      IN MUNICIPIOS.TIPO_CLI%TYPE,
	xTPC_Vol       IN MUNICIPIOS.TPC_VOL%TYPE,
	xTPC_Eje       IN MUNICIPIOS.TPC_EJE%TYPE,
	xTPC_Recargo   IN MUNICIPIOS.TPC_RECARGO%TYPE,
	xTPC_Demora    IN MUNICIPIOS.TPC_DEMORA%TYPE,
	xTPC_Costas    IN MUNICIPIOS.TPC_COSTAS%TYPE,
	xTPC_Bajas_Vol IN MUNICIPIOS.TPC_BAJAS_VOL%TYPE,
	xTPC_Bajas_Eje IN MUNICIPIOS.TPC_BAJAS_EJE%TYPE,
	xTPC_Bajas_Eje_BR IN MUNICIPIOS.TPC_BAJAS_EJE_BR%TYPE,
	xTPC_Bajas_Eje_BI IN MUNICIPIOS.TPC_BAJAS_EJE_BI%TYPE,
	xTPC_Bajas_Eje_BP IN MUNICIPIOS.TPC_BAJAS_EJE_BP%TYPE,
	xTPC_Bajas_Eje_BO IN MUNICIPIOS.TPC_BAJAS_EJE_BO%TYPE)
AS
BEGIN

  --Guardo la modificación de los campos del municipio
  UPDATE MUNICIPIOS SET ZONA=xZona,NOMBRE=xNombre,ALCALDE=xAlcalde,SECRETARIO=xSecretario,
				INTERVENTOR=xInterventor,TESORERO=xTesorero,COD_POSTAL=xCod_Postal,
				CIF=xCIF,TIPO_CLI=xTipo_Cli,FECHA=xFecha_Inicio,
				TPC_VOL=xTPC_Vol, TPC_EJE=xTPC_Eje,
				TPC_RECARGO=xTPC_Recargo, TPC_DEMORA=xTPC_Demora,
				TPC_COSTAS=xTPC_Costas, TPC_BAJAS_VOL=xTPC_Bajas_Vol,
				TPC_BAJAS_EJE=xTPC_Bajas_Eje,
				TPC_BAJAS_EJE_BR=xTPC_Bajas_Eje_BR,
				TPC_BAJAS_EJE_BI=xTPC_Bajas_Eje_BI,
				TPC_BAJAS_EJE_BP=xTPC_Bajas_Eje_BP,
				TPC_BAJAS_EJE_BO=xTPC_Bajas_Eje_BO
  WHERE AYTO=xAyto;

  IF SQL%NOTFOUND THEN /* Si el municipio no existe, se crea */

	INSERT INTO MUNICIPIOS (AYTO,ZONA,NOMBRE,ALCALDE,SECRETARIO,INTERVENTOR,
		TESORERO,COD_POSTAL,CIF,TIPO_CLI,FECHA,TPC_VOL,TPC_EJE,
		TPC_RECARGO, TPC_DEMORA, TPC_COSTAS, TPC_BAJAS_VOL,
		TPC_BAJAS_EJE,TPC_BAJAS_EJE_BR,TPC_BAJAS_EJE_BI,TPC_BAJAS_EJE_BP,TPC_BAJAS_EJE_BO)
	VALUES
		(xAyto, xZona,xNombre,xAlcalde,xSecretario,xInterventor,
		xTesorero,xCod_Postal,xCIF,xTipo_Cli,xFecha_Inicio,
		xTPC_Vol, xTPC_Eje,xTPC_Recargo, xTPC_Demora, xTPC_Costas, xTPC_Bajas_Vol,
		xTPC_Bajas_Eje,xTPC_Bajas_Eje_BR,xTPC_Bajas_Eje_BI,xTPC_Bajas_Eje_BP,
		xTPC_Bajas_Eje_BO);

  END IF;

END;
/

-- Procedimiento para modificar las comisiones de un UNICO municipio
-- Se pueden modificar de dos formas:
--	a -> Incrementando/Decrementando las comisiones ya existentes
--	b -> Introduciendo nuevas comisiones.
--ENERO - 2.001  AUTOR: LUCAS
-- Modificacion: 09/10/2002 Lucas Fernández Pérez. Modifica las comisiones de un municipio
-- solamente, no de todos como lo hacia antes.

CREATE OR REPLACE PROCEDURE MODIFICA_COMISIONES(
	xFecha 		IN MUNICIPIOS.FECHA%TYPE,
	xTPCVol 		IN MUNICIPIOS.TPC_VOL%TYPE,
	xTPCEje 		IN MUNICIPIOS.TPC_EJE%TYPE,
	xTPCRecargo 	IN MUNICIPIOS.TPC_RECARGO%TYPE,
	xTPCDemora 		IN MUNICIPIOS.TPC_DEMORA%TYPE,
	xTPCCostas	 	IN MUNICIPIOS.TPC_COSTAS%TYPE,
	xTPCBajasVol 	IN MUNICIPIOS.TPC_BAJAS_VOL%TYPE,
	xTPCBajasEje 	IN MUNICIPIOS.TPC_BAJAS_EJE%TYPE,
	xTPCBajasEje_BR 	IN MUNICIPIOS.TPC_BAJAS_EJE_BR%TYPE,
	xTPCBajasEje_BI 	IN MUNICIPIOS.TPC_BAJAS_EJE_BI%TYPE,
	xTPCBajasEje_BP 	IN MUNICIPIOS.TPC_BAJAS_EJE_BP%TYPE,
	xTPCBajasEje_BO 	IN MUNICIPIOS.TPC_BAJAS_EJE_BO%TYPE,
	xTipoModificacion IN INTEGER )
AS

   CURSOR CMUNICIPIOS IS
   SELECT AYTO,TPC_VOL, TPC_EJE, TPC_RECARGO, TPC_DEMORA, TPC_COSTAS, TPC_BAJAS_VOL,
	TPC_BAJAS_EJE, TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI, TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO
   FROM MUNICIPIOS;

BEGIN

   --  Tipo_Modificacion:
   --     0 -> Incremento sobre las comisiones existentes
   --	    1 -> Nuevos valores totales de las comisiones

   IF (xTipoModificacion=1) THEN

      UPDATE MUNICIPIOS SET FECHA=xFecha, TPC_VOL=xTPCVol ,
	   TPC_EJE=xTPCEje, TPC_RECARGO=xTPCRecargo,TPC_DEMORA=xTPCDemora,
	   TPC_COSTAS=xTPCCostas, TPC_BAJAS_VOL=xTPCBajasVol,TPC_BAJAS_EJE=xTPCBajasEje,
	   TPC_BAJAS_EJE_BR=xTPCBajasEje_BR,TPC_BAJAS_EJE_BI=xTPCBajasEje_BI,
	   TPC_BAJAS_EJE_BP=xTPCBajasEje_BP,TPC_BAJAS_EJE_BO=xTPCBajasEje_BO;

   ELSE  -- incremento sobre lo existente
	FOR v_MUNI IN CMUNICIPIOS LOOP

	  UPDATE MUNICIPIOS SET FECHA=xFecha, TPC_VOL=TPC_VOL+xTPCVol,
	     TPC_EJE=TPC_EJE+xTPCEje, TPC_RECARGO=TPC_RECARGO+xTPCRecargo,
	     TPC_DEMORA=TPC_DEMORA+xTPCDemora, TPC_COSTAS=TPC_COSTAS+xTPCCostas,
	     TPC_BAJAS_VOL=TPC_BAJAS_VOL+xTPCBajasVol,
	     TPC_BAJAS_EJE=TPC_BAJAS_EJE+xTPCBajasEje,
	     TPC_BAJAS_EJE_BR=TPC_BAJAS_EJE_BR+xTPCBajasEje_BR,
	     TPC_BAJAS_EJE_BI=TPC_BAJAS_EJE_BI+xTPCBajasEje_BI,
	     TPC_BAJAS_EJE_BP=TPC_BAJAS_EJE_BP+xTPCBajasEje_BP,
	     TPC_BAJAS_EJE_BO=TPC_BAJAS_EJE_BO+xTPCBajasEje_BO
	  WHERE AYTO=v_MUNI.AYTO;

	END LOOP;

   END IF;

END;
/

--
-- 09/10/2002 Lucas Fernandez Perez.
-- Añadir comisiones ESPECÍFICAS para un ayuntamiento y padron.
--
-- MOTIVO: Además de las comisiones globles (a todos los conceptos) puede haber conceptos que
-- necesiten tratamiento especial de comisiones.
-- Esos conceptos se guardan en la tabla COMISIONES_AYTO_PADRON.
--
-- Así, si un concepto de un municipio tiene datos en esa tabla,las comisiones a aplicar
-- serán las de la tabla COMISIONES_AYTO_PADRON; en cambio, si
-- el municipio-padron no tiene datos en esa tabla, se tomaran como comisiones las comisiones
-- globales que se encuentran en la tabla MUNICIPIOS.
--
-- Estas comisiones se utilizan para las liquidaciones.
--
CREATE OR REPLACE PROCEDURE MOD_COMISIONES_AYTO_PADRON(
	xAyto			IN CHAR,
	xPADRON		IN CHAR,
	xFecha 		IN DATE,
	xTPCVol 		IN FLOAT,
	xTPCEje 		IN FLOAT,
	xTPCRecargo 	IN FLOAT,
	xTPCDemora 		IN FLOAT,
	xTPCCostas	 	IN FLOAT,
	xTPCBajasVol 	IN FLOAT,
	xTPCBajasEje 	IN FLOAT,
	xTPCBajasEje_BR 	IN FLOAT,
	xTPCBajasEje_BI 	IN FLOAT,
	xTPCBajasEje_BP 	IN FLOAT,
	xTPCBajasEje_BO 	IN FLOAT,
	xTipoModificacion IN INTEGER )
AS
   xInserta	INTEGER;

BEGIN

   --  Tipo_Modificacion:
   --     0 -> Incremento sobre las comisiones existentes
   --	    1 -> Nuevos valores totales de las comisiones

   xInserta:=0;

   IF (xTipoModificacion=1) THEN

      UPDATE COMISIONES_AYTO_PADRON SET FECHA_INICIO=xFecha, TPC_VOL=xTPCVol ,
	   TPC_EJE=xTPCEje, TPC_RECARGO=xTPCRecargo,TPC_DEMORA=xTPCDemora,
	   TPC_COSTAS=xTPCCostas, TPC_BAJAS_VOL=xTPCBajasVol,TPC_BAJAS_EJE=xTPCBajasEje,
	   TPC_BAJAS_EJE_BR=xTPCBajasEje_BR, TPC_BAJAS_EJE_BI=xTPCBajasEje_BI,
	   TPC_BAJAS_EJE_BP=xTPCBajasEje_BP, TPC_BAJAS_EJE_BO=xTPCBajasEje_BO
	WHERE AYTO=xAYTO AND PADRON=xPADRON;

	IF SQL%NOTFOUND THEN -- Si el municipio no existe, se crea
	   xInserta:=1;
	END IF;

   ELSE  -- incremento sobre lo existente

	UPDATE COMISIONES_AYTO_PADRON SET FECHA_INICIO=xFecha, TPC_VOL=TPC_VOL+xTPCVol,
	   	TPC_EJE=TPC_EJE+xTPCEje, TPC_RECARGO=TPC_RECARGO+xTPCRecargo,
	   	TPC_DEMORA=TPC_DEMORA+xTPCDemora, TPC_COSTAS=TPC_COSTAS+xTPCCostas,
	   	TPC_BAJAS_VOL=TPC_BAJAS_VOL+xTPCBajasVol,
		TPC_BAJAS_EJE=TPC_BAJAS_EJE+xTPCBajasEje,
	     	TPC_BAJAS_EJE_BR=TPC_BAJAS_EJE_BR+xTPCBajasEje_BR,
	     	TPC_BAJAS_EJE_BI=TPC_BAJAS_EJE_BI+xTPCBajasEje_BI,
	     	TPC_BAJAS_EJE_BP=TPC_BAJAS_EJE_BP+xTPCBajasEje_BP,
	     	TPC_BAJAS_EJE_BO=TPC_BAJAS_EJE_BO+xTPCBajasEje_BO
	WHERE AYTO=xAYTO AND PADRON=xPADRON;

	IF SQL%NOTFOUND THEN -- Si el municipio no existe, se crea
	   xInserta:=1;
	END IF;

   END IF;

   -- Hay un trigger ON UPDATE de la tabla comisiones_ayto_padron, que guarda
   -- en el histórico de comisiones las comisiones que había antes de la modificacion.

   if xInserta=1 then
   	INSERT INTO COMISIONES_AYTO_PADRON (AYTO,PADRON,FECHA_INICIO,
		TPC_VOL,TPC_EJE, TPC_RECARGO, TPC_DEMORA, TPC_COSTAS,TPC_BAJAS_VOL, TPC_BAJAS_EJE,
		TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI, TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO)
   	VALUES (xAyto, xPADRON, xFecha, xTPCVol , xTPCEje, xTPCRecargo, xTPCDemora,
	   	xTPCCostas, xTPCBajasVol, xTPCBajasEje,
		xTPCBajasEje_BR, xTPCBajasEje_BI, xTPCBajasEje_BP, xTPCBajasEje_BO);
   end if;

END;
/

--
--Dar de alta y modificar las zonas
--Modificado: 12 de junio de 2002. Agustin Leon Robles. Se ha añadido los campos con la ruta
--de los documentos de Interbase
--Modificado: 24/06/2003. Lucas Fernández Pérez. Nuevos parámetros: xTel1, xTel2, xFax
--
CREATE OR REPLACE PROCEDURE GESTZONAS(
	xZONA 		IN ZONAS.ZONA%TYPE,
      xYEAR 		IN ZONAS.YEAR%TYPE,
	xCIF 			IN ZONAS.CIF%TYPE,
	xCODIGO_ORG 	IN ZONAS.CODIGO_ORGANISMO%TYPE,
	xAYUNTAMIENTO 	IN ZONAS.AYUNTAMIENTO%TYPE,
	xNOMBRE 		IN ZONAS.NOMBRE%TYPE,
	xRESPONSABLE 	IN ZONAS.RESPONSABLE%TYPE,
	xCARGO 		IN ZONAS.CARGO_RESPONSABLE%TYPE,
	xDIRECCION 		IN ZONAS.DIRECCION%TYPE,
	xPOBLACION 		IN ZONAS.POBLACION%TYPE,
	xPROVINCIA 		IN ZONAS.PROVINCIA%TYPE,
	xTEL1	 		IN ZONAS.TELEFONO1%TYPE,
	xTEL2	 		IN ZONAS.TELEFONO2%TYPE,
	xFAX	 		IN ZONAS.FAX%TYPE,
	xE_MAIL 		IN ZONAS.E_MAIL%TYPE,
	xRutaRecauda	IN ZONAS.RUTA_DOCU_RECAUDACION%TYPE,
	xRutaRentas		IN ZONAS.RUTA_DOCU_RENTAS%TYPE,
	xRutaCuentas	IN ZONAS.RUTA_DOCU_CUENTASANUALES%TYPE)
AS
BEGIN


   UPDATE ZONAS SET CIF=xCIF,CODIGO_ORGANISMO=xCODIGO_ORG,AYUNTAMIENTO=xAYUNTAMIENTO,
		NOMBRE=xNOMBRE,RESPONSABLE=xRESPONSABLE,CARGO_RESPONSABLE=xCARGO,
		DIRECCION=xDIRECCION,POBLACION=xPOBLACION,
		PROVINCIA=xPROVINCIA,YEAR=xYEAR,
		TELEFONO1=xTEL1, TELEFONO2=xTEL2, FAX=xFAX, E_MAIL=xE_MAIL,
		RUTA_DOCU_RECAUDACION=xRutaRecauda,
		RUTA_DOCU_RENTAS=xRutaRentas,
		RUTA_DOCU_CUENTASANUALES=xRutaCuentas

	WHERE ZONA=xZONA;

   IF SQL%NOTFOUND THEN
	INSERT INTO ZONAS (ZONA,CIF,CODIGO_ORGANISMO,AYUNTAMIENTO,NOMBRE,RESPONSABLE,
		CARGO_RESPONSABLE,DIRECCION,POBLACION,PROVINCIA,YEAR,E_MAIL,TELEFONO1,TELEFONO2,FAX,
		RUTA_DOCU_RECAUDACION,RUTA_DOCU_RENTAS,RUTA_DOCU_CUENTASANUALES)
	VALUES
		(xZONA,xCIF,xCODIGO_ORG,xAYUNTAMIENTO,xNOMBRE,xRESPONSABLE,xCARGO,
		xDIRECCION,xPOBLACION,xPROVINCIA,xYEAR,xE_MAIL,xTEL1, xTEL2, xFAX,
		xRutaRecauda,xRutaRentas,xRutaCuentas);

	-- INSERTAR SU CAJA
	INSERT INTO SALDOCAJA (ZONA) VALUES (xZONA);

	-- Inserto una nueva tupla en la tabla de configuracion
	INSERT INTO CONFIGURACION (ZONA,MENOR_CUANTIA,MAXIMO_IMPORTE_C63,TIPO_ENTIDAD)
	VALUES (xZONA,150.25,4000,'A');

	-- Inserto una nueva tupla en D_CARTA_PAGO, para meter el escudo y varios titulos
	INSERT INTO D_CARTA_PAGO(ZONA) VALUES (xZona);

   END IF;


END;
/


/* ******************************************************** */

CREATE OR REPLACE PROCEDURE ADDMODUSUARIO (
	xUSUARIO 	 IN	CHAR,
	xZONA 	 IN	CHAR,
	xDNI 		 IN 	CHAR,
	xNOMBRE 	 IN 	VARCHAR,
	xCAMSERVER 	 IN	VARCHAR,
	xCAMOFI 	 IN	VARCHAR,
	xCAMDOCS 	 IN	VARCHAR,
	xCAMIMPRE 	 IN	VARCHAR,
	xDIRECCION 	 IN	VARCHAR,
	xTELEFONO 	 IN	VARCHAR,
	xPOBLACION 	 IN	VARCHAR,
	xPROVINCIA 	 IN	VARCHAR,
	xEMAIL 	 IN	VARCHAR,
	xNIC		 IN   CHAR,
	xMAILOUTLOOK IN   CHAR,
	xOUTLOOK	 IN   CHAR,
	xJefe		 IN   CHAR,
	xRoot		 IN   CHAR,
	xCARGOSZONAS IN	CHAR)
AS
BEGIN


   UPDATE USUARIOS SET ZONA=xZONA,DNI=xDNI,
         		     NOMBRE=xNOMBRE,CAMINO_SERVER=xCAMSERVER,
         		     CAMINO_OFIMATICA=xCAMOFI,CAMINO_DOCS=xCAMDOCS,
         		     CAMINO_IMPRE=xCAMIMPRE,DIRECCION=xDIRECCION,
         		     TELEFONO=xTELEFONO,POBLACION=xPOBLACION,
         		     PROVINCIA=xPROVINCIA,EMAIL=xEMAIL,
			     NIC=xNIC,OUTLOOK=xOUTLOOK,MAILOUTLOOK=xMAILOUTLOOK,
			     ROOT=xROOT,CARGOSZONAS=xCARGOSZONAS
      WHERE USUARIO=xUSUARIO;

   IF SQL%NOTFOUND THEN

      INSERT INTO USUARIOS
        (USUARIO, ZONA, DNI, NOMBRE,
         CAMINO_SERVER, CAMINO_OFIMATICA, CAMINO_DOCS, CAMINO_IMPRE,
         DIRECCION, TELEFONO, POBLACION, PROVINCIA, EMAIL, NIC, OUTLOOK, MAILOUTLOOK,
	   ROOT, CARGOSZONAS )
      VALUES
        (xUSUARIO, xZONA, xDNI, xNOMBRE,
         xCAMSERVER, xCAMOFI, xCAMDOCS, xCAMIMPRE,
         xDIRECCION, xTELEFONO, xPOBLACION, xPROVINCIA, xEMAIL, xNIC,
	   xOUTLOOK, xMAILOUTLOOK, xROOT, xCARGOSZONAS );

      INSERT INTO ZONAS_USUARIO (USUARIO,ZONA) VALUES (xUSUARIO, xZONA);

   ELSE
	UPDATE ZONAS_USUARIO SET ZONA=xZONA WHERE USUARIO=xUSUARIO;
   END IF;

   IF xJEFE='S' THEN
	UPDATE ZONAS SET USUARIO=xUSUARIO WHERE ZONA=xZONA;
   END IF;

END;
/

/******************************************************************************************/

CREATE OR REPLACE FUNCTION MONTH (xFECHA IN DATE)
RETURN INTEGER
AS
BEGIN
  RETURN TO_NUMBER(TO_CHAR(xFECHA,'MM'));
END;
/

/*******************************************************************************************/

CREATE OR REPLACE FUNCTION F_YEAR ( xFECHA IN DATE) RETURN INTEGER
AS
BEGIN
  RETURN TO_NUMBER(TO_CHAR(xFECHA,'YYYY'));
END;
/

/*******************************************************************************************/

CREATE OR REPLACE FUNCTION DAYOFMONTH (xFECHA IN DATE) RETURN INTEGER
AS
BEGIN
  RETURN TO_NUMBER(TO_CHAR(xFECHA,'DD'));
END;
/

/*******************************************************************************************/

CREATE OR REPLACE FUNCTION DAYOFYEAR (xFECHA IN DATE) RETURN INTEGER
AS
BEGIN
   RETURN TO_NUMBER(TO_CHAR(xFECHA,'DDD'));
END;
/


/*******************************************************************************************/
--
-- CREATE OR REPLACE PROCEDURE PUT_YEAR_WORK_Expe(NuevoYear IN CHAR)
-- HA SIDO MOVIDO AL FINAL AL PAQUETE 11-EXPEDIENTES_PAQUETE_CREAR
--

/*******************************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_YEAR_WORK_Noti(NuevoYear IN char)

AS

xYeNoti         char(4);
oldConta        integer;

BEGIN

 /* comprobar que el año a cambiar es distinto del actual */

 SELECT YEAR_RELACION INTO xYeNoti
 FROM GENERNOTI;

 if (NuevoYear<>xYeNoti) then

    SELECT MAX(SUBSTR(RELACION, 6, 5))
    INTO oldConta FROM RELACIONES_NOTI
    WHERE SUBSTR(RELACION, 1, 4)=NuevoYear;

    /* PONER A CERO EL CONTADOR Y EL AÑO AL DEL USUARIO*/

    UPDATE GENERNOTI SET YEAR_RELACION=NuevoYear,
                         ID_RELACION=0;

    if (NuevoYear is not null) AND (oldConta IS NOT NULL) then

       /* poner el antiguo valor almacenado en la tabla */

       UPDATE GENERNOTI SET ID_RELACION=oldConta;

    end if;

  end if;

END;
/

/*******************************************************************************************/
-- MODIFICACIÓN: 06/06/2002 M. Carmen Junco Gómez. Se ha introducido un contador
-- independiente para las datas de bajas.

CREATE OR REPLACE PROCEDURE PUT_YEAR_WORK_Datas(NuevoYear IN CHAR)
AS

xYeData         CHAR(4);
oldContaING     integer;
OLDCONTABAJ     INTEGER;
xZONA           CHAR(2);

CURSOR CZONAS IS
  SELECT YEAR,ZONA FROM ZONAS;

BEGIN

 OPEN CZONAS;

 LOOP

   FETCH CZONAS INTO xYeData,xZONA;
   EXIT WHEN CZONAS%NOTFOUND;

   --comprobar que el año a cambiar es distinto del actual

   if (NuevoYear<>xYeData) then

      SELECT MAX(SUBSTR(NUMERO_DE_DATA, 6, 5))
      INTO OLDCONTAING FROM DATAS_INGRESOS
      WHERE SUBSTR(NUMERO_DE_DATA, 1, 4)=NuevoYear
            AND ZONA=xZONA;

      SELECT MAX(SUBSTR(NUMERO_DE_DATA, 6, 5))
      INTO OLDCONTABAJ FROM DATAS_BAJAS
      WHERE SUBSTR(NUMERO_DE_DATA, 1, 4)=NuevoYear
            AND ZONA=xZONA;

      --poner a cero el contador de datas y el año al del usuario

      UPDATE ZONAS SET YEAR=NuevoYear,
                       NUMERO_DATA=0,
			     NUMERO_DATA_BAJA=0
      WHERE ZONA=xZONA;

      if (NuevoYear is not null) then

        --poner el antiguo valor almacenado en la tabla
        UPDATE ZONAS SET NUMERO_DATA=DECODE(OLDCONTAING,NULL,0,OLDCONTAING),
		             NUMERO_DATA_BAJA=DECODE(OLDCONTABAJ,NULL,0,OLDCONTABAJ)
        WHERE ZONA=xZONA;

      end IF;

   END IF;

 END LOOP;
 CLOSE CZONAS;

END;
/

/****************************************************************************************
Acción: Devuelve el principal de la deuda quitandole los ingresos a cuenta en voluntaria.
        Sirve para calcular el recargo de apremio.
****************************************************************************************/
CREATE OR REPLACE FUNCTION DameIngresosVoluntaria(xValor IN INTEGER)
return float
AS
oPRINCIPAL FLOAT default 0;
xPRINCIPAL	FLOAT	DEFAULT 0;
BEGIN

	--principal del valor
	SELECT PRINCIPAL INTO oPRINCIPAL
	FROM IMPORTE_VALORES WHERE ID=xValor;

	IF oPRINCIPAL IS NULL THEN
         oPRINCIPAL:=0;
	END IF;


	--suma de los ingresos en voluntaria, para poder calcular el recargo de apremio
	--sobre el principal de la deuda en ejecutiva

	SELECT SUM(PRINCIPAL) INTO xPRINCIPAL
	FROM INGRESOS
	WHERE VALOR=xValor and Vol_Eje='V';

	IF xPRINCIPAL IS NULL THEN
 	   xPRINCIPAL:=0;
	END IF;

	oPRINCIPAL:=oPRINCIPAL-xPRINCIPAL;

	RETURN oPRINCIPAL;
END;
/

/**************************************************************************************
Autor: Mª Carmen Junco Gómez
Acción: Rellena una tabla temporal con :
			1. Todos los recibos de un cargo
 			2. Los recibos en ejecutiva de un cargo
			3. Los recibos en ejecutiva de un cargo de una F_APREMIO.
Modificación: 31/10/2002. Lucas Fernández Pérez.
              Se añade el parámetro xFechaProvi IN DATE. Con las notificaciones en
              voluntaria un mismo cargo puede tener varios pases a ejecutiva, y
              varias fechas de providencia.
 			  xFechaProvi indica si el listado de providencia es del cargo completo
 			  (año=1901) o solo de los recibos que tengan una fecha de providencia
 			  determinada (año<>1901)
Modificado: 26/02/2004. Lucas Fernández Pérez. Se añade el nuevo campo cuota_inicial.
Modificado: 28/09/2004. Gloria Maria Calle Hernandez. Se añaden nuevos campos para 
			la impresión del listado de Providencia de Apremio: Objeto Tributario,
			Domicilio_Fiscal, Poblacion, Provincia, Cod_Postal, Recargo. 
			Devuelve parámetro de salida xNum_Apremio no nulo si los valores a imprimir pertenecen 
			al mismo numero de relación apremiado.
Modificado: 06/10/2004. Gloria Maria Calle Hernandez. Añadido parámetro vSentencia para imprimir
		  y por tanto rellenar la tabla temporal las liquidaciones según la sentencia montada y 
		  especificada desde Delphi.
Modificado: 21/10/2004. Gloria Maria Calle Hernandez. Guarda en el objeto tributario el domicilio
			tributario si se trata de recibos (padrones) y el objeto tributraio por ahora, si se trata de
			liquidaciones. Inserta el recargo correspondiente del 10 o el 20 por ciento según si la fecha 
			de fin de periodo voluntario menor o mayor que la entrada de la ley el 30/06/2004 respectivamente. 
Modificado: 08/11/2004. Gloria Maria Calle Hernandez. Guarda en el objeto tributario el domicilio tributario 
			si se trata de recibos (padrones) o de liquidaciones de los conceptos de IBI y Plusvalias;
			y el objeto tributraio, si se trata de liquidaciones de otros conceptos.
Modificado: 09/11/2004. Gloria Maria Calle Hernandez. No distinguía correctamente los valores que deben 
			tener recargo 20% del 10%.
Modificado: 10/11/2004. Gloria Maria Calle Hernandez. Guarda en el objeto tributario la referencia del IAE
			cuando se trata de un valor del concepto de IAE, respetando lo definido para otros conceptos.
Modificado: 11/11/2004. Gloria Maria Calle Hernandez. Modificaciones para comparar en lugar de con el código 
			de concepto para la impresión del objeto tributario compare con el nombre del programa de la 
			tabla de Programas.
Modificado: 16/11/2004. Gloria Maria Calle Hernandez. Corrección sobre el insert para la opción xCargoProvi='P'
			pues no era completo.
Modificado: 02/12/2004. Gloria Maria Calle Hernandez. Añadido campo Tipo_de_objeto a la tabla InformeCargos.
Modificado: 29/03/2005. Gloria Maria Calle Hernandez. Añadido campo Clave_concepto a la tabla InformeCargos.
**************************************************************************************/
CREATE OR REPLACE PROCEDURE Proc_InformeCargos(
			xAYTO  			IN CHAR,
			xCargo 			IN CHAR,
			xCargoProvi		IN CHAR,
			xFechaProvi 	IN DATE,
			xSentencia		IN CHAR,
			xNum_Apremio 	OUT CHAR)
AS
  	-- Variables para crear la sentencia
    TYPE tCURSOR IS REF CURSOR; -- define REF CURSOR type
    vCURSOR 	 tCURSOR;    -- declare cursor variable
	vValores	 VALORES%ROWTYPE;


	vPRINCIPAL   FLOAT DEFAULT 0;
	vDOMICILIO	 VARCHAR2(50);
	vPOBLACION	 VARCHAR2(35);
	vPROVINCIA	 VARCHAR2(35);
	vCODPOSTAL	 CHAR(5);
	vOBJTRIB	 VARCHAR2(1024);
    vPrograma	 CHAR(10); --Nombre Programa
	vTodasFechas CHAR(1);
	vRecargo	 FLOAT	 DEFAULT 0.1;


	--cuando se quiera imprimir un listado de providencia de apremio solo se incluiran
	--recibos que esten en ejecutiva
	CURSOR cProvidencia IS SELECT ID,PADRON,YEAR,PERIODO,RECIBO,OBJETO_TRIBUTARIO,DOM_TRIBUTARIO,TIPO_DE_OBJETO,
		   				          NIF,NOMBRE,PRINCIPAL,RECARGO,F_APREMIO,RELACION_APREMIO,FIN_PE_VOL,CLAVE_CONCEPTO
		   				   	 FROM VALORES WHERE AYTO=xAYTO AND N_CARGO=xCARGO AND VOL_EJE='E';

	--cuando se quiera imprimir un listado de cargo se incluiran tanto recibos en voluntaria
	--como en ejecutiva
	CURSOR cCargo IS SELECT ID,PADRON,YEAR,PERIODO,RECIBO,NIF,CUOTA_INICIAL,PRINCIPAL,NOMBRE,F_APREMIO,CLAVE_CONCEPTO
			 FROM VALORES WHERE AYTO=xAYTO AND N_CARGO=xCARGO;

BEGIN

	-- borramos de la tabla auxiliar antes de introducir nuevos datos
	DELETE FROM InformeCargos WHERE USUARIO=UID;

	--listado de providencia según SENTENCIA pasada
	if xCargoProvi='S' then

       --Abrimos cursor...
       OPEN vCURSOR FOR xSentencia;
       LOOP
   	      FETCH vCURSOR INTO vValores;
	      EXIT WHEN vCURSOR%NOTFOUND;


		  vPRINCIPAL:= DameIngresosVoluntaria(vValores.ID);
		  GetDomicilioFiscal(vValores.NIF,null,vDomicilio,vPoblacion,vProvincia,vCodPostal);

		  IF (trunc(vValores.FIN_PE_VOL,'dd') <= to_date('30/06/2004','dd/mm/yyyy')) THEN
		      vRecargo:= 0.2;
		  ELSE vRecargo:= 0.1;
		  END IF;

		  IF vValores.Tipo_de_objeto='R' THEN
		     vOBJTRIB:= vValores.DOM_TRIBUTARIO;
		  ELSE
		  	  BEGIN
			     SELECT PROGRAMA INTO vPrograma FROM PROGRAMAS WHERE CONCEPTO=vValores.Padron;
		      EXCEPTION
	    	     WHEN OTHERS THEN
			          BEGIN 
			   		     SELECT 'EXACCIONES' INTO vPrograma FROM DUAL WHERE vValores.Padron IN 
			  			 (SELECT DISTINCT COD_ORDENANZA FROM EXACCIONES);				 
					  EXCEPTION
			   		     WHEN OTHERS THEN
      			  		      vPrograma:=NULL;
      				  END;
	  		  END;

		      BEGIN
			     select Decode(vPrograma,'IBI',Decode(TRIM(REF_CATASTRAL),null,
				  		 						 Decode(TRIM(DOMI_TRIBUTARIO),null,SUBSTR(MOTIVO,1,50),DOMI_TRIBUTARIO),REF_CATASTRAL),
				        Decode(vPrograma,'PLUSVALIA',Decode(TRIM(REF_CATASTRAL),null,
						 						 Decode(TRIM(DOMI_TRIBUTARIO),null,SUBSTR(MOTIVO,1,50),DOMI_TRIBUTARIO),REF_CATASTRAL),
						Decode(vPrograma,'IAE',Decode(instr(upper(motivo),'REFERENCIA'),0,
						 						 substr(motivo,instr(upper(motivo),'RFA')+4,14),substr(motivo,instr(upper(motivo),'REFERENCIA')+11,14)),
						Decode(TRIM(DOMI_TRIBUTARIO),null,SUBSTR(MOTIVO,1,50),DOMI_TRIBUTARIO))))
				   into vOBJTRIB
				   from liquidaciones where idvalor=vValores.ID;
			  EXCEPTION
			 	 when no_data_found then
				      vOBJTRIB:= null;
			  END;
		  END IF;

		  INSERT INTO InformeCargos (ID,AYTO,PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,OBJ_TRIBUTARIO,
				   					 NIF,NOMBRE,DOMI_FISCAL,POBLACION,PROVINCIA,COD_POSTAL,
									 N_CARGO,F_APREMIO,PRINCIPAL,RECARGO,CLAVE_CONCEPTO)
		  VALUES (vValores.ID,vValores.AYTO,vValores.PADRON,vValores.YEAR,vValores.PERIODO,vValores.RECIBO,
		  		  vValores.TIPO_DE_OBJETO,vOBJTRIB,
		  		  vValores.NIF,vValores.NOMBRE,vDomicilio,vPoblacion,vProvincia,vCodPostal,
		  		  vValores.N_CARGO,vValores.F_APREMIO,vPRINCIPAL,vPRINCIPAL*vRecargo,vValores.CLAVE_CONCEPTO);
	   END LOOP;

	--listado de providencia
	elsif xCargoProvi='P' then

   	   --como no podemos enviar nulos en parametros de fecha, utilizamos este año
	   if trim(xFechaProvi) is null then
	      vTodasFechas:='S';
	   else
  		  vTodasFechas:='N';
	   end if;

	   FOR vValores2 IN cProvidencia
	   LOOP

	   	 if ((vTodasFechas='S') OR
		    (trunc(vValores2.F_Apremio,'dd')=trunc(xFechaProvi,'dd'))) then

			vPRINCIPAL:= DameIngresosVoluntaria(vValores2.ID);
			GetDomicilioFiscal(vValores2.NIF,null,vDomicilio,vPoblacion,vProvincia,vCodPostal);

		    IF (trunc(vValores2.FIN_PE_VOL,'dd') <= to_date('30/06/2004','dd/mm/yyyy')) THEN
		        vRecargo:= 0.2;
  	  	    ELSE vRecargo:= 0.1;
  	  	    END IF;

		    IF vValores2.Tipo_de_objeto='R' THEN
		       vOBJTRIB:= vValores2.DOM_TRIBUTARIO;
		    ELSE
		  	   BEGIN
			      SELECT PROGRAMA INTO vPrograma FROM PROGRAMAS WHERE CONCEPTO=vValores2.Padron;
		       EXCEPTION
	    	      WHEN OTHERS THEN
			           BEGIN 
			   		      SELECT 'EXACCIONES' INTO vPrograma FROM DUAL WHERE vValores2.Padron IN 
			  			  (SELECT DISTINCT COD_ORDENANZA FROM EXACCIONES);				 
					   EXCEPTION
			   		      WHEN OTHERS THEN
      			  		       vPrograma:=NULL;
      				   END;
	  		   END;

 		       BEGIN
			      select Decode(vPrograma,'IBI',Decode(TRIM(REF_CATASTRAL),null,
				   	 						    Decode(TRIM(DOMI_TRIBUTARIO),null,SUBSTR(MOTIVO,1,50),DOMI_TRIBUTARIO),REF_CATASTRAL),
				         Decode(vPrograma,'PLUSVALIA',Decode(TRIM(REF_CATASTRAL),null,
						 						Decode(TRIM(DOMI_TRIBUTARIO),null,SUBSTR(MOTIVO,1,50),DOMI_TRIBUTARIO),REF_CATASTRAL),
						 Decode(vPrograma,'IAE',Decode(instr(upper(motivo),'REFERENCIA'),0,
						 						substr(motivo,instr(upper(motivo),'RFA')+4,14),substr(motivo,instr(upper(motivo),'REFERENCIA')+11,14)),
						 Decode(TRIM(DOMI_TRIBUTARIO),null,SUBSTR(MOTIVO,1,50),DOMI_TRIBUTARIO))))
				    into vOBJTRIB
				    from liquidaciones where idvalor=vValores2.ID;
			   EXCEPTION
			   	  when no_data_found then
				       vOBJTRIB:= null;
			   END;
		    END IF;

		    INSERT INTO InformeCargos (ID,AYTO,PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,OBJ_TRIBUTARIO,
				   					 NIF,NOMBRE,DOMI_FISCAL,POBLACION,PROVINCIA,COD_POSTAL,
									 N_CARGO,F_APREMIO,PRINCIPAL,RECARGO,CLAVE_CONCEPTO)
		    VALUES (vValores2.ID,xAYTO,vValores2.PADRON,vValores2.YEAR,vValores2.PERIODO,vValores2.RECIBO,
		    		vValores2.TIPO_DE_OBJETO,vOBJTRIB,
				    vValores2.NIF,vValores2.NOMBRE,vDomicilio,vPoblacion,vProvincia,vCodPostal,
				    xCARGO,vValores2.F_APREMIO,vPRINCIPAL,vPRINCIPAL*vRecargo,vValores2.CLAVE_CONCEPTO);

		 end if;
	   END LOOP;

       BEGIN
	      SELECT Distinct RELACION_APREMIO INTO xNum_Apremio FROM VALORES WHERE AYTO=xAYTO AND N_CARGO=xCARGO AND VOL_EJE='E';
	   EXCEPTION
	      WHEN NO_DATA_FOUND OR TOO_MANY_ROWS THEN
		       xNum_Apremio:= Null;
	   END;

	else	--listado de cargo
	   FOR v_valor IN cCargo
	   LOOP
		INSERT INTO InformeCargos (ID,AYTO,PADRON,YEAR,PERIODO,RECIBO,
			   					   NIF,NOMBRE,N_CARGO,F_APREMIO,CUOTA_INICIAL,PRINCIPAL,CLAVE_CONCEPTO)
		VALUES (v_valor.ID,xAYTO,v_valor.PADRON,v_valor.YEAR,v_valor.PERIODO,v_valor.RECIBO,
			    v_valor.NIF,v_valor.NOMBRE,xCARGO,v_valor.F_APREMIO,v_valor.CUOTA_INICIAL,v_valor.PRINCIPAL,
				v_valor.CLAVE_CONCEPTO);
	   END LOOP;
	end if;

END;
/

/***********************************************************************************
Acción: Gráfico de situación por cargos
MODIFICACIÓN: 09/10/2001 M. Carmen Junco Gómez. Necesitaba reiniciar variables.
Parámetros: xOpcion tomará dos valores 0/1 0 año de contraido 1 año del valor
MODIFICACIÓN: 12/12/2002 M. Carmen Junco Gómez. Organismo_Ext puede tomar sólo los
              valores 'N','R','S'. Descartamos 'A' de ingresos de la Junta
***********************************************************************************/

CREATE OR REPLACE PROCEDURE INSERT_GRAFICOS_CARGOS(
		xAyto		 IN 	char,
		xPadron 	 IN 	char,
		xYearInicial IN 	char,
		xYearFinal	 IN 	char,
	      xYearIngreso IN   char,
		xPeri		 IN 	char,
		xOpcion	 IN   INTEGER,
		xTotalCargo1 OUT	FLOAT,
		xTotalCargo2 OUT  FLOAT)

AS
   xIngresos 		float default 0;
   xBajas			float default 0;
   xIngresosACuenta	float default 0;
   xPendiente		float default 0;
   xYear			char(4);
   xYearIngre		char(4);

   xSUMA_V FLOAT:=0;
   xSUMA_E FLOAT:=0;
   xSUMA_P FLOAT:=0;

   CURSOR cINGRE IS
   SELECT I.PRINCIPAL,I.VOL_EJE,V.F_INGRESO,V.FECHA_DE_BAJA
	FROM INGRESOS I, VALORES V
	WHERE I.VALOR=V.ID AND V.AYTO=xAYTO AND V.PADRON=xPADRON
	AND V.YEAR=xYEAR AND V.PERIODO=xPERI
	AND I.YEAR_INGRE LIKE xYEarIngre||'%'
	AND I.ORGANISMO_EXT<>'A';

   --Bajas
   CURSOR cBAJAS IS
   SELECT B.PRINCIPAL,B.VOL_EJE
	FROM BAJAS B, VALORES V
	WHERE B.VALOR=V.ID AND V.AYTO=xAYTO AND V.PADRON=xPADRON
	AND V.YEAR=xYEAR AND V.PERIODO=xPERI
	AND B.YEAR_BAJA LIKE xYEarIngre||'%';

BEGIN

   /* Borramos los datos antiguos */
   DELETE from TMP_GRAFICOS_CARGOS
   WHERE USUARIO=USER AND YEAR between xYearInicial AND xYearFinal AND
        AYTO=xAYTO AND CONCEPTO=xPADRON AND PERIODO=xPERI;

   xTotalCargo1:=0;
   xTotalCargo2:=0;

   xYear:=xYearInicial;

   if xOpcion=0 then
      xYearIngre:=xYearIngreso;
   end if;

   -- Total del CONCEPTO año inicial
   select sum(principal) into xTotalCargo1 from valores
   where ayto=xAyto and padron=xPadron and year=xYearInicial and periodo=xPeri;

   Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
   values (xYear,'CARGO', xTotalCargo1, xAYTO, xPADRON, xPERI);

   if xTotalCargo1 is null then
      xTotalCargo1:=0;
   end if;

   IF xYearInicial <> xYearFinal THEN
      -- Total del CONCEPTO año final
      select sum(principal) into xTotalCargo2 from valores
      where ayto=xAyto and padron=xPadron
	and year=xYearFinal and periodo=xPeri;
   ELSE
      xTotalCargo2:=0;
   END IF;

   if xTotalCargo2 is null then
      xTotalCargo2:=0;
   end if;


   WHILE xYear <= xYearFinal
   LOOP

      xSUMA_P:=0;
	xSUMA_V:=0;
	xSUMA_E:=0;
	xPENDIENTE:=0;

      -- INGRESOS

	FOR v_cINGRE IN cINGRE
      LOOP

	   -- Entregas a cuenta
	   IF v_cINGRE.F_INGRESO IS NULL AND v_cINGRE.FECHA_DE_BAJA IS NULL THEN
	      xSUMA_P:=xSUMA_P + v_cINGRE.principal;
	   END IF;

    	   IF v_cINGRE.vol_eje='E' THEN
    	      xSUMA_E:=xSUMA_E + v_cINGRE.principal;
    	   ELSE
	      xSUMA_V:=xSUMA_V + v_cINGRE.principal;
    	   END IF;

      END LOOP;

	IF xSUMA_E IS NULL THEN
	   xSUMA_E:=0;
	END IF;

	IF xSUMA_V IS NULL THEN
	   xSUMA_V:=0;
	END IF;

	-- Ingresos de un concepto año y periodo

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'INGRESOS', xSUMA_E + xSUMA_V , xAYTO, xPADRON, xPERI);

	-- Ingresos en VOLUNTARIA

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'INGRESOS VOLUNTARIA', xSUMA_V, xAYTO, xPADRON, xPERI);

	-- Ingresos en EJECUTIVA

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'INGRESOS EJECUTIVA', xSUMA_E, xAYTO, xPADRON, xPERI);


	-- Pendiente de cobro
	select sum(principal) into xPendiente
	from VALORES
	where ayto=xAyto and padron=xPadron and year=xYear and periodo=xPeri
	AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL;

	if xPendiente is null then
	   xPendiente:=0;
	end if;

	-- Ingresos a cuenta de los valores pendientes

	if xSUMA_P IS NULL then
	   xSUMA_P:=0;
	end if;

	xPendiente := xPendiente - xSUMA_P;

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'PENDIENTE',xPendiente, xAYTO, xPADRON, xPERI);



	-- Bajas
	xSUMA_E := 0;
	xSUMA_V := 0;

	FOR v_cBAJAS IN cBAJAS
      LOOP

    	   IF v_cBAJAS.vol_eje='E' THEN
    	      xSUMA_E:=xSUMA_E + v_cBAJAS.principal;
    	   ELSE
	      xSUMA_V:=xSUMA_V + v_cBAJAS.principal;
    	   END IF;

      END LOOP;

	IF xSUMA_E IS NULL THEN
	   xSUMA_E:=0;
	END IF;

	IF xSUMA_V IS NULL THEN
	   xSUMA_V:=0;
	END IF;

	-- SUMA TOTAL DE BAJAS

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'BAJAS', xSUMA_E + xSUMA_V, xAYTO, xPADRON, xPERI );


	--Bajas en VOLUNTARIA

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'BAJAS VOLUNTARIA', xSUMA_V, xAYTO, xPADRON, xPERI);

	--Bajas en EJECUTIVA

	Insert Into TMP_GRAFICOS_CARGOS(YEAR,TIPO,IMPORTE,AYTO,CONCEPTO,PERIODO)
	values (xYear,'BAJAS EJECUTIVA', xSUMA_E, xAYTO, xPADRON, xPERI);


	-- Aumentamos el año para el bucle
	xYear:=xYear+1;

   END LOOP;

END;
/

/****************************************************************************************
Acción: caché para los graficos de ingresos entre fechas
MODIFICACIÓN: Mª Carmen Junco Gómez. Se han de excluir los ingresos de la Junta
			  (Organismo_Ext='A')
Modificado 23/10/2003. Agustín León Robles.  No actualiza bien las graficas. De todas 
		formas se ha probado con los datos reales de Salobreña de 2 años completos de ingresos
		y no tarda absolutamente nada de tiempo
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE INSERT_GRAFICOS_INGRESOS(xYearGrafico IN char)
AS
xCuantos integer default 0;
CURSOR cINGRE IS
SELECT SUM(PRINCIPAL) AS PRINCIPAL,SUM(RECARGO) AS RECARGO,
	SUM(COSTAS) AS COSTAS,SUM(DEMORA) AS DEMORA,
	VOL_EJE,AYTO,ZONA,MES,YEAR_INGRE
	FROM INGRESOS
	WHERE YEAR_INGRE=xYearGrafico AND ORGANISMO_EXT<>'A'
	GROUP BY VOL_EJE,AYTO,ZONA,MES,YEAR_INGRE
	ORDER BY MES,VOL_EJE;

CURSOR cINGRE_MES IS
SELECT SUM(PRINCIPAL) AS PRINCIPAL,SUM(RECARGO) AS RECARGO,
	SUM(COSTAS) AS COSTAS,SUM(DEMORA) AS DEMORA,
	VOL_EJE,AYTO,ZONA,MES,YEAR_INGRE
	FROM INGRESOS
	WHERE YEAR_INGRE=xYearGrafico and MES>=to_char(ADD_MONTHS(SYSDATE,-1),'mm')
	AND ORGANISMO_EXT<>'A'
	GROUP BY VOL_EJE,AYTO,ZONA,MES,YEAR_INGRE
	ORDER BY MES,VOL_EJE;
BEGIN


--para la primera vez se leen todos los datos del año actual
--SELECT COUNT(*) INTO xCuantos
--	FROM TMP_GRAFICOS_INGRESOS where usuario=user AND YEAR=xYearGrafico;

--if xCuantos=0 then
	/* Borramos los datos antiguos */
	delete from TMP_GRAFICOS_INGRESOS where usuario=user AND YEAR=xYearGrafico;

	FOR v_cINGRE IN cINGRE LOOP
		INSERT INTO TMP_GRAFICOS_INGRESOS (USUARIO,ZONA,AYTO,MES,YEAR,VOL_EJE,
			PRINCIPAL,RECARGO,COSTAS,INTERESES)
		VALUES (USER,v_cINGRE.ZONA,v_cINGRE.AYTO,v_cINGRE.MES,v_cINGRE.YEAR_INGRE,
			v_cINGRE.VOL_EJE,v_cINGRE.PRINCIPAL,v_cINGRE.RECARGO,v_cINGRE.COSTAS,
			v_cINGRE.DEMORA);
	END LOOP;
	return;
--end if;

-- si es el año en curso y estamos mas adelante del primer mes solo leeremos los datos del mes
-- anterior y el actual
/*if xYearGrafico=to_char(sysdate,'yyyy') and to_char(sysdate,'mm')>'02' then

	delete from TMP_GRAFICOS_INGRESOS where usuario=user AND YEAR=xYearGrafico
				and mes>=to_char(ADD_MONTHS(SYSDATE,-1),'mm');

	FOR v_cINGRE IN cINGRE_MES LOOP
		INSERT INTO TMP_GRAFICOS_INGRESOS (USUARIO,ZONA,AYTO,MES,YEAR,VOL_EJE,
			PRINCIPAL,RECARGO,COSTAS,INTERESES)
		VALUES (USER,v_cINGRE.ZONA,v_cINGRE.AYTO,v_cINGRE.MES,v_cINGRE.YEAR_INGRE,
			v_cINGRE.VOL_EJE,v_cINGRE.PRINCIPAL,v_cINGRE.RECARGO,v_cINGRE.COSTAS,
			v_cINGRE.DEMORA);
	END LOOP;
	return;
end if;

-- solo para releer el primer mes del año en curso
if xYearGrafico=to_char(sysdate,'yyyy') and to_char(sysdate,'mm')='01' then
	delete from TMP_GRAFICOS_INGRESOS where usuario=user AND YEAR=xYearGrafico;

	FOR v_cINGRE IN cINGRE LOOP
		INSERT INTO TMP_GRAFICOS_INGRESOS (USUARIO,ZONA,AYTO,MES,YEAR,VOL_EJE,
			PRINCIPAL,RECARGO,COSTAS,INTERESES)
		VALUES (USER,v_cINGRE.ZONA,v_cINGRE.AYTO,v_cINGRE.MES,v_cINGRE.YEAR_INGRE,
			v_cINGRE.VOL_EJE,v_cINGRE.PRINCIPAL,v_cINGRE.RECARGO,v_cINGRE.COSTAS,
			v_cINGRE.DEMORA);
	END LOOP;
end if;
*/
END;
/




/* *************************************************************************** */
-- Antonio Pérez Caballero
-- 26-01-2001
-- Suma del principal ingresedo de todos los valores de un expediente
/* *************************************************************************** */

-- Suma del principal ingresedo de todos los valores de un expediente

CREATE OR REPLACE FUNCTION GetSumaPrinIngreExpe(xIDExpe IN INTEGER)
RETURN FLOAT

AS
xPRINCIPAL FLOAT;
BEGIN

   SELECT SUM(PRINCIPAL) Into xPRINCIPAL FROM INGRESOS
   WHERE VALOR IN (select ID from valores where expediente=xIDExpe
	and F_ingreso is null
	and fecha_de_baja is null
	and F_suspension is null);


   if xPRINCIPAL is null then
   	RETURN 0;
   else
   	RETURN xPRINCIPAL;
   end if;

END;
/

-- Suma del principal ingresedo de un valor

CREATE OR REPLACE FUNCTION GetSumaPrinIngreValor(xIDValor IN INTEGER)
RETURN FLOAT

AS
xPRINCIPAL FLOAT;
BEGIN

   SELECT SUM(PRINCIPAL) Into xPRINCIPAL FROM INGRESOS
   WHERE VALOR=xIDValor;

   if xPRINCIPAL is null then
   	RETURN 0;
   else
   	RETURN xPRINCIPAL;
   end if;

END;
/

-- Modificado : 15/12/2003. Lucas Fernández Pérez. 
-- Añade a la descripción la clave_concepto del recibo
CREATE OR REPLACE FUNCTION GetDescripcionValor(xIDValor IN INTEGER)
RETURN VARCHAR2

AS
	xDescri Varchar2(190);
BEGIN

  SELECT PADRON||' - '||YEAR||' - '||PERIODO||' - '||RECIBO||'  '||
    RTRIM(substr(C.DESCRIPCION,1,39) ||' '||RTRIM(V.DOM_TRIBUTARIO)||' -- '||CLAVE_CONCEPTO)
  Into xDescri
  FROM VALORES V, CONCEPTOS C
  WHERE V.ID=xIDValor
  AND V.PADRON=C.CONCEPTO;
  
  RETURN xDescri;

END;
/

/* ************************************************************* */
-- NOS DEVUELVE UNA CADENA DE CARACTERES CON EL NIF Y SU LISTA DE MOTES
-- 'NIF','MOTE1','MOTE2'....
--


CREATE OR REPLACE FUNCTION ListaDeMotes(xNIF CHAR)
RETURN VARCHAR2
AS

xlistaDeNIF VARCHAR2(1024);
xCUANTOS INT;
ComillaSimple char(1):=chr(39);


CURSOR cLISTANIF IS
SELECT ALIASNIF FROM ALIASDNI
		WHERE NIFBUENO=xNIF;

BEGIN

   -- Buscamos los créditos que se han dado de baja pero que aún no están prescritos

	SELECT COUNT(*) INTO xCUANTOS FROM ALIASDNI
		WHERE NIFBUENO=xNIF;

	IF xCUANTOS = 0 THEN
	   xlistaDeNIF:=chr(39) || xNIF || chr(39);
	ELSE
	   xlistaDeNIF:=chr(39) || xNIF || chr(39) ;
	   FOR v_cLISTANIF IN cLISTANIF
	     LOOP
		  xlistaDeNIF:=xlistaDeNIF || ',' || chr(39) || v_cLISTANIF.ALIASNIF || chr(39);
	     END LOOP;
	END IF;

RETURN RTRIM(xlistaDeNIF);

END;
/

--
-- 14-05-2002 Antonio Pérez Caballero
-- Poner unos permisos a un usuario
--
CREATE OR REPLACE PROCEDURE SetAutUser(
	xUsuario IN Char,
	xFormu   IN Integer,
	xPermiso IN Integer)
AS
BEGIN

UPDATE UsuaPerForm SET PERMISO1=xPermiso
	WHERE USUARIO=xUsuario
	AND FORMU=xFormu;

IF SQL%NOTFOUND THEN
   INSERT INTO UsuaPerForm (USUARIO,FORMU,PERMISO1)
	VALUES (xUsuario, xFormu, xPermiso);
END IF;

END;
/

--
-- 15-05-2002 Antonio Pérez Caballero
-- Quitar una zona a un usuario
--
CREATE OR REPLACE PROCEDURE ZonasUserDel(
	xUsuario IN Char,
	xZona    IN Char)
AS
BEGIN

Delete From ZONAS_USUARIO Where Usuario=xUsuario and Zona=xZona;

END;
/


/********************************************************************************************
Autor: 29/05/2002 Antonio Pérez Caballero
Acción: Cuando en el formulario de modificaciones de conceptos LiquiAddConcep
	  se cambia el tipo de objeto y se marca la opción de aplicar cambios en Recaudación,
	  se actualiza el valor de TIPO_DE_TRIBUTO en la tabla de valores.
MODIFICACIÓN: 18/09/2002 M. Carmen Junco Gómez. Ya que la modificación de un concepto afecta
		  sólo a un municipio, la búsqueda en valores también debe ser sólo para
		  recibos de este municipio
********************************************************************************************/

CREATE OR REPLACE PROCEDURE TipoDeObjetoCHG(
		xAyto		IN  CHAR,
		xConcepto   IN  CHAR,
		xTipoObjeto IN  CHAR)
AS
BEGIN

   -- Sólo actualizo las filas que realmente tengo que actualizar
   Update Valores set TIPO_DE_TRIBUTO=xTipoObjeto
   Where AYTO=xAYTO AND PADRON=xConcepto AND TIPO_DE_TRIBUTO<>xTipoObjeto;

END;
/

/********************************************************************/
-- Lucas Fernández Pérez.
-- Función para obtener el SID (Session ID) de la B.D. Este número es único
-- por sesion, a diferencia del UID (User ID) que es único por usuario
/********************************************************************/

GRANT SELECT ON SYS.V_$MYSTAT TO GIALNET;
CREATE OR REPLACE FUNCTION GETSID
RETURN INTEGER
AS
xSID INTEGER;
BEGIN
	SELECT MAX(SID) INTO xSID FROM SYS.V_$MYSTAT;
	RETURN(xSID);
END;
/


-- procedimiento para indicar en que momento incluir el 20% de recargo
CREATE OR REPLACE PROCEDURE CONF_CALCULO20 (
			xRECARGO IN INTEGER)
AS
BEGIN
	UPDATE CONFIGURACION SET RECARGO=xRECARGO 
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);
END;			
/

/********************************************************************/
COMMIT;
/********************************************************************/
