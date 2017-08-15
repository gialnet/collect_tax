--
-- Cierra el expediente y pone todas sus variables en estado neutro.
-- xTipoIngreso VE=ventanilla 
--
CREATE OR REPLACE PROCEDURE CerrarExpediente(
	xIDExpe In INT,
	xTipoIngreso IN Char)
AS
BEGIN

-- TRIGGER PAGA_EXPEDIENTE, se encarga de poner los estados correspondientes

UPDATE EXPEDIENTES SET 
		F_INGRESO=SYSDATE,
		CODIGO_INGRESO=xTipoIngreso
      WHERE ID=xIDExpe;

PkSeguimiento.NotaInformativa(xIDExpe, 'Se cierra el expediente');

END;
/

--
-- Levantar sólo un embargo de bienes inmuebles.
-- Si no hay mandamiento de anotación preventiva se borra sin más
-- en caso contrario se pone como para emitir la diligencia de levantamiento
-- al registro de la propiedad
--
CREATE OR REPLACE PROCEDURE LEVANTA_UN_INMUEBLE(xIDEmbargo IN INTEGER, xFechaManda IN DATE)
AS
BEGIN

	IF xFechaManda IS NULL THEN

		UPDATE VALORES SET ID_INMUEBLES=NULL,EN_INMUEBLES='N' 
			WHERE ID_INMUEBLES=xIDEmbargo;

		DELETE FROM FINCAS_EMBARGADAS WHERE IDEMBINMU=xIDEmbargo;

		DELETE FROM EMBARGOS_INMUEBLES WHERE ID=xIDEmbargo;

	ELSE

		-- Otro procedimiento lo borra definitivo trás la impresión

		UPDATE EMBARGOS_INMUEBLES SET QUITAR_EMBARGO='S' WHERE ID=xIDEmbargo;

	END IF;

END;
/



/*****************************************************************************************/
-- Realiza el levantamiento de un embargo de inmuebles (intenta eliminar el embargo).
-- 1. Si el embargo esta pendiente, solo hay que dejar al expediente sin tramites.
-- 2. Si no se ha emitido el mandamiento del embargo, se elimina el embargo,
--    y se deja al expediente sin trámites.
-- 3. En el caso de que se hubiese emitido el mandamiento, el embargo se pone
--    en estado de quitar_embargo, y el expediente en estado 'L', para permitir hacer el
--    levantamiento y depues eliminarlo. El borrado definitivo del embargo en este caso 
--    lo hará el procedimiento BORRA_LEVANTA_INMU

CREATE OR REPLACE PROCEDURE LEVANTA_INMUEBLES(xIDEXPE IN INTEGER)
AS

xCuantos INT;
xEmbargo CHAR(1);
xEsta_Embargo CHAR(1);

-- Todos los embargos de un expediente, puede haber más de uno con el tema de la afección
-- también en caso de una entidad supramunicipal habría tantos como aytos distintos.
CURSOR cEmbExpe IS 
	SELECT ID,F_MANDAMIENTO FROM EMBARGOS_INMUEBLES 
		WHERE IDEXPE=xIDEXPE;
BEGIN

   xCuantos:=0;

   FOR v_cEmbExpe IN cEmbExpe LOOP

	IF v_cEmbExpe.F_MANDAMIENTO IS NOT NULL THEN

		xCuantos:=xCuantos+1;

	END IF;

	LEVANTA_UN_INMUEBLE(v_cEmbExpe.ID ,v_cEmbExpe.F_MANDAMIENTO);

   END LOOP;

   SELECT EMBARGO,ESTA_EMBARGO INTO xEmbargo,xEsta_Embargo FROM EXPEDIENTES WHERE ID=xIDExpe;

   -- Que no haya ningún mandamiento o esta en el pendiente del embargo
   IF xCuantos = 0 THEN

	-- El expediente puede estar en inmuebles o en CUENTAS CORRIENTES. 
	-- Si está en el ABIERTO de embargo de Inmuebles, se elimina del embargo.
	-- Si NO está en el ABIERTO de embargo de Inmuebles, se deja en el estado que esté.
	-- Si está en embargo de Cuentas Corrientes,sigue alli,y se indica en_otrotramite='N'

	IF (xEmbargo='4') AND (xEsta_Embargo='O') THEN                                     

	   PKSeguimiento.NotaInformativa(xIDEXPE,
		'Se elimina del embargo de inmuebles. Expediente sin trámites');
		
	   UPDATE EXPEDIENTES SET EMBARGO='0',
			ESTA_EMBARGO='C',
			F_EMBARGO=SYSDATE,
			EN_OTROTRAMITE='N',
			FECHA_DILIGENCIA=NULL
	   WHERE ID=xIDEXPE;
	ELSIF xEmbargo<>'4' THEN -- Esta en cuentas corrientes, se deja allí
         PKSeguimiento.NotaInformativa(xIDEXPE,'El expediente no tiene embargo de inmuebles. Está en tramite '||xEmbargo);	
	   UPDATE EXPEDIENTES SET EN_OTROTRAMITE='N' WHERE ID=xIdExpe;	
	ELSE
	   PKSeguimiento.NotaInformativa(xIDEXPE,'Se eliminan los embargos abiertos de inmuebles. Hay más embargos de inmuebles.');	
	END IF;

   ELSE
	-- Al levantar levanto todos los embargos, y si el exped.estaba en 4P pasa a 4L
	IF xEmbargo='4' THEN                                     
	   PKSeguimiento.NotaInformativa(xIDEXPE,'Levantamiento del embargo de inmuebles');
  	   -- Que haya algún mandamiento emitido y anotado
	   UPDATE EXPEDIENTES SET ESTA_EMBARGO='L',F_EMBARGO=SYSDATE
	   WHERE ID=xIDEXPE;

	ELSE -- Esta en cuentas corrientes, se deja allí
         PKSeguimiento.NotaInformativa(xIDEXPE,'Levantamiento del embargo de inmuebles. El expediente está en tramite '||xEmbargo);	
	END IF;

   END IF;

END;
/

/***************************************************************************************
Acción: Levantamiento parcial de cuentas. Puede levantar totalmente alguna cuenta/s
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez.
***************************************************************************************/
-- Modificado: 24/12/2003. Lucas Fernández Pérez.
--	Si la cuenta a levantar tiene un levantamiento hecho el mismo día y sin enviar a fase 5,
--	actualiza los datos de ese levantamiento. En cualquier otro caso, crea un nuevo registro
--	de levantamiento.

CREATE OR REPLACE PROCEDURE LEVANTA_PARCIAL_CUENTAS(
			xIDExpe IN INTEGER, 
			xDeMasCobrado IN FLOAT)
AS
	xID INT;
	xTexto VARCHAR(150);
	xCuanto FLOAT;
	xtmpMasCobrado FLOAT DEFAULT 0;	
	xNIF CHAR(10);
	xZONA CHAR(2);
	xLOTE CHAR(10);
	xEntidad CHAR(4);
	xOficina CHAR(4);	
	xPuedoUpdate CHAR(1);
	xInsertar CHAR(1);

	CURSOR cDiligen IS
		   SELECT ID,DEUDA_A_EMBARGAR,FECHA_RETENCION,IMPORTE_RETENIDO,
		   		  ENTIDAD,OFICINA,DC,CUENTA,ZONA,LOTE,F_DILIGENCIA
		   FROM CUENTAS_LOTES
		   WHERE IdEXPE=xIDEXPE 
				 AND DILIGENCIA='S' 
				 AND HECHO='N'
				 AND IMPORTE_RETENIDO > 0
		   ORDER BY FECHA_RETENCION DESC;	

BEGIN

	xtmpMasCobrado:=xDeMasCobrado;

	-- Recorrer las diligencias con retenciones sin aplicar en orden inverso 
	-- de fecha de retención, e ir restando el importe ingresado de más hasta 
	-- cubrir las retenciones.
	-- Anotar en el seguimiento del expediente

   	-- COMPROBAR SI HAY UNA TUPLA DE ESTE EXPEDIENTE EN EL LEVANTAMIENTO PARA LA FECHA
   	-- DE ENTRADA (SYSDATE) Y SIN ENVIAR EN DISCO FASE5
   	BEGIN
      	SELECT ID INTO xID FROM NEXT_LEVANTA_CUENTAS
		WHERE IDEXPE=xIDexpe AND TRUNC(F_ENTRADA)=TRUNC(SYSDATE) AND
			  F_ENVIO_FASE5 IS NULL;
		xPuedoUpdate:='S';

      	EXCEPTION
      		WHEN NO_DATA_FOUND THEN
      		BEGIN
      			SELECT NIF,ZONA,LOTE INTO xNIF,xZONA,xLOTE
      			FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDexpe;
         		INSERT INTO NEXT_LEVANTA_CUENTAS
          			(IDEXPE,NIF,ZONA,LOTE)
          		VALUES (xIDEXPE,xNIF,xZONA,xLOTE)	   			
          		RETURNING ID INTO xID;
				xPuedoUpdate:='N';
          	END;
   	END;


	FOR v_cDiligen IN cDiligen LOOP

		IF xtmpMasCobrado >= v_cDiligen.IMPORTE_RETENIDO THEN

			-- Ponemos el campo de la nueva retencion a cero pues hay que devolverlo todo
			xCuanto:=0;

			xTexto:='Se levanta embargo, en un levantamiento parcial '|| 
					v_cDiligen.Entidad ||'-'||v_cDiligen.Oficina||'-'|| 
					v_cDiligen.DC||'-'||v_cDiligen.Cuenta|| 
					' importe retenido: '||to_char(v_cDiligen.IMPORTE_RETENIDO)||
					' nuevo importe: 0';
					
		    -- borramos la cuenta y comprobamos el estado del embargo		    		    
		    DELETE FROM CUENTAS_LOTES WHERE ID=v_cDiligen.ID;   			
   			
    		CUENTAS_CONTROL_ESTADOS(xIDEXPE,v_cDiligen.Entidad,v_cDiligen.Oficina,
    					v_cDiligen.ZONA,v_cDiligen.LOTE,v_cDiligen.F_DILIGENCIA);		    
   	
			-- Descontamos lo devuelto
			xtmpMasCobrado:=xtmpMasCobrado - v_cDiligen.IMPORTE_RETENIDO;

		ELSE

			-- Es suficiente con parte de esta retención

			xTexto:='Se levanta embargo, en un levantamiento parcial '|| 
			        v_cDiligen.Entidad||'-'||v_cDiligen.Oficina||'-'|| 
			        v_cDiligen.DC||'-'||v_cDiligen.Cuenta|| 
					' importe retenido: '||to_char(v_cDiligen.IMPORTE_RETENIDO)||
					' nuevo importe: '|| 
					To_char(v_cDiligen.IMPORTE_RETENIDO - xtmpMasCobrado);

			-- pondremos en el campo de la nueva retencion el importe ingresado de más
			xCuanto:=v_cDiligen.IMPORTE_RETENIDO - xtmpMasCobrado;

			-- Descontamos lo devuelto
			xtmpMasCobrado:=0;

		END IF;	
		
			
		if xPuedoUpdate='S' then
		  xInsertar:='N';
		  UPDATE CUENTAS_A_LEVANTAR SET NUEVARETEN=xCuanto
		  WHERE ID=xID AND IDEXPE=xIDExpe AND ENTIDAD=v_cDiligen.Entidad
				AND OFICINA=v_cDiligen.Oficina AND DC=v_cDiligen.DC 
				AND CUENTA=v_cDiligen.Cuenta;
		  if SQL%NOTFOUND then
		  	xInsertar:='S';
		  end if;
		else 
			xInsertar:='S';
		end if;

		if xInsertar='S' then
		-- Insertar la cuenta en cuentas a levantar
   			INSERT INTO CUENTAS_A_LEVANTAR
       			(ID,IDEXPE,ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,RETENIDO,
       		 	F_RETENCION,NUEVARETEN)
   			VALUES  
       			(xID,xIDExpe,v_cDiligen.Entidad,v_cDiligen.Oficina,v_cDiligen.DC,
       		 	v_cDiligen.Cuenta,v_cDiligen.DEUDA_A_EMBARGAR,     
			 	v_cDiligen.IMPORTE_RETENIDO,v_cDiligen.FECHA_RETENCION,xCuanto);
		end if;

		-- anotar en el seguimiento del expediente
		PkSeguimiento.NotaInformativa(xIDExpe, xTexto, v_cDiligen.ID);

		if xtmpMasCobrado=0 then
			return;
		end if;

	END LOOP;

END;
/

/****************************************************************************************
Acción: Para poder realizar la diligencia de levantamiento de una cuenta.
        Borra la cuenta de CUENTAS_LOTES, lo anota en NEXT_LEVANTA_CUENTAS y en 
        CUENTAS_A_LEVANTAR; si es la última cuenta del expediente con diligencia 
        modifica EMBARGOS_CUENTAS y EXPEDIENTES, y por último descuenta de 
        DILIGENCIAS_CUENTAS.
 	    Lo anota en el seguimiento del expediente
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez.
****************************************************************************************/
-- Modificado: 24/12/2003. Lucas Fernández Pérez.
--	Si la cuenta a levantar tiene un levantamiento hecho el mismo día y sin enviar a fase 5,
--	actualiza los datos de ese levantamiento. En cualquier otro caso, crea un nuevo registro
--	de levantamiento.

CREATE OR REPLACE PROCEDURE LEVANTA_UNA_CUENTA(
      xIDEXPE 	IN	INT,
      xNIF	 	IN	CHAR,
      xEntidad 	IN	CHAR,
      xOficina 	IN	CHAR,
      xDC 		IN	CHAR,
      xCuenta 	IN	CHAR,
      xZONA 	IN 	CHAR,
      xLOTE 	IN 	CHAR)
AS

	xID 		INTEGER;
	xRetenido 	FLOAT DEFAULT 0;
	xDeuda_a_embargar FLOAT DEFAULT 0;
	xFRete 	DATE;
	xF_DILIGENCIA DATE;
	xCUANTOS INT;
	xPuedoUpdate CHAR(1);
	xInsertar CHAR(1);

BEGIN

	/* comprobar que queda alguna cuenta con una 
       diligencia emitida sin aplicar su importe retenido */

	/* Si no hay cuentas salirnos sin mas, vía la excepcion */

   	BEGIN

      	SELECT IMPORTE_RETENIDO,FECHA_RETENCION,ID,F_DILIGENCIA,DEUDA_A_EMBARGAR
	   	INTO xRetenido,xFRete,xID,xF_DILIGENCIA,xDEUDA_A_EMBARGAR
      	FROM CUENTAS_LOTES 
      	WHERE ZONA=xZONA
	   		  AND LOTE=xLOTE
   	   		  AND IDEXPE=xIDExpe
	   		  AND DILIGENCIA='S' 
	   		  AND HECHO='N' 
         	  AND ENTIDAD=xEntidad 
	   		  AND OFICINA=xOficina
         	  AND DC=xDC 
	   		  AND CUENTA=xCuenta;

      	EXCEPTION
         	WHEN NO_DATA_FOUND THEN
            	RETURN;
   	END;

   	-- BORRAMOS LA CUENTA   	
   	DELETE FROM CUENTAS_LOTES WHERE ID=xID;

   	-- COMPROBAR SI HAY UNA TUPLA DE ESTE EXPEDIENTE EN EL LEVANTAMIENTO PARA LA FECHA
   	-- DE ENTRADA (SYSDATE) Y SIN ENVIAR EN DISCO FASE5
   	BEGIN
      	SELECT ID INTO xID FROM NEXT_LEVANTA_CUENTAS
		WHERE IDEXPE=xIDexpe AND TRUNC(F_ENTRADA)=TRUNC(SYSDATE) AND
			  F_ENVIO_FASE5 IS NULL;
		xPuedoUpdate:='S';
      	EXCEPTION
      		WHEN NO_DATA_FOUND THEN
         		INSERT INTO NEXT_LEVANTA_CUENTAS
          			(IDEXPE,NIF,ZONA,LOTE)
	   			VALUES 
          			(xIDExpe,xNIF,xZONA,xLOTE)
          		RETURNING ID INTO xID;
   	END;
   
	if xPuedoUpdate='S' then
	  xInsertar:='N';
	  UPDATE CUENTAS_A_LEVANTAR SET NUEVARETEN=0
	  WHERE ID=xID AND IDEXPE=xIDExpe AND ENTIDAD=xEntidad
			AND OFICINA=xOficina AND DC=xDC AND CUENTA=xCuenta;
	  if SQL%NOTFOUND then
	  	xInsertar:='S';
	  end if;
	else 
		xInsertar:='S';
	end if;

	if xInsertar='S' then
		-- Insertar la cuenta en cuentas a levantar
 		INSERT INTO CUENTAS_A_LEVANTAR
    	(ID,IDEXPE,ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,RETENIDO, F_RETENCION)
   		VALUES  
	    (xID,xIDExpe,xEntidad,xOficina,xDC,xCuenta,xDEUDA_A_EMBARGAR,xRetenido,xFRete);
	end if;

   	PkSeguimiento.NotaInformativa(xIDExpe,'Se levanta embargo ' || xEntidad ||
                '-' || xOficina || '-'|| xDC || '-' || xCuenta);
                
    -- CONTROL DEL ESTADO de embargos_cuentas
    CUENTAS_CONTROL_ESTADOS(xIDEXPE,xEntidad,xOficina,      			
      						xZONA,xLOTE,xF_DILIGENCIA) ;
      						
END;
/


/*****************************************************************************************
Acción: Hace todo lo necesario para levantar un expediente del embargo de cuentas 
		corrientes, dejando una copia de todo y en situación para poder deshacer esta 
		operación.
		Levanta las cuentas con diligencia de un expediente.
		Las inserta en cuentas_a_levantar, lo anota en next_levanta_cuentas,y las copia en 
		borra_cuentas_lotes
		Lo anota en el seguimiento del expediente
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Se ha cambiado la estructura de las tablas
		next_levanta_cuentas y cuentas_a_levantar. También se almacena en la tabla
		borra_levantamientos el id del levantamiento del expediente para poder deshacer
		este paso.
******************************************************************************************/
-- Modificado: 24/12/2003. Lucas Fernández Pérez.
--	Si la cuenta a levantar tiene un levantamiento hecho el mismo día y sin enviar a fase 5,
--	actualiza los datos de ese levantamiento. En cualquier otro caso, crea un nuevo registro
--	de levantamiento.

CREATE OR REPLACE PROCEDURE ADD_CUENTAS_A_LEVANTAR(xIDEXPE IN INTEGER)
AS

	xID INTEGER DEFAULT 0;
	xPuedoUpdate CHAR(1);
	xInsertar CHAR(1);
	
	-- Cuentas con diligencia sin aplicar de un determinado expediente
	CURSOR cCUENTAS IS 
		   SELECT *
		   FROM CUENTAS_LOTES 
  		   WHERE DILIGENCIA='S' 
				 AND HECHO='N' 
				 AND IDEXPE=xIDEXPE;

BEGIN

	--Grabamos en una tabla temporal para poder deshacer esta operación en caso
   	--de error humano
   	INSERT INTO BORRA_EMBARGOS_CUENTAS
   		(IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,EMBARGO,F_EMBARGO,
   		 QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,NOTIFICADO,NEXT_PRELA,
   		 ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,HUBO_CUENTAS,PUEDO_DILIGENCIA)
   	SELECT IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,EMBARGO,F_EMBARGO,
   		 QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,NOTIFICADO,NEXT_PRELA,
   		 ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,HUBO_CUENTAS,PUEDO_DILIGENCIA
   	FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDEXPE;   	   	
   
   	-- Solo levantamos las diligenciadas

	FOR vCuentas IN cCuentas LOOP

		-- COMPROBAR SI HAY UNA TUPLA DE ESTE EXPEDIENTE EN EL LEVANTAMIENTO PARA LA FECHA
   		-- DE ENTRADA (SYSDATE) Y SIN ENVIAR EN DISCO FASE5
   		BEGIN
      		SELECT ID INTO xID FROM NEXT_LEVANTA_CUENTAS
			WHERE IDEXPE=xIDexpe AND TRUNC(F_ENTRADA)=TRUNC(SYSDATE) AND
			  	  F_ENVIO_FASE5 IS NULL;
			xPuedoUpdate:='S';
      		EXCEPTION
      			WHEN NO_DATA_FOUND THEN      		
         			INSERT INTO NEXT_LEVANTA_CUENTAS
          				(IDEXPE,NIF,ZONA,LOTE)
          			VALUES 
          				(xIDEXPE,vCuentas.NIF,vCuentas.ZONA,vCuentas.LOTE)	   			
          			RETURNING ID INTO xID;          	
   		END;
   	   			
	if xPuedoUpdate='S' then
	  xInsertar:='N';
	  UPDATE CUENTAS_A_LEVANTAR SET NUEVARETEN=0
	  WHERE ID=xID AND IDEXPE=xIDExpe AND ENTIDAD=vCuentas.Entidad
			AND OFICINA=vCuentas.Oficina AND DC=vCuentas.DC 
			AND CUENTA=vCuentas.Cuenta;
	  if SQL%NOTFOUND then
	  	xInsertar:='S';
	  end if;
	else 
		xInsertar:='S';
	end if;

	if xInsertar='S' then
		-- Insertar la cuenta en cuentas a levantar
 		INSERT INTO CUENTAS_A_LEVANTAR
    	(ID,IDEXPE,ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,RETENIDO, F_RETENCION)
   		VALUES  
	      (xID,xIDExpe,vCuentas.ENTIDAD,vCuentas.OFICINA,vCuentas.DC,vCuentas.CUENTA,
	      vCuentas.DEUDA_A_EMBARGAR,vCuentas.IMPORTE_RETENIDO,vCuentas.FECHA_RETENCION);
	end if;

		PkSeguimiento.NotaInformativa(xIDEXPE,'SE LEVANTA EMBARGO '|| 
					  vCuentas.ENTIDAD||'-'||vCuentas.OFICINA||'-'||
				      vCuentas.DC||'-'||vCuentas.CUENTA);
				      
		-- Grabamos la cuenta en una copia temporal para poder deshacer esta operación
   		-- en caso de error humano.   		
		INSERT INTO BORRA_CUENTAS_LOTES
     		(ID,LOTE,IDEXPE,EXPEDIENTE,ZONA,NIF,ENTIDAD,OFICINA,DC,CUENTA,CLAVE_SEGURIDAD,
	   	 	 IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,DILIGENCIA,F_DILIGENCIA,
	   	 	 DEUDA_A_EMBARGAR,VECES)
   		VALUES 
   			(vCuentas.ID,vCuentas.LOTE,vCuentas.IDEXPE,vCuentas.EXPEDIENTE,
   			vCuentas.ZONA,vCuentas.NIF,vCuentas.ENTIDAD,vCuentas.OFICINA,vCuentas.DC,
   			vCuentas.CUENTA,vCuentas.CLAVE_SEGURIDAD,vCuentas.IMPORTE_RETENIDO,
   			vCuentas.FECHA_RETENCION,vCuentas.NOTIFICADO,vCuentas.HECHO,vCuentas.DILIGENCIA,
	     	vCuentas.F_DILIGENCIA,vCuentas.DEUDA_A_EMBARGAR,vCuentas.VECES);	    
				      
		-- borramos la cuenta y comprobamos el estado del embargo		    		    
		DELETE FROM CUENTAS_LOTES WHERE ID=vCuentas.ID;   			
   			
    	CUENTAS_CONTROL_ESTADOS(xIDEXPE,vCuentas.Entidad,vCuentas.Oficina,
    					vCuentas.ZONA,vCuentas.LOTE,vCuentas.F_DILIGENCIA);		    	    		      

   	END LOOP;
   	
   	-- Grabamos el ID de la tabla next_levanta_cuentas para saber qué levantamiento
	-- sobre el expediente hay que eliminar en el caso de reposición
	IF (xID>0) THEN
		INSERT INTO BORRA_LEVANTAMIENTOS (IDEXPE,ID)
		VALUES (xIDEXPE,xID);	    
	END IF;

   	UPDATE EXPEDIENTES SET ESTA_EMBARGO='L',F_EMBARGO=SYSDATE WHERE ID=xIDEXPE;   	
   	
END;
/


--
-- Hace todo lo necesario para levantar un expediente del embargo de cuentas corrientes
-- dejando una copia de todo y en situación para poder deshacer esta operación atrás
--
-- Levanta las cuentas con diligencia de un expediente.
-- Las inserta en cuentas_a_levantar, lo anota en next_levanta_cuentas,y las copia en 
-- borra_cuentas_lotes
-- Lo anota en el seguimiento del expediente
--
-- INTERNO
--
CREATE OR REPLACE PROCEDURE LEVANTA_CUENTAS(xIDEXPE IN INTEGER)
AS
	xOTRO Char(1);
BEGIN
   
	ADD_CUENTAS_A_LEVANTAR(xIDEXPE);

	-- eliminar del lote el expediente
	QUITO_EXPE_LOTE(xIDEXPE);

	-- Comprobar si hay un embargo de cuentas simultáneo
	SELECT EN_OTROTRAMITE INTO xOTRO 
	FROM EXPEDIENTES WHERE ID=xIDEXPE;

	-- en caso afirmativo levantarlo
	IF xOTRO='S' THEN
   		LEVANTA_INMUEBLES(xIDExpe);
	END IF;

END;
/

/******************************************************************************************
Acción: Levantar un embargos de vehiculos para un expediente-ayto.

Parámetros: xIDEmbargo: ID del Embargo;
		xFechaManda: Fecha del Mandamiento;

MODIFICACIÓN: 20/02/2002 M. Carmen Junco Gómez. Revisión del proceso de embargo de vehiculos.
*******************************************************************************************/

CREATE OR REPLACE PROCEDURE LEVANTA_UN_VEHICULO(xIDEmbargo IN INTEGER, xFechaManda IN DATE)
AS
BEGIN

   IF xFechaManda IS NULL THEN

      UPDATE VALORES SET ID_INMUEBLES=NULL,
				 EN_INMUEBLES='N'
	WHERE ID_INMUEBLES=xIDEmbargo;
	DELETE FROM AUTOS_EMBARGADOS WHERE IDEMBARGOAUTO=xIDEmbargo;
	DELETE FROM EMBARGOS_AUTOS WHERE ID=xIDEmbargo;

   ELSE

      -- Otro procedimiento lo borra definitivamente trás la impresión
	UPDATE EMBARGOS_AUTOS SET QUITAR_EMBARGO='S' WHERE ID=xIDEmbargo;

   END IF;

END;
/

/******************************************************************************************
Acción: Levantamiento de todos los embargos de vehículos, pues en la configuración 
	  supramunicipal habría tantos embargos como expediente-ayto haya.

Parámetros: xIDExpe: ID del Expediente;

MODIFICACIÓN: 20/02/2002 M. Carmen Junco Gómez. Revisión del proceso de embargo de vehiculos.
******************************************************************************************/

CREATE OR REPLACE PROCEDURE LEVANTA_VEHICULOS(xIDExpe IN INTEGER)
AS

   xCuantos INT default 0;

   -- Todos los embargos de un expediente, puede haber más de uno 
   -- en caso de una entidad supramunicipal habría tantos como aytos distintos.
   CURSOR cEmbExpe IS  
	    SELECT ID,F_MANDAMIENTO FROM EMBARGOS_AUTOS 
	    WHERE IDEXPE=xIDEXPE;

BEGIN

   xCuantos:=0;

   FOR v_cEmbExpe IN cEmbExpe LOOP

	IF v_cEmbExpe.F_MANDAMIENTO IS NOT NULL THEN

	   xCuantos:=xCuantos+1;

      END IF;

	LEVANTA_UN_VEHICULO(v_cEmbExpe.ID ,v_cEmbExpe.F_MANDAMIENTO);

   END LOOP;


   -- Que no haya ningún mandamiento o esta en el pendiente de vehiculos
   IF xCuantos = 0 THEN

	PKSeguimiento.NotaInformativa(xIDEXPE,
			'Se elimina del embargo de vehículos. Expediente sin trámites');	

	UPDATE EXPEDIENTES SET EMBARGO='0',
				     ESTA_EMBARGO='C',
				     F_EMBARGO=SYSDATE,
				     EN_OTROTRAMITE='N',
				     FECHA_DILIGENCIA=NULL
	WHERE ID=xIDEXPE;

   ELSE

	-- Que haya algún mandamiento emitido y anotado
	PKSeguimiento.NotaInformativa(xIDEXPE,'Levantamiento del embargo de vehiculos');

	UPDATE EXPEDIENTES SET ESTA_EMBARGO='L',
				     F_EMBARGO=SYSDATE
	WHERE ID=xIDEXPE;

   END IF;

END;
/


-- *************************************************************************************
-- Realiza el levantamiento de un embargo de salarios (intenta eliminar el embargo).
-- 1. Si no se ha emitido la diligencia a la empresa del embargo, se elimina el embargo,
-- y se deja al expediente sin trámites.
-- 2. En el caso de que se hubiese emitido la diligencia a la empresa, el embargo se pone
-- en estado de levantado, y el expediente en estado 'L', para permitir mostrar un informe
-- a la empresa indicando que el embargo se elimina, antes de que se elimine.
-- El borrado definitivo del embargo en este caso lo hará el procedimiento BORRA_DILI_LEVANTA
--
-- Modificado: 24/07/2003. Lucas Fernández Pérez. Se cambia el mensaje del seguimiento cuando
--	el embargo no está emitido a la empresa, que decía que se levantaba cuando realmente no
--	se levanta hasta que se emite a la empresa. Ahora anota en seguimiento que se elimina.
--
CREATE OR REPLACE PROCEDURE LEVANTA_SALARIOS(xIDExpe IN INTEGER)
AS

CURSOR C1 IS 
	SELECT EMITIDA_EMPRESA,ID
            FROM EMBARGOS_SALARIOS
	          WHERE IDEXPE=xIDEXPE;
BEGIN

  FOR v_C1 IN C1 LOOP

      IF v_C1.EMITIDA_EMPRESA='N' THEN
		
		UPDATE VALORES SET ID_INMUEBLES=NULL,EN_INMUEBLES='N' 
			WHERE EXPEDIENTE=xIDEXPE;

	      UPDATE SALARIOS SET IDSALARIO=NULL WHERE IDEXPE=xIDEXPE;

		DELETE FROM EMBARGOS_SALARIOS	WHERE ID=v_C1.ID;
   		
		PKSeguimiento.NotaInformativa(xIDEXPE,
					'Se elimina del embargo de salarios. Expediente sin trámites');	

		UPDATE EXPEDIENTES SET EMBARGO='0', 
                          ESTA_EMBARGO='C', 
				  F_EMBARGO=NULL,
				  FECHA_DILIGENCIA=NULL
		WHERE ID=xIDEXPE;

      ELSE
		PKSeguimiento.NotaInformativa(xIDEXPE,'Levantamiento del embargo de salarios.');	
		-- DESPUES DE IMPRIMIR BORRAREMOS 
		UPDATE EXPEDIENTES SET ESTA_EMBARGO='L',F_EMBARGO=SYSDATE
			WHERE ID=xIDEXPE;

		UPDATE EMBARGOS_SALARIOS SET LEVANTADO='S' WHERE ID=v_C1.ID;
      END IF;
 
  END LOOP;

END;
/

--
-- Levantamiento de Otros Trámites
--
CREATE OR REPLACE PROCEDURE LEVANTA_OTROS(xIDExpe IN INTEGER)
AS
BEGIN

      DELETE FROM OTROS_TRAMITES WHERE ID_EXPE=xIDExpe;

END;
/


--
-- Comprueba que levantamiento hay que practicar
--
CREATE OR REPLACE PROCEDURE LEVANTA_CHECK(xIDExpe IN INTEGER, xEMBARGO IN CHAR)
AS
BEGIN


	IF xEMBARGO='1' THEN
         LEVANTA_CUENTAS(xIDExpe);
      END IF;

      IF xEMBARGO='3' THEN
         LEVANTA_SALARIOS(xIDExpe);
      END IF;

      IF xEMBARGO='4' THEN
         LEVANTA_INMUEBLES(xIDExpe);
      END IF;

      IF xEMBARGO='8' THEN
	   LEVANTA_VEHICULOS(xIDExpe);
      END IF;

      IF xEMBARGO='X' THEN
         LEVANTA_OTROS(xIDExpe);
      END IF;


END;
/

/********************************************************************************
Acción: Comprobar si hay retenciones de cuentas y en caso afirmativo
		realizar un levantamiento parcial o total. Esta rutina es llamada
        desde los procedimientos que hacen alguna aminoración del importe del
		expediente ya sea por ingreso, baja o suspensión.
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. 
*********************************************************************************/
CREATE OR REPLACE PROCEDURE CHECK_RETENIDO_LEVANTA(xIDExpe IN INTEGER)
AS
	xDiferencia	FLOAT DEFAULT 0;  --diferencia entre el pendiente y lo retenido
	xPendiente 	FLOAT DEFAULT 0;  --pendiente del expediente	
	sPrincipal 	float default 0;
	sRecargo 	float default 0;
	sCostas 	float default 0;
	sDemora 	float default 0;
	sPendiente 	float default 0;
BEGIN


	-- Diligencia en marcha
	IF EmbargoCuentaEnMarcha(xIDExpe) THEN

		PkIngresos.Get_PendienteRetenido(xIDExpe, xDiferencia);
   		PkIngresos.PENDIENTE_EXPE(xIDEXPE,'N',SYSDATE,sPrincipal,sRecargo,sCostas,
                	   			  sDemora, xPendiente);

        -- Haremos un levantamiento total si el pendiente del expediente es cero
        IF (xPendiente = 0) THEN
        
           LEVANTA_CUENTAS(xIDEXPE);
            
        -- Si queda pendiente y la diferencia entre lo pendiente y lo retenido es menor
        -- a cero, haremos un levantamiento parcial  
        ELSIF ((xPendiente > 0) AND (xDiferencia < 0)) THEN
           LEVANTA_PARCIAL_CUENTAS(xIDExpe, (xDiferencia * (-1)) );
        END IF;

	END IF;

END;
/
/*******************************************************************************************
Acción: Pasa un expediente del estado levantado ('L') al estado abierto ('O').
	  Para eso el expediente tiene que estar vivo.
 	  Deshace los cambios realizados cuando se levantó el expediente.
 	  PARA SALARIOS, INMUEBLES y VEHICULOS.

Parámetros: xIDExpe: ID del Expediente;
		xIDEMBARGO: ID del Embargo;
		xEMBARGO: '3' Salarios, '4' Inmuebles, '8' Vehículos.

MODIFICACIÓN: 20/02/2002 M. Carmen Junco Gómez. Se añaden notas informativas en el seguimiento.
DELPHI
********************************************************************************************/

CREATE OR REPLACE PROCEDURE DESHACE_LEVANTA(
		xIDExpe 	IN INTEGER, 
		xIDEMBARGO 	IN INTEGER,
		xEMBARGO 	IN CHAR)
AS
xISOPEN CHAR(1);
BEGIN


   UPDATE EXPEDIENTES SET ESTA_EMBARGO='O' 
	WHERE ISOPEN='S' AND ID=xIDExpe AND EN_OTROTRAMITE='N';

   SELECT ISOPEN INTO xISOPEN FROM EXPEDIENTES WHERE ID=xIDExpe;
   
   IF xISOPEN='S' THEN -- Permito deshacer el levantamiento

   	IF xEMBARGO='3' THEN
	   UPDATE EMBARGOS_SALARIOS SET LEVANTADO='N' WHERE IDEXPE=xIDExpe;
	   PKSeguimiento.NotaInformativa(xIDEXPE,
			'Se anula el levantamiento del embargo de Salarios');

   	ELSIF xEMBARGO='4' THEN

		--si lo llamamos desde reponer una anulacion del expediente, se repone todos
		--los embargos de inmuebles que pudiera tener
		if xIDEMBARGO is not null then
			UPDATE EMBARGOS_INMUEBLES SET QUITAR_EMBARGO='N' WHERE ID=xIDEMBARGO;
		else
			UPDATE EMBARGOS_INMUEBLES SET QUITAR_EMBARGO='N' WHERE IDEXPE=xIDExpe;
		end if;

		PKSeguimiento.NotaInformativa(xIDEXPE,
			'Se anula el levantamiento del embargo de Inmuebles');

   	ELSIF xEMBARGO='8' THEN

		--si lo llamamos desde reponer una anulacion del expediente, se repone todos
		--los embargos de vehiculos que pudiera tener
		if xIDEMBARGO is not null then
			UPDATE EMBARGOS_AUTOS SET QUITAR_EMBARGO='N' WHERE ID=xIDEmbargo;
		else
			UPDATE EMBARGOS_AUTOS SET QUITAR_EMBARGO='N' WHERE IDEXPE=xIDExpe;
		end if;

		PKSeguimiento.NotaInformativa(xIDEXPE,
			'Se anula el levantamiento del embargo de Vehículos');
	END IF;

   END IF;
	
END;
/
