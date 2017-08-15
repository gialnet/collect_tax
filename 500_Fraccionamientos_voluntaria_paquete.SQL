-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.(ROUNDS)
--
-- Modificado: 29/08/2003. Lucas Fernández Pérez.
--	Paga_Plazo_Vol: se elimina el parámetro xIDPlazo
--					se le añaden los parámetros xCanalIngreso y xIDCartaPagoBanco. 
--					se ajusta la llamada a get_next_plazo_vol
--  Aplicar_Plazo_Vol: se le añaden los parámetros xCanalIngreso y xFecha. 
--		 Cambia la antigua llamada a write_ingresovol por la llamada a write_ingreso.
--  CheckCierreFrac: se le añade el parámetro xFechaIngreso
--  Get_Next_Plazo_Vol: se le añade el parámetro xFechaIngreso
-- Modificado: 01/09/2003. Lucas Fernández Pérez.
--	Paga_Plazo_Vol: se le añade el parámetro xCodOpeCartas. Se actualiza ingreso_tramite.
-- -----------------------------------------------------
CREATE OR REPLACE PACKAGE PKFraccionamientosVol
AS
/******************************************************************************/
/* 	PROCEDIMIENTO	: Cierra un fraccionamiento si tiene todos sus 		*/
/*				  plazos pagados.						      */
/*	Parametros Entrada:									*/
/*					xIDFrac INTEGER, Identificador del Fracc.		*/
/*					xFechaIngreso DATE, Fecha de ingreso del fracc.		*/
/******************************************************************************/
/*BASE*/
PROCEDURE CheckCierreFrac(xIDFrac IN INTEGER, xFechaIngreso IN DATE);

/******************************************************************************/
/* 	PROCEDIMIENTO	: Calcula el siguiente plazo a pagar de un fracc.     */
/*	Parametros Entrada:									*/
/*					xIDFrac INTEGER, Identificador del Fracc.		*/
/*					xFechaIngreso DATE, Fecha de Ingreso del fracc. si no hay mas plazos */
/*	Parametros Salida:	xFECHA DATE, Fecha del siguiente plazo  		*/
/******************************************************************************/
/*BASE*/
PROCEDURE GET_NEXT_PLAZO_VOL(xIDFrac IN INTEGER,xFechaIngreso IN DATE, xFecha  OUT DATE);

/* ****************************************************************************/
/* PROCEDIMIENTO: REALIZA EL PAGO DE UN PLAZO EN VOLUNTARIA				*/
/*			SOBRECARGADA PARA PAGOS DOMICILIADOS				*/
/* Parametros Entrada:										*/
/*			xID INTEGER, Identificador del fraccionamiento    		*/
/*			xFecha DATE, Fecha del pago						*/
/*			xPlazo DATE, Fecha de vencimiento del plazo			*/
/* Parametros Sobrecargados:									*/
/*			xFecha_ingreso DATE, Fecha del ingreso en entidad		*/
/*			xEntidad CHAR, Entidad de cobro					*/
/*			xOficina CHAR, Oficina de cobro					*/
/*			xCanalIngreso CHAR, Canal de ingreso					*/
/*			xImporte_ingreso FLOAT, Importe del ingreso realizado		*/
/*			xImporte_plazo FLOAT, Importe del plazo				*/
/*			xCuenta IN INTEGER, Numero de cuenta de ingreso			*/
/*			xIDCartaPagoBanco IN INTEGER, Identificador de carta de pago			*/
/*			xCodOpeCartas INTEGER, Identificador global de ingresos multiples */ 
/******************************************************************************/
/*BASE*/
PROCEDURE PAGA_PLAZO_VOL(xID IN INTEGER,xFecha IN DATE,xPlazo IN DATE);

PROCEDURE PAGA_PLAZO_VOL(xID IN INTEGER,xFecha IN DATE,xPlazo IN DATE,
			   xFecha_ingreso IN DATE,xEntidad IN CHAR,xOficina IN CHAR,
			   xCanalIngreso IN CHAR,xImporte_ingreso IN FLOAT,
			   xImporte_plazo IN FLOAT,xCuenta IN INTEGER,
			   xIDCartaPagoBanco IN INTEGER,xCodOpeCartas IN INTEGER);


/* ****************************************************************************/
/* PROCEDIMIENTO: REALIZA EL INGRESO PENDIENTE O TOTAL DE UN PLAZO 		*/
/*			SOBRECARGADA PARA PAGOS DOMICILIADOS				*/
/* Parametros Entrada:										*/
/*			xID INTEGER, Identificador del fraccionamiento    		*/
/*	        xCodOpe INTEGER, Codigo de la operacion				*/
/*			xPlazo DATE, Fecha de vencimiento del plazo			*/
/*			xFecha DATE, Fecha de ingreso en la aplicación			*/
/* Parametros Sobrecargados:									*/
/*			xFecha_ingreso DATE, Fecha del ingreso en entidad		*/
/*			xEntidad CHAR, Entidad de cobro					*/
/*			xOficina CHAR, Oficina de cobro					*/
/*			xCanalIngreso CHAR, Canal de ingreso					*/
/*			xCuenta IN INTEGER, Numero de cuenta de ingreso			*/
/*			xImporte_plazo FLOAT, Importe del plazo				*/
/*			xImporte_ingreso FLOAT, Importe del ingreso realizado		*/
/******************************************************************************/
/*INTERNO*/
PROCEDURE APLICAR_PLAZO_VOL(xID IN INTEGER,xCODOPE IN INTEGER,xPLAZO IN DATE,xFECHA IN DATE);

PROCEDURE APLICAR_PLAZO_VOL(xID IN INTEGER,xCODOPE IN INTEGER,xPLAZO IN DATE,xFECHA IN DATE,
				xFecha_ingreso IN DATE,xEntidad IN CHAR,xOficina IN CHAR,xCanalIngreso IN CHAR,
				xCuenta IN INTEGER,xImporte_plazo IN FLOAT,xImporte_ingreso IN FLOAT);

/******************************************************************************/
/* 	FUNCION	: Calcula el importe de un fraccionamiento			*/
/*	SOBRECARGA  : Si se le indica fecha calcula el importe del primer plazo	*/
/*	Parametros Entrada:									*/
/*					xIDFraccionamiento: INTEGER				*/
/*	Parametros Sobrecargados:								*/
/*					xFecha: DATE						*/
/*	Valor  Retorno:		El importe de un fraccionamiento, tipo FLOAT	*/
/******************************************************************************/
/*BASE*/
FUNCTION Calcula_importe_fracc_vol(xIDFracc IN INTEGER) RETURN FLOAT;
FUNCTION Calcula_importe_fracc_vol(xIDFracc IN INTEGER,xFecha IN DATE) RETURN FLOAT;

END PKFraccionamientosVol;
/

/********************************************************************************/
CREATE OR REPLACE PACKAGE BODY PKFraccionamientosVol
AS

FUNCTION Calcula_importe_fracc_vol(xIDFracc IN INTEGER) RETURN FLOAT
AS
 xTotal_fracc FLOAT DEFAULT 0;
BEGIN

 SELECT sum(PRINCIPAL+RECARGO+COSTAS+DEMORA) 
 INTO   xTotal_fracc
 FROM   PLAZOS_FRAC_VOL
 WHERE  FRACCIONA=xIDFracc;

 RETURN xTotal_fracc;

END Calcula_importe_fracc_vol;

/********************************************************************************/

FUNCTION Calcula_importe_fracc_vol(xIDFracc IN INTEGER,xFecha IN DATE) RETURN FLOAT
AS
 xTotal_plazo FLOAT DEFAULT 0;
BEGIN

 SELECT sum(PRINCIPAL+RECARGO+COSTAS+DEMORA) 
 INTO   xTotal_plazo
 FROM   PLAZOS_FRAC_VOL 
 WHERE  FRACCIONA=xIDFracc AND FECHA=xFecha;

 RETURN xTotal_plazo;

END Calcula_importe_fracc_vol;

/********************************************************************************/

PROCEDURE PAGA_PLAZO_VOL(
      	xID      IN INTEGER,
	    xFecha   IN DATE, 
		xPlazo   IN DATE)

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
   SELECT SUM(PENDIENTE) INTO xPENDIENTE FROM vwPLAZOS_FRAC_VOL
   WHERE FRACCIONA=xID and FECHA=xPlazo and ingresado<>'S';

   if xPENDIENTE is Null then
     return;
   end if;

   -- aumenta el contador de codigo de operación y lo escribe en la tabla de usuarios
   CODIGO_OPERACION(xCiego);

   -- lanzar, para hacer el ingreso
   PKFraccionamientosVol.APLICAR_PLAZO_VOL(xID, xCiego, xPLAZO, xFecha);

   -- Se indica que el tramite de ingreso es de fraccionamiento.
   UPDATE INGRESOS SET INGRESO_TRAMITE='F' WHERE CODIGO_OPERACION=xCiego;
   
   --Anotar el movimento en el seguimiento de ingresos de frac.
   --No hace falta el campo tipo pues va por default plazo
   INSERT INTO INGRESOS_FRAC_VOL
        (FRAC,FECHA,F_PLAZO,COD_INGRESO,IMPORTE)
   VALUES (xID,xFecha,xPlazo,xCiego,xPENDIENTE);

   xMENSAJE:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);

   update PLAZOS_FRAC_VOL set F_INGRESO=xFecha,INGRESADO='S'
   where FRACCIONA=xID and FECHA=xPlazo and ingresado<>'S';

   -- Coje la fecha del siguiente plazo en caso
   --   contrario da por cobrados los recibos y el fraccionamiento 
   PKFraccionamientosvol.get_next_plazo_vol(xID, xFecha, yFecha);

   --suma el importe del proximo plazo y las entregas a cuenta
   SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS S1, SUM(ENTREGAS) AS S2
   INTO IMPO_NEXT,impo_entre
   FROM vwPLAZOS_FRAC_VOL
   where FRACCIONA=xID AND FECHA=yFecha;

   --actualiza los totalizadores del fraccionamiento
   update FRACCIONAMIENTO_VOL SET PAGADO=PAGADO+xPENDIENTE, 
   			IMPO_NEXT_PLAZO= IMPO_NEXT - impo_entre, F_NEXT_PLAZO=yFecha
   where ID=xID;

END PAGA_PLAZO_VOL;

/********************************************************************************/

PROCEDURE PAGA_PLAZO_VOL(xID IN INTEGER,xFecha IN DATE,xPlazo IN DATE,
			   xFecha_ingreso IN DATE,xEntidad IN CHAR,xOficina IN CHAR,
			   xCanalIngreso IN CHAR,xImporte_ingreso IN FLOAT,
			   xImporte_plazo IN FLOAT,xCuenta IN INTEGER,
			   xIDCartaPagoBanco IN INTEGER, xCodOpeCartas IN INTEGER)
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
   FROM VWPLAZOS_FRAC_VOL
   WHERE FRACCIONA=xID and FECHA=xPlazo and ingresado<>'S';

   if xPENDIENTE is Null then
	   return;
   end if;

   --aumenta el contador de codigo de operación y lo escribe en la tabla de usuarios
   CODIGO_OPERACION(xCiego);

   -- lanzar APLICAR_PLAZO, para hacer el ingreso
   PKFraccionamientosVol.APLICAR_PLAZO_VOL( xID, xCiego,xPLAZO,xFecha, xFecha_ingreso,
			xEntidad, xOficina,xCanalIngreso, xCuenta,xImporte_plazo,xImporte_ingreso);

	-- Actualizo en los ingresos recién realizados el campo idcartapagobanco
   if xIDCartaPagoBanco is not null then
   	UPDATE INGRESOS SET 
   		IDCARTAPAGOBANCO=xIDCartaPagoBanco,
	   	COD_OPERACION_CARTAS_PAGO=xCodOpeCartas 
   	WHERE CODIGO_OPERACION=xCiego;
   end if;

   --Anotar el movimento en el seguimiento de ingresos de frac.
   --No hace falta el campo tipo pues va por default plazo
   INSERT INTO INGRESOS_FRAC_VOL
        (FRAC,FECHA,F_PLAZO,COD_INGRESO,IMPORTE)
   VALUES (xID,xFecha,xPlazo,xCiego,xPENDIENTE);

   xMENSAJE:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);

   update PLAZOS_FRAC_VOL set F_INGRESO=xFecha,INGRESADO='S'
   where FRACCIONA=xID and FECHA=xPlazo and ingresado<>'S';

   -- Coje la fecha del siguiente plazo en caso
   --   contrario da por cobrados los recibos y el fraccionamiento 
   PKFraccionamientosVol.get_next_plazo_vol(xID, xFecha, yFecha);

   --suma el importe del proximo plazo y las entregas a cuenta
   SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS S1,
          SUM(ENTREGAS) AS S2
   INTO IMPO_NEXT,impo_entre
   FROM vwPLAZOS_FRAC_VOL
   where FRACCIONA=xID
         AND FECHA=yFecha;

   --actualiza los totalizadores del fraccionamiento
   update FRACCIONAMIENTO_VOL
   SET PAGADO=PAGADO+xPENDIENTE,
       IMPO_NEXT_PLAZO= IMPO_NEXT - impo_entre,
       F_NEXT_PLAZO=yFecha
   where ID=xID;

END PAGA_PLAZO_VOL;

/********************************************************************************/

PROCEDURE APLICAR_PLAZO_VOL( 
		xID        IN INTEGER,
      	xCODOPE    IN INTEGER,
	    xPLAZO     IN DATE,
	    xFECHA IN DATE)
AS

xPendiente FLOAT DEFAULT 0;

xPrin FLOAT DEFAULT 0;
xReca FLOAT DEFAULT 0;
xGastos FLOAT DEFAULT 0;
xInteres FLOAT DEFAULT 0;
xIDPlazo INTEGER DEFAULT 0;

xPRINCIPAL FLOAT DEFAULT 0;
xRECARGO FLOAT DEFAULT 0;
xCOSTAS FLOAT DEFAULT 0;
xDEMORA FLOAT DEFAULT 0;
xENTREGAS FLOAT DEFAULT 0;
xSUMENTREGAS FLOAT DEFAULT 0;
xImportePlazo FLOAT DEFAULT 0;

xMensaje char(50);

xINGRESADO CHAR(1);
xVALOR INTEGER;
xPendienteEje FLOAT;
xPendi	  FLOAT;
BEGIN

   
   -- Mira si el fraccionamiento tiene importes pendientes de plazos en ejecutiva.
   SELECT SUM(PENDIENTE) INTO xPendienteEje FROM IMPORTE_VALORES WHERE 
   ID IN (SELECT VALOR FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xID AND VOL_EJE='E');

   IF xPendienteEje IS NULL THEN
	xPendienteEje:=0;
   END IF;

   SELECT INGRESADO,VALOR,ENTREGAS,PRINCIPAL,RECARGO,COSTAS,DEMORA,IMPORTE,ID
   INTO xINGRESADO,xVALOR,xENTREGAS,xPRINCIPAL,xRECARGO,
   			xCOSTAS,xDEMORA,xImportePlazo,xIDPlazo
   FROM VWPLAZOS_FRAC_VOL
   WHERE FRACCIONA=xID And FECHA=xPlazo;

   -- PAGA UN PLAZO DEL FRACCIONAMIENTO
   if (xIngresado='N') then
	   xMensaje:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);
         xPrin:=xPRINCIPAL;
         xReca:=xRECARGO;
         xGastos:=xCOSTAS;
         xInteres:=xDEMORA;
   else
         xPendiente:=xImportePlazo-xEntregas;

         -- Repartir el importe de la entrega entre principal,recargo,costas, etc.
         reparto_frac(xPendiente,xImportePlazo,
                      xPrincipal,xRecargo,
                      xCostas,xDemora,
                      xPrin,xReca,xGastos,xInteres);

         xMensaje:='Pago parcial de un plazo fraccionamiento';
   end IF;


   -- LE PASAMOS EL ID DEL PLAZO PARA EN EL TR_INGRE_AI
   -- SE LO PODAMOS ESCRIBIR EN LA TABLA DE INGRESOS
   UPDATE USUARIOS SET LAST_TAREA=xIDPlazo WHERE USUARIO=USER;

   -- Ahora con las cartas de pago puede que no se pague al final el ultimo plazo, sino que
   -- se page en el banco el ultimo plazo quedando otros pendientes de cobro.
   -- Por lo tanto, miro si pago todo lo pendiente.
   SELECT SUM(ENTREGAS) INTO xSUMENTREGAS FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xID;
   SELECT TOTAL_DEUDA - PAGADO - xPrin - xReca - xGastos - xInteres - xSUMENTREGAS
   INTO xPendi
   FROM FRACCIONAMIENTO_VOL WHERE ID=xID;

   -- Si se ingresa el ultimo plazo y el pendiente de posibles plazos en ejecutiva es 0,cerrar.
   IF xPendienteEje=0 and xPendi=0 THEN
		PKIngresos.WRITE_INGRESO(xVALOR,xMensaje,'FV',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'C');
   ELSE
		PKIngresos.WRITE_INGRESO(xVALOR,xMensaje,'F1',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P');
   END IF;
 
END APLICAR_PLAZO_VOL;

/********************************************************************************/

PROCEDURE APLICAR_PLAZO_VOL( 
		xID        IN INTEGER,
      	xCODOPE    IN INTEGER,
	    xPLAZO     IN DATE,
	    xFECHA IN DATE,
		xFecha_ingreso IN DATE,
		xEntidad IN CHAR,
		xOficina IN CHAR,
		xCanalIngreso IN CHAR,
		xCuenta  IN INTEGER,
		xImporte_plazo IN FLOAT,
		xImporte_ingreso IN FLOAT)

AS

xPendiente FLOAT DEFAULT 0;

xPrin FLOAT DEFAULT 0;
xReca FLOAT DEFAULT 0;
xGastos FLOAT DEFAULT 0;
xInteres FLOAT DEFAULT 0;
xIDPlazo INTEGER DEFAULT 0;

xPRINCIPAL FLOAT DEFAULT 0;
xRECARGO FLOAT DEFAULT 0;
xCOSTAS FLOAT DEFAULT 0;
xDEMORA FLOAT DEFAULT 0;
xENTREGAS FLOAT DEFAULT 0;
xSUMENTREGAS FLOAT DEFAULT 0;
xImportePlazo FLOAT DEFAULT 0;
xUltimoPlazo DATE;

xMensaje char(50);

xINGRESADO CHAR(1);
xVALOR INTEGER;

xPendienteEje FLOAT;
xPendi	  FLOAT;
BEGIN

   SELECT MAX(FECHA) INTO xUltimoplazo
   FROM plazos_frac_vol
   WHERE FRACCIONA=xID;

   -- Mira si el fraccionamiento tiene importes pendientes de plazos en ejecutiva.
   SELECT SUM(PENDIENTE) INTO xPendienteEje FROM IMPORTE_VALORES WHERE 
   ID IN (SELECT VALOR FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xID AND VOL_EJE='E');

   IF xPendienteEje IS NULL THEN
	xPendienteEje:=0;
   END IF;

   xMensaje:='PAGO DE PLAZO FRACCIONAMIENTO EN VOLUNTARIA';

   -- ¿QUE HAGO CON EL EXPEDIENTE? xIDExpe=null 
   IF xPlazo=xUltimoPlazo THEN
	COBROS_BANCOS_EXPE(null,xCuenta,xCodOpe,'FV',
			       xImporte_ingreso,xImporte_plazo,
			       xFecha_ingreso,xMensaje);
   ELSE
	COBROS_BANCOS_EXPE(null,xCuenta,xCodOpe,'F1',
			       xImporte_ingreso,xImporte_plazo,
			       xFecha_ingreso,xMensaje);
   END IF;


   SELECT INGRESADO,VALOR,
          ENTREGAS,PRINCIPAL,RECARGO,COSTAS,DEMORA,IMPORTE,ID
   INTO xINGRESADO,xVALOR,xENTREGAS,xPRINCIPAL,xRECARGO,
   	  xCOSTAS,xDEMORA,xImportePlazo,xIDPlazo
   FROM vwplazos_frac_vol
   WHERE FRACCIONA=xID And FECHA=xPlazo;

   -- PAGA UN PLAZO DEL FRACCIONAMIENTO
   if (xIngresado='N') then
         xMensaje:='Plazo del fraccionamiento del MES ' ||
              Month(xPlazo) || ' DEL AÑO ' || F_Year(xPlazo);
         xPrin:=xPRINCIPAL;
         xReca:=xRECARGO;
         xGastos:=xCOSTAS;
         xInteres:=xDEMORA;
    else

         xPendiente:=xImportePlazo-xEntregas;
         --Repartir el importe de la entrega entre principal,recargo,costas, etc.
         reparto_frac(xPendiente,xImportePlazo,
                      xPrincipal,xRecargo,
                      xCostas,xDemora,
                      xPrin,xReca,xGastos,xInteres);
         xMensaje:='Pago parcial de un plazo fraccionamiento';
   end IF;


   -- LE PASAMOS EL ID DEL PLAZO PARA EN EL TR_INGRE_AI SE LO PODAMOS 
   -- ESCRIBIR EN LA TABLA DE INGRESOS 
   UPDATE USUARIOS SET LAST_TAREA=xIDPlazo,LAST_BAJA=xCuenta
   WHERE USUARIO=USER;

   -- Ahora con las cartas de pago puede que no se pague al final el ultimo plazo, sino que
   -- se page en el banco el ultimo plazo quedando otros pendientes de cobro.
   -- Por lo tanto, miro si pago todo lo pendiente.
   SELECT SUM(ENTREGAS) INTO xSUMENTREGAS FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xID;
   SELECT TOTAL_DEUDA - PAGADO - xPrin - xReca - xGastos - xInteres - xSUMENTREGAS
   INTO xPendi
   FROM FRACCIONAMIENTO_VOL WHERE ID=xID;

   -- Si se ingresa el ultimo plazo y el pendiente de posibles plazos en ejecutiva es 0,cerrar.
--   IF xPlazo=xUltimoPlazo and xPendienteEje=0 THEN
   IF xPendienteEje=0 and xPendi=0 THEN
	      PKIngresos.WRITE_INGRESO(xVALOR,xMensaje,'FV',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'C',
			xFecha_ingreso,xEntidad,xOficina,xCanalIngreso,'F');
   ELSE
	      PKIngresos.WRITE_INGRESO(xVALOR,xMensaje,'F1',xFecha,
			xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P',
			xFecha_ingreso,xEntidad,xOficina,xCanalIngreso,'F');	
   END IF;

END APLICAR_PLAZO_VOL;

/* ********************************************************************* */
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
--	Añadido el parámetro xFechaIngreso para indicar la fecha de ingreso del 
--	fraccionamiento y del recibo en el caso de que no haya más plazos.
PROCEDURE CheckCierreFrac(
	        xIDFrac IN INTEGER,
	        xFechaIngreso IN DATE)
AS

xPendiente INTEGER DEFAULT 0;
xDarPorPagado INTEGER;

CURSOR CPLAZOS IS SELECT * FROM PLAZOS_FRAC_VOL WHERE FRACCIONA=xIDFrac;

BEGIN
   xDarPorPagado:=1;
   -- Miro para cada plazo si tiene algo pendiente.
   FOR v_Plazos IN CPLAZOS LOOP
	-- Si el plazo esta en voluntaria y no esta ingresado es porque tiene importe pendiente.
   	IF v_Plazos.VOL_EJE='V' THEN
	   if v_Plazos.INGRESADO<>'S' THEN
	   	xDarPorPagado:=0;
	   end if;
	ELSE
	-- Si el plazo está en ejecutiva hay que mirar si el valor en ejecutiva tiene pendiente
	   SELECT PENDIENTE INTO xPendiente FROM IMPORTE_VALORES WHERE ID=v_Plazos.Valor; 
	   IF xPendiente>0 THEN
	   	xDarPorPagado:=0;
	   END IF;
	END IF;
   END LOOP;

   if xDarPorPagado=1 then
	-- Si llega aqui, es porque todos los plazos están pagados.
   	-- Ahora sí puede cerrar el fraccionamiento.
   	DarPorPagadoFRAC_VOL(xIDFrac,xFechaIngreso);
   end if;

END CheckCierreFrac;
/* ********************************************************************* */
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
--	Añadido el parámetro xFechaIngreso para indicar la fecha de ingreso del 
--	fraccionamiento y del recibo en el caso de que no haya más plazos.
PROCEDURE GET_NEXT_PLAZO_VOL(
	        xIDFrac IN INTEGER, 
	        xFechaIngreso IN DATE,
		  xFecha  OUT DATE)
AS

   xIDExpe INTEGER;
   xCuantos integer DEFAULT 0;

BEGIN

   -- LEER EL SIGUIENTE PLAZO SI EXISTE
   Select MIN(FECHA) AS RESU INTO xFECHA
   from PLAZOS_FRAC_VOL
   where FRACCIONA=xidFrac and INGRESADO<>'S' and VOL_EJE='V'
   order by RESU ASC;


   IF (xFECHA IS NULL) THEN -- No hay mas plazos en voluntaria.
	-- Miro si queda algo pendiente de ingresar para cerrar el fraccionamiento.
      PKFraccionamientosVol.CheckCierreFrac(xIDFrac,xFechaIngreso);

   END IF;

END GET_NEXT_PLAZO_VOL;

END; 
/
