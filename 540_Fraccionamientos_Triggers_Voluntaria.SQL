-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_FRACCIONAMIENTO_VOL
BEFORE INSERT ON FRACCIONAMIENTO_VOL
FOR EACH ROW

BEGIN
   SELECT GENERFRAC.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID 
   WHERE USUARIO=USER; 
END T_INS_FRACCIONAMIENTO_VOL;
/

/********************************************************************************************/
CREATE OR REPLACE TRIGGER T_INS_PLAZOS_FRAC_VOL
BEFORE INSERT ON PLAZOS_FRAC_VOL
FOR EACH ROW

BEGIN
   SELECT GENERPFRAC.NEXTVAL INTO :NEW.ID FROM DUAL;
   UPDATE USUARIOS SET LAST_NUMERO=:NEW.ID 
   WHERE USUARIO=USER; 
END T_INS_PLAZOS_FRAC_VOL;
/


