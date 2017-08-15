/*******************************************************************************************
Acción: Elimina un vehiculo. 

Parámetros: xID: ID del Vehículo en la tabla VehiculosR -> campo VEHI de AUTOS_EMBARGADOS.
		xERROR: Parámetro de Salida con el código de error que se pueda producir.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE BORRAR_VEHICULO(xID IN INTEGER, xERROR OUT INTEGER)
AS
  xCONT INTEGER;
BEGIN

	SELECT COUNT(*) INTO xCONT FROM AUTOS_EMBARGADOS WHERE VEHI=xID;
	IF xCONT>0 THEN
		xERROR:=1;
		RETURN;
	END IF;

	SELECT COUNT(*) INTO xCONT FROM AUTOS_TERCEROS WHERE VEHI=xID;
	IF xCONT>0 THEN
		xERROR:=2;
		RETURN;
	END IF;

	xERROR:=0;
	Delete from VEHICULOSR where ID=xID;
END;
/

/*****************************************************************************************
Autor:  Antonio Pérez Caballero.
Fecha:  23/03/2001
Acción: Inserta un embargo de vehiculos a un expediente de un deudor.
        La deuda es a un municipio.
	  Los vehículos se separan en tantos embargos como entidades acreedoras de un deudor,
        de igual manera que los embargos de bienes inmuebles. Se utilizan en valores
        los mismos campos que para bienes inmuebles valores.
        Valores.ID_VEHICULOS como mecanismo de control de que un valor
        pertenece a un embargo de vehículos en particular.

Parámetros: xIDExpe: ID del Expediente.
		xZona:   Zona de Gestión.
		xAyto:   Ayuntamiento.
		xExpe:   Expediente expresado en cadena de diez caracteres.
		xNIF:    Nif del Deudor.

INTERNO
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE AUTOS_DIVIDIR_AYTO
(			xIDExpe IN INT, 
			xZona IN char,
			xAyto IN char,
			xEXPE IN CHAR,
			xNIF IN CHAR)
AS

xPRINPEN 	FLOAT DEFAULT 0;
xRECAPEN 	FLOAT DEFAULT 0;
PCOSTAS 	FLOAT DEFAULT 0;
PDEMORA 	FLOAT DEFAULT 0;
xTOTAL 		FLOAT DEFAULT 0;
sPrincipal	FLOAT DEFAULT 0;
sRecargo	FLOAT DEFAULT 0;
xLast 		INT;

CURSOR cVALORES IS
	SELECT ID FROM VALORES
	where Expediente=xIDExpe
          and F_ingreso is null
          and Fecha_de_baja is null
          and F_suspension is null
          and ID_VEHICULOS IS NULL
		  and AYTO=xAYTO
	FOR UPDATE OF ID_VEHICULOS;
BEGIN


	-- Suma del pendiente por cada ayuntamiento
	FOR v_Valores IN cVALORES
	LOOP
		PkIngresos.GET_PENDIENTE(v_Valores.ID, xPRINPEN, xRECAPEN, PCOSTAS, PDEMORA, xTOTAL);
		sPrincipal:=sPrincipal+xPRINPEN;
		sRecargo:=sRecargo+xRECAPEN;
	END LOOP;

	-- creamos el expediente de embargo
	INSERT INTO EMBARGOS_AUTOS
    	    (ZONA,AYTO,IDEXPE,EXPEDIENTE,DEUDA_TOTAL,NIF)
  	VALUES
    	    (xZona,xAYTO,xIDExpe,xExpe,ROUND(sPrincipal+sRecargo,2), xNIF)
	return ID into xLast;

	-- Se lo asignamos a los valores 
	FOR v_Valores IN cVALORES
	LOOP
      UPDATE VALORES SET ID_VEHICULOS=xLast
		where current of cVALORES;
	END LOOP;

END;
/

/*******************************************************************************************
Acción: Inserta un embargo de vehiculos a un expediente de un deudor.
        La deuda es a la junta.

Parámetros: xIDExpe: ID del Expediente;
		xZona: Zona de Gestión;
		xExpe: Expediente expresado en cadena de diez caracteres;
		xNIF:  Nif del Deudor.

INTERNO
********************************************************************************************/

CREATE OR REPLACE PROCEDURE AUTOS_DIVIDIR_JUNTA
(			xIDExpe IN INT, 
			xZona IN char,
			xEXPE IN CHAR,
			xNIF IN CHAR)
AS

xPRINPEN 	FLOAT DEFAULT 0;
xRECAPEN 	FLOAT DEFAULT 0;
PCOSTAS 	FLOAT DEFAULT 0;
PDEMORA 	FLOAT DEFAULT 0;
xTOTAL      FLOAT DEFAULT 0;
sPrincipal	FLOAT DEFAULT 0;
sRecargo	FLOAT DEFAULT 0;
xLast       INT;

CURSOR cVALORES IS
	SELECT V.ID FROM VALORES V, MUNICIPIOS M
	where V.Expediente=xIDExpe
            and V.F_ingreso is null
            and V.Fecha_de_baja is null
            and V.F_suspension is null
            and V.ID_VEHICULOS IS NULL
		    AND V.AYTO=M.AYTO
		    AND M.TIPO_CLI='JUN'
	FOR UPDATE OF V.ID_VEHICULOS;

BEGIN


	-- Suma del pendiente por cada ayuntamiento

	FOR v_Valores IN cVALORES
	LOOP
		PkIngresos.GET_PENDIENTE(v_Valores.ID, xPRINPEN, xRECAPEN, PCOSTAS, PDEMORA, xTOTAL);
		sPrincipal:=sPrincipal+xPRINPEN;
		sRecargo:=sRecargo+xRECAPEN;
	END LOOP;


	-- creamos el expediente de embargo
    INSERT INTO EMBARGOS_AUTOS
    	    (ZONA,AYTO,IDEXPE,EXPEDIENTE,DEUDA_TOTAL,NIF)
  	VALUES
    	    (xZona,'JUN',xIDExpe,xExpe,ROUND(sPrincipal+sRecargo,2), xNIF)
	return ID into xLast;

	-- Se lo asignamos a los valores 
	FOR v_Valores IN cVALORES
	LOOP
		UPDATE VALORES SET ID_VEHICULOS=xLast
		where current of cVALORES;
	END LOOP;

END;
/

/*******************************************************************************************
Acción: Parte de un expediente en trámite de embargo de vehiculos y estado PENDIENTE.
        Genera un embargo de vehiculos para cada ayuntamiento y/o para la junta, y 
        pasa al expediente al estado de ABIERTO en ese trámite. 

Parámetros: xIDExpe: ID del Expediente.

DELPHI e INTERNO
********************************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_UnExpeEnLoteVehi(xIDExpe IN INTEGER)
AS
xNIF   CHAR(10);
xZONA  CHAR(2);
xAYTO  CHAR(3);
xEXPE  CHAR(10);
xJUNTA CHAR(1);
xLOTE  CHAR(8);

CURSOR cCLIENTES IS 
	SELECT V.AYTO,M.TIPO_CLI FROM VALORES V, MUNICIPIOS M
		WHERE V.AYTO=M.AYTO
		AND EXPEDIENTE=xIDExpe
		AND F_ingreso is null
      	AND Fecha_de_baja is null
      	AND F_suspension is null
      	AND ID_VEHICULOS IS NULL
	GROUP BY V.AYTO,M.TIPO_CLI;

BEGIN

   -- Averiguar la zona gestora del expediente y el nif del deudor

   SELECT DEUDOR,ZONA,EXPEDIENTE Into xNIF,xZONA,xEXPE
   FROM EXPEDIENTES
   WHERE ID=xIDExpe;

   xJUNTA:='N';
   FOR v_CLIENTES IN cCLIENTES LOOP

		-- PARA LOS AYUNTAMIENTOS UN EMBARGO POR CADA AYUNTAMIENTO AL QUE SE LE DEBA
		IF v_CLIENTES.TIPO_CLI='LOC' THEN
		   -- DEUDOR DE UN AYUNTAMIENTO
		   AUTOS_DIVIDIR_AYTO(xIDExpe, xZONA, v_CLIENTES.AYTO, xEXPE, xNIF);
		END IF;

		-- PARA DEUDAS DE LA JUNTA TODAS LAS DEUDAS A UN UNICO EMBARGO
		IF v_CLIENTES.TIPO_CLI='JUN' AND xJUNTA='N' THEN
		   -- DEUDOR DE LA JUNTA
			AUTOS_DIVIDIR_JUNTA(xIDExpe ,xZONA, xEXPE, xNIF);
		   xJUNTA:='S';
		END IF;

   END LOOP;

   UPDATE EXPEDIENTES SET EMBARGO_8='O'
   WHERE ID=xIDexpe And EMBARGO_8='P'
   RETURNING LOTE_8 INTO xLOTE;

   IF xLOTE IS NOT NULL THEN
      PKSeguimiento.NotaInformativa(xIDExpe,
	   'Se agrega al Embargo de Vehículos con Lote número: '||xLote);	
   ELSE
      PKSeguimiento.NotaInformativa(xIDExpe,
	   'Se agrega al Embargo de Vehículos');
   END IF;

END;
/

/******************************************************************************************
Acción: Genera el embargo de vehiculos de expedientes que estaban en estado PENDIENTE 
        de una zona.
Parámetro: xZONA: Zona de Gestión.
	     xLOTE: Lote de Expedientes en el Pendiente que se desea agregar al Abierto.
MODIFICACION: 19/02/2002 M. Carmen Junco Gomez. Inclusión del número de Lote.
DELPHI
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADDVEHIALL(
		xZONA IN CHAR,
		xLOTE IN CHAR)
AS
   CURSOR EXPE_CUR IS
        SELECT ID
        FROM EXPEDIENTES
        WHERE ZONA=xZONA
              AND EMBARGO_8='P'
              AND F_INGRESO IS NULL
              AND F_ANULACION IS NULL
              AND F_SUSPENSION IS NULL
		  AND LOTE_8=xLOTE;
BEGIN

   FOR v_EXPE IN EXPE_CUR LOOP
      PUT_UnExpeEnLoteVehi(v_EXPE.ID);
   END LOOP;

END;
/

/*******************************************************************************************
Acción: Elimina un embargo de vehiculos, dejando el expediente sin tramites.
        Es similar al procedimiento LEVANTA_VEHICULOS, con la diferencia de que no comprueba 
        si se había emitido el mandamiento. Borra el embargo sin comprobaciones.
        ¿Por que puede ocurrir esto? Porque se paga el embargo, cuando el mandamiento
        se había emitido ya. Una vez que se responde al mandamiento, ya se puede eliminar
        el embargo, y es cuando se llama a este procedimiento.

Parámetros: xIDExpe: ID del Expediente que se desea borrar del trámite.
		xIDEMBAUTO: ID del embargo de autos.

MODIFICACIÓN: 18/02/2002 M. Carmen Junco Gómez.
MODIFICACIÓN: 04/03/2002 M. Carmen Junco Gómez. El expediente se ha de dejar sin trámites 
		  cuando no queden embargos abiertos para ese expediente.
DELPHI
********************************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_LEVANTA_AUTOS(xIDExpe	IN INTEGER,
								xIDEMBAUTO IN INTEGER)
AS
xCUANTOS INTEGER;

BEGIN

	DELETE FROM AUTOS_EMBARGADOS WHERE IDEMBARGOAUTO=xIDEMBAUTO;

   	UPDATE VALORES SET ID_VEHICULOS=NULL 
      WHERE EXPEDIENTE=xIDExpe AND ID_VEHICULOS=xIDEMBAUTO;

    DELETE FROM EMBARGOS_AUTOS WHERE ID=xIDEMBAUTO; 

	SELECT COUNT(*) INTO xCUANTOS FROM EMBARGOS_AUTOS where IDExpe=xIDExpe;	

	IF (xCUANTOS = 0) THEN -- Es el último embargo de vehículos de este Expediente	

      PKSeguimiento.NotaInformativa(xIDEXPE,'El expediente no tiene trámite de vehículos.');	
                                                            
      UPDATE EXPEDIENTES SET EMBARGO_8='0' WHERE ID=xIdExpe;
   
	END IF;
	
END;
/

/******************************************************************************************
Acción: Elimina el embargo de vehiculos de un valor (o varios) de un expediente, 
        dejando al expediente en el trámite de embargo de vehiculos, y pasandolo al estado 
        PENDIENTE si el que se elimina es el último embargo sobre ese expediente.

Parámetros: xIDExpe: ID del Expediente;
		xIDEMBVEHI: ID del Embargo de vehículos;

MODIFICACIÓN: 18/02/2002 M. Carmen Junco Gómez.

DELPHI
******************************************************************************************/

CREATE OR REPLACE PROCEDURE QUITO_EXPELOTEVEHI 
		(xIDEXPE 	IN INTEGER,
		 xIDEMBVEHI IN INTEGER)

AS
xCUANTOS INTEGER DEFAULT 0;

BEGIN

	--estos campos tambien se utilizan para el embargo de vehiculos
	UPDATE VALORES SET ID_VEHICULOS=NULL
		WHERE EXPEDIENTE=xIDEXPE AND ID_VEHICULOS=xIDEMBVEHI;

	DELETE FROM AUTOS_EMBARGADOS WHERE IDEMBARGOAUTO=xIDEMBVEHI;
	DELETE FROM EMBARGOS_AUTOS WHERE ID=xIDEMBVEHI;

	-- Las notificaciones no las elimino, solamente anulo su apunte al embargo.
	UPDATE NOTIFICACIONES SET ID_EMBARGOS=NULL 
	WHERE EXPEDIENTE=xIDEXPE 
		AND ID_EMBARGOS=xIDEMBVEHI 
		AND TIPO_NOTI LIKE '8%';

	SELECT COUNT(*) INTO xCUANTOS FROM EMBARGOS_AUTOS where IDExpe=xIDExpe;	

	IF (xCUANTOS = 0) THEN -- Es el último embargo de vehículos de este Expediente
		PKSeguimiento.NotaInformativa(xIDEXPE,'Pasa a estado Pendiente de Vehículos.');	
		UPDATE EXPEDIENTES SET EMBARGO_8='P'
		WHERE ID=xIDExpe
		      And Embargo_8='O';
	END IF;
	
END;
/	

/*******************************************************************************************
Acción: Deja un Expediente sin trámites. Este expediente debe estar en estado PENDIENTE.
        Lo anota en el seguimiento.
MODIFICACIÓN: 19/02/2002 M. Carmen Junco Gomez. Se estaba modificando el campo 
		  ESTA_EMBARGO='P' en vez de a 'C'.
********************************************************************************************/

CREATE OR REPLACE PROCEDURE QUITA_VEHI_NADA (xEXPE IN INTEGER)
AS
BEGIN
   -- Anotarlo en el seguimiento
   PkSeguimiento.NotaInformativa(xExpe,'Se quita el expediente del pendiente de Vehículos');

   -- Dejar el expediente sin trámites
   UPDATE EXPEDIENTES SET EMBARGO_8='0' WHERE ID=xEXPE;

END;
/

/******************************************************************************************
			   VEHICULOS PENDIENTES -> OTROS PENDIENTES   
Acción: Pasa expedientes con embargo de VEHICULOS en estado PENDIENTE al embargo
        de tipo OTROS en estado PENDIENTE. ¿Cuantos expedientes? Depende del valor de xIDEXPE:
           xIDEXPE  = -1  -> Todos los expedientes de una zona (xZONA)
           xIDEXPE <> -1 -> Un solo expediente (xIDEXPE).
        Anota el tramite negativo para el/los expedientes que trata.

Parámetros: xIDExpe: ID del Expediente;
		xZona:   Zona de Gestión;
		
Modificacion: 02/12/2003. Agustín León Robles. 
		Se modifica el apunte en el seguimiento de que no tiene vehiculos cuando se pasa a otro tramites
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE BORRAR_SIN_AUTOS(
				xIDEXPE 	IN 		INTEGER, 
				xZONA   	IN 		CHAR)

AS
	-- expedientes sin vehículos los pasamos al siguiente trámite
	CURSOR CC_LOTE IS
			SELECT ID FROM EXPEDIENTES
					WHERE LOTE_8 IS NULL AND DEUDOR NOT IN (SELECT NIF FROM VEHICULOSR) 
					AND ZONA=xZONA AND EMBARGO_8='P';

BEGIN   

	IF xIDEXPE=-1 THEN

		-- Se pasan todos los expedientes pendientes de Vehículos a Otros Trámites
		FOR v_LOTE IN CC_LOTE LOOP
		
			PkSeguimiento.AnotaTramiteNegativo(v_LOTE.ID,
				'No se encontraron bienes muebles o semovientes. No tiene lote.','8',sysdate);

			UPDATE EXPEDIENTES SET EMBARGO_8='0',
					EMBARGO_X=DECODE(EMBARGO_X,'0','P',EMBARGO_X),
					F_EMBARGO_OTROS=DECODE(EMBARGO_X,'0',SYSDATE,F_EMBARGO_OTROS)
			WHERE ID=v_LOTE.ID;

		END LOOP;

	ELSE -- Se pasa un sólo expediente a Otros Trámites

		PkSeguimiento.AnotaTramiteNegativo(xIDEXPE,
			'No se encontraron bienes muebles o semovientes','8',sysdate);

		UPDATE EXPEDIENTES SET EMBARGO_8='0',
					EMBARGO_X=DECODE(EMBARGO_X,'0','P',EMBARGO_X),
					F_EMBARGO_OTROS=DECODE(EMBARGO_X,'0',SYSDATE,F_EMBARGO_OTROS)
		WHERE ID=xIDEXPE AND EMBARGO_8='P';

	END IF;

END;
/


/******************************************************************************************
Acción: Realiza la diligencia de un embargo de vehiculos de un expediente,
        calculando la deuda total del embargo y anotando la operación en 
        el seguimiento del expediente.

Parámetros: xIDVEHI: ID del Embargo;
		xIDEXPE: ID del Expediente;
		xFecha:  Fecha de la Diligencia;

MODIFICACIÓN: 20/02/2002 M. Carmen Junco Gómez.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE DILIGENCIA_VEHI 
			(xIDVEHI IN INTEGER,
			 xIDEXPE IN INTEGER, 
			 xFecha IN DATE)
AS
BEGIN   

   UPDATE EMBARGOS_AUTOS SET F_DILIGENCIA=xFECHA
   WHERE ID=xIDVEHI;

   UPDATE EXPEDIENTES SET FECHA_DILI_VEHICULOS=xFECHA WHERE ID=xIDEXPE;

   pkSeguimiento.NotaInformativa(xIDExpe,'Diligencia embargo vehículos con fecha: ' || xFECHA);       	

END;
/

/******************************************************************************************
Autor:  M. Carmen Junco Gómez.
Fecha:  26/02/2002
Acción: Realiza diligencias de embargo de vehículos masivas para los embargos sobre expedientes
	  pertenecientes al Lote que se pasa como parámetro. Se calcula para cada embargo la
	  deuda total y se hace una anotación en el seguimiento del expediente.

Parámetros: xZONA:  Zona de Gestíon;		
		xFecha: Fecha de la Diligencia;
		xLOTE:  Número de Lote;
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE DILIGENCIAS_VEHI(	
				     xZONA   IN CHAR,
				     xFECHA  IN DATE,
				     xLOTE 	 IN CHAR)

AS

   CURSOR CDILI IS SELECT DISTINCT E.ID,E.IDEXPE		
	FROM EMBARGOS_AUTOS E,AUTOS_EMBARGADOS A, EXPEDIENTES P 
	WHERE E.ID=A.IDEMBARGOAUTO 
	AND E.IDEXPE=A.IDEXPE 
	AND E.IDEXPE=P.ID 
	AND E.F_DILIGENCIA IS NULL 
	AND E.ZONA=xZONA AND P.LOTE_8=xLOTE;

BEGIN

   FOR v_AUTO IN CDILI
   LOOP
      DILIGENCIA_VEHI(v_AUTO.ID,v_AUTO.IDEXPE,xFECHA);
   END LOOP;   

END;
/

/******************************************************************************************
Acción: Indica, en un embargo de vehiculos, que se ha realizado la emision de notificación de 
        embargo y crea una Notificacion de embargo de un embargo de vehiculos correspondiente 
        a un expediente determinado.
        La notificación se genera para el deudor y para los terceros afectados.

Parámetros: xIDExpe: ID del Expediente;
		xIDVehi: ID del Embargo de Vehículos;

MODIFICACIÓN: 21/02/2002 M. Carmen Junco Gómez
******************************************************************************************/

CREATE OR REPLACE PROCEDURE NOTI_EMBARGOS_AUTOS
		(xIDExpe IN INTEGER, 
		 xIDVehi IN INTEGER)
AS
	xEmi char(1);
	xNIF char(10);
	xID integer;
	xCuantos integer default 0;

	--solamente se generan notificaciones para los terceros que tengan todos los tramites
	--o especificamente el de vehiculos
	CURSOR cTerceros IS select NIF,ID
                from TERCEROS
                where Expediente=xIDExpe and TRAMITE in ('T','8');
BEGIN

	--en vehiculos no ocurre igual que en inmuebles. Cuando se emita el mandamiento
	--es cuando se conocen los terceros acreedores, entonces hay que generar las 
	--notificaciones para esos terceros. 
	SELECT EMITIDA_NOTI,NIF into xEmi,xNIF
	FROM EMBARGOS_AUTOS
	WHERE ID=xIDVehi;

	-- Si ya se han realizado las notificaciones se anulan todas aquellas de 
    -- terceros que ya no pertenezcan al expediente. 
	-- Se anulan poniendo a null el id de embargos.
	IF (xEmi='S') then

	  UPDATE NOTIFICACIONES SET ID_EMBARGOS=NULL 
	  WHERE EXPEDIENTE=xIDExpe AND ID_EMBARGOS=xIDVehi AND TIPO_NOTI='802'
	        AND NIF NOT IN 
		     (SELECT NIF FROM TERCEROS WHERE EXPEDIENTE=xIDExpe AND TRAMITE IN ('T','8'));

	else
		UPDATE EMBARGOS_AUTOS SET EMITIDA_NOTI='S' WHERE ID=xIDVehi;
	end if;

	--si hay una notificacion generada PARA EL DEUDOR 
	--no se tiene que insertar otra
	select count(*) into xCuantos from notificaciones 
		where ID_Embargos=xIDVehi and Expediente=xIDExpe
		and tipo_noti='801' and NIF=xNIF;

	if xCuantos=0 then
		--notificar al deudor
		--notificacion embargo de vehiculos
		Add_Notificaciones_expe(xIDExpe,'801',xIDVehi, xNIF,'QQ');
	end if;


	--insertar tantas como terceros nuevos del expediente (notificaciones_expe)
	FOR v_TERC IN CTERCEROS LOOP
		--si hay una notificacion generada y grabada PARA LOS TERCEROS
		--no se tiene que insertar otra
		select count(*) into xCuantos from notificaciones 
		where ID_Embargos=xIDVehi and Expediente=xIDExpe
		and tipo_noti='802' and NIF=v_TERC.NIF;

		if xCuantos=0 then
			-- Para no tener que modificar los parametros de la rutina
			-- Add_Notificaciones_Expe se lo pasamos a la tabla de usuarios
			UPDATE USUARIOS SET LAST_TAREA=v_TERC.ID WHERE USUARIO=USER;

			--notificacion embargo bienes muebles terceros
			Add_Notificaciones_expe(xIDExpe,'802', xIDVehi, v_TERC.NIF, 'TE');
		end if;
	END LOOP;
	
END;
/


/***************************************************************************************
Autor: M. Carmen Junco Gomez.
Fecha: 26/02/2002
Acción: Indica, para cada embargo de vehiculos de los expedientes pertenecientes al lote
	  pasado como parámetro, que se ha realizado la emision de notificación de 
        embargo y crea las Notificaciones de embargo.
        Las notificaciones se generan para el deudor y para los terceros afectados.

Parámetros: xZona: Zona de Gestión;
		xQuien: 2: Notificación diligencia de embargo de vehículos;
			  6: Notificación Valoración municipal;
			  7: Notificación Certificación de Cargas;
			  10: Notificación de Subasta;

DELPHI
***************************************************************************************/
-- Modificado: 18/03/2003. Lucas Fernández Pérez. Se introduce un nuevo tipo como '8',
-- por lo que la notificación de subasta pasa de ser tipo '9' a tipo '10'
--
CREATE OR REPLACE PROCEDURE NOTI_AUTOS_MASIVOS(	
     	xZONA   IN CHAR,
     	xQUIEN  IN INTEGER,
     	xFECHA  IN DATE,
     	xLOTE   IN CHAR)

AS

   xCuantos INTEGER;

   CURSOR CDILIGENCIA IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P
				WHERE E.IDEXPE=P.ID AND
					E.ID=A.IDEMBARGOAUTO AND
					E.F_DILIGENCIA IS NOT NULL AND
					E.EMITIDA_NOTI='N' AND 
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;


   CURSOR CVALORACION IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.NOTI_EMBARGO='S' AND E.VALORACION='N' AND 
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;			

   CURSOR CCARGAS IS SELECT DISTINCT E.ID,E.IDEXPE		
				FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.NOTI_EMBARGO='S' AND E.CERTIFICACION_CARGAS IS NULL AND 
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;	

   CURSOR CSUBASTA IS SELECT DISTINCT E.ID,E.IDEXPE
			      FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A,EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.VALORACION='S' AND
					E.F_SUBASTA IS NOT NULL AND
					E.EMI_NOTI_SUBA='N' AND
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;

BEGIN


   -- Notificación diligencia de embargo
   IF xQUIEN=2 THEN
      FOR v_AUTO IN CDILIGENCIA
      LOOP
         NOTI_EMBARGOS_AUTOS(v_AUTO.IDEXPE,v_AUTO.ID);
      END LOOP;      

   -- Notificación Valoración municipal
   ELSIF xQUIEN=6 THEN
      FOR v_AUTO IN CVALORACION 
      LOOP
	   NOTI_VALORACION_VEHI(v_AUTO.IDEXPE,v_AUTO.ID);
      END LOOP;      
   
   -- Notificación Certificación de Cargas
   ELSIF xQUIEN=7 THEN
      FOR v_AUTO IN CCARGAS
	  LOOP
         NOTI_CARGAS_VEHI(v_AUTO.IDEXPE,v_AUTO.ID,xFECHA);
	  END LOOP;

   -- Notificación de Subasta
   ELSIF xQUIEN=10 THEN
	  FOR v_AUTO IN CSUBASTA
	  LOOP
	     NOTI_SUBASTA_VEHI(v_AUTO.IDEXPE,v_AUTO.ID);
	  END LOOP;   
   END IF;

END;
/

-- ****************************************************************************************
-- Acción: Indica en un embargo de vehiculos que se ha realizado la valoración y genera una 
--        Notificación de Valoración Municipal de un embargo de vehículos correspondiente 
--	  a un expediente determinado. La notificación va dirigida al deudor.
--
--Parámetros: xIDExpe: ID del Expediente.
--		xIDVehi: ID del Embargo de Vehículos.
-- Modificado: 17/03/2003 Lucas Fernández Pérez. Inserta una notificación por 
--	Requerimiento de títulos cuando la valoración no se ha emitido.
-- ****************************************************************************************

CREATE OR REPLACE PROCEDURE NOTI_VALORACION_VEHI 
        (xIDExpe IN INTEGER,
        xIDVehi IN INTEGER)
AS
xEmi char(1);
xNIF char(10);

BEGIN

	SELECT VALORACION,NIF into xEmi,xNIF from EMBARGOS_AUTOS WHERE ID=xIDVehi;

	IF (xEmi='N') THEN

		--activar el detector para no poder hacerlo de nuevo
		update EMBARGOS_AUTOS set VALORACION='S' WHERE ID=xIDVehi;

		--notificacion VALORACION
		Add_Notificaciones_expe(xIDExpe,'803', xIDVehi, xNIF,'QQ');
		-- notificación REQUERIMIENTO DE TITULOS
		Add_Notificaciones_expe(xIDExpe,'804', xIDVehi, xNIF,'QQ');

	END IF;
END;
/

/********************************************************************************************
Acción: Indica en un embargo de vehiculos que se ha realizado la emision de notificación de 
        subasta y crea una Notificacion de Subasta del embargo correspondiente a un expediente 
        concreto.
        La notificación se genera para el deudor y para los terceros afectados.

Parámetros: xIDExpe: ID del Expediente;
		xIDVehi: ID del Embargo de Vehículos;
********************************************************************************************/

CREATE OR REPLACE PROCEDURE NOTI_SUBASTA_VEHI
        (xIDExpe IN INTEGER,
        xIDVehi IN INTEGER)
AS
xEmi char(1);
xNIF char(10);

   	--solamente se generan notificaciones para los terceros que tengan todos los tramites
	--o especificamente el de vehiculos
	CURSOR CTerceros IS select NIF
                from TERCEROS
                where Expediente=xIDExpe and TRAMITE in ('T','8');
BEGIN

	SELECT EMI_NOTI_SUBA,NIF into xEmi,xNIF from EMBARGOS_AUTOS WHERE ID=xIDVehi;

	IF (xEmi='N') THEN

		--activar el detector para no poder hacerlo de nuevo
		update EMBARGOS_AUTOS set EMI_NOTI_SUBA='S' WHERE ID=xIDVehi;

		--notificacion de Subasta para el Deudor
		Add_Notificaciones_expe(xIDExpe,'807', xIDVehi, xNIF,'QQ');

		--insertar tantas como terceros del expediente
        FOR v_TERC IN CTerceros LOOP
	         Add_Notificaciones_expe(xIDExpe,'808', xIDVehi, v_TERC.NIF, 'TE');
      	END LOOP;

	END IF;
END;
/

/********************************************************************************************
Acción: Genera y registra la certificación de cargas de un embargo de Vehículos. 
        Esta certificación solo se crea una vez.

Parámetros: xIDExpe: ID del Expediente.
		xIDVehi: ID del Embargo de Vehículos.
		xFecha:  Fecha de Certificación de Cargas.

MODIFICACIÓN: 18/02/2002 M. Carmen Junco Gómez. Para comprobar si existía o no ya certificación
		  se estaba comparando el ID_EMBARGOS de la tabla de notificaciones con
		  el ID del tercero. 
		  07/03/2002 M. Carmen Junco Gómez. Añadir nota informativa en el seguimiento al
		  notificar certificación de cargas.
*********************************************************************************************/

CREATE OR REPLACE PROCEDURE NOTI_CARGAS_VEHI 
        (xIDExpe 	IN INTEGER,
         xIDVehi 	IN INTEGER,
	   xFecha	IN date)
AS
xNIF char(10);
xCUANTOS INTEGER;
xID INTEGER;
mFecha date;

   CURSOR EXPE_CUR IS
        SELECT NIF,ID FROM TERCEROS
        WHERE EXPEDIENTE=xIDEXPE and TRAMITE in ('T','8')
              AND RELACION IN ('03','04');

BEGIN

   -- A Estos Terceros tenemos que solicitarle el estado actual de cargas
   -- 03 son Acreedores Hipotecarios y 04 deudores por embargo
   -- Le enviamos el NIF del tercero pues puede haber mas de un Acreedor

   FOR v_EXPE IN EXPE_CUR LOOP
  
      xCUANTOS:=0;

      -- Comprobar que no se haya emitido aun la Certificación de Cargas
      SELECT COUNT(*) INTO xCUANTOS 
      FROM NOTIFICACIONES
      WHERE EXPEDIENTE=xIDEXPE
            AND ID_EMBARGOS=xIDVehi 
		AND NIF=v_EXPE.NIF
		AND TIPO_NOTI='805';

      IF (xCUANTOS = 0) THEN

         -- Para no tener que modificar los parámetros de la rutina 
         -- Add_Notificaciones_Expe se lo pasamos a la tabla de Usuarios
         UPDATE USUARIOS SET LAST_TAREA=v_EXPE.ID WHERE USUARIO=USER;

        Add_Notificaciones_Expe (xIDExpe, '805', xIDVehi, v_EXPE.NIF, 'TE');
      END IF;

   END LOOP;


   SELECT CERTIFICACION_CARGAS into mFecha from EMBARGOS_AUTOS WHERE ID=xIDVehi;

   if (mFecha is null) THEN
	update EMBARGOS_AUTOS set CERTIFICACION_CARGAS=xFecha WHERE ID=xIDVehi;
      PkSeguimiento.NotaInformativa(xIDExpe,
		'Emitida Notificación de situación actual de cargas. Fecha: '||
	      to_char(xFecha,'dd/mm/yyyy'));
   end if;

END;
/

--****************************************************************************************
--Acción: Anota una fecha en el embargo de vehiculos, dependiendo del 
--	parametro de entrada Quien.
--
--Parámetros: xIDVehi: ID del Embargo de Vehículos.
--		xImpo:   Importe de las cargas del embargo.
--		Quien:   Dependiento de su valor se realizará una acción u otra. 
--                   Quien=1 -> anota la fecha de anotación preventiva 
--					  (mandamiento al Registro Mercantil).
--                   Quien=2 -> anota el importe de cargas del embargo.
--                   Quien=3 -> anota la f. de petición de certificación para suplir titulos.
--                   Quien=4 -> anota la fecha de autorización de subasta del embargo.
--                   Quien=5 -> anota la fecha de subasta del embargo.
--		xFecha:  Fecha a utilizar en la anotación correspondiente.
--
-- Modificado: 18/03/2003 . Lucas Fernández Pérez.
-- Se añade la fecha de Petición de Certificación para suplir titulos a un vehículo
-- Modificado: 26/09/2003. Lucas Fernández Pérez.
-- Se añade la posibilidad de poner fecha de autorización de subasta y de subasta a NULL
-- *****************************************************************************************

CREATE OR REPLACE PROCEDURE PON_FECHAS_VEHI (
	xIdVehi	IN	INTEGER,
      xImpo		IN 	float,
      Quien 	IN	INTEGER,
	xFecha 	IN	DATE)

AS
xFechaSubasta DATE;
begin

   -- En los casos 4 y 5 (autorización de subasta y subasta) puede ponerse la fecha a null
   IF TRUNC(xFecha,'dd')='01/01/1901' THEN
	 xFechaSubasta:=NULL;
   ELSE
 	 xFechaSubasta:=xFecha;
   END IF;

   -- Fecha anotacion preventiva
   if Quien=1 then
      update embargos_Autos set MANDAMIENTO_REGIS='S', F_MANDAMIENTO=xFecha
      where Id=xIdVehi and F_MANDAMIENTO is null;
   end if; 

   -- Importe de cargas
   if Quien=2 then
      update embargos_Autos set importe_cargas=ROUND(xImpo,2) where Id=xIdVehi;
   end if;

   -- Fecha de petición de certificación para suplir titulos
   if Quien=3 then
      update embargos_Autos set F_SUPLIR_TITULOS=xFecha 
      where Id=xIdVehi and F_SUPLIR_TITULOS IS NULL;
   end if;

   -- Fecha de autorización de subasta
   if Quien=4 then
      update embargos_Autos set F_AUTORIZACION=xFechaSubasta where Id=xIdVehi;
   end if;
 
   -- Fecha de Subasta
   if Quien=5 then
      update embargos_Autos set F_SUBASTA=xFechaSubasta where Id=xIdVehi;
   end if;

end;
/

-- ****************************************************************************************
-- Autor: M. Carmen Junco Gomez.
-- Fecha: 26/02/2002
-- Acción: Para cada uno de los trámites sobre expedientes del lote que se pasa como parámetro,
--	  el procedimiento anota la fecha de Mandamiento al Registro Mercantil, o la fecha
-- 	  de petición de certificación para suplir títulos, segun el parámetro de entrada xQuien.

-- Parámetros: xZona:  Zona de Gestión;
-- 		xLote:  Número de Lote;
-- 		xFecha: Fecha a utilizar en la anotación correspondiente.
--		xQuien: '3' -> Mandamiento al Registro
--				'8' -> Petición de Certificación para suplir títulos
-- DELPHI
--
-- Modificado: 18/03/2003. Lucas Fernández Pérez. Se añade el parámetro xQuien para aceptar
--		llamada de petición de certificación para suplir títulos.
-- *****************************************************************************************

CREATE OR REPLACE PROCEDURE VEHI_FECHAS_MASIVAS (
		xZONA		IN	CHAR,
		xLOTE		IN	CHAR,		
		xFECHA		IN	DATE,
		xQUIEN		IN CHAR)
AS
   CURSOR CMANDAMIENTO IS SELECT E.ID
			        FROM EMBARGOS_AUTOS E, VWAUTOSEMBARGADOS A, EXPEDIENTES P 
				  WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					  E.F_DILIGENCIA IS NOT NULL AND E.MANDAMIENTO_REGIS='N' AND
					  E.ZONA=xZONA AND P.LOTE_8=xLOTE;			       

	CURSOR CSUPLIR_TITULOS IS SELECT DISTINCT E.ID
				FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.NOTI_EMBARGO='S' AND E.F_SUPLIR_TITULOS IS NULL AND 
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;	

BEGIN   

   IF xQUIEN='3' THEN
   	 -- Mandamiento al Registro Mercantil
   	 FOR v_AUTO IN CMANDAMIENTO LOOP
       		PON_FECHAS_VEHI(v_AUTO.ID,0,1,xFECHA);
   	 END LOOP;
   	 
   ELSIF xQUIEN='8' THEN
     
     FOR v_AUTO IN CSUPLIR_TITULOS LOOP
			PON_FECHAS_VEHI(v_AUTO.ID,0,3,xFECHA);
	 END LOOP;
  
   END IF;

END;
/

/******************************************************************************************
Acción: Grabar la fecha de anotacion del mandamiento a un Vehiculo.

Parámetros: xIDVehi: ID del Vehículo en la tabla de embargos_autos
		xFecha:  Fecha de Anotación del Mandamiento.

******************************************************************************************/

CREATE OR REPLACE PROCEDURE PutFechasVehiMandamiento(
		xIDVehi 	IN integer,
		xFecha  	IN Date)
AS
BEGIN

	update AUTOS_EMBARGADOS set fecha_embargo=xFecha
		where VEHI=xIDVehi;
END;
/


/*****************************************************************************************
Acción: Dependiendo del valor del parámetro xValoracion:
		xValoración='S' -> Graba la fecha de valoracion y el importe de un 
                               vehiculo embargado.
            xValoracion<>'S'-> Graba la fecha de valoracion contradictoria y el 
                               importe de un vehiculo embargado en un expediente.

Parámetros: xValoración: Dependiendo de su valor se realizará una u otra acción;
		xIDExpe: ID del Expediente;
		xIDVehi: ID del Embargo de Vehículos;
		xFecha:  Fecha de Valoración;
		xImpo:   Importe de la Valoración;
******************************************************************************************/

CREATE OR REPLACE PROCEDURE PutDatosVehiValoracion(
		xValoracion	IN char,
		xIDExpe 	IN integer,
		xIDVehi	IN integer,
		xFecha  	IN Date,
		xImpo   	IN float)
AS
BEGIN
	
	IF xValoracion='S' THEN  --fecha e importe de la valoracion municipal

	  update AUTOS_EMBARGADOS set F_VALORACION=xFecha,
						IMPORTE_VALO=ROUND(xImpo,2)
	  where VEHI=xIDVehi and IdExpe=xIDExpe;	

	ELSE --fecha e importe de la valoracion contradictoria

	  update AUTOS_EMBARGADOS set VALO_CONTRADICTORIA=xFecha,
						IMPORTE_VALO_CON=ROUND(xImpo,2)
	  where VEHI=xIDVehi and IdExpe=xIDExpe;

	END IF;

END;
/

/*****************************************************************************************
Acción: Anotar en el seguimiento la solicitud de captura y deposito del vehiculo.
        Tambien se utiliza para la solicitud de valoracion del vehiculo.

Parámetros: xIDExpe: ID del Expediente;
		xTexto: Texto a insertar en el seguimiento;
******************************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_SEGUIMIENTO_VEHI(
			xIDExpe IN INTEGER,
			xTexto IN CHAR)
AS
   xCuantos integer default 0;
BEGIN

   SELECT COUNT(*) INTO xCuantos 
   FROM SEGUIMIENTO
   WHERE ID_EXPE=xIDExpe AND
	   DEBE_O_HABER='I' AND
	   DESCRIPCION=xTexto;
	
   IF  xCuantos=0 THEN
	-- Anotarlo en el seguimiento
	PkSeguimiento.NotaInformativa(xIDExpe,xTexto);
   END IF;

END;
/

/*****************************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 26/02/2002
Acción: Hacer una anotación en el seguimiento para todos los expedientes de un lote.        

Parámetros: xZona:  Zona de Gestión;
		xLote:  Número de Lote;
		xQuien: Quien hace la petición:
			  '4': Captura, depósito y precinto;
		xTexto: Texto a insertar en el seguimiento;
******************************************************************************************/

CREATE OR REPLACE PROCEDURE VEHI_ANOTA_SEGUI_MASIVO(
		xZONA		IN	CHAR,
		xLOTE		IN	CHAR,
		xQUIEN	IN	INTEGER,
		xTEXTO	IN	VARCHAR2)
AS
   CURSOR CCAPTURA IS SELECT DISTINCT E.IDEXPE 
			    FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND					
					E.NOTI_EMBARGO='S' AND
					E.ZONA=xZONA AND P.LOTE_8=xLOTE AND
					E.ID NOT IN 
					(SELECT IDEMBARGOAUTO FROM VWAUTOSEMBARGADOS 
			         	   WHERE IDEMBARGOAUTO=E.ID AND FECHA_EMBARGO IS NULL);
BEGIN
   IF ((xQUIEN=4) OR (xQUIEN=5)) THEN
	FOR v_AUTO IN CCAPTURA 
	LOOP
	   PUT_SEGUIMIENTO_VEHI(v_AUTO.IDEXPE,xTEXTO);
	END LOOP;
   END IF;
END;
/

-- ****************************************************************************************
-- Autor: Antonio Pérez Caballero.
-- Fecha: 14/08/2001
-- Acción: Añadir o modificar un vehículo de nuestra Gestión Tributaria en la Recaudación.
--         Cada vez que demos de alta un vehículo nuevo en la gestión tributaria se dará 
--         de alta a su vez en la recaudación. Cuando modifiquemos a su vez se modificará 
--         en ambos sitios.
-- 
-- Parámetros: xADDMOD:    Indica si se está añadiendo o modificando el vehículo.
-- 		xABONADO:   Número de Abonado en la gestión del Impuesto en G. Tributaria.
-- 		xNIF:       Nif del Sujeto Pasivo.
-- 		xMATRICULA: Matrícula del Vehículo.
-- 		xMARCA:	Marca del vehículo.
-- 		xMODELO:	Modelo del vehículo.
-- Modificado: 27/06/2003. Lucas Fernández Pérez. En la modificación de la tabla VEHICULOS,
--	 también se actualiza en VEHICULOSR el NIF.
-- *******************************************************************************************

CREATE OR REPLACE PROCEDURE ADDMOD_VEHI_RECATRIBU(
		xADDMOD	IN CHAR,
		xABONADO   IN INTEGER,
	      xNIF       IN CHAR,
	      xMATRICULA IN CHAR,
		xMARCA     IN CHAR,
		xMODELO    IN CHAR)
AS
BEGIN

   IF (xADDMOD='A') THEN
	INSERT INTO VEHICULOSR(NIF,MARCA,MODELO,MATRICULA,ABONADO_VEHI)
	VALUES(xNIF,xMARCA,xMODELO,xMATRICULA,xABONADO);
   ELSE
	UPDATE VEHICULOSR SET NIF=xNIF,
						MATRICULA=xMATRICULA,
			          	MARCA=xMARCA,
                        MODELO=xMODELO
      WHERE ABONADO_VEHI=xABONADO;
   END IF;
END;
/

/*****************************************************************************************
Autor: M. Carmen Junco Gomez.
Fecha: 19/02/2002
Acción: Sacar un expediente de un lote al dejarlo sin vehículos

Parámetros: xIDExpe:    ID del Expediente.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE VEHI_SACAR_EXPE_LOTE(
		xIDExpe	IN	INTEGER)

AS
   xLOTE CHAR(8);   
BEGIN
	begin
         SELECT LOTE_8 INTO xLOTE FROM EXPEDIENTES WHERE ID=xIDExpe;
	Exception
	   When no_data_found then
		xLOTE:=NULL;
	end;
		
	if xLOTE IS NOT NULL then
	   UPDATE EXPEDIENTES SET LOTE_8=NULL WHERE ID=xIDExpe;
         PKSeguimiento.NotaInformativa(xIDExpe,'Se elimina el expediente del Lote: '||xLote||
		' por quedarse sin vehículos');	
	end if;

END;
/


/*****************************************************************************************
Autor: M. Carmen Junco Gomez.
Fecha: 19/02/2002
Accion: Rellena una tabla temporal para la impresión de notificaciones en el 
embargo de Vehiculos.


Parámetros: xZONA: 	 Zona de Gestión.
		xFECHA:      Fecha de actuación.
		xQUIEN = '1'->  DILIGENCIA DE EMBARGO
                     '2' -> NOTIFICACION AL DEUDOR Y TERCEROS
                     '3' -> MANDAMIENTO AL REGISTRADOR
                     '4' -> CAPTURA, DEPÓSITO Y PRECINTO
                     '5' -> DOCUMENTOS INTERNOS
                     '6' -> NOTIFICACION VALORACION MUNICIPAL
                     '7' -> SITUACION ACTUAL DE CARGAS INSCRITAS
                     '8' -> PETICIÓN DE CERTIFICACIÓN PARA SUPLIR TITULOS
			   		 '9' -> AUTORIZACION DE SUBASTA
                     '10' -> SUBASTA
		xLOTE:       Número de Lote.
		xLOTEENTERO: 'S': impresión del lote entero.
				 'N': impresión sólo parcial del lote.
				 
MODIFICACIÓN: 17/03/2003. Lucas Fernández Pérez. Para el tipo '6' se calcula la deuda para
              ponerla en los campos correspondientes de la tabla tmp_imp_vehiculos.
MODIFICACIÓN: 18/03/2003. Lucas Fernández Pérez. Nuevo tipo de impreso, (8).Se reajusta
	 		  el resto y se añade el relleno de las tablas para ese nuevo tipo              
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE IMPRIME_NOTI_VEHICULOS (
		xZONA		IN CHAR,
		xFECHA	IN DATE,
		xQUIEN	IN CHAR,
		xLOTE		IN CHAR,
		xLOTEENTERO IN CHAR)
AS

   xIDEXPE		INTEGER;
   xIDEMBARGO	INTEGER;
   xIDTERCERO	INTEGER;

   xAYUNTAMIENTO VARCHAR2(50);
   xNOMBRE		 VARCHAR2(80);
   xDIRECCION	 VARCHAR2(100);
   xPOBLACION	 VARCHAR2(50);
   xCIF	         CHAR(10);
   xPROVINCIA	 VARCHAR2(50);
   xTELEFONOS	 VARCHAR2(100);
   xRESPONSABLE	 VARCHAR2(50);
   xTESORERO	 VARCHAR2(50);
   xID_CUENTA	 INTEGER;
   xENTIDAD		 CHAR(4);
   xSUCURSAL	 CHAR(4);
   xDC		     CHAR(2);
   xCUENTA		 CHAR(10);
   xBANCO		 VARCHAR2(50);
   xPOSTALES_NIF VARCHAR2(80);
   xRELACION	 CHAR(10);

   xPrincipal	  FLOAT;
   xRecargo		  FLOAT;
   xSumaPrincipal FLOAT;
   xSumaRecargo	  FLOAT;
   xValoracion	  FLOAT;
   xNada1	      FLOAT;
   xNada2	      FLOAT;
   xNada3	      FLOAT; 
   xFECHAS		  VARCHAR2(2048);   

   -- Recorre todos los trámites sobre expedientes de un lote que tengan al menos 
   -- un vehiculo embargado.
   CURSOR CDILI IS SELECT DISTINCT E.ID,E.IDEXPE,E.AYTO,E.EXPEDIENTE,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.F_DILIGENCIA
			 FROM EMBARGOS_AUTOS E,AUTOS_EMBARGADOS A, EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=A.IDEXPE AND E.IDEXPE=P.ID AND
				E.ZONA=xZONA AND P.LOTE_8=xLOTE;

   -- Recorre todos los trámites sobre expedientes de un lote con diligencia de embargo emitida.
   CURSOR CAUTO IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.EMITIDA_NOTI
			 FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.F_DILIGENCIA IS NOT NULL AND 
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;

   -- Recorre todos los trámites sobre expedientes de un lote con diligencia de embargo emitida,
   -- pero generando una tupla por cada vehículo embargado
   CURSOR CAUTOSEMB IS SELECT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.NIF,
			 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.F_DILIGENCIA,E.F_MANDAMIENTO,E.COSTAS,E.INTERESES,
			 A.VEHI,A.MATRICULA,A.MARCA,A.MODELO
			 FROM EMBARGOS_AUTOS E, VWAUTOSEMBARGADOS A, EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.F_DILIGENCIA IS NOT NULL AND 
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;			    

   -- Recorre todos los trámites sobre expedientes de un lote con todas las 
   -- notificaciones recibidas
   CURSOR CNOTIFICADO IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.DEUDA_TOTAL,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.COSTAS, E.INTERESES, E.F_MANDAMIENTO, E.EMITIDA_CARGAS, E.VALORACION,
			 E.F_SUPLIR_TITULOS
			 FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.NOTI_EMBARGO='S' AND
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;

   -- Recorre todos los trámites sobre expedientes de un lote con todas las notificaciones
   -- recibidas y la anotación del mandamiento para cada uno de los vehículos embargados.
   CURSOR CMANDAMIENTO IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,
			 E.NIF,rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,
			 rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF, E.F_DILIGENCIA
			 FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND					
					E.NOTI_EMBARGO='S' AND
					E.ZONA=xZONA AND P.LOTE_8=xLOTE AND
					E.ID NOT IN 
					(SELECT IDEMBARGOAUTO FROM VWAUTOSEMBARGADOS 
			         	   WHERE IDEMBARGOAUTO=E.ID AND FECHA_EMBARGO IS NULL);
			
   -- Recorre todos los trámites sobre expedientes de un lote con los mandamientos y la 
   -- valoracion emitidos, y con la fecha de autorizacion de subasta puesta. 
   CURSOR CAUTORIZASUBASTA IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.DEUDA_TOTAL,
			 			 E.NIF,rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,
			 			 rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
					       E.F_AUTORIZACION,E.EMI_NOTI_SUBA,E.F_SUBASTA 
			 		FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A, EXPEDIENTES P 
					WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
						E.F_MANDAMIENTO IS NOT NULL AND
						E.VALORACION='S' AND
						E.F_AUTORIZACION IS NOT NULL AND
						E.ZONA=xZONA AND P.LOTE_8=xLOTE;

   -- Recorre todos los trámites sobre expedientes de un lote con los mandamientos y la 
   -- valoracion emitidos, y con la fecha de subasta puesta. 
   CURSOR CSUBASTA IS SELECT DISTINCT E.ID,E.IDEXPE,E.EXPEDIENTE,E.AYTO,E.DEUDA_TOTAL,E.NIF,
		 	 rtrim(GETNOMBRE(E.NIF)) AS NOMBRE_NIF,rtrim(GETDOMICILIO(E.NIF)) AS DOMI_NIF,
			 E.F_AUTORIZACION,E.F_SUBASTA,E.EMI_NOTI_SUBA,E.COSTAS,E.INTERESES
			 FROM EMBARGOS_AUTOS E, AUTOS_EMBARGADOS A,EXPEDIENTES P 
				WHERE E.ID=A.IDEMBARGOAUTO AND E.IDEXPE=P.ID AND
					E.F_MANDAMIENTO IS NOT NULL AND
					E.VALORACION='S' AND
					E.F_SUBASTA IS NOT NULL AND
					E.ZONA=xZONA AND P.LOTE_8=xLOTE;



   -- Recorre los valores de un expediente.
   CURSOR CVALORES IS SELECT V.ID, V.YEAR,  
		V.PADRON||'-'||V.YEAR||'-'||V.PERIODO||'-'||V.RECIBO||'   '||rtrim(C.DESCRIPCION)||
		'   '||rtrim(V.DOM_TRIBUTARIO) AS CONCEPTO,
		V.DOM_TRIBUTARIO, V.F_APREMIO, C.DESCRIPCION 
		FROM VALORES V, CONCEPTOS C WHERE 
		EXPEDIENTE=xIDEXPE AND ID_VEHICULOS=xIDEMBARGO AND C.CONCEPTO=V.PADRON
		AND V.F_INGRESO IS NULL AND V.F_SUSPENSION IS NULL AND V.FECHA_DE_BAJA IS NULL;

   CURSOR CTERCEROS IS SELECT 
		T.ID, T.NIF, NOMBRE AS NOMBRE_NIF, DOMICILIO AS DOMI_NIF, 
		CODIGO_POSTAL||' '||rtrim(POBLACION)||' '||rtrim(PROVINCIA) AS POSTALES_NIF, 
            T.RELACION, R.DESCRIPCION
		FROM TERCEROS T, vwDOMICONTRI C, TIPO_TERCERO R
		WHERE EXPEDIENTE=xIDEXPE AND T.NIF=C.NIF AND T.RELACION=R.RELACION
		AND TRAMITE IN('T','8');  

   CURSOR CEMBARGADOS IS SELECT V.MATRICULA,V.MARCA,V.MODELO,A.IMPORTE_VALO,
	    A.F_VALORACION	
	FROM VEHICULOSR V,AUTOS_EMBARGADOS A
	WHERE V.ID=A.VEHI AND A.IDEXPE=xIDEXPE AND A.IDEMBARGOAUTO=xIDEMBARGO
    	AND ( 
		xIDTERCERO=0
		OR 
		A.IDEXPE IN 
			(SELECT T.EXPEDIENTE FROM TERCEROS T 
				WHERE T.ID=xIDTERCERO AND
				     (T.VEHI_TODAS='S' OR T.ID  IN(
              			SELECT T2.ID FROM TERCEROS T2,AUTOS_TERCEROS M
			            WHERE M.TERCERO=T2.ID AND M.VEHI=A.VEHI)
				)
			)
		);


BEGIN

  -- --------------------------------------------------------------------------------------
  -- PARTE COMUN A TODAS LAS OPCIONES -----------------------------------------------------
  -- --------------------------------------------------------------------------------------
   DELETE FROM TMP_IMP_VEHICULOS WHERE USUARIO=UID;
   DELETE FROM TMP_IMP_VEHICULOS_DETALLE WHERE USUARIO=UID;
   DELETE FROM TMP_IMP_VEHICULOS_DETALLE2 WHERE USUARIO=UID;
 
   SELECT Z.AYUNTAMIENTO,Z.NOMBRE,Z.DIRECCION,Z.POBLACION,Z.PROVINCIA,
	Z.RESPONSABLE,Z.ID_CUENTA,Z.CIF,
	'Tel.'||Z.TELEFONO1||'-'||Z.TELEFONO2||',Fax:'||Z.FAX AS TELEFONOS
   INTO xAYUNTAMIENTO,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xRESPONSABLE,xID_CUENTA,xCIF,
	  xTELEFONOS
   FROM ZONAS Z, USUARIOS U 
   WHERE Z.ZONA=U.ZONA AND U.USUARIO=USER;   

   SELECT ENTIDAD,OFICINA,DC,CUENTA 
   INTO xENTIDAD,xSUCURSAL,xDC,xCUENTA
   FROM CUENTAS_SERVICIO
   WHERE ID=xID_CUENTA;

   SELECT NOMBRE INTO xBANCO
   FROM BANCOS
   WHERE ENTIDAD=xENTIDAD;

  -- --------------------------------------------------------------------------------------
  -- DILIGENCIA DE EMBARGO ----------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   IF xQUIEN='1' THEN  

      FOR v_dili IN CDILI -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente de emitir la diligencia.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_dili.F_DILIGENCIA IS NULL) THEN
	   	
		xPOSTALES_NIF:='';

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_dili.NIF;
		   exception
		      when no_data_found then
			   null;
	   	end;
		
		xIDEXPE:=v_dili.IDEXPE;
		xIDEMBARGO:=v_dili.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;

		-- Para cada valor del trámite sobre un expediente debo generar una tupla en la 
            -- tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		   INSERT INTO TMP_IMP_VEHICULOS_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES
			(xIDEXPE,xIDEMBARGO,v_Valor.YEAR,v_Valor.CONCEPTO,v_Valor.DOM_TRIBUTARIO,
			 v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;

         	INSERT INTO TMP_IMP_VEHICULOS(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,
		   TELEFONOS,IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
		   NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,ID_TERCERO,FECHA,RESPONSABLE,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_dili.IDEXPE,v_dili.EXPEDIENTE,v_dili.ID,v_dili.AYTO,
		   v_dili.NIF,v_dili.NOMBRE_NIF,
		   v_dili.DOMI_NIF,xPOSTALES_NIF,0,xFECHA,xRESPONSABLE,
		   xSumaPrincipal,xSumaRecargo,v_dili.COSTAS,v_dili.INTERESES,
		   xSumaPrincipal+xSumaRecargo+v_dili.COSTAS+v_dili.INTERESES);

	   END IF;

	   -- Genero los vehículos embargados del deudor
	   xIDTercero:=0;
	   FOR v_embargados IN CEMBARGADOS LOOP
		INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
			 MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			  v_embargados.MARCA,v_embargados.MODELO,			
		 	  v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	   END LOOP;

	END LOOP; -- CDILI

  -- --------------------------------------------------------------------------------------
  -- EMISION DE NOTIFICACIONES AL DEUDOR Y A LOS TERCEROS ---------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='2' THEN  

      FOR v_AUTO IN CAUTO -- Recorre todos los expedientes
	LOOP
	   -- Genera una tupla si se ha solicitado todo el lote o si solicitandose solo 
	   -- lo pendiente del lote, el expediente esta pendiente de notificar.
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_AUTO.EMITIDA_NOTI='N') THEN
	   	
		xPOSTALES_NIF:='';

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_AUTO.NIF;
		   exception
		      when no_data_found then
			   null;
	   	end;

		SELECT MAX(N_RELACION) INTO xRELACION FROM NOTIFICACIONES
		WHERE EXPEDIENTE=v_AUTO.IDEXPE;
		
		xIDEXPE:=v_AUTO.IDEXPE;
		xIDEMBARGO:=v_AUTO.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;

		-- Para cada valor del trámite sobre un expediente debo generar una tupla en la 
            -- tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		   INSERT INTO TMP_IMP_VEHICULOS_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES
			(xIDEXPE,xIDEMBARGO,v_Valor.YEAR,v_Valor.CONCEPTO,
			 v_Valor.DOM_TRIBUTARIO,v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;

         	INSERT INTO TMP_IMP_VEHICULOS(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,
		   TELEFONOS,IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
		   NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,FECHA,RESPONSABLE,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
		   ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,POSTALES_TERCERO,N_RELACION)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,v_AUTO.NOMBRE_NIF,
		   v_AUTO.DOMI_NIF,xPOSTALES_NIF,xFECHA,xRESPONSABLE,
		   xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,
		   xSumaPrincipal+xSumaRecargo+v_AUTO.COSTAS+v_AUTO.INTERESES,
		   0,v_AUTO.NIF,v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,xRELACION);

		-- Genero los vehículos embargados del deudor
		xIDTercero:=0;
		FOR v_embargados IN CEMBARGADOS LOOP
			INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				 MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
				  v_embargados.MARCA,v_embargados.MODELO,			
			 	  v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
		END LOOP;


		-- Para cada tercero genero una nueva tupla en la tabla principal igual que la 
		-- del deudor salvo que tendrá como datos personales los datos 
		-- del tercero. Se rellena el campo ENCALIDADDE
		FOR v_Terc IN CTERCEROS LOOP
         	   INSERT INTO TMP_IMP_VEHICULOS(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,
			PROVINCIA,TELEFONOS,IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,
			NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,FECHA,RESPONSABLE,
		   	PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
			ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,POSTALES_TERCERO,
			ENCALIDADDE,N_RELACION)
	   	   VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   	v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
			v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,xFECHA,xRESPONSABLE,
		   	xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,
		   	xSumaPrincipal+xSumaRecargo+v_AUTO.COSTAS+v_AUTO.INTERESES,
			v_Terc.ID,v_TERC.NIF,v_TERC.NOMBRE_NIF,v_TERC.DOMI_NIF,v_TERC.POSTALES_NIF,
			v_TERC.DESCRIPCION,xRELACION);

		   -- insertamos para cada tercero los vehículos embargados asociados a él.
		   xIDTercero:=v_Terc.ID;
		   FOR v_embargados IN CEMBARGADOS LOOP
			INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				 MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
			VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
				  v_embargados.MARCA,v_embargados.MODELO,			
			 	  v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
		   END LOOP; 

		END LOOP;

	   END IF;

	END LOOP; -- CAUTO

  -- --------------------------------------------------------------------------------------
  -- MANDAMIENTOS AL REGISTRO MERCANTIL ---------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='3' THEN  

      FOR v_AUTO IN CAUTOSEMB -- Recorre todos los vehículos embargados de todos los trámites
					-- sobre expedientes
	LOOP
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_AUTO.F_MANDAMIENTO IS NULL) THEN	   	

		xPOSTALES_NIF:='';

	   	begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_AUTO.NIF;
		   exception
		      when no_data_found then
			   null;
	   	end;
		
		xIDEXPE:=v_AUTO.IDEXPE;
		xIDEMBARGO:=v_AUTO.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;
		xFechas:='';

		-- Para cada valor del trámite sobre un expediente debo generar una tupla en la 
            -- tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;
		   xFechas:=xFechas||TO_CHAR(v_Valor.F_APREMIO,'dd-mm-yyyy')||',';

		   INSERT INTO TMP_IMP_VEHICULOS_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE,VEHI)
		   VALUES
			(xIDEXPE, xIDEMBARGO, v_Valor.YEAR,v_Valor.CONCEPTO,
			 v_Valor.DOM_TRIBUTARIO,v_Valor.DESCRIPCION,xPrincipal,v_AUTO.VEHI);

		END LOOP;


		-- una tupla por cada vehículo embargado de cada trámite sobre un expediente
     	      INSERT INTO TMP_IMP_VEHICULOS(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,
			PROVINCIA,TELEFONOS,IDEXPE,EXPEDIENTE,IDEMBARGO, AYTO,
			NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,FECHA,RESPONSABLE,
		   	PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL,
			FECHAS_APREMIO,VEHI,MATRICULA,MARCA,MODELO)
	   	   VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   	v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
			v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,v_AUTO.F_DILIGENCIA,
			xRESPONSABLE,
		   	xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,
		   	xSumaPrincipal+xSumaRecargo+v_AUTO.COSTAS+v_AUTO.INTERESES,
			xFechas,v_AUTO.VEHI,v_AUTO.MATRICULA,v_AUTO.MARCA,v_AUTO.MODELO);		

	   END IF;

	END LOOP; -- CAUTOSEMB

  -- --------------------------------------------------------------------------------------
  -- CAPTURA, DEPOSITO Y PRECINTO
  -- --------------------------------------------------------------------------------------

   ELSIF (xQUIEN='4') THEN
   
      FOR v_AUTO IN CMANDAMIENTO
	LOOP

	   xPOSTALES_NIF:='';

	   begin
	      select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	      into xPOSTALES_NIF	
		from contribuyentes where nif=v_AUTO.NIF;
		exception
		   when no_data_found then
			null;
	   end;	   
	
	   INSERT INTO TMP_IMP_VEHICULOS
	   	(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,RESPONSABLE,
		 IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,
		 ID_TERCERO,FECHA)
	   VALUES 
		(xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		 xRESPONSABLE,v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
		 v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,0,v_AUTO.F_DILIGENCIA);

	   -- Genero los vehículos embargados del deudor
	   xIDEXPE:=v_AUTO.IDEXPE;
	   xIDEMBARGO:=v_AUTO.ID;
	   xIDTercero:=0;
	   FOR v_embargados IN CEMBARGADOS LOOP		 
		 INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				 MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		 VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			   v_embargados.MARCA,v_embargados.MODELO,			
			   v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	   END LOOP;

	END LOOP; -- CMANDAMIENTO

  -- --------------------------------------------------------------------------------------
  -- DOCUM.INTERNOS O NOTIFICACION VALORACION MUNICIPAL O PET.CERTIF.PARA SUPLIR TITULOS.
  -- --------------------------------------------------------------------------------------

   ELSIF (xQUIEN='5') OR (xQUIEN='6') THEN

      FOR v_AUTO IN CNOTIFICADO -- Recorre todos los trámites sobre expedientes notificados
	LOOP	   

	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_AUTO.VALORACION='N') THEN

	      xPOSTALES_NIF:='';

	      begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_AUTO.NIF;
		   exception
		      when no_data_found then
			   null;
	      end;

		SELECT SUM(IMPORTE_VALO) INTO xValoracion 
		FROM AUTOS_EMBARGADOS 
		WHERE IDEXPE=v_AUTO.IDEXPE AND IDEMBARGOAUTO=v_AUTO.ID;

		SELECT MAX(N_RELACION) INTO xRELACION FROM NOTIFICACIONES
		WHERE EXPEDIENTE=v_AUTO.IDEXPE;

		-- Calculo el importe de la deuda con ppal,recargo,y costas e interes a resultas
		xIDEXPE:=v_AUTO.IDEXPE;
		xIDEMBARGO:=v_AUTO.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;
		FOR v_valor IN CVALORES LOOP
		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;
		END LOOP;

				
		INSERT INTO TMP_IMP_VEHICULOS
		  (AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,RESPONSABLE,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,ID_TERCERO,
		   N_RELACION,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   xRESPONSABLE,v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
		   v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,0,xRELACION,
		   xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,xVALORACION);

		-- Genero los vehículos embargados del deudor
	      xIDEXPE:=v_AUTO.IDEXPE;
	      xIDEMBARGO:=v_AUTO.ID;
	      xIDTercero:=0;
	      FOR v_embargados IN CEMBARGADOS LOOP		 
		    INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				 MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		    VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			   v_embargados.MARCA,v_embargados.MODELO,			
			   v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	      END LOOP;

	   END IF;

	END LOOP; -- CNOTIFICADO

  -- --------------------------------------------------------------------------------------
  -- SITUACION ACTUAL DE CARGAS INSCRITAS -------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='7' THEN  

      FOR v_AUTO IN CNOTIFICADO
	LOOP

	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_AUTO.EMITIDA_CARGAS='N') THEN

	      xPOSTALES_NIF:='';

	      begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_AUTO.NIF;
		   exception
		      when no_data_found then
			   null;
	      end;

		xIDEXPE:=v_AUTO.IDEXPE;
            xIDEMBARGO:=v_AUTO.ID;

		FOR v_Terc IN CTERCEROS LOOP
		   IF v_TERC.RELACION IN ('03','04') THEN

         	      INSERT INTO TMP_IMP_VEHICULOS
		         (AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,
			    RESPONSABLE,IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,
			    POSTALES_NIF,TOTAL,ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,
			    POSTALES_TERCERO)
	   	      VALUES 
                     (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		          xRESPONSABLE,v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,
			    v_AUTO.NIF,v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,
			    v_AUTO.DEUDA_TOTAL,v_TERC.ID,v_TERC.NIF,v_TERC.NOMBRE_NIF,
			    v_TERC.DOMI_NIF,v_TERC.POSTALES_NIF);

			-- Genero los vehículos embargados asociados con el tercero	   
	   		xIDTercero:=v_Terc.ID;
	   		FOR v_embargados IN CEMBARGADOS LOOP		 
		 	   INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		 	   VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			      v_embargados.MARCA,v_embargados.MODELO,			
			      v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	   		END LOOP;

		   END IF;
		END LOOP;       	

	   END IF;

	END LOOP; -- CNOTIFICADO

  -- --------------------------------------------------------------------------------------
  -- PETICION DE CERTIFICACION PARA SUPLIR TITULOS ----------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='8' THEN

      FOR v_AUTO IN CNOTIFICADO -- Recorre todos los trámites sobre expedientes notificados
	LOOP	   

	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_AUTO.F_SUPLIR_TITULOS IS NULL) THEN

	      xPOSTALES_NIF:='';

	      begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_AUTO.NIF;
		   exception
		      when no_data_found then
			   null;
	      end;

		SELECT SUM(IMPORTE_VALO) INTO xValoracion 
		FROM AUTOS_EMBARGADOS 
		WHERE IDEXPE=v_AUTO.IDEXPE AND IDEMBARGOAUTO=v_AUTO.ID;

		SELECT MAX(N_RELACION) INTO xRELACION FROM NOTIFICACIONES
		WHERE EXPEDIENTE=v_AUTO.IDEXPE;

		-- Calculo el importe de la deuda con ppal,recargo,y costas e interes a resultas
		xIDEXPE:=v_AUTO.IDEXPE;
		xIDEMBARGO:=v_AUTO.ID;
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;
		FOR v_valor IN CVALORES LOOP
		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;
		END LOOP;

				
		INSERT INTO TMP_IMP_VEHICULOS
		  (AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,RESPONSABLE,
		   IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,ID_TERCERO,
		   N_RELACION,
		   PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		   xRESPONSABLE,v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
		   v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,0,xRELACION,
		   xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,xVALORACION);

		-- Genero los vehículos embargados del deudor
	      xIDEXPE:=v_AUTO.IDEXPE;
	      xIDEMBARGO:=v_AUTO.ID;
	      xIDTercero:=0;
	      FOR v_embargados IN CEMBARGADOS LOOP		 
		    INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				 MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		    VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			   v_embargados.MARCA,v_embargados.MODELO,			
			   v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	      END LOOP;

	   END IF;

	END LOOP; -- CNOTIFICADO
  -- --------------------------------------------------------------------------------------
  -- AUTORIZACION DE SUBASTA --------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='9' THEN  

      FOR v_AUTO IN CAUTORIZASUBASTA -- Recorre todos los expedientes
	LOOP 
         -- Obtengo el nombre del tesorero del ayuntamiento.
         begin
	      SELECT TESORERO INTO xTESORERO FROM MUNICIPIOS WHERE AYTO=v_AUTO.AYTO;  
		exception
		   When no_data_found then
		      xTESORERO:='';
	   end;
	   
         INSERT INTO TMP_IMP_VEHICULOS
		(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,RESPONSABLE,
		 TESORERO,IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,F_SUBASTA)
	   VALUES 
		(xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		 xRESPONSABLE,xTESORERO,v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,
		 v_AUTO.NIF,v_AUTO.NOMBRE_NIF,v_AUTO.F_SUBASTA);

      END LOOP; -- CAUTORIZASUBASTA

  -- --------------------------------------------------------------------------------------
  -- SUBASTA ------------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------
   ELSIF xQUIEN='10' THEN  

      FOR v_AUTO IN CSUBASTA -- Recorre todos los expedientes
	LOOP
	   IF xLOTEENTERO='S' OR (xLOTEENTERO='N' AND v_AUTO.EMI_NOTI_SUBA='N') THEN

		xPOSTALES_NIF:='';		

	      begin
	         select ltrim(rtrim(CODIGO_POSTAL||' '||POBLACION||' '||PROVINCIA)) 
	         into xPOSTALES_NIF	
		   from contribuyentes where nif=v_AUTO.NIF;
		   exception
		      when no_data_found then
			   null;
	      end;	

		xIDEXPE:=v_AUTO.IDEXPE;
		xIDEMBARGO:=v_AUTO.ID;	
		xSumaPrincipal:=0;
   		xSumaRecargo:=0;

		-- Para cada valor del trámite sobre un expediente debo generar una tupla en la 
            -- tabla de detalle
		FOR v_valor IN CVALORES LOOP

		   PkIngresos.GET_Pendiente(v_Valor.ID,xPrincipal,xRecargo,xNada1,xNada2,xNada3);
		   xSumaPrincipal:=xSumaPrincipal+xPrincipal;
		   xSumaRecargo:=xSumaRecargo+xRecargo;

		   INSERT INTO TMP_IMP_VEHICULOS_DETALLE
			(IDEXPE, IDEMBARGO, YEAR,CONCEPTO,DOM_TRIBUTARIO,DESCRIPCION,IMPORTE)
		   VALUES
			(xIDEXPE,xIDEMBARGO,v_Valor.YEAR,v_Valor.CONCEPTO,v_Valor.DOM_TRIBUTARIO,
			 v_Valor.DESCRIPCION,xPrincipal);

		END LOOP;

		SELECT MAX(N_RELACION) INTO xRELACION FROM NOTIFICACIONES
		WHERE EXPEDIENTE=v_AUTO.IDEXPE;

		-- para el deudor
		INSERT INTO TMP_IMP_VEHICULOS
		   (AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,
		    IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,
		    N_RELACION,FECHA,F_SUBASTA,ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,DOMI_TERCERO,
		    POSTALES_TERCERO,RESPONSABLE,
		    PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL)
	   	VALUES (xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		    v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
		    v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,xRELACION,
		    v_AUTO.F_AUTORIZACION,v_AUTO.F_SUBASTA,0,v_AUTO.NIF,v_AUTO.NOMBRE_NIF,
		    v_AUTO.DOMI_NIF,xPOSTALES_NIF,xRESPONSABLE,
		    xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,
		    xSumaPrincipal+xSumaRecargo+v_AUTO.COSTAS+v_AUTO.INTERESES);

		-- Genero los vehículos embargados para el propietario
	   	xIDTercero:=0;
	   	FOR v_embargados IN CEMBARGADOS LOOP		 
		 	INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
				MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		 	VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			      v_embargados.MARCA,v_embargados.MODELO,			
			      v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	   	END LOOP;

		-- Para cada tercero genero una nueva tupla en la tabla principal igual que la 
		-- del deudor 
		FOR v_Terc IN CTERCEROS LOOP
		   INSERT INTO TMP_IMP_VEHICULOS
			(AYUNTAMIENTO,CIF,NOMBRE,DIRECCION,POBLACION,PROVINCIA,TELEFONOS,
		       IDEXPE,EXPEDIENTE,IDEMBARGO,AYTO,NIF,NOMBRE_NIF,DOMI_NIF,POSTALES_NIF,
		       N_RELACION,FECHA,F_SUBASTA,ID_TERCERO,NIF_TERCERO,NOMBRE_TERCERO,
			 DOMI_TERCERO,POSTALES_TERCERO,RESPONSABLE,
			 PRINCIPAL,RECARGO,COSTAS_RESULTAS,INTERES_RESULTAS,TOTAL)
	   	   VALUES 
			(xAYUNTAMIENTO,xCIF,xNOMBRE,xDIRECCION,xPOBLACION,xPROVINCIA,xTELEFONOS,
		       v_AUTO.IDEXPE,v_AUTO.EXPEDIENTE,v_AUTO.ID,v_AUTO.AYTO,v_AUTO.NIF,
		       v_AUTO.NOMBRE_NIF,v_AUTO.DOMI_NIF,xPOSTALES_NIF,xRELACION,
		       v_AUTO.F_AUTORIZACION,v_AUTO.F_SUBASTA,v_TERC.ID,v_TERC.NIF,
			 v_TERC.NOMBRE_NIF,v_TERC.DOMI_NIF,v_TERC.POSTALES_NIF,xRESPONSABLE,
			 xSumaPrincipal,xSumaRecargo,v_AUTO.COSTAS,v_AUTO.INTERESES,
		       xSumaPrincipal+xSumaRecargo+v_AUTO.COSTAS+v_AUTO.INTERESES);

		   -- Genero los vehículos embargados asociados con el tercero	   
	   	   xIDTercero:=v_Terc.ID;
	   	   FOR v_embargados IN CEMBARGADOS LOOP		 
		 	 INSERT INTO TMP_IMP_VEHICULOS_DETALLE2(IDEMBARGO,ID_TERCERO,MATRICULA,
			      MARCA,MODELO,IMPORTE_VALO,F_VALORACION) 
		 	 VALUES (xIDEMBARGO,xIDTERCERO,v_embargados.MATRICULA,
			      v_embargados.MARCA,v_embargados.MODELO,			
			      v_embargados.IMPORTE_VALO,v_embargados.F_VALORACION);
	   	   END LOOP;

		END LOOP;

	   END IF;

	END LOOP; -- CSUBASTA

   END IF;   

END;
/


/*********************************************************************/
COMMIT;
/********************************************************************/