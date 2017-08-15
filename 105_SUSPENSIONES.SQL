/*************************************************************************************
Acción: Suspender un valor, este o no dentro de un expediente
MODIFICACION: 30/07/2003 M. Carmen Junco Gómez. Si el valor suspendido es el último 
			  pendiente del expediente, se suspende el expediente.
MODIFICACIÓN: 16/02/2004 M. Carmen Junco Gómez. Si el valor está dentro de un expediente
			  le quitamos las posibles costas al expediente que tenga asociadas y las
			  repartimos entre el resto de valores pendientes dentro del expediente.
**************************************************************************************/

CREATE OR REPLACE PROCEDURE SUSPENDE_VALOR(
	   xID          IN INTEGER,
	   xFECHA       IN DATE,
	   xF_ACUERDO   IN DATE,
	   xORGANISMO   IN CHAR,
       xDESCRIPCION IN CHAR,
       xERROR		OUT INTEGER)

AS

	xIDExpe INTEGER default NULL;
	xFExpe	DATE;
	xPendiente 	FLOAT DEFAULT 0;  --pendiente del expediente	
	sPrincipal 	float default 0;
	sRecargo 	float default 0;
	sCostas 	float default 0;
	sDemora 	float default 0;

BEGIN

	-- Ponemos la deuda como suspendida
	UPDATE VALORES SET F_SUSPENSION=xFECHA,IS_LIVE='X'
   	WHERE ID=xID AND
		  FECHA_DE_BAJA IS NULL AND
		  F_INGRESO IS NULL AND
		  F_SUSPENSION IS NULL
	Returning EXPEDIENTE,F_IN_EXPEDIENTE into xIDEXPE,xFEXPE;

	-- Si no estaba en situación nada que hacer
	IF SQL%NOTFOUND THEN
   		RETURN;
	END IF;

	-- Los incorporamos a las deudas suspendidas
	INSERT INTO SUSPENSIONES_VALORES
         (valor,ID_EXPE,F_ACUERDO,ORGANISMO,DESCRIPCION)
	VALUES (xID,xIDExpe,xF_ACUERDO,xORGANISMO,xDESCRIPCION);	
	
	-- buscamos si el valor a suspender está dentro de un expediente; de ser así
	-- le quitamos las posibles costas al expediente para repartirlas entre los
	-- valores que quedan pendientes en el expediente, además de controlar el estado
	-- de la traba de cuentas, pues habría que realizar una aminoración.	

	IF (xIDExpe IS NOT NULL) THEN
	
		DELCostaValorPasaAExpe(xIDEXPE,xFEXPE,xID,xERROR);	

      	UPDATE EXPEDIENTES SET RECIBOS=RECIBOS-1,
					CODIGO_INGRESO=NULL,
					CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN+1
        WHERE ID=xIDExpe AND
		      F_ANULACION IS NULL AND
		      F_INGRESO IS NULL;
		      
		-- Si está anulado o pagado nada que hacer, esto no debería de ocurrir nunca
		-- lo ponemos por proteger el código, aunque no tenga mucho sentido, pues dentro
		-- de un expediente pagado no puede haber deudas pendientes, ni tampoco en uno
		-- que esté anulado.
		      
		IF SQL%NOTFOUND THEN
	   		RETURN;
		END IF;
	
		PkIngresos.PENDIENTE_EXPE(xIDEXPE,'N',SYSDATE,sPrincipal,sRecargo,sCostas,
                	   			  sDemora, xPendiente);
        -- si el pendiente es cero después de suspender el valor, suspendemos el expediente.
        IF (xPendiente=0) THEN
        	UPDATE EXPEDIENTES SET F_SUSPENSION=xFECHA,ESTADO='SUSPEND'   						  
   			WHERE ID=xIDExpe AND
				  F_ANULACION IS NULL AND
				  F_INGRESO IS NULL AND
				  F_SUSPENSION IS NULL;	
				  
			IF SQL%NOTFOUND THEN
	   			RETURN;
			END IF;

			-- Anotamos en el seguimiento del expediente
			PkSeguimiento.NotaInformativa(xIDExpe, 'Se suspende el expediente');
        END IF;	


		-- Diligencia en marcha
		CHECK_RETENIDO_LEVANTA(xIDExpe);
		
	END IF;

END;
/

/******************************************************************************************
Autor: 24/07/2002 Mª del Carmen Junco Gómez. 
Acción: Suspende de forma masiva un grupo de valores
******************************************************************************************/
--
-- Suspender un valor, este o no dentro de un expediente
--
CREATE OR REPLACE PROCEDURE SUSPENDE_GRUPO_VALORES(
	   xGRUPO       IN INTEGER,
	   xFECHA       IN DATE,
	   xF_ACUERDO   IN DATE,
	   xORGANISMO   IN CHAR,
       xDESCRIPCION IN CHAR)

AS
   xERROR INTEGER;
   CURSOR CVALORES IS SELECT ID FROM VALORES 
		    WHERE CODIGO_OPERACION=xGRUPO AND F_INGRESO IS NULL AND
			    FECHA_DE_BAJA IS NULL;				                  
BEGIN
   FOR v_Valores IN CVALORES
   LOOP
      SUSPENDE_VALOR(v_Valores.ID,xFECHA,xF_ACUERDO,xORGANISMO,xDESCRIPCION,xERROR);
   END LOOP;
END;
/


--
-- Levantar un valor suspendido, esté o no dentro de un expediente
--
CREATE OR REPLACE PROCEDURE DEL_SUSPEN_VALOR(xID  IN INTEGER)
AS

xIDExpe INTEGER DEFAULT NULL;

BEGIN

-- comprobamos si está dentro de un expediente
begin
  SELECT EXPEDIENTE INTO xIDExpe FROM VALORES
      WHERE ID=xID 
	AND FECHA_DE_BAJA IS NULL
      AND F_INGRESO IS NULL;
exception
when no_data_found then
  xIDExpe:=null;
end;


IF (xIDExpe IS NOT NULL) THEN
	UPDATE EXPEDIENTES SET RECIBOS=RECIBOS+1,
				CODIGO_INGRESO=NULL,
				CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN-1
	WHERE ID=xIDExpe 
	AND F_ANULACION IS NULL
	AND F_INGRESO IS NULL;

	-- Si está pagado o anulado el expediente no se hace nada
	IF SQL%NOTFOUND THEN
	   RETURN;
	END IF;

	PkSeguimiento.NotaInformativa(xIDExpe, 
		'Se levanta la suspensión de una deuda ID: '||to_char(xID));

END IF;

-- Levantar el valor
UPDATE VALORES SET F_SUSPENSION=NULL,IS_LIVE='S'
   WHERE ID=xID 
	AND FECHA_DE_BAJA IS NULL
      AND F_INGRESO IS NULL;

-- Quitarlo de la lista de valores suspendidos
DELETE FROM SUSPENSIONES_VALORES
   WHERE valor=xID;

END;
/

/***************************************************************************************
Autor: 24/07/2002 Mª del Carmen Junco Gómez.
Acción: Quitar la suspensión a un grupo de valores
***************************************************************************************/

CREATE OR REPLACE PROCEDURE DEL_SUSPEN_GRUPO_VALORES(xGRUPO IN INTEGER)
AS
   CURSOR CVALORES IS SELECT ID FROM VALORES 
			    WHERE CODIGO_OPERACION=xGRUPO AND F_SUSPENSION IS NOT NULL;
BEGIN
   FOR v_Valores IN CVALORES
   LOOP
      DEL_SUSPEN_VALOR(v_Valores.ID);
   END LOOP;
END;
/


--
-- Realiza la suspensión del expediente, anota en el seguimiento y pone los valores
-- del expediente como suspendidos, también los anota en la tabla de SUSPENSIONES_VALORES
-- y por último comprueba si había alguna traba en marcha y en tal caso realiza 
-- los levantamientos.
-- Es equivalente a la situación de un pago, pero con caracter provisional.
--
-- El parametro xTipo nos indica C por compensación X otras causas
--
-- Modificado: 23/06/2003. Lucas Fernández Pérez. Al suspender el expediente reajusta los
--	campos CUANTOS_R_SUSPEN y RECIBOS indicando que los valores estan suspendidos.
--
CREATE OR REPLACE PROCEDURE SUSPENDE_EXPE(
		  xIDExpe      IN INTEGER, 
		  xFECHA       IN DATE, 
		  xF_ACUERDO   IN DATE, 
		  xORGANISMO   IN VARCHAR,
	        xDESCRIPCION IN VARCHAR, 
	        xTIPO 	   IN CHAR)
AS
xTraba Char(1);
BEGIN
  

	--Suspendemos el expediente si no está pagado, anulado o suspendido
   UPDATE EXPEDIENTES SET F_SUSPENSION=xFECHA, ESTADO='SUSPEND', 
   						  CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN+RECIBOS, RECIBOS=0 
   WHERE ID=xIDExpe
		AND F_ANULACION IS NULL 
		AND F_INGRESO IS NULL
		AND F_SUSPENSION IS NULL
	Returning Embargo INTO xTraba;

	IF SQL%NOTFOUND THEN
	   RETURN;
	END IF;

	-- Anotamos en el seguimiento del expediente
	PkSeguimiento.NotaInformativa(xIDExpe, 'Se suspende el expediente');

	-- los insertamos en valores suspendidos
	INSERT INTO SUSPENSIONES_VALORES
      (VALOR,ID_EXPE,F_ACUERDO,ORGANISMO,DESCRIPCION)
	SELECT ID,xIDExpe,xF_ACUERDO,xORGANISMO,xDESCRIPCION FROM VALORES
                WHERE EXPEDIENTE=xIDExpe 
			AND FECHA_DE_BAJA IS NULL 
			AND F_INGRESO IS NULL
			AND F_SUSPENSION IS NULL;

	--Suspendemos los valores
    UPDATE VALORES SET F_SUSPENSION=xFECHA,IS_LIVE=xTIPO
    WHERE EXPEDIENTE=xIDExpe 
		AND FECHA_DE_BAJA IS NULL 
		AND F_INGRESO IS NULL 
		AND F_SUSPENSION IS NULL;

-- Realizar los levantamientos pertinentes
IF xTraba<>'0' THEN
   LEVANTA_CHECK(xIDExpe, xTraba); 
END IF;

END;
/

-- ***************************************************************************************
-- Acción: Quitar la suspensión del expediente
-- MODIFICACIÓN: Modificado: 23/06/2003. Lucas Fernández Pérez. Al quitar la suspension 
-- 		      reajusta los campos CUANTOS_R_SUSPEN y RECIBOS indicando que los valores 
-- 		      ya no estan suspendidos.
-- MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Si el expediente estaba en un embargo 
-- 			  de cuentas, éste se ha de reponer.
-- Modificación. 06/11/2003. Lucas Fernández Pérez. 
--		Reajuste en el borrado de suspensiones_valores
-- ***************************************************************************************

CREATE OR REPLACE PROCEDURE DEL_SUSPENDE_EXPE(xID IN INTEGER)
AS
   xTramite char(1);
BEGIN

	--Actualizamos el expediente
   	UPDATE EXPEDIENTES SET F_SUSPENSION=NULL,ESTADO='ABIERTO',
   						   RECIBOS=RECIBOS+CUANTOS_R_SUSPEN, CUANTOS_R_SUSPEN=0
   	WHERE ID=xID AND
	      F_ANULACION IS NULL AND
	      F_INGRESO IS NULL;

   	-- Si no hay cambios, nos salimos
   	IF SQL%NOTFOUND THEN
      	RETURN;
   	END IF;


	--Actualizamos los valores
   	UPDATE VALORES SET F_SUSPENSION=NULL,IS_LIVE='S'
   	WHERE EXPEDIENTE=xID AND
	      FECHA_DE_BAJA IS NULL AND
	      F_INGRESO IS NULL;

	--Eliminamos los valores de la lista
   	DELETE FROM SUSPENSIONES_VALORES WHERE VALOR IN (SELECT ID FROM VALORES
   	WHERE EXPEDIENTE=xID AND
	      FECHA_DE_BAJA IS NULL AND
	      F_INGRESO IS NULL);


	--Anotamos en el seguimiento
   	PkSeguimiento.NotaInformativa(xID, 'Se repone la suspensión');
   	
   	--Comprobamos si el expediente estaba en embargo de cuentas
   	SELECT EMBARGO INTO xTRAMITE FROM EXPEDIENTES WHERE ID=xID;
   	IF (xTRAMITE='1') THEN
   		ReponerEmbargoCuentas(xID);
	END IF;   

END;
/
