-- -----------------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez
-- Se han realizado cambios.Rounds en inserciones y updates.
-- -----------------------------------------------------------

--
-- Saber el pendiente de un valor en un momento determinado
-- Se descuentan todas las entregas a cuenta y se calculan los intereses de esas
-- entregas, además se calculan los intereses del principal pendiente.
--

--
-- Modificado: 27-11-2002 Agustín León Robles.
-- No grababa los intereses de demora en la tabla de valores
--
-- Modificado: 18/07/2003. Lucas Fernández Pérez. Añade la posibilidad de generar intereses
--	aún estando el recibo sin acuse o con acuse negativo e ignorando los plazos del art.108
--  si por configuración se indica que genere intereses por adelantado.
--
-- Modificacion: 23/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
-- Modificacion: 05/05/2005 Agustín León Robles. Según nos comenta en Torrejon hay que quitar el calculo
--							de intereses a los valores no notificados aunque en la configuración está activada
--							la opción de intereses por anticipado. Esta opción de configuración solo es para
--							la emisión de las providencias de apremio.
-- Modificacion: 17/05/2005 Lucas Fernández Pérez. Si hay entregas en voluntaria, fallaba en el bucle al llamar 
--							a cal_demora, por lo que se cambia la condición "IF v_INGRESO.PRINCIPAL > 0 THEN"
--							por "IF ((v_INGRESO.PRINCIPAL > 0) AND (v_INGRESO.VOL_EJE='V') )THEN"
/*DELPHI y BASE*/
CREATE OR REPLACE PROCEDURE GetPendienteNow(
	xIDValor		IN 		INTEGER,
	xFIntereses		IN		DATE,
	oPendiente 		OUT 	FLOAT)
AS

xPRINCIPAL_VA 		FLOAT DEFAULT 0;
xPRINCIPAL_IN		FLOAT DEFAULT 0;
xRECARGO_VA  		FLOAT DEFAULT 0;
xRECARGO_IN			FLOAT DEFAULT 0;
xCOSTAS_VA 			FLOAT DEFAULT 0;
xCOSTAS_IN 			FLOAT DEFAULT 0;
xDEMORA_VA 			FLOAT DEFAULT 0;
xDEMORA_IN 			FLOAT DEFAULT 0;

xTipoTributo 		Char(2);
xFinPeVol 			DATE;
xINTERESES 			float default 0;
xSUMA				FLOAT default 0;
xNOTIFICADO			Char(1);
xVolEje				char(1);
xOrden_Apremio 		Integer;
xFNoti				Date;
xPuedo 				INTEGER;
xIDExpe				INTEGER;
xFING				DATE;
xFBAJ				DATE;
xSiCompruebo		boolean default false;

-- Ingresos realizados sobre el valor
CURSOR VALOR_EXPE IS SELECT PRINCIPAL,RECARGO,COSTAS,DEMORA,FECHA,VOL_EJE
		FROM INGRESOS WHERE VALOR=xIDValor;

BEGIN


	oPendiente:=0;

	-- Obtengo el importe total del valor
	SELECT PRINCIPAL,RECARGO,COSTAS,DEMORA,TIPO_DE_TRIBUTO,FIN_PE_VOL,NOTIFICADO,F_NOTIFICACION,ORDEN_APREMIO,
			EXPEDIENTE,F_INGRESO,FECHA_DE_BAJA,VOL_EJE
	INTO xPRINCIPAL_VA,xRECARGO_VA,xCOSTAS_VA,xDEMORA_VA,xTipoTributo,xFinPeVol,xNOTIFICADO,xFNoti,xOrden_Apremio,
			xIDExpe,xFING,xFBAJ,xVolEje
	FROM IMPORTE_VALORES WHERE ID=xIDValor;

	IF (xFING IS NOT NULL) OR (xFBAJ IS NOT NULL) THEN
		RETURN;
	END IF;

	xPuedo:=0;
   
	if xVolEje='E' then
	
		if xNOTIFICADO='S' then
						
			xSiCompruebo:=True;
								
		end if;
   
	end if;
	
	
	if xSiCompruebo then
	
		if PERMITO_CALCULAR_INTERESES(xIDExpe) then
			
			-- Si devuelve un 1 es que se pueden calcular los intereses
			xPuedo:=PLAZO_APREMIO(xFIntereses,xFNoti,xFinPeVol);
				
		end if;
		
	end if;
	
	-- Sumatoria de todos los ingresos y cálculo de los intereses de esas entregas
	FOR v_INGRESO IN VALOR_EXPE LOOP

		xPRINCIPAL_IN:=xPRINCIPAL_IN + v_INGRESO.PRINCIPAL;
		xRECARGO_IN:=xRECARGO_IN + v_INGRESO.RECARGO;
		xDEMORA_IN:=xDEMORA_IN + v_INGRESO.DEMORA;
		xCOSTAS_IN:=xCOSTAS_IN + v_INGRESO.COSTAS;

		IF xPuedo=1 THEN
		
			-- Si había ingresos de principal y no son en voluntaria, calcula la demora hasta la fecha del ingreso
			IF ((v_INGRESO.PRINCIPAL > 0) AND (v_INGRESO.VOL_EJE='E') )THEN

				xINTERESES:=0;
				CAL_DEMORA(v_INGRESO.FECHA, xFinPeVol, xTipoTributo,v_INGRESO.PRINCIPAL, xINTERESES);

				xSUMA:= xSUMA + xINTERESES;

			END IF;
		END IF;

	END LOOP;

	-- principal pendiente es el principal del valor menos el principal de la entregas
	xPRINCIPAL_VA := xPRINCIPAL_VA - xPRINCIPAL_IN;

	xINTERESES:=0;

	-- Si se han cumplido los plazos del art. 108
	IF xPuedo=1 THEN

		-- Si quedaba principal pendiente
		IF xPRINCIPAL_VA > 0 THEN
		
			-- Averiguar los intereses a la fecha del principal pendiente
			CAL_DEMORA(xFIntereses, xFINPEVOL, xTipoTributo, xPRINCIPAL_VA, xINTERESES);
			
		END IF;

		-- Los intereses de las entregas + los intereses pendientes - los intereses ingresados
		-- Intereses pendientes
		xDEMORA_VA:=xSUMA + xINTERESES - xDEMORA_VA;

		update valores set demora_pendiente=round(xDEMORA_VA,2) where id=xIDValor;

	END IF;

	-- Recargo del valor menos los recargos ingresados
	xRECARGO_VA:=xRECARGO_VA - xRECARGO_IN;

	-- Costas del valor menos las costas ingresadas
	xCOSTAS_VA:=xCOSTAS_VA - xCOSTAS_IN;

	-- Pendiente de ingreso a la fecha
	oPendiente := Round(xPRINCIPAL_VA + xRECARGO_VA + xCOSTAS_VA + xDEMORA_VA, 2);


END;
/

/**********************************************************************************
Autor: 13/03/2003 Mª del Carmen Junco Gómez.
Acción: Función que devuelve el principal pendiente de un expediente
**********************************************************************************/
CREATE OR REPLACE FUNCTION EXPE_PRIN_PENDIENTE(
	xIDEXPE	IN	INTEGER) RETURN FLOAT
AS
   xPENDIENTE FLOAT;
   xINGRESADO FLOAT;
   xPRINCIPAL FLOAT;   
   
BEGIN   

   SELECT SUM(PRINCIPAL) INTO xPRINCIPAL
   FROM VALORES 
   WHERE EXPEDIENTE=xIDEXPE AND 
   		 F_INGRESO IS NULL AND
   		 FECHA_DE_BAJA IS NULL AND
   		 F_SUSPENSION IS NULL;
   		 
   SELECT SUM(PRINCIPAL) INTO xINGRESADO
   FROM INGRESOS 
   WHERE VALOR IN (SELECT ID FROM VALORES 
   				   WHERE EXPEDIENTE=xIDEXPE AND 
   		 	    	     F_INGRESO IS NULL AND
   		                 FECHA_DE_BAJA IS NULL AND
   		                 F_SUSPENSION IS NULL);
   		                 
   IF xPRINCIPAL IS NULL THEN
      xPRINCIPAL:=0;
   END IF;
      
   IF xINGRESADO IS NULL THEN
      xINGRESADO:=0;  
   END IF;
   
   xPENDIENTE:=xPRINCIPAL-xINGRESADO;
   
   RETURN(xPENDIENTE); 
   
END;
/

/* ******************************************************************************* */
-- Devuelve el importe pendiente total de un embargo, es decir, de todos los valores
-- que estando en un expediente pertenecen a un embargo.
-- El parametro  xRecalculaDEMORA cuando tiene el valor a S se recalculanlos intereses
--   de demora a la fecha indicada en el parametro xFecha
-- 29-04-2002 Lucas Fernández Pérez
/*BASE*/

CREATE OR REPLACE FUNCTION PENDIENTE_EMBARGO(
	xIDEXPE 		IN 	INTEGER,
	xIDEMBARGO 		IN 	INTEGER,
      xRecalculaDEMORA 	IN 	CHAR,
      xFECHA 		IN	DATE)
RETURN FLOAT

AS

xDEMORA 		FLOAT DEFAULT 0;
xTOTALPENDIENTE	FLOAT DEFAULT 0;
SPENDIENTE		FLOAT DEFAULT 0;

CURSOR cPendiEmbargo IS
   SELECT ID,PENDIENTE
	FROM VALORESEXPE
	WHERE EXPEDIENTE=xIDEXPE AND ID_INMUEBLES = xIDEMBARGO
	AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL AND F_SUSPENSION IS NULL;

BEGIN

   SPENDIENTE:=0;

   IF xRecalculaDEMORA='S' THEN
      CALCDEMORA_EXPE(xIDEXPE, xFECHA, 'S','E', xDEMORA, xTOTALPENDIENTE);
   END IF;

   FOR vPendiEmbargo IN cPendiEmbargo LOOP
      -- SUMATORIA DEL PENDIENTE
    	SPENDIENTE := SPENDIENTE + vPendiEmbargo.PENDIENTE;
   END LOOP;

   RETURN SPENDIENTE;

END;
/

/* ******************************************************************************* */
--
-- Modificado: 25/08/2003. Lucas Fernández Pérez. 
--	Paga_Plazo : se le añaden los parámetros xCanalIngreso y xIDCartaPagoBanco. 
--  Aplicar_Plazo: se le añade el parámetro xCanalIngreso.
--
-- Modificado: 28/08/2003. Lucas Fernández Pérez. 
--  Aplicar_Plazo: se le añade el parámetro xFecha
--	Paga_Plazo : se le añade el campo xFecha en la llamada a aplicar_plazo

-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
-- 	  Aplicar_Plazo: Para saber si se aplica el último plazo, antes se miraba si era 
--		  el de la fecha última. Ahora se mira si hay algún otro plazo con algo pendiente. 
--      El motivo de este cambio es que con las cartas de pago puede ingresarse en orden 
--  	  distinto al de las fechas de los plazos. De este modo pueden ingresarse los plazos
--	      de forma desordenada.
--	  Paga_Plazo: Se añade la fecha de ingreso en la llamada al procedimiento GetNextPlazo
-- Modificado: 01/09/2003. Lucas Fernández Pérez.
--	Paga_Plazo: se le añade el parámetro xCodOpeCartas.Se actualiza ingreso_tramite.
/* ******************************************************************************* */

CREATE OR REPLACE PACKAGE PkIngresos
AS

-- Le enviamos un valor y nos devuelve los importes ingresados
PROCEDURE GET_INGRESADO (xIDValor IN INTEGER, xPRINCIPAL OUT FLOAT, xRECARGO OUT FLOAT,
	xCOSTAS OUT FLOAT, xDEMORA OUT FLOAT);

-- Le pasamos un valor y devuelve lo que queda pendiente de principal,recargo,costas y demora
PROCEDURE GET_PENDIENTE(xIDValor IN INTEGER, oPRINCIPAL OUT	FLOAT,
	oRECARGO OUT FLOAT, oCOSTAS OUT FLOAT, oDEMORA OUT FLOAT,oTOTAL_DEUDA OUT FLOAT);

-- Realiza un ingreso sobre un valor. Actualiza en valores los importes ingresados y pendientes.
PROCEDURE WRITE_INGRESO(xValor IN INTEGER, xTexto IN char, xTipo IN char,
      xFecha IN DATE, xPrincipal IN float, xRecargo IN float,
      xCostas IN float, xDemora IN float,
	xCodOperacion IN INTEGER, xParcial_o_Cobro IN char);

-- Sobrecarga para tratamiento de cobros cuadernillo 60
PROCEDURE WRITE_INGRESO(xValor IN INTEGER, xTexto IN char, xTipo IN char,
      xFecha IN DATE, xPrincipal IN float, xRecargo IN float,
      xCostas IN float, xDemora IN float,
	xCodOperacion IN INTEGER, xParcial_o_Cobro IN char,
	xF_COBRO_BANCO IN DATE, xENTIDAD_COBRO IN CHAR, xOFICINA_COBRO IN CHAR,
	xCanalIngreso IN CHAR, xIngreso_Tramite IN CHAR);


-- Realizar el Pago Total del Expediente
PROCEDURE MAKE_INGRE_RETENIDO(xIDExpe IN INTEGER, xCodOpe IN INT, xFIngre IN DATE, xFIngreBanco IN DATE,
        xSuma IN float, xTipoIngreso IN char, xID_CUENTA IN integer, xMessage	IN Varchar);

-- De un determinado expediente nos devuelve el total pendiente de todos los recibos vivos
-- El parametro  xRecalculaDEMORA cuando tiene el valor a S se recalculanlos intereses
--   de demora a la fecha indicada en el parametro xFecha
PROCEDURE PENDIENTE_EXPE(
	xIDEXPE IN INTEGER, xRecalculaDEMORA IN CHAR, xFECHA IN DATE,
	sPRINCIPAL OUT FLOAT, sRECARGO OUT FLOAT, sCOSTAS OUT FLOAT, sDEMORA OUT FLOAT,
      sPENDIENTE OUT FLOAT);

-- Nos devuelve la diferencia entre el pediente de un expediente y los importes
-- retenidos en los embargos de cuentas
PROCEDURE Get_PendienteRetenido(
        xIDExpe IN INT, xPendiente OUT float);

PROCEDURE PAGA_PLAZO(xID IN INTEGER,xExpe IN INTEGER,xFecha IN DATE,xPlazo IN DATE);

PROCEDURE PAGA_PLAZO(xID IN INTEGER,xExpe IN INTEGER,xFecha IN DATE,
			   xPlazo IN DATE,xFecha_ingreso IN DATE,xEntidad IN CHAR,xOficina IN CHAR,
			   xCanalIngreso IN CHAR, xImporte_ingreso IN FLOAT,xImporte_plazo IN FLOAT,
			   xCuenta IN INTEGER, xIDCartaPagoBanco IN INTEGER,xCodOpeCartas IN INTEGER);

PROCEDURE APLICAR_PLAZO(xID IN INTEGER, xCODOPE IN INTEGER, xPLAZO IN DATE, xFECHA IN DATE);

PROCEDURE APLICAR_PLAZO(xID IN INTEGER,xCODOPE IN INTEGER,xPLAZO IN DATE,xFecha IN DATE,
				xFecha_ingreso IN DATE,xEntidad IN CHAR,xOficina IN CHAR,xCuenta IN INTEGER,
				xCanalIngreso IN CHAR, xImporte_plazo IN FLOAT,xImporte_ingreso IN FLOAT,
				xIDExpe  IN INTEGER);


State_of_I_Animate Integer default 0;

END PkIngresos;
/


-- ******************* Cuerpo del paquete de ingresos **********************************

CREATE OR REPLACE PACKAGE BODY PkIngresos
AS

--
-- Le enviamos un valor y nos devuelve los importes ingresados
--
/*BASE*/
PROCEDURE GET_INGRESADO (
	xIDValor	IN	INTEGER,
	xPRINCIPAL 	OUT	FLOAT,
	xRECARGO 	OUT 	FLOAT,
	xCOSTAS 	OUT 	FLOAT,
	xDEMORA 	OUT 	FLOAT)
AS

BEGIN

   SELECT SUM(PRINCIPAL),SUM(RECARGO),SUM(COSTAS),SUM(DEMORA)
      INTO xPRINCIPAL,xRECARGO,xCOSTAS,xDEMORA
   FROM INGRESOS
   WHERE VALOR=xIDValor;

   IF xPRINCIPAL IS NULL THEN
      xPRINCIPAL:=0;
   END IF;
   IF xRECARGO IS NULL THEN
      xRECARGO:=0;
   END IF;
  IF xCOSTAS IS NULL THEN
     xCOSTAS:=0;
  END IF;
  IF xDEMORA IS NULL THEN
     xDEMORA:=0;
  END IF;

END;

--
-- Le enviamos un valor y nos devuelve los importes pendientes
-- (importe del valor - importes ingresados
--
/*BASE*/
PROCEDURE GET_PENDIENTE(
	xIDValor		IN 	INTEGER,
	oPRINCIPAL 		OUT 	FLOAT,
	oRECARGO 		OUT 	FLOAT,
	oCOSTAS 		OUT 	FLOAT,
	oDEMORA 		OUT	FLOAT,
	oTOTAL_DEUDA 	OUT 	FLOAT)
AS
xPRINCIPAL	FLOAT	DEFAULT 0;
xRECARGO  	FLOAT DEFAULT 0;
xCOSTAS  	FLOAT DEFAULT 0;
xDEMORA  	FLOAT DEFAULT 0;
BEGIN

    oPRINCIPAL:=0;

    -- Obtengo el importe total del valor
    SELECT PRINCIPAL,RECARGO,COSTAS,DEMORA_PENDIENTE
      INTO oPRINCIPAL,oRECARGO,oCOSTAS,oDEMORA
    FROM IMPORTE_VALORES
	WHERE ID=xIDValor;

    -- Obtengo el importe ingresado del valor
    GET_INGRESADO(xIDValor, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA);

    -- Pendiente = Total - Ingresado.
    oPRINCIPAL:=oPRINCIPAL-xPRINCIPAL;
    oRECARGO:=oRECARGO-xRECARGO;
    oCOSTAS:=oCOSTAS-xCOSTAS;
    oTOTAL_DEUDA:=oPRINCIPAL+oRECARGO+oCOSTAS+oDEMORA;

END;

/*BASE*/
-- Realiza un ingreso sobre un valor. Actualiza en valores los importes ingresados y pendientes.
-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
PROCEDURE WRITE_INGRESO(
         xValor           IN INTEGER,
         xTexto           IN char,
         xTipo            IN char,
         xFecha  	        IN DATE,
         xPrincipal  	  IN float,
         xRecargo  	  IN float,
         xCostas  	  IN float,
         xDemora  	  IN float,
         xCodOperacion    IN INTEGER,
         xParcial_o_Cobro IN char)

AS

xAyto   	      char(3);
xZona	    		char(2);
xVol_Eje  	  	char(1);
xContraido    	char(4);
xCargo     	  	char(10);

xSin_Recargo 	float DEFAULT 0;
xRecargo_20  	float DEFAULT 0;
xRecargo_10  	float DEFAULT 0;
xRecargo_5  	float DEFAULT 0;
xRecargoOE		float DEFAULT 0;
xID 	    	INTEGER;
xMES         	CHAR(2);
xYEAR_INGRE  	CHAR(4);
xMANE        	INTEGER DEFAULT 0;
xCuantos		INTEGER DEFAULT 0;
xRecargoValor	float default 0;
xPrincipalValor	FLOAT DEFAULT 0;
xCuotaInicial	FLOAT DEFAULT 0;
xFechaDesde		date;
xFechaHasta		date;
BEGIN


if State_of_I_Animate > 0 then
   Select usuario into xCargo from usuarios;
end if;

xMES:=TO_CHAR(xFECHA, 'MM');
xYEAR_INGRE:=TO_CHAR(xFECHA, 'YYYY');


	IF xParcial_o_Cobro='C' THEN -- Pago del total del importe del valor
		UPDATE VALORES SET F_INGRESO=xFECHA,
	                    COD_INGRESO=xTIPO,
		              ENTREGAS_A_CUENTA=PRINCIPAL+RECARGO+COSTAS+DEMORA+ROUND(xDEMORA,2),
		              DEMORA_PENDIENTE=0,
	                    DEMORA=DEMORA+ROUND(xDEMORA,2),
	                    CODIGO_OPERACION=xCODOPERACION
		WHERE ID=xVALOR
		RETURN AYTO,VOL_EJE,N_CARGO,YEAR_CONTRAIDO,PRINCIPAL,RECARGO,CUOTA_INICIAL,RECARGO_O_E
		INTO xAYTO,xVol_Eje,xCargo,xContraido,xPrincipalValor,xRecargoValor,xCuotaInicial,xRecargoOE;
	ELSE -- Pago de una parte del importe del valor.Se anota y descuenta del pendiente.
		UPDATE VALORES SET COD_INGRESO=xTIPO,
	                    ENTREGAS_A_CUENTA=ENTREGAS_A_CUENTA+
				  			  ROUND(xPRINCIPAL+xRECARGO+xCOSTAS+xDEMORA,2),
			        DEMORA_PENDIENTE=DEMORA_PENDIENTE-ROUND(xDEMORA,2),
			        DEMORA=DEMORA+ROUND(xDEMORA,2),
			        CODIGO_OPERACION=xCODOPERACION

		WHERE ID=xVALOR
		RETURN AYTO,VOL_EJE,N_CARGO,YEAR_CONTRAIDO,PRINCIPAL,RECARGO,CUOTA_INICIAL,RECARGO_O_E
		INTO xAYTO,xVol_Eje,xCargo,xContraido,xPrincipalValor,xRecargoValor,xCuotaInicial,xRecargoOE;

		IF xRecargoOE > 0 THEN
			xRecargoOE:= round( (xPrincipal*xRecargoOE) / xPrincipalValor,2 );
		ELSE
			xRecargoOE:=0;
		END IF;

	END IF;
	

   -- Averiguar que porcentaje es el recargo sobre el principal 5, 10% o 20%
   IF (xRecargo > 0) THEN
   
	if Round(xCuotaInicial * 5 / 100, 2)= xRecargoValor then
		xRecargo_5:=xRecargo;
	elsif Round(xCuotaInicial * 10 / 100, 2)= xRecargoValor then
		xRecargo_10:=xRecargo;
	else
		xRecargo_20:=xRecargo;
	end if;

   ELSE
	--puede ser un ingreso de solo costas
	IF ((xRecargoValor=0) And (xVol_Eje='E')) THEN
		xSin_Recargo:=xPrincipal;
	END IF;

   END IF;


   SELECT LAST_TAREA,ZONA INTO xMANE,xZONA
   FROM USUARIOS WHERE USUARIO=USER;

--
--
-- PROCESO ESPECIAL PARA LA DIPUTACION DE GRANADA MIENTRAS ESTEN GRABANDO INGRESOS DE
--	REGULARIZACION DE LA JUNTA O DE LOS AYUNTAMIENTOS. CUANDO TERMINEN DE GRABAR LOS INGRESOS
--	DE REGULARIZACION HABRA QUE QUITAR
--

	/*
	select min(Fecha_Desde) into xFechaDesde from datas_ingresos where zona=xZona;

	select max(Fecha_Hasta) into xFechaHasta from datas_ingresos where zona=xZona;

	if (xFecha >= xFechaDesde) and (xFecha<=xFechaHasta) then
		raise_application_error(-20001,'No se pueden realizar ingresos con fecha: '
			||to_char(xFecha,'dd/mm/yyyy')||' porque hay una data ');
	end if;
	*/


   -- Controlar que no se puedan realizar ingresos con fechas anteriores a una data
   select count(*) into xCuantos
	from datas_ingresos where zona=xZona and Fecha_Hasta>xFECHA;

   if xCuantos>0 then
	raise_application_error(-20001,'No se pueden realizar ingresos con fecha: '
			||to_char(xFecha,'dd/mm/yyyy')||' porque hay una data ');
   end if;

   -- GUARDAMOS EN EL MANEJADOR EL ID DEL PLAZO PARA PODER
   -- BORRAR EL INGRESO DEL PLAZO MAS FACILMENTE
   IF (xTIPO NOT IN ('FE','FV','EF','F1','F2')) THEN
      xMANE:=0;
   END IF;

   INSERT INTO INGRESOS(AYTO, CARGO, CODIGO_OPERACION, VALOR, YEAR_CONTRAIDO,FECHA,MES,
       YEAR_INGRE, PARCIAL_O_COBRO, TIPO_INGRESO, ZONA, VOL_EJE, CONCEPTO, PRINCIPAL,
	 RECARGO, COSTAS, DEMORA, RECARGO_5, RECARGO_10, RECARGO_20, SIN_RECARGO, MANEJADOR, RECARGO_O_E)

   VALUES(xAYTO, xCARGO, xCODOPERACION, xVALOR, xCONTRAIDO, xFECHA, xMES,
	    xYEAR_INGRE, xPARCIAL_O_COBRO, xTIPO, xZONA, xVOL_EJE, xTexto,
	    ROUND(xPRINCIPAL,2), ROUND(xRECARGO,2), ROUND(xCOSTAS,2), ROUND(xDEMORA,2),
	    ROUND(xRECARGO_5,2), ROUND(xRECARGO_10,2), ROUND(xRECARGO_20,2), ROUND(xSIN_RECARGO,2), xMANE, xRecargoOE);
END;

/* *********************************************************************** */
/* Funcion sobrecargada */

-- En este caso es para los cobros en entidades financieras. En el caso de cobros
-- cuadernillo 60 xENTIDAD_COBRO y xOFICINA_COBRO tendrán un valor. en el resto de
-- ingresos estos valores vendrán a null
--
--  Tenemos los siguientes campos:
--			xTipo: tipo de ingreso
--			xCanalIngreso: canal de ingreso, Pago en ventanilla, Pago en internet,
--						Pago mediante cajero
--			xIngreso_Tramite: de forma resumida, mediante que tramite se ha pagado. Solo
--						sirve para las estadisticas.
-- Modificacion: 14/06/2004 Agustín León Robles. Cambios de la Nueva Ley General Tributaria
/*BASE*/
PROCEDURE WRITE_INGRESO(
	xValor 		IN INTEGER,
	xTexto 		IN char,
	xTipo 		IN char,
      xFecha 		IN DATE,
	xPrincipal 		IN float,
	xRecargo 		IN float,
      xCostas 		IN float,
	xDemora 		IN float,
	xCodOperacion 	IN INTEGER,
	xParcial_o_Cobro 	IN char,
	xF_COBRO_BANCO 	IN DATE,
	xENTIDAD_COBRO 	IN CHAR,
	xOFICINA_COBRO 	IN CHAR,
	xCanalIngreso	IN CHAR,
	xIngreso_Tramite	IN CHAR)
AS

xAyto   	    char(3);
xZona	    	char(2);
xVol_Eje  	  	char(1);
xContraido    	char(4);
xCargo     	  	char(10);

xSin_Recargo 	float DEFAULT 0;
xRecargo_20  	float DEFAULT 0;
xRecargo_10  	float DEFAULT 0;
xRecargo_5  	float DEFAULT 0;
xRecargoOE		float DEFAULT 0;
xID 	    	INTEGER;
xMES         	CHAR(2);
xYEAR_INGRE  	CHAR(4);
xMANE        	INTEGER DEFAULT 0;
xCuantos		INTEGER DEFAULT 0;
xPARTE_DEL_DIA    INTEGER;
xCUENTA		INT;
xRecargoValor	float default 0;
xPrincipalValor	FLOAT DEFAULT 0;
xCuotaInicial	float default 0;
xFechaDesde		date;
xFechaHasta		date;
BEGIN


if State_of_I_Animate > 0 then
   Select ayto into xMes from Municipios;
end if;


xMES:=TO_CHAR(xFECHA, 'MM');

xYEAR_INGRE:=TO_CHAR(xFECHA, 'YYYY');


	IF xParcial_o_Cobro='C' THEN
		UPDATE VALORES SET F_INGRESO=xFECHA,
	                    COD_INGRESO=xTIPO,
		              ENTREGAS_A_CUENTA=PRINCIPAL+RECARGO+COSTAS+DEMORA+ROUND(xDEMORA,2),
		              DEMORA_PENDIENTE=0,
	                    DEMORA=DEMORA+ROUND(xDEMORA,2),
	                    CODIGO_OPERACION=xCODOPERACION
		WHERE ID=xVALOR
		RETURN AYTO,VOL_EJE,N_CARGO,YEAR_CONTRAIDO,PRINCIPAL,RECARGO,CUOTA_INICIAL,RECARGO_O_E
		INTO xAYTO,xVol_Eje,xCargo,xContraido,xPrincipalValor,xRecargoValor,xCuotaInicial,xRecargoOE;
	ELSE
		UPDATE VALORES SET COD_INGRESO=xTIPO,
	                    ENTREGAS_A_CUENTA=ENTREGAS_A_CUENTA+
							ROUND(xPRINCIPAL+xRECARGO+xCOSTAS+xDEMORA,2),
			        DEMORA_PENDIENTE=DEMORA_PENDIENTE-ROUND(xDEMORA,2),
			        DEMORA=DEMORA+ROUND(xDEMORA,2),
			        CODIGO_OPERACION=xCODOPERACION

		WHERE ID=xVALOR
		RETURN AYTO,VOL_EJE,N_CARGO,YEAR_CONTRAIDO,PRINCIPAL,RECARGO,CUOTA_INICIAL,RECARGO_O_E
		INTO xAYTO,xVol_Eje,xCargo,xContraido,xPrincipalValor,xRecargoValor,xCuotaInicial,xRecargoOE;

		IF xRecargoOE > 0 THEN
			xRecargoOE:= round( (xPrincipal*xRecargoOE) / xPrincipalValor,2 );
		ELSE
			xRecargoOE:=0;
		END IF;

	END IF;

	
   -- Averiguar que porcentaje es el recargo sobre el principal 5, 10% o 20%
   IF (xRecargo > 0) THEN

	if Round(xCuotaInicial * 5 / 100, 2)= xRecargoValor then
		xRecargo_5:=xRecargo;
	elsif Round(xCuotaInicial * 10 / 100, 2)= xRecargoValor then
		xRecargo_10:=xRecargo;
	else
		xRecargo_20:=xRecargo;
	end if;


   ELSE
	--puede ser un ingreso de solo costas
	IF ((xRecargoValor=0) And (xVol_Eje='E')) THEN
		xSin_Recargo:=xPrincipal;
	END IF;

   END IF;


   SELECT LAST_TAREA,ZONA,LAST_NUMERO,LAST_BAJA INTO xMANE,xZONA,xPARTE_DEL_DIA,xCUENTA
   FROM USUARIOS WHERE USUARIO=USER;



--
--
-- PROCESO ESPECIAL PARA LA DIPUTACION DE GRANADA MIENTRAS ESTEN GRABANDO INGRESOS DE
--	REGULARIZACION DE LA JUNTA O DE LOS AYUNTAMIENTOS. CUANDO TERMINEN DE GRABAR LOS INGRESOS
--	DE REGULARIZACION HABRA QUE QUITAR
--

	/*
	select min(Fecha_Desde) into xFechaDesde from datas_ingresos where zona=xZona;

	select max(Fecha_Hasta) into xFechaHasta from datas_ingresos where zona=xZona;

	if (xFecha >= xFechaDesde) and (xFecha<=xFechaHasta) then
		raise_application_error(-20001,'No se pueden realizar ingresos con fecha: '
			||to_char(xFecha,'dd/mm/yyyy')||' porque hay una data ');
	end if;
	*/


   -- Controlar que no se puedan realizar ingresos con fechas anteriores a una data
   select count(*) into xCuantos
	from datas_ingresos where zona=xZona and Fecha_Hasta>xFECHA;

   if xCuantos>0 then
	raise_application_error(-20001,'No se pueden realizar ingresos con fecha: '
			||to_char(xFecha,'dd/mm/yyyy')||' porque hay una data ');
   end if;


   -- GUARDAMOS EN EL MANEJADOR EL ID DEL PLAZO PARA PODER
   --   BORRAR EL INGRESO DEL PLAZO MAS FACILMENTE
   IF (xTIPO NOT IN ('FE','FV','EF','F1','F2')) THEN
       xMANE:=0;
   END IF;


   INSERT INTO INGRESOS(AYTO, CARGO, CODIGO_OPERACION, VALOR, YEAR_CONTRAIDO,FECHA,MES,
       YEAR_INGRE, PARCIAL_O_COBRO, TIPO_INGRESO, ZONA, VOL_EJE, CONCEPTO, PRINCIPAL,
	 RECARGO, COSTAS, DEMORA, RECARGO_5, RECARGO_10, RECARGO_20, SIN_RECARGO, MANEJADOR,
	 F_COBRO_BANCO, ENTIDAD_COBRO, OFICINA_COBRO, CANAL_INGRESO, INGRESO_TRAMITE,
	 PARTE_DEL_DIA,CUENTA,RECARGO_O_E)

   VALUES(xAYTO, xCARGO, xCODOPERACION, xVALOR, xCONTRAIDO, xFECHA, xMES,
	    xYEAR_INGRE, xPARCIAL_O_COBRO, xTIPO, xZONA, xVOL_EJE, xTexto,
	    ROUND(xPRINCIPAL,2), ROUND(xRECARGO,2), ROUND(xCOSTAS,2), ROUND(xDEMORA,2),
	    ROUND(xRECARGO_5,2), ROUND(xRECARGO_10,2), ROUND(xRECARGO_20,2), ROUND(xSIN_RECARGO,2),
	    xMANE, xF_COBRO_BANCO, xENTIDAD_COBRO, xOFICINA_COBRO,
	    DECODE(xCanalIngreso,'',null,xCanalIngreso),xIngreso_Tramite,
	    xPARTE_DEL_DIA,xCUENTA,xRecargoOE);

END;


/* ****************************************** */
/* REALIZAR EL PAGO DEL TOTAL DEL EXPEDIENTE  */
/*BASE*/
-- Modificacion: 14/04/2005. Lucas Fernández Pérez. 
-- Nuevo parámetro xFIngre con la fecha de ingreso en la aplicación de la retención. Se pone esa fecha sólo en
--  la tabla INGRESOS, dejando en el seguimiento y al ingresar el expediente (y en mov_cuentas) como fecha Sysdate.
--
PROCEDURE MAKE_INGRE_RETENIDO(
        xIDExpe      IN INTEGER,
        xCodOpe      IN INT,
        xFIngre      IN DATE,
        xFIngreBanco IN DATE,
        xSuma      	 IN float,
        xTipoIngreso IN char,
        xID_CUENTA 	 IN integer,
        xMessage   	 IN Varchar)
AS

xValor  int;
xPrincipal  float;
xRecargo  float;
xCostas  float;
xDemora  float;
xTotal_Deuda float;
xInteres  float;
xPARC_COBRO CHAR(1) DEFAULT 'C';
xEN_OTROTRAMITE	CHAR(1);

CURSOR C1 IS
	Select id,vol_eje
	    from valores
	         WHERE EXPEDIENTE=xIDExpe
 	         and F_ingreso is null
		   and fecha_de_baja is null
		   and F_suspension is null;


BEGIN


  Insert Into SEGUIMIENTO
        (ID_EXPE, F_ACTUACION, DESCRIPCION,  DEBE_O_HABER,
         IMPORTE, ID_RETENIDO_CUENTA, ID_INGRESOS)
  values
        (xIDExpe, SYSDATE, xMessage,
         'H', ROUND(xSuma,2), xID_Cuenta, xCodOpe );

   FOR v_C1 IN C1 LOOP

      Get_Pendiente( v_C1.ID, xPrincipal, xRecargo,
                     xCostas, xDemora, xTOTAL_DEUDA);

      WRITE_INGRESO( v_C1.ID, xMessage,
                    xTipoIngreso, xFIngre, xPrincipal,
	 	        xRecargo, xCostas, xDemora, xCodOpe,
			  xPARC_COBRO,xFIngreBanco,NULL,NULL,NULL,'1');

   END LOOP;

   /* Actualizamos el expediente como pagado */
   UPDATE EXPEDIENTES SET F_INGRESO=SYSDATE,
	                    CARTA_PAGO='P',
		              codigo_ingreso=xTipoIngreso
   WHERE ID=xIDExpe
   RETURN EN_OTROTRAMITE INTO xEN_OTROTRAMITE;

   IF xEN_OTROTRAMITE='S' THEN
      LEVANTA_INMUEBLES(xIDExpe);
      UPDATE EXPEDIENTES SET en_otrotramite='N' where id=xIDExpe;
   END IF;

END;


/* ************************************************* */
-- Devuelve el importe pendiente total de un expediente
-- El parametro  xRecalculaDEMORA cuando tiene el valor a S se recalculanlos intereses
--   de demora a la fecha indicada en el parametro xFecha
/*BASE*/
PROCEDURE PENDIENTE_EXPE(
	xIDEXPE 		IN 	INTEGER,
      xRecalculaDEMORA 	IN 	CHAR,
      xFECHA 		IN	DATE,
      SPRINCIPAL 		OUT 	FLOAT,
      SRECARGO 		OUT 	FLOAT,
      SCOSTAS 		OUT 	FLOAT,
      SDEMORA 		OUT 	FLOAT,
      SPENDIENTE 		OUT 	FLOAT)

AS

xINGRPRIN 		FLOAT DEFAULT 0;
xINGRRECA 		FLOAT DEFAULT 0;
PCOSTAS 		FLOAT DEFAULT 0;
PDEMORA 		FLOAT DEFAULT 0;
IPRINCIPAL 		FLOAT DEFAULT 0;
IRECARGO 		FLOAT DEFAULT 0;
ICOSTAS 		FLOAT DEFAULT 0;
xTOTALPENDIENTE	FLOAT DEFAULT 0;

CURSOR cPendiExpe IS
   SELECT ID,PRINCIPAL,RECARGO,COSTAS,PENDIENTE
	FROM VALORESEXPE
	WHERE EXPEDIENTE=xIDEXPE
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL;

BEGIN

   SPRINCIPAL:=0;
   SRECARGO:=0;
   SCOSTAS:=0;
   SDEMORA:=0;
   SPENDIENTE:=0;
   xTOTALPENDIENTE:=0;


   FOR vPendiExpe IN cPendiExpe LOOP

      -- SUMATORIA DEL PENDIENTE

    	SPENDIENTE := SPENDIENTE + vPendiExpe.PENDIENTE;
    	SPRINCIPAL := SPRINCIPAL + vPendiExpe.PRINCIPAL;
    	SRECARGO := SRECARGO + vPendiExpe.RECARGO;
    	SCOSTAS := SCOSTAS + vPendiExpe.COSTAS;

	--COGER LOS IMPORTES DE LO ANTERIORMENTE INGRESADO

	GET_INGRESADO(vPendiExpe.ID, xINGRPRIN, xINGRRECA, PCOSTAS, PDEMORA);

	--SUMATORIA DE LOS INGRESOS

      IPRINCIPAL := IPRINCIPAL + xINGRPRIN;
      IRECARGO := IRECARGO + xINGRRECA;
      ICOSTAS := ICOSTAS + PCOSTAS;

   END LOOP;

   IF xRecalculaDEMORA='S' THEN
      CALCDEMORA_EXPE(xIDEXPE, xFECHA, 'S','E', SDEMORA, xTOTALPENDIENTE);
      SPENDIENTE:=xTOTALPENDIENTE;
   END IF;

   SPENDIENTE := SPENDIENTE;
   SPRINCIPAL := SPRINCIPAL - IPRINCIPAL;
   SRECARGO := SRECARGO - IRECARGO;
   SCOSTAS := SCOSTAS - ICOSTAS;

END;

/* ******************************************************************************* */
-- Nos devuelve la diferencia entre el pendiente de un expediente y los importes
--   retenidos en los embargos de cuentas
/*BASE*/
PROCEDURE Get_PendienteRetenido(
        xIDExpe 	IN	INT,
        xPendiente OUT	float)
AS

xRetenido 		float DEFAULT 0;
sPrincipal 		float default 0;
sRecargo 		float default 0;
sCostas 		float default 0;
sDemora 		float default 0;
sPendiente 		float default 0;
xFECHAACTUAL	DATE;

BEGIN

   xPendiente:=0;
   xFECHAACTUAL:=SYSDATE;

   PENDIENTE_EXPE(xIDEXPE , 'N', xFECHAACTUAL,
                sPrincipal, sRecargo, sCostas,
                sDemora, sPendiente);

   Select Sum(IMPORTE_RETENIDO) INTO xRetenido
   from Cuentas_lotes where IDExpe=xIDExpe and hecho='N';

   if xRetenido is null then
      xRetenido:=0;
   end if;

   xPendiente:=sPendiente-xRetenido;

END;


/*INTERNO*/
PROCEDURE APLICAR_PLAZO(
		xID        IN INTEGER,
      	xCODOPE    IN INTEGER,
	    xPLAZO     IN DATE,
	    xFecha	   IN DATE)
AS

xPrin FLOAT DEFAULT 0;
xReca FLOAT DEFAULT 0;
xGastos FLOAT DEFAULT 0;
xInteres FLOAT DEFAULT 0;

xHayOtrosPlazos INTEGER;

xMensaje char(50);

CURSOR PLAZO_EXPE IS SELECT ID,INGRESADO,VALOR,
		ENTREGAS,PRINCIPAL,RECARGO,COSTAS,DEMORA,IMPORTE,PENDIENTE
      FROM vwplazos_frac
	  WHERE FRACCIONA=xID
		And FECHA=xPlazo And PENDIENTE > 0; -- Si no tiene pendiente, no genero ingreso


BEGIN

   -- Si queda algún plazo sin ingresar de otra fecha, el ingreso que vamos a realizar 
   -- no es el pago que cierra el fraccionamiento.
   SELECT COUNT(*) INTO xHayOtrosPlazos FROM PLAZOS_FRAC 
   WHERE FRACCIONA=xID AND INGRESADO <> 'S' AND FECHA<>xPLAZO;

   FOR v_Plazo_Expe IN Plazo_Expe LOOP

      /*PAGA UN PLAZO DEL FRACCIONAMIENTO*/
      if (v_Plazo_Expe.INGRESADO='N') then
         xMensaje:='Plazo del fraccionamiento del MES ' ||
             Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);
         xPrin:=v_Plazo_Expe.PRINCIPAL;
         xReca:=v_Plazo_Expe.RECARGO;
         xGastos:=v_Plazo_Expe.COSTAS;
         xInteres:=v_Plazo_Expe.DEMORA;
      else

         /*Repartir el importe de la entrega entre
          	principal,recargo,costas, etc.*/

         reparto_frac(v_Plazo_Expe.Pendiente,v_Plazo_Expe.IMPORTE,
                      v_Plazo_Expe.Principal,v_Plazo_Expe.Recargo,
                      v_Plazo_Expe.Costas,v_Plazo_Expe.Demora,
                      xPrin,xReca,xGastos,xInteres);

         xMensaje:='Pago parcial de un plazo fraccionamiento';
      end IF;


      /* LE PASAMOS EL ID DEL PLAZO PARA EN EL TR_INGRE_AI
         SE LO PODAMOS ESCRIBIR EN LA TABLA DE INGRESOS */
      UPDATE USUARIOS SET LAST_TAREA=v_Plazo_Expe.ID WHERE USUARIO=USER;

   IF xHayOtrosPlazos=0 THEN
		PkIngresos.WRITE_INGRESO(v_Plazo_Expe.VALOR,xMensaje,'FE',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'C');
	ELSE
		PkIngresos.WRITE_INGRESO(v_Plazo_Expe.VALOR,xMensaje,'EF',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P');
	END IF;

   END LOOP;


END;

/* *********************************************************************** */
/* Funcion sobrecargada 								   */
/* Para los cobros en entidades financieras					   */
/*INTERNO*/
PROCEDURE APLICAR_PLAZO(
		xID        IN INTEGER,
      	xCODOPE    IN INTEGER,
	    xPLAZO     IN DATE,
	    xFecha IN DATE,
		xFecha_ingreso IN DATE,
		xEntidad IN CHAR,
		xOficina IN CHAR,
		xCuenta  IN INTEGER,
		xCanalIngreso IN CHAR,
		xImporte_plazo IN FLOAT,
		xImporte_ingreso IN FLOAT,
		xIDExpe  IN INTEGER)

AS

xPrin FLOAT DEFAULT 0;
xReca FLOAT DEFAULT 0;
xGastos FLOAT DEFAULT 0;
xInteres FLOAT DEFAULT 0;

xHayOtrosPlazos INTEGER;

xMensaje char(50);


CURSOR PLAZO_EXPE IS SELECT ID,INGRESADO,VALOR,ENTREGAS,
			PRINCIPAL,RECARGO,COSTAS,DEMORA,IMPORTE,PENDIENTE
      FROM vwplazos_frac
	  WHERE FRACCIONA=xID
		And FECHA=xPlazo And PENDIENTE > 0; -- Si no tiene pendiente, no genero ingreso


BEGIN
-- Si queda algún plazo sin ingresar de otra fecha, no es el pago que cierra el fraccionam.
   SELECT COUNT(*) INTO xHayOtrosPlazos FROM PLAZOS_FRAC 
   WHERE FRACCIONA=xID AND INGRESADO <> 'S' AND FECHA<>xPLAZO;

   xMensaje:='PAGO DE PLAZO FRACCIONAMIENTO EN EJECUTIVA';
   IF xHayOtrosPlazos=0 THEN
    COBROS_BANCOS_EXPE(xIDExpe,xCuenta,xCodOpe,'FE',
                      xImporte_ingreso,xImporte_plazo,
			    xFecha_ingreso,xMensaje);
   ELSE
      COBROS_BANCOS_EXPE(xIDExpe,xCuenta,xCodOpe,'EF',
                      xImporte_ingreso,xImporte_plazo,
			    xFecha_ingreso,xMensaje);
   END IF;


   FOR v_Plazo_Expe IN Plazo_Expe
   LOOP

	/*PAGA UN PLAZO DEL FRACCIONAMIENTO*/
    if (v_Plazo_Expe.Ingresado='N') then
	   xMensaje:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);
         xPrin:=v_Plazo_Expe.PRINCIPAL;
         xReca:=v_Plazo_Expe.RECARGO;
         xGastos:=v_Plazo_Expe.COSTAS;
	   xInteres:=v_Plazo_Expe.DEMORA;
	else
         /*Repartir el importe de la entrega entre
         principal,recargo,costas, etc.*/

         reparto_frac(v_Plazo_Expe.Pendiente,v_Plazo_Expe.Importe,
                      v_Plazo_Expe.Principal,v_Plazo_Expe.Recargo,
                      v_Plazo_Expe.Costas,v_Plazo_Expe.Demora,
                      xPrin,xReca,xGastos,xInteres);

         xMensaje:='Pago parcial de un plazo fraccionamiento';
      end IF;

      /* LE PASAMOS EL ID DEL PLAZO PARA EN EL TR_INGRE_AI
      SE LO PODAMOS ESCRIBIR EN LA TABLA DE INGRESOS */
      UPDATE USUARIOS SET LAST_TAREA=v_Plazo_Expe.ID,LAST_BAJA=xCuenta
      WHERE USUARIO=USER;

   IF xHayOtrosPlazos=0 THEN
		PkIngresos.WRITE_INGRESO(v_Plazo_Expe.VALOR,xMensaje,'FE',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'C',
			xFecha_ingreso,xEntidad,xOficina,xCanalIngreso,'F');
	ELSE
	      PkIngresos.WRITE_INGRESO(v_Plazo_Expe.VALOR,xMensaje,'EF',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P',
			xFecha_ingreso,xEntidad,xOficina,xCanalIngreso,'F');
	END IF;

   END LOOP;

END;


/* *********************************************************************** */
/* Funcion sobrecargada 								   */
/* Para los cobros en entidades financieras					   */
/*BASE*/
PROCEDURE PAGA_PLAZO(
        xID    IN INTEGER,
		xExpe  IN INTEGER,
	    xFecha IN DATE,
		xPlazo IN DATE,
		xFecha_ingreso IN DATE,
		xEntidad IN CHAR,
		xOficina IN CHAR,
		xCanalIngreso IN CHAR,
		xImporte_ingreso IN FLOAT,
		xImporte_plazo IN FLOAT,
		xCuenta IN INTEGER,
		xIDCartaPagoBanco IN INTEGER,
		xCodOpeCartas IN INTEGER)

AS

IMPO_NEXT FLOAT DEFAULT 0;
yFecha DATE;
impo_entre FLOAT DEFAULT 0;
xCiego integer DEFAULT 0;
xPENDIENTE FLOAT DEFAULT 0;
xMENSAJE CHAR(90);

BEGIN

   yFecha:=Null;

   -- leer lo que queda pendiente del plazo
   SELECT SUM(PENDIENTE) INTO xPENDIENTE
   FROM vwPLAZOS_FRAC
   WHERE FRACCIONA=xID
         and FECHA=xPlazo
         and ingresado<>'S';

   if xPENDIENTE is Null then
      return;
   end if;

   --aumenta el contador de codigo de operación y lo escribe en la tabla de usuarios
   CODIGO_OPERACION(xCiego);

   -- lanzar APLICAR_PLAZO, para hacer el ingreso
   PKIngresos.APLICAR_PLAZO( xID, xCiego, xPLAZO, xFecha, xFecha_ingreso,
			xEntidad, xOficina,xCuenta,xCanalIngreso,xImporte_plazo,
			xImporte_ingreso,xExpe);
			
	-- Actualizo en los ingresos recién realizados el campo idcartapagobanco
   if xIDCartaPagoBanco is not null then
   	UPDATE INGRESOS SET IDCARTAPAGOBANCO=xIDCartaPagoBanco,
   		   	COD_OPERACION_CARTAS_PAGO=xCodOpeCartas 
	WHERE CODIGO_OPERACION=xCiego;
   end if;

   --Anotar el movimento en el seguimiento de ingresos de frac.
   --No hace falta el campo tipo pues va por default plazo
   INSERT INTO INGRESOS_FRAC
        (FRAC,FECHA,F_PLAZO,COD_INGRESO,IMPORTE)
   VALUES (xID,xFecha,xPlazo,xCiego,xPENDIENTE);

   xMENSAJE:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);

   INSERT INTO SEGUIMIENTO(ID_EXPE,F_ACTUACION,DESCRIPCION,
          IMPORTE,DEBE_O_HABER,ID_INGRESOS)
   VALUES (xExpe,xFecha,xMENSAJE,xPENDIENTE,'H',xCiego);

   update PLAZOS_FRAC set F_INGRESO=xFecha,
	                    INGRESADO='S'
   where FRACCIONA=xID
         and FECHA=xPlazo
         and ingresado<>'S';

   --Coge la fecha del siguiente plazo. En caso contrario da por cobrados los recibos
   --cierra el expediente y los fraccionamientos
   get_next_plazo(xID, xFecha, yFecha);

   --suma el importe del proximo plazo y las entregas a cuenta
   SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS S1,
          SUM(ENTREGAS) AS S2
   INTO IMPO_NEXT,impo_entre
   FROM vwPLAZOS_FRAC
   where FRACCIONA=xID
         AND FECHA=yFecha;

   --actualiza los totalizadores del fraccionamiento
   update FRACCIONAMIENTO SET PAGADO=PAGADO+xPENDIENTE,
	                        IMPO_NEXT_PLAZO= IMPO_NEXT - impo_entre,
              		      F_NEXT_PLAZO=yFecha
   where ID=xID;

END;

/*BASE*/
PROCEDURE PAGA_PLAZO(
        xID    IN INTEGER,
		xExpe  IN INTEGER,
	    xFecha IN DATE,
		xPlazo IN DATE)

AS

IMPO_NEXT FLOAT DEFAULT 0;
yFecha DATE;
impo_entre FLOAT DEFAULT 0;
xCiego integer DEFAULT 0;
xPENDIENTE FLOAT DEFAULT 0;
xMENSAJE CHAR(90);
BEGIN

   yFecha:=Null;

   -- leer lo que queda pendiente del plazo
   SELECT SUM(PENDIENTE) INTO xPENDIENTE FROM vwPLAZOS_FRAC
   WHERE FRACCIONA=xID and FECHA=xPlazo and ingresado<>'S';

   if xPENDIENTE is Null then
	return;
   end if;

   --aumenta el contador de codigo de operación y lo escribe en la tabla de usuarios
   CODIGO_OPERACION(xCiego);

   -- lanzar, para hacer el ingreso
   PKIngresos.APLICAR_PLAZO(xID,xCiego,xPLAZO,xFecha);

   -- Se indica que el tramite de ingreso es de fraccionamiento.
   UPDATE INGRESOS SET INGRESO_TRAMITE='F' WHERE CODIGO_OPERACION=xCiego;

   --Anotar el movimento en el seguimiento de ingresos de frac.
   --No hace falta el campo tipo pues va por default plazo
   INSERT INTO INGRESOS_FRAC (FRAC,FECHA,F_PLAZO,COD_INGRESO,IMPORTE)
   VALUES (xID,xFecha,xPlazo,xCiego,xPENDIENTE);

   xMENSAJE:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);

   INSERT INTO SEGUIMIENTO(ID_EXPE,F_ACTUACION,DESCRIPCION,
          IMPORTE,DEBE_O_HABER,ID_INGRESOS)
   VALUES (xExpe,xFecha,xMENSAJE,xPENDIENTE,'H',xCiego);

   update PLAZOS_FRAC set F_INGRESO=xFecha,INGRESADO='S'
   where FRACCIONA=xID and FECHA=xPlazo and ingresado<>'S';

   --Coge la fecha del siguiente plazo. En caso contrario da por cobrados los recibos
   --cierra el expediente y los fraccionamientos
   Get_Next_Plazo(xID, xFecha, yFecha);

   --suma el importe del proximo plazo y las entregas a cuenta
   SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS S1, SUM(ENTREGAS) AS S2
   INTO IMPO_NEXT,impo_entre
   FROM vwPLAZOS_FRAC where FRACCIONA=xID AND FECHA=yFecha;

   --actualiza los totalizadores del fraccionamiento
   update FRACCIONAMIENTO SET PAGADO=PAGADO+xPENDIENTE,
	                      IMPO_NEXT_PLAZO= IMPO_NEXT - impo_entre,
              		      F_NEXT_PLAZO=yFecha
   where ID=xID;

END;


-- Inicializar el paquete

BEGIN

SELECT EstadoIani INTO State_of_I_Animate FROM DATOSPERR;

END;
/
