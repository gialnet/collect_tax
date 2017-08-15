/**************************************************************************************
Acción: Borrar un fraccionamiento. Si el fraccionamiento no esta cerrado, se deja el 
		expediente abierto con sus valores pendientes de cobro.		
MODIFICACIÓN: 11/09/2002. Agustín León Robles. Borra de la tabla de suspensiones_valores.
MODIFICACIÓN: 30/07/2003. M. Carmen Junco Gómez. Se ha de borrar de la tabla 
			  borra_levantamientos al borrar de borra_embargos_cuentas y borra_cuentas_lotes.

DELPHI
****************************************************************************************/
-- Modificado: 04/11/2003. Lucas Fernández Pérez. 
--	  Borra de la tabla suspensiones_valores cuando se elimina la suspension al valor.


CREATE OR REPLACE PROCEDURE DELETE_FRAC(
		xFRAC IN INTEGER,
		xEXPE IN INTEGER)
AS
xESTA 	CHAR(7);
xEmbargo 	CHAR(1);
xEsta_embargo CHAR(1);
BEGIN
	SELECT ESTADO INTO xESTA FROM FRACCIONAMIENTO WHERE ID=xFRAC;

	-- BORRAR LA LISTA DE INGRESOS 
	DELETE FROM INGRESOS_FRAC WHERE FRAC=xFRAC;

	-- BORRAR EL SEÑALAMIENTO DE PLAZOS 
	DELETE FROM PLAZOS_FRAC WHERE FRACCIONA=xFRAC;

	-- BORRAR LA CABECERA DEL FRACCIONAMIENTO 
	DELETE FROM FRACCIONAMIENTO WHERE ID=xFRAC;

	--si no esta cerrado volvemos a dejar los recibos pendientes de cobro, porque si esta 
	--cerrado es debido a que se ha pagado el expediente
	IF (xESTA<>'CERRADO') THEN		

	-- Al fraccionar probablemente se levantó de algun embargo. Si se levantó de CC, se
	-- pasa el nuevo estado del expediente de '1L' a '0C', y se borran los datos del
	-- levantamiento de cuentas.Si se levantó de cualquier otro embargo o no se levantó nada,
	-- no se hace ningun tratamiento especial.

	   SELECT EMBARGO,ESTA_EMBARGO INTO xEmbargo,xEsta_embargo FROM EXPEDIENTES 
	   WHERE ID=xEXPE;
	
	   if xEmbargo='1' and xEsta_embargo='L' then
		UPDATE EXPEDIENTES SET EMBARGO='0',ESTA_EMBARGO='C',ESTADO='ABIERTO',
			F_SUSPENSION=NULL,FECHA_DILIGENCIA=NULL,INTERES_DILIGENCIA=0 WHERE ID=xEXPE;

		DELETE FROM NEXT_LEVANTA_CUENTAS WHERE IDEXPE=xEXPE;
		DELETE FROM BORRA_CUENTAS_LOTES WHERE IDEXPE=xEXPE;
		DELETE FROM BORRA_EMBARGOS_CUENTAS WHERE IDEXPE=xEXPE;
		DELETE FROM BORRA_LEVANTAMIENTOS WHERE IDEXPE=xEXPE;
	   else 
		UPDATE EXPEDIENTES SET ESTADO='ABIERTO',F_SUSPENSION=NULL WHERE ID=xEXPE;
	   end if;


	   DELETE FROM SUSPENSIONES_VALORES WHERE VALOR IN 
	   	(SELECT ID FROM VALORES WHERE EXPEDIENTE=xEXPE
	   		AND F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL	AND IS_LIVE='N');
	   UPDATE VALORES SET IS_LIVE='S',F_SUSPENSION=NULL
		WHERE EXPEDIENTE=xEXPE
			AND F_INGRESO IS NULL
			AND FECHA_DE_BAJA IS NULL
			AND IS_LIVE='N';

	END IF;

	PkSeguimiento.NotaInformativa(xEXPE,'SE HA BORRADO EL FRACCIONAMIENTO');
END;
/