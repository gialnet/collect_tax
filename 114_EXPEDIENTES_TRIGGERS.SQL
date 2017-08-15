-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
--No dejar pasar a salarios los nif de las sociedades, solo los de los deudores asalariados
--
--
-- Ultima modificacion: 25 de Octubre de 2001 Agustin Leon Robles. Actualizar en la tabla 
-- salarios el nuevo numero de expediente por si ya hubiera tenido otro con anterioridad
--
CREATE OR REPLACE TRIGGER T_EXPE_EMBARGO_3
BEFORE UPDATE OF EMBARGO_3 ON EXPEDIENTES
FOR EACH ROW
DECLARE
   xCont INTEGER;
BEGIN

  IF :NEW.EMBARGO_3 = 'P'  AND :OLD.EMBARGO_3<>'P' THEN -- Se está intentando pasar al pendiente de salarios.
    
    --No dejar pasar a salarios los nif de las sociedades, solo los de los deudores asalariados
    IF SUBSTR(:NEW.DEUDOR,1,1) NOT IN ('X','1','2','3','4','5','6','7','8','9','0') THEN

      :NEW.EMBARGO_3:=:OLD.EMBARGO_3; 
      IF :NEW.EMBARGO_4='0' THEN -- Si no está el expediente en trámite de inmuebles, lo pasa al pendiente.
        :NEW.EMBARGO_4 := 'P';
        :NEW.F_EMBARGO_INMUEBLES:=SYSDATE;
      END IF;

 
    ELSE

      :NEW.F_EMBARGO_SALARIOS:=SYSDATE;
      :NEW.FECHA_DILI_SALARIOS:=NULL;
      
      UPDATE SALARIOS SET IDEXPE=:NEW.ID WHERE NIF=:NEW.DEUDOR;
      SELECT COUNT(*) INTO xCont FROM SALARIOS WHERE IDEXPE=:NEW.ID;
      IF xCont>0 THEN
        :NEW.E_LOTE3:='R';
      ELSE
        if :NEW.LOTE_3 is null then
          :NEW.E_LOTE3:='N';
        else
          :NEW.E_LOTE3:='S';
        end if;
      END IF;
    END IF;
  
  END IF;
  
  IF :NEW.EMBARGO_3 = '0' AND :OLD.EMBARGO_3<>'0' THEN -- Se está eliminando el expediente del tramite de salarios
    :NEW.F_EMBARGO_SALARIOS:=NULL;
    :NEW.FECHA_DILI_SALARIOS:=NULL;
    :NEW.LOTE_3:=NULL;
    :NEW.E_LOTE3:='N';
  END IF;

END;
/

CREATE OR REPLACE TRIGGER T_EXPE_EMBARGO_1
BEFORE UPDATE OF EMBARGO_1 ON EXPEDIENTES
FOR EACH ROW
BEGIN

  IF :NEW.EMBARGO_1 = 'P' AND :OLD.EMBARGO_1<>'P' THEN -- Se está intentando pasar al pendiente de cuentas.
    :NEW.F_EMBARGO_CUENTAS:=SYSDATE;
    :NEW.FECHA_DILI_CUENTAS:=NULL;
  END IF;
  
  IF :NEW.EMBARGO_1 = '0' AND :OLD.EMBARGO_1<>'0' THEN -- Se está eliminando el expediente del tramite de cuentas
    :NEW.F_EMBARGO_CUENTAS:=NULL;
    :NEW.FECHA_DILI_CUENTAS:=NULL;
  END IF;

END;
/

CREATE OR REPLACE TRIGGER T_EXPE_EMBARGO_4
BEFORE UPDATE OF EMBARGO_4 ON EXPEDIENTES
FOR EACH ROW
BEGIN

  IF :NEW.EMBARGO_4 = 'P' AND :OLD.EMBARGO_4<>'P' THEN -- Se está intentando pasar al pendiente de inmuebles.
    :NEW.F_EMBARGO_INMUEBLES:=SYSDATE;
    :NEW.FECHA_DILI_SALARIOS:=NULL;
  END IF;
  
  IF :NEW.EMBARGO_4 = '0' AND :OLD.EMBARGO_4<>'0' THEN -- Se está eliminando el expediente del tramite de inmuebles
    :NEW.F_EMBARGO_INMUEBLES:=NULL;
    :NEW.FECHA_DILI_INMUEBLES:=NULL;
  END IF;

END;
/

CREATE OR REPLACE TRIGGER T_EXPE_EMBARGO_8
BEFORE UPDATE OF EMBARGO_8 ON EXPEDIENTES
FOR EACH ROW
BEGIN

  IF :NEW.EMBARGO_8 = 'P' AND :OLD.EMBARGO_8<>'P' THEN -- Se está intentando pasar al pendiente de vehiculos.
    :NEW.F_EMBARGO_VEHICULOS:=SYSDATE;
    :NEW.FECHA_DILI_VEHICULOS:=NULL;
  END IF;
  
  IF :NEW.EMBARGO_8 = '0' AND :OLD.EMBARGO_8<>'0' THEN -- Se está eliminando el expediente del tramite de vehiculos
    :NEW.F_EMBARGO_VEHICULOS:=NULL;
    :NEW.FECHA_DILI_VEHICULOS:=NULL;
  END IF;

END;
/

CREATE OR REPLACE TRIGGER T_EXPE_EMBARGO_X
BEFORE UPDATE OF EMBARGO_X ON EXPEDIENTES
FOR EACH ROW
BEGIN

  IF :NEW.EMBARGO_X = 'P'  AND :OLD.EMBARGO_X<>'P' THEN -- Se está intentando pasar al pendiente de otros trámites
    :NEW.F_EMBARGO_OTROS:=SYSDATE;
  END IF;
  
  IF :NEW.EMBARGO_X = '0' AND :OLD.EMBARGO_X<>'0' THEN -- Se está eliminando el expediente del tramite de OTROS
    :NEW.F_EMBARGO_OTROS:=NULL;
  END IF;

END;
/
/*CREATE OR REPLACE TRIGGER T_NoSalaEmpresas
BEFORE UPDATE OF EMBARGO ON EXPEDIENTES
FOR EACH ROW
DECLARE
   xCont INTEGER;
BEGIN

--si no esta en este intervalo significa que el expediente es de una empresa
IF SUBSTR(:NEW.DEUDOR,1,1) NOT IN ('X','1','2','3','4','5','6','7','8','9','0') THEN

   IF :NEW.EMBARGO='3' THEN --Salarios
      :NEW.EMBARGO := '4';
	:NEW.ESTA_EMBARGO := 'P';
   END IF;

END IF;

-- SI ESTA YA EN INMUEBLES SOLO PODRÁ IR A CUENTAS O A INMUEBLES
IF :NEW.EN_OTROTRAMITE='S' THEN
   IF :NEW.EMBARGO NOT IN ('1','4') THEN --En caso contrario a inmuebles
	:NEW.EMBARGO:='4';
	:NEW.EN_OTROTRAMITE:='N';
	:NEW.ESTA_EMBARGO:='O';
   END IF;

   IF :NEW.EMBARGO='4' THEN 
	:NEW.EN_OTROTRAMITE:='N';
	:NEW.ESTA_EMBARGO:='O';
   END IF;   

   UPDATE EMBARGOS_INMUEBLES SET EN_OTROTRAMITE='N' WHERE IDEXPE=:NEW.ID;

END IF;

-- Si pasamos de un tramite a otro, se pierde el numero de lote y estado porque en 
-- el nuevo tramite estos campos tendran otro significado. Por eso se borran.
IF :NEW.EMBARGO<>:OLD.EMBARGO THEN
	:NEW.LOTE:=NULL;
	:NEW.E_LOTE:='N';
END IF;

-- Si el contribuyente ha tenido un expediente con anterioridad y se le ha hecho un embargo de
-- salarios, hay que actualizar el campo idexpe en salarios con el nuevo numero de expediente
-- sino, a la hora de añadir el expediente en el embargo de salarios no te deja.
IF :NEW.EMBARGO='3' THEN
	UPDATE SALARIOS SET IDEXPE=:NEW.ID WHERE NIF=:NEW.DEUDOR;
	SELECT COUNT(*) INTO xCont FROM SALARIOS WHERE IDEXPE=:NEW.ID;
	IF xCont>0 THEN
	   :NEW.E_LOTE:='R';
	ELSE
	   :NEW.E_LOTE:='N';
	END IF;
	
END IF;

END;
/

*/

--
-- Se encarga de poner los estados de expedientes en caso de ingreso o reposición
--
-- Modificado: 23/06/2003 Lucas Fernández Pérez. Reajusta el campo RECIBOS  
--	del expediente al reponer un ingreso.
--
-- Modificado: 26/08/2003 Lucas Fernández Pérez. 
--	El codigo_ingreso en expedientes, antes se ponía a 'FR', ahora se pone a 'FE'.
--
CREATE OR REPLACE TRIGGER PAGA_EXPEDIENTE
BEFORE UPDATE OF F_INGRESO ON EXPEDIENTES
FOR EACH ROW

DECLARE 

xCUANTOS INT;

BEGIN

	/* SE INTRODUCE LA FECHA DE INGRESO */
	IF (:OLD.F_INGRESO IS NULL AND :NEW.F_INGRESO IS NOT NULL) THEN	
		:NEW.AVISO:='000';
		:NEW.ESTADO:='PAGADO';
		:NEW.F_ESTADO:=SYSDATE;
		:NEW.F_SUSPENSION:=NULL;
		:NEW.F_AVISO:=SYSDATE;
		:NEW.RETENIDO:=0;
		:NEW.RECIBOS:=0;
		:NEW.FECHA_RETENCION:=NULL;
		-- No se borra la fecha de diligencia.:NEW.FECHA_DILIGENCIA:=NULL;
		:NEW.INTERES_DILIGENCIA:=0;	
		:NEW.PRESU_COSTAS:=0;
		:NEW.PRESU_DEMORA:=0;
	END IF;


	-- Se está reponiendo un ingreso
	IF (:NEW.F_INGRESO IS NULL AND :OLD.F_INGRESO IS NOT NULL) THEN	

		-- Recibos pendientes dentro de un expediente
		SELECT COUNT(*) INTO xCUANTOS FROM VALORES 
   			WHERE EXPEDIENTE=:NEW.ID
			AND F_SUSPENSION IS NULL;

		:NEW.AVISO:='005';
		
		IF :OLD.CODIGO_INGRESO<>'FE' THEN
			:NEW.ESTADO:='ABIERTO';
			:NEW.F_SUSPENSION:=NULL;
		ELSE
			:NEW.ESTADO:='FRACCIO';
			:NEW.F_SUSPENSION:=SYSDATE;	
		END IF;

		:NEW.F_ESTADO:=SYSDATE;
		:NEW.F_AVISO:=SYSDATE;

		:NEW.RECIBOS:=xCUANTOS;
		:NEW.CODIGO_INGRESO:=NULL;
		:NEW.CARTA_PAGO:='N';

	END IF;


END;
/

CREATE OR REPLACE TRIGGER T_NotiTercerosExpe
BEFORE UPDATE OF AVISO ON EXPEDIENTES
FOR EACH ROW

BEGIN

IF :NEW.AVISO='010' THEN

   -- SE ENCARGA DE REALIZAR TODOS LOS AVISOS A GESTORES, GERENTES JEFES DE ZONA ETC.
   LISTADEAVISOS(:NEW.ID,:NEW.EXPEDIENTE,:NEW.USUARIO, :NEW.AVISO, :NEW.ZONA);


END IF;

END;
/


/*CONTROL DE SI HAY RECIBOS SUSPENDIDOS EN EL EXPEDIENTE, PARA QUE A LA HORA DE 
  DAR POR PAGADO UN EXPEDIENTE PODER CONTROLAR SI HAY RECIBOS SUSPENDIDOS */


CREATE OR REPLACE TRIGGER CUANTOS_SUSPENSOS
BEFORE UPDATE OF CUANTOS_R_SUSPEN ON EXPEDIENTES
FOR EACH ROW
BEGIN


IF (:NEW.CUANTOS_R_SUSPEN<>:OLD.CUANTOS_R_SUSPEN) THEN
	
	IF (:NEW.CUANTOS_R_SUSPEN>0) THEN

		:NEW.R_SUSPENDIDOS:='S';
	ELSE
		:NEW.R_SUSPENDIDOS:='N';
	END IF;

END IF;

END;
/

