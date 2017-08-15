-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.(ROUND)
-- -----------------------------------------------------
-- -----------------------------------------------------
-- DAR POR PAGADO EN FRACCIONAMIENTOS 
--
-- Modificado: 26/08/2003. Lucas Fernández Pérez. 
--	El cod_ingreso en valores y expedientes, antes se ponía 'FR', ahora se pone a 'FE'.
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
--	Añadido el parámetro xFechaIngreso para indicar la fecha de ingreso (antes ponía sysdate)
-- Modificado: 04/11/2003. Lucas Fernández Pérez. 
--	  Borra de la tabla suspensiones_valores cuando se elimina la suspension al valor.
-- Modificado: 03/03/2005. Lucas Fernández Pérez. 
--	  El borrado y modificacion de suspensiones_valores y valores lo hacía where Expediente=xID and
--    fecha_de_baja is null and is_live='N'. Si en el expediente había valores de otro fraccionamiento
--    anterior ya ingresado, entraban en esa consulta, y se cambiaba la fecha de ingreso, dejándola mal.
--    Se añade a la condición and f_suspension is not null, porque los valores fraccionados la cumplen,
--    y los que estaban fraccionados, al ingresarse, ponían f_suspension a null, y no entran en la consulta.
-- ----------------------------------------------------------------------------------------------------------
/*BASE*/

CREATE OR REPLACE PROCEDURE DarPorPagadoFRAC(xIDFrac IN INTEGER,xFechaIngreso IN DATE)
AS
xIDExpe INT;
BEGIN

   update FRACCIONAMIENTO 
	set F_CIERRE=xFechaIngreso,ISOPEN='C',
	ESTADO='CERRADO',F_ESTADO=xFechaIngreso
      where ID=xIdFrac RETURNING expediente into xIDExpe;


   -- DAR POR COBRADOS LOS VALORES QUE PERTENECIAN AL FRACCIONAMIENTO, en la condicion del 
   -- where no se puede poner "f_ingreso is null" porque cuando llega aqui ya esta dado por
   -- pagado a traves del procedimiento de "write_ingreso"
   -- y entonces no le qutaria la fecha de suspension a los valores

   DELETE FROM SUSPENSIONES_VALORES WHERE VALOR in 
   	(select id from valores WHERE Expediente=xIDExpe AND FECHA_DE_BAJA IS NULL
            AND IS_LIVE='N' AND F_SUSPENSION IS NOT NULL);
   UPDATE VALORES SET F_INGRESO=xFechaIngreso,
	  	             COD_INGRESO='FE',
			       DEMORA_PENDIENTE=0,
			       F_SUSPENSION=NULL
	WHERE Expediente=xIDExpe
            AND FECHA_DE_BAJA IS NULL
            AND IS_LIVE='N'
            AND F_SUSPENSION IS NOT NULL; -- Con esta condición no entran valores ingresados en frac.anteriores a este.

   -- CERRAR EL EXPEDIENTE Y DARLO POR PAGADO 
   --Comprobar si hubiera recibos que han entrado en el expediente 
   -- despues de haber concedido el fraccionamiento
   IF NOT PkValoresVarios.ExisteValoresVivos(xIDExpe) THEN
	update expedientes set 
		codigo_ingreso='FE', 
		f_ingreso=xFechaIngreso, 
		CARTA_PAGO='P',
		ESTADO='PAGADO'
	where ID=xIDExpe;
   ELSE
	update expedientes set 
		ESTADO='ABIERTO',
		F_SUSPENSION=NULL
	where ID=xIDExpe;
   END IF;


END DarPorPagadoFRAC;
/


/*********************************************************************/
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
--	Añadido el parámetro xFechaIngreso para indicar la fecha de ingreso del 
--	fraccionamiento, recibos y expediente en caso de que no haya más plazos.
/*BASE*/

CREATE OR REPLACE PROCEDURE GET_NEXT_PLAZO(
	        xIDFrac IN INTEGER, 
	        xFechaIngreso IN DATE,
		  	xFecha  OUT DATE)
AS
BEGIN

   -- LEER EL SIGUIENTE PLAZO 
   Select MIN(FECHA) AS RESU INTO xFECHA
      from PLAZOS_FRAC
      where FRACCIONA=xidFrac and INGRESADO<>'S'
      order by RESU ASC;

   IF (xFECHA IS NULL) THEN
   	DarPorPagadoFRAC(xIDFrac,xFechaIngreso);
   END IF;

END;
/

/* ********************************************************************** */
/*BASE*/
CREATE OR REPLACE PROCEDURE REPARTO_FRAC(
		 IMPORTEENTREGA IN FLOAT,
		 xIMPORTE 	    IN FLOAT,
		 xPRINCIPAL     IN FLOAT,
		 xRECARGO       IN FLOAT,
		 xCOSTAS        IN FLOAT,
		 xDEMORA        IN FLOAT,
		 SPRINCIPAL     OUT FLOAT,
		 SRECARGO       OUT FLOAT,
		 SCOSTAS        OUT FLOAT,
		 SDEMORA        OUT FLOAT)
AS
xSUMA FLOAT;
xSumaErrores FLOAT;
BEGIN

   SPRINCIPAL:=0;
   SRECARGO:=0;
   SCOSTAS:=0;
   SDEMORA:=0;
   xSumaErrores:=0;



   IF (xRECARGO > 0) THEN
      SRECARGO:=xRECARGO/xIMPORTE;
      SRECARGO:=SRECARGO*IMPORTEENTREGA;
	xSumaErrores:=SRECARGO-ROUND(SRECARGO,2);
	SRECARGO:=round(SRECARGO, 2);
   END IF;

   IF (xCOSTAS > 0) THEN
      SCOSTAS:=xCOSTAS/xIMPORTE;
      SCOSTAS:=SCOSTAS*IMPORTEENTREGA;
	xSumaErrores:=xSumaErrores + (SCOSTAS-ROUND(SCOSTAS,2));
	SCOSTAS:=round(SCOSTAS, 2);
   END IF;

   IF (xDEMORA > 0) THEN
      SDEMORA:=xDEMORA/xIMPORTE;
      SDEMORA:=SDEMORA*IMPORTEENTREGA;
	xSumaErrores:=xSumaErrores + (SDEMORA-ROUND(SDEMORA,2));
	SDEMORA:=round(SDEMORA, 2);
   END IF;

   IF (xPRINCIPAL > 0) THEN
      SPRINCIPAL:=xPRINCIPAL/xIMPORTE;
      SPRINCIPAL:=SPRINCIPAL*IMPORTEENTREGA;
	xSumaErrores:=xSumaErrores + (SPRINCIPAL-ROUND(SPRINCIPAL,2));
	SPRINCIPAL:=SPRINCIPAL+xSumaErrores;
	IF SPRINCIPAL<0 THEN
	   SPRINCIPAL:=0;
	END IF;
	SPRINCIPAL:=round(SPRINCIPAL, 2);
   END IF;

   -- SUMA DE LOS VALORES REDONDEADOS 
   xSUMA:=SPRINCIPAL+SRECARGO+SCOSTAS+SDEMORA;

   IF xSUMA > IMPORTEENTREGA THEN
     SDEMORA:=SDEMORA - (xSUMA - IMPORTEENTREGA);
   END IF;

END;
/

/*********************************************************************/
/*	PROCEDIMIENTO: Paga los plazos pendientes cuando se realiza    */
/*			   una entrega del total pendiente	   		   */
/*	PARAMETROS ENTRADA:  xID id del fraccionamiento			   */
/*				   xExpe id del Expediente			   */
/*				   xFecha Fecha del ingreso			   */
/*				   xPlazo Fecha de vencimiento del plazo	   */
/*********************************************************************/
-- Modificado: 29/08/2003.Lucas Fernández Pérez. 
-- Se añade la fecha de ingreso en la llamada al procedimiento GetNextPlazo
/* Delphi */
CREATE OR REPLACE PROCEDURE ENTREGA_PENDIENTE(
        	xID    IN INTEGER, 
		xExpe  IN INTEGER,
	      xFecha IN DATE, 
		xPlazo IN DATE)
AS
     xNextPlazo DATE;
BEGIN
     
    xNextPlazo:=xPlazo; 

    WHILE not(xNextPlazo is null) LOOP
		PKIngresos.PAGA_PLAZO(xID,xExpe,xFecha,xNextPlazo);
		GET_NEXT_PLAZO(xID,xFecha,xNextPlazo);  
    END LOOP;

END;
/

/*********************************************************************/
COMMIT;
/********************************************************************/