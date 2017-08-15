-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios. ROUND en insert y updates.
-- -----------------------------------------------------

-- -----------------------------------------------------------------------
-- CREAR LOS PLAZOS DE UN FRACCIONAMIENTO 
--
-- Realiza una simulación de un fraccionamiento guardando los importes
-- en la tabla temporal TEMP_PLAZOS
-- -----------------------------------------------------------------------
/*DELPHI*/
 
 
CREATE OR REPLACE PROCEDURE PROC_PLAZOS_FRAC(
  	 xIDExpe 		IN	INTEGER,
       xPRIMER_PLAZO 	IN	DATE,
       xPLAZOS 		IN	INTEGER,
       xCARENCIA 		IN	INTEGER,
       xFIN_PE_VOLMAN 	IN	DATE,
       HayDemora 		IN	CHAR)
AS

xVALOR				integer default 0;
xFIN_PE_VOL 			DATE;
xTIPO 				char(2);
xPADRON 				CHAR(6);
xYEAR 				CHAR(4);
xPERIODO 				CHAR(2);
xRECIBO 				INTEGER;

xPrincipal 				float default 0;
xRecargo 				float default 0;
xCOSTAS 				float default 0;
xDEMORA 				float default 0;
xTOTAL_DEUDA 			FLOAT;

-- para tener los importes Primitivos
xSumaPrincipal 			float default 0;
xSumaRecargo			float default 0;
xSumaCOSTAS 			float default 0;
xSumaDEMORA 			float default 0;

-- para acumular la perdida por redondeos
xErrorPrincipal 	float default 0;
xErrorRecargo	float default 0;
xErrorCOSTAS 	float default 0;
xErrorINTERESES 	float default 0;


I					INT;
xF_PLAZO 				DATE;
xInteresAcumulado 		FLOAT;
InteresesPendientes 		float default 0;
xINTERESES 				FLOAT default 0;

xRegistro_Valores_expe		PKFraccionamientos.Registro_Valores;

BEGIN

-- BORRAR SIMULACIONES ANTERIORES
DELETE FROM TEMP_PLAZOS WHERE USUARIO=(SELECT UID FROM DUAL);

 
 OPEN PKFraccionamientos.Valores_expediente(xIDExpe);
 LOOP

    FETCH PKFraccionamientos.Valores_expediente
    INTO xRegistro_Valores_expe;
    EXIT WHEN PKFraccionamientos.Valores_expediente%NOTFOUND;

    xVALOR:=xRegistro_Valores_expe.ID;
    xFIN_PE_VOL:=xRegistro_Valores_expe.FIN_PE_VOL;
    xTIPO:=xRegistro_Valores_expe.TIPO_DE_TRIBUTO;
    xPADRON:=xRegistro_Valores_expe.PADRON;
    xYEAR:=xRegistro_Valores_expe.YEAR;
    xPERIODO:=xRegistro_Valores_expe.PERIODO;
    xRECIBO:=xRegistro_Valores_expe.RECIBO;
 
   -- LEER LO ANTERIORMENTE INGRESADO en esta ocasión la demora no tiene
   --   sentido pues se va a calcular en este momento 
   
   PkIngresos.Get_Pendiente(xRegistro_Valores_expe.ID,xPrincipal,xRecargo,xCostas,xDemora,
                 xTotal_Deuda);
 

   -- guardamos los importes primitivos, para posteriormente calcular el ultimo plazo
   xSumaPrincipal:=xPrincipal;
   xSumaRecargo:=xRecargo;
   xSumaCOSTAS:=xCostas;
	

   -- CALCULAR EL IMPORTE DE LOS PLAZOS DE CADA CONCEPTO     
   xPRINCIPAL:=PKFraccionamientos.Calcula_importe_plazo(xPRINCIPAL,xPLAZOS);
   xRECARGO:=PKFraccionamientos.Calcula_importe_plazo(xRECARGO,xPLAZOS);
   xCOSTAS:=PKFraccionamientos.Calcula_importe_plazo(xCOSTAS,xPLAZOS);

   IF xFIN_PE_VOL is null then
      xFIN_PE_VOL:=xFIN_PE_VOLMAN;
   END IF;
 
   -- CALCULAR LOS INTERESES DE LAS ENTREGAS 
   Int_entregas(xRegistro_Valores_expe.ID,xFIN_PE_VOL,xTIPO,InteresesPendientes);
   xSumaDEMORA:=InteresesPendientes;

   InteresesPendientes:=PKFraccionamientos.Calcula_importe_plazo(InteresesPendientes,xPLAZOS);


   xErrorPrincipal:=0;
   xErrorRecargo:=0;
   xErrorCOSTAS:=0;
   xErrorINTERESES:=0;

   -- tantos como plazos 
   I:=1;
   xF_PLAZO:=xPRIMER_PLAZO;
 
   xInteresAcumulado:=0;

   WHILE I <= xPLAZOS LOOP

     -- en el caso del ultimo plazo, se le asignan los importes anteriormente calculados 
     if I=xPLAZOS then
		xPRINCIPAL:=xPrincipal+xErrorPrincipal;
		xRECARGO:=xRecargo+xErrorRecargo;
		xCOSTAS:=xCOSTAS+xErrorCostas;
		xINTERESES:=InteresesPendientes+xErrorIntereses;
		-- No permito valores negativos.
		if (xPRINCIPAL<0)  then xPRINCIPAL:=0; end if;
		if (xRECARGO<0)     then xRECARGO:=0;    end if;
		if (xCOSTAS<0)   	  then xCOSTAS :=0;    end if;
		if (xINTERESES<0)   then xINTERESES:=0;  end if;
     end if;

     if HayDemora='S' then

        -- Si hay algo de principal calcularle los intereses de demora
       if xPRINCIPAL > 0 then
           Cal_Demora(xF_PLAZO,xFIN_PE_VOL,xTIPO,xPRINCIPAL,xINTERESES);
       else
           xINTERESES:=0;
       end if;
 
       xINTERESES:=xINTERESES+InteresesPendientes;
     else
       xINTERESES:=0;
     end if;
 
     xInteresAcumulado:=xInteresAcumulado+ROUND(xIntereses,2);
 
	-- Voy acumulando el error por redondear para aplicarlo al ultimo plazo.
	xErrorPrincipal:= xErrorPrincipal + ( xPRINCIPAL  - ROUND(xPRINCIPAL,2)  );
	xErrorRecargo  := xErrorRecargo   + ( xRECARGO  - ROUND(xRECARGO,2)  );
	xErrorCostas   := xErrorCostas    + ( xCOSTAS   - ROUND(xCOSTAS,2)   );
	xErrorIntereses:= xErrorIntereses + ( xINTERESES- ROUND(xINTERESES,2));

     PKFraccionamientos.Insertar_Plazo_Temp(xRegistro_Valores_expe.ID,xF_PLAZO,xPRINCIPAL,
				xRECARGO,xCOSTAS,xINTERESES,xPADRON,xYEAR,xPERIODO,xRECIBO);

     -- SABER LA FECHA DEL SIGUIENTE PLAZO 
     xF_PLAZO:=PKFraccionamientos.NEXT_PLAZO(xF_PLAZO, xCARENCIA);
 
     I:=I+1;
 
    END LOOP;
 
    UPDATE VALORES SET DEMORA_PENDIENTE=xInteresAcumulado
    WHERE ID=xRegistro_Valores_expe.ID;
 
 END LOOP;
 CLOSE PKFraccionamientos.Valores_expediente;

 EXCEPTION
  WHEN OTHERS THEN
	BEGIN
	   CLOSE PKFraccionamientos.Valores_expediente;
         raise_application_error(-20007,'Error en la fecha del final del periodo voluntario: '
			||to_char(xFin_Pe_Vol,'dd/mm/yyyy')
			||' Fecha de pago: '||to_char(xF_Plazo,'dd/mm/yyyy'));
 	END;

 END;
/ 


-- -----------------------------------------------------------------------
-- CREAR UN NUEVO FRACCIONAMIENTO 
--
-- Accediendo a la tabla TEMP_PLAZOS que tiene una simulación de un 
-- fraccionamiento, crea el fraccionamiento y sus plazos.
-- Es delphi quien asegura que cuando se llama a este procedimiento antes 
-- se ha simulado para que la tabla temporal tenga datos.
-- -----------------------------------------------------------------------
-- Modificado: 11/09/2002. Agustin Leon Robles
--			En valores se pone la fecha de suspension a sysdate, en vez de 
--					la fecha del primer plazo de pago.
--			Tambien se escribe en suspensiones_valores cosa que antes no lo hacia
--
/*DELPHI*/

CREATE OR REPLACE PROCEDURE CREAR_FRAC(
	xCODOPE 		IN	INTEGER,
      xIDExpe 		IN	INTEGER,
      xDEUDOR 		IN	CHAR,
      xFECHA 		IN	DATE,
      xPLAZOS 		IN	INTEGER)
AS
 
xFRAC 			INTEGER;
xZONA 			CHAR(2);
xIMPO_NEXT_PLAZO 		FLOAT DEFAULT 0;
xSuma 			FLOAT DEFAULT 0;

BEGIN
 
  -- Comprobar que no este anulado o ingresado anteriormente 
  Select count(*) INTO xFRAC from Expedientes
   where ID=xIDExpe 
	and f_ingreso is null 
	and F_ANULACION is null;
   
  IF xFRAC = 1 THEN -- El expediente existe y no esta ingresado ni anulado.
 
	-- pasar los valores del expediente al estado de fraccionamiento
	-- los insertamos en valores suspendidos
	INSERT INTO SUSPENSIONES_VALORES
      (VALOR,ID_EXPE,F_ACUERDO,DESCRIPCION)
	SELECT ID,xIDExpe,SYSDATE,'FRACCIONAMIENTO' FROM VALORES
                WHERE EXPEDIENTE=xIDExpe 
			AND F_INGRESO IS NULL
			AND FECHA_DE_BAJA IS NULL 
			AND F_SUSPENSION IS NULL;

	UPDATE VALORES SET IS_LIVE='N',F_SUSPENSION=SYSDATE
     		WHERE EXPEDIENTE=xIDExpe 
		AND F_INGRESO IS NULL
      	AND FECHA_DE_BAJA IS NULL
      	AND F_SUSPENSION IS NULL;
 
	-- averiguar la zona del expediente
	SELECT ZONA INTO xZONA FROM EXPEDIENTES WHERE ID=xIDExpe;

	-- INSERTAR EL MAESTRO DEL FRACCIONAMIENTO
	Insert into fraccionamiento
       (NIF,EXPEDIENTE,PLAZOS,ZONA,ISOPEN,IS_LIVE)
	values
       (xDeudor,xIDExpe,xPlazos,xZONA,'S','S')
	return ID INTO xFRAC;
 
 
	-- ESCRIBIR LOS PLAZOS DEL FRACCIONAMIENTO DESDE EL TEMPORAL
      -- QUE ESTA ORGANIZADO POR USUARIO 
  
	INSERT INTO PLAZOS_FRAC
      	(VALOR,FECHA,PRINCIPAL,RECARGO,COSTAS,DEMORA,FRACCIONA)

	SELECT VALOR,FECHA,PRINCIPAL,RECARGO,COSTAS,DEMORA,xFRAC
    	FROM TEMP_PLAZOS WHERE USUARIO=(SELECT UID FROM DUAL);
 
	-- SUMA TOTAL DEL IMPORTE DEL FRACCIONAMIENTO
	xSUMA:=PKFraccionamientos.Calcula_importe_fracc(xFRAC);

	-- SUMA DEL IMPORTE DEL PRIMER PLAZO
	xIMPO_NEXT_PLAZO:=PKFraccionamientos.Calcula_importe_fracc(xFRAC,xFECHA);

	-- ACTUALIZAMOS EL IMPORTE Y LA FECHA DEL PRIMER PLAZO EN LA CABECERA DEL FRACCIONAMIENTO
	update fraccionamiento set TOTAL_DEUDA=ROUND(xSuma,2),
         			   F_NEXT_PLAZO=xFecha, IMPO_NEXT_PLAZO=ROUND(xIMPO_NEXT_PLAZO,2)
	where ID=xFRAC;
 
	-- ACTUALIZAMOS LOS DATOS DEL FRACCIONAMIENTO EN EL EXPEDIENTE(levanto si esta en embargo)
	PKFraccionamientos.Actualiza_fraccionamiento(xIDExpe);

	PkSeguimiento.NotaInformativa(xIDExpe, 'Se suspende el expediente por fraccionamiento');
 
	Update Expedientes set Estado='FRACCIO', F_ESTADO=SYSDATE,
                        F_SUSPENSION=SYSDATE, AVISO='016', F_AVISO=SYSDATE
	where ID=xIDExpe;

  END IF;
 
END;
/

-- -------------------------------------------------------------------------------
-- BORRAR UNA SIMULACION DE FRACCIONAMIENTO
--
-- Elimina una simulación si no llegó a convertirse en un fraccionamiento.
-- Actualiza la demora pendiente de los valores, que en la simulación se cambió y 
-- debe ponerse a su valor anterior.
-- -------------------------------------------------------------------------------
/*DELPHI*/

CREATE OR REPLACE PROCEDURE DELSIMULACION(xIDEXPE IN INTEGER)
AS
xESTADO		CHAR(7);
xPendienteOut	FLOAT DEFAULT 0;
xDemoraOut 		FLOAT DEFAULT 0;
BEGIN

   SELECT ESTADO INTO xESTADO FROM EXPEDIENTES WHERE ID=xIDEXPE;
   IF xESTADO<>'FRACCIO' THEN -- Si el expediente no está fraccionado
      -- Actualiza la demora de los valores del expediente
      CALCDEMORA_EXPE(xIDEXPE, SYSDATE, 'S','E', xDemoraOut, xPendienteOut);
   END IF;

END;
/

/*********************************************************************/
COMMIT;
/********************************************************************/