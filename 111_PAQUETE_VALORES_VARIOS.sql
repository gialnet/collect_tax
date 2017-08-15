-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
CREATE OR REPLACE PACKAGE PkValoresVarios
AS

FUNCTION ExisteValoresVivos(xIDExpe IN INT) RETURN BOOLEAN;


END PkValoresVarios;
/


CREATE OR REPLACE PACKAGE BODY PkValoresVarios
AS

FUNCTION ExisteValoresVivos(xIDExpe IN INT)
RETURN BOOLEAN
AS
vReturn BOOLEAN default True;
xCuantos INT DEFAULT 0;
BEGIN


Select count(*) INTO xCUANTOS
      from valores
      where Expediente=xIDExpe
            AND FECHA_DE_BAJA IS NULL
            AND F_INGRESO IS NULL;

IF xCuantos=0 THEN
   vReturn:=False;
ELSE
   vReturn:=True;
END IF;

RETURN vReturn;


END ExisteValoresVivos;



/* ************************************************************ */
/* INICIALIZACION DEL PAQUETE. 
BEGIN*/


END PkValoresVarios;
/