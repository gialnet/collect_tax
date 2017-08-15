-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

/********************************************************************************************/
-- Elimina un embargo (de tipo OTROS) de un expediente y lo deja sin trámite de embargos. 
-- Borra el embargo de la tabla OTROS_TRAMITES.
/********************************************************************************************/
CREATE OR REPLACE PROCEDURE OTROS_SIN_TRAMITES(
		xEXPE IN INTEGER,
		xID   IN INTEGER)

AS
BEGIN

   DELETE FROM OTROS_TRAMITES WHERE ID=xID;

   UPDATE EXPEDIENTES SET EMBARGO_X='0' WHERE ID=xEXPE;

END;
/

/********************************************************************************************/
-- Elimina el tramite de embargo de un expediente y deja al expediente en estado PENDIENTE
-- del tramite de OTROS.
-- Borra el embargo de la tabla OTROS_TRAMITES.
/********************************************************************************************/
CREATE OR REPLACE PROCEDURE QUITO_EXPEOTROS(
		xID_EXPE IN INTEGER)
AS
BEGIN
	
   DELETE FROM OTROS_TRAMITES WHERE ID_EXPE=xID_EXPE;

   UPDATE EXPEDIENTES SET EMBARGO_X='P' WHERE ID=xID_EXPE;

END;
/

/*********************************************************************************/
-- Genera para un expediente un embargo de tipo OTROS
/*********************************************************************************/
CREATE OR REPLACE PROCEDURE PUT_UnExpe_Otros (
         xIDExpe IN INTEGER,
         xNIF    IN char)

AS
   xZona char(2);
BEGIN

   -- Cambia el estado del expediente de pendiente a en curso
   UPDATE EXPEDIENTES SET EMBARGO_X='O'
   WHERE ID=xIDEXPE;

   Select zona into xZona from usuarios where usuario=USER;

   -- Crea el embargo	  
   INSERT INTO otros_tramites (Zona, ID_Expe, NIF)
   values (xZona,xIDExpe,xNIF);

END;
/
/***************************************************************************************/
-- Genera para un conjunto de expedientes un embargo de tipo OTROS.
-- Ese conjunto es el de los expedientes en estado PENDIENTE de embargo de tipo OTROS
-- que no estan ingresados, anulados o suspendidos.
/***************************************************************************************/
CREATE OR REPLACE PROCEDURE PUT_EN_LOTE_OTROS(
		xNADA IN INTEGER)

/* a la fuerza pasarle un parametro al procedimiento, aunque no sirva, porque si no
   no reconoce delphi el procedimiento */

AS

   CURSOR EXPE_CUR IS
        SELECT ID,DEUDOR
	  FROM EXPEDIENTES
        WHERE EMBARGO_X='P'
      	  AND F_INGRESO IS NULL
	        AND F_ANULACION IS NULL
	        AND F_SUSPENSION IS NULL;
BEGIN

   FOR v_EXPE IN EXPE_CUR LOOP
      PUT_UnExpe_Otros(v_EXPE.ID,v_EXPE.DEUDOR);
   END LOOP;

END;
/

/**************************************************************************************/
-- Genera para un conjunto de expedientes un embargo de tipo OTROS.
-- Ese conjunto es el de los expedientes en estado PENDIENTE de embargo de tipo OTROS
-- que no estan ingresados, anulados o suspendidos, y cuyo importe pendiente esté entre
-- dos valores que se pasan como parámetros al procedimiento.
/**************************************************************************************/

CREATE OR REPLACE PROCEDURE PUT_EN_OTROS_between(
        xDesde IN float,
        xHasta IN float)
AS

   CURSOR EXPE_CUR IS
        SELECT E.ID,E.DEUDOR
        FROM EXPEDIENTES E,PendiValoresExpe V
        WHERE E.ID=V.EXPEDIENTE
              AND EMBARGO_X='P'
              AND E.F_INGRESO IS NULL
              AND E.F_ANULACION IS NULL
              AND E.F_SUSPENSION IS NULL
              AND V.PENDIENTE BETWEEN ROUND(xDESDE,2) AND ROUND(xHASTA,2);

BEGIN

   FOR v_EXPE IN EXPE_CUR LOOP
      PUT_UnExpe_Otros(v_EXPE.ID,v_EXPE.DEUDOR);      
   END LOOP;

END;
/

/*********************************************************************************/
COMMIT;
/*********************************************************************************/
