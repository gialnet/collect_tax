
-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.(ROUNDS)
-- -----------------------------------------------------
-- ----------------------------------------------------------------
-- PROCEDIMIENTO: DA POR PAGADO UN FRACCIONAMIENTO EN VOLUNTARIA 	
-- Parametros Entrada:							   	
--				xIDFrac INTEGER, Identificador del Fracc. 
-- Modificado: 26/08/2003. Lucas Fernández Pérez. 
--	El cod_ingreso en la tabla valores, antes se ponía 'FR', ahora se pone a 'FV'.
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
--	Añadido el parámetro xFechaIngreso para indicar la fecha de ingreso (antes ponía sysdate)
-- Modificado: 08/01/2004. Lucas Fernández Pérez.
-- Al dar por cobrado el valor, en el where no se puede poner "f_ingreso is null" porque 
-- cuando llega aqui ya esta dado por pagado a traves del procedimiento de "write_ingreso"
-- y entonces no le quitaria la fecha de suspension al valor. 
-- También borra de suspensiones_valores

-- ----------------------------------------------------------------
/*BASE*/
CREATE OR REPLACE PROCEDURE DarPorPagadoFRAC_VOL(xIDFrac IN INTEGER,xFechaIngreso IN DATE)
AS
xIDValor INT;
BEGIN

   update FRACCIONAMIENTO_VOL
   set F_CIERRE=xFechaIngreso,ISOPEN='C',ESTADO='CERRADO',F_ESTADO=xFechaIngreso
   where ID=xidFrac;

   SELECT VALOR INTO xIDValor
   FROM FRACCIONAMIENTO_VOL 
   WHERE ID=xidFrac;	

   -- DAR POR COBRADO EL VALOR AL QUE PERTENECIA EL FRACCIONAMIENTO, Y BORRAR LA SUSPENSION
   DELETE FROM SUSPENSIONES_VALORES WHERE VALOR in 
   	(select id from valores WHERE ID=xIDValor AND FECHA_DE_BAJA IS NULL AND IS_LIVE='N');
   	
   UPDATE VALORES SET F_INGRESO=xFechaIngreso,
	             COD_INGRESO='FV',
		       DEMORA_PENDIENTE=0,
		       F_SUSPENSION=NULL
   WHERE ID=xIDValor AND 
	FECHA_DE_BAJA IS NULL AND 
      IS_LIVE='N';

END DarPorPagadoFRAC_VOL;
/

/******************************************************************/
/* PROCEDIMIENTO: DA POR PAGADO UN VALOR.Reajusta sus importes.	*/
/* Y devuelve lo que ha quedado pendiente de cobrar del valor	*/
/* desglosado por principal, recargo, costas y demora			*/
/* IMPORTANTE: Si el valor no tiene ingresos, lo ELIMINA		*/
/* Parametros Entrada:							   	*/
/*				xIDValor INTEGER, Identificador del Valor.*/
/* Parametros Salida:							   	*/
/*  				xPrincipal,xRecargo,xCostas,xDemora, FLOAT*/
/*  				el pendiente de cobrar en el valor de 	*/
/*				principal, recargo, costas y demora		*/
/******************************************************************/
/*BASE*/
CREATE OR REPLACE PROCEDURE DarPorPagadoVALOR(
	xIDValor IN INTEGER,
	xPrincipal OUT FLOAT,
	xRecargo OUT FLOAT,
	xCostas OUT FLOAT,
	xDemora OUT FLOAT)
AS
xPrinIngre FLOAT;
xRecargoIngre FLOAT;
xCostasIngre FLOAT;
xFechaUltimoIngreso DATE;
xCont INTEGER;

BEGIN

   SELECT COUNT(*),SUM(PRINCIPAL),SUM(RECARGO),SUM(COSTAS),MAX(FECHA)  
	INTO xCont,xPrinIngre, xRecargoIngre, xCostasIngre, xFechaUltimoIngreso
	FROM INGRESOS WHERE VALOR=xIDVALOR;

   IF xCont=0 THEN
	xPrinIngre:=0;
	xRecargoIngre:=0;
	xCostasIngre:=0;
   END IF;

   SELECT PRINCIPAL, RECARGO, COSTAS, DEMORA_PENDIENTE
	INTO xPrincipal,xRecargo,xCostas,xDemora
	FROM VALORES WHERE ID= xIDVALOR;

   xPrincipal:=xPrincipal - xPrinIngre;
   xRecargo:=xRecargo - xRecargoIngre;
   xCostas:= xCostas - xCostasIngre;
   -- La demora que queda por cobrar está en el campo DEMORA_PENDIENTE del valor

   IF xCont=0 THEN
	DELETE FROM PLAZOS_FRAC_VOL WHERE VALOR=xIDValor;
	DELETE FROM VALORES WHERE ID=xIDValor;
   ELSE
   	UPDATE VALORES SET PRINCIPAL=xPrinIngre, RECARGO=xRecargoIngre,
			COSTAS=xCostasIngre, -- El campo demora del valor indica la demora ingresada
			DEMORA_PENDIENTE=0,
			F_SUSPENSION=NULL,
			F_INGRESO=xFechaUltimoIngreso,
			-- CODIGO_INGRESO='FV',se pone ???
			IS_LIVE='N'
   	WHERE ID=xIDVALOR;
   END IF;

END;
/


/******************************************************************
 PROCEDIMIENTO: PASA UN PLAZO DE VOLUNTARIA A EJECUTIVA 		
			CREANDO UN NUEVO VALOR CON EL PENDIENTE		
 Parametros Entrada:								
			xIDPlazo, Identificador del plazo vencido		
*****************************************************************/

-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
-- Se añade el valor sysdate en la llamada a get_next_plazoVol
-- Modificado: 26/07/2004. Agustin Leon Robles. Daba un error cuando se convertia de integer a char(3). Lo que se hace ahora
--				es asignarlo directamente sin hacer el to_char previamente
-- Modificado: 03/08/2004. Agustin Leon Robles. Se cambia el objeto tributario que pone ahora el mes del plazo en vez del número del plazo

-- Delphi 
CREATE OR REPLACE PROCEDURE VENCIDO_PLAZO_VOL(xIDPlazo IN INTEGER)
AS
	xObjeto				VARCHAR(70);
	xNext_princ 		FLOAT DEFAULT 0;
	xNext_pend 			FLOAT DEFAULT 0;
	xFecha     			DATE;
	xNext_plazo 		DATE;
	xValor     			INTEGER;
	xIDNuevo   			INTEGER;
	xIDFrac    			INTEGER;
	xPrincipal 			FLOAT DEFAULT 0;
	xRecargo   			FLOAT DEFAULT 0;
	xCostas    			FLOAT DEFAULT 0;
	xDemora    			FLOAT DEFAULT 0;
	xEntregas  			FLOAT DEFAULT 0;
	xPADRON    			VALORES.PADRON%TYPE;
	xYEAR				VALORES.YEAR%TYPE;
	xPERIODO			VALORES.PERIODO%TYPE;
	xRECIBO				VALORES.RECIBO%TYPE;
	xTIPO_DE_OBJETO 	VALORES.TIPO_DE_OBJETO%TYPE;
	xCLAVE_CONCEPTO 	VALORES.CLAVE_CONCEPTO%TYPE;
	xCERT_DESCUBIERTO 	VALORES.CERT_DESCUBIERTO%TYPE;
	xYEAR_CONTRAIDO 	VALORES.YEAR_CONTRAIDO%TYPE;
	xNIF 				VALORES.NIF%TYPE;
	xNOMBRE 			VALORES.NOMBRE%TYPE;
	xCUOTA_INICIAL 		VALORES.CUOTA_INICIAL%TYPE;
	xRECARGO_O_E 		VALORES.RECARGO_O_E%TYPE;
	xVOL_EJE 			VALORES.VOL_EJE%TYPE;
    xN_CARGO 			VALORES.N_CARGO%TYPE;
	xF_CARGO 			VALORES.F_CARGO%TYPE;
	xFIN_PE_VOL 		VALORES.FIN_PE_VOL%TYPE;
	xESTADO_BANCO 		VALORES.ESTADO_BANCO%TYPE;
    xDOM_TRIBUTARIO 	VALORES.DOM_TRIBUTARIO%TYPE;
	xOBJETO_TRIBUTARIO 	VALORES.OBJETO_TRIBUTARIO%TYPE;
	xTIPO_DE_TRIBUTO 	VALORES.TIPO_DE_TRIBUTO%TYPE;
    xPROPU_INSOLVENTE 	VALORES.PROPU_INSOLVENTE%TYPE;
	xIS_LIVE 			VALORES.IS_LIVE%TYPE;
	xSELECCION 			VALORES.SELECCION%TYPE;
	xAYTO 				VALORES.AYTO%TYPE;
	xF_Apremio 			VALORES.F_APREMIO%TYPE;
	xSALTO				CHAR(2);
BEGIN

	SELECT min(SALTO) INTO xSALTO FROM SALTO;

	-- Vemos el valor al que pertenecia el fraccionamiento voluntario
	SELECT VALOR,PRINCIPAL,COSTAS,DEMORA,ENTREGAS,FRACCIONA,FECHA,PENDIENTE
	INTO xValor,xPrincipal,xCostas,xDemora,xENTREGAS,xIDFrac,xFecha,xNext_pend
	FROM VWPLAZOS_FRAC_VOL
	WHERE ID=xIDPlazo;

	--Según la nueva Ley General Tributaria es un 5% de recargo
    xRecargo:=ROUND(xNext_pend*0.05,2);
	xCUOTA_INICIAL:=xNext_pend;

	-- Tomamos los datos del valor que fue fraccionado
	SELECT PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,
		CLAVE_CONCEPTO,CERT_DESCUBIERTO,YEAR_CONTRAIDO,NIF,NOMBRE,
		RECARGO_O_E,VOL_EJE,
		N_CARGO,F_CARGO,FIN_PE_VOL,ESTADO_BANCO,
		DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,TIPO_DE_TRIBUTO,
		PROPU_INSOLVENTE,IS_LIVE,SELECCION,AYTO,F_APREMIO

	INTO xPADRON,xYEAR,xPERIODO,xRECIBO,xTIPO_DE_OBJETO,
		xCLAVE_CONCEPTO,xCERT_DESCUBIERTO,xYEAR_CONTRAIDO,xNIF,xNOMBRE,
		xRECARGO_O_E,xVOL_EJE,
		xN_CARGO,xF_CARGO,xFIN_PE_VOL,xESTADO_BANCO,
		xDOM_TRIBUTARIO,xOBJETO_TRIBUTARIO,xTIPO_DE_TRIBUTO,
		xPROPU_INSOLVENTE,xIS_LIVE,xSELECCION,xAYTO,xF_Apremio
	FROM VALORES WHERE ID=xVALOR;

	xOBJETO:='PLAZO FECHA: '||to_char(xFecha,'dd/mm/yyyy')||' DEL FRACCIONAMIENTO: '||to_char(xIDFrac)||xSALTO;
	xOBJETO_TRIBUTARIO:=xOBJETO||TRIM(xOBJETO_TRIBUTARIO);

	xRECIBO:=-1*xRECIBO;

	-- Actualizamos el principal del valor antiguo para reflejar el plazo que vencio
	UPDATE VALORES SET 
					PRINCIPAL=PRINCIPAL-xPrincipal,
					DEMORA_PENDIENTE=DEMORA_PENDIENTE-xDemora 
	WHERE ID=xValor;

	-- Creamos un  nuevo valor igual que el antiguo pero en ejecutiva 
	-- con los nuevos pendientes 
    INSERT INTO VALORES
		(PADRON,YEAR,PERIODO,RECIBO,TIPO_DE_OBJETO,
		CLAVE_CONCEPTO,CERT_DESCUBIERTO,YEAR_CONTRAIDO,NIF,NOMBRE,
		CUOTA_INICIAL,PRINCIPAL,RECARGO_O_E,VOL_EJE,
		N_CARGO,F_CARGO,FIN_PE_VOL,ESTADO_BANCO,
		DOM_TRIBUTARIO,OBJETO_TRIBUTARIO,TIPO_DE_TRIBUTO,
		PROPU_INSOLVENTE,IS_LIVE,AYTO,RECARGO,
		COSTAS,DEMORA_PENDIENTE,F_APREMIO)
	VALUES
		(xPADRON,xYEAR,xPERIODO,xRECIBO,xTIPO_DE_OBJETO,
		xCLAVE_CONCEPTO,xCERT_DESCUBIERTO,xYEAR_CONTRAIDO,xNIF,xNOMBRE,
		xCUOTA_INICIAL,xNext_Pend,xRECARGO_O_E,'E',
		xN_CARGO,xF_CARGO,xFIN_PE_VOL,xESTADO_BANCO,
		xDOM_TRIBUTARIO,xOBJETO_TRIBUTARIO,xTIPO_DE_TRIBUTO,
		xPROPU_INSOLVENTE,'S',xAYTO,xRECARGO,0,0,xF_Apremio)
	RETURN ID INTO xIDNuevo;

	
	-- Pasamos el plazo a ejecutiva y le asignamos el nuevo valor creado 
	UPDATE PLAZOS_FRAC_VOL SET VOL_EJE='E',VALOR=xIDNuevo WHERE ID=xIDPlazo;

	-- Actualizamos la cabecera del fraccionamiento con la fecha del siguiente plazo
	PKFraccionamientosVol.GET_NEXT_PLAZO_VOL(xIDFrac,sysdate,xNext_plazo);

	IF xNext_plazo is not null THEN
		SELECT PENDIENTE INTO xNext_princ
		FROM VWPLAZOS_FRAC_VOL 
		WHERE FECHA=xNext_plazo AND FRACCIONA=xIDFrac;
	END IF;

	UPDATE FRACCIONAMIENTO_VOL SET 
			F_NEXT_PLAZO=xNext_plazo, 
			IMPO_NEXT_PLAZO=xNext_princ,
			TOTAL_DEUDA=TOTAL_DEUDA-xNext_Pend 
	WHERE ID=xIDFrac;
	
END;
/

/************************************************************************/
/* PROCEDIMIENTO: PASA A EJECUTIVA LOS PLAZOS DE UN FRACCIONAMIENTO EN 	*/
/*			VOLUNTARIA POR INCUMPLIMIENTO DE PAGOS EN EJECUTIVA	*/
/* Parametros Entrada:									*/
/*			xIDFraccionamiento INTEGER, Identificador del fracc.	*/
/************************************************************************/
/*
	Nuevo Principal: 
		Principal de los plazos en voluntaria 
		+ lo entregado de plazos (en principal) que ahora estan en ejecutiva 
			(cuentan en el valor como entregas y por eso se acumula) 
		+ el principal pendiente de los valores de plazos en ejecutiva.
		   Es decir, el principal inicial del valor en ejecutiva menos 
		   el principal de posibles entregas realizadas al valor.

	Nueva Demora:
		Demora de los plazos en voluntaria 
		+ lo entregado de plazos (en demora) que ahora estan en ejecutiva
			(cuentan en el valor como entregas y por eso se acumula)
		+ posible demora generada que quede pendiente en los valores de plazos en ejecutiva.

		Demora ingresada:
			Es la demora de los ingresos del valor.

		Demora pendiente:
			Es la Nueva Demora - demora ingresada

	Nuevo Recargo:
		10 % de recargo del pendiente de los plazos en voluntaria.
		+ recargo pendiente de los valores de plazos en ejecutiva.

	Nuevas Costas:
		Costas pendientes de los valores de plazos en ejecutiva.

	El nuevo pendiente: PRINCIPAL+DEMORA+DEMORA_PENDIENTE+RECARGO+COSTAS-ENTREGAS_A_CUENTA

	Los valores en ejecutiva se cierran sin nada pendiente.Lo pendiente lo pasan al valor
	que estaba en voluntaria. 
	Este valor se pasa a ejecutiva con los nuevos importes anteriormente citados.
	El valor tendrá las entregas que tenía, los nuevos recargos, y todo lo pendiente
	de los plazos en ejecutiva.
	NOTA: Como el recargo no se acumula, al notificar se pondría a valor de 10% del principal

	Por este motivo el recargo se dejará a 0 y el principal será principal+recargo
*/
--
--
-- Modificado: 03/08/2004. Agustin Leon Robles. Ahora cuando se incumple el fraccionamiento el principal pasa a ser
--						la suma de los principales más los intereses de demora, y a todo esto se le calcula el 5% de recargo
--
/*INTERNO*/
CREATE OR REPLACE PROCEDURE PASAR_A_EJE_RESTO(
		xIDFraccionamiento IN INTEGER)
AS

xIDValorVol 	INTEGER;
xPrincipal 		FLOAT;
xRecargo		FLOAT;
xCostas 		FLOAT;
xDemora 		FLOAT;

xSumPrincipal 	FLOAT DEFAULT 0;
xSumCostas 		FLOAT DEFAULT 0;

xSumPrincipalVol 	FLOAT DEFAULT 0;
xSumDemoraVol		FLOAT DEFAULT 0;

xDemoraIngre		FLOAT;

xCont INTEGER;

CURSOR CPlazos_frac IS
	SELECT * FROM vwPLAZOS_FRAC_VOL WHERE FRACCIONA=xIDFraccionamiento;

BEGIN
	

	-- Recorremos todos los plazos del fraccionamiento 
	FOR v_Plazo IN CPlazos_frac LOOP

		-- Si el plazo esta en ejecutiva apunta a un valor en ejecutiva.Cierro ese valor
		-- y me quedo con los importes pendientes de cobrar en el mismo.	
		IF v_Plazo.VOL_EJE='E' THEN
		
			DarPorPagadoVALOR(v_Plazo.Valor,xPrincipal,xRecargo,xCostas,xDemora);
			
			xSumPrincipal:=xSumPrincipal+xPrincipal;
			xSumCostas:=xSumCostas+xCostas;
			
			-- Si se le realizaron entregas antes de pasar a ejecutiva, lo acumulo para el valor en voluntaria.
			if v_Plazo.Entregas>0 then
			
				select SUM(PRINCIPAL) INTO xPrincipal FROM INGRESOS WHERE MANEJADOR=v_Plazo.ID;
				
				xSumPrincipalVol:=xSumPrincipalVol+xPrincipal;
				xSumDemoraVol:=xSumDemoraVol+v_Plazo.Demora;
			end if;
			
		ELSE
			
			-- El plazo esta en voluntaria.Lo paso a ejecutiva.Y acumulo los datos en otras variables.
			xSumPrincipalVol:=xSumPrincipalVol+v_Plazo.Principal;
			xSumDemoraVol:=xSumDemoraVol+v_Plazo.Demora;
			
		END IF;

	END LOOP;


	-- Llegados a este punto tengo el pendiente de todos los plazos que estaban en ejecutiva.
	-- y el pendiente de todos los plazos que estaban en voluntaria.
	-- La suma de todos los pendientes pasará a ser el nuevo principal del valor sobre el que
	-- se generó el fraccionamiento.Y ese valor se pondrá en estado de ejecutiva.

	SELECT VALOR INTO xIDValorVol FROM FRACCIONAMIENTO_VOL WHERE ID=xIDFraccionamiento;
	
	select COUNT(*),SUM(DEMORA) INTO xCont,xDemoraIngre FROM INGRESOS WHERE VALOR=xIDValorVol;
	
	IF xCont=0 THEN
		xDemoraIngre:=0;
	END IF;
	
	UPDATE VALORES SET 
			PRINCIPAL=xSumPrincipalVol+xSumPrincipal+xSumDemoraVol,
			RECARGO=round((xSumPrincipalVol+xSumPrincipal+xSumDemoraVol)*5/100,2),
			COSTAS=xSumCostas,
			DEMORA=xDemoraIngre,
			DEMORA_PENDIENTE=0,
			VOL_EJE = 'E',
			F_SUSPENSION=NULL,
			IS_LIVE='S'
	WHERE ID=xIDValorVol;

	-- Borro el fraccionamiento.
	DELETE FROM INGRESOS_FRAC_VOL WHERE FRAC=xIDFraccionamiento;
	DELETE FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xIDFraccionamiento;
	DELETE FROM FRACCIONAMIENTO_VOL WHERE ID=xIDFraccionamiento;

	
END;
/

  
/******************************************************************/
/* PROCEDIMIENTO: PASA A EJECUTIVA LOS PLAZOS RESTANTES 		*/
/*			DE UN FRACCIONAMIENTO SEGUN Art 57RGR y 107RGR	*/
/* Parametros Entrada:								*/
/*			xIDPlazo INTEGER, Identificador del plazo		*/
/******************************************************************/
/* Delphi */
CREATE OR REPLACE PROCEDURE VENCIDO_PLAZO_EJE(xIDPlazo IN INTEGER)

AS
	xIDValor			INTEGER;
	xIDFraccionamiento 	INTEGER;
	xFecha_notificacion 	DATE;
	xPuedo  			INT DEFAULT 0;
	xFinPeVol			date;

BEGIN
	-- Tomamos el ID del valor y del fraccionamiento del plazo en ejecutiva
	SELECT VALOR,FRACCIONA
	INTO xIDValor,xIDFraccionamiento
	FROM  VWPLAZOS_FRAC_VOL
	WHERE ID=xIDPlazo;

	-- Tomamos la fecha en la que se notifico 
	SELECT F_NOTIFICACION,FIN_PE_VOL INTO xFecha_notificacion,xFinPeVol
	FROM VALORES
	WHERE ID=xIDValor;
	
	-- Debe haberse notificado para poder vencer el resto de los plazos 
	IF xFecha_notificacion is null THEN
		raise_application_error(-20009,'El valor debe estar notificado ');
	end if;
	   
	-- Mira si el plazo ha cumplido el plazo marcado por el Art.108
	xPuedo:= PLAZO_APREMIO(SYSDATE, xFecha_notificacion,xFinPeVol);

      IF xPUEDO=1 THEN

	   PASAR_A_EJE_RESTO(xIDFraccionamiento);

	END IF;
	
END;
/

/******************************************************************/
/* PROCEDIMIENTO:	Realiza una entrega sobre un plazo en voluntaria*/
/*			Es llamado por PUT_ENTREGA_PLAZOS_VOL		*/
/* Parametros Entrada:								*/
/*			xIDPlazo INTEGER, Identificador plazo		*/
/*			xCODOPE INTEGER, Codigo de la operacion		*/
/*			xEntrega FLOAT, Cantidad entregada			*/
/******************************************************************/
--
-- Modificado: 29/08/2003. Lucas Fernández Pérez. Cambia la antigua llamada a 
-- write_ingresovol por la llamada a write_ingreso.
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
--
/*INTERNO*/
CREATE OR REPLACE PROCEDURE ENTREGA_RECIBO_PLAZO_VOL(
	xIDPlazo  IN INTEGER,
	xCODOPE   IN INTEGER,
	xEntrega  IN FLOAT,
    xFechaIngreso IN DATE )
AS
xPrin FLOAT DEFAULT 0;
xReca FLOAT DEFAULT 0;
xGastos FLOAT DEFAULT 0;
xInteres FLOAT DEFAULT 0;
xPRINCIPAL FLOAT DEFAULT 0;
xRECARGO FLOAT DEFAULT 0;
xCOSTAS FLOAT DEFAULT 0;
xDEMORA FLOAT DEFAULT 0;

xImportePlazo FLOAT DEFAULT 0;
xVALOR INTEGER;

BEGIN


   SELECT IMPORTE,VALOR,PRINCIPAL,RECARGO,COSTAS,DEMORA
   INTO xImportePlazo,xVALOR,xPRINCIPAL,xRECARGO,xCOSTAS,xDEMORA
   FROM VWplazos_frac_vol
   WHERE ID=xIDPlazo;

   -- Repartir el importe de la entrega entre principal,recargo,costas, etc.
   reparto_frac(xEntrega,xImportePlazo,
   	xPrincipal,xRecargo,xCostas,xDemora,xPrin,xReca,xGastos,xInteres);

   -- LE PASAMOS EL ID DEL PLAZO PARA que en WRITE_INGRESO SE LO PODAMOS ESCRIBIR 
   --	EN LA TABLA DE INGRESOS 
   UPDATE USUARIOS SET LAST_TAREA=xIDPlazo WHERE USUARIO=USER; 

   PkIngresos.WRITE_INGRESO(xVALOR, 'Pago parcial de un plazo fraccionamiento' ,
		'F1',xFechaIngreso,xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P');

END;
/

/******************************************************************/
/* PROCEDIMIENTO: Realiza el pago completo de un plazo.		*/
/*			El pago es del pendiente del plazo.			*/
/*			Es llamado por PUT_ENTREGA_PLAZOS_VOL		*/
/* Parametros Entrada:								*/
/*			xID INTEGER, Identificador del plazo		*/
/*			xCODOPE INTEGER, Codigo operacion			*/
/******************************************************************/
-- Modificado: 01/09/2003. Lucas Fernández Pérez. Cambia la antigua llamada a 
-- write_ingresovol por la llamada a write_ingreso.
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
/*INTERNO*/
CREATE OR REPLACE PROCEDURE APLICAR_RECIBO_PLAZO_VOL( 
		xID        	IN INTEGER,
      	xCODOPE    	IN INTEGER,
	    xFechaIngreso IN DATE )

AS

xPendiente FLOAT DEFAULT 0;

xPrin FLOAT DEFAULT 0;
xReca FLOAT DEFAULT 0;
xGastos FLOAT DEFAULT 0;
xInteres FLOAT DEFAULT 0;

xPRINCIPAL FLOAT DEFAULT 0;
xRECARGO FLOAT DEFAULT 0;
xCOSTAS FLOAT DEFAULT 0;
xDEMORA FLOAT DEFAULT 0;
xENTREGAS FLOAT DEFAULT 0;
xSUMENTREGAS FLOAT DEFAULT 0;
xImportePlazo FLOAT DEFAULT 0;
xIDPlazo INTEGER;
xINGRESADO CHAR(1);
xVALOR INTEGER;
xFracciona INTEGER;
xPlazo DATE;
xUltimoPlazo DATE;

xPendi FLOAT;

BEGIN

   SELECT FRACCIONA,FECHA INTO xFracciona,xPlazo
   FROM VWPLAZOS_FRAC_VOL
   WHERE ID=xID;

   SELECT MAX(FECHA) INTO xUltimoPlazo
   FROM VWPLAZOS_FRAC_VOL
   WHERE FRACCIONA=xFracciona;

   SELECT INGRESADO,VALOR,ENTREGAS,IMPORTE,PRINCIPAL,RECARGO,COSTAS,DEMORA,ID
   INTO xINGRESADO,xVALOR,xENTREGAS,xImportePlazo,xPRINCIPAL,xRECARGO,
   			xCOSTAS,xDEMORA,xIDPlazo
   FROM vwplazos_frac_vol
   WHERE ID=xID;

   IF xENTREGAS > 0 THEN
	-- QUE EXISTAN ENTREGAS ANTERIORES 
	xPendiente:=xImportePlazo-xEntregas;
	-- Repartir el importe de la entrega entre principal,recargo,costas, etc.
	reparto_frac(xPendiente,xImportePlazo,xPrincipal,xRecargo,xCostas,xDemora,
                      xPrin,xReca,xGastos,xInteres);
   ELSE
	xPrin:=xPRINCIPAL;
	xReca:=xRECARGO;
	xGastos:=xCOSTAS;
	xInteres:=xDEMORA;
   END IF;

   -- LE PASAMOS EL ID DEL PLAZO PARA EN EL TR_INGRE_AI SE LO PODAMOS ESCRIBIR EN LA TABLA DE INGRESOS 
   UPDATE USUARIOS SET LAST_TAREA=xID WHERE USUARIO=USER;

   -- Ahora con las cartas de pago puede que no se pague al final el ultimo plazo, sino que
   -- se page en el banco el ultimo plazo quedando otros pendientes de cobro.
   -- Por lo tanto, miro si pago todo lo pendiente.
   SELECT SUM(ENTREGAS) INTO xSUMENTREGAS FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xFRACCIONA;
   SELECT TOTAL_DEUDA - PAGADO - xPrin - xReca - xGastos - xInteres - xSUMENTREGAS
   INTO xPendi
   FROM FRACCIONAMIENTO_VOL WHERE ID=xFracciona;

--   IF xPlazo=xUltimoPlazo THEN
   IF xPendi=0 THEN
	PKIngresos.WRITE_INGRESO(xVALOR, 'Pago parcial de un plazo fraccionamiento',
		'FV',xFechaIngreso,xPrin,xReca,xGASTOS,xInteres,xCodOpe,'C');
   ELSE
	PKIngresos.WRITE_INGRESO(xVALOR, 'Pago parcial de un plazo fraccionamiento',
		'F1',xFechaIngreso,xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P');
   END IF;

END;
/

/*******************************************************************/
/* PROCEDIMIENTO: ENTREGA A CUENTA A UN FRACCIONAMIENTO VOLUNTARIA */
/*			LLAMA A PUT_ENTREGA_PLAZOS_VOL		 	 */
/* Parametros Entrada:								 */
/*			xIDFrac INTEGER, Identificador del fracciona.	 */
/*			xImpo FLOAT, Importe de la entrega			 */
/*******************************************************************/
-- Modificado: 01/09/2003. Lucas Fernández Pérez. 
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
-- Se indica en la tabla de ingresos que el tramite de ingreso es de fraccionamiento.
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PUT_ENTREGA_FRAC_VOL(
		xIDFrac IN INTEGER,
		xImpo IN FLOAT,
        xFechaIngreso IN DATE,
		xIDCartaPago IN INTEGER)

AS
   xCiego integer;
   xFECHA DATE;
   xCUANTOS INTEGER DEFAULT 0;
   xImpoNextPlazo FLOAT DEFAULT 0;
   xNext_Entregas FLOAT DEFAULT 0;

BEGIN

   -- Aumenta el contador de codigo de operacion y lo escribe en la tabla de usuarios 
   CODIGO_OPERACION(xCiego);

   -- realizar el ingreso de las entregas 
   PUT_ENTREGA_PLAZOS_VOL(xImpo, xIDFrac, xFechaIngreso, xCiego, xIDCartaPago);

   -- Se indica que el tramite de ingreso es de fraccionamiento.
   UPDATE INGRESOS SET INGRESO_TRAMITE='F' WHERE CODIGO_OPERACION=xCiego;

   -- Anotar el movimento en el seguimiento de ingresos del frac. 
   INSERT INTO INGRESOS_FRAC_VOL
          (FRAC,FECHA,COD_INGRESO,IMPORTE,TIPO)
   VALUES (xidFrac,xFechaIngreso,xCiego,ROUND(xImpo,2),'E');

   -- averiguar la fecha del siguiente plazo 
   -- Primero buscamos si hay algún parcial
   SELECT COUNT(*),MIN(FECHA) INTO xCUANTOS,xFECHA
   FROM PLAZOS_FRAC_VOL
   WHERE FRACCIONA=xIDFrac AND INGRESADO='P' AND VOL_EJE='V';

   -- Si no hubiera ninguno, entonces se busca los Ingresado='N'
   IF xCUANTOS=0 THEN
         SELECT COUNT(*),MIN(FECHA) INTO xCUANTOS,xFecha
         FROM PLAZOS_FRAC_VOL
         WHERE FRACCIONA=xIDFrac AND INGRESADO='N' AND VOL_EJE='V';
   END IF;

   IF xCUANTOS<>0 THEN 
	SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS S1, 
		 SUM(ENTREGAS) AS S2
	INTO xImpoNextPlazo,xNext_Entregas
	FROM VWPLAZOS_FRAC_VOL
	WHERE FECHA=xFECHA AND FRACCIONA=xIDFrac;	
   END IF;

   update FRACCIONAMIENTO_VOL SET 
		ENTREGAS=ENTREGAS+ROUND(xImpo,2),F_NEXT_PLAZO=xFECHA,
		IMPO_NEXT_PLAZO=(xImpoNextPlazo-xNext_Entregas)
   where ID=xIdFrac;

   -- Si no quedan plazos voluntarios que pagar fin del fracionamiento 
   IF xCUANTOS=0 THEN 
      PKFraccionamientosVol.CheckCierreFrac(xIDFrac,xFechaIngreso);
   END IF;

END;
/

/******************************************************************/
/* PROCEDIMIENTO: ENTREGA A CUENTA A UN FRACCIONAMIENTO VOLUNTARIA*/
/* Parametros Entrada:								*/
/*			xEntrega FLOAT, Importe entregado			*/
/*			xIDFrac INTEGER, Identificador del fracciona.	*/
/*			xCODOPE INTEGER, Codigo Operacion			*/
/******************************************************************/
-- Modificado: 01/09/2003. Lucas Fernández Pérez. 
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
/*INTERNO*/
CREATE OR REPLACE PROCEDURE PUT_ENTREGA_PLAZOS_VOL(
        xENTREGA IN FLOAT,
        xidFrac  IN INTEGER,
        xFechaIngreso IN DATE,
        xCODOPE  IN INTEGER,
	  xIDCartaPago IN INTEGER)

AS

xPendiente float default 0;
xLast float default 0;
xID integer;
xIMPORTE FLOAT;
xIDIngresosIndebidos INTEGER;
xIDValor INTEGER;
xDeudaValor FLOAT;
xZONA		CHAR(2);

-- leer los todos los plazos de un fraccionamiento que no esten ingresados 
CURSOR CUR_PLAZO IS 
	select PENDIENTE,ID
	from   VWPLAZOS_FRAC_VOL
	where  FRACCIONA=xidFrac and INGRESADO<>'S' and VOL_EJE='V'
	order by fecha,ID;

BEGIN

   xIMPORTE:=ROUND(xENTREGA,2);

   open cur_plazo;

   LOOP

      FETCH  cur_plazo into xPendiente,xID;
      EXIT WHEN (CUR_PLAZO%NOTFOUND OR xIMPORTE<=0);
      
         -- averiguar que queda pendiente 
         xLast:=xImporte;

         xImporte := xImporte - xPendiente;

         -- sobra para otro plazo MAS como MINIMO 

         IF (xImporte >= 0) THEN

            APLICAR_RECIBO_PLAZO_VOL(xID, xCODOPE, xFechaIngreso);

            update PLAZOS_FRAC_VOL 
			set INGRESADO='S',
		    ENTREGAS=PRINCIPAL+RECARGO+COSTAS+DEMORA,
                F_INGRESO=xFechaIngreso
            where ID=xID;
         END IF;

         -- ha faltado para completar este plazo 
         IF (xImporte < 0) THEN

            ENTREGA_RECIBO_PLAZO_VOL(xID, xCODOPE, ROUND(xLAST,2),xFechaIngreso);

            update PLAZOS_FRAC_VOL
			set ENTREGAS=ENTREGAS+xLast, INGRESADO='P'
            where ID=xID;

         END IF;

   END LOOP;

   close cur_plazo;

   IF (xImporte >= 0) THEN -- Si aun pagando todo queda importe sobrante

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	INSERT INTO INGRESOS_INDEBIDOS(IDCARTAPAGO,CODIGO_OPERACION,IMPORTE,ZONA) 
		VALUES (xIDCartaPago,xCODOPE,xImporte,xZONA)
		RETURNING ID INTO xIDIngresosIndebidos;

	SELECT ID,(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) INTO xIDValor,xDeudaValor 
	FROM VALORES WHERE ID=(SELECT VALOR FROM FRACCIONAMIENTO_VOL WHERE ID=xIDFrac);

	--Insertamos el detalle del recibo que comprende
	INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES)
	VALUES (xIDIngresosIndebidos,xIDValor,xDeudaValor,'N');

   END IF;

END;
/

/*********************************************************************/
/*	PROCEDIMIENTO: Paga los plazos pendientes cuando se realiza    */
/*			   una entrega del total pendiente	   		   */
/*	PARAMETROS ENTRADA:  xID id del fraccionamiento			   */
/*				   xFecha Fecha del ingreso			   */
/*				   xPlazo Fecha de vencimiento del plazo	   */
/*********************************************************************/
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
-- Se elimina el campo xIDPlazo de la llamada a Paga_plazo_vol.
-- Se añade el campo xFecha en la llamada a get_next_plazoVol
/* Delphi */
CREATE OR REPLACE PROCEDURE ENTREGA_PENDIENTE_VOL(
        	xID       IN INTEGER, 
	      xFecha    IN DATE, 
		xPlazo    IN DATE)
AS
	xNextPlazo DATE;
BEGIN

    xNextPlazo:=xPlazo; 

    WHILE not(xNextPlazo is null) LOOP
		PKFraccionamientosVol.PAGA_PLAZO_VOL(xID,xFecha,xNextPlazo);
		PKFraccionamientosVol.GET_NEXT_PLAZO_VOL(xID,xFecha,xNextPlazo);  
    END LOOP;

END;
/

/******************************************************************/
/* PROCEDIMIENTO: Busca plazos en ejecutiva con incumplimiento	*/
/*			de pagos, segun lo establecido en el Art 108RGR */
/*			Debe ser un Jobs que se ejecute automaticamente */
/*			en las fechas 6 y 21 de cada Mes, pues son las  */
/*			posibles fechas de incumplimiento.			*/
/* Parametros Entrada: No tiene.						*/
/******************************************************************/
/****** NO SE UTILIZA EN LA APLICACION PORQUE VAN A SER SOMETIDOS ****
CREATE OR REPLACE PROCEDURE BUSCAR_VENCIDOS_EJECUTIVA
AS
	xPlazoID INTEGER DEFAULT 0;

	CURSOR Plazos_frac IS
	SELECT ID
	FROM PLAZOS_FRAC_VOL
	WHERE VOL_EJE='E';
BEGIN
	OPEN Plazos_frac;
	LOOP
		FETCH Plazos_frac INTO xPlazoID;
	      EXIT WHEN Plazos_frac%NOTFOUND;
		
		VENCIDO_PLAZO_EJE(xPlazoID);
	END LOOP;
	CLOSE Plazos_frac;
END;
/
*/

/******************************************************************/
/* PROCEDIMIENTO: Procedimiento que busca que plazos de voluntaria*/
/*			han vencido, para pasarlos automaticamente a 	*/
/*			ejecutiva. 							*/
/*			Debe ser un Jobs que se ejecute automaticamente */
/*			cada cierto tiempo, por ejemplo cada Mes		*/
/* Parametros Entrada: No tiene.						*/
/******************************************************************/
/*CREATE OR REPLACE PROCEDURE BUSCAR_VENCIDOS_VOLUNTARIA
AS
	xPlazoID INTEGER DEFAULT 0;
	xFecha   DATE;

	CURSOR Plazos_frac IS
	SELECT ID,FECHA
	FROM PLAZOS_FRAC_VOL
	WHERE VOL_EJE='V';
		
BEGIN
	OPEN Plazos_frac;
	LOOP
		FETCH Plazos_frac INTO xPlazoID,xFecha;
	      EXIT WHEN Plazos_frac%NOTFOUND;
		
		IF SYSDATE>xFecha THEN
		   VENCIDO_PLAZO_VOL(xPlazoID);
		END IF;
		
	END LOOP;
	CLOSE Plazos_frac;
END;
/
*/