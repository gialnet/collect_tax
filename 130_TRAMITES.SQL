-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- Modificado 22-10-2002. Si el nuevo tipo es '0', deja al expediente en estado 'C', no 'P'.
-- -----------------------------------------------------

/***********************************************************************/
CREATE OR REPLACE PROCEDURE CAMBIAR_PRELACION_UNO(
        xIDEXPE  IN INTEGER,
		xTIPO IN CHAR)
AS
xTramiteNuevo VARCHAR2(150);
BEGIN

   IF xTIPO='0' THEN -- Indica que se quiere eliminar el embargo. 
     -- Este es un caso especial que sólo se llama desde el pendiente de cuentas.
     UPDATE EXPEDIENTES SET EMBARGO_1='0' WHERE ID=xIDEXPE AND EMBARGO_1='P';
     PKSeguimiento.NotaInformativa(xIDEXPE,'El expediente no tiene trámite de cuentas corrientes');	
     RETURN;
   END IF;

   -- Trámite al que lo pasamos
   SELECT SUBSTR(TEXTO,0,30) INTO xTramiteNuevo FROM EMBARGOS
		WHERE EMBARGO=xTIPO;

   xTramiteNuevo:='Se incorpora a la prelación de ' ||xTramiteNuevo;

   PkSeguimiento.NotaInformativa(xIDExpe,xTramiteNuevo);

   UPDATE EXPEDIENTES SET 
   			EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   			EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
   			EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
   			EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
   			EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
		    RETENIDO=0,
	        FECHA_RETENCION=NULL,
		    INTERES_DILIGENCIA=0  -- Al cambiar de tramite se borra el lote y 
						-- su estado con un trigger
   WHERE ID=xIDEXPE;

END;
/


/***********************************************************************/
-- Modificacion: 19/01/2004. Gloria Maria Calle Hernandez. Si se trata de un deudor jurídico 
-- no pasará al embargo de salarios, pues no tiene sentido, pasará al embargo de inmuebles.
-- Modificacion: 26/05/2004. Gloria Maria Calle Hernandez. El cambio anterior sobre si se trata 
-- de un deudor jurídico no pasará al embargo de salarios sino al embargo de inmuebles, sólo se 
-- produce cuando xTIPO vale 3, es decir, si se está pasando al embargo de salarios.
/***********************************************************************/
CREATE OR REPLACE PROCEDURE CAMBIAR_PRELACION_TODOS(
		TRAMITE IN CHAR, 
		xTIPO   IN CHAR)
AS

   xZONA CHAR(2);

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;
   
   IF TRAMITE='1' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_1='P';
   
   ELSIF TRAMITE='3' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_3='P';

   ELSIF TRAMITE='4' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_4='P';
     
   ELSIF TRAMITE='8' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_8='P';
     
   ELSIF TRAMITE='X' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_X='P';
   END IF;


 END;
/


/***********************************************************************/
-- Modificacion: 19/01/2004. Gloria Maria Calle Hernandez. Si se trata de un deudor jurídico 
-- no pasará al embargo de salarios, pues no tiene sentido, pasará al embargo de inmuebles.
-- Modificacion: 26/05/2004. Gloria Maria Calle Hernandez. El cambio anterior sobre si se trata 
-- de un deudor jurídico no pasará al embargo de salarios sino al embargo de inmuebles, sólo se 
-- produce cuando xTIPO vale 3, es decir, si se está pasando al embargo de salarios.
/***********************************************************************/
CREATE OR REPLACE PROCEDURE CAMBIAR_PRELACION_IMPORTE(
		TRAMITE IN CHAR, 
		xDESDE  IN FLOAT, 
		xHASTA  IN FLOAT, 
		xTIPO   IN CHAR)
AS
 
   xZONA CHAR(2);

BEGIN

   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   IF TRAMITE='1' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_1='P'
          AND ID IN (SELECT EXPEDIENTE FROM PendiValoresExpe
                 WHERE pendiente BETWEEN ROUND(xDESDE,2) AND ROUND(xHASTA,2));
   
   ELSIF TRAMITE='3' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_3='P'
          AND ID IN (SELECT EXPEDIENTE FROM PendiValoresExpe
                 WHERE pendiente BETWEEN ROUND(xDESDE,2) AND ROUND(xHASTA,2));

   ELSIF TRAMITE='4' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_4='P'
          AND ID IN (SELECT EXPEDIENTE FROM PendiValoresExpe
                 WHERE pendiente BETWEEN ROUND(xDESDE,2) AND ROUND(xHASTA,2));
     
   ELSIF TRAMITE='8' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_8='P'
          AND ID IN (SELECT EXPEDIENTE FROM PendiValoresExpe
                 WHERE pendiente BETWEEN ROUND(xDESDE,2) AND ROUND(xHASTA,2));
     
   ELSIF TRAMITE='X' THEN
     UPDATE EXPEDIENTES SET 
		RETENIDO=0,
		FECHA_RETENCION=NULL,
		INTERES_DILIGENCIA=0,
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
     WHERE ZONA=xZONA AND EMBARGO_X='P'
          AND ID IN (SELECT EXPEDIENTE FROM PendiValoresExpe
                 WHERE pendiente BETWEEN ROUND(xDESDE,2) AND ROUND(xHASTA,2));

   END IF;

END;
/


-- Cambia un expediente a pendiente de algún trámite
-- También sirve para parar momentaneamente la ejecución de trámites
-- para esto el tipo debe ser 'P'
-- /*DELPHI*/ unit FConsultaExpediente;

CREATE OR REPLACE PROCEDURE CHG_TRAMITE(xIDExpe IN INT,
	xTIPO IN CHAR,
	xFechaAviso IN DATE,
	xCausa	IN CHAR)
AS
BEGIN

  UPDATE EXPEDIENTES SET 
   		EMBARGO_1=DECODE(xTIPO,'1',DECODE(EMBARGO_1,'0','P',EMBARGO_1),EMBARGO_1),
   	    EMBARGO_3=DECODE(xTIPO,'3',DECODE(EMBARGO_3,'0','P',EMBARGO_3),EMBARGO_3),
	    EMBARGO_4=DECODE(xTIPO,'4',DECODE(EMBARGO_4,'0','P',EMBARGO_4),EMBARGO_4),
	    EMBARGO_8=DECODE(xTIPO,'8',DECODE(EMBARGO_8,'0','P',EMBARGO_8),EMBARGO_8),
	    EMBARGO_X=DECODE(xTIPO,'X',DECODE(EMBARGO_X,'0','P',EMBARGO_X),EMBARGO_X),
	    F_AVISO_OUTLOOK=xFechaAviso
	WHERE ID=xIDExpe;

  PkSeguimiento.NotaInformativa(xIDExpe, xCausa);

END;
/



/***********************************************************************/
COMMIT;
/********************************************************************/
