/* Procedimiento en 085_LEVANTAMIENTOS_EMBARGOS.SQL */

CREATE OR REPLACE PROCEDURE CHECK_RETENIDO_LEVANTA(xIDExpe IN INTEGER)
AS
	xDiferencia	FLOAT DEFAULT 0;  --diferencia entre el pendiente y lo retenido
	xPendiente 	FLOAT DEFAULT 0;  --pendiente del expediente	
	sPrincipal 	float default 0;
	sRecargo 	float default 0;
	sCostas 	float default 0;
	sDemora 	float default 0;
	sPendiente 	float default 0;
BEGIN


	-- Diligencia en marcha
	IF EmbargoCuentaEnMarcha(xIDExpe) THEN

		PkIngresos.Get_PendienteRetenido(xIDExpe, xDiferencia);
   		PkIngresos.PENDIENTE_EXPE(xIDEXPE,'N',SYSDATE,sPrincipal,sRecargo,sCostas,
                	   			  sDemora, xPendiente);

        -- Haremos un levantamiento total si el pendiente del expediente es cero
        IF (xPendiente = 0) THEN
        
           LEVANTA_CUENTAS(xIDEXPE);
            
        -- Si queda pendiente y la diferencia entre lo pendiente y lo retenido es menor
        -- a cero, haremos un levantamiento parcial  
        ELSIF ((xPendiente > 0) AND (xDiferencia < 0)) THEN
           LEVANTA_PARCIAL_CUENTAS(xIDExpe, (xDiferencia * (-1)) );
        END IF;

	END IF;

END;
/

/***************************************************************************************/
/* NUEVO PROCEDIMIENTO 
Autor: 28/07/2003 Mª del Carmen Junco Gómez
Acción: Control del estado de embargos_cuentas y de diligencias_cuentas
*/

CREATE OR REPLACE PROCEDURE CUENTAS_CONTROL_ESTADOS(
				xIDEXPE 		IN	INT,      			
      			xEntidad 		IN	CHAR,
      			xOficina 		IN	CHAR,      			
      			xZONA 			IN 	CHAR,
      			xLOTE 			IN 	CHAR,
      			xF_DILIGENCIA 	IN	DATE) 
AS
	xCUANTOS INTEGER;      			
BEGIN

	-- Control del estado de embargos_cuentas
   	SELECT COUNT(*) INTO xCUANTOS
   	FROM CUENTAS_LOTES 
   	WHERE ZONA=xZONA
		  AND LOTE=xLOTE
		  AND IDEXPE=xIDExpe
		  AND DILIGENCIA='S' 
		  AND HECHO='N'
	      AND IMPORTE_RETENIDO=0;

   	IF xCUANTOS=0 THEN
      	UPDATE EMBARGOS_CUENTAS SET F_DILIGENCIA=NULL, 
      								PUEDO_DILIGENCIA='S', 
      								DEUDA_TOTAL=0
		WHERE IDEXPE=xIDExpe;

      	UPDATE EXPEDIENTES SET FECHA_DILIGENCIA=NULL,
      						   INTERES_DILIGENCIA=0
		WHERE ID=xIDExpe;
   	END IF;

    -- control del estado de diligencias_cuentas
   	UPDATE DILIGENCIAS_CUENTAS SET CUANTOS=CUANTOS-1 
   	WHERE ZONA=xZONA
		  AND LOTE=xLOTE
      	  and ENTIDAD=xEntidad 
		  and OFICINA=xOficina
		  AND FECHA_ENVIO=xF_DILIGENCIA
    RETURN CUANTOS INTO xCUANTOS;

   	IF xCUANTOS = 0 THEN
      	DELETE FROM DILIGENCIAS_CUENTAS 
      	WHERE ZONA=xZONA
	   		  AND LOTE=xLOTE
         	  AND ENTIDAD=xEntidad 
	   		  AND OFICINA=xOficina
   	   		  AND FECHA_ENVIO=xF_DILIGENCIA;
   	END IF;
   	
END;
/


CREATE PUBLIC SYNONYM CUENTAS_CONTROL_ESTADOS FOR .CUENTAS_CONTROL_ESTADOS;

/***************************************************************************************/
/* Procedimiento en 085_LEVANTAMIENTOS_EMBARGOS.SQL */

CREATE OR REPLACE PROCEDURE LEVANTA_UNA_CUENTA(
      xIDEXPE 	IN	INT,
      xNIF	 	IN	CHAR,
      xEntidad 	IN	CHAR,
      xOficina 	IN	CHAR,
      xDC 		IN	CHAR,
      xCuenta 	IN	CHAR,
      xZONA 	IN 	CHAR,
      xLOTE 	IN 	CHAR)
AS

	xID 		INTEGER;
	xRetenido 	FLOAT DEFAULT 0;
	xDeuda_a_embargar FLOAT DEFAULT 0;
	xFRete 	DATE;
	xF_DILIGENCIA DATE;
	xCUANTOS INT;

BEGIN

	/* comprobar que queda alguna cuenta con una 
       diligencia emitida sin aplicar su importe retenido */

	/* Si no hay cuentas salirnos sin mas, vía la excepcion */

   	BEGIN

      	SELECT IMPORTE_RETENIDO,FECHA_RETENCION,ID,F_DILIGENCIA,DEUDA_A_EMBARGAR
	   	INTO xRetenido,xFRete,xID,xF_DILIGENCIA,xDEUDA_A_EMBARGAR
      	FROM CUENTAS_LOTES 
      	WHERE ZONA=xZONA
	   		  AND LOTE=xLOTE
   	   		  AND IDEXPE=xIDExpe
	   		  AND DILIGENCIA='S' 
	   		  AND HECHO='N' 
         	  AND ENTIDAD=xEntidad 
	   		  AND OFICINA=xOficina
         	  AND DC=xDC 
	   		  AND CUENTA=xCuenta;

      	EXCEPTION
         	WHEN NO_DATA_FOUND THEN
            	RETURN;
   	END;

   	-- BORRAMOS LA CUENTA   	
   	DELETE FROM CUENTAS_LOTES WHERE ID=xID;

   	-- COMPROBAR SI HAY UNA TUPLA DE ESTE EXPEDIENTE EN EL LEVANTAMIENTO PARA LA FECHA
   	-- DE ENTRADA (SYSDATE) Y SIN ENVIAR EN DISCO FASE5
   	BEGIN
      	SELECT ID INTO xID FROM NEXT_LEVANTA_CUENTAS
		WHERE IDEXPE=xIDexpe AND TRUNC(F_ENTRADA)=TRUNC(SYSDATE) AND
			  F_ENVIO_FASE5 IS NULL;

      	EXCEPTION
      		WHEN NO_DATA_FOUND THEN
         		INSERT INTO NEXT_LEVANTA_CUENTAS
          			(IDEXPE,NIF,ZONA,LOTE)
	   			VALUES 
          			(xIDExpe,xNIF,xZONA,xLOTE)
          		RETURNING ID INTO xID;
   	END;
   
   	INSERT INTO CUENTAS_A_LEVANTAR
       (ID,IDEXPE,ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,RETENIDO,F_RETENCION)
   	VALUES  
       (xID,xIDExpe,xEntidad,xOficina,xDC,xCuenta,xDEUDA_A_EMBARGAR,xRetenido,xFRete);

   	PkSeguimiento.NotaInformativa(xIDExpe,'Se levanta embargo ' || xEntidad ||
                '-' || xOficina || '-'|| xDC || '-' || xCuenta);
                
    -- CONTROL DEL ESTADO de embargos_cuentas
    CUENTAS_CONTROL_ESTADOS(xIDEXPE,xEntidad,xOficina,      			
      						xZONA,xLOTE,xF_DILIGENCIA) ;
      						
END;
/

/***************************************************************************************/
/* Procedimiento en 085_LEVANTAMIENTOS_EMBARGOS.SQL */

CREATE OR REPLACE PROCEDURE LEVANTA_PARCIAL_CUENTAS(
			xIDExpe IN INTEGER, 
			xDeMasCobrado IN FLOAT)
AS
	xID INT;
	xTexto VARCHAR(150);
	xCuanto FLOAT;
	xtmpMasCobrado FLOAT DEFAULT 0;	
	xNIF CHAR(10);
	xZONA CHAR(2);
	xLOTE CHAR(10);
	xEntidad CHAR(4);
	xOficina CHAR(4);	

	CURSOR cDiligen IS
		   SELECT ID,DEUDA_A_EMBARGAR,FECHA_RETENCION,IMPORTE_RETENIDO,
		   		  ENTIDAD,OFICINA,DC,CUENTA,ZONA,LOTE,F_DILIGENCIA
		   FROM CUENTAS_LOTES
		   WHERE IdEXPE=xIDEXPE 
				 AND DILIGENCIA='S' 
				 AND HECHO='N'
				 AND IMPORTE_RETENIDO > 0
		   ORDER BY FECHA_RETENCION DESC;	

BEGIN

	xtmpMasCobrado:=xDeMasCobrado;

	-- Recorrer las diligencias con retenciones sin aplicar en orden inverso 
	-- de fecha de retención, e ir restando el importe ingresado de más hasta 
	-- cubrir las retenciones.
	-- Anotar en el seguimiento del expediente

   	-- COMPROBAR SI HAY UNA TUPLA DE ESTE EXPEDIENTE EN EL LEVANTAMIENTO PARA LA FECHA
   	-- DE ENTRADA (SYSDATE) Y SIN ENVIAR EN DISCO FASE5
   	BEGIN
      	SELECT ID INTO xID FROM NEXT_LEVANTA_CUENTAS
		WHERE IDEXPE=xIDexpe AND TRUNC(F_ENTRADA)=TRUNC(SYSDATE) AND
			  F_ENVIO_FASE5 IS NULL;

      	EXCEPTION
      		WHEN NO_DATA_FOUND THEN
      		BEGIN
      			SELECT NIF,ZONA,LOTE INTO xNIF,xZONA,xLOTE
      			FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDexpe;
         		INSERT INTO NEXT_LEVANTA_CUENTAS
          			(IDEXPE,NIF,ZONA,LOTE)
          		VALUES (xIDEXPE,xNIF,xZONA,xLOTE)	   			
          		RETURNING ID INTO xID;
          	END;
   	END;


	FOR v_cDiligen IN cDiligen LOOP

		IF xtmpMasCobrado >= v_cDiligen.IMPORTE_RETENIDO THEN

			-- Ponemos el campo de la nueva retencion a cero pues hay que devolverlo todo
			xCuanto:=0;

			xTexto:='Se levanta embargo, en un levantamiento parcial '|| 
					v_cDiligen.Entidad ||'-'||v_cDiligen.Oficina||'-'|| 
					v_cDiligen.DC||'-'||v_cDiligen.Cuenta|| 
					' importe retenido: '||to_char(v_cDiligen.IMPORTE_RETENIDO)||
					' nuevo importe: 0';
					
		    -- borramos la cuenta y comprobamos el estado del embargo		    		    
		    DELETE FROM CUENTAS_LOTES WHERE ID=v_cDiligen.ID;   			
   			
    		CUENTAS_CONTROL_ESTADOS(xIDEXPE,v_cDiligen.Entidad,v_cDiligen.Oficina,
    					v_cDiligen.ZONA,v_cDiligen.LOTE,v_cDiligen.F_DILIGENCIA);		    
   	
			-- Descontamos lo devuelto
			xtmpMasCobrado:=xtmpMasCobrado - v_cDiligen.IMPORTE_RETENIDO;

		ELSE

			-- Es suficiente con parte de esta retención

			xTexto:='Se levanta embargo, en un levantamiento parcial '|| 
			        v_cDiligen.Entidad||'-'||v_cDiligen.Oficina||'-'|| 
			        v_cDiligen.DC||'-'||v_cDiligen.Cuenta|| 
					' importe retenido: '||to_char(v_cDiligen.IMPORTE_RETENIDO)||
					' nuevo importe: '|| 
					To_char(v_cDiligen.IMPORTE_RETENIDO - xtmpMasCobrado);

			-- pondremos en el campo de la nueva retencion el importe ingresado de más
			xCuanto:=v_cDiligen.IMPORTE_RETENIDO - xtmpMasCobrado;

			-- Descontamos lo devuelto
			xtmpMasCobrado:=0;

		END IF;	

		-- Insertar la cuenta en cuentas a levantar
   		INSERT INTO CUENTAS_A_LEVANTAR
       		(ID,IDEXPE,ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,RETENIDO,
       		 F_RETENCION,NUEVARETEN)
   		VALUES  
       		(xID,xIDExpe,v_cDiligen.Entidad,v_cDiligen.Oficina,v_cDiligen.DC,
       		 v_cDiligen.Cuenta,v_cDiligen.DEUDA_A_EMBARGAR,     
			 v_cDiligen.IMPORTE_RETENIDO,v_cDiligen.FECHA_RETENCION,xCuanto);

		-- anotar en el seguimiento del expediente
		PkSeguimiento.NotaInformativa(xIDExpe, xTexto, v_cDiligen.ID);

		if xtmpMasCobrado=0 then
			return;
		end if;

	END LOOP;

END;
/

/*****************************************************************************************
Acción: Hace todo lo necesario para levantar un expediente del embargo de cuentas 
		corrientes, dejando una copia de todo y en situación para poder deshacer esta 
		operación.
		Levanta las cuentas con diligencia de un expediente.
		Las inserta en cuentas_a_levantar, lo anota en next_levanta_cuentas,y las copia en 
		borra_cuentas_lotes
		Lo anota en el seguimiento del expediente
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Se ha cambiado la estructura de las tablas
		next_levanta_cuentas y cuentas_a_levantar. También se almacena en la tabla
		borra_levantamientos el id del levantamiento del expediente para poder deshacer
		este paso.
******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_CUENTAS_A_LEVANTAR(xIDEXPE IN INTEGER)
AS

	xID INTEGER DEFAULT 0;

	-- Cuentas con diligencia sin aplicar de un determinado expediente
	CURSOR cCUENTAS IS 
		   SELECT *
		   FROM CUENTAS_LOTES 
  		   WHERE DILIGENCIA='S' 
				 AND HECHO='N' 
				 AND IDEXPE=xIDEXPE;

BEGIN

	--Grabamos en una tabla temporal para poder deshacer esta operación en caso
   	--de error humano
   	INSERT INTO BORRA_EMBARGOS_CUENTAS
   		(IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,EMBARGO,F_EMBARGO,
   		 QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,NOTIFICADO,NEXT_PRELA,
   		 ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,HUBO_CUENTAS,PUEDO_DILIGENCIA)
   	SELECT IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,EMBARGO,F_EMBARGO,
   		 QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,NOTIFICADO,NEXT_PRELA,
   		 ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,HUBO_CUENTAS,PUEDO_DILIGENCIA
   	FROM EMBARGOS_CUENTAS WHERE IDEXPE=xIDEXPE;   	   	
   
   	-- Solo levantamos las diligenciadas

	FOR vCuentas IN cCuentas LOOP

		-- COMPROBAR SI HAY UNA TUPLA DE ESTE EXPEDIENTE EN EL LEVANTAMIENTO PARA LA FECHA
   		-- DE ENTRADA (SYSDATE) Y SIN ENVIAR EN DISCO FASE5
   		BEGIN
      		SELECT ID INTO xID FROM NEXT_LEVANTA_CUENTAS
			WHERE IDEXPE=xIDexpe AND TRUNC(F_ENTRADA)=TRUNC(SYSDATE) AND
			  	  F_ENVIO_FASE5 IS NULL;

      		EXCEPTION
      			WHEN NO_DATA_FOUND THEN      		
         			INSERT INTO NEXT_LEVANTA_CUENTAS
          				(IDEXPE,NIF,ZONA,LOTE)
          			VALUES 
          				(xIDEXPE,vCuentas.NIF,vCuentas.ZONA,vCuentas.LOTE)	   			
          			RETURNING ID INTO xID;          	
   		END;
   	   			
      	INSERT INTO CUENTAS_A_LEVANTAR
          (ID,IDEXPE,ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,RETENIDO,F_RETENCION)
      	VALUES 
	      (xID,xIDExpe,vCuentas.ENTIDAD,vCuentas.OFICINA,vCuentas.DC,vCuentas.CUENTA,
	      vCuentas.DEUDA_A_EMBARGAR,vCuentas.IMPORTE_RETENIDO,vCuentas.FECHA_RETENCION);

		PkSeguimiento.NotaInformativa(xIDEXPE,'SE LEVANTA EMBARGO '|| 
					  vCuentas.ENTIDAD||'-'||vCuentas.OFICINA||'-'||
				      vCuentas.DC||'-'||vCuentas.CUENTA);
				      
		-- Grabamos la cuenta en una copia temporal para poder deshacer esta operación
   		-- en caso de error humano.   		
		INSERT INTO BORRA_CUENTAS_LOTES
     		(ID,LOTE,IDEXPE,EXPEDIENTE,ZONA,NIF,ENTIDAD,OFICINA,DC,CUENTA,CLAVE_SEGURIDAD,
	   	 	 IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,DILIGENCIA,F_DILIGENCIA,
	   	 	 DEUDA_A_EMBARGAR,VECES)
   		VALUES 
   			(vCuentas.ID,vCuentas.LOTE,vCuentas.IDEXPE,vCuentas.EXPEDIENTE,
   			vCuentas.ZONA,vCuentas.NIF,vCuentas.ENTIDAD,vCuentas.OFICINA,vCuentas.DC,
   			vCuentas.CUENTA,vCuentas.CLAVE_SEGURIDAD,vCuentas.IMPORTE_RETENIDO,
   			vCuentas.FECHA_RETENCION,vCuentas.NOTIFICADO,vCuentas.HECHO,vCuentas.DILIGENCIA,
	     	vCuentas.F_DILIGENCIA,vCuentas.DEUDA_A_EMBARGAR,vCuentas.VECES);	    
				      
		-- borramos la cuenta y comprobamos el estado del embargo		    		    
		DELETE FROM CUENTAS_LOTES WHERE ID=vCuentas.ID;   			
   			
    	CUENTAS_CONTROL_ESTADOS(xIDEXPE,vCuentas.Entidad,vCuentas.Oficina,
    					vCuentas.ZONA,vCuentas.LOTE,vCuentas.F_DILIGENCIA);		    	    		      

   	END LOOP;
   	
   	-- Grabamos el ID de la tabla next_levanta_cuentas para saber qué levantamiento
	-- sobre el expediente hay que eliminar en el caso de reposición
	IF (xID>0) THEN
		INSERT INTO BORRA_LEVANTAMIENTOS (IDEXPE,ID)
		VALUES (xIDEXPE,xID);	    
	END IF;

   	UPDATE EXPEDIENTES SET ESTA_EMBARGO='L',F_EMBARGO=SYSDATE WHERE ID=xIDEXPE;   	
   	
END;
/


/***************************************************************************************/
/* Procedimiento en 159_NEWCUENTAS.SQL */
/* se llama desde delphi */
CREATE OR REPLACE PROCEDURE DEL_LEVANTA_CUENTAS
	(xID IN INT)
AS
 
BEGIN
 
   delete from next_levanta_cuentas where ID=xID;
 
END;
/
/***************************************************************************************/
/* Procedimiento en 160_CUENTAS.SQL */

CREATE OR REPLACE PROCEDURE CUENTAS_FASE5
		(xFECHA			DATE,
		 xENTIDAD		CHAR,
		 xOFICINA		CHAR)
AS

	xID		INTEGER;
	xIDEXPE INTEGER;
	xIMP_TOTAL_EMBARGAR FLOAT DEFAULT 0;
	xIMP_TOTAL_RETEN 	FLOAT DEFAULT 0;
	xF_RETENCION 		DATE;
	xCCC1				CHAR(20);		
	xCCC2				CHAR(20);	
	xCCC3				CHAR(20);	
	xC_SEGURIDAD1		CHAR(12);
	xC_SEGURIDAD2		CHAR(12);
	xC_SEGURIDAD3		CHAR(12);
	xIMP_TOTAL_LEVANTAR	FLOAT DEFAULT 0;
	xTIPO_LEVANTA		CHAR(1);
	xIMP_LEVANTAR1		FLOAT DEFAULT 0;
	xTIPO_LEVANTA1		CHAR(1);
	xIMP_LEVANTAR2		FLOAT DEFAULT 0;
	xTIPO_LEVANTA2		CHAR(1);
	xIMP_LEVANTAR3		FLOAT DEFAULT 0;
	xTIPO_LEVANTA3		CHAR(1);
	xRETENIDO1			FLOAT DEFAULT 0;
	xNUEVARETEN1		FLOAT DEFAULT 0;
	xRETENIDO2			FLOAT DEFAULT 0;
	xNUEVARETEN2		FLOAT DEFAULT 0;
	xRETENIDO3			FLOAT DEFAULT 0;
	xNUEVARETEN3		FLOAT DEFAULT 0;
	
	i					INTEGER;
	xIMPORTE			FLOAT DEFAULT 0;
	xPENDIEXPE			FLOAT DEFAULT 0;	
	sPrincipal 			FLOAT DEFAULT 0;
	sRecargo 			FLOAT DEFAULT 0;
	sCostas 			FLOAT DEFAULT 0;
	sDemora 			FLOAT DEFAULT 0;	


	-- expedientes pendientes de levantar no enviados en otro disco.
	CURSOR CEXPEDIENTES IS 
			SELECT N.ID,N.IDEXPE,SUBSTR(N.NIF,1,9) AS NIF,N.F_ENTRADA,C.NOMBRE,
				   SUBSTR(C.VIA||' '||RTRIM(C.CALLE)||' '||C.NUMERO||' '||
				   C.ESCALERA||' '||C.PLANTA ||' '||C.PISO,1,39) AS DOMICILIO,
				   SUBSTR(C.POBLACION,1,12) AS POBLACION,C.CODIGO_POSTAL
			FROM NEXT_LEVANTA_CUENTAS N,CONTRIBUYENTES C
			WHERE N.NIF=C.NIF AND N.ZONA IN (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER)
				  AND TRUNC(N.F_ENTRADA)<=TRUNC(xFECHA) AND F_ENVIO_FASE5 IS NULL;
					
	-- cuentas asociadas a los expedientes pendientes de levantar						   		   
	-- (cuentas a levantar)
    CURSOR CCUENTAS_ENTIDAD IS SELECT ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,
    								  RETENIDO,NUEVARETEN    						        
    						   FROM CUENTAS_A_LEVANTAR
    					 	   WHERE ID=xID AND ENTIDAD=xENTIDAD;							   
    							  
	-- cuentas asociadas a los expedientes pendientes de levantar						   		   
	-- (cuentas a levantar)
    CURSOR CCUENTAS_OFICINA IS SELECT ENTIDAD,OFICINA,DC,CUENTA,DEUDA_A_EMBARGAR,
    								  RETENIDO,NUEVARETEN
    						   FROM CUENTAS_A_LEVANTAR
    						   WHERE ID=xID AND ENTIDAD=xENTIDAD AND OFICINA=xOFICINA;							       							  
	
BEGIN

	DELETE FROM TMP_CUENTAS_FASE5 WHERE USUARIO=UID;
	
	FOR vEXPEDIENTES IN CEXPEDIENTES
	LOOP
	
		xID:=vEXPEDIENTES.ID;	
		xIDEXPE:=vEXPEDIENTES.IDEXPE;		
		i:=0;
		
		IF xOFICINA='0000' THEN -- por entidad						
    			  
    	    -- recogemos el importe total de las retenciones efectuadas; para ello
    	    -- sumamos el campo RETENIDO de la tabla cuentas_a_levantar y el
    	    -- campo IMPORTE_RETENIDO de las posibles cuentas del expediente 
    	    -- para la entidad dada y que no necesiten ser levantadas.
    	    SELECT SUM(RETENIDO),MIN(F_RETENCION) 
    	    INTO xIMP_TOTAL_RETEN,xF_RETENCION
    	    FROM CUENTAS_A_LEVANTAR WHERE ID=xID AND ENTIDAD=xENTIDAD;     	    
    	    
    	    SELECT SUM(IMPORTE_RETENIDO) INTO xIMPORTE FROM CUENTAS_LOTES
    	    WHERE IDEXPE=xIDEXPE AND DILIGENCIA='S' AND HECHO='N' AND
    	    IMPORTE_RETENIDO>0 AND ENTIDAD=xENTIDAD AND 
    	    ENTIDAD||OFICINA||DC||CUENTA NOT IN (SELECT ENTIDAD||OFICINA||DC||CUENTA
    	    FROM CUENTAS_A_LEVANTAR WHERE ID=xID AND ENTIDAD=xENTIDAD);
    	    
    	    IF (xIMP_TOTAL_RETEN IS NULL) THEN
    	       xIMP_TOTAL_RETEN:=0;
    	    END IF; 	        	    
    	    
    	    IF (xIMPORTE IS NULL) THEN
    	       xIMPORTE:=0;
    	    END IF;
    	    
    	    xIMP_TOTAL_RETEN:=xIMP_TOTAL_RETEN+xIMPORTE;
			
    	    -- retenciones en las distintas cuentas y claves de seguridad
			FOR vCUENTAS IN CCUENTAS_ENTIDAD
			LOOP
				i:=i+1;				
				IF i=1 THEN
					xCCC1:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||
						   vCUENTAS.DC||vCUENTAS.CUENTA;
				    xRETENIDO1:=vCUENTAS.RETENIDO;
				    xNUEVARETEN1:=vCUENTAS.NUEVARETEN;
				    xIMP_TOTAL_EMBARGAR:=vCUENTAS.DEUDA_A_EMBARGAR;
				    SELECT MIN(CLAVE_SEGURIDAD)
				    INTO xC_SEGURIDAD1
				    FROM CUENTAS_CORRIENTES
				    WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC1;					
				ELSIF i=2 THEN
					xCCC2:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||
						   vCUENTAS.DC||vCUENTAS.CUENTA;
					xRETENIDO2:=vCUENTAS.RETENIDO;
				    xNUEVARETEN2:=vCUENTAS.NUEVARETEN;
				    SELECT MIN(CLAVE_SEGURIDAD) 
				    INTO xC_SEGURIDAD2
				    FROM CUENTAS_CORRIENTES
				    WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC2;
				ELSIF i=3 THEN
					xCCC3:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||
						   vCUENTAS.DC||vCUENTAS.CUENTA;
					xRETENIDO3:=vCUENTAS.RETENIDO;
				    xNUEVARETEN3:=vCUENTAS.NUEVARETEN;
				    SELECT MIN(CLAVE_SEGURIDAD) 
				    INTO xC_SEGURIDAD3
				    FROM CUENTAS_CORRIENTES
				    WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC3;
				END IF;
			END LOOP;			   			
		
		ELSE -- por oficina			
    			  
    	    -- recogemos el importe total de las retenciones efectuadas; para ello
    	    -- sumamos el campo RETENIDO de la tabla cuentas_a_levantar y el
    	    -- campo IMPORTE_RETENIDO de las posibles cuentas del expediente 
    	    -- para la entidad dada y que no necesiten ser levantadas.
    	    SELECT SUM(RETENIDO),MIN(F_RETENCION) 
    	    INTO xIMP_TOTAL_RETEN,xF_RETENCION
    	    FROM CUENTAS_A_LEVANTAR WHERE ID=xID AND ENTIDAD=xENTIDAD
    	    AND OFICINA=xOFICINA;     	    
    	    
    	    SELECT SUM(IMPORTE_RETENIDO) INTO xIMPORTE FROM CUENTAS_LOTES
    	    WHERE IDEXPE=xIDEXPE AND DILIGENCIA='S' AND HECHO='N' AND
    	    IMPORTE_RETENIDO>0 AND ENTIDAD=xENTIDAD AND OFICINA=xOFICINA AND
    	    ENTIDAD||OFICINA||DC||CUENTA NOT IN (SELECT ENTIDAD||OFICINA||DC||CUENTA
    	    FROM CUENTAS_A_LEVANTAR WHERE ID=xIDEXPE AND ENTIDAD=xENTIDAD 
    	    AND OFICINA=xOFICINA);
    	    
    	    IF (xIMP_TOTAL_RETEN IS NULL) THEN
    	       xIMP_TOTAL_RETEN:=0;
    	    END IF; 	        	    
    	    
    	    IF (xIMPORTE IS NULL) THEN
    	       xIMPORTE:=0;
    	    END IF;
    	    
    	    xIMP_TOTAL_RETEN:=xIMP_TOTAL_RETEN+xIMPORTE;
		
    	    -- retenciones en las distintas cuentas y claves de seguridad
			FOR vCUENTAS IN CCUENTAS_OFICINA
			LOOP
				i:=i+1;				
				IF i=1 THEN
					xCCC1:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||
						   vCUENTAS.DC||vCUENTAS.CUENTA;
				    xRETENIDO1:=vCUENTAS.RETENIDO;
				    xNUEVARETEN1:=vCUENTAS.NUEVARETEN;
				    xIMP_TOTAL_EMBARGAR:=vCUENTAS.DEUDA_A_EMBARGAR;
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD1
				    FROM CUENTAS_CORRIENTES
				    WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC1;					
				ELSIF i=2 THEN
					xCCC2:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||
						   vCUENTAS.DC||vCUENTAS.CUENTA;
					xRETENIDO2:=vCUENTAS.RETENIDO;
				    xNUEVARETEN2:=vCUENTAS.NUEVARETEN;
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD2
				    FROM CUENTAS_CORRIENTES
				    WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC2;
				ELSIF i=3 THEN
					xCCC3:=vCUENTAS.ENTIDAD||vCUENTAS.OFICINA||
						   vCUENTAS.DC||vCUENTAS.CUENTA;
					xRETENIDO3:=vCUENTAS.RETENIDO;
				    xNUEVARETEN3:=vCUENTAS.NUEVARETEN;
				    SELECT MIN(CLAVE_SEGURIDAD) INTO xC_SEGURIDAD3
				    FROM CUENTAS_CORRIENTES
				    WHERE ENTIDAD||OFICINA||DC||CUENTA=xCCC3;
				END IF;
			END LOOP;		
		
		END IF;		
		
		-- si se han encontrado cuentas para levantar
		IF (i>0) THEN
						
			IF xIMP_TOTAL_EMBARGAR IS NULL THEN
    			xIMP_TOTAL_EMBARGAR:=0;
    		END IF;    	
    	
    		-- Datos orden de levantamiento			
   			PkIngresos.PENDIENTE_EXPE(xIDEXPE,'N',SYSDATE,sPrincipal,sRecargo,sCostas,
        		       		      sDemora,xPENDIEXPE);   		   			
        		       		      
        	IF xPENDIEXPE > 0 THEN
        		xTIPO_LEVANTA:='2'; --levantamiento parcial
        	ELSIF xPENDIEXPE=0 THEN
        		xTIPO_LEVANTA:='1'; --levantamiento total
        	END IF;  						
   			
    	
    		IF (i=1) THEN
    	   		xCCC2:=NULL;
    	   		xCCC3:=NULL;
    		ELSIF (i=2) THEN
    	   		xCCC3:=NULL;
    		END IF;
    	
    		IF xCCC1 IS NOT NULL THEN 			
   				
   				xIMP_LEVANTAR1:=xRETENIDO1-xNUEVARETEN1;
   				IF xNUEVARETEN1=0 THEN
   			   		xTIPO_LEVANTA1:='1'; --levantamiento total de la cuenta
   				ELSE
   			   		xTIPO_LEVANTA1:='2'; --levantamiento parcial de la cuenta
   				END IF;
   			END IF;
   			
   			IF xCCC2 IS NOT NULL THEN  			
   			
   				xIMP_LEVANTAR2:=xRETENIDO2-xNUEVARETEN2;
   				IF xNUEVARETEN2=0 THEN
   		   			xTIPO_LEVANTA2:='1'; --levantamiento total de la cuenta
   				ELSE
   			   		xTIPO_LEVANTA2:='2'; --levantamiento parcial de la cuenta
   				END IF;
   			END IF;
   			
   			IF xCCC3 IS NOT NULL THEN   			
   				
   				xIMP_LEVANTAR3:=xRETENIDO3-xNUEVARETEN3;
   				IF xNUEVARETEN3=0 THEN
   			   		xTIPO_LEVANTA3:='1'; --levantamiento total de la cuenta
   				ELSE
   			   		xTIPO_LEVANTA3:='2'; --levantamiento parcial de la cuenta
   				END IF;
   			END IF;			
   		
   			xIMP_TOTAL_LEVANTAR:=xIMP_LEVANTAR1+xIMP_LEVANTAR2+xIMP_LEVANTAR3;  		   		
		
   		
			INSERT INTO TMP_CUENTAS_FASE5
				(ID,NIF,NOMBRE,DOMICILIO,MUNICIPIO,CODIGO_POSTAL,IDEXPE,IMP_TOTAL_EMBARGAR,
				IMP_TOTAL_RETEN,F_RETENCION,CCC1,COD_RESULTADO1,IMP_RETENIDO1,CCC2,
				COD_RESULTADO2,IMP_RETENIDO2,CCC3,COD_RESULTADO3,IMP_RETENIDO3,C_SEGURIDAD1,
				C_SEGURIDAD2,C_SEGURIDAD3,IMP_TOTAL_LEVANTAR,TIPO_LEVANTA,IMP_LEVANTAR1,
				TIPO_LEVANTA1,IMP_LEVANTAR2,TIPO_LEVANTA2,IMP_LEVANTAR3,TIPO_LEVANTA3)
			VALUES
				(xID,vEXPEDIENTES.NIF,vEXPEDIENTES.NOMBRE,vEXPEDIENTES.DOMICILIO,
				vEXPEDIENTES.POBLACION,vEXPEDIENTES.CODIGO_POSTAL,xIDEXPE,xIMP_TOTAL_EMBARGAR,
				xIMP_TOTAL_RETEN,xF_RETENCION,xCCC1,'01',xRETENIDO1,xCCC2,'01',
				xRETENIDO2,xCCC3,'01',xRETENIDO3,xC_SEGURIDAD1,xC_SEGURIDAD2,
				xC_SEGURIDAD3,xIMP_TOTAL_LEVANTAR,xTIPO_LEVANTA,xIMP_LEVANTAR1,
				xTIPO_LEVANTA1,xIMP_LEVANTAR2,xTIPO_LEVANTA2,xIMP_LEVANTAR3,xTIPO_LEVANTA3);		
				
		END IF; -- i>0
		
	END LOOP;
	
	
END;
/

/***************************************************************************************
Acción: Reponer la aplicación de un embargo total por causa de cualquier error, 
        pues no era la fecha correcta de aplicación u otras causas extrañas.
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Al poder tener mas de una tupla en 
		next_levanta_cuentas para un mismo expediente, tendremos que registrar cual
		es la que hay que borrar en caso de reposición y eliminar sólo ésta. Para ello
		se utiliza la tabla BORRA_LEVANTAMIENTOS.
***************************************************************************************/

CREATE OR REPLACE PROCEDURE ReponerEmbargoCuentas(xIDExpe IN INT)

AS
	xOTRO CHAR(1);
 	xESTA CHAR(1);
BEGIN

   	INSERT INTO EMBARGOS_CUENTAS(IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,
		EMBARGO,F_EMBARGO,QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,
		NOTIFICADO,NEXT_PRELA,ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,
		HUBO_CUENTAS,PUEDO_DILIGENCIA)

   	SELECT IDEXPE,LOTE,EXPEDIENTE,ZONA,USUARIO,NIF,DEUDA_TOTAL,
		EMBARGO,F_EMBARGO,QUITAR_EMBARGO,IMPORTE_EMBARGADO,FECHA_RETENCION,
		NOTIFICADO,NEXT_PRELA,ID,F_DILIGENCIA,APLICADO,ALGUN_EMBARGO,
		HUBO_CUENTAS,PUEDO_DILIGENCIA

   	FROM BORRA_EMBARGOS_CUENTAS WHERE IDEXPE=xIDEXPE;


	-- Reponer las cuentas del lote

	INSERT INTO CUENTAS_LOTES (ID,
		LOTE,IDEXPE,EXPEDIENTE,ZONA,NIF,ENTIDAD,OFICINA,DC,CUENTA,
		CLAVE_SEGURIDAD,IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,
		DILIGENCIA,F_DILIGENCIA,DEUDA_A_EMBARGAR,VECES)

	SELECT ID,LOTE, IDEXPE, EXPEDIENTE, ZONA, NIF, ENTIDAD, OFICINA, DC,CUENTA,
		CLAVE_SEGURIDAD,IMPORTE_RETENIDO,FECHA_RETENCION,NOTIFICADO,HECHO,
		DILIGENCIA,F_DILIGENCIA,DEUDA_A_EMBARGAR,VECES

	FROM BORRA_CUENTAS_LOTES WHERE IDEXPE=xIDExpe;

	-- Borrar de la lista circular de borrado
	DELETE FROM BORRA_EMBARGOS_CUENTAS WHERE IDEXPE=xIDExpe;
	DELETE FROM BORRA_CUENTAS_LOTES WHERE IDEXPE=xIDExpe;

	-- Borrar del levantamiento de cuentas
	DELETE FROM NEXT_LEVANTA_CUENTAS WHERE ID IN (SELECT ID FROM 
	BORRA_LEVANTAMIENTOS WHERE IDEXPE=xIDExpe);
	DELETE FROM BORRA_LEVANTAMIENTOS WHERE IDEXPE=xIDEXPE;


	-- Comprobar si hay un embargo de cuentas simultaneo
	SELECT EN_OTROTRAMITE,ESTA_EMBARGO INTO xOTRO,xESTA FROM EXPEDIENTES WHERE ID=xIDEXPE;
	-- en caso afirmativo reponerlo
	IF xOTRO='S' THEN
   		IF xESTA='L' THEN -- Estaba levantado, lo vuelvo a abrir
			UPDATE EMBARGOS_INMUEBLES SET QUITAR_EMBARGO='N' WHERE IDEXPE=xIDExpe;
   		END IF;
	END IF;

	UPDATE EXPEDIENTES SET Esta_Embargo='O' WHERE ID=xIDExpe;

END;
/


/***************************************************************************************
Acción: Quitar la suspensión del expediente
MODIFICACIÓN: Modificado: 23/06/2003. Lucas Fernández Pérez. Al quitar la suspension 
		      reajusta los campos CUANTOS_R_SUSPEN y RECIBOS indicando que los valores 
		      ya no estan suspendidos.
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Si el expediente estaba en un embargo 
			  de cuentas, éste se ha de reponer.
***************************************************************************************/

CREATE OR REPLACE PROCEDURE DEL_SUSPENDE_EXPE(xID IN INTEGER)
AS
   xTramite char(1);
BEGIN

	--Actualizamos el expediente
   	UPDATE EXPEDIENTES SET F_SUSPENSION=NULL,ESTADO='ABIERTO',
   						   RECIBOS=RECIBOS+CUANTOS_R_SUSPEN, CUANTOS_R_SUSPEN=0
   	WHERE ID=xID AND
	      F_ANULACION IS NULL AND
	      F_INGRESO IS NULL;

   	-- Si no hay cambios, nos salimos
   	IF SQL%NOTFOUND THEN
      	RETURN;
   	END IF;


	--Actualizamos los valores
   	UPDATE VALORES SET F_SUSPENSION=NULL,IS_LIVE='S'
   	WHERE EXPEDIENTE=xID AND
	      FECHA_DE_BAJA IS NULL AND
	      F_INGRESO IS NULL;

	--Eliminamos los valores de la lista
   	DELETE FROM SUSPENSIONES_VALORES WHERE ID_EXPE=xID;

	--Anotamos en el seguimiento
   	PkSeguimiento.NotaInformativa(xID, 'Se repone la suspensión');
   	
   	--Comprobamos si el expediente estaba en embargo de cuentas
   	SELECT EMBARGO INTO xTRAMITE FROM EXPEDIENTES WHERE ID=xID;
   	IF (xTRAMITE='1') THEN
   		ReponerEmbargoCuentas(xID);
	END IF;   

END;
/


/***************************************************************************************
Acción: Anular o reponer la anulación de un expediente
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Si el expediente se anuló estando en 
			  el embargo de cuentas, se tendrá que reponer al estado en el que estaba
			  antes de la anulación, borrando el posible levantamiento.

***************************************************************************************/
CREATE OR REPLACE PROCEDURE ANULA_EXPE(
		xID		IN	INTEGER,
      	xTIPO 	IN	INTEGER,
      	xFECHA 	IN	DATE)
AS    
	xEMBARGO	char(1);
BEGIN

	IF xTIPO=0 THEN

		UPDATE EXPEDIENTES SET F_ANULACION=xFECHA,ISOPEN='N',IS_LIVE='N',
			   F_ESTADO=SYSDATE,ESTADO='ANULADO',TIPO_ANULACION='NO' 
		WHERE ID=xID RETURN EMBARGO INTO xEMBARGO;

		-- Control del levantamiento de embargos
		-- Levantar los trámites si hubiera alguno en marcha
		LEVANTA_CHECK(xID, xEMBARGO);

		PkSeguimiento.NotaInformativa(xID, 'Se anula el expediente');

   	ELSE -- Si el expediente estaba levantado en algun embargo, lo abro.

		UPDATE EXPEDIENTES SET F_ANULACION=NULL,ISOPEN='S',IS_LIVE='S',
		  	   F_ESTADO=SYSDATE, ESTADO='ABIERTO',TIPO_ANULACION=NULL 
		WHERE ID=xID
		RETURN EMBARGO INTO xEmbargo;

		--deshace el levantamiento que le corresponda para salarios, inmuebles y vehiculos
		IF xEmbargo not in ('0','1') then
		   DESHACE_LEVANTA(xID, null, xEMBARGO);
		ELSIF (xEmbargo='1') THEN
		   REPONEREMBARGOCUENTAS(xID);
		END IF;

		PkSeguimiento.NotaInformativa(xID, 'Se repone la anulación');
	END IF;

END;
/


/**************************************************************************************
Acción: Borrar un fraccionamiento. Si el fraccionamiento no esta cerrado, se deja el 
		expediente abierto con sus valores pendientes de cobro.		
MODIFICACIÓN: 11/09/2002. Agustín León Robles. Borra de la tabla de suspensiones_valores.
MODIFICACIÓN: 30/07/2003. M. Carmen Junco Gómez. Se ha de borrar de la tabla 
			  borra_levantamientos al borrar de borra_embargos_cuentas y borra_cuentas_lotes.

DELPHI
****************************************************************************************/


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


	   UPDATE VALORES SET IS_LIVE='S',F_SUSPENSION=NULL
		WHERE EXPEDIENTE=xEXPE
			AND F_INGRESO IS NULL
			AND FECHA_DE_BAJA IS NULL
			AND IS_LIVE='N';

	   DELETE FROM SUSPENSIONES_VALORES WHERE ID_EXPE=xEXPE;

	END IF;

	PkSeguimiento.NotaInformativa(xEXPE,'SE HA BORRADO EL FRACCIONAMIENTO');
END;
/


/*************************************************************************************
Acción: Suspender un valor, este o no dentro de un expediente
MODIFICACION: 30/07/2003 M. Carmen Junco Gómez. Si el valor suspendido es el último 
			  pendiente del expediente, se suspende el expediente.
**************************************************************************************/

CREATE OR REPLACE PROCEDURE SUSPENDE_VALOR(
	   xID          IN INTEGER,
	   xFECHA       IN DATE,
	   xF_ACUERDO   IN DATE,
	   xORGANISMO   IN CHAR,
       xDESCRIPCION IN CHAR )

AS

	xIDExpe INTEGER default NULL;
	xPendiente 	FLOAT DEFAULT 0;  --pendiente del expediente	
	sPrincipal 	float default 0;
	sRecargo 	float default 0;
	sCostas 	float default 0;
	sDemora 	float default 0;

BEGIN

	-- Ponemos la deuda como suspendida
	UPDATE VALORES SET F_SUSPENSION=xFECHA,IS_LIVE='X'
   	WHERE ID=xID AND
		  FECHA_DE_BAJA IS NULL AND
		  F_INGRESO IS NULL AND
		  F_SUSPENSION IS NULL
	returning Expediente INTO xIDExpe;

	-- Si no estaba en situación nada que hacer
	IF SQL%NOTFOUND THEN
   		RETURN;
	END IF;

	-- Los incorporamos a las deudas suspendidas
	INSERT INTO SUSPENSIONES_VALORES
         (valor,ID_EXPE,F_ACUERDO,ORGANISMO,DESCRIPCION)
	VALUES (xID,xIDExpe,xF_ACUERDO,xORGANISMO,xDESCRIPCION);

	-- Si está dentro de un expediente, controlar el estado de la
	-- traba de cuentas, pues habría que realizar una aminoración

	IF (xIDExpe IS NOT NULL) THEN

      	UPDATE EXPEDIENTES SET RECIBOS=RECIBOS-1,
					CODIGO_INGRESO=NULL,
					CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN+1
        WHERE ID=xIDExpe AND
		      F_ANULACION IS NULL AND
		      F_INGRESO IS NULL;
		      
		-- Si está anulado o pagado nada que hacer, esto no debería de ocurrir nunca
		-- lo ponemos por proteger el código, aunque no tenga mucho sentido, pues dentro
		-- de un expediente pagado no puede haber deudas pendientes, ni tampoco en uno
		-- que esté anulado.
		      
		IF SQL%NOTFOUND THEN
	   		RETURN;
		END IF;
	
		PkIngresos.PENDIENTE_EXPE(xIDEXPE,'N',SYSDATE,sPrincipal,sRecargo,sCostas,
                	   			  sDemora, xPendiente);
        -- si el pendiente es cero después de suspender el valor, suspendemos el expediente.
        IF (xPendiente=0) THEN
        	UPDATE EXPEDIENTES SET F_SUSPENSION=xFECHA,ESTADO='SUSPEND'   						  
   			WHERE ID=xIDExpe AND
				  F_ANULACION IS NULL AND
				  F_INGRESO IS NULL AND
				  F_SUSPENSION IS NULL;	
				  
			IF SQL%NOTFOUND THEN
	   			RETURN;
			END IF;

			-- Anotamos en el seguimiento del expediente
			PkSeguimiento.NotaInformativa(xIDExpe, 'Se suspende el expediente');
        END IF;	


	-- Diligencia en marcha
	CHECK_RETENIDO_LEVANTA(xIDExpe);

END IF;


END;
/


/****************************************************************************************
Acción: repone la última baja asociada al valor con id=xID
MODIFICACIÓN: 02/12/2002 M. Carmen Junco Gómez. 
 		      No se estaba seleccionando la máxima baja asociada al valor, con lo cual
              el select podía devolver más de una tupla.
 		      Además se ha añadido en la descripción de la baja el ID de la BAJA.
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez.
			  Al reponer la baja repondremos los intereses pendientes que tenía el valor
			  en el momento de darlo de baja.
*****************************************************************************************/

CREATE OR REPLACE PROCEDURE REPON_BAJA 
	(xID		IN	INTEGER,
     xERROR 	OUT 	INTEGER)
AS
	xBAJA	INTEGER;
    xTIPO CHAR(2);
   	xRECARGO FLOAT DEFAULT 0;
   	xDEMORA	FLOAT DEFAULT 0;
    xZONA CHAR(2);
    xCONT INTEGER DEFAULT 0;

BEGIN

  SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

  xERROR:=0;

  SELECT COUNT(*) INTO xCONT FROM BAJAS
  WHERE VALOR=xID AND NUMERO_DE_DATA IS NOT NULL;

  IF xCONT>0 THEN
    xERROR:=1;
  ELSE

	-- El max es porque puede haber varias bajas sobre un valor:
	-- Una o mas bajas de aminoracion del principal, y una como maximo del valor.
	-- Ademas, la baja del valor será la última porque una vez hecha no se puede dar de baja
	-- por aminoracion de principal.

	SELECT MAX(ID) INTO xBAJA FROM BAJAS WHERE VALOR=xID;

	SELECT RECARGO,DEMORA,TIPO_BAJA INTO xRECARGO,xDEMORA,xTIPO 
	FROM BAJAS WHERE ID=xBAJA;

	UPDATE VALORES SET FECHA_DE_BAJA=NULL,CODIGO_DE_BAJA=NULL,IS_LIVE='S',
			RECARGO=DECODE(xTIPO,'BN',xRECARGO,RECARGO),DEMORA_PENDIENTE=xDEMORA
	WHERE ID=xID;

	DELETE FROM DESCRIPCION_BAJA WHERE BAJA=xBAJA;
	DELETE FROM BAJAS WHERE ID=xBAJA;

  END IF;

END;
/

