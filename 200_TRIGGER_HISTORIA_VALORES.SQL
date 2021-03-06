-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fern�ndez P�rez 
-- No se han realizado cambios.
-- Modificaci�n: 30/01/2004 M� Carmen Junco G�mez. Faltaba insertar la descripci�n
--               para los c�digos SV y AS
-- -----------------------------------------------------
/* C�DIGOS DE HISTORIA VALORES 
VE: Ventanilla Recaudaci�n
VB: Ventanilla Banco (cuaderno 60)
PD: Domiciliaci�n (cuaderno 19)
CM: Compensaci�n
CC: Embargo total de Cuentas C. (cuaderno 63)
BB: Ventanilla Banco para ejecutiva
ER: Entrega a un valor
EE: Entrega a un expediente

BA: Baja
BR: Baja por reposici�n a voluntaria
BI: Baja por insolvencia
BP: Baja por prescripci�n
BO: Baja por otros motivos
BN: Baja por anulaci�n del recargo

RI: Reposici�n al cobro de un ingreso
AB: Anulaci�n de una baja

SV: Suspensi�n de un valor
AS: Anulaci�n de la suspensi�n de un valor

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
	xDESCRI:='ANULACI�N DE BAJA';
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

