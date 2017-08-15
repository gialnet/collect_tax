-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.(ROUND en insert/updates)
-- -----------------------------------------------------
/********************************************************************************************/
-- -----------------------------------------------------------------------
-- CREAR LOS PLAZOS DE UN FRACCIONAMIENTO EN VOLUNTARIA
--
-- Realiza una simulación de un fraccionamiento guardando los importes
-- en la tabla temporal TEMP_PLAZOS
-- Modificado: 14/01/2003. Lucas Fernández Pérez. Si el valor tiene entregas a cuenta,
-- 	realiza el fraccionamiento sobre su importe pendiente.
-- -----------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE SIMULA_FRAC_VOL(
	 xID 			IN INTEGER,
       xPRIMER_PLAZO 	IN DATE,
       xPLAZOS 		IN INTEGER,
       xCARENCIA 		IN INTEGER,
       xFIN_PE_VOLMAN 	IN DATE,
       HayDemora 		IN CHAR)
AS

xFIN_PE_VOL 	VALORES.FIN_PE_VOL%TYPE;
xTIPO_DE_TRIBUTO 	VALORES.TIPO_DE_TRIBUTO%TYPE;
xPADRON 		VALORES.PADRON%TYPE;
xYEAR			VALORES.YEAR%TYPE;
xPERIODO		VALORES.PERIODO%TYPE;
xRECIBO		VALORES.RECIBO%TYPE;
xPRINCIPAL		VALORES.PRINCIPAL%TYPE;
xRECARGO		VALORES.RECARGO%TYPE;
xCOSTAS		VALORES.COSTAS%TYPE;
xNADA_1		FLOAT;
xNADA_2		FLOAT;

xPRINCIP 		FLOAT DEFAULT 0;

xF_PLAZO 		DATE;

/*para tener el pago del ultimo plazo*/
xLastPrincipal 	FLOAT DEFAULT 0;
xLastRecargo	FLOAT DEFAULT 0;
xLastCOSTAS 	FLOAT DEFAULT 0;
xLastDEMORA 	FLOAT DEFAULT 0;

/*para tener los importes Primitivos*/
xSumaPrincipal 	float default 0;
xSumaRecargo	float default 0;
xSumaCOSTAS 	float default 0;
xSumaDEMORA 	float default 0;

/*para acumular la perdida por redondeos*/
xErrorPrincipal 	float default 0;
xErrorRecargo	float default 0;
xErrorCOSTAS 	float default 0;
xErrorINTERESES 	float default 0;

I			INT;
xINTERESES 			FLOAT default 0;
InteresesPendientes 	FLOAT default 0;
xInteresAcumulado 	FLOAT default 0;

BEGIN

   /*BORRAR SIMULACIONES ANTERIORES*/
   DELETE FROM TEMP_PLAZOS WHERE USUARIO=(SELECT UID FROM DUAL);

   PkIngresos.GET_PENDIENTE(xID,xPRINCIPAL,xRECARGO,xCOSTAS,xNADA_1,xNADA_2);

   SELECT FIN_PE_VOL,TIPO_DE_TRIBUTO,PADRON,YEAR,PERIODO,RECIBO
   INTO xFIN_PE_VOL,xTIPO_DE_TRIBUTO,xPADRON,xYEAR,xPERIODO,xRECIBO 
   FROM IMPORTE_VALORES WHERE ID=xID;

   xPRINCIP:=xPRINCIPAL;
   IF xFIN_PE_VOL is null then 
      xFIN_PE_VOL:=xFIN_PE_VOLMAN;
   END IF;


   /*guardamos los importes primitivos, para posteriormente calcular el ultimo plazo*/
   xSumaPrincipal:=xPRINCIPAL;
   xSumaRecargo:=xRECARGO;
   xSumaCOSTAS:=xCOSTAS;
	

   /* CALCULAR EL IMPORTE DE LOS PLAZOS DE CADA CONCEPTO */    
   xPRINCIP:=PKFraccionamientos.Calcula_importe_plazo(xPRINCIP,xPLAZOS);
   xRECARGO:=PKFraccionamientos.Calcula_importe_plazo(xRECARGO,xPLAZOS);
   xCOSTAS:=PKFraccionamientos.Calcula_importe_plazo(xCOSTAS,xPLAZOS);

   /* CALCULAR LOS INTERESES DE LAS ENTREGAS */ 
   Int_entregas(xID,xFIN_PE_VOL,xTIPO_DE_TRIBUTO,InteresesPendientes);

   xSumaDEMORA:=InteresesPendientes;

   InteresesPendientes:=PKFraccionamientos.Calcula_importe_plazo(InteresesPendientes,xPLAZOS);


   /*calculamos los importes del ultimo plazo*/
   xLastPrincipal:=xSumaPrincipal-( xPRINCIP*(xPLAZOS-1) );
   xLastRecargo:=xSumaRecargo-( xRECARGO*(xPLAZOS-1) );
   xLastCOSTAS:=xSumaCostas-( xCOSTAS*(xPLAZOS-1) );
   xLastDEMORA:=xSumaDemora-( InteresesPendientes*(xPLAZOS-1) );


   /* tantos como plazos */ 
   I:=1;
   xF_PLAZO:=xPRIMER_PLAZO;
 
   xErrorPrincipal:=0;
   xErrorRecargo:=0;
   xErrorCOSTAS:=0;
   xErrorINTERESES:=0;

   xInteresAcumulado:=0;

   WHILE I <= xPLAZOS LOOP

     /*en el caso del ultimo plazo, se le asigna los importes anteriormente calculados */
     	if I=xPLAZOS then
		xPRINCIP:=xLastPrincipal+xErrorPrincipal;
		xRECARGO:=xLastRecargo+xErrorRecargo;
		xCOSTAS:=xLastCOSTAS+xErrorCostas;
		xINTERESES:=xLastDEMORA+xErrorIntereses;
		-- No permito valores negativos.
		if (xPRINCIP<0)  then xPRINCIP:=0; end if;
		if (xRECARGO<0)     then xRECARGO:=0;    end if;
		if (xCOSTAS<0)   	  then xCOSTAS :=0;    end if;
		if (xINTERESES<0)   then xINTERESES:=0;  end if;
     	end if;

	if HayDemora='S' then  /*Si se indico con demora la calculo en base al principal */
        if xPRINCIPAL > 0 then
           Cal_Demora(xF_PLAZO,xFIN_PE_VOL,xTIPO_DE_TRIBUTO,xPRINCIP,xINTERESES);
        else
           xINTERESES:=0;
	  end if;
 
        xINTERESES:=xINTERESES+InteresesPendientes;
     	else
        xINTERESES:=0;
     	end if;
 
     	-- xIntereses es un importe que se guarda en una tabla y a su vez se acumula para
	-- guardar el total en valores.Por eso se hace el ROUND,para que el importe total sea
	-- siempre igual a la suma de las partes.
     	xInteresAcumulado:=xInteresAcumulado+ROUND(xIntereses,2);

	-- Voy acumulando el error por redondear para aplicarlo al ultimo plazo.
	xErrorPrincipal:= xErrorPrincipal + ( xPRINCIP  - ROUND(xPRINCIP,2)  );
	xErrorRecargo  := xErrorRecargo   + ( xRECARGO  - ROUND(xRECARGO,2)  );
	xErrorCostas   := xErrorCostas    + ( xCOSTAS   - ROUND(xCOSTAS,2)   );
	xErrorIntereses:= xErrorIntereses + ( xINTERESES- ROUND(xINTERESES,2));
 
     	PKFraccionamientos.Insertar_Plazo_Temp(xID,xF_PLAZO,xPRINCIP,
				xRECARGO,xCOSTAS,xINTERESES,xPADRON,xYEAR,xPERIODO,xRECIBO);

     	/* SABER LA FECHA DEL SIGUIENTE PLAZO */
     	xF_PLAZO:=PKFraccionamientos.NEXT_PLAZO(xF_PLAZO, xCARENCIA);
 
     	I:=I+1;
 
   END LOOP;
 
   UPDATE VALORES SET DEMORA_PENDIENTE=xInteresAcumulado WHERE ID=xID;

END;
/

/****************************************************************************************************************
Acción: CREA FRACCIONAMIENTOS DE VOLUNTARIA. 
        Accediendo a la tabla TEMP_PLAZOS que tiene una simulación de un 
        fraccionamiento, crea el fraccionamiento y sus plazos.
        Es delphi quien asegura que cuando se llama a este procedimiento antes 
        se ha simulado para que la tabla temporal tenga datos.
MODIFICACIÓN: 06/02/2003 Mª del Carmen Junco Gómez. En vez de la zona del ayto del valor se va a recoger la
		      zona del usuario, ya que si no, por ejemplo, en torrejón, siempre se crearán con la zona '00'.
*****************************************************************************************************************/

CREATE OR REPLACE PROCEDURE CREAR_FRAC_VOL(
	xCODOPE 		IN	INTEGER,
      xIDFrac 		IN	INTEGER,
      xDEUDOR 		IN	CHAR,
      xFECHA 		IN	DATE,
      xPLAZOS 		IN	INTEGER
)
AS
 
xIMPO_NEXT_PLAZO 		FLOAT DEFAULT 0;
xSuma 			FLOAT DEFAULT 0;
xEmbargo 			char(1);
xAYTO 			CHAR(3);
xZONA 			CHAR(2);
xFRAC 			INTEGER;

BEGIN
 
/*pasar los valores al fraccionamiento*/

	UPDATE VALORES SET IS_LIVE='N',F_SUSPENSION=sysdate
     	WHERE ID=xIDFrac 
		AND F_INGRESO IS NULL
      	AND FECHA_DE_BAJA IS NULL
      	AND F_SUSPENSION IS NULL;
 
	/*averiguar el ayuntamiento */
	SELECT AYTO INTO xAYTO FROM VALORES WHERE ID=xIDFrac;
	
	/*y la zona del Usuario*/
	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	/*INSERTAR EL MAESTRO DEL FRACCIONAMIENTO*/
	INSERT INTO FRACCIONAMIENTO_VOL
       (NIF,VALOR,PLAZOS,AYTO,ZONA,ISOPEN,IS_LIVE)
	VALUES
       (xDeudor,xIDFrac,xPlazos,xAYTO,xZONA,'S','S')
	RETURN ID INTO xFRAC;
 
 
	/*ESCRIBIR LOS PLAZOS DEL FRACCIONAMIENTO DESDE EL TEMPORAL
      QUE ESTA ORGANIZADO POR USUARIO */
  
	INSERT INTO PLAZOS_FRAC_VOL(VALOR,FECHA,PRINCIPAL,RECARGO,COSTAS,DEMORA,FRACCIONA)
	SELECT VALOR,FECHA,PRINCIPAL,RECARGO,COSTAS,DEMORA,xFRAC
    	FROM TEMP_PLAZOS WHERE USUARIO=(SELECT UID FROM DUAL);
 
	/*SUMA TOTAL DEL IMPORTE DEL FRACCIONAMIENTO*/
	xSUMA:=PKFraccionamientosvol.Calcula_importe_fracc_vol(xFRAC);

	/*SUMA DEL IMPORTE DEL PRIMER PLAZO*/
	xIMPO_NEXT_PLAZO:=PKFraccionamientosvol.Calcula_importe_fracc_vol(xFRAC,xFECHA);

	/* ACTUALIZAMOS EL IMPORTE Y LA FECHA DEL PRIMER PLAZO 
		EN LA CABECERA DEL FRACCIONAMIENTO*/
	update fraccionamiento_vol
	set TOTAL_DEUDA=ROUND(xSuma,2),F_NEXT_PLAZO=xFecha,IMPO_NEXT_PLAZO=ROUND(xIMPO_NEXT_PLAZO,2)
	where ID=xFRAC;
 
END;
/

