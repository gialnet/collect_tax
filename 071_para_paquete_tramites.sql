-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

/* todo esto se pasara al paquete tramites */
--
-- Comprobar si un expediente tiene un embargo de cuentas corrientes en marcha
--
CREATE OR REPLACE FUNCTION EmbargoCuentaEnMarcha(xIDExpe INT)
RETURN BOOLEAN
AS
xCuantos INT;
v_Return Boolean;
BEGIN

   SELECT COUNT(*) INTO xCuantos 
	FROM CUENTAS_LOTES
		WHERE IdEXPE=xIDEXPE 
		AND DILIGENCIA='S' 
		AND HECHO='N';

   if xCuantos > 0 then
   	v_Return:=True;
   else
   	v_Return:=False;
   end if;
   RETURN v_Return;

END;
/


CREATE OR REPLACE FUNCTION HayRetenidoCuentas(xIDExpe IN INT, xImporteRetenido OUT Float)
RETURN BOOLEAN
AS

v_Return Boolean;
xZONA CHAR(2);
xLOTE CHAR(10);

BEGIN

v_Return:=True;

BEGIN
SELECT ZONA,LOTE INTO xZONA,xLOTE
	from EMBARGOS_CUENTAS
		WHERE IdEXPE=xIDExpe;
EXCEPTION
WHEN no_data_found THEN
   v_Return:=False;
END;

if v_Return = False then
   RETURN v_Return;
end if;

-- las retenciones que ya estan vencidas no se les puede hacer una entrega a cuenta
-- solamente se podra en aquellas retenciones que no han pasado los 19 dias
select sum(IMPORTE_RETENIDO) into xImporteRetenido
	FROM CUENTAS_LOTES
		WHERE IdEXPE=xIDEXPE 
		AND FECHA_RETENCION is not null
		and to_char(FECHA_RETENCION,'ddd') + 19 < to_char(sysdate,'ddd')
		AND HECHO='N';

if xImporteRetenido IS NULL then
   v_Return:=False;
   xImporteRetenido:=0;
else
   v_Return:=True;
end if;

RETURN v_Return;

END;
/

--
-- número de dias que han pasado desde la retención y aún no se ha aplicado
-- 
CREATE OR REPLACE FUNCTION NumeroDeDias(xIDCuenta IN CUENTAS_LOTES.ID%Type)
RETURN INT
AS
xDias INT;
BEGIN

-- Número de días que han pasado desde la retención
-- y aún no se ha aplicado
   SELECT Trunc(Sysdate-FECHA_RETENCION) INTO xDias 
	FROM CUENTAS_LOTES
		WHERE ID=xIDCuenta 
		AND DILIGENCIA='S' 
		AND HECHO='N';

   RETURN xDias;
   exception
   	when no_data_found then
         Return 0;

END;
/

--
-- número de dias que han pasado desde la retención y aún no se ha aplicado
-- 
CREATE OR REPLACE FUNCTION NumeroDeDiasEImporte(xIDCuenta IN CUENTAS_LOTES.ID%Type,
				xRetencion OUT FLOAT)
RETURN INT
AS
xDias INT;
BEGIN

-- Número de días que han pasado desde la retención
-- y aún no se ha aplicado
   SELECT Trunc(Sysdate-FECHA_RETENCION),IMPORTE_RETENIDO INTO xDias,xRetencion 
	FROM CUENTAS_LOTES
		WHERE ID=xIDCuenta 
		AND DILIGENCIA='S' 
		AND HECHO='N';

   RETURN xDias;
   exception
   	when no_data_found then
     	   xRetencion:=0;
     	   Return 0;
END;
/

--
-- número de dias que han pasado desde la retención y aún no se ha aplicado
-- 
CREATE OR REPLACE FUNCTION SumaImporteRetenido(xIDExpe IN INT)
RETURN FLOAT
AS
vRetenido FLOAT;
BEGIN

   SELECT SUM(IMPORTE_RETENIDO) INTO vRetenido
	FROM CUENTAS_LOTES
		WHERE ID=xIDExpe 
		AND DILIGENCIA='S' 
		AND HECHO='N';

   RETURN vRetenido;
   exception
     	when no_data_found then
     	   Return 0;

END;
/

--
-- Contar el número de recibos vivos y suspendidos de un expediente
--
CREATE OR REPLACE PROCEDURE RecibosVivosSuspen(
	xIDExpe In INT,
	xVivos OUT INT,
	xSuspe OUT INT)
AS

CURSOR cVALORES IS
	Select F_SUSPENSION
      from valores
      where Expediente=xIDExpe
            AND FECHA_DE_BAJA IS NULL
            AND F_INGRESO IS NULL;

BEGIN

xSuspe:=0;
xVivos:=0;


FOR v_cVALORES IN cVALORES LOOP

    IF v_cVALORES.F_SUSPENSION IS NULL THEN
		xVivos:=xVivos+1;
    ELSE
       	xSuspe:=xSuspe+1;
    END IF;

END LOOP;

END;
/


-- -----------------------------------------------------------------------------------

