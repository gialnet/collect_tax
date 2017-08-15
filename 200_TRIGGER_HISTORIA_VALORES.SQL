-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- Modificación: 30/01/2004 Mª Carmen Junco Gómez. Faltaba insertar la descripción
--               para los códigos SV y AS
-- -----------------------------------------------------
/* CÓDIGOS DE HISTORIA VALORES 
VE: Ventanilla Recaudación
VB: Ventanilla Banco (cuaderno 60)
PD: Domiciliación (cuaderno 19)
CM: Compensación
CC: Embargo total de Cuentas C. (cuaderno 63)
BB: Ventanilla Banco para ejecutiva
ER: Entrega a un valor
EE: Entrega a un expediente

BA: Baja
BR: Baja por reposición a voluntaria
BI: Baja por insolvencia
BP: Baja por prescripción
BO: Baja por otros motivos
BN: Baja por anulación del recargo

RI: Reposición al cobro de un ingreso
AB: Anulación de una baja

SV: Suspensión de un valor
AS: Anulación de la suspensión de un valor

RM: Recargo Manual del 10% o del 20%
*/

CREATE OR REPLACE TRIGGER TR_HISTORIA_VALORES
BEFORE UPDATE OF 
F_INGRESO,FECHA_DE_BAJA,F_SUSPENSION,ENTREGAS_A_CUENTA,CODIGO_DE_BAJA ON VALORES
FOR EACH ROW
DECLARE
xTipo CHAR(2);
xDESCRI VARCHAR2(70);
SiInserto char(1) default 'N';
BEGIN

/* INGRESO */
IF (:OLD.F_INGRESO IS NULL) AND (:NEW.F_INGRESO IS NOT NULL) THEN
	xTipo:=:NEW.COD_INGRESO;
	xDESCRI:='INGRESO';
	SiInserto:='S';
ELSE
	--Estoy realizando una entrega a cuenta 
	--la reposicion al cobro de ingreso parcial se hace en el trigger DEL_INGRESOS
	IF (:NEW.ENTREGAS_A_CUENTA>:OLD.ENTREGAS_A_CUENTA) THEN
		xTipo:=:NEW.COD_INGRESO;
		xDescri:='ENTREGAS A CUENTA';
		SiInserto:='S';
	END IF;
END IF;


/* ANULACION DE UN INGRESO */
IF (:OLD.F_INGRESO IS NOT NULL) AND (:NEW.F_INGRESO IS NULL) THEN
	xTipo:='RI';
	SELECT RTRIM(SUBSTR(TEXTO,1,70)) INTO xDESCRI FROM USUARIOS WHERE USUARIO=USER;
	SiInserto:='S';
END IF;


/* BAJA */
IF (:NEW.FECHA_DE_BAJA IS NOT NULL) AND (:OLD.FECHA_DE_BAJA IS NULL) THEN
	xTipo:=:NEW.CODIGO_DE_BAJA;
	xDESCRI:='BAJA';
	SiInserto:='S';
END IF;

/* ANULACION DE UNA BAJA */
IF (:NEW.FECHA_DE_BAJA IS NULL) AND (:OLD.FECHA_DE_BAJA IS NOT NULL) THEN
	xTipo:='AB';
	xDESCRI:='ANULACIÓN DE BAJA';
	SiInserto:='S';
END IF;

/* SUSPENSION */
IF (:NEW.F_SUSPENSION IS NOT NULL) AND (:OLD.F_SUSPENSION IS NULL) THEN
	xTipo:='SV';
	xDESCRI:='SUSPENSION VALOR';
	SiInserto:='S';       
END IF;

/* ANULACION DE UNA SUSPENSION */
IF (:NEW.F_SUSPENSION IS NULL) AND (:OLD.F_SUSPENSION IS NOT NULL) THEN
	xTipo:='AS';
	xDESCRI:='ANULACION SUSPENSION';
	SiInserto:='S';
END IF;

if SiInserto='S' then
	INSERT INTO HISTORIA_VALORES
	     (ID,VALOR,COD_OPERACION,NIF,NOMBRE,FECHA,
      	TIPO_DATA,EXPLICACION,USUARIO,TERMINAL)
	VALUES
		(GEN_H_VALOR.NEXTVAL,:NEW.ID,:NEW.CODIGO_OPERACION,:NEW.NIF,:NEW.NOMBRE,
		SYSDATE, xTipo, xDESCRI, USER, UID);
end if;

END;
/

