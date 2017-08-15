--**************************************************************************************
--Autor: 14/03/2003 Mª del Carmen Junco Gómez.
--Acción: Procedimiento que rellena una tabla temporal para la impresión de informes
--        de la opción de Tramitaciones->Informes de Expedientes
--		Este procedimiento se debe a que el join entre expedientes y PendiValoresExpe
--		es excesivamente lento.
--Parámetros:
--		xTIPOINFORME: 0 -> Expedientes abiertos.
--                      4 -> Expedientes en sus diferentes estados de embargo.
--                      5 -> Expedientes pendientes de embargo.
--                      6 -> Expedientes por sus tipos de aviso.		 
--        xDESDE  : Desde la fecha.        
--        xHASTA  : Hasta la fecha.
--        xPDESDE : Desde el importe.
--        xPHASTA : Hasta el importe.         
--        xQUEPENDIENTE : 'T' todo el pendiente 'P' solo el principal pendiente
--        				 necesario para comparar con xPDESDE y xPHASTA.
--        xEMBARGO : Para listados tipo 4
--        xESTA    : Para listados tipo 5
--        xAVISO	 : Para listados tipo 6

-- Modificado: 17/06/2003. Lucas Fernández Pérez.
--	Nuevos tipo de informe 1 -> Expedientes Suspendidos
--						   2 -> Expedientes Anulados
--						   3 -> Expedientes Ingresados
-- Nuevo Parámetro xADD_SUSPEN -> Indica si incluir los recibos suspendidos en los importes
--
-- **************************************************************************************
CREATE OR REPLACE PROCEDURE RELLENA_TMP_INFORME_EXPE(
			xTIPOINFORME  IN INTEGER,
			xDESDE		  IN DATE,
			xHASTA		  IN DATE,
			xPDESDE		  IN FLOAT,
			xPHASTA		  IN FLOAT,
			xQUEPENDIENTE IN CHAR,
			xEMBARGO	  IN CHAR,			
			xAVISO		  IN CHAR,
			xADD_SUSPEN	  IN CHAR
)
AS
   xPENDIENTE 		FLOAT DEFAULT 0;
   xPRINPENDIENTE 	FLOAT DEFAULT 0;   
   xPRINCIPAL		FLOAT DEFAULT 0;
   xINGRESADO		FLOAT DEFAULT 0;
   xIMPORTE			FLOAT DEFAULT 0;
   xINSERTAR 		BOOLEAN;
   
   -- Expedientes abiertos
   CURSOR CEXPE_PENDI IS SELECT E.ID,E.EXPEDIENTE,E.DEUDOR,C.NOMBRE,
   					      E.EMBARGO,E.ESTA_EMBARGO,E.F_EMBARGO,E.RECIBOS,
   					      E.F_APERTURA,E.F_SUSPENSION,E.F_ANULACION,E.F_INGRESO,
   					      E.AVISO,E.F_AVISO
   						  FROM EXPEDIENTES E, CONTRIBUYENTES C
   		  				  WHERE E.DEUDOR=C.NIF AND E.ZONA IN 
   		  				  (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER)
   		  				  AND E.F_ANULACION IS NULL AND E.F_INGRESO IS NULL;   
   
   -- Expedientes Suspendidos   		  				  
   CURSOR CEXPE_SUSPEN IS SELECT E.ID,E.EXPEDIENTE,E.DEUDOR,C.NOMBRE,E.RECIBOS,
   					      E.F_APERTURA,E.F_SUSPENSION
   						  FROM EXPEDIENTES E, CONTRIBUYENTES C
   		  				  WHERE E.DEUDOR=C.NIF AND E.ZONA IN 
   		  				  (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER)
   		  				  AND E.F_SUSPENSION BETWEEN xDesde AND xHasta
   		  				  AND E.F_ANULACION IS NULL AND E.F_INGRESO IS NULL;   

   -- Expedientes Anulados   		  				  
   CURSOR CEXPE_ANULADOS IS SELECT E.ID,E.EXPEDIENTE,E.DEUDOR,C.NOMBRE,E.RECIBOS,
   					      E.F_APERTURA,E.F_ANULACION
   						  FROM EXPEDIENTES E, CONTRIBUYENTES C
   		  				  WHERE E.DEUDOR=C.NIF AND E.ZONA IN 
   		  				  (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER)
   		  				  AND E.F_ANULACION BETWEEN xDesde AND xHasta
   		  				  AND E.F_SUSPENSION IS NULL AND E.F_INGRESO IS NULL;   
   		  				  
   -- Expedientes Ingresados
   CURSOR CEXPE_INGRESADOS IS SELECT E.ID,E.EXPEDIENTE,E.DEUDOR,C.NOMBRE,E.RECIBOS,
   					      E.F_APERTURA,E.F_INGRESO
   						  FROM EXPEDIENTES E, CONTRIBUYENTES C
   		  				  WHERE E.DEUDOR=C.NIF AND E.ZONA IN 
   		  				  (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER)
   		  				  AND E.F_INGRESO BETWEEN xDesde AND xHasta
   		  				  AND E.F_ANULACION IS NULL AND E.F_SUSPENSION IS NULL;   
   		  				  
BEGIN

  DELETE FROM TMP_INFORME_EXPE WHERE USUARIO=UID;
   
  IF ( (xTIPOINFORME=0) OR (xTIPOINFORME=4) OR (xTIPOINFORME=5) OR (xTIPOINFORME=6) ) THEN

   	FOR vEXPE IN CEXPE_PENDI LOOP -- Recorre todos los expedientes pendientes
   
      xINSERTAR:=FALSE;      
      
      IF ((xADD_SUSPEN='S') OR (vEXPE.F_SUSPENSION IS NULL)) THEN 
        
      	-- Obtenemos el PRINCIPAL e IMPORTE PENDIENTE del EXPEDIENTE
        if xADD_SUSPEN='S' then -- Los suspendidos entran en la suma
	      	SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS_A_CUENTA+DEMORA_PENDIENTE ) 
      				AS PENDIENTE, SUM(PRINCIPAL) INTO xPENDIENTE, xPRINCIPAL
   			FROM VALORES 
   			WHERE EXPEDIENTE=vEXPE.ID AND 
   				F_INGRESO IS NULL AND 
   				FECHA_DE_BAJA IS NULL;
        else  -- Los suspendidos NO ENTRAN en la suma
	      	SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA-ENTREGAS_A_CUENTA+DEMORA_PENDIENTE ) 
      				AS PENDIENTE, SUM(PRINCIPAL) INTO xPENDIENTE, xPRINCIPAL
   			FROM VALORES 
   			WHERE EXPEDIENTE=vEXPE.ID AND 
   				F_INGRESO IS NULL AND 
   				FECHA_DE_BAJA IS NULL AND
	   		 	F_SUSPENSION is NULL;
        end if;
   		 	
   		IF xPRINCIPAL IS NULL THEN
      		xPRINCIPAL:=0;
      		xPENDIENTE:=0;
   		END IF;

   		IF xQUEPENDIENTE='P' THEN -- Pide el pendiente en principal

	      	if xADD_SUSPEN='S' then -- Los suspendidos entran en la suma
   		 		SELECT SUM(PRINCIPAL) INTO xINGRESADO
   				FROM INGRESOS 
   				WHERE VALOR IN (SELECT ID FROM VALORES 
   						WHERE EXPEDIENTE=vEXPE.ID AND 
   		 	    	     F_INGRESO IS NULL AND 
   		 	    	     FECHA_DE_BAJA IS NULL);
			else -- Los suspendidos NO ENTRAN en la suma
   		 		SELECT SUM(PRINCIPAL) INTO xINGRESADO
   				FROM INGRESOS 
   				WHERE VALOR IN (SELECT ID FROM VALORES 
   						WHERE EXPEDIENTE=vEXPE.ID AND 
   		 	    	     F_INGRESO IS NULL AND 
   		 	    	     FECHA_DE_BAJA IS NULL AND
   		                 F_SUSPENSION IS NULL);
			end if;
   		                 
        	if xINGRESADO IS NULL then
    	  		xINGRESADO:=0;
   			end if;  
   
   			xPRINPENDIENTE:=xPRINCIPAL-xINGRESADO;
   			
   			if xPRINPENDIENTE BETWEEN xPDESDE AND xPHASTA then
               xINSERTAR:=true;	
            end if;
   		
        ELSIF ((xQUEPENDIENTE='T') AND (xPENDIENTE BETWEEN xPDESDE AND xPHASTA)) THEN
               xINSERTAR:=true;
   		END IF;

         
		-- Informe de Expedientes ABIERTOS             
        IF ((xTIPOINFORME=0) AND (xINSERTAR=TRUE) AND 
            (vEXPE.F_APERTURA BETWEEN xDESDE AND xHASTA)) THEN
           xINSERTAR:=TRUE;
             
        -- Informe de Expedientes dentro de un tipo de embargo
        ELSIF ((xTIPOINFORME=4) AND (xINSERTAR=TRUE) AND (vEXPE.EMBARGO=xEMBARGO)) THEN
           IF ((vEXPE.EMBARGO='0') AND (vEXPE.ESTA_EMBARGO<>'C')) THEN
              xINSERTAR:=FALSE;
           ELSIF ((vEXPE.EMBARGO<>'0') AND (vEXPE.ESTA_EMBARGO<>'O')) THEN
              xINSERTAR:=FALSE;
           END IF;     
           
        -- Informe de Expedientes en el PENDIENTE de un tipo de embargo
        ELSIF ((xTIPOINFORME=5) AND (xINSERTAR=TRUE) AND 
            (vEXPE.EMBARGO=xEMBARGO) AND (vEXPE.ESTA_EMBARGO='P') AND 
            (vEXPE.F_EMBARGO BETWEEN xDESDE and xHASTA)) THEN
           xINSERTAR:=TRUE;
             
        -- Informe de Expedientes con un tipo de aviso
        ELSIF ((xTIPOINFORME=6) AND (xINSERTAR=TRUE) AND (vEXPE.AVISO=xAVISO)) THEN
            IF ((xAVISO<>'000') AND (vEXPE.F_AVISO NOT BETWEEN xDESDE AND xHASTA)) THEN
               xINSERTAR:=FALSE;
            END IF;          
            
        ELSE
        	xINSERTAR:=FALSE;
        END IF;   
                          
        IF (xINSERTAR) THEN                   
		   INSERT INTO TMP_INFORME_EXPE
          	   (ID,EXPEDIENTE,DEUDOR,NOMBRE,EMBARGO,RECIBOS,F_APERTURA,
	    	    F_SUSPENSION,F_ANULACION,PENDIENTE,PRINPENDIENTE)
		   VALUES
			   (vEXPE.ID,vEXPE.EXPEDIENTE,vEXPE.DEUDOR,vEXPE.NOMBRE,vEXPE.EMBARGO,
			    vEXPE.RECIBOS,vEXPE.F_APERTURA,vEXPE.F_SUSPENSION,vEXPE.F_ANULACION,
			    xPENDIENTE,xPRINPENDIENTE);
		END IF;                               
      
      END IF;
      
    END LOOP;

  END IF;
  
  
  -- SUSPENDIDOS
  IF xTIPOINFORME=1 THEN 

 	FOR vEXPE IN CEXPE_SUSPEN LOOP -- Recorre todos los expedientes suspendidos

		SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE ) AS IMPORTE,
				 SUM(PRINCIPAL) INTO xIMPORTE, xPRINCIPAL
   		FROM VALORES 
   		WHERE EXPEDIENTE=vEXPE.ID AND F_SUSPENSION is NOT NULL;
   		 	
   		IF xPRINCIPAL IS NULL THEN
      		xPRINCIPAL:=0;
      		xIMPORTE:=0;
   		END IF;

	   	INSERT INTO TMP_INFORME_EXPE
          	   (ID,EXPEDIENTE,DEUDOR,NOMBRE,RECIBOS,
          	   		F_APERTURA,F_SUSPENSION,PENDIENTE,PRINPENDIENTE)
	   	VALUES
			   (vEXPE.ID,vEXPE.EXPEDIENTE,vEXPE.DEUDOR,vEXPE.NOMBRE,vEXPE.RECIBOS,
			   		vEXPE.F_APERTURA,vEXPE.F_SUSPENSION,xIMPORTE,xPRINCIPAL);
  	END LOOP;
  	
  END IF;

  -- ANULADOS
  IF xTIPOINFORME=2 THEN 

 	FOR vEXPE IN CEXPE_ANULADOS LOOP -- Recorre todos los expedientes anulados

		SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE ) AS IMPORTE, 
				SUM(PRINCIPAL) INTO xIMPORTE, xPRINCIPAL
   		FROM VALORES 
   		WHERE EXPEDIENTE=vEXPE.ID AND FECHA_DE_BAJA is NOT NULL;
   		 	
   		IF xPRINCIPAL IS NULL THEN
      		xPRINCIPAL:=0;
      		xIMPORTE:=0;
   		END IF;

	    INSERT INTO TMP_INFORME_EXPE
          	   (ID,EXPEDIENTE,DEUDOR,NOMBRE,RECIBOS,
          	   		F_APERTURA,F_ANULACION,PENDIENTE,PRINPENDIENTE)
		VALUES
			   (vEXPE.ID,vEXPE.EXPEDIENTE,vEXPE.DEUDOR,vEXPE.NOMBRE,vEXPE.RECIBOS,
			   		vEXPE.F_APERTURA,vEXPE.F_ANULACION,xIMPORTE,xPRINCIPAL);
  	END LOOP;
  	
  END IF;
  
  -- INGRESADOS
  IF xTIPOINFORME=3 THEN 

 	FOR vEXPE IN CEXPE_INGRESADOS LOOP -- Recorre todos los expedientes ingresados

 		SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE ) AS IMPORTE,
      			 SUM(PRINCIPAL) INTO xIMPORTE, xPRINCIPAL
   		FROM VALORES 
   		WHERE EXPEDIENTE=vEXPE.ID AND F_INGRESO is NOT NULL;
   		 	
   		IF xPRINCIPAL IS NULL THEN
      		xPRINCIPAL:=0;
      		xIMPORTE:=0;
   		END IF;

		INSERT INTO TMP_INFORME_EXPE
          	   (ID,EXPEDIENTE,DEUDOR,NOMBRE,RECIBOS,
          	   		F_APERTURA,F_INGRESO,PENDIENTE,PRINPENDIENTE)
		VALUES
			   (vEXPE.ID,vEXPE.EXPEDIENTE,vEXPE.DEUDOR,vEXPE.NOMBRE,vEXPE.RECIBOS,
			   		vEXPE.F_APERTURA,vEXPE.F_INGRESO,xIMPORTE,xPRINCIPAL);
  	END LOOP;
  	
  END IF;
    
END;
/