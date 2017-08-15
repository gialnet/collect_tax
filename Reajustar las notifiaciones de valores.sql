--
--
--
create or replace procedure borrar
as
cursor cNotiValor is 
	select valor,F_1ACUSE,F_PUBLICACION from notificaciones
		where expediente is null and notificado='S';
begin


FOR v_cNotiValor IN cNotiValor LOOP

  UPDATE VALORES SET F_NOTIFICACION=
     DECODE(v_cNotiValor.F_PUBLICACION,NULL,v_cNotiValor.F_1ACUSE,v_cNotiValor.F_PUBLICACION)
		WHERE ID=v_cNotiValor.VALOR;

END LOOP;

end;
/
EXECUTE BORRAR;
DROP PROCEDURE BORRAR;



--
-- Como se ha modificado la funcionalidad de la prescripción, hay que repasar la base
-- de datos completa de los clientes para que reflejen la nueva situación
-- En la tabla de valores se va a guardar la última comunicación válida con el sujeto pasivo
--

CREATE OR REPLACE PROCEDURE Borrar
AS

-- Valores vivos que pertenecen a un expediente vivo

CURSOR cValoExpe IS
 SELECT ID,EXPEDIENTE FROM VALORES 
	WHERE VOL_EJE='E'
	AND EXPEDIENTE IS NOT NULL
      AND F_INGRESO IS NULL
      AND FECHA_DE_BAJA IS NULL
	FOR UPDATE OF F_LAST_NOTI;


xFNOTI  DATE;
BEGIN


FOR v_cValoExpe IN cValoExpe LOOP

   -- buscar la notificación de expediente válida más reciente
   SELECT MAX(F_NOTIFICACION) INTO xFNOTI FROM NOTIFICACIONES
	WHERE EXPEDIENTE=v_cValoExpe.EXPEDIENTE
	AND NOTIFICADO='S';

   IF xFNOTI IS NOT NULL THEN

      UPDATE VALORES SET F_LAST_NOTI=xFNOTI WHERE CURRENT OF cValoExpe;

   END IF;


END LOOP;

END;
/

--
-- 25/02/2002 Antonio Pérez Caballero 
-- Proceder a los expedientes incobrables de todos los expedientes de una zona
--
CREATE OR REPLACE PROCEDURE Borrar
AS

xIDExpe INTEGER;
xNOCUENTAS		CHAR(1);
xNOSALARIOS		CHAR(1);
xNOINMUEBLES	CHAR(1);
xNOAUTOS		CHAR(1);
xNOOTROS		CHAR(1);

CURSOR cEXPE IS 
	SELECT ID FROM Expedientes
      where f_ingreso is null 
	AND f_anulacion is null 
	AND f_suspension is null;

CURSOR cSEGUI IS
	SELECT TIPO_TRAMITE FROM SEGUIMIENTO
	WHERE ID_EXPE=xIDExpe AND DEBE_O_HABER='N';

BEGIN

   FOR  v_cEXPE IN cEXPE  LOOP

	xIDExpe:=v_cEXPE.ID;

	xNOCUENTAS:='N';
	xNOSALARIOS:='N';
	xNOINMUEBLES:='N';
	xNOAUTOS:='N';
	xNOOTROS:='N';

	FOR v_cSEGUI IN cSEGUI LOOP

	    IF v_cSEGUI.TIPO_TRAMITE='1' THEN
		 xNOCUENTAS:='S';
	    END IF;
	    IF v_cSEGUI.TIPO_TRAMITE='3' THEN
		 xNOSALARIOS:='S';
	    END IF;
	    IF v_cSEGUI.TIPO_TRAMITE='4' THEN
		 xNOINMUEBLES:='S';
	    END IF;
	    IF v_cSEGUI.TIPO_TRAMITE='8' THEN
		 xNOAUTOS:='S';
	    END IF;
	    IF v_cSEGUI.TIPO_TRAMITE='X' THEN
		 xNOOTROS:='S';
	    END IF;

	END LOOP;

      UPDATE EXPEDIENTES SET NOCUENTAS=xNOCUENTAS,	
		NOSALARIOS=xNOSALARIOS,
		NOINMUEBLES=xNOINMUEBLES,
		NOAUTOS=xNOAUTOS,
		NOOTROS=xNOOTROS
	WHERE ID=xIDExpe;

   END LOOP;
 
END;
/

