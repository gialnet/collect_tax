-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/********************************************************************************************/

CREATE OR REPLACE TRIGGER T_NEWNOTI
BEFORE INSERT ON NOTIFICACIONES
FOR EACH ROW
BEGIN

SELECT GENERIDNOTI.NEXTVAL INTO :NEW.ID FROM DUAL;

IF (:NEW.EXPEDIENTE IS NOT NULL) THEN
	:NEW.N_ORDEN:=:NEW.ID;
END IF;

END;
/


/* ***************************************************************** */

CREATE OR REPLACE TRIGGER T_GENNOTI
AFTER UPDATE ON GENERNOTI
FOR EACH ROW

BEGIN

   IF :OLD.ID_RELACION <> :NEW.ID_RELACION THEN
      UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID_RELACION WHERE USUARIO=USER;
   END IF;


END;
/
