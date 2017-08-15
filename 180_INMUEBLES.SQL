-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/* *************************************************************************************** */
-- Cuando un expediente llega al embargo de bienes inmuebles viene agrupado por todos
-- los debitos de un deudor, ya sean de uno o varios municipios y/o de deudas de la junta
-- pero como los bienes hay que inscribirlos en su embargo preventivo en el registro de
-- la propiedad a nombre del derecho de cobro, es decir a nombre del ayuntamiento al cual se
-- le debe, no nos queda más remedio que partir el expediente en tantos embargos de bienes
-- inmuebles como deudores haya
--
-- El procedimeinto principal se llama PUT_UnExpeEnLoteInmuebles y este a su vez llama
-- a los procedimientos INMUEBLES_DIVIDIR_AYTO para dividir en tantos expedientes como
-- ayuntamientos deudores y al procedimiento INMUEBLES_DIVIDIR_JUNTA para las deudas
-- de la junta de andalucía
-- Antonio Pérez Caballero 23 de Marzo del 2001
/* *************************************************************************************** */
-- Inserta un embargo de inmuebles a un expediente de un deudor. La deuda es a un municipio
/* *************************************************************************************** */
/*INTERNO*/
CREATE OR REPLACE PROCEDURE INMUEBLES_DIVIDIR_AYTO(
			xIDExpe IN INT, 
			xZona IN char,
			xAyto IN char,
			xEXPE IN CHAR,
			xNIF IN CHAR)
AS

xPRINPEN 		FLOAT DEFAULT 0;
xRECAPEN 		FLOAT DEFAULT 0;
PCOSTAS 		FLOAT DEFAULT 0;
PDEMORA 		FLOAT DEFAULT 0;
xTOTAL 	        FLOAT DEFAULT 0;
sPrincipal		FLOAT DEFAULT 0;
sRecargo		FLOAT DEFAULT 0;
xLast           INT;
xCuantos		INT;

CURSOR cVALORES IS
	SELECT ID FROM VALORES
	where Expediente=xIDExpe
            and F_ingreso is null
            and Fecha_de_baja is null
            and F_suspension is null
            AND ID_INMUEBLES IS NULL
		AND AYTO=xAYTO
	for update of ID_INMUEBLES;
	
BEGIN


	-- Averiguar el número de recibos pendientes
      Select count(*) into xCuantos from valores
      where Expediente=xIDExpe
            and F_ingreso is null
            and Fecha_de_baja is null
            and F_suspension is null
            AND ID_INMUEBLES IS NULL
		AND AYTO=xAYTO;

	-- Suma del pendiente por cada ayuntamiento

	FOR v_Valores IN cVALORES
	LOOP
		PkIngresos.GET_PENDIENTE(v_Valores.ID, xPRINPEN, xRECAPEN, PCOSTAS, PDEMORA, xTOTAL);
		sPrincipal:=sPrincipal+xPRINPEN;
		sRecargo:=sRecargo+xRECAPEN;
	END LOOP;

	-- creamos el expediente de embargo

      INSERT INTO EMBARGOS_INMUEBLES
         (IDEXPE, DEUDA_TOTAL, NIF, ZONA, AYTO, EXPEDIENTE,
          N_RECIBOS, F_ACUMULACION, F_ANTERIOR_ACU,
          PRINCIPAL, RECARGO)
      VALUES
         (xIDExpe, ROUND(sPrincipal+sRecargo,2), xNIF, xZONA, xAYTO, xEXPE,
             xCUANTOS, sysdate, sysdate, ROUND(sPrincipal,2), ROUND(sRecargo,2))
	return ID into xLast;

	-- Se lo asignamos a los valores 
	FOR v_Valores IN cVALORES
	LOOP
		UPDATE VALORES SET ID_INMUEBLES=xLast
			where current of cVALORES;
	END LOOP;

END;
/

/* *************************************************************************************** */
-- Inserta un embargo de inmuebles a un expediente de un deudor.La deuda es a la junta.
/* *************************************************************************************** */
/*INTERNO*/
CREATE OR REPLACE PROCEDURE INMUEBLES_DIVIDIR_JUNTA(
			xIDExpe IN INT, 
			xZona IN char,
			xEXPE IN CHAR,
			xNIF IN CHAR)
AS

xPRINPEN 		FLOAT DEFAULT 0;
xRECAPEN 		FLOAT DEFAULT 0;
PCOSTAS 		FLOAT DEFAULT 0;
PDEMORA 		FLOAT DEFAULT 0;
xTOTAL  		FLOAT DEFAULT 0;
sPrincipal		FLOAT DEFAULT 0;
sRecargo		FLOAT DEFAULT 0;
xLast 		    INT;
xCuantos		INT;

CURSOR cVALORES IS
	SELECT V.ID FROM VALORES V, MUNICIPIOS M
	where V.Expediente=xIDExpe
            and V.F_ingreso is null
            and V.Fecha_de_baja is null
            and V.F_suspension is null
            AND V.ID_INMUEBLES IS NULL
		AND V.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN'
	FOR UPDATE of ID_INMUEBLES;

BEGIN

	-- Averiguar el número de recibos pendientes
    Select count(*) into xCuantos FROM VALORES V, MUNICIPIOS M
	where V.Expediente=xIDExpe
            and V.F_ingreso is null
            and V.Fecha_de_baja is null
            and V.F_suspension is null
            AND V.ID_INMUEBLES IS NULL
		AND V.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN';

	-- Suma del pendiente por cada ayuntamiento
	FOR v_Valores IN cVALORES
	LOOP
		PkIngresos.GET_PENDIENTE(v_Valores.ID, xPRINPEN, xRECAPEN, PCOSTAS, PDEMORA, xTOTAL);
		sPrincipal:=sPrincipal+xPRINPEN;
		sRecargo:=sRecargo+xRECAPEN;
	END LOOP;

	-- creamos el expediente de embargo
    INSERT INTO EMBARGOS_INMUEBLES
       (IDEXPE, DEUDA_TOTAL, NIF, ZONA, AYTO, EXPEDIENTE,
        N_RECIBOS, F_ACUMULACION, F_ANTERIOR_ACU,
        PRINCIPAL, RECARGO)
    VALUES
       (xIDExpe, ROUND(sPrincipal+sRecargo,2), xNIF, xZONA, 'JUN', xEXPE,
           xCUANTOS, sysdate, sysdate, ROUND(sPrincipal,2), ROUND(sRecargo,2))
	return ID into xLast;

	-- Se lo asignamos a los valores 
	FOR v_Valores IN cVALORES
	LOOP
		UPDATE VALORES SET ID_INMUEBLES=xLast
			where current of cVALORES;
	END LOOP;

END;
/

/* *************************************************************************************** */
-- Parte de un expediente en trámite de embargo de inmuebles y estado PENDIENTE.
-- Genera un embargo de inmuebles para cada ayuntamiento y/o para la junta, y 
-- pasa al expediente al estado de ABIERTO en ese trámite. 
/* *************************************************************************************** */
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PUT_UnExpeEnLoteInmuebles(xIDExpe IN INTEGER)

AS
xPENDIENTE FLOAT DEFAULT 0;
xNIF       CHAR(10);
xZONA      CHAR(2);
xAYTO      CHAR(3);
xEXPE      CHAR(10);
xCuantos   INT DEFAULT 0;
sPrincipal FLOAT DEFAULT 0;
sRecargo   FLOAT DEFAULT 0;
sCostas    FLOAT DEFAULT 0;
sDemora    FLOAT DEFAULT 0;
sPendiente FLOAT DEFAULT 0;
xFECHA_HOY DATE;
xMENOR     FLOAT;
xJUNTA     CHAR(1);
xNLote     CHAR(8);
xCadena    CHAR(150);

CURSOR cCLIENTES IS 
	SELECT V.AYTO,M.TIPO_CLI FROM VALORES V, MUNICIPIOS M
		WHERE V.AYTO=M.AYTO
		AND EXPEDIENTE=xIDExpe
		AND F_ingreso is null
      	AND Fecha_de_baja is null
      	AND F_suspension is null
      	AND ID_INMUEBLES IS NULL
	GROUP BY V.AYTO,M.TIPO_CLI;

BEGIN

   xFECHA_HOY:=SYSDATE;

-- Averiguar la zona gestora del expediente, el nif del deudor

   Select DEUDOR,ZONA,EXPEDIENTE Into xNIF,xZONA,xEXPE
   	from EXPEDIENTES
   	WHERE ID=xIDExpe;

--   SELECT COUNT(NIF) INTO xCuantos
--   FROM FINCAS WHERE NIF=xNIF;


-- Averiguar el total pendiente de todas las deudas del expediente
-- Indistintamente a que pertenezcan a municipios y/o Junta de Andalucia

   SELECT SUM(PRINCIPAL + RECARGO + COSTAS - ENTREGAS_A_CUENTA)
	INTO xPENDIENTE
   FROM VALORES
   WHERE EXPEDIENTE=xIDExpe
	AND F_ingreso is null
      and Fecha_de_baja is null
      and F_suspension is null
      AND ID_INMUEBLES IS NULL;

-- Averiguar el importe más pequeño que podemos pasar a un embargo de inmuebles

   SELECT MENOR_CUANTIA INTO xMENOR FROM CONFIGURACION 
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);
	
   if (xPendiente < xMENOR) then
	raise_application_error(-20008,'No se puede embargar un inmueble para un expediente con menos de '||xMENOR||' euros');
   end if;

   xJUNTA:='N';
   if (xPendiente > xMENOR) then

	FOR v_CLIENTES IN cCLIENTES
	LOOP

		-- PARA LOS AYUNTAMIENTOS UN EMBARGO POR CADA AYUNTAMIENTO AL QUE SE LE DEBA
		IF v_CLIENTES.TIPO_CLI='LOC' THEN
		   -- DEUDOR DE UN AYUNTAMIENTO
		   INMUEBLES_DIVIDIR_AYTO(xIDExpe, xZONA, v_CLIENTES.AYTO, xEXPE, xNIF);
		END IF;

		-- PARA DEUDAS DE LA JUNTA TODAS LAS DEUDAS A UN UNICO EMBARGO
		IF v_CLIENTES.TIPO_CLI='JUN' AND xJUNTA='N' THEN
		   -- DEUDOR DE LA JUNTA
			INMUEBLES_DIVIDIR_JUNTA(xIDExpe ,xZONA, xEXPE, xNIF);
		   xJUNTA:='S';
		END IF;

	END LOOP;

	SELECT LOTE_4 Into xNLote FROM EXPEDIENTES WHERE ID=xIDExpe;
	IF xNLote IS NULL THEN
	   xCadena:='Comienza proceso embargo de Inmuebles. No esta en ningun lote.';
	ELSE
	   xCadena:='Comienza proceso embargo de Inmuebles. Lote Número: '||xNLote;
	END IF;
	pkSeguimiento.NotaInformativa(xIDEXPE,xCadena);

    UPDATE EXPEDIENTES SET EMBARGO_4='O'
    WHERE ID=xIDexpe And Embargo_4='P';
          
   END IF;

END;
/

/*****************************************************************************************/
-- Los afectados son todos los expedientes en trámite de embargo de inmuebles y estado PENDIENTE.
-- Expedientes además no ingresados, anulados o suspensos.
-- Genera embargos de inmuebles para los distintos ayuntamientos y/o junta de los valores
-- de cada expediente, y pasa a los expedientes al estado de ABIERTO en ese trámite.
/*****************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PorZonasINMUEBLES(
		xZONA IN CHAR,
		xNLOTE IN CHAR)

AS

   CURSOR EXPE_CUR IS
        SELECT ID
        FROM EXPEDIENTES
        WHERE ZONA=xZONA
              AND EMBARGO_4='P'
              AND F_INGRESO IS NULL
              AND F_ANULACION IS NULL
              AND F_SUSPENSION IS NULL
		  AND LOTE_4=xNLOTE;
BEGIN

   FOR v_EXPE IN EXPE_CUR LOOP
      PUT_UnExpeEnLoteINMUEBLES(v_EXPE.ID);
   END LOOP;

END;
/


/*****************************************************************************************/
-- Pone un valor en un embargo de inmuebles con garantías afectadas.
-- Si ese valor es el último del expediente, se pasa al expediente del 
-- estado PENDIENTE a estado ABIERTO.
/*****************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE INMUEBLESAFECTOS(
	xIDEXPE	 IN	INTEGER,
    xIDVALOR IN	INTEGER,
    xHECHO 	 IN	VARCHAR2)

AS
xLAST 	    INTEGER;
xNIF 		CHAR(10);
xZONA 	    CHAR(2);
xAYTO 	    CHAR(3);
xEXPE 	    CHAR(10);
xCUANTOS 	INTEGER DEFAULT 0;
SPRINCIPAL 	FLOAT DEFAULT 0;
SRECARGO 	FLOAT DEFAULT 0;
SCOSTAS 	FLOAT DEFAULT 0;
SDEMORA 	FLOAT DEFAULT 0;
SPENDIENTE  FLOAT DEFAULT 0;

BEGIN

   SELECT DEUDOR,ZONA,EXPEDIENTE INTO xNIF,xZONA,xEXPE FROM EXPEDIENTES
   WHERE ID=xIDEXPE;

   -- EL CONTROL DE LA SITUACION DEL EMBARGO SE HARA DESDE DELPHI 

	-- COMPROBAR QUE NO SE HAGA DOS VECES EL MISMO 
	begin
		SELECT AYTO INTO xAYTO FROM VALORES
			WHERE ID=xIDVALOR AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND 
			F_SUSPENSION IS NULL AND ID_INMUEBLES IS NULL;
			-- F_SUSPENSION IS NULL AND EN_INMUEBLES='S' AND ID_INMUEBLES IS NOT NULL;
	Exception
		When no_data_found then
			raise_application_error(-20003,
                    'Este valor ya está en un embargo de inmuebles con garantías afectadas');
	end;

   pkIngresos.Get_Pendiente( xIDVALOR, SPRINCIPAL, SRECARGO, SCOSTAS, SDEMORA, SPENDIENTE);

   IF sPENDIENTE > 0 THEN
		xCUANTOS:=1;         

		INSERT INTO EMBARGOS_INMUEBLES
           	(IDEXPE,DEUDA_TOTAL,NIF,ZONA,AYTO,EXPEDIENTE,N_RECIBOS, F_ACUMULACION, 
			F_ANTERIOR_ACU,PRINCIPAL, RECARGO, AFECTADO, HECHO_IMPONIBLE)
		VALUES
      	     (xIDEXPE, ROUND(sPrincipal+sRecargo,2), xNIF, xZONA, xAYTO, xEXPE,xCUANTOS,SYSDATE,
			SYSDATE,ROUND(SPRINCIPAL,2), ROUND(SRECARGO,2), 'S', xHECHO)
		return ID into xLast;

		UPDATE VALORES SET ID_INMUEBLES=xLAST
			WHERE ID=xIDVALOR AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND 
			F_SUSPENSION IS NULL AND ID_INMUEBLES IS NULL;

		--si no hay mas recibos en el expediente actualizamos el estado para que no salga
		--en el grid de pendiente de embargos de inmuebles
		SELECT COUNT(*) INTO xCUANTOS FROM VALORES
			WHERE F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL
					AND ID_INMUEBLES IS NULL AND EXPEDIENTE=xIDExpe;

		IF xCUANTOS = 0 THEN
			UPDATE EXPEDIENTES SET EMBARGO_4='O'
			WHERE ID=xIDEXPE AND EMBARGO_4='P';
		END IF;
   END IF;
END;
/

/******************************************************************************/
-- Añade una finca a un contribuyente (Tabla FINCAS), indicando los datos de 
-- la finca y el nif del contribuyente.
/******************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE AddFincaContri(
         xID            IN INTEGER,
         xNIF           IN CHAR,
         xTOMO          IN CHAR,
         xFINCA         IN CHAR,
         xLIBRO         IN CHAR,
         xFOLIO         IN CHAR,
         xINSCRIPCION   IN CHAR,
         xINSCRITA      IN CHAR,
         xF_INSCRIPCION IN DATE,
         xF_MARGINAL    IN DATE,
         xNOTARIO       IN VARCHAR,
         xPROTOCOLO     IN CHAR,
         xF_ESCRITURAS  IN DATE,
         xDESCRIPCION   IN VARCHAR,
	   xIDRegistro	IN INTEGER)
AS
mF_MARGINAL		date default null;
mNOTARIO		varchar(150) default null;
mPROTOCOLO		char(10) default null;
mF_ESCRITURAS	date default null;
mF_INSCRIPCION	date default null;
mIDRegistro		integer default null;

BEGIN


	IF (xINSCRITA='N') THEN
		mF_MARGINAL:=xF_MARGINAL;
		mNOTARIO:=xNOTARIO;
		mPROTOCOLO:=xPROTOCOLO;
		mF_ESCRITURAS:=xF_ESCRITURAS;
	ELSE
		mF_INSCRIPCION:=xF_INSCRIPCION;
		mIDRegistro:=xIDRegistro;
	END IF;


	UPDATE FINCAS SET NIF=xNIF, DESCRIPCION=xDESCRIPCION,
                TOMO=xTOMO, FINCA=xFINCA, LIBRO=xLIBRO, FOLIO=xFOLIO,
                INSCRIPCION=xINSCRIPCION, 
                F_INSCRIPCION=mF_INSCRIPCION, 
		    F_MARGINAL=mF_MARGINAL, NOTARIO=mNOTARIO, 
		    PROTOCOLO=mPROTOCOLO, F_ESCRITURAS=mF_ESCRITURAS,
		    ID_REGISTRO_PRO=mIDRegistro
	WHERE ID=xID;

	-- SI LA FINCA no existe, se crea 
	IF SQL%NOTFOUND THEN 

   		INSERT INTO FINCAS (NIF, DESCRIPCION,
			TOMO,   FINCA, LIBRO, FOLIO, INSCRIPCION,
			F_INSCRIPCION,
			F_MARGINAL, NOTARIO, PROTOCOLO, F_ESCRITURAS,ID_REGISTRO_PRO)
		VALUES
			(xNIF, xDESCRIPCION,
			xTOMO, xFINCA, xLIBRO, xFOLIO, xINSCRIPCION,
			mF_INSCRIPCION,
			mF_MARGINAL, mNOTARIO,
			mPROTOCOLO, mF_ESCRITURAS,mIDRegistro);
	END IF;

END;
/

/*******************************************************************************************/
-- Deja un Expediente sin trámites. Este expediente debe estar en estado PENDIENTE.
-- Lo anota en el seguimiento.
/*******************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE QUITA_INMU_NADA (xIDExpe IN INTEGER)
AS
BEGIN

   -- Anotarlo en el seguimiento
   PkSeguimiento.NotaInformativa(xIDExpe,'Se quita el expediente del pendiente de Inmuebles');

   -- Dejar el expediente sin trámite de inmuebles
   UPDATE EXPEDIENTES SET EMBARGO_4='0' WHERE ID=xIDExpe;

END;
/

/*****************************************************************************************/
-- Elimina un embargo de inmuebles, dejando el expediente sin tramites.
-- Es similar al procedimiento LEVANTA_INMUEBLES, con la diferencia de que no comprueba 
-- si se había emitido el mandamiento. Borra el embargo sin comprobaciones.
-- ¿Por que puede ocurrir esto? Porque se paga el embargo, cuando el mandamiento
-- se había emitido ya. Una vez que se responde al mandamiento, ya se puede eliminar
-- el embargo, y es cuando se llama a este procedimiento.
/*****************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE BORRA_LEVANTA_INMU
			(xIDEMBINMU IN INTEGER,
			 xIDExpe IN INTEGER)
AS
xCuantos INTEGER;
xEsta_Embargo CHAR(1);

BEGIN                                                                                                      

   DELETE FROM FINCAS_EMBARGADAS WHERE IDEMBINMU=xIDEMBINMU; 

   UPDATE VALORES SET ID_INMUEBLES=NULL 
   WHERE ID_INMUEBLES=xIDEMBINMU AND EXPEDIENTE=xIDExpe;

   DELETE FROM EMBARGOS_INMUEBLES WHERE ID=xIDEMBINMU; 

   SELECT COUNT(*) INTO xCUANTOS FROM EMBARGOS_INMUEBLES where IDExpe=xIDExpe;

   IF (xCUANTOS = 0) THEN -- Era el último embargo de Inmuebles de ese Expediente.
                       
	  -- Si está en LEVANTADO de embargo de Inmuebles, se pasa al pendiente de inmuebles.
	  -- Si No está en el levantado de embargo de Inmuebles, se deja en el estado que esté.

 	  SELECT EMBARGO_4 INTO xEsta_Embargo FROM EXPEDIENTES WHERE ID=xIDExpe;
	  IF xEsta_Embargo='L' THEN                                     
	    PKSeguimiento.NotaInformativa(xIDEXPE,'El expediente no tiene trámite de inmuebles');	
	   	UPDATE EXPEDIENTES SET EMBARGO_4='0' WHERE ID=xIdExpe;
   	  END IF;
   ELSE
     	PKSeguimiento.NotaInformativa(xIDEXPE,'Se elimina un embargo de inmuebles. Hay más embargos de inmuebles');
   END IF;

END;                                             
/

/*****************************************************************************************/
-- Elimina el embargo de inmuebles de un valor (o varios) de un expediente, 
-- dejando al expediente en el trámite de embargo de inmuebles, y pasandolo al estado 
-- PENDIENTE si el que se elimina es el último embargo sobre ese expediente.
/*****************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE Quito_ExpeLoteInmuebles(
         xIDExpe    IN INTEGER,
         xIDEMBINMU IN INTEGER)

AS

   xCUANTOS INTEGER DEFAULT 0;
   xEMBARGO CHAR(1);
   xEsta_Embargo CHAR(1);
BEGIN

	UPDATE VALORES SET ID_INMUEBLES=NULL
	WHERE ID_INMUEBLES=xIDEMBINMU AND EXPEDIENTE=xIDExpe;

	--en el trigger  se controla si tambien estaba en cuentas
	delete from EMBARGOS_Inmuebles where ID=xIDEMBINMU;

	-- Las notificaciones no las elimino, solamente anulo su apunte al embargo.
	UPDATE NOTIFICACIONES SET ID_EMBARGOS=NULL 
	WHERE EXPEDIENTE=xIDEXPE 
		AND ID_EMBARGOS=xIDEMBINMU 
		AND TIPO_NOTI LIKE '4%';

	DELETE FROM FINCAS_EMBARGADAS WHERE IDEMBINMU=xIDEMBINMU;

	SELECT COUNT(*) INTO xCUANTOS FROM EMBARGOS_Inmuebles where IDExpe=xIDExpe;

	IF (xCUANTOS = 0) THEN -- Era el último embargo de Inmuebles de ese Expediente.

	   -- El expediente puede estar en inmuebles o en CUENTAS CORRIENTES. 
	   -- Si está en el abierto de embargo de Inmuebles, se pasa al pendiente de inmuebles.
	   -- Si No está en el abierto de embargo de Inmuebles, se deja en el estado que esté.
   	   -- Si está en embargo de Cuentas Corrientes,sigue alli,y se indica en_otrotramite='N'

	   SELECT EMBARGO_4 INTO xEsta_Embargo 
		FROM EXPEDIENTES WHERE ID=xIDExpe;

	   if xEsta_Embargo='O' then                                     
		 PKSeguimiento.NotaInformativa(xIDEXPE,'Pasa a estado Pendiente de Inmuebles');	
		 UPDATE EXPEDIENTES SET EMBARGO_4='P' WHERE ID=xIDExpe;
	   end if;

	ELSE
	   PKSeguimiento.NotaInformativa(xIDEXPE,'Se elimina un embargo de inmuebles. Hay más embargos de inmuebles');
	END IF;


END;
/

/*****************************************************************************************/
-- ----------   INMUEBLES PENDIENTES -> MUEBLES PENDIENTES   -----------------------------
/*****************************************************************************************/
-- Pasa expedientes con embargo de INMUEBLES en estado PENDIENTE al embargo
-- de MUEBLES en estado PENDIENTE. ¿Cuantos expedientes? Depende del valor de xIDEXPE:
-- xIDEXPE  = -1  -> Todos los expedientes de una zona (xZONA)
-- xIDEXPE <> -1 -> Un solo expediente (xIDEXPE).
-- Anota el tramite negativo para el/los expedientes que trata.
/***************************************************************************************/
/*DELPHI E INTERNO*/
CREATE OR REPLACE PROCEDURE BORRAR_SIN_INMUEBLES(
		xIDEXPE IN INTEGER, 
		xZONA   IN CHAR,
		xNLOTE  IN CHAR)

AS
xCadena CHAR(150);

   CURSOR CC_LOTE IS
	    SELECT ID FROM EXPEDIENTES
          WHERE LOTE_4=xNLOTE AND ZONA=xZONA AND EMBARGO_4='P';
BEGIN

   IF xNLote is NULL THEN
	xCadena:='No se encontraron bienes inmuebles. No tiene lote.';
   ELSE
	xCadena:='No se encontraron bienes inmuebles. Número de Lote: '||xNLOTE;
   END IF;

   IF xIDEXPE=-1 THEN 

	-- Se pasan todos los expedientes pendientes de Inmuebles al trámite de Vehiculos
	FOR v_LOTE IN CC_LOTE LOOP

	   PkSeguimiento.AnotaTramiteNegativo(v_LOTE.ID,xCadena,'4',sysdate);

         UPDATE EXPEDIENTES SET EMBARGO_4='0', 
                      EMBARGO_8=DECODE(EMBARGO_8,'0','P',EMBARGO_8),
					  F_EMBARGO_VEHICULOS=DECODE(EMBARGO_8,'0',SYSDATE,F_EMBARGO_VEHICULOS)
         WHERE ID=v_LOTE.ID;

	END LOOP;

   ELSE -- Se pasa un sólo expediente al trámite de Vehiculos

	PkSeguimiento.AnotaTramiteNegativo(xIDEXPE,xCadena,'4',sysdate);

      UPDATE EXPEDIENTES SET EMBARGO_4='0', 
              EMBARGO_8=DECODE(EMBARGO_8,'0','P',EMBARGO_8),
			  F_EMBARGO_VEHICULOS=DECODE(EMBARGO_8,'0',SYSDATE,F_EMBARGO_VEHICULOS)
      WHERE ID=xIDEXPE
            AND EMBARGO_4='P';

   END IF;

END;
/

/*****************************************************************************************/
-- Pasa un expediente a pendiente de cuentas corrientes e indicamos que está en otro
-- trámite
/*****************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE INMUBLES_A_CUENTAS(xIDEXPE IN INTEGER)
AS
BEGIN
-- Lo pasamos a pendiente de cuentas corrientes y le indicamos que está en otro
-- trámite

   	UPDATE EXPEDIENTES SET EMBARGO_1='P'
    WHERE ID=xIDEXPE;

	pkSeguimiento.NotaInformativa(xIDEXPE,'Pasa a pendiente de CC estando en inmuebles');

END;
/

/*****************************************************************************************/
-- Elimina una finca.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE BORRAR_FINCA(xID IN INTEGER, xERROR OUT INTEGER)

AS
  xCONT	INTEGER;

BEGIN

  SELECT COUNT(*) INTO xCONT FROM FINCAS_EMBARGADAS
  WHERE FINCA=xID;

  IF xCONT>0 THEN
    xERROR:=1;
    RETURN;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM FINCAS_TERCEROS
  WHERE FINCA=xID;

  IF xCONT>0 THEN
    xERROR:=2;
    RETURN;
  END IF;

  xERROR:=0;
  Delete from fincas where ID=xID;

END;
/



/*****************************************************************************************
Acción: Realiza la diligencia del embargo de inmuebles de un expediente 
	  en un embargo concreto de inmuebles.

Parámetros: xIDInmu: ID del embargo de Inmuebles;
		xIDEXPE: ID del Expediente;
		xFECHA:  Fecha de Diligencia;

MODIFICACIÓN: 20/02/2002 M. Carmen Junco Gómez. Se pasa también el parámetro xIDINMU; en
		  caso contrario daría la misma fecha de diligencia a dos o mas posibles 
		  embargos de inmuebles sobre el mismo expediente.
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE DILIGENCIA_INMUEBLES(
	xIDINMU	IN	INTEGER,
	xIDEXPE 	IN 	INTEGER, 
	xFECHA  	IN 	DATE)

AS

BEGIN

  UPDATE EMBARGOS_INMUEBLES SET F_DILIGENCIA=xFECHA WHERE ID=xIDINMU ;

  UPDATE EXPEDIENTES SET FECHA_DILI_INMUEBLES=xFECHA WHERE ID=xIDExpe;

  pkSeguimiento.NotaInformativa(xIDExpe,'Diligencia embargo inmuebles con fecha: ' || xFECHA);

END;
/

/*****************************************************************************************/
-- Indica en un embargo de inmuebles que se ha realizado la emision de notificación de 
-- embargo y crea una Notificacion de embargo de un embargo de inmuebles correspondiente 
-- a un expediente determinado.
-- La notificación se genera para el deudor y para los terceros afectados.
-- Modificado: 15/11/2004. Lucas Fernández Pérez. Los terceros a los que se notifica deben
--	tener fincas embargadas asociadas, de tal modo que solo los terceros que tengan finca 
--  asociada y embargada serán notificados. Antes notificaba a todos los terceros sin mirar
--  si la finca estaba embargada, por lo que salían notificaciones a fincas no embargadas.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE NOTI_EMBARGO_INMUEBLES(
      xIDExpe IN INTEGER,
      xIDInmu IN INTEGER)
AS
xEmi     char(1);
xNIF     char(10);
xCuantos integer default 0;

	--solamente se generan notificaciones para los terceros que tengan todos los tramites
	--o especificamente el de inmuebles, y tengan asignada alguna finca de las embargadas
	CURSOR cTerceros IS select NIF,ID
                from TERCEROS
                where Expediente=xIDExpe and TRAMITE in ('T','4')
					  AND ( (FINCAS_TODAS='S') 
					  		OR
					  		(ID IN (SELECT T.TERCERO FROM FINCAS_TERCEROS T, FINCAS_EMBARGADAS E 
								WHERE T.FINCA=E.FINCA AND E.IDEXPE=xIDExpe AND E.IDEMBINMU=xIDInmu))
					  );
						

BEGIN

	--Puede ocurrir que despues de haber emitido las notificaciones conozcamos mas terceros
	--entonces hay que generar las notificaciones cada vez
	SELECT EMITIDA_NOTI,NIF into xEmi,xNIF
	FROM EMBARGOS_INMUEBLES
	WHERE ID=xIDInmu;

	-- Si ya se han realizado las notificaciones se anulan del embargo todas aquellas 
	-- de terceros que ya no pertenezcan al expediente.
	-- La forma de anular la notificacion del embargo consiste en anular el id de embargos.
	IF (xEmi='S') then

	  UPDATE NOTIFICACIONES SET ID_EMBARGOS=NULL 
		WHERE EXPEDIENTE=xIDExpe AND ID_EMBARGOS=xIDInmu AND TIPO_NOTI='402'
		AND NIF NOT IN 
		(SELECT NIF FROM TERCEROS WHERE EXPEDIENTE=xIDExpe AND TRAMITE IN ('T','4')
			AND ( 
				  (FINCAS_TODAS='S') 
				  OR
				  (ID IN (SELECT T.TERCERO FROM FINCAS_TERCEROS T, FINCAS_EMBARGADAS E 
				  WHERE T.FINCA=E.FINCA AND E.IDEXPE=xIDExpe AND E.IDEMBINMU=xIDInmu))
				)
		);

	else
		UPDATE EMBARGOS_INMUEBLES SET EMITIDA_NOTI='S' WHERE ID=xIDInmu;
	end if;


	--si hay una notificacion generada PARA EL DEUDOR no se tiene que insertar otra
	select count(*) into xCuantos from notificaciones 
		where ID_Embargos=xIDInmu and Expediente=xIDExpe
		and tipo_noti='401' and NIF=xNIF;

	if xCuantos=0 then
		--notificar al deudor
		--notificacion embargo bienes inmuebles
		Add_Notificaciones_expe(xIDExpe,'401',xIDInmu, xNIF,'QQ');
	end if;


	-- insertar tantas como terceros nuevos del expediente (notificaciones_expe)
	FOR v_TERC IN CTERCEROS LOOP
		--si hay una notificacion generada PARA LOS TERCEROS no se tiene que insertar otra
		select count(*) into xCuantos from notificaciones 
		where ID_Embargos=xIDInmu and Expediente=xIDExpe
		and tipo_noti='402' and NIF=v_TERC.NIF;

		if xCuantos=0 then
			-- Para no tener que modificar los parametros de la rutina
			-- Add_Notificaciones_Expe se lo pasamos a la tabla de usuarios
			UPDATE USUARIOS SET LAST_TAREA=v_TERC.ID WHERE USUARIO=USER;

			--notificacion embargo bienes inmuebles terceros
			Add_Notificaciones_expe(xIDExpe,'402', xIDInmu, v_TERC.NIF, 'TE');
		end if;
	END LOOP;

END;
/
/*****************************************************************************************/
-- Indica en un embargo de inmuebles que se ha realizado la valoración y genera una 
-- Notificación de Valoración Municipal de un embargo de inmuebles 
-- correspondiente a un expediente determinado. La notificación va dirigida al deudor.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE NOTI_VALORACION_INMUEBLES(
        xIDExpe IN INTEGER,
        xIDInmu IN INTEGER)

AS
xEmi char(1);
xNIF char(10);

BEGIN

   SELECT VALORACION,NIF into xEmi,xNIF from EMBARGOS_INMUEBLES WHERE ID=xIDInmu;

   IF (xEmi='N') THEN -- Solo se notifica una vez

      --activar el detector para no poder hacerlo de nuevo
      update EMBARGOS_INMUEBLES set VALORACION='S'
      WHERE ID=xIDInmu;

      --notificar al deudor
      --notificacion VALORACION
      Add_Notificaciones_expe(xIDExpe,'403', xIDInmu, xNIF,'QQ');

   END IF;

END;
/



/********************************************************************************************/
-- Indica en un embargo de inmuebles que se ha realizado la emision de notificación de 
-- subasta y crea una Notificacion de Subasta de un embargo de inmuebles correspondiente 
-- a un expediente determinado.
-- La notificación se genera para el deudor y para los terceros afectados.
-- Modificado: 3/3/03. Lucas Fernández Pérez. No ponía en Usuarios el ID del tercero, por lo que
-- fallaba el procedimiento.
-- Modificado: 15/11/2004. Lucas Fernández Pérez. Los terceros a los que se notifica deben
--	tener fincas embargadas asociadas, de tal modo que solo los terceros que tengan finca 
--  asociada y embargada serán notificados. Antes notificaba a todos los terceros sin mirar
--  si la finca estaba embargada, por lo que salían notificaciones a fincas no embargadas.
/********************************************************************************************/

CREATE OR REPLACE PROCEDURE NOTI_SUBASTA_INMUEBLES(
      xIDExpe IN INTEGER,
      xIDInmu IN INTEGER)

AS
	xEmi char(1);
	xNIF char(10);

   	--solamente se generan notificaciones para los terceros que tengan todos los tramites
	--o especificamente el de inmuebles
	CURSOR C1 IS select NIF,ID
         from TERCEROS
         where Expediente=xIDExpe and TRAMITE in ('T','4')
		 	   AND ( 
				  (FINCAS_TODAS='S') 
				  OR
				  (ID IN (SELECT T.TERCERO FROM FINCAS_TERCEROS T, FINCAS_EMBARGADAS E 
				  WHERE T.FINCA=E.FINCA AND E.IDEXPE=xIDExpe AND E.IDEMBINMU=xIDInmu))
				);
BEGIN

   SELECT EMI_NOTI_SUBA,NIF into xEmi,xNIF
   FROM EMBARGOS_INMUEBLES
   WHERE ID=xIDInmu;


   IF (xEmi='N') THEN -- Solo se notifica una vez

      --activar el detecto para no poder hacerlo de nuevo
      UPDATE EMBARGOS_INMUEBLES SET EMI_NOTI_SUBA='S'
      WHERE ID=xIDInmu;

      --notificar al deudor
      --notificacion embargo bienes inmuebles
      Add_Notificaciones_expe(xIDExpe,'407',xIDInmu, xNIF,'QQ');

      --insertar tantas como terceros del expediente notificaciones_expe 

      FOR v_C1 IN C1 LOOP
        -- PARA NO TENER QUE MODIFICAR LOS PARAMETROS DE LA RUTINA
        --   Add_Notificaciones_Expe SE LO PASAMOS A LA TABLA DE USUARIOS 
        UPDATE USUARIOS SET LAST_TAREA=v_C1.ID WHERE USUARIO=USER;

         --notificacion embargo b.i. terceros
         Add_Notificaciones_expe(xIDExpe,'408', xIDInmu, v_C1.NIF, 'TE');
      END LOOP;

   END IF;

END;
/

/*****************************************************************************************/
-- Anota una fecha en el embargo de inmuebles, dependiendo del parametro de entrada Quien.
-- Quien=1 -> anota la fecha de mandamiento al registro del embargo.
-- Quien=2 -> anota la fecha de autorización de subasta del embargo.
-- Quien=3 -> anota la fecha de subasta del embargo.
-- Modificado: 26/09/2003. Lucas Fernández Pérez.
-- Se añade la posibilidad de poner fecha de autorización de subasta y de subasta a NULL
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE Pon_Fechas_Inmu(
         xIDTramite 	IN integer,
         Quien   		IN integer,
         xFecha  		IN Date)
AS
xFechaSubasta DATE;
begin

   -- En los casos 2 y 3 (autorización de subasta y subasta) puede ponerse la fecha a null
   IF TRUNC(xFecha,'dd')='01/01/1901' THEN
	 xFechaSubasta:=NULL;
   ELSE
 	 xFechaSubasta:=xFecha;
   END IF;

   --Fecha anotacion preventiva
   IF (Quien=1) THEN
      UPDATE embargos_inmuebles SET MANDAMIENTO_REGIS='S', F_MANDAMIENTO=xFecha
      	where ID=xIDTramite and F_MANDAMIENTO is null;
   END IF;

   IF (Quien=2) THEN
      UPDATE embargos_inmuebles SET F_AUTORIZACION=xFechaSubasta where ID=xIDTramite;
   END IF;
      
   IF (Quien=3) THEN
      UPDATE embargos_inmuebles SET F_SUBASTA=xFechaSubasta  where ID=xIDTramite;
   END IF;

END;
/

/*****************************************************************************************/
--Grabar la fecha de anotacion del mandamiento de un Expediente
--a las fincas que pertenezcan al mismo registro de la propiedad
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE PutFechasMandamiento(
		xIDExpe 	IN integer,
		xIDEmbargo	IN integer,
		xIDFinca	IN integer,
		xFecha  	IN Date)
AS
BEGIN

	update fincas_embargadas set fecha_embargo=xFecha
		where IdExpe=xIDExpe and IdEmbInmu=xIDEmbargo
			and finca=xIDFinca;
END;
/


/*****************************************************************************************/
--xValoracion = 'S' -> Graba la fecha de valoracion y el importe de una finca embargada.
--xValoracion <> 'S'-> Graba la fecha de valoracion contradictoria y el importe de 
--				una finca embargada en un expediente.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE PutDatosValoracion(
		xValoracion	IN char,
		xIDExpe 	IN integer,
		xIDEmbargo	IN integer,
		xIDFinca	IN integer,
		xFecha  	IN Date,
		xImpo   	IN float)
AS
BEGIN

	if xValoracion='S' then	 --fecha e importe de la valoracion municipal
	  update fincas_embargadas set F_VALORACION=xFecha,IMPORTE_VALO=ROUND(xImpo,2)
	  where finca=xIDFinca and IdExpe=xIDExpe and IdEmbInmu=xIDEmbargo;	

	else --fecha e importe de la valoracion contradictoria
	  update fincas_embargadas set VALO_CONTRADICTORIA=xFecha,IMPORTE_VALO_CON=ROUND(xImpo,2)
	  where finca=xIDFinca and IdExpe=xIDExpe and IdEmbInmu=xIDEmbargo;
	end if;

END;
/

/*****************************************************************************************/
-- Genera y registra la certificación de cargas de un embargo de inmuebles. 
-- Esta certificación solo se crea una vez.
-- Modificado: 15/11/2004. Lucas Fernández Pérez. Los terceros a los que se notifica deben
--	tener fincas embargadas asociadas, de tal modo que solo los terceros que tengan finca 
--  asociada y embargada serán notificados. Antes notificaba a todos los terceros sin mirar
--  si la finca estaba embargada, por lo que salían notificaciones a fincas no embargadas.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE CERTIFICA_CARGAS_DEUDORES(
         xIDEXPE    IN INTEGER,
         xIDEMBARGO IN INTEGER,
	     xFecha	  IN DATE)

AS
   xCUANTOS INTEGER;
   mFecha date;

   CURSOR EXPE_CUR IS
        SELECT NIF,ID FROM TERCEROS
        WHERE EXPEDIENTE=xIDEXPE and TRAMITE in ('T','4')
              AND RELACION IN ('03','04')
		 	  AND ( 
				  (FINCAS_TODAS='S') 
				  OR
				  (ID IN (SELECT T.TERCERO FROM FINCAS_TERCEROS T, FINCAS_EMBARGADAS E 
				  WHERE T.FINCA=E.FINCA AND E.IDEXPE=xIDExpe AND E.IDEMBINMU=xIDEmbargo))
				);


BEGIN

   --A ESTAS PERSONAS TENEMOS QUE SOLICITARLE EL ESTADO ACTUAL DE CARGAS
   --RELACION 03 SON ACREEDORES HIPOTECARIOS 04 DEUDORES POR EMBARGO

   --LE ENVIAMOS EL NIF DE TERCERO PUES PUEDE HABER MAS DE UN ACREEDOR

   FOR v_EXPE IN EXPE_CUR LOOP
  
      xCUANTOS:=0;

      --COMPROBAR QUE NO SE HAYA EMITIDO AUN LA CERTIFICACION DE CARGAS
      SELECT COUNT(*) INTO xCUANTOS 
      FROM NOTIFICACIONES
      WHERE EXPEDIENTE=xIDEXPE
            AND ID_EMBARGOS=xIDEmbargo
		AND NIF=v_EXPE.NIF
		AND TIPO_NOTI='405';

      IF (xCUANTOS = 0) THEN

        -- PARA NO TENER QUE MODIFICAR LOS PARAMETROS DE LA RUTINA
        --   Add_Notificaciones_Expe SE LO PASAMOS A LA TABLA DE USUARIOS 
        UPDATE USUARIOS SET LAST_TAREA=v_EXPE.ID WHERE USUARIO=USER;

        Add_Notificaciones_Expe (xIDExpe, '405', xIDEMBARGO, v_EXPE.NIF, 'TE');
      END IF;

   END LOOP;


   select CERTIFICACION_CARGAS into mFecha from embargos_inmuebles where id=xIDEMBARGO;
   if mFecha is null then
		UPDATE embargos_inmuebles SET CERTIFICACION_CARGAS=xFecha
		where ID=xIDEMBARGO;
		PkSeguimiento.NotaInformativa(xIDExpe,'Emitida notificación de situación actual de cargas. Fecha: '||TO_CHAR(xFecha,'DD-MM-YYYY'));
   end if;


END;
/

/*****************************************************************************************/
-- Genera y registra la notificación de Requerimiento de títulos de un embargo de inmuebles. 
-- Esta notificación solo se crea una vez.
/*****************************************************************************************/
CREATE OR REPLACE PROCEDURE Requerimiento_DE_Titulos(
         xIDEXPE    IN INTEGER,
         xIDEMBARGO IN INTEGER,
         xFecha     IN DATE)
AS
   xNIF  char(10);
   xDate DATE;
BEGIN

	select REQUERIMIENTO_TITULOS,NIF into xDate,xNIF
	From embargos_INMUEBLES where ID=xIDEMBARGO;

	if (xDate is null) then
		Add_Notificaciones_Expe (xIDExpe, '404', xIDEMBARGO, xNIF, 'QQ');
		update embargos_INMUEBLES set REQUERIMIENTO_TITULOS=xFecha
		where ID=xIDEMBARGO;
	end IF;

END;
/

--
-- Añadir una petición de nota simple a un embargo de bienes inmuebles.
-- Pedido por Paco Bustos
-- 21/01/2002 Antonio Pérez Caballero
--
CREATE OR REPLACE PROCEDURE NotaSimplePedir(
		xIDexpe IN INTEGER, 
		xIDRegistro IN INTEGER,
		xNIF	IN CHAR)
AS
xNUMERO INTEGER;
xNOMBRE CHAR(50);
xImporte FLOAT;
xIDCostas integer;
BEGIN

  -- Si se ha pedido hoy nos salimos, para evitar que el usuario pulse dos veces el botón en el interfaz
  SELECT COUNT(*) INTO xNUMERO FROM NOTAS_SIMPLES 
	WHERE IDEXPE=xIDexpe
	AND IDREGISTRO=xIDRegistro
	AND TO_CHAR(FECHA_PETICION,'DDD')=TO_CHAR(SYSDATE,'DDD');

  IF xNUMERO > 0 THEN
    RETURN;
  END IF;

  -- Si no existe el registro nos salimos
  BEGIN
    select NUMERO,NOMBRE INTO xNUMERO,xNOMBRE FROM REGISTROS_PROPIEDAD 
    WHERE ID=xIDRegistro;
  EXCEPTION WHEN no_data_found THEN
	RETURN;
  END;

  SELECT IMPORTE_NOTA_SIMPLE INTO xImporte
	FROM CONFIGURACION
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

  -- En notas simples
  INSERT INTO NOTAS_SIMPLES(IDEXPE,IDREGISTRO,USUARIO,NIF)
  VALUES (xIDexpe, xIDRegistro, USER, xNIF );

  ADD_COSTA_EXPE(xIDexpe, xImporte, 
	'Costas, petición de nota simple registro '||xNUMERO||' de '||xNOMBRE
	, xIDCostas);


END;
/

--
-- Llega una petición de nota simple a un embargo de bienes inmuebles.
-- Pedido por Paco Bustos
-- 28/01/2002 Antonio Pérez Caballero
--
CREATE OR REPLACE PROCEDURE NotaSimpleLlegar(
	xIDRegistro IN INTEGER,
	xIDExpe IN INTEGER,
	xHayDatos IN Char)
AS
  xEmbargo CHAR(1);
  xDeudor	CHAR(10);
  xEsta_embargo CHAR(1);
  xNUMERO INTEGER;
  xNOMBRE CHAR(50);
  xCuantos INTEGER;

BEGIN

   -- Anotar la llegada de la nota
   UPDATE NOTAS_SIMPLES SET RECIBIDA='S',FECHA_RECEPCION=SYSDATE
	WHERE IDEXPE=xIDexpe
	AND IDREGISTRO=xIDRegistro;

   -- Sólo si está en estado PENDIENTE DE INMUEBLES (4 P) trato la información.
   begin
   	SELECT EMBARGO_4, DEUDOR INTO xEsta_embargo, xDeudor
	 FROM EXPEDIENTES WHERE ID=xIDExpe;
	exception
	   when no_data_found then -- No existe ya el expediente.Nos salimos.
		return;
   end;

   select NUMERO,NOMBRE INTO xNUMERO,xNOMBRE FROM REGISTROS_PROPIEDAD
	WHERE ID=xIDRegistro;

   -- Si llega aquí es porque tiene expediente.
   IF xHayDatos='N' THEN
      PKSeguimiento.NotaInformativa(xIDEXPE,
		'Recibida información negativa del registro '||xNUMERO||' de '||xNOMBRE);	
   ELSE
      PKSeguimiento.NotaInformativa(xIDEXPE,
		'Recibida información positiva del registro '||xNUMERO||' de '||xNOMBRE);
   END IF;


   -- Y además debe ser la última nota simple de las pedidas para poder tratar la información
   select count(*) into xCuantos from notas_simples where idexpe=xIDExpe and RECIBIDA='N';
   IF xCuantos>0 THEN
      RETURN;
   END IF;

   IF xEsta_Embargo<>'P' THEN
   	RETURN;
   END IF;

   -- Aqui el expediente esta en estado PENDIENTE DE INMUEBLES
   -- Aqui se han recibido todas las notas simples. Si todas son negativas, se pasa al 
   -- Pendiente de Vehiculos. Si hay alguna positiva, se pasa al abierto de Inmuebles.
   -- Es decir, si el expediente tiene fincas, pasa al abierto, y si no tiene, a vehiculos

   SELECT count(*) into xCuantos FROM FINCAS WHERE NIF=xDeudor;

   IF xCuantos=0 THEN

      -- En caso de que no haya fincas, lo pasa al pendiente de vehículos
      BORRAR_SIN_INMUEBLES(xIDExpe,'XX',null); -- Solo es relevante el número de expediente

   ELSE

      -- Si hay fincas los pasamos al trámite de inmuebles
      PUT_UnExpeEnLoteInmuebles(xIDExpe);

   END IF;

END;
/

/***************************************************************************************/
CREATE OR REPLACE PROCEDURE DILIGENCIAS_MASIVAS_INMU(	
				     xZONA   IN CHAR,
				     xFECHA  IN DATE,
				     xLOTE 	 IN CHAR)

AS
   CURSOR CDILI IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E,FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=F.IDEXPE AND E.IDEXPE=P.ID AND
				E.F_DILIGENCIA IS NULL AND 
				E.ZONA=xZONA AND P.LOTE_4=xLOTE;

BEGIN

   	FOR v_INMU IN CDILI
   	LOOP
         DILIGENCIA_INMUEBLES(v_INMU.ID,v_INMU.IDEXPE,xFECHA);
   	END LOOP;   

END;
/
/***************************************************************************************/
-- Genera un documentos de embargo de inmuebles masivos de TODOS
-- los expedientes de una ZONA y un LOTE. Estas notificaciones pueden ser:
-- 1. Al deudor y terceros en concepto de notificación de embargo.  (xQUIEN='D') 
-- 2. Internas, en concepto de documento de mandamiento al registrador. (xQUIEN='M')
-- 3. Al deudor, en concepto de notificacion de la valoracion municipal.(xQUIEN='V')
-- 4. Al propio deudor como notificacion de subasta. (xQUIEN='S') 
-- Solo permite crear una notificación de cada tipo.
/***************************************************************************************/
/*DELPHI*/
CREATE OR REPLACE PROCEDURE NOTIFICA_INMUEBLES_MASIVOS(	
     xZONA   IN CHAR,
     xQUIEN  IN CHAR,
     xFECHA  IN DATE,
     xLOTE 	 IN CHAR)

AS

   xCuantos INTEGER;
   -- En los cursores siempre comprueba que el embargo tenga fincas embargadas.

   CURSOR CINMUEBLES IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=F.IDEMBINMU AND
					E.F_DILIGENCIA IS NOT NULL AND
					E.EMITIDA_NOTI='N' AND 
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   CURSOR CMANDAMIENTO IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=F.IDEMBINMU AND
					E.NOTI_EMBARGO='S' AND
					E.F_MANDAMIENTO IS NULL AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   CURSOR CVALORACION IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=F.IDEMBINMU AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.VALORACION='N' AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE AND 
					E.ID NOT IN 
					(SELECT IDEMBINMU FROM VWFINCASEMBARGADAS 
			         	   WHERE IDEMBINMU=E.ID AND FECHA_EMBARGO IS NULL);
			-- mientras que no esten grabadas todas las fechas del mandamiento en cada
		   	-- una de las fincas no se puede imprimir la valoracion municipal.


   CURSOR CSUBASTA IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=F.IDEMBINMU AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.VALORACION='S' AND
					E.F_SUBASTA IS NOT NULL AND
   					EMI_NOTI_SUBA='N' AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   CURSOR CREQUETITULOS IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=F.IDEMBINMU AND
					E.F_DILIGENCIA IS NOT NULL AND
					E.REQUERIMIENTO_TITULOS IS NULL AND 
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   CURSOR CCARGAS IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=F.IDEMBINMU AND
					E.F_DILIGENCIA IS NOT NULL AND
					E.CERTIFICACION_CARGAS IS NULL AND 
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

BEGIN


   -- Notificación al deudor 
   IF xQUIEN='D' THEN
      FOR v_Inmu IN CINMUEBLES 
      LOOP
         NOTI_EMBARGO_INMUEBLES(v_Inmu.IDEXPE,v_Inmu.ID);
      END LOOP;      
   END IF;

   -- Mandamiento al Registro
   IF xQUIEN='M' THEN
      FOR v_Inmu IN CMANDAMIENTO 
      LOOP
	   Pon_Fechas_Inmu(v_Inmu.ID,1,xFECHA);
      END LOOP;      
   END IF;

   -- Valoración Municipal
   IF xQUIEN='V' THEN

      FOR v_Inmu IN CVALORACION 
      LOOP
         NOTI_VALORACION_INMUEBLES(v_Inmu.IDEXPE,v_Inmu.ID);
      END LOOP;      
   END IF;

   -- Subasta
   IF xQUIEN='S' THEN
      FOR v_Inmu IN CSUBASTA
      LOOP
	   NOTI_SUBASTA_INMUEBLES(v_Inmu.IDEXPE,v_Inmu.ID);
      END LOOP;      
   END IF;

   -- Requerimiento de Titulos
   IF xQUIEN='R' THEN
      FOR v_Inmu IN CREQUETITULOS
      LOOP
	   Requerimiento_DE_Titulos(v_Inmu.IDEXPE,v_Inmu.ID,xFecha);
      END LOOP;      
   END IF;

   -- Cargas Inscritas
   IF xQUIEN='C' THEN
      FOR v_Inmu IN CCARGAS
      LOOP
	   CERTIFICA_CARGAS_DEUDORES(v_Inmu.IDEXPE,v_Inmu.ID,xFecha);
      END LOOP;      
   END IF;

END;
/

/********************************************************************/
/*
xQUIEN = 'E' -> EMISION DE DILIGENCIA
xQUIEN = 'D' -> NOTIFICACION AL DEUDOR Y TERCEROS
xQUIEN = 'M' -> MANDAMIENTO AL REGISTRADOR
xQUIEN = 'I' -> DOCUMENTOS INTERNOS
xQUIEN = 'V' -> VALORACION MUNICIPAL
xQUIEN = 'A' -> AUTORIZACION DE SUBASTA
xQUIEN = 'S' -> SUBASTA
xQUIEN = 'R' -> REQUERIMIENTO DE TITULOS
xQUIEN = 'C' -> SITUACION DE CARGAS INSCRITAS
*/
--
CREATE OR REPLACE PROCEDURE IMPRIME_NOTI_INMUEBLES (
		xZONA		IN CHAR,
		xQUIEN	IN CHAR,
		xLOTE		IN CHAR,
		xLOTEENTERO IN CHAR)
AS

   xIDExpe		INTEGER;
   xIDEmbargo	INTEGER;
   xIDTERCERO	INTEGER;

   xAYUNTAMIENTO	VARCHAR2(50);
   xNOMBRE		VARCHAR2(80);
   xDIRECCION	VARCHAR2(100);
   xPOBLACION	VARCHAR2(50);
   xCIF		CHAR(10);
   xTELEFONOS	VARCHAR2(100);
   xPROVINCIA	VARCHAR2(50);
   xRESPONSABLE	VARCHAR2(50);
   xPOSTALES_NIF	VARCHAR2(80);
   xARQUITECTO	VARCHAR2(50);

   xPrincipal		FLOAT;
   xRecargo			FLOAT;
   xSumaPrincipal		FLOAT;
   xSumaRecargo		FLOAT;
   xValoracion		FLOAT;
   xNada1	FLOAT;
   xNada2	FLOAT;
   xNada3	FLOAT; 
   xFECHAS		VARCHAR2(2048);

   -- Recorre todos los expedientes de un lote que tengan al menos una finca embargada.
   CURSOR CDILI IS SELECT DISTINCT E.ID,E.IDEXPE,E.AYTO,E.EXPEDIENTE,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.F_DILIGENCIA
			 FROM EMBARGOS_INMUEBLES E,FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=F.IDEXPE AND E.IDEXPE=P.ID AND
				E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   -- Recorre todos los expedientes de un lote con diligencia de embargo emitida.
   CURSOR CINMU IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.EMITIDA_NOTI
			 FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=P.ID AND
					E.F_DILIGENCIA IS NOT NULL AND 
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   -- Recorre todos los expedientes de un lote con todas las notificaciones recibidas
   CURSOR CMANDAMIENTO IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.F_MANDAMIENTO
			 FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=P.ID AND
					E.NOTI_EMBARGO='S' AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   -- Recorre todos los expedientes de un lote con los mandamientos anotados
   CURSOR CVALORACION IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.VALORACION
			 FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=P.ID AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE AND
					E.ID NOT IN 
					(SELECT IDEMBINMU FROM VWFINCASEMBARGADAS 
			         	   WHERE IDEMBINMU=E.ID AND FECHA_EMBARGO IS NULL);

   -- Recorre todos los expedientes de un lote con los mandamientos y la valoracion anotados,
   -- y con la fecha de autorizacion de subasta puesta. 
   CURSOR CAUTORIZASUBASTA IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.F_AUTORIZACION,E.EMI_NOTI_SUBA
			 FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=P.ID AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.VALORACION='S' AND
					E.F_AUTORIZACION IS NOT NULL AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   -- Recorre todos los expedientes de un lote con los mandamientos y la valoracion anotados, 
   -- y con la fecha de subasta puesta. 
   CURSOR CSUBASTA IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.F_AUTORIZACION,E.F_SUBASTA,E.EMI_NOTI_SUBA
			 FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F,EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=P.ID AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.VALORACION='S' AND
					E.F_SUBASTA IS NOT NULL AND
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;


   -- Recorre todos los expedientes de un lote con la diligencia emitida
   CURSOR CREQUETITULOSYCARGAS IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, 
			 E.F_MANDAMIENTO,E.REQUERIMIENTO_TITULOS, E.CERTIFICACION_CARGAS
			 FROM EMBARGOS_INMUEBLES E, FINCAS_EMBARGADAS F, EXPEDIENTES P 
				WHERE E.ID=F.IDEMBINMU AND E.IDEXPE=P.ID AND
					E.F_DILIGENCIA IS NOT NULL AND 
					E.ZONA=xZONA AND P.LOTE_4=xLOTE;

   -- Recorre los valores de un expediente.
   CURSOR CVALORES IS SELECT V.ID, V.YEAR,  
		V.PADRON||'-'||V.YEAR||'-'||V.PERIODO||'-'||V.RECIBO||'   '||rtrim(C.DESCRIPCION)||
		'   '||rtrim(V.DOM_TRIBUTARIO) AS CONCEPTO,
		V.DOM_TRIBUTARIO, V.F_APREMIO, C.DESCRIPCION 
		FROM VALORES V, CONCEPTOS C WHERE 
		EXPEDIENTE=xIDEXPE AND ID_INMUEBLES=xIDEMBARGO AND C.CONCEPTO=V.PADRON
		AND V.F_INGRESO IS NULL AND V.F_SUSPENSION IS NULL AND V.FECHA_DE_BAJA IS NULL;

   CURSOR CTERCEROS IS SELECT 
		T.ID AS IDTERCERO, T.NIF, NOMBRE AS NOMBRE_NIF, DOMICILIO AS DOMI_NIF, 
		CODIGO_POSTAL||' '||rtrim(POBLACION)||' '||rtrim(PROVINCIA) AS POSTALES_NIF, R.DESCRIPCION 	
		FROM TERCEROS T, vwDOMICONTRI C, TIPO_TERCERO R
		WHERE EXPEDIENTE=xIDEXPE AND T.NIF=C.NIF AND T.RELACION=R.RELACION
		AND TRAMITE IN('T','4') and
		(t.fincas_todas='S' or t.id in
		  (select tercero from fincas_terceros where finca in
  			(select finca from fincas_embargadas where idexpe=xIDEXPE 
				and idembinmu=xIDEMBARGO)
  		   )
		);
	
   CURSOR CFINCAS IS SELECT F.DESCRIPCION,F.LIBRO,F.TOMO,F.FOLIO,F.FINCA,F.INSCRIPCION,
	E.IMPORTE_VALO, E.F_VALORACION
	FROM FINCAS F, FINCAS_EMBARGADAS E
	WHERE F.ID=E.FINCA AND E.IDEXPE=xIDEXPE AND E.IDEMBINMU=xIDEMBARGO
    	AND (
		xIDTERCERO=0 
		OR 
		E.IDEXPE IN 
			(SELECT E.IDEXPE FROM TERCEROS T 
				WHERE T.ID=xIDTERCERO AND E.IDEXPE=T.EXPEDIENTE
				AND (T.FINCAS_TODAS='S' OR T.ID  IN(
              			SELECT T.ID FROM TERCEROS T,FINCAS_TERCEROS M
			            WHERE M.TERCERO=T.ID AND M.FINCA=E.FINCA)
				)
			)
		);



   CURSOR CREGISTROS IS SELECT ID, NUMERO, NOMBRE, DIRECCION, 
	RTRIM(PROVINCIA)||' '||CODIGO_POSTAL AS POSTALES_REGISTRO
	FROM REGISTROS_PROPIEDAD WHERE ID IN
	(SELECT ID_REGISTRO_PRO FROM VWFINCASEMBARGADAS
	WHERE IDEXPE=xIDEXPE AND IDEMBINMU=xIDEMBARGO);


BEGIN

  -- --------------------------------------------------------------------------------------
  -- PARTE COMUN A TODAS LAS OPCIONES -----------------------------------------------------
  -- --------------------------------------------------------------------------------------
   DELETE FROM IMP_NOTI_INMUEBLES WHERE USUARIO=(SELECT UID FROM DUAL);
   DELETE FROM IMP_NOTI_INMUEBLES_DETALLE WHERE USUARIO=(SELECT UID FROM DUAL);
   DELETE FROM IMP_NOTI_INMUEBLES_DETALLE2 WHERE USUARIO=(SELECT UID FROM DUAL);
 
   SELECT Z.AYUNTAMIENTO,Z.NOMBRE,Z.DIRECCION,Z.POBLACION,Z.PROVINCIA,Z.RESPONSABLE,Z.CIF,
	'Tel.'||Z.TELEFONO1||'-'||Z.TELEFONO2||',Fax:'||Z.FAX AS TELEFONOS
   INTO xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xRESPONSABLE, xCIF,xTELEFONOS
   FROM ZONAS Z, USUARIOS U 
   WHERE Z.ZONA=U.ZONA AND U.USUARIO=USER;   

  -- --------------------------------------------------------------------------------------
  -- EMISION DE DILIGENCIA ----------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   IF xQUIEN='E' THEN  

      FOR v_dili IN CDILI -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_dili.F_DILIGENCIA IS NULL) THEN

	   	begin -- Obtengo los datos postales del deudor
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF from contribuyentes where nif=v_dili.NIF;
		   exception
		      when no_data_found then
		   	   xPOSTALES_NIF:='';
	   	end;

		xIDExpe:=v_dili.IDEXPE;
		xIDEmbargo:=v_dili.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;

		-- Para cada valor del expediente debo generar una tupla en la tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		   INSERT INTO IMP_NOTI_INMUEBLES_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES
			(xIDExpe,xIDEmbargo,v_Valor.YEAR,v_Valor.CONCEPTO,v_Valor.DOM_TRIBUTARIO,
				v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;

		-- Datos del deudor
         	INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
		   POBLACION,PROVINCIA,TELEFONOS,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
		   NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,RESPONSABLE,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_dili.IDEXPE,v_dili.EXPEDIENTE,v_dili.ID,v_dili.AYTO,
		   v_dili.NIF,v_dili.NOMBRE_NIF,
		   v_dili.DOMI_NIF,xPOSTALES_NIF,xRESPONSABLE,
		   xSumaPrincipal,xSumaRecargo,v_dili.COSTAS,v_dili.INTERESES,
		   xSumaPrincipal+xSumaRecargo+v_dili.COSTAS+v_dili.INTERESES);

	   END IF;

	END LOOP; -- v_dili

  -- --------------------------------------------------------------------------------------
  -- EMISION DE NOTIFICACIONES AL DEUDOR Y A LOS TERCEROS ---------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='D' THEN  

      FOR v_Inmu IN CINMU -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.EMITIDA_NOTI='N') THEN
	   	
	   	begin -- Obtengo datos postales del deudor
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF from contribuyentes where nif=v_Inmu.NIF;
		   exception
		      when no_data_found then
			   xPOSTALES_NIF:='';
	   	end;

		xIDExpe:=v_Inmu.IDEXPE;
		xIDEmbargo:=v_Inmu.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;

		-- Para cada valor del expediente debo generar una tupla en la tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		   INSERT INTO IMP_NOTI_INMUEBLES_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES 
			(xIDExpe,xIDEmbargo, v_Valor.YEAR,v_Valor.CONCEPTO,
				v_Valor.DOM_TRIBUTARIO, v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;

		-- Introduzco los datos del deudor
         	INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
		   POBLACION,PROVINCIA,TELEFONOS,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
		   NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,RESPONSABLE,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
		   ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,POSTALES_TERCERO)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
		   v_Inmu.NOMBRE_NIF,v_Inmu.DOMI_NIF,xPOSTALES_NIF,xRESPONSABLE,
		   xSumaPrincipal,xSumaRecargo,v_Inmu.COSTAS,v_Inmu.INTERESES,
		   xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES,
		   0,v_Inmu.NIF,v_Inmu.NOMBRE_NIF, v_Inmu.DOMI_NIF,xPOSTALES_NIF);

		-- Genero las fincas del deudor
		xIDTercero:=0;
		FOR v_Fincas IN CFINCAS LOOP
			INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION,IMPORTE_VALO,F_VALORACION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION,
				v_Fincas.IMPORTE_VALO, v_Fincas.F_VALORACION);
		END LOOP;

		-- Para cada tercero genero una nueva tupla en la tabla principal igual que la 
		-- del deudor salvo que tendrá como datos personales los datos 
		-- del tercero se rellena el campo ENCALIDADDE
		FOR v_Terc IN CTERCEROS LOOP
         	   INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
			POBLACION,PROVINCIA,TELEFONOS,
		   	IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
			NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,RESPONSABLE,
		   	PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
			ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,
			POSTALES_TERCERO,ENCALIDADDE)
	   	   VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   	v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,v_Inmu.NOMBRE_NIF,
		   	v_Inmu.DOMI_NIF,xPOSTALES_NIF,xRESPONSABLE,
		   	xSumaPrincipal,xSumaRecargo,v_Inmu.COSTAS,v_Inmu.INTERESES,
		   	xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES,
			v_TERC.IDTERCERO, v_TERC.NIF,v_TERC.NOMBRE_NIF,v_TERC.DOMI_NIF,
			v_TERC.POSTALES_NIF,v_TERC.DESCRIPCION);
			
		   -- Rellena para cada tercero las fincas a las que está afecto.
		   xIDTERCERO:=v_TERC.IDTERCERO;
		   FOR v_Fincas IN CFINCAS LOOP
			INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION,IMPORTE_VALO,F_VALORACION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION,
				v_Fincas.IMPORTE_VALO, v_Fincas.F_VALORACION);
		   END LOOP;

		END LOOP;

	   END IF;

	END LOOP; -- v_Inmu

  -- --------------------------------------------------------------------------------------
  -- EMISION DE MANDAMIENTOS AL REGISTRO --------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='M' THEN  

      FOR v_Inmu IN CMANDAMIENTO -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.F_MANDAMIENTO IS NULL) THEN
	   	
	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF from contribuyentes where nif=v_Inmu.NIF;
		   exception
		      when no_data_found then
			   xPOSTALES_NIF:='';
	   	end;

		xIDExpe:=v_Inmu.IDEXPE;
		xIDEmbargo:=v_Inmu.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;
		xFechas:='';

		-- Para cada valor del expediente debo generar una tupla en la tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;
		   xFechas:=xFechas||TO_CHAR(v_Valor.F_APREMIO,'dd-mm-yyyy')||',';

		   INSERT INTO IMP_NOTI_INMUEBLES_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES
			(xIDExpe, xIDEmbargo, v_Valor.YEAR,v_Valor.CONCEPTO,v_Valor.DOM_TRIBUTARIO,
				v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;


		-- Para cada registro genero una nueva tupla.
		FOR v_Regi IN CREGISTROS LOOP
         	   INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
			POBLACION,PROVINCIA,TELEFONOS,
		   	IDEXPE,EXPEDIENTE,IDEMBARGO, AYTO,
			NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,RESPONSABLE,
		   	PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
			FECHAS_APREMIO,ID_REGISTRO,
		   	NOMBRE_REGISTRO,DOMI_REGISTRO,POSTALES_REGISTRO,NUMERO_REGISTRO)
	   	   VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   	v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,v_Inmu.NOMBRE_NIF,
		   	v_Inmu.DOMI_NIF,xPOSTALES_NIF,xRESPONSABLE,
		   	xSumaPrincipal,xSumaRecargo,v_Inmu.COSTAS,v_Inmu.INTERESES,
		   	xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES,
			xFechas,v_Regi.ID,
		   	v_Regi.NOMBRE, v_Regi.DIRECCION,v_Regi.POSTALES_REGISTRO,v_Regi.NUMERO);

		END LOOP;

	   END IF;

	END LOOP; -- v_Inmu
  -- --------------------------------------------------------------------------------------
  -- DOCUMENTOS INTERNOS O VALORACION MUNICIPAL. NECESITAN LOS MISMOS CAMPOS Y TUPLAS -----
  -- --------------------------------------------------------------------------------------
   ELSIF (xQUIEN='I') OR (xQUIEN='V') THEN  

      FOR v_Inmu IN CVALORACION -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.VALORACION='N') THEN

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF from contribuyentes where nif=v_Inmu.NIF;
		   exception
		      when no_data_found then
			   xPOSTALES_NIF:='';
	   	end;

		-- Obtengo el arquitecto que valorará la finca.
		SELECT ARQUITECTO INTO xARQUITECTO FROM MUNICIPIOS WHERE AYTO=v_Inmu.AYTO;

       	INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
		   POBLACION,PROVINCIA,TELEFONOS,ENCALIDADDE,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,RESPONSABLE)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,
		   xTELEFONOS,xARQUITECTO,
		   v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
		   v_Inmu.NOMBRE_NIF,v_Inmu.DOMI_NIF,xPostales_Nif,xRESPONSABLE);

		-- Esto se utiliza para la notificacion de valoracion, para mostrar solo 
		-- las fincas del deudor que tienen valoracion.
		   xIDExpe:=v_Inmu.IDEXPE;
		   xIDEmbargo:=v_Inmu.ID;
		   xIDTercero:=0;
		   FOR v_Fincas IN CFINCAS LOOP
			IF v_Fincas.F_VALORACION IS NOT NULL THEN
			   INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION,IMPORTE_VALO,F_VALORACION) 
			   VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION,
				v_Fincas.IMPORTE_VALO, v_Fincas.F_VALORACION);
			END IF;
		   END LOOP;

	   END IF;

	END LOOP; -- v_Inmu

  -- --------------------------------------------------------------------------------------
  -- AUTORIZACION DE SUBASTA --------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='A' THEN  

      FOR v_Inmu IN CAUTORIZASUBASTA -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.EMI_NOTI_SUBA='N') THEN

		xIDExpe:=v_Inmu.IDEXPE;
		xIDEmbargo:=v_Inmu.ID;
		xSumaPrincipal:=0;
		xSumaRecargo:=0;

		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		END LOOP;

		-- El campo principal tiene la valoracion de todas las fincas del embargo.
		SELECT SUM(IMPORTE_VALO) INTO xValoracion FROM FINCAS_EMBARGADAS 
		WHERE IDEMBINMU=xIDEmbargo;

		IF xValoracion IS NULL THEN
		   xValoracion:=0;
		END IF;

       	INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
		   POBLACION,PROVINCIA,TELEFONOS,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,RESPONSABLE,FECHA,
		   PRINCIPAL,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
		   v_Inmu.NOMBRE_NIF,xRESPONSABLE,v_Inmu.F_AUTORIZACION,
		   xValoracion,
		   xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES);

	   END IF;

	END LOOP; -- v_Inmu

  -- --------------------------------------------------------------------------------------
  -- SUBASTA ------------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='S' THEN  

      FOR v_Inmu IN CSUBASTA -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.EMI_NOTI_SUBA='N') THEN

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_Inmu.NIF;
		   exception
		      when no_data_found then
			   xPOSTALES_NIF:='';
	   	end;

		xIDExpe:=v_Inmu.IDEXPE;
		xIDEmbargo:=v_Inmu.ID;
		xSumaPrincipal:=0;
		xSumaRecargo:=0;

		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		END LOOP;

		-- Introduce el deudor
		INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
			POBLACION,PROVINCIA,TELEFONOS,
		   	IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,RESPONSABLE,
		   	ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,POSTALES_TERCERO,
		   	FECHAS_APREMIO,FECHA,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
	   	   v_Inmu.NOMBRE_NIF,xRESPONSABLE,
		   0,v_Inmu.NIF,v_Inmu.NOMBRE_NIF, v_Inmu.DOMI_NIF,xPOSTALES_NIF,
	   	   TO_CHAR(v_Inmu.F_AUTORIZACION,'DD-MM-YYYY'),v_Inmu.F_SUBASTA,
	   	   xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES);

		xIDTERCERO:=0;
		-- Introduce todas las fincas del deudor
		FOR v_Fincas IN CFINCAS LOOP
			INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION,IMPORTE_VALO,F_VALORACION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION,
				v_Fincas.IMPORTE_VALO, v_Fincas.F_VALORACION);
		END LOOP;

		-- Para cada tercero genero una nueva tupla en la tabla principal con 
		-- los datos del tercero, e introduzco las fincas asociadas al mismo
		FOR v_Terc IN CTERCEROS LOOP
		   INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
			POBLACION,PROVINCIA,TELEFONOS,
		   	IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,RESPONSABLE,
		   	ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,POSTALES_TERCERO,
		   	FECHAS_APREMIO,FECHA,TOTAL,ENCALIDADDE)
	   	   VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   	v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
		   	v_Inmu.NOMBRE_NIF,xRESPONSABLE,
			v_TERC.IDTERCERO, v_TERC.NIF,v_TERC.NOMBRE_NIF,v_TERC.DOMI_NIF,
			v_TERC.POSTALES_NIF,
		   	TO_CHAR(v_Inmu.F_AUTORIZACION,'DD-MM-YYYY'),v_Inmu.F_SUBASTA,
		   	xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES,v_TERC.DESCRIPCION);


		   xIDTERCERO:=v_TERC.IDTERCERO;
		   -- Fincas afectas al tercero.Las introduzco en la tabla temporal.
		   FOR v_Fincas IN CFINCAS LOOP
			INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION,IMPORTE_VALO,F_VALORACION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION,
				v_Fincas.IMPORTE_VALO, v_Fincas.F_VALORACION);
		   END LOOP;

		END LOOP;

	   END IF;

	END LOOP; -- v_Inmu


  -- --------------------------------------------------------------------------------------
  -- REQUERIMIENTO DE TITULOS --------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='R' THEN  

      FOR v_Inmu IN CREQUETITULOSYCARGAS -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.REQUERIMIENTO_TITULOS IS NULL) THEN
	   	
	   	begin -- Obtengo datos postales del deudor
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF from contribuyentes where nif=v_Inmu.NIF;
		   exception
		      when no_data_found then
			   xPOSTALES_NIF:='';
	   	end;

		xIDExpe:=v_Inmu.IDEXPE;
		xIDEmbargo:=v_Inmu.ID;
		xSumaPrincipal:=0;
		xSumaRecargo:=0;

		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		END LOOP;

		-- Introduzco los datos del deudor
         	INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
		   POBLACION,PROVINCIA,TELEFONOS,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
		   NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
		   v_Inmu.NOMBRE_NIF,v_Inmu.DOMI_NIF,xPOSTALES_NIF,
		   xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES);


	   END IF;

	END LOOP; -- v_Inmu

  -- --------------------------------------------------------------------------------------
  -- CERTIFICACION DE CARGAS ----------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='C' THEN  

      FOR v_Inmu IN CREQUETITULOSYCARGAS -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_Inmu.CERTIFICACION_CARGAS IS NULL) THEN
	   	
	   	begin -- Obtengo datos postales del deudor
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF from contribuyentes where nif=v_Inmu.NIF;
		   exception
		      when no_data_found then
			   xPOSTALES_NIF:='';
	   	end;

		xIDExpe:=v_Inmu.IDEXPE;
		xIDEmbargo:=v_Inmu.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;

		-- Para cada valor del expediente debo generar una tupla en la tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		   INSERT INTO IMP_NOTI_INMUEBLES_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES 
			(xIDExpe,xIDEmbargo, v_Valor.YEAR,v_Valor.CONCEPTO,
				v_Valor.DOM_TRIBUTARIO, v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;

		-- Introduzco los datos del deudor
         	INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
		   POBLACION,PROVINCIA,TELEFONOS,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
		   NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,FECHA,RESPONSABLE,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
		   ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,POSTALES_TERCERO)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,
		   v_Inmu.NOMBRE_NIF,v_Inmu.DOMI_NIF,xPOSTALES_NIF,v_Inmu.F_MANDAMIENTO,xRESPONSABLE,
		   xSumaPrincipal,xSumaRecargo,v_Inmu.COSTAS,v_Inmu.INTERESES,
		   xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES,
		   0,v_Inmu.NIF,v_Inmu.NOMBRE_NIF, v_Inmu.DOMI_NIF,xPOSTALES_NIF);

		-- Genero las fincas del deudor
		xIDTercero:=0;
		FOR v_Fincas IN CFINCAS LOOP
			INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION);
		END LOOP;

		-- Para cada tercero genero una nueva tupla en la tabla principal igual que la 
		-- del deudor salvo que tendrá como datos personales los datos 
		-- del tercero se rellena el campo ENCALIDADDE
		FOR v_Terc IN CTERCEROS LOOP
         	   INSERT INTO IMP_NOTI_INMUEBLES(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,
			POBLACION,PROVINCIA,TELEFONOS,
		   	IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
			NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,FECHA,RESPONSABLE,
		   	PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
			ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,
			POSTALES_TERCERO,ENCALIDADDE)
	   	   VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   	v_Inmu.IDEXPE,v_Inmu.EXPEDIENTE,v_Inmu.ID,v_Inmu.AYTO,v_Inmu.NIF,v_Inmu.NOMBRE_NIF,
		   	v_Inmu.DOMI_NIF,xPOSTALES_NIF,v_Inmu.F_MANDAMIENTO,xRESPONSABLE,
		   	xSumaPrincipal,xSumaRecargo,v_Inmu.COSTAS,v_Inmu.INTERESES,
		   	xSumaPrincipal+xSumaRecargo+v_Inmu.COSTAS+v_Inmu.INTERESES,
			v_TERC.IDTERCERO, v_TERC.NIF,v_TERC.NOMBRE_NIF,v_TERC.DOMI_NIF,
			v_TERC.POSTALES_NIF,v_TERC.DESCRIPCION);
			
		   -- Rellena para cada tercero las fincas a las que está afecto.
		   xIDTERCERO:=v_TERC.IDTERCERO;
		   FOR v_Fincas IN CFINCAS LOOP
			INSERT INTO IMP_NOTI_INMUEBLES_DETALLE2(IDEMBARGO,ID_TERCERO,DESCRIPCION,
				TOMO, FINCA,LIBRO,FOLIO,INSCRIPCION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_Fincas.DESCRIPCION,v_Fincas.TOMO,
				v_Fincas.FINCA,v_Fincas.LIBRO,v_Fincas.FOLIO,v_Fincas.INSCRIPCION);
		   END LOOP;

		END LOOP;

	   END IF;

	END LOOP; -- v_Inmu

  -- --------------------------------------------------------------------------------------
   END IF;   
  -- --------------------------------------------------------------------------------------

END;
/

/********************************************************************/
COMMIT;
/********************************************************************/

