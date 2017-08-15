/* ESTADOS DE UN PLAZO 

	DO - DOMICILIADO
	EB - ENVIADO AL BANCO
	DB - DEVUELTO POR EL BANCO
	PD - PAGADA LA DOMICILIACION

	VE - VENTANILLA
	PB - EMITIDO DOCUMENTO DE PAGO EN BANCO. (CUADERNO 60 MODALIDAD 2)
*/
-- ------------------------------------------------------------------------------------
-- Poner/Quitar Domiciliación a un fraccionamiento.
-- Modificado: 04/07/2003. Agustín León Robles. No grababa el número de cuenta del contribuyente
--					en donde se iban a realizar los cargos de los plazos
-- 
-- Modificado: 28/07/2003. Lucas Fernández Pérez. Elimina la llamada a DomiciliaUnPlazoFrac
-- 	porque las comprobaciones ahora	se hacen desde Delphi, y son:
--	Para DOMICILIAR: Podrá domiciliar si no hay ingresos previos en ningún plazo 
--						y si no hay generada ninguna carta de pago.
--  Para QUITAR DOMICILIACIÓN: No podrá haber ningún plazo en estado 'EB' ni 'PD'
--
-- Modificado: 01/09/2003. Lucas Fernández Pérez. Se añade el parámetro xVolEje para que 
--		sirva tanto para fraccionamientos en ejecutiva como en voluntaria.
-- ------------------------------------------------------------------------------------
/*DELPHI*/
CREATE OR REPLACE PROCEDURE DomiciliaFrac(
			xIDFrac 		IN	INTEGER,
			xVol_Eje		IN  char,
			xDomiciliado	IN	char,
			xEntidad 		IN	char,
			xOficina		IN	char,
			xDC			IN	char,
			xCuenta		IN	char,
			xTitular		IN	char,
			xFDomiciliacion	IN	date)
AS
BEGIN

  if xVol_Eje='E' then -- Fraccionamientos en EJECUTIVA
  
    IF xDomiciliado='N' THEN
    
		UPDATE FRACCIONAMIENTO SET
			Domiciliado='N', Entidad=NULL, Oficina=NULL, DC=NULL, Cuenta=NULL,
			Titular=NULL, FDomiciliacion=null
		WHERE ID=xIDFrac;

		UPDATE PLAZOS_FRAC SET ESTADO='VE' WHERE FRACCIONA=xIDFrac;

	ELSE 

		UPDATE FRACCIONAMIENTO SET
			Domiciliado='S', Entidad=xEntidad, Oficina=xOficina, DC=xDC, Cuenta=xCuenta,
			Titular=xTitular, FDomiciliacion=xFDomiciliacion
		WHERE ID=xIDFrac;

		UPDATE PLAZOS_FRAC SET ESTADO='DO' WHERE FRACCIONA=xIDFrac;

	END IF;
	
  else -- Fraccionamientos en VOLUNTARIA

   	IF xDomiciliado='N' THEN
   	
		UPDATE FRACCIONAMIENTO_VOL SET
			Domiciliado='N', Entidad=NULL, Oficina=NULL, DC=NULL, Cuenta=NULL,
			Titular=NULL, FDomiciliacion=null
		WHERE ID=xIDFrac;
		
		UPDATE PLAZOS_FRAC_VOL SET ESTADO='VE' WHERE FRACCIONA=xIDFrac;
		
	ELSE
	 
		UPDATE FRACCIONAMIENTO_VOL SET
			Domiciliado='S', Entidad=xEntidad, Oficina=xOficina, DC=xDC, Cuenta=xCuenta,
			Titular=xTitular, FDomiciliacion=xFDomiciliacion
		WHERE ID=xIDFrac;
		
		UPDATE PLAZOS_FRAC_VOL SET ESTADO='DO' WHERE FRACCIONA=xIDFrac;
		
	END IF;

  end if;

END;
/


--
-- Autor: 29/07/2003. Lucas Fernández Pérez. 
--	Procedimiento que revisa el correcto orden de aplicación de los discos de 
--		domiciliaciones de fraccionamientos en voluntaria/ejecutiva.
--
--	Parámetros:
--	xF_PLAZO : Mes de los plazos
--	xFECHA	 : Fecha de Envio/Devolucion/Pago
--	xCODIGO	 : Tipo de Operación
--				1 -> Envío del disco. 
--				2 -> Devolución del disco. 
--				3 -> Ingreso del disco. 
--	xVOLEJE	 : Tipo de Fraccionamiento (en voluntaria o en ejecutiva)
--	xERROR   : Código de salida
--			0 -> La operación es correcta.
--			1 -> Se intenta enviar un disco que ya se envió y se procesaron los devueltos.
--			2 -> Se intenta procesar el disco de devueltos sin haberse enviado primero.
--			3 -> Si el disco de devueltos ya se había procesado no se puede volver a hacer.
--			4 -> Se intenta procesar el disco de devueltos habiendo un disco anterior sin ingresar.
--			5 -> Se intenta ingresar sin haberse enviado el disco.
--   		6 -> Se intenta ingresar sin haber procesado el disco de devueltos antes.
--			7 -> Se intenta ingresar cuando ya estaba ingresado anteriormente.
--
-- Modificado: 01/09/2003. Lucas Fernández Pérez. Se añade el parámetro xVolEje para que 
--		sirva tanto para fraccionamientos en ejecutiva como en voluntaria.
--
-- DELPHI
-- 
CREATE OR REPLACE PROCEDURE DISCOS_C19_FRAC(
			xCODIGO IN CHAR,
			xF_PLAZO IN DATE,
			xFECHA  IN DATE,
			xVOL_EJE IN CHAR,
			xERROR  OUT INTEGER)
AS
	xExiste 	INTEGER;
	xFechaPago 	DATE;
	xFechaDevo	DATE;
BEGIN

	SELECT COUNT(*), MAX(F_PAGO), MAX(F_DEVOLUCION) Into xExiste, xFechaPago, xFechaDevo
	FROM DISCO_FRACCIONAMIENTOS_C19 
	WHERE TRUNC(F_PLAZO,'MM')=TRUNC(xF_PLAZO,'MM') AND VOL_EJE=xVOL_EJE;

	-- ENVIO DEL DISCO. 
	IF xCodigo=1 THEN 
	
		-- ERROR 1: Si el disco se envió anteriormente, y se devolvieron los plazos, 
		--				no puedo volver a enviarlo
		if ((xExiste>0) and (xFechaDevo is not null)) then 
		  xError:=1;
		  return;
		end if;
	
		-- Si es la primera vez que se genera el envío, se registra en la tabla. Si no fuese
		--	la primera vez no hace nada con la tabla.
		if xExiste=0 then 
			INSERT INTO DISCO_FRACCIONAMIENTOS_C19 ( F_PLAZO , F_ENVIO_BANCO, VOL_EJE )
			VALUES (xF_PLAZO, xFECHA, xVOL_EJE);
		end if;
		
		
	-- DISCO DE DEVOLUCION.
	ELSIF xCodigo=2 THEN

		-- ERROR 2: Si se intenta leer el disco de los plazos devueltos sin haberse enviado 
		--				no es posible procesar el disco.
		if xExiste=0 then 
		  xError:=2;
		  return;
		end if;

		-- ERROR 3: Si el disco de devueltos ya se había procesado no se puede volver a hacer.
		if ((xExiste>0) and (xFechaDevo is not null) ) then 
		  xError:=3;
		  return;
		end if;

		SELECT COUNT(*) Into xExiste FROM DISCO_FRACCIONAMIENTOS_C19 
		WHERE TRUNC(F_PLAZO,'MM')<TRUNC(xF_PLAZO,'MM') 
				AND F_PAGO IS NULL AND VOL_EJE=xVOL_EJE;

		-- ERROR 4: Si se intenta procesar el disco de devueltos habiendo un disco anterior 
		--				sin ingresar no permito procesar el disco de devoluciones
		if xExiste>0 then 
		  xError:=4;
		  return;
		end if;
		
		-- Anotamos que se ha procesado el disco de devolución.
		UPDATE DISCO_FRACCIONAMIENTOS_C19 SET F_DEVOLUCION=xFECHA 
		WHERE TRUNC(F_PLAZO,'MM')=TRUNC(xF_PLAZO,'MM') AND VOL_EJE=xVOL_EJE;
	
	-- INGRESO DEL DISCO.		
	ELSIF xCodigo=3 THEN

		-- ERROR 5: El disco se intenta ingresar sin haberse enviado
		if xExiste=0 then 
		  xError:=5;
		  return;
		end if;

		-- ERROR 6: El disco se intenta ingresar sin haber procesado el disco de devueltos
		--				 antes.
		if ( (xExiste>0) and (xFechaDevo is null) )  then 
		  xError:=6;
		  return;
		end if;
		
		-- ERROR 7: El disco se intenta ingresar cuando ya estaba ingresado.
		if ( (xExiste>0) and (xFechaPago is not null) )  then 
		  xError:=7;
		  return;
		end if;

		-- Anotamos el ingreso del disco.
		UPDATE DISCO_FRACCIONAMIENTOS_C19 SET F_PAGO=xFECHA 
		WHERE TRUNC(F_PLAZO,'MM')=TRUNC(xF_PLAZO,'MM') AND VOL_EJE=xVOL_EJE;
	
	END IF;
	
	xError:=0; -- Si llega aquí es que no ha habido error
	
END;
/

--
-- Autor: 07/07/2003. Agustín León Robles
--  Generar el disco del Cuaderno 19 de los fraccionamientos en ejecutiva
--
-- Se generan todos aquellos fraccionamientos que tengan plazos en el mes y año indicados,
--  siempre que el estado de los plazos de ese mes y año sea 'DO' ó 'EB'
--
-- Modificado: 16/07/2003. Lucas Fernández Pérez. 
-- Se añade un nuevo parametro para distinguir entre la impresión y la generación del disco.
--  xGeneraSoporte = 0 -> Solamente se quiere imprimir un listado del soporte, sin generarlo.
--						(no modifica plazos_frac)
--  xGeneraSoporte = 1 -> Se va a generar el soporte (modifica plazos_frac)
--
-- Modificado: 01/09/2003. Lucas Fernández Pérez. 
-- Se añade un parametro para distinguir entre fraccionamientos en voluntaria y ejecutiva.
--
-- MODIFICACION: 08/06/2004 Gloria Maria Calle Hernandez. Añadido campo AYTO a la tabla 
--		Recibos_Cuadreno19 para generar ficheros por ayuntamientos (xej. Catoure).
--
CREATE OR REPLACE PROCEDURE CUADERNO19_Frac
		(xMes		IN	CHAR,
		 xYear		IN	CHAR,
		 xVol_Eje 	IN  CHAR,
		 xGeneraSoporte   IN  INTEGER)
AS
      xNOMBRE_TITULAR 	CHAR(40);
    	xDOMI_TITULAR 	CHAR(50);
    	xCODPOSTAL 		CHAR(5);    
      xMUNITITULAR 	CHAR(35);
      xPROVINCIA		VARCHAR2(35);
    
    	x2 			CHAR(40);
    	x3 			CHAR(40);
    	x4 			CHAR(40);
      I 			INTEGER;
      xREGIS 		INTEGER default 0;
	xFecha		date;
	xCadena		Char(30);
	xESTADO		CHAR(2);

	-- cursores que recorren todos los FRACCIONAMIENTOS domiciliados y pendientes
	CURSOR cFraccionamiento IS 
	SELECT * FROM FRACCIONAMIENTO WHERE DOMICILIADO='S' AND ESTADO='ABIERTO';

	CURSOR cFraccionamientoVol IS 
	SELECT * FROM FRACCIONAMIENTO_VOL WHERE DOMICILIADO='S' AND ESTADO='ABIERTO';

BEGIN

	-- Borrar los datos de este usuario de la tabla temporal 
	DELETE FROM RECIBOS_CUADERNO19 WHERE USUARIO=USER;

	xCadena:='01/'||xMes||'/'||xYear||' 00:00:00';
	xFecha:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

	IF xVol_Eje='E' THEN -- FRACCIONAMIENTOS EN EJECUTIVA.
      FOR v_Fracc IN cFraccionamiento
      LOOP

		SELECT DISTINCT(ESTADO) INTO xESTADO FROM PLAZOS_FRAC
		WHERE FRACCIONA=v_Fracc.ID AND FECHA=v_Fracc.F_NEXT_PLAZO;

		IF (xESTADO IN ('DO','EB') 
			and (to_char(v_Fracc.F_NEXT_PLAZO,'mm')=xMes) 
			and (to_char(v_Fracc.F_NEXT_PLAZO,'yyyy')=xYear)
			) then

     		   	GETContribuyente(v_Fracc.TITULAR,xNOMBRE_TITULAR,xMuniTitular,
            	              xProvincia,xCodPostal,xDomi_Titular);

			xREGIS:=xREGIS+1;   
		 	I:=3;
      	   	x2:='EXPEDIENTE: ' ||v_Fracc.Expediente;
	         	x3:='N. DE FRACCIONAMIENTO: ' ||v_Fracc.ID;
         		x4:='PLAZO DE FECHA: ' ||TO_CHAR(v_Fracc.F_NEXT_PLAZO,'DD/MM/YYYY');
	   
      	   	INSERT INTO RECIBOS_CUADERNO19
		      	(AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
			 	ENTIDAD,SUCURSAL,DC,CUENTA,TOTAL,
			 	Campo2, Campo3, Campo4, CAMPOS_OPCIONALES, REFERENCIA_INTERNA)
	 	   	VALUES 
		  		(v_Fracc.AYTO,v_Fracc.ID,v_Fracc.TITULAR,xNOMBRE_TITULAR,
	             	SUBSTR(xDOMI_TITULAR,1,40),xCODPOSTAL,xMUNITITULAR, xNOMBRE_TITULAR, 
		 		v_Fracc.ENTIDAD,v_Fracc.OFICINA,v_Fracc.DC,v_Fracc.CUENTA,
            	 	v_Fracc.IMPO_NEXT_PLAZO,x2, x3, x4, I, TO_CHAR(v_Fracc.F_NEXT_PLAZO,'DD/MM/YYYY'));

			if xGeneraSoporte=1 then -- No es una impresión, se quiere generar el soporte.
				--Los Plazos se marcan como enviados al banco 
				--Hasta que no se apliquen los ingresos y devoluciones de este disco
				--no se podra volver a generar otro soporte.
				UPDATE PLAZOS_FRAC SET ESTADO='EB' 
				WHERE FRACCIONA=v_Fracc.ID AND FECHA=v_Fracc.F_NEXT_PLAZO;
			end if;

		end if;

      END LOOP;
      
    ELSE -- FRACCIONAMIENTOS EN VOLUNTARIA

      FOR v_Fracc IN cFraccionamientoVOL
      LOOP

		SELECT ESTADO INTO xESTADO FROM PLAZOS_FRAC_VOL
		WHERE FRACCIONA=v_Fracc.ID AND FECHA=v_Fracc.F_NEXT_PLAZO;

		IF (xESTADO IN ('DO','EB') 
			and (to_char(v_Fracc.F_NEXT_PLAZO,'mm')=xMes) 
			and (to_char(v_Fracc.F_NEXT_PLAZO,'yyyy')=xYear)
			) then

     		   	GETContribuyente(v_Fracc.TITULAR,xNOMBRE_TITULAR,xMuniTitular,
            	              xProvincia,xCodPostal,xDomi_Titular);

			xREGIS:=xREGIS+1;   
		 	I:=2;
	         	x2:='N. DE FRACCIONAMIENTO: ' ||v_Fracc.ID;
         		x3:='PLAZO DE FECHA: ' ||TO_CHAR(v_Fracc.F_NEXT_PLAZO,'DD/MM/YYYY');
	   
      	   	INSERT INTO RECIBOS_CUADERNO19
		      	(AYTO,ABONADO,NIF,NOMBRE,DOMICILIO,CODPOSTAL,MUNICIPIO,NOMBRE_TITULAR,
			 	ENTIDAD,SUCURSAL,DC,CUENTA,TOTAL,
			 	Campo2, Campo3, CAMPOS_OPCIONALES, REFERENCIA_INTERNA)
	 	   	VALUES 
		  		(v_Fracc.AYTO,v_Fracc.ID,v_Fracc.TITULAR,xNOMBRE_TITULAR,
	             	SUBSTR(xDOMI_TITULAR,1,40),xCODPOSTAL,xMUNITITULAR, xNOMBRE_TITULAR, 
		 		v_Fracc.ENTIDAD,v_Fracc.OFICINA,v_Fracc.DC,v_Fracc.CUENTA,
            	 	v_Fracc.IMPO_NEXT_PLAZO,x2, x3, I, TO_CHAR(v_Fracc.F_NEXT_PLAZO,'DD/MM/YYYY'));

			if xGeneraSoporte=1 then -- No es una impresión, se quiere generar el soporte.
				--Los Plazos se marcan como enviados al banco 
				--Hasta que no se apliquen los ingresos y devoluciones de este disco
				--no se podra volver a generar otro soporte.
				UPDATE PLAZOS_FRAC_VOL SET ESTADO='EB' 
				WHERE FRACCIONA=v_Fracc.ID AND FECHA=v_Fracc.F_NEXT_PLAZO;
			end if;

		end if;

      END LOOP;
  
    END IF;
    
	UPDATE RECIBOS_CUADERNO19 SET CUANTOS_REGISTROS=xREGIS WHERE USUARIO=USER;

END;
/

--
-- Autor: 09/07/2003. Agustín León Robles.
--	Dar por pagado los plazos de los fraccionamientos para a continuación procesar el disco de los devueltos.
--
-- Modificado: 29/07/2003. Lucas Fernández Pérez. 
--	Ya no es necesario comprobar si hay plazos de fechas anteriores en estado 'EB', porque
--	se controla desde el proceso DISCOS_C19_FRAC en combinación con DELPHI.
--	Se elimina el paráretro de salida xCuantos.
--
-- Modificado: 25/08/2003. Lucas Fernández Pérez. Se añaden los parametros xCanalIngreso 
--	y xidcartapagobanco	(con valores nulos) en la llamada al procedimiento paga_plazo.
-- Modificado: 01/09/2003. Lucas Fernández Pérez. Se añade el campo xCodOpeCartas en la
--  llamada a pagaplazo (con valor null). Se cambia el Canal_ingreso de NULL a 'PB'
-- Se añade un parametro para distinguir entre fraccionamientos en voluntaria y ejecutiva.
--	
CREATE OR REPLACE PROCEDURE PAGAR_PLAZOS_DOMICILIACIONES
		(xVol_Eje 		IN CHAR,
		xFIngre			IN	date,
		xFIngreBanco	IN	date,
		xFPlazo			IN	date,
		xIDCuenta		IN	integer)
AS

xIDExpe	integer;

CURSOR cPagarPlazos IS SELECT SUM(PENDIENTE) AS PENDIENTE,FRACCIONA,FECHA 
		FROM vwPLAZOS_FRAC WHERE ESTADO='EB' AND TO_CHAR(FECHA,'MM/YYYY')=TO_CHAR(xFPlazo,'MM/YYYY')
		GROUP BY FRACCIONA,FECHA;

CURSOR cPagarPlazosVol IS SELECT SUM(PENDIENTE) AS PENDIENTE,FRACCIONA,FECHA 
		FROM vwPLAZOS_FRAC_VOL WHERE ESTADO='EB' AND TO_CHAR(FECHA,'MM/YYYY')=TO_CHAR(xFPlazo,'MM/YYYY')
		GROUP BY FRACCIONA,FECHA;
BEGIN

  if xVol_Eje='E' then -- Fraccionamientos en EJECUTIVA
  
	FOR vPagarPlazos IN cPagarPlazos LOOP

		select Expediente into xIDExpe from Fraccionamiento where ID=vPagarPlazos.Fracciona;

		PkIngresos.PAGA_PLAZO(vPagarPlazos.Fracciona,xIDExpe,xFIngre,
					vPagarPlazos.Fecha,xFIngreBanco,
					NULL,NULL,'PB',vPagarPlazos.Pendiente,vPagarPlazos.Pendiente,
					xIDCuenta,NULL,NULL);

		--Lo marcamos como ingresado por domiciliacion
		UPDATE PLAZOS_FRAC SET ESTADO='PD' 
		WHERE FRACCIONA=vPagarPlazos.Fracciona AND FECHA=vPagarPlazos.Fecha AND ESTADO='EB';

	END LOOP;
	
  else -- Fraccionamientos en VOLUNTARIA

  	FOR vPagarPlazos IN cPagarPlazosVOL LOOP

		PKFraccionamientosVol.PAGA_PLAZO_VOL(vPagarPlazos.Fracciona,xFIngre,
				vPagarPlazos.Fecha,xFIngreBanco,
				NULL,NULL,'PB',vPagarPlazos.Pendiente,vPagarPlazos.Pendiente,
				xIDCuenta,NULL,NULL);

		--Lo marcamos como ingresado por domiciliacion
		UPDATE PLAZOS_FRAC_VOL SET ESTADO='PD' 
		WHERE FRACCIONA=vPagarPlazos.Fracciona AND FECHA=vPagarPlazos.Fecha AND ESTADO='EB';

	END LOOP;
  
  end if;

END;
/

-- *****************************************************************************************
--  Autor: 07/07/2003. Agustín León Robles
--  Marcar los Plazos de los fraccionamientos que vienen devueltos en el disco del cuad.19
--
--  Modificado: 01/08/2003. Lucas Fernández Pérez.
--  Primero se procesa la devolución y luego el ingreso (antes era al reves), 
--	  por lo que ya no es necesario ningún código referente a reposición de ingresos.
--
-- Modificado: 01/09/2003. Lucas Fernández Pérez. 
-- Se añade un parametro para distinguir entre fraccionamientos en voluntaria y ejecutiva.
-- *****************************************************************************************
CREATE OR REPLACE PROCEDURE DEVOLUCIONES_FRAC(xVol_Eje IN CHAR)
AS

  xFNextPlazo	DATE;
  xSuma			FLOAT;

CURSOR cDevoluciones IS SELECT RECIBO,IMPORTE,CODIGO_DEVOLU,REFERENCIA_INTERNA
		    FROM COBROS_BANCOS_DOMICILIADOS
		    WHERE USUARIO=USER AND PADRON='XXXXXE' AND YEAR='XXXX' AND PERIODO='XX';

CURSOR cDevolucionesVOL IS SELECT RECIBO,IMPORTE,CODIGO_DEVOLU,REFERENCIA_INTERNA
		    FROM COBROS_BANCOS_DOMICILIADOS
		    WHERE USUARIO=USER AND PADRON='XXXXXV' AND YEAR='XXXX' AND PERIODO='XX';
		    
BEGIN

  if xVol_Eje='E' then -- Fraccionamientos en Ejecutiva
  
	FOR v_Cursor IN cDevoluciones LOOP
		--La fecha del plazo devuelto por el banco viene en el campo referencia_interna del disco
		xFNextPlazo:=TO_DATE(v_Cursor.REFERENCIA_INTERNA,'DD/MM/YYYY');
	
       -- marcamos el Plazo del Fracc. como devuelto e incrementamos el número de devoluciones
		UPDATE PLAZOS_FRAC SET ESTADO='DB',NUM_DEVOLUCIONES=NUM_DEVOLUCIONES+1
		WHERE FRACCIONA=v_Cursor.RECIBO AND ESTADO='EB' AND FECHA=xFNextPlazo;
	END LOOP;

  else -- Fraccionamientos en Voluntaria
	   
	FOR v_Cursor IN cDevolucionesVOL LOOP
		--La fecha del plazo devuelto por el banco viene en el campo referencia_interna del disco
		xFNextPlazo:=TO_DATE(v_Cursor.REFERENCIA_INTERNA,'DD/MM/YYYY');
	
       -- marcamos el Plazo del Fracc. como devuelto e incrementamos el número de devoluciones
		UPDATE PLAZOS_FRAC_VOL SET ESTADO='DB' ,NUM_DEVOLUCIONES=NUM_DEVOLUCIONES+1
		WHERE FRACCIONA=v_Cursor.RECIBO AND ESTADO='EB' AND FECHA=xFNextPlazo;
	END LOOP;
	   
  end if;

END;
/

-- ----------------------------------------------------------------------------------------
-- Genera una carta de pago para el banco de un plazo de un fraccionamiento.
-- xVol_Eje='E' -> Fraccionamiento en ejecutiva.
-- xVol_Eje='V' -> Fraccionamiento de un recibo en voluntaria.
-- ----------------------------------------------------------------------------------------
/*INTERNO*/
CREATE OR REPLACE PROCEDURE CartaPagoBancoPlazoFrac(
			xIDPlazo IN INTEGER,
			xIDFrac  IN INTEGER,
			xFecha   IN DATE,
			xVol_Eje IN CHAR)
AS
 xCodOpe INTEGER;
BEGIN

   -- Pone un solo apunte al primero de los recibos que componen el plazo.
   PKCartaPagoBanco.NewCartaPago;
   xCodOpe:=PKCartaPagoBanco.VarCartaPagoBanco;
 
   IF xVol_Eje='E' THEN
	PKCartaPagoBanco.CartaPagoAddPlazo(xCodOpe,xIDPlazo);	
  	UPDATE PLAZOS_FRAC SET ESTADO='PB' WHERE FRACCIONA=xIDFrac AND FECHA=xFecha;
   ELSE
	PKCartaPagoBanco.CartaPagoAddPlazoVol(xCodOpe,xIDPlazo);	
   	UPDATE PLAZOS_FRAC_VOL SET ESTADO='PB' WHERE ID=xIDPlazo;
   END IF;

END;
/

-- ----------------------------------------------------------------------------------------
-- Genera una carta de pago para el banco de un fraccionamiento completo.
-- Solo genera una carta de pago, en las reimpresiones no se crean nuevas cartas de pago.
-- xVol_Eje='E' -> Fraccionamiento en ejecutiva.
-- xVol_Eje='V' -> Fraccionamiento de un recibo en voluntaria.
-- -----------------------------------------------------------------------------
/*DELPHI*/
CREATE OR REPLACE PROCEDURE CartaPagoBancoFraccionamiento(
		xIDFrac IN INTEGER,
		xVol_Eje IN CHAR)
AS

   xIDPlazo INTEGER;
   xGenerados INTEGER;

   CURSOR CPLAZOS IS SELECT FECHA FROM PLAZOS_FRAC 
		WHERE FRACCIONA=xIDFrac GROUP BY FECHA;

   CURSOR CPLAZOS_VOL IS SELECT ID,FECHA FROM PLAZOS_FRAC_VOL 
		WHERE FRACCIONA=xIDFrac;

BEGIN

   IF xVol_Eje = 'E' THEN -- Fraccionamiento en ejecutiva

	FOR v_Plazos in CPLAZOS LOOP

	   SELECT MIN(ID) INTO xIDPlazo FROM PLAZOS_FRAC 
	   WHERE FRACCIONA=xIDFrac AND FECHA=v_Plazos.Fecha;

	   SELECT COUNT(*) INTO xGenerados FROM RECIBOSCARTAPAGOBANCO 
	   WHERE PLAZO=xIDPlazo;

	   IF xGenerados=0 THEN
	   	CartaPagoBancoPlazoFrac(xIDPlazo,xIDFrac,v_Plazos.Fecha,xVol_Eje);
	   END IF;

   	END LOOP;	
	
	PkwtDocIngreso.wtDatosPostalesDeudorCPFrac(xIDFrac,xVol_Eje);

   ELSE -- Fraccionamiento de un recibo en voluntaria.

	FOR v_Plazos in CPLAZOS_VOL LOOP

	   SELECT COUNT(*) INTO xGenerados FROM RECIBOSCARTAPAGOBANCO 
	   WHERE PLAZO_VOL=v_Plazos.ID;

	   IF xGenerados=0 THEN
	   	CartaPagoBancoPlazoFrac(v_Plazos.ID,xIDFrac,v_Plazos.Fecha,xVol_Eje);
	   END IF;

   	END LOOP;	

	PkwtDocIngreso.wtDatosPostalesDeudorCPFrac(xIDFrac,xVol_Eje);

   END IF;
END;
/