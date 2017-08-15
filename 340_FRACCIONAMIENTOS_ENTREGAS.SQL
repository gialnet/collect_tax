-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.(ROUNDS)
-- -----------------------------------------------------

-- -----------------------------------------------------------------
-- SE VA A DAR POR PAGADO UN RECIBO DEL SEÑALAMIENTO 
-- Realiza el pago completo de un único plazo del fraccionamiento
-- Modificado: 25/08/2003 Lucas Fernández Pérez. 
--	Al ingresar por completo un recibo se pone la f_suspension a null
-- Modificado: 28/08/2003. Lucas Fernández Pérez. 
-- 	  Se añade el parámetro xFechaIngreso con la fecha de la entrega.
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
-- 	  Para saber si se aplica el último plazo, antes se miraba si era el de la fecha última.
--	  Ahora se mira si hay algún otro plazo con algo pendiente. Si no hay, es el último.
--    El motivo de este cambio es que con las cartas de pago puede ingresarse en orden 
--	  distinto al de las fechas de los plazos. De este modo pueden ingresarse los plazos
--	  de forma desordenada.
-- Modificado: 03/11/2003. Lucas Fernández Pérez. 
--	  Borra de la tabla suspensiones_valores cuando se elimina la suspension al valor.
-- --------------------------------------------------------------------------------------
/*INTERNO*/
CREATE OR REPLACE PROCEDURE APLICAR_RECIBO_PLAZO( 
		xID        	  IN INTEGER,
      	xCODOPE    	  IN INTEGER,
      	xFechaIngreso IN DATE)

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
xImportePlazo FLOAT DEFAULT 0;

xINGRESADO CHAR(1);
xVALOR INTEGER;
xPlazo DATE;
xFracciona INTEGER;
xHayOtrosPlazos INTEGER;
BEGIN

   SELECT FRACCIONA,FECHA INTO xFracciona,xPlazo FROM PLAZOS_FRAC WHERE ID=xID;

   -- Si queda algún plazo sin ingresar de otra fecha, el ingreso que vamos a realizar 
   -- no es el pago que cierra el fraccionamiento.
   SELECT COUNT(*) INTO xHayOtrosPlazos FROM PLAZOS_FRAC 
   WHERE FRACCIONA=xFracciona AND INGRESADO <> 'S' AND FECHA<>xPLAZO;

 
   SELECT INGRESADO,VALOR,ENTREGAS,IMPORTE,PRINCIPAL,RECARGO,COSTAS,DEMORA
	INTO xINGRESADO,xVALOR,xENTREGAS,xImportePlazo,xPRINCIPAL,xRECARGO,
				    xCOSTAS,xDEMORA
      			FROM vwplazos_frac
			      WHERE ID=xID;

   IF xENTREGAS > 0 THEN

	-- QUE EXISTAN ENTREGAS ANTERIORES 
	xPendiente:=xImportePlazo-xEntregas;

	-- Repartir el importe de la entrega entre principal,recargo,costas, etc.
	reparto_frac(xPendiente,xImportePlazo,
                      xPrincipal,xRecargo,xCostas,xDemora,
                      xPrin,xReca,xGastos,xInteres);
   ELSE
	xPrin:=xPRINCIPAL;
	xReca:=xRECARGO;
	xGastos:=xCOSTAS;
	xInteres:=xDEMORA;
   END IF;



   -- LE PASAMOS EL ID DEL PLAZO PARA EN EL TR_INGRE_AI
   --    SE LO PODAMOS ESCRIBIR EN LA TABLA DE INGRESOS 
   UPDATE USUARIOS SET LAST_TAREA=xID WHERE USUARIO=USER;

   IF xHayOtrosPlazos=0 THEN
	PkIngresos.WRITE_INGRESO(xVALOR, 'Pago parcial de un plazo fraccionamiento',
		'FE',xFechaIngreso,xPrin,xReca,xGASTOS,xInteres,xCodOpe,'C');
		
	-- Este recibo ya está ingresado totalmente, elimino la marca de suspendido que tenía.
	UPDATE VALORES SET F_SUSPENSION=NULL WHERE ID=xValor;
	DELETE FROM SUSPENSIONES_VALORES WHERE VALOR=xValor;
		
   ELSE
	PkIngresos.WRITE_INGRESO(xVALOR, 'Pago parcial de un plazo fraccionamiento',
		'EF',xFechaIngreso,xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P');
   END IF;


END;
/

-- -------------------------------------------------------------
-- Entrega a cuenta sobre un único plazo de un fraccionamiento.
--
-- Modificado: 28/08/2003. Lucas Fernández Pérez. 
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
-- -------------------------------------------------------------
/*INTERNO*/
CREATE OR REPLACE PROCEDURE ENTREGA_RECIBO_PLAZO( 
	  	  xIDFrac       IN INTEGER,
	      xCODOPE       IN INTEGER,
	      xEntrega 	    IN FLOAT,
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
      FROM VWplazos_frac
      WHERE ID=xIDFrac;

   -- Repartir el importe de la entrega entre principal,recargo,costas, etc.

   reparto_frac(xEntrega,xImportePlazo,
                         xPrincipal,xRecargo,
                         xCostas,xDemora,
                         xPrin,xReca,xGastos,xInteres);

   -- LE PASAMOS EL ID DEL PLAZO PARA que en WRITE_INGRESO
   --       SE LO PODAMOS ESCRIBIR EN LA TABLA DE INGRESOS 
   UPDATE USUARIOS SET LAST_TAREA=xIDFrac WHERE USUARIO=USER; 

   PkIngresos.WRITE_INGRESO(xVALOR, 'Pago parcial de un plazo fraccionamiento' ,'EF',
   				xFechaIngreso,xPrin,xReca,xGASTOS,xInteres,xCodOpe,'P');


END;
/

-- -------------------------------------------------------------------------------
-- REALIZAR UNA ENTREGA A CUENTA A UN FRACCIONAMIENTO 
-- La entrega puede abarcar varios plazos
-- (uno o varios plazos completos y/o una entrega a cuenta)
--
-- Modificado: 28/08/2003. Lucas Fernández Pérez. 
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
-- -------------------------------------------------------------------------------
/*INTERNO*/

CREATE OR REPLACE PROCEDURE PUT_ENTREGA_PLAZOS(
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
xZONA		CHAR(2);

-- Leer los plazos de un fraccionamiento desde el primero 
-- de todos los que no esten ingresados
CURSOR CUR_PLAZO IS 
	select PENDIENTE,ID
	from VWPLAZOS_FRAC
	where FRACCIONA=xidFrac and INGRESADO<>'S'
	order by fecha,ID;

  CURSOR CVALORESCARTAPAGO IS 
	SELECT ID,(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA 
	FROM VALORES WHERE ID IN (
	SELECT DISTINCT VALOR FROM PLAZOS_FRAC WHERE FRACCIONA=xidFrac);

BEGIN

   xIMPORTE:=ROUND(xENTREGA,2);

   Open cur_plazo;

   LOOP

      FETCH  cur_plazo into xPendiente,xID;
      EXIT WHEN (CUR_PLAZO%NOTFOUND OR xIMPORTE<=0);
      
         -- averiguar que queda pendiente 
         xLast:=xImporte;

         xImporte := xImporte - xPendiente;

         -- sobra para otro plazo MAS como MINIMO 

         IF (xImporte >= 0) THEN

		-- Pago completo del plazo
            APLICAR_RECIBO_PLAZO(xID, xCODOPE, xFechaIngreso);

            update PLAZOS_FRAC set INGRESADO='S',
                                   ENTREGAS=PRINCIPAL+RECARGO+COSTAS+DEMORA,
                                   F_INGRESO=xFechaIngreso
            where ID=xID;
         END IF;

         -- ha faltado para completar este plazo 
         IF (xImporte < 0) THEN

		-- Entrega a cuenta sobre el plazo
            ENTREGA_RECIBO_PLAZO(xID, xCODOPE, ROUND(xLAST,2), xFechaIngreso);

            update PLAZOS_FRAC set ENTREGAS=ENTREGAS+xLast, INGRESADO='P'
            where ID=xID;

         END IF;

   END LOOP;

   close cur_plazo;

   IF (xImporte >= 0) THEN -- Si aun pagando todo queda importe sobrante
	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	INSERT INTO INGRESOS_INDEBIDOS(IDCARTAPAGO,CODIGO_OPERACION,IMPORTE,ZONA) 
		VALUES (xIDCartaPago,xCODOPE,xImporte,xZONA)
		RETURNING ID INTO xIDIngresosIndebidos;

	--Insertamos el detalle de que recibos comprende
	FOR v_Valores IN CVALORESCARTAPAGO LOOP
		INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES)
		VALUES (xIDIngresosIndebidos,v_Valores.ID,v_Valores.DEUDA,'N');
	END LOOP;

   END IF;

END;
/

/*********************************************************************/
-- Modificado: 28/08/2003. Lucas Fernández Pérez. 
-- Se añade el parámetro xFechaIngreso con la fecha de la entrega.
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
-- Se añade la fecha de ingreso en la llamada al procedimiento DarPorPagadoFrac
-- Modificado: 01/09/2003. Lucas Fernández Pérez. 
-- Se indica en la tabla de ingresos que el tramite de ingreso es de fraccionamiento.
/*DELPHI*/
CREATE OR REPLACE PROCEDURE put_entrega_frac(
        xIDFrac		  IN INTEGER,
        xExpe  		  IN INTEGER,
        xImpo   	  IN FLOAT,
        xFechaIngreso IN DATE,
	  	xIDCartaPago  IN INTEGER)

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
   PUT_ENTREGA_plazos(xImpo, xIDFrac, xFechaIngreso, xCiego, xIDCartaPago);

   -- Se indica que el tramite de ingreso es de fraccionamiento.
   UPDATE INGRESOS SET INGRESO_TRAMITE='F' WHERE CODIGO_OPERACION=xCiego;

   -- Anotar el movimento en el seguimiento de ingresos del frac. 
   INSERT INTO INGRESOS_FRAC
      (FRAC,FECHA,COD_INGRESO,IMPORTE,TIPO)
   VALUES (xidFrac,xFechaIngreso,xCiego,ROUND(xImpo,2),'E');

   -- Anotar en el seguimiento 
   INSERT INTO SEGUIMIENTO
      (ID_EXPE,
       F_ACTUACION,
       DESCRIPCION,
       IMPORTE,DEBE_O_HABER,ID_INGRESOS)
   VALUES (xExpe,xFechaIngreso,'Entrega a cuenta sobre el FRACCIONAMIENTO.'||
		' ID Fraccionamiento: '||TO_CHAR(xIDFrac),ROUND(xIMPO,2),'H',xCiego);

   -- averiguar la fecha del siguiente plazo 

   -- Primero buscamos si hay algún parcial
   SELECT COUNT(*),MIN(FECHA) INTO xCUANTOS,xFECHA
   FROM PLAZOS_FRAC
   WHERE FRACCIONA=xIDFrac
         AND INGRESADO='P';

   -- Si no hubiera ninguno, entonces se busca los Ingresado='N'
   IF xCUANTOS=0 THEN
         SELECT COUNT(*),MIN(FECHA) INTO xCUANTOS, xFecha
         FROM PLAZOS_FRAC
         WHERE FRACCIONA=xIDFrac AND INGRESADO='N';
   END IF;

   IF xCUANTOS<>0 THEN 
	SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS S1,
		 SUM(ENTREGAS) AS S2
	INTO xImpoNextPlazo,xNext_Entregas
	FROM VWPLAZOS_FRAC
	WHERE FECHA=xFECHA AND FRACCIONA=xIDFrac;	
   END IF;

   update FRACCIONAMIENTO SET ENTREGAS=ENTREGAS+ROUND(xImpo,2),
                              F_NEXT_PLAZO=xFECHA,
					IMPO_NEXT_PLAZO=(xImpoNextPlazo-xNext_Entregas)
   where ID=xidFrac;

   IF xCUANTOS=0 THEN
	DarPorPagadoFRAC(xIDFrac,xFechaIngreso);
   END IF;

END;
/

/*********************************************************************/
COMMIT;
/********************************************************************/
