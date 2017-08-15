--
-- Creado: 26 de Diciembre de 2001 Agustin Leon Robles
--		Sirve para borrar una costa en el seguimiento de expedientes
--
-- Modificado: 09/06/2003. Lucas Fernández Pérez. Antes de borrar una costa, revisa si 
-- 	algun recibo tiene parte de esa costa ingresada, en cuyo caso no deja borrarla.
--
-- DELPHI
CREATE OR REPLACE PROCEDURE Delete_Costa(xIdCostas IN integer)   
AS

  xCostasIngre 	FLOAT;
  xCostasValor 	FLOAT;
  xCuantos 		INTEGER;
  
CURSOR cBorra_Costa IS select valor,importe
		             from costas_valores
			       where codigo_operacion=xIdCostas;
BEGIN

  FOR vBorraCosta IN cBorra_Costa loop

	-- Costas del valor
  	SELECT COSTAS INTO xCostasValor FROM VALORES WHERE ID=vBorraCosta.valor;

  	-- Costas ingresadas del valor
  	SELECT COUNT(*), SUM(COSTAS) INTO xCuantos,xCostasIngre FROM INGRESOS 
  		WHERE VALOR=vBorraCosta.valor;
	if xCuantos=0 then
  	  xCostasIngre:=0;
	end if;

	-- Si las costas que voy a borrar superan las costas pendientes, no dejo borrarlas,
	--  porque en los ingresos del valor hay importe de costas correspondientes a estas que
	--	intento borrar.
 	if vBorraCosta.Importe > (xCostasValor-xCostasIngre)  then
	   raise_application_error(-20004,'No se puede borrar la costa, está parcialmente ingresada');
 	end if;
 	
  END LOOP;

  -- Aquí llegados, se pueden borrar con seguridad las costas.
  FOR vBorraCosta IN cBorra_Costa loop
	update valores set costas=costas-vBorraCosta.Importe where id=vBorraCosta.Valor;
  END LOOP;
	
  delete from costas_valores where codigo_operacion=xIdCostas;
  delete from seguimiento where id_costas=xIdCostas;
  
END;
/


-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------

--
-- Documento técnico 07200-Costas.doc
--

/****************************************************************************/
-- Inserta una costa a un valor.
-- nos devuelde el identificador de la costa
--
/*DELPHI*/
CREATE OR REPLACE PROCEDURE PUT_COSTAS_RECIBO(
		xValor        IN INTEGER,
   		xConcep 	  IN VARCHAR,
   		xImpo         IN FLOAT,
   		xFecha        IN DATE,
   		xCodOperacion IN INTEGER,
		xID		  OUT INTEGER)

AS

BEGIN

  INSERT INTO COSTAS_VALORES
         (VALOR,Concepto,Importe,FECHA,codigo_operacion)
  VALUES (xValor,SubStr(xConcep,1,50),ROUND(xImpo,2),xFecha, xCodOperacion)
  RETURNING ID INTO xID;

  /*actualizamos en la tabla de valores*/
  UPDATE VALORES SET COSTAS = COSTAS + ROUND(xImpo,2)
  WHERE ID=xVALOR;

 END;
/

/****************************************************************************/
-- Inserta una costa a un expediente
-- Reparte el importe de la costa entre los valores del mismo, 
-- de forma proporcional al pendiente del valor.
--
/*DELPHI*/
CREATE OR REPLACE PROCEDURE ADD_COSTA_EXPE(
      xIDexpe 		IN	INTEGER,
      xCosta 		IN 	FLOAT,
      xQuien 		IN	VARCHAR,
      xCodigoOperacion 	OUT	INT
)
AS

xDEUDA 		FLOAT DEFAULT 0;
xPARTICIPA 		FLOAT DEFAULT 0;
xENTRPAR 		FLOAT DEFAULT 0;
xTEXTO 		CHAR(150);
xNada 		INTEGER;
xCont			INTEGER;
xContReg		INTEGER DEFAULT 0;
xErrorRound		FLOAT DEFAULT 0;

CURSOR C1 IS
        SELECT PENDIENTE,ID
               FROM IMPORTE_VALORES
               WHERE EXPEDIENTE=xIDEXPE
               AND F_INGRESO IS NULL
               AND FECHA_DE_BAJA IS NULL
               AND F_SUSPENSION IS NULL;

BEGIN

  xCodigoOperacion:=0;

-- Si está pagado o anulado no hacemos nada

SELECT COUNT(*) INTO xNADA FROM EXPEDIENTES 
	WHERE ID=xIDexpe
	AND F_INGRESO IS NULL
	AND F_ANULACION IS NULL;

IF xNADA = 0 THEN
   RETURN;
END IF;

  -- COMPROBAR SI HAY UNA DILIGENCIA DE EMBARGO DE CUENTAS CORRIENTES
  -- EN MARCHA PARA NO A#ADIR COSTAS DE CORREOS, PUES EN CASO CONTRARIO
  -- SERIA COMO LA PESCADILLA QUE SE MUERDE LA COLA NUNCA ACABARIAMOS
  -- LOS EMBARGOS AL NOTIFICARLE EL EMBARGO APARECIA UNA NUEVA DEUDA 

  IF EmbargoCuentaEnMarcha(xIDExpe) THEN

    -- SI HAY UNA DILIGENCIA EN MARCHA SOLO ANOTAR LA LLEGADA
    -- DE LA NOTIFICACION SIN HACER UN IMPORTE DE COSTAS 

    xTexto:=RTRIM(LTRIM(xQuien))||' '||ROUND(xCosta,2);

    PkSeguimiento.NotaInformativa(xIDEXPE, xQuien);

  ELSE

    SELECT SUM(PENDIENTE) INTO xDeuda FROM IMPORTE_VALORES
    WHERE EXPEDIENTE=xIDEXPE
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        AND F_SUSPENSION IS NULL;

    --en las publicaciones del BOP de expedientes se puede dar que se publique expedientes 
    --pagados, entonces no tiene que hacer nada.
    if xDeuda is null then 
	 return;
    end if;

    CODIGO_OPERACION(xCodigoOperacion);

    -- Necesito saber en el bucle cual es el ultimo registro para aplicarle los redondeos
    SELECT COUNT(*) INTO xCont FROM IMPORTE_VALORES
               WHERE EXPEDIENTE=xIDEXPE
               AND F_INGRESO IS NULL
               AND FECHA_DE_BAJA IS NULL
               AND F_SUSPENSION IS NULL;

    FOR v_VALOR IN  C1 LOOP

       -- PORCENTAJE DE PARTICIPACIÓN EN LA DEUDA 
       xPARTICIPA := v_VALOR.PENDIENTE * 100 / xDeuda;

       -- CALCULAR EL IMPORTE DE LA ENTREGA 
       xENTRPAR := xPARTICIPA * xCosta / 100;

	  -- Voy acumulando el error por redondeo a 2 cuando inserto en la B.D. el valor
	 xErrorRound:=xErrorRound+(xENTRPAR-ROUND(xENTRPAR,2));

	 xContREG:=xContREG+1; -- contador de registros que se estan tratando en el cursor
	 if xCont=xContREG then -- si es el último registro del cursor
		xENTRPAR:=xENTRPAR+xErrorRound; -- se le acumulan los errores de redondeo.
		if xENTRPAR < 0 then -- Si se llega a valores negativos por el redondeo
			xENTRPAR:=0; -- Se rebaja el redondeo lo máximo posible.
		end if;
	 end if;

       -- REALIZAR AL ENTREGA AL VALOR 
       PUT_COSTAS_RECIBO(v_VALOR.ID, xQuien, xENTRPAR,
                          sysdate, xCodigoOperacion, xNada);

    END LOOP;


    PkSeguimiento.AnotaCostas(xIDexpe, ROUND(xCosta, 2), xQuien, xCodigoOperacion);

  END IF;

END;
/

--**************************************************************************
--Acción: Al desagrupar o anular un valor de un expediente, quitarle las costas al 
--		  valor y pasárselas al resto de valores vivos en el expediente.
--Parámetros:
--			xIDEXPE: ID del Expediente.
--			xFecha: Fecha de entrada del valor en el expediente.
--			xID: ID del Valor.
--			xERROR: Código de error. Parámetro de salida.
--
--Modificación: 06/06/2003. Lucas Fernández Pérez. Si el recibo a desagrupar tiene costas 
-- 				 del expediente ingresadas no borra esas costas, asi como si esas costas no se pueden
--				 luego redistribuir en el expediente (por tener importe 0 o por no quedar recibos).
--
--Códigos de Incidencia que genera:
--
-- 	xError=0 : Se han borrado las costas al expediente del recibo desagrupado o suspendido.
--
--  xError=4 : No se han borrado las costas al expediente que tenía el recibo porque parte
--				de las mismas están ya ingresadas.
--
--  xError=5 : No se han borrado las costas al expediente que tenía el recibo porque al   
--				desagrupar o suspender el recibo el expediente queda sin recibos pendientes, 
--			    y no se puede redistribuir el importe de las costas.
--
--  xError=6 : No se han borrado las costas al expediente que tenía el recibo porque los  
--				recibos que quedan en el expediente no tienen importe pendiente, y no se 
--				puede redistribuir entre los mismos.
--
				
CREATE OR REPLACE PROCEDURE DELCostaValorPasaAExpe(
	xIDEXPE IN	INT, 
	xFecha 	IN	DATE, 
	xID 	IN	INT,
	xERROR 	OUT	INT)

AS

  xSUMA 	FLOAT DEFAULT 0;
  xCUANTOS 	FLOAT DEFAULT 0;
  xNADA 	INT default 0;

  xCostasIngre		FLOAT;
  xCostasValor 		FLOAT;
  xCostasPendientes FLOAT;
  xCostasExpe 		FLOAT;
  xImporte 			FLOAT;
  
  CURSOR C1 IS
  SELECT ID_COSTAS FROM SEGUIMIENTO
  WHERE ID_EXPE=xIDEXPE
 	AND F_ACTUACION >= xFecha
    AND ID_COSTAS IS NOT NULL;

BEGIN

  -- Costas del valor
  SELECT COSTAS INTO xCostasValor FROM VALORES WHERE ID=xID;

  -- Costas ingresadas del valor
  SELECT COUNT(*), SUM(COSTAS) INTO xCuantos,xCostasIngre FROM INGRESOS WHERE VALOR=xID;
  if xCuantos=0 then
  	xCostasIngre:=0;
  end if;

  -- Costas del valor - costas ingresadas = Costas pendientes del valor
  xCostasPendientes:=xCostasValor-xCostasIngre; 

  -- Costas del valor correspondientes al expediente del que se quiere desagrupar.
  SELECT COUNT(*),SUM(IMPORTE) INTO xCuantos, xCostasExpe FROM COSTAS_VALORES 
  WHERE VALOR=xID AND CODIGO_OPERACION IN (
  	SELECT ID_COSTAS FROM SEGUIMIENTO
  	WHERE ID_EXPE=xIDEXPE
 	AND F_ACTUACION >= xFecha
    AND ID_COSTAS IS NOT NULL);
  if xCuantos=0 then
  	xCostasExpe:=0;
  end if;
  
  -- si el pendiente de costas del valor es menor que las costas asociadas al expediente
  -- es porque parte de estas costas del expediente ya se han ingresado. No borro esas 
  -- costas, y permito que el recibo se desagrupe con las costas que tiene por expediente, 
  -- en delphi mostrará un mensaje de advertencia que indique este hecho.
  if xCostasExpe>xCostasPendientes then
  	xError:=4;
  	RETURN;
  end if;
  
  SELECT COUNT(*), SUM(PENDIENTE) INTO xCuantos, xImporte FROM IMPORTE_VALORES
    WHERE EXPEDIENTE=xIDEXPE
        AND F_INGRESO IS NULL
        AND FECHA_DE_BAJA IS NULL
        AND F_SUSPENSION IS NULL;

  -- Si no quedan valores a los que repartir las costas, no borro las costas del recibo.
  if ( (xCuantos=0) and (xCostasExpe >0) ) then
  	xError:=5;
	RETURN;
  end if;

  -- si importe=0, no añadiría costas, luego no borro las costas del recibo a desagrupar
  if ( (xImporte=0) and (xCostasExpe >0) ) then
  	xError:=6; 
	RETURN;
  end if;

                   
  -- Busca en seguimiento las costas del expediente donde esta el valor
  FOR v_COSTAS IN C1 LOOP

    -- Elimino las costas del valor
    DELETE FROM COSTAS_VALORES
     	  WHERE VALOR=xID 
	  AND CODIGO_OPERACION=v_COSTAS.ID_COSTAS
    RETURN IMPORTE INTO xImporte;

    IF SQL%FOUND THEN
	xSUMA:=xSUMA+xImporte;

  	-- actualizamos en la tabla de valores
  	UPDATE VALORES SET COSTAS = COSTAS - xImporte
  	WHERE ID=xID;

    END IF;

  END LOOP;

  -- SI HA HABIDO ALGUNA COSTA SUMARSELA A LOS DEMAS DEL EXPEDIENTE (sabiendo ya que hay 
  -- otros y que tienen importe pendiente, de no ser así saltarían los errores 5 y 6)
  IF xSUMA > 0 THEN
    ADD_COSTA_EXPE(xIDEXPE, xSUMA, 
      'COSTAS QUE TENIA UN RECIBO QUE SE HA DESAGRUPADO, SUSPENDIDO O ANULADO',xNADA);
  END IF;

  xError:=0;

END;
/

-- **************************************************************************
