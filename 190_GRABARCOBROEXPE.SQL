/**************************************************************************************************
Acción: Dar por pagado un expediente en ventanilla de la recaudación a través de la gestión
        de expedientes.
        
Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
                       Se han realizado cambios.Se elimino un round innecesario
Modificado: 02-01-2002 Agustin Leon Robles
 	        Se ha eliminado la llamada a  PkwtDocIngreso.wtDatosPostalesDeudor(xIDExpe);
MODIFICACIÓN: 07/03/2003 Mª del Carmen Junco. En vez de usar el campo R_SUSPENDIDOS de la tabla
			  de expedientes, contamos si hay valores suspendidos o no directamente de la tabla
			  de VALORES. (Este cambio viene por un problema de Paco Bustos con la fiabilidad
			  del contenido de R_SUSPENDIDOS) 
Modificación: 3/11/2003. Agustín León Robles. Se cambia la consulta para comprobar si hay recibos
			suspendidos dentro del expediente. Ahora esta la consulta de que ademas de estar suspendidos
			tiene que estar pendiente de ingreso
Modificación: 28/06/2004. Lucas Fernández Pérez.
			Si INCLUIRDEMORA='S', independientemente del valor de DEMORAMANUAL, se llama a INT_ENTREGAS, siempre
			que pase el filtro de la llamada a PLAZO_APREMIO, que revisa si ha pasado el plazo del art.108 necesario
			para poder calcular intereses.
***************************************************************************************************/ 



CREATE OR REPLACE PROCEDURE GRABAR_COBRO_EXPE(
     				xIDExpe			IN	INTEGER,
      				xF_INGRE 		IN 	DATE,
      				xF_DEMORA 		IN 	DATE,
      				INCLUIRDEMORA 	IN  CHAR,
      				DEMORAMANUAL 	IN  CHAR,
					xCIEGO			OUT INTEGER)

AS

xPRINCIPAL 		FLOAT;
xRECARGO 		FLOAT;
xCOSTAS			FLOAT;
xDEMORA 		FLOAT;
xDEMORA_VA 		FLOAT;
xTIPO 			CHAR(2);
xTOTAL_DEUDA 	FLOAT;
xINTERES 		FLOAT;
xFINPEVOL 		DATE;
xFNOTIFICACION	DATE;
xFECHA 			DATE;
xEMBARGO 		CHAR(1);
xSUSPENDIDOS 	CHAR(1);
xIMPORTE 		FLOAT DEFAULT 0;
xVOL_EJE 		CHAR(1) DEFAULT 'E';
xVALOR 			INTEGER;
xINCLUIRDEMORA 	CHAR(1);
xDEMORAMANUAL 	CHAR(1);
xPUEDO			INTEGER DEFAULT 0;

-- Cursor con todos las deudas del expediente no incluyendo las suspendidas
CURSOR C1 IS 
	SELECT ID,TIPO_DE_TRIBUTO,FIN_PE_VOL, DEMORA_PENDIENTE, F_NOTIFICACION 
	FROM VALORES  
	WHERE EXPEDIENTE=xIDExpe 
		AND F_INGRESO IS NULL 
		AND FECHA_DE_BAJA IS NULL 
		AND F_SUSPENSION IS NULL;

BEGIN

	SELECT decode(count(*),0,'N','S') INTO xSUSPENDIDOS FROM VALORES WHERE EXPEDIENTE=xIDEXPE
	AND F_SUSPENSION IS NOT NULL AND FECHA_DE_BAJA IS NULL AND F_INGRESO IS NULL;

	-- asignar un código de operación nuevo para esta transacción
	CODIGO_OPERACION (xCIEGO);

	-- Dar por pagadas todas las deudas vivas del expediente
	OPEN C1;
	LOOP
		FETCH C1 INTO xVALOR,xTIPO,xFINPEVOL,xDEMORA_VA,xFNOTIFICACION;
		EXIT WHEN C1%NOTFOUND;

	    -- EN CASO DE HABER UNA DILIGENCIA DE EMBARGO EN MARCHA
 	    --Y SE DA POR INGRESADO LA FECHA DE CALCULO DE INTERESES
	    --SER  LA DE LA ULTIMA DILIGENCIA EMITIDA,
	    --QUE SIEMPRE SE GUARDA EN UN CAMPO DE LA TABLA EXPEDIENTES
	    xINCLUIRDEMORA:=INCLUIRDEMORA;
	    xDEMORAMANUAL:=DEMORAMANUAL;
 	
	    -- Ver la fecha de diligencia si la hubiera y el trámite actual
	    -- el deudor, el número de recibos suspendidos y si hay otro tramite adicional
	    -- en caso de embargo de bienes inmuebles puede estar simultaneamente a su vez
	    -- en cuentas corrientes
	    SELECT FECHA_DILIGENCIA,EMBARGO INTO xFECHA, xEMBARGO
	    FROM EXPEDIENTES WHERE ID=xIDExpe;

	    -- Si hay diligencia de embargo y el trámite obliga a que 
	    -- se bloquee el cálculo de intereses de demora
	    IF NOT PERMITO_CALCULAR_INTERESES(xVALOR) THEN
   	
		    -- AHORA SE PONE PARA QUE NO CALCULE INTERESES SOBRE LA ULTIMA DILIGENCIA
		    --PORQUE SINO SALE MAS IMPORTE
		    xINCLUIRDEMORA := 'N';
		    xDEMORAMANUAL := 'S';
	    ELSE
	    	xFECHA:=xF_DEMORA;
	    END IF;

		-- comprobamos si hubiera entregas
		PkIngresos.Get_Pendiente(xValor,xPrincipal,xRecargo,xCostas,xDemora,xTotal_Deuda);

		-- AVERIGUAMOS EL IMPORTE DE LOS INTERESES DE DEMORA
		-- A LA FECHA DE LA DILIGENCIA DE EMBARGO DEL PRINCIPAL
		--PENDIENTE A LA FECHA
		xINTERES:=0;
		xPuedo:=0;

		IF xINCLUIRDEMORA='S' THEN
			
			-- Comprueba si cumple los plazos del art.108 para poder calcular intereses.
   	 		xPuedo:=PLAZO_APREMIO(xF_INGRE, xFNOTIFICACION, xFINPEVOL);

       		IF xPUEDO=1 THEN
       		   --DEVUELVE LOS INTERESES QUE HABRIA QUE COBRAR INCLUIDO DE LAS ENTREGAS A LAS QUE NO SE LES HAYA COBRADO
			   INT_ENTREGAS(xVALOR,xFINPEVOL,xTIPO,xDEMORA_VA);
			
 			   CAL_DEMORA(xFECHA, xFINPEVOL, xTIPO, xPRINCIPAL, xINTERES);

			   xINTERES := xINTERES + xDEMORA_VA;
			   
			END IF;
			
		ELSE
			IF xDEMORAMANUAL='S' THEN
				xINTERES:=xDEMORA_VA;
			END IF;
		END IF;
	
		PkIngresos.WRITE_INGRESO(xVALOR,'INGRESADO EN GESTION DE EXPEDIENTES','VE',xF_INGRE,
					xPRINCIPAL,xRECARGO,xCOSTAS,xINTERES,xCIEGO,'C');
	

	END LOOP;
	CLOSE C1;

	-- Solo dejamos los correctos.
	DelDeudasDiligenVencidas(xCIEGO);

	--Rellenar el temporal con las deudas que han sido procesadas
	PkwtDocIngreso.wtDeudasVivasySuspendidas(Null, xCIEGO, Null,'N','S');

	
	-- AVERIGUAR EL IMPORTE QUE SE HA INGRESADO
	SELECT SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) INTO xIMPORTE 
	FROM INGRESOS WHERE CODIGO_OPERACION=xCIEGO;


	-- Anotamos en el seguimiento del expediente el ingreso
	PkSeguimiento.AnotaIngreso(xIDExpe, xCIEGO, xIMPORTE, 'Ingreso');

	-- SI NO HAY RECIBOS SUSPENDIDOS Cerramos el expediente 
	IF xSUSPENDIDOS='N' THEN

		-- Se actualiza en expedientes y se anota en el seguimiento
		CerrarExpediente(xIDExpe, 'VE');

	ELSE

		UPDATE EXPEDIENTES SET AVISO='060',F_AVISO = SYSDATE WHERE ID=xIDExpe;

		PkSeguimiento.NotaInformativa(xIDExpe,'SE QUISO PAGAR UN EXPEDIENTE Y SE CAMBIA A ENTREGA PORQUE HABIA RECIBOS SUSPENDIDOS');
	

	END IF;


	-- Control del levantamiento de embargos
	-- Levantar los trámites si hubiera alguno en marcha
	LEVANTA_CHECK(xIDExpe, xEMBARGO);


END;
/

/******************************************************************************************/
COMMIT;
/********************************************************************/
