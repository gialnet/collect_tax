-- ***************************************************************************************
-- Acción: Entrega de una cantidad sobre un valor
-- MODIFICACIÓN: 3/12/2001 Lucas Fernández Pérez. Euro. Se han realizado cambios. Rounds en insert/update.
-- MODIFICACIÓN: 02/01/2002 Agustin Leon Robles. Siempre se le envia el código de operación.
-- MODIFICACIÓN: 24/01/2002 Lucas Fernández Pérez. Recalcula intereses al valor sobre el que se
-- 		  hace la entrega siempre que el valor este en ejecutiva, notificado, y
-- 		  sin embargo.
-- MODIFICACIÓN: 19/10/2002 Antonio Pérez Caballero
-- 	Para que el orden de aplicación de ingresos sea por configuración PkEntregas. También se
-- tiene en cuenta si el ingreso es en banco la fecha de cálculo de intereses es la del banco.
--
-- Modificado: 18/07/2003. Lucas Fernández Pérez. Añade la posibilidad de calcular intereses
--	aún estando el recibo sin acuse o con acuse negativo e ignorando los plazos del art.108
--  si por configuración se indica que genere intereses por adelantado.
-- 
-- Modificado: 29/08/2003. Lucas Fernández Pérez. Añade el campo f_entrega a la llamada
--		al procedimiento CheckCierreFrac, porque si se cierra el fraccionamiento en
--		voluntaria es necesario saber en qué fecha, para anotarlo en el mismo, y en el valor.
--
-- Modificacion: 23/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- Modificacion: 05/05/2005 Agustín León Robles. Según nos comenta en Torrejon hay que quitar el calculo
--							de intereses a los valores no notificados aunque en la configuración está activada
--							la opción de intereses por anticipado. Esta opción de configuración solo es para
--							la emisión de las providencias de apremio.
-- DELPHI
-- *******************************************************************************************

CREATE OR REPLACE PROCEDURE ENTREGA_VALOR(
	xID         		IN integer,
	iEntrega    		IN float,
	F_entrega   		IN date,
	xFechaBanco 		IN DATE,
	xDescrip    		IN varchar,
	xTipoEntrega 		IN char,
	xCodOpe 			IN INTEGER,
	xCanalIngreso 		IN CHAR,
	xIngreso_Tramite 	IN CHAR,
	xError 				OUT INTEGER)

AS
xEntrega 			float;
xRecargo 			float default 0;
xPrincipal 			float default 0;
xCostas 			float default 0;
xDemora 			float default 0;
xPendiente 			float default 0;
mParReca 			float default 0;
xFSuspen 			Date;
xISLive 			Char(1);
xCont 				INTEGER;
xIDFrac 			INTEGER;
xFBanco				date;
xFCalculoDemora   	date;
xIDExpe				INTEGER;
xVol_Eje			Char(1);
xNotificado			Char(1);
xOrden_Apremio		Integer;
xF_Notificacion		date;
xFin_Pe_Vol			date;
xTipoTributo		char(2);
xInteres			float default 0;
xPuedo  			integer DEFAULT 0;
xDEMORA_VA			FLOAT;
xSiCompruebo		boolean default false;
BEGIN

	--esto sucedera cuando se haga una entrega a cuenta desde ventanilla, como no podemos
	--enviar nulos en parametros de fecha, utilizamos este año
	if to_char(xFechaBanco,'yyyy')='1901' then
		xFBanco:=NULL;
		xFCalculoDemora:=F_entrega;
	else
		xFBanco:=xFechaBanco;
		xFCalculoDemora:=xFechaBanco;
	end if;

	xEntrega:=iEntrega;

	xError:=0;

	-- Si un valor está fraccionado no se le pueden realizar entregas a cuenta
	SELECT F_SUSPENSION,IS_LIVE,EXPEDIENTE,VOL_EJE,Notificado,F_Notificacion,
			ORDEN_APREMIO,FIN_PE_VOL,TIPO_DE_TRIBUTO
	INTO xFSuspen,xISLive,xIDExpe,xVol_Eje,xNotificado,xF_Notificacion,
			xOrden_Apremio, xFin_Pe_Vol, xTipoTributo 
	FROM VALORES WHERE ID=xId;

	IF xFSuspen IS NOT NULL AND xISLive='N' THEN
		
		-- Es recibo de un fraccionamiento
		xError:=1;
		return;
		
	END IF;	

	-- Obtengo los importes pendientes de cobrar
	PkIngresos.Get_Pendiente(xID,xPrincipal,xRecargo,xCostas,xDemora,xPendiente);

	-- --------------------------------------------------------------
	-- Se recalcula el interés pendiente a la fecha indicada por f_entrega.
	-- Para esto el valor tiene que estar en ejecutiva, notificado, y libre de embargos.

	xPuedo:=0; -- Indica si se deben o no recalcular los intereses de demora
	
	if xVol_Eje='E' then
	
		if xNotificado='S' then
			xSiCompruebo:=True;
		end if;	   
		
	end if;

	if xSiCompruebo then
	
		if PERMITO_CALCULAR_INTERESES(xIDEXPE) then
		
			-- No tiene embargos que bloqeen el cálculo de interes de demora.
			xPuedo:=PLAZO_APREMIO(xFCalculoDemora, xF_NOTIFICACION,xFin_Pe_Vol);
			
		end if;
		
	end if;
	
	
	IF xPUEDO=1 THEN

		-- DEVUELVE LOS INTERESES QUE HABRIA QUE COBRAR INCLUIDO DE LAS ENTREGAS A
		--LAS QUE NO SE LES HAYA COBRADO 
		INT_ENTREGAS(xID,xFIN_PE_VOL, xTIPOTRIBUTO,xDEMORA_VA);

		CAL_DEMORA(xFCalculoDemora, xFIN_PE_VOL, xTIPOTRIBUTO,xPRINCIPAL, xINTERES);
		
		xDemora := xINTERES + xDEMORA_VA;

		update valores set demora_pendiente=ROUND(xDemora,2) where id=xID;
		
	END IF;


	IF (xPendiente <= 0) then
		
		-- No debe nada
		xError:=2;		
		RETURN;
		
   END IF;


	--
	-- Entregas a cuenta en función de la configuración
	--
	PkEntregas.main(xID, xEntrega);


	IF xFBanco is null THEN
			PkIngresos.WRITE_INGRESO(xID,xDescrip,xTipoEntrega,F_Entrega,
					PkEntregas.xImportePrincipal, PkEntregas.xImporteRecargo,
					PkEntregas.xImporteCostas, PkEntregas.xImporteDEMORA, xCodOpe, 'P');
	ELSE
			PkIngresos.WRITE_INGRESO(xID,xDescrip,xTipoEntrega,F_Entrega,
					PkEntregas.xImportePrincipal, PkEntregas.xImporteRecargo,
					PkEntregas.xImporteCostas, PkEntregas.xImporteDEMORA, xCodOpe,
					'P', xFBanco, NULL, NULL, xCanalIngreso, xIngreso_Tramite);
	END IF;

	-- Mira si el ingreso es sobre un valor de un plazo en ejecutiva y si cierra su fraccionamiento.
	-- El valor sobre el que se hace el fraccionamiento es otro distinto del que estamos ingresando.
	
	select count(*), max(fracciona) into xCont,xIDFrac from plazos_frac_vol where valor=xID;
	
	if xCont>0 then
		-- Si esta entrega cierra el fraccionamiento,se da por cerrado el valor sobre el que
		-- se efectuó el fraccionamiento.
		pkFraccionamientosVol.CheckCierreFrac(xIDFrac,F_entrega);
	end if;

END;
/



/*******************************************************************************************/
-- SÓLO PARA INGRESOS DE EXPEDIENTES A TRAVES DE ENTIDADES FINANCIERAS
-- Anota un ingreso en cuentas_servicio, mov_cuentas
-- (e ingresos_indebidos dependiendo del tipo de ingreso)
--
/*BASE*/
CREATE OR REPLACE PROCEDURE COBROS_BANCOS_EXPE(
	xIDExpe 		IN    	INTEGER,
	xCUENTA 		IN		INTEGER,
	xCodOpe			IN    	INTEGER,
    xTIPO_INGRESO 	IN 		CHAR,
    xIMPORTE 		IN 		FLOAT,
    xRECIBOS 		IN 		FLOAT,
    xF_INGRESO 		IN 		DATE,
	xTEXTO 			IN 		VARCHAR2)

AS
   xSALDO  FLOAT DEFAULT 0;
BEGIN


   IF xIMPORTE > 0 THEN
	UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + ROUND(xIMPORTE,2) WHERE ID=xCUENTA
	RETURN SALDO INTO xSALDO;
   END IF;


   /* INSERTAR EN MOVIMIENTOS CUENTAS*/
   INSERT INTO MOV_CUENTAS
	(CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
   VALUES
	(xCUENTA,xTEXTO,xTIPO_INGRESO,ROUND(xIMPORTE,2),ROUND(xRECIBOS,2),
	xCUENTA,'H',xF_INGRESO,xSALDO);


   -- Anotar los posibles cobros indebidos de expedientes
/*   IF xTIPO_INGRESO IN ('TC','TS','TI','TV','TO','FE','FV','F1','F2') THEN
   	IF xIMPORTE > xRECIBOS THEN
     	   INSERT INTO INGRESOS_INDEBIDOS
		 (IDEXPE, FECHAINGRESO, COD_INGRESO, TIPO_INGRESO, IMPORTE)
	   VALUES (xIDExpe, xF_INGRESO, xCodOpe, xTIPO_INGRESO, ROUND(xIMPORTE - xRECIBOS,2));
   	END IF;
   END IF;
*/
END;
/


/* ********************************************************************** */
--
-- Anota en cuentas_servicio y mov_cuentas una operación de Haber o Debe
--
/*BASE*/
CREATE OR REPLACE PROCEDURE IN_MOV_CUE(
	xCUENTA 		IN	INTEGER,
      xTEXTO 		IN 	VARCHAR2,
      xTIPO_INGRESO 	IN 	CHAR,
      xIMPORTE 		IN 	FLOAT,
      xRECIBOS 		IN 	FLOAT,
      xORIGEN 		IN 	INTEGER,
      xOPERACION 		IN 	CHAR,
      xF_INGRESO 		IN 	DATE,
	xID			OUT	INTEGER)

AS
   xSALDO  FLOAT DEFAULT 0;
BEGIN

   --xOperacion tendrá los valores de H-aber o D-ebe

   IF xIMPORTE > 0 THEN
      UPDATE CUENTAS_SERVICIO
	   SET SALDO = DECODE(xOPERACION,'H',ROUND(SALDO + xIMPORTE,2),ROUND(SALDO - xIMPORTE,2))
      WHERE ID=xCUENTA
	RETURN SALDO INTO xSALDO;
   END IF;

   /* INSERTAR EN MOVIMIENTOS CUENTAS*/
   INSERT INTO MOV_CUENTAS
      (CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
   VALUES
      (xCUENTA,xTEXTO,xTIPO_INGRESO,ROUND(xIMPORTE,2),ROUND(xRECIBOS,2),xORIGEN,
	xOPERACION,xF_INGRESO,xSALDO)
   RETURN ID INTO xID;

END;
/


/******************************************************************************************/
-- AL GRUPO DE INGRESOS QUE VAN A ENTRAR EN EL PARTE SE LE PONE COMO REFERENCIA EL ID
--   DEL MOVIMIENTO DE CUENTAS TABLE MOV_CUENTAS
--   EL PARTE DEL DIA TENDRÁ DOS COMPONENTES POR UN LADO LOS INGRESOS EN METALICO
--   QUE SON LOS QUE SE PASAN A LA CUENTA RESTRINGIDA Y EL RESTO DE INGRESOS.

-- Modificado: Agustín León Robles. 29-10-2002.
-- 	Se añade la condición de fecha de cobro banco igual a nulo
--
-- Modificado: Agustín León Robles. 5-12-2002. Parametro de salida con el importe del 
--		movimiento bancario
--

/*DELPHI*/
CREATE OR REPLACE PROCEDURE ASIGNAR_PARTES(
	xFDESDE	IN	DATE,
      xFHASTA 	IN 	DATE,
      xCUENTA 	IN 	INTEGER,
      xFECHA 	IN 	DATE,
	xDEUDA 	OUT	FLOAT)

AS
xSALDO 	FLOAT;
xIDMOV	INTEGER;
xTEXTO 	VARCHAR(80);
xZONA 	CHAR(2);
BEGIN


   /* ZONA */
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   /* SUMAR EL TOTAL DEL IMPORTE DE LOS INGRESOS EN METALICO SOLAMENTE */
   SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) INTO xDEUDA
	FROM INGRESOS
	WHERE FECHA BETWEEN xFDESDE AND xFHASTA
		AND PARTE_DEL_DIA IS NULL
		AND ZONA=xZONA
		AND F_COBRO_BANCO IS NULL
		AND TIPO_INGRESO IN ('VE','FE','FV','EE','ER','EF','F1','F2');

   IF xDEUDA IS NOT NULL THEN

	xTEXTO:='PARTE DEL DIA: '||TO_CHAR(xFDESDE,'DD/MM/YYYY');

	IN_MOV_CUE(xCUENTA,xTEXTO,'PD',xDEUDA,xDEUDA,xCUENTA,'H',xFECHA,xIDMOV);

	-- EN EL PARTE SIN EMBARGO SI ENTRAN TODOS LOS TIPOS DE INGRESOS
	UPDATE INGRESOS SET PARTE_DEL_DIA=xIDMOV,CUENTA=xCUENTA
      	WHERE FECHA BETWEEN xFDESDE AND xFHASTA
		AND PARTE_DEL_DIA IS NULL
          	AND ZONA=xZONA
		AND F_COBRO_BANCO IS NULL
		AND TIPO_INGRESO IN ('VE','FE','FV','EE','ER','EF','F1','F2');
   END IF;

END;
/



/* ************************************************************** */
/* PAGAR UN CONCEPTO DE UN RECIBO UNIFICADO DE VARIOS CONCEPTOS */
/* MODIFICADO: 16/02/2005. Gloria Maria Calle. Eliminada actualización sobre 
			   desglose_valores, pues se eliminan los campos ingresado e id_ingreso,
			   no se usa nunca. */
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PAGA_DESGLOSE_VALOR(
         xFecha      IN		DATE,
         xIDDesglose IN		INT,
         xVALOR      IN		INT,
	   xImporte    IN 	FLOAT)

AS

xPRINCIPAL      FLOAT;
xRECARGO        FLOAT;
xResto          float;
xParReca        float;
xEntrePrinci    float;
xEntreReca      float;
xID_INGRESOS    FLOAT;
xCodOpe	INT;

BEGIN


  CODIGO_OPERACION(xCodOpe);

  UPDATE VALORES SET CODIGO_OPERACION=xCodOpe
	WHERE ID=xVALOR
	return PRINCIPAL,RECARGO
  	INTO xPRINCIPAL,xRECARGO;


  xParReca := xRECARGO * 100 / xPRINCIPAL;
  xParReca := (xParReca + 100) / 100;
  xEntrePrinci := ROUND(xImporte / xParReca,2);
  xEntreReca := xImporte - xEntrePrinci;


  PkIngresos.WRITE_INGRESO(xVALOR,
                'PAGO DE UNA PARTE DEL VALOR', 'ER',
                xFecha, xEntrePrinci, xEntreReca, 0, 0, xCodOpe, 'P');

  SELECT LAST_INGRESO INTO xID_INGRESOS
  	FROM USUARIOS
		WHERE USUARIO=USER;

END;
/


-- ****************************************************************************************
-- 
-- Acción: Nos prepara las deudas para poder emitir un informe de deudas a una fecha 
--         determinada. Este procedimiento se puede utilizar también para los documentos de 
--         pago en bancos según se haya elegido en el interfaz de usuario
-- 			xTipo_Ingreso='VE' cobros en ventanilla metalico
-- 			xTipo_Ingreso='CM' compensasión de debitos
-- 			xTipo_Ingreso='DB' documento bancario
-- 
-- MODIFICACIÓN: 20/11/2001 Antonio Pérez Caballero: Hay que probar esta nueva versión de 
--               manera concienzuda, pues es una de las funciones principales del sistema 
--               de ingresos.
--               
-- MODIFICACIÓN: 03/06/2003. Mª del Carmen Junco Gómez: Se añade una nueva opción de 
-- 			  configuración (DEMORA_ANTES_NOTI) que indica si se va a calcular o no 
-- 			  demora para el valor antes incluso de haberlo notificado, siempre que
-- 			  el valor tenga generada la relación de apremio (posea el 20%)
-- 
-- Modificado: 03/07/2003. Lucas Fernández Pérez. Cuando desde ventanilla se graba un acuse,
-- 		no tiene relación de apremio generada, pero en cambio sí tiene 20% y por 
--		configuracion puede estar indicado que se quiere calcular demora. Por eso no se va a 
--		consultar el campo RELACION_APREMIO del valor, sino el campo ORDEN_APREMIO, que
--		tiene datos cuando se genera relacion de apremio para el valor o cuando se notifica
--		desde ventanilla.
-- Modificado: 18/07/2003 Lucas Fernández Pérez. En el procedimiento plazo_apremio se 
-- 	comprueba si hay que hacer caso del artículo 108, según el valor de DEMORA_ANTES_NOTI,
--  por lo que ya no se comprueba aquí.
--
-- Modificacion: 22/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
--
-- Modificacion: 05/05/2005 Agustín León Robles. Según nos comenta en Torrejon hay que quitar el calculo
--							de intereses a los valores no notificados aunque en la configuración está activada
--							la opción de intereses por anticipado. Esta opción de configuración solo es para
--							la emisión de las providencias de apremio.
--								
-- DELPHI y BASE
-- ***************************************************************************************

CREATE OR REPLACE PROCEDURE INFORME_DEUDAS(
        xCodOperacion	IN		INT,
        xFecha 			IN 		DATE,
        IncluirDemora 	IN		char,
	  	xTipo_Ingreso 	IN		CHAR)
AS

xInteres 			FLOAT default 0;
xPuedo 				integer default 0;
xPrinING 			FLOAT;
xPrinPen 			FLOAT;
FIN_TABLA 			integer DEFAULT 0;
xDEMORA_VA 			FLOAT;
xDiligencia			boolean default False;
xSiCompruebo		boolean default false;

CURSOR c_DEUDAS IS
  	SELECT ID,EXPEDIENTE,PRINCIPAL,TIPO_DE_TRIBUTO,FIN_PE_VOL,NOTIFICADO,
         F_NOTIFICACION,DEMORA,VOL_EJE,ORDEN_APREMIO
  	FROM VALORES
  	WHERE CODIGO_OPERACION=xCodOperacion
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL;

CURSOR cSinDemora IS
	SELECT ID,EXPEDIENTE FROM VALORES
		WHERE CODIGO_OPERACION=xCodOperacion AND DEMORA=0;
BEGIN

	IF IncluirDemora='X' THEN
		-- NO HACER NADA, LA ASIGNACIÓN ES DE ADORNO
		xPUEDO:=0;

	ELSE

		IF IncluirDemora='N' THEN

			-- se pone a cero la demora pendiente de aquellas deudas a las que no se le haya
			-- cobrado intereses pues si quitamos a la demora pendiente el importe del recibo
			-- daria valores negativos

			FOR v_cSinDemora IN cSinDemora LOOP

				IF v_cSinDemora.EXPEDIENTE IS NULL THEN
					UPDATE VALORES SET DEMORA_PENDIENTE=0 WHERE ID=v_cSinDemora.ID;
				ELSE
					-- Si no hay una diligencia de embargo en marcha que bloquee la aplicacion de demora
					IF PERMITO_CALCULAR_INTERESES(v_cSinDemora.EXPEDIENTE) THEN
						UPDATE VALORES SET DEMORA_PENDIENTE=0 WHERE ID=v_cSinDemora.ID;
					END IF;
				END IF;

			END LOOP;

		ELSE

			-- INCLUIRDEMORA='S' 
			FOR v_DEUDAS IN c_DEUDAS LOOP

				xInteres:=0;
				xSiCompruebo:=False;
				xDiligencia:=False;
				
       
				if v_DEUDAS.VOL_EJE='E' then
					
					
					if v_DEUDAS.Notificado='S' then
						
						xSiCompruebo:=True;
								
					end if;				
					
					
					if xSiCompruebo then

						IF PERMITO_CALCULAR_INTERESES(v_DEUDAS.EXPEDIENTE) THEN
							xDiligencia:=False;
						ELSE
							xDiligencia:=True;
						END IF;
		        
						
						xPuedo:=PLAZO_APREMIO(xFecha, v_DEUDAS.F_NOTIFICACION,v_DEUDAS.FIN_PE_VOL);

						if xPuedo=1 AND xDiligencia=False then

							SELECT SUM(PRINCIPAL) INTO xPrinING FROM INGRESOS where VALOR=v_DEUDAS.ID;

							IF xPrinING IS NULL THEN
								xPrinING:=0;
							END IF;

							xPrinPen := v_DEUDAS.PRINCIPAL - xPrinING;

							-- DEVUELVE LOS INTERESES QUE HABRIA QUE COBRAR INCLUIDO DE LAS ENTREGAS A LAS QUE NO SE LES
							--HAYA COBRADO 

							INT_ENTREGAS(v_DEUDAS.ID,v_DEUDAS.FIN_PE_VOL,v_DEUDAS.TIPO_DE_TRIBUTO,xDEMORA_VA);

							Cal_Demora(xFecha, v_DEUDAS.FIN_PE_VOL, v_DEUDAS.TIPO_DE_TRIBUTO, xPrinPen, xInteres);

							xINTERES := xINTERES + xDEMORA_VA;							
							
						end if; -- xPuedo

					end if;  --xSiCompruebo
					
				end if;   -- v_DEUDAS.VOL_EJE='E' then

				--
	  			-- Si aún no se ha cobrado demora la demora pendiente es igual a la suma
	  			-- de los intereses de las entregas + intereses del principal pendiente
	  			-- xINTERES:=intereses de las entregas + intereses del principal pendiente
	  			--
	  			-- Además, si el valor esta en un embargo que no permite recalcular intereses,
	  			-- no debe tocarse la demora pendiente.
				IF v_DEUDAS.DEMORA=0 and xDiligencia=False THEN

					update VALORES set DEMORA_PENDIENTE = ROUND(xInteres,2) where ID=v_DEUDAS.ID;

				END IF;

			END LOOP;

		END IF; -- IncluirDemora='N'

	END IF; -- IncluirDemora='X'

	-- Para los bancos solo mostrar los correctos.
	IF xTipo_Ingreso='DB' THEN
		DelDeudasDiligenVencidas(xCodOperacion);
	END IF;

	-- rellena dos tablas temporales, para que sea facil
	-- realizar la impresion de la carta de pago. Si es de bancos genera la carga de pago.
	PkwtDocIngreso.wtDeudasVivasySuspendidas( Null, xCodOperacion, xTipo_Ingreso,'N','S');

END;
/

--
-- Comprobar lo que ha seleccionado el usuario por pantalla
-- en caso de que se hubieran seleccionado deudas de un expediente con embargo de cuentas
-- con retenciones ya vencidas y no aplicadas. Borrar esas deudas de la seleeción pues
-- en caso contrario lo estaría pagando por dos veces.
-- 28/11/2001 Antonio Pérez Caballero
-- En el interfaz ya hemos filtrado que las deudas que formen parte de un fraccionamiento
-- no entren en la selección.
-- En el procedimeinto haremos la comprobación de que si está dentro de una diligencia
-- de embargo de cuentas corrientes y han pasado los 19 días de bloqueo estas retenciones
-- se entienden ya como entregas practidas pendientes de aplicación.
--
-- Modificado: 16/01/2004. Lucas Fernández Pérez. 
--	El cursor tenía la condición 'and expediente is not null' que hacía que tardara mucho
--	la consulta. Se pasa esa condición al if que hay dentro del cursor.
/*DELPHI*/
CREATE OR REPLACE PROCEDURE DelDeudasDiligenVencidas(xCodOpe IN INT)
AS

xRetenido FLOAT default 0;
xIDEXPE INT;

-- de todas las deudas solo las que están dentro de un expediente
CURSOR cTmpDeudasVivas IS
	SELECT EXPEDIENTE FROM Valores
	WHERE CODIGO_OPERACION=xCodOpe
		GROUP BY EXPEDIENTE;

-- Todas las diligencias pendientes de aplicar
CURSOR cDiligencias IS
	SELECT ID,F_DILIGENCIA,ENTIDAD,OFICINA FROM CUENTAS_LOTES
		WHERE IdEXPE=xIDEXPE
		AND DILIGENCIA='S'
		AND HECHO='N';
BEGIN


  -- Borrar posibles mensajes anteriores
  DELETE FROM TmpMensajes WHERE USUARIO=UID;

  -- Analizar los valores de las tablas temporales
  -- sólo aquellos que tienen expediente con una diligencia de embargo de cuentas en marcha

  FOR vTmpDeudasVivas IN cTmpDeudasVivas LOOP

    IF ((vTmpDeudasVivas.EXPEDIENTE is not null) 
    		and (EmbargoCuentaEnMarcha(vTmpDeudasVivas.EXPEDIENTE))) THEN

	  -- Conjunto de diligencias sin aplicar
	  xIDEXPE:=vTmpDeudasVivas.EXPEDIENTE;
	  FOR v_cDiligencias IN cDiligencias LOOP

	    -- Si han pasado más de 19 días no deberiamos de dejar pagar
	    xRetenido:=0;
	    IF NumeroDeDiasEImporte(v_cDiligencias.ID, xRetenido) >= 19 THEN

	      -- No incorporar

		  -- Anotar el mensaje
		  Insert into TmpMensajes (mensaje, importe)
			values ('EMBARGO YA VENCIDO EN LA ENTIDAD: '||v_cDiligencias.ENTIDAD||
				'OFICINA: '|| v_cDiligencias.OFICINA,
				xRetenido);

		  -- Desmarcar los valores que no entraran en el ingreso
		  Update valores set CODIGO_OPERACION=NULL
			where Expediente = vTmpDeudasVivas.EXPEDIENTE
			AND F_INGRESO IS NULL
			AND FECHA_DE_BAJA IS NULL;

	    END IF;

	  END LOOP;

    END IF;

  END LOOP;

END;
/

--
--
-- Revisar los expedientes tras los ingresos en que situación han quedado
-- Fecha de creacion: 14 de Enero de 2002
--
-- Modificado: 19/03/2003 Lucas Fernández Pérez. 
-- En INGRESOS_SALA introduce el campo F_COBRO_BANCO.

-- Modificado: 25/02/2004. Agustín León Robles. Perdía el indice cuando tenía en el cursor la 
--		declaracion "and expediente is not null". Se quita esta condición y se comprueba mediante
--		un if dentro del cursor


/*BASE*/
CREATE OR REPLACE PROCEDURE RevisarExpeTrasIngre
	(xCod    		IN	INT,
	xTipo_Ingreso	IN	CHAR)
AS
xVivos			INT;
xSuspe			INT;
xTraba			Char(1);
xEsta_Embargo		Char(1);
xTotal_Deuda 		float;
xfechacobrobanco		date;
xIDEmbargo			INT;
xTipoIngresoValor		Char(2);
xCadena			Char(150);

-- Cursor con los expedientes que han sido tocados
CURSOR cExpedientes IS
    Select Expediente
    from valores
	where codigo_operacion = xCod	
	group by expediente;

BEGIN


	FOR vcExpedientes IN cExpedientes LOOP

		if vcExpedientes.Expediente is not null then
  
	 		-- Anotación del ingreso correspondiente al expediente
			Select sum(i.principal+i.recargo+i.costas+i.demora),max(f_cobro_banco),max(tipo_ingreso)
			Into xTotal_Deuda, xfechacobrobanco, xTipoIngresoValor
			from ingresos i, valores v
				where i.valor=v.id
				and i.codigo_operacion=xCod
				and v.codigo_operacion=xCod
				and v.expediente=vcExpedientes.Expediente;


			xCadena:='Ingreso de deudas seleccionadas';

			-- Si es un ingreso por ventanilla de banco, y es sobre un expediente con embargo, el
			-- seguimiento indicará que el ingreso es por dicho embargo.
			IF xTipo_Ingreso='VB' THEN -- Hay que mirar el tipo de ingreso.
	   		if (xTipoIngresoValor='TC') or (xTipoIngresoValor='EC') then
				xCadena:='Ingreso de deudas en el embargo de cuentas';
	   		elsif (xTipoIngresoValor='TS') or (xTipoIngresoValor='ES') then
				xCadena:='Ingreso de deudas en el embargo de salarios';
	   		elsif (xTipoIngresoValor='TI') or (xTipoIngresoValor='EI') then
				xCadena:='Ingreso de deudas en el embargo de inmuebles';
	   		elsif (xTipoIngresoValor='TV') or (xTipoIngresoValor='EV') then
				xCadena:='Ingreso de deudas en el embargo de vehículos';
	   		elsif (xTipoIngresoValor='TO') or (xTipoIngresoValor='EO') then
				xCadena:='Ingreso de deudas en otros embargos';
	   		end if;
			END IF;

    		PkSeguimiento.AnotaIngreso(vcExpedientes.Expediente, xCod, xTotal_Deuda, xCadena);

			--Leer la traba que habia
			Select EMBARGO,ESTA_EMBARGO INTO xTraba,xEsta_Embargo from Expedientes
				where ID=vcExpedientes.Expediente;

			-- Contar las deudas vivas y los suspendidos
			RecibosVivosSuspen(vcExpedientes.Expediente, xVivos,	xSuspe);

			-- No Hay traba
			IF xTraba='0' THEN

			   IF xVivos=0 AND xSuspe=0 THEN

	   			--No quedan más deudas se cierra el expediente
	   			CerrarExpediente(vcExpedientes.Expediente, xTipo_Ingreso);

	   		   END IF;

			ELSE
				-- Si el ingreso es por ventanilla no genera una tupla en ingresos_sala
				IF xTraba='3' AND xEsta_Embargo='O' AND xTipo_Ingreso NOT IN ('VE','CM') THEN
					SELECT MAX(ID) INTO xIDEmbargo FROM EMBARGOS_SALARIOS
						WHERE IDEXPE=vcExpedientes.Expediente;

					UPDATE EMBARGOS_SALARIOS SET
						LAST_RETENCION=xfechacobrobanco WHERE ID=xIDEmbargo;

					INSERT INTO INGRESOS_SALA (IDSALARIO, FECHA, F_COBRO_BANCO,COD_INGRESO, IMPORTE)
		      		VALUES (xIDEmbargo,SYSDATE, xfechacobrobanco,xCod, xTotal_Deuda);

				END IF;

				IF xVivos=0 AND xSuspe=0 THEN

	   				LEVANTA_CHECK(vcExpedientes.Expediente, xTraba);

   	   				--No quedan más deudas se cierra el expediente
	   				CerrarExpediente(vcExpedientes.Expediente, xTipo_Ingreso);

				ELSE
      				-- Diligencia en marcha
					CHECK_RETENIDO_LEVANTA(vcExpedientes.Expediente);

				END IF; --xVivos=0 AND xSuspe=0

			END IF; --xTraba
			
		end if; --final del if expediente is not null

	END LOOP;
END;
/


/* ************************************************ */
--
-- 28/11/2001 Antonio Pérez Caballero
-- Da por pagadas las deudas seleccionadas, en ventanilla
--
-- Modificado : 23/1/2002 Lucas Fernández Pérez
-- 	Mira para cada valor si está en un embargo que bloquee intereses, en cuyo caso 
--	no recalcula intereses.
--
-- Modificado : 17/07/2003 Lucas Fernández Pérez.
-- 	Por configuración puede indicarse mediante "intereses por adelantado" que se quieren 
--	generar intereses aun cuando esté notificado negativo el recibo, o bien cuando estando
--	notificado positivo todavía no se han cumplido los plazos para que se pudiesen cobrar
--	intereses. Se ajusta para que el cobro calcule intereses en estos casos dependiendo
--	de la variable DEMORA_ANTES_NOTI de la tabla de CONFIGURACION
--
-- Modificado: 18/07/2003 Lucas Fernández Pérez. En el procedimiento plazo_apremio se 
-- 	comprueba si hay que hacer caso del artículo 108, según el valor de DEMORA_ANTES_NOTI,
--  por lo que ya no se comprueba aquí.
--
-- Modificado: 29/08/2003. Lucas Fernández Pérez. Añade el campo f_entrega a la llamada
--		al procedimiento CheckCierreFrac, porque si se cierra el fraccionamiento en
--		voluntaria es necesario saber en qué fecha, para anotarlo en el mismo, y en el valor.
--
-- Modificacion: 23/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- Modificacion: 05/05/2005 Agustín León Robles. Según nos comenta en Torrejon hay que quitar el calculo
--							de intereses a los valores no notificados aunque en la configuración está activada
--							la opción de intereses por anticipado. Esta opción de configuración solo es para
--							la emisión de las providencias de apremio.
-- DELPHI
CREATE OR REPLACE PROCEDURE MAKE_PAGO(
	xCod    		IN	INT,
	xFechaI  		IN 	DATE,
	xFechaDemora	IN 	DATE,
	xIncluirDemora 	IN	CHAR,
	xDemoraManual 	IN	CHAR,
	xTipo_Ingreso 	IN	CHAR)
AS
xPrincipal  		float;
xRecargo  			float;
xCostas  			float;
xDemora  			float;
xTotal_Deuda 		float;
xInteres  			float;
xPuedo  			INT DEFAULT 0;
xDEMORA_VA 			FLOAT;
xcont 				INTEGER;
xIDFrac 			INTEGER;
xIncluyeDemora		CHAR(1);
xDemoraEsManual		CHAR(1);
xSiCompruebo		boolean default false;

-- Cursor con los valores seleccionados en el interfaz usuario
CURSOR cVALORES IS
    Select id,vol_eje,Notificado,F_Notificacion,FIN_PE_VOL,DEMORA_PENDIENTE,
    		TIPO_DE_TRIBUTO,orden_apremio,EXPEDIENTE
    from valores
	where codigo_operacion = xCod;

BEGIN

	-- Dar por pagadas las deudas señaladas
	FOR vVALORES IN cVALORES LOOP
		

	    -- Si hay diligencia y el trámite es de los que por configuración obliga
    	-- a que se bloquee el cálculo de intereses de demora
    	IF NOT PERMITO_CALCULAR_INTERESES(vVALORES.Expediente) THEN
			--ahora se pone para que no calcule intereses sobre la última diligencia
			--porque si no sale más importe
    		xIncluyeDemora := 'N';
    		xDemoraEsManual := 'S';
    	ELSE
    		xIncluyeDemora:=xIncluirDemora;
    		xDemoraEsManual:=xDemoraManual;
    	END IF;

    	PkIngresos.Get_Pendiente(vVALORES.ID,xPrincipal,xRecargo,xCostas,xDemora,xTOTAL_DEUDA);

    	xInteres := 0;
    	xSiCompruebo:=False;

    	IF xIncluyeDemora='S' AND vVALORES.Vol_Eje='E'  THEN

    	
			if vVALORES.NOTIFICADO='S' then
						
				xSiCompruebo:=True;
								
			end if;
	   		
			if xSiCompruebo then
			
      	 		xPuedo:=PLAZO_APREMIO(xFechaI, vVALORES.F_NOTIFICACION,vVALORES.FIN_PE_VOL);

         		IF xPUEDO=1 THEN

					-- devuelve los intereses que habría que cobrar
            		-- incluido de las entregas a las que no se les haya cobrado
	      			INT_ENTREGAS(vVALORES.ID,vVALORES.FIN_PE_VOL, vVALORES.TIPO_DE_TRIBUTO,xDEMORA_VA);

            		CAL_DEMORA(xFechaDemora, vVALORES.FIN_PE_VOL, vVALORES.TIPO_DE_TRIBUTO,xPRINCIPAL, xINTERES);
            		
	      			xINTERES := xINTERES + xDEMORA_VA;
         		END IF;

	   		end if;
	   			   		
		ELSE
			IF xDEMORAESMANUAL='S' THEN
				xINTERES:=vVALORES.DEMORA_PENDIENTE;
			END IF;
		END IF;

		PkIngresos.WRITE_INGRESO(vVALORES.ID,'INGRESADO EN EL NUEVO SISTEMA',xTipo_Ingreso,
        				      xFechaI,xPrincipal,xRecargo,
    				          xCostas,xInteres,xCod,'C');

		-- Valores con numero de recibo NEGATIVO: Cuando en un fraccionamiento en voluntaria cumple
		-- un plazo, se crea un NUEVO VALOR en ejecutiva por el importe de ese plazo con el
		-- numero de recibo negativo.
		-- Si pagamos ese nuevo valor que se sacó del fraccionamiento, hay que comprobar
		-- si produce un cambio en el estado del fraccionamiento.
		-- Por lo tanto, se mira si el valor que se paga es un valor de este tipo, para actualizar
		-- el fraccionamiento que lo creó.
		select count(*), max(fracciona) into xcont,xIDFrac from plazos_frac_vol where valor=vVALORES.ID;
		
		if xCont > 0 then
			-- Si esta entrega cierra el fraccionamiento en voluntaria,se da por cerrado el valor
			-- sobre el que se efectuó el fraccionamiento.
			pkFraccionamientosVol.CheckCierreFrac(xIDFrac,xFechaI);
		end if;

	END LOOP;

	RevisarExpeTrasIngre(xCod,xTipo_Ingreso);

END;
/




-- *************************************************************************************
-- Dar por pagado un recibo o varios recibos. Se podría utilizar el make_pago, pero ocurre
-- que desde las aplicaciones parciales de embargos de cuentas que dan para pagar un recibo
-- no graba la fecha del banco y por consiguiente no hace el apunte en las cuentas restringidas
--
-- Modificado: 18/07/2003. Lucas Fernández Pérez. Añade la posibilidad de generar intereses
--	aún estando el recibo sin acuse o con acuse negativo e ignorando los plazos del art.108
--  si por configuración se indica que genere intereses por adelantado. Además, comprueba
--  si el expediente tiene bloqueado el cálculo de intereses para no recalcularlos.
--
--	Modificado: 23/06/2004. Agustín León Robles. Se eliminan los parametros de xIncluirDemora y xDemoraManual
--					porque todo se hace desde el procedimiento EXPE_ENTRE_ANTIGUEDAD 
--					que luego llama al APLICA_ENTREGA_ANTIGUEDAD y este ultimo llama a este procedimiento
-- BASE
--
CREATE OR REPLACE PROCEDURE DAR_PAGADO_RECIBOS(
		xCod    		IN	INTEGER,
		xFechaI  		IN 	DATE,
		xFechaBanco		IN 	DATE,	
		xTipo_Ingreso 	IN	CHAR,
		xTexto			IN	CHAR)
AS
xPrincipal  			float default 0;
xRecargo  				float default 0;
xCostas  				float default 0;
xDemora  				float default 0;
xTotal_Deuda 			float default 0;
xIngreso_Tramite		char(1);

CURSOR cVALORES IS
    Select id from valores where codigo_operacion = xCod;
    
BEGIN	

	FOR vVALORES IN cVALORES LOOP

		PkIngresos.Get_Pendiente(vVALORES.ID,xPrincipal,xRecargo,xCostas,xDemora,xTOTAL_DEUDA);
		
		--
		--si se llama desde entregas a cuenta de expedientes por ventanilla no hay que enviar
		--fecha de ingreso en el banco, pues daría error con el campo parte_del_dia en ingresos
		--
		--El Embargo Parcial (EP) de cuentas siempre es por bancos
		--
		IF xTipo_Ingreso IN ('ES','EI','EV','EO','EE') THEN
			PkIngresos.WRITE_INGRESO(vVALORES.ID,xTexto,xTipo_Ingreso,xFechaI,xPrincipal,xRecargo,
								xCostas,xDemora,xCod,'C');
		ELSE

			--si el ingreso es de un embargo parcial de cuentas se pone el valor a 1 y sino a nulo
			if xTipo_Ingreso='EP' then
				xIngreso_Tramite:='1';
			else
				xIngreso_Tramite:=null;
			end if;

			PkIngresos.WRITE_INGRESO(vVALORES.ID,xTexto,xTipo_Ingreso,
            	     xFechaI,xPrincipal,xRecargo,
                	 xCostas,xDemora,xCod,'C',xFechaBanco,null,null,null,xIngreso_Tramite);
		END IF;
		
	END LOOP;

END;
/

--
-- 1) Registrar una nueva asistencia de un ciudadano a nuestras oficinas
-- guardar esta información
-- 2) Nos permite saber quién fué el ciudadano
-- que realizó el ingreso, para ponerlo en la carta de pago a la hora de reimprimir
-- una carta de pago desde el formulario VerCobrosDiario
-- 3) Nos va a permitir poder sacar estadisticas de asistencia de los ciudadanos a
-- nuestras oficinas
-- xMotivo nos indica de manera codificada el porqué de la visita
-- pago de voluntaria, carta de pago en banco, embargos, etc.
-- "EI" informe de debito en expedientes, 
-- "EB" carta de pago con vencimiento en expedientes
-- "E+tramite" en pago en expedientes
-- "ID" informe de debitos ventanilla, 
-- "DB" carta de pago con vencimiento en ventanilla
-- "CV" entrega a cuenta de un valor, 
-- "CC" entrega a cuenta por compensacion
-- "CE" entrega a cuenta de un expediente
-- "VE" pago en ventanilla, 
-- "CM" compensación en ventanilla
-- "SE" Segregación por ingreso
-- xValida nos indica si el usuario que atendió al ciudadano comprobó los datos postales
-- del ciudadano y recogio algún datos adicional como teléfono, e-mail, etc.
--

--
-- Hay otro procedimiento en Gestión tributaria NewAsistenciaGT
--

CREATE OR REPLACE PROCEDURE NewAsistencia(
	xIDINGRESO 	IN INTEGER,
	xNIF		IN CHAR,
	xMOTIVO	IN CHAR,
	xVALIDA	IN CHAR)
AS
xNumero	integer;
BEGIN

	if xMOTIVO='EB' or xMOTIVO='DB' then
		select last_numero into xNumero from usuarios where usuario=user;

		INSERT INTO ASISTENCIA (NIF, MOTIVO, VALIDA, IDCARTAPAGOBANCO)
		VALUES (xNIF, xMOTIVO, xVALIDA,xNumero);
	else
		INSERT INTO ASISTENCIA (IDINGRESO, NIF, MOTIVO, VALIDA)
		VALUES (DECODE(xIDINGRESO,0,NULL,xIDINGRESO), xNIF, xMOTIVO, xVALIDA);
	end if;

END;
/




/* ***************************************************************** */
COMMIT;
/* ***************************************************************** */
