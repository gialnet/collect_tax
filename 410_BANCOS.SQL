--
-- Indica el tipo de ingreso que ha de tener un valor, dependiendo de si es un ingreso parcial
-- o no y de si el valor está en algun embargo. Se llama desde la generación de ingresos por
-- parte de los bancos.
CREATE OR REPLACE PROCEDURE DimeTipoIngreso(
		xIDExpe 		IN INT,
		xPARCIAL_O_COBRO 	IN CHAR,
		xTipoIngreso 	OUT CHAR,
		xEmbargo 		OUT CHAR)
AS
xFDiligencia 	date;
BEGIN

   xEmbargo:='0';
   IF xIDExpe IS NOT NULL THEN
	   SELECT FECHA_DILIGENCIA, EMBARGO INTO xFDiligencia, xEmbargo
		 FROM EXPEDIENTES WHERE ID = xIDExpe;
   END IF;

   IF xFDiligencia IS NULL THEN -- No tiene embargo, se pone de tipo ingreso en ventanilla
	IF xPARCIAL_O_COBRO='C' THEN
	   xTipoIngreso:='VB';
	ELSE
	   xTipoIngreso:='EB';
	END IF;

   ELSE
	-- Miro que tipo de embargo tiene y así devuelvo el tipo de ingreso
	IF xPARCIAL_O_COBRO='C' THEN
	   if xEmbargo='1' then
	   	xTipoIngreso:='TC';
	   else if xEmbargo='3' then
		   	xTipoIngreso:='TS';
	   	  else if xEmbargo='4' then
		   		xTipoIngreso:='TI';
			 else if xEmbargo='8' then
			   		xTipoIngreso:='TV';
				else
			   		xTipoIngreso:='TO';
				end if;
			 end if;
		  end if;
	   end if;

	ELSE

	   if xEmbargo='1' then
	   	xTipoIngreso:='EP';
	   else if xEmbargo='3' then
		   	xTipoIngreso:='ES';
	   	  else if xEmbargo='4' then
		   		xTipoIngreso:='EI';
			 else if xEmbargo='8' then
			   		xTipoIngreso:='EV';
				else
			   		xTipoIngreso:='EO';
				end if;
			 end if;
		  end if;
	   end if;

	END IF;

   END IF;
END;
/

-- 12 de Marzo de 2002. Lucas Fernández Pérez
-- Obtiene los importes pendientes de un conjunto de valores agrupados por el CODIGO_OPERACION
-- Se utiliza en las entregas por banco, cuando por configuración se tengan que cobrar
-- primero las costas, puesto que ahí se necesita saber el pendiente total por costas.
/*INTERNO*/
CREATE OR REPLACE PROCEDURE PENDIENTE_CODIGO_OPERACION(
	xCodigoOperacion	IN 	INTEGER,
      SPRINCIPAL 		OUT 	FLOAT,
      SRECARGO 		OUT 	FLOAT,
      SCOSTAS 		OUT 	FLOAT,
      SDEMORA 		OUT 	FLOAT,
      SPENDIENTE 		OUT 	FLOAT)

AS

xINGRPRIN 		FLOAT DEFAULT 0;
xINGRRECA 		FLOAT DEFAULT 0;
PCOSTAS 		FLOAT DEFAULT 0;
PDEMORA 		FLOAT DEFAULT 0;

IPRINCIPAL 		FLOAT DEFAULT 0;
IRECARGO 		FLOAT DEFAULT 0;
ICOSTAS 		FLOAT DEFAULT 0;

CURSOR cPendiCodOpe IS
   SELECT ID,PRINCIPAL,RECARGO,COSTAS,DEMORA_PENDIENTE,PENDIENTE
	FROM IMPORTE_VALORES
	WHERE CODIGO_OPERACION=xCodigoOperacion
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL;

BEGIN

   SPRINCIPAL:=0;
   SRECARGO:=0;
   SCOSTAS:=0;
   SDEMORA:=0;
   SPENDIENTE:=0;

   FOR vPendi IN cPendiCodOpe LOOP

      -- SUMATORIA DEL PENDIENTE
    	SPENDIENTE := SPENDIENTE + vPendi.PENDIENTE;
    	SPRINCIPAL := SPRINCIPAL + vPendi.PRINCIPAL;
    	SRECARGO := SRECARGO + vPendi.RECARGO;
    	SCOSTAS := SCOSTAS + vPendi.COSTAS;
	SDEMORA:= SDEMORA + vPendi.DEMORA_PENDIENTE;

	-- COJER LOS IMPORTES DE LO ANTERIORMENTE INGRESADO
	PkIngresos.GET_INGRESADO(vPendi.ID, xINGRPRIN, xINGRRECA, PCOSTAS, PDEMORA);
	--SUMATORIA DE LOS INGRESOS
      IPRINCIPAL := IPRINCIPAL + xINGRPRIN;
      IRECARGO := IRECARGO + xINGRRECA;
      ICOSTAS := ICOSTAS + PCOSTAS;

   END LOOP;

   SPRINCIPAL := SPRINCIPAL - IPRINCIPAL;
   SRECARGO := SRECARGO - IRECARGO;
   SCOSTAS := SCOSTAS - ICOSTAS;

END;
/

-- 12 de Marzo de 2002. Lucas Fernández Pérez
-- Obtiene los importes pendientes de un conjunto de valores agrupados por
-- una CARTA DE PAGO EN BANCO
-- Se utiliza en las entregas por banco, cuando por configuración se tengan que cobrar
-- primero las costas, puesto que ahí se necesita saber el pendiente total por costas.
/*INTERNO*/
CREATE OR REPLACE PROCEDURE PENDIENTE_CARTA_PAGO(
	xIDCartaPagoBanco	IN 	INTEGER,
      SPRINCIPAL 		OUT 	FLOAT,
      SRECARGO 		OUT 	FLOAT,
      SCOSTAS 		OUT 	FLOAT,
      SDEMORA 		OUT 	FLOAT,
      SPENDIENTE 		OUT 	FLOAT)

AS

xINGRPRIN 		FLOAT DEFAULT 0;
xINGRRECA 		FLOAT DEFAULT 0;
PCOSTAS 		FLOAT DEFAULT 0;
PDEMORA 		FLOAT DEFAULT 0;

IPRINCIPAL 		FLOAT DEFAULT 0;
IRECARGO 		FLOAT DEFAULT 0;
ICOSTAS 		FLOAT DEFAULT 0;

CURSOR cPendiCodOpe IS
   SELECT ID,PRINCIPAL,RECARGO,COSTAS,DEMORA_PENDIENTE,PENDIENTE
	FROM IMPORTE_VALORES
	WHERE ID in (select valor from RecibosCartaPagoBanco
			where CartaPagoBanco=xIDCartaPagoBanco)
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL;

BEGIN

   SPRINCIPAL:=0;
   SRECARGO:=0;
   SCOSTAS:=0;
   SDEMORA:=0;
   SPENDIENTE:=0;

   FOR vPendi IN cPendiCodOpe LOOP

      -- SUMATORIA DEL PENDIENTE
    	SPENDIENTE := SPENDIENTE + vPendi.PENDIENTE;
    	SPRINCIPAL := SPRINCIPAL + vPendi.PRINCIPAL;
    	SRECARGO := SRECARGO + vPendi.RECARGO;
    	SCOSTAS := SCOSTAS + vPendi.COSTAS;
	SDEMORA:= SDEMORA + vPendi.DEMORA_PENDIENTE;

	-- COJER LOS IMPORTES DE LO ANTERIORMENTE INGRESADO
	PkIngresos.GET_INGRESADO(vPendi.ID, xINGRPRIN, xINGRRECA, PCOSTAS, PDEMORA);
	--SUMATORIA DE LOS INGRESOS
      IPRINCIPAL := IPRINCIPAL + xINGRPRIN;
      IRECARGO := IRECARGO + xINGRRECA;
      ICOSTAS := ICOSTAS + PCOSTAS;

   END LOOP;

   SPRINCIPAL := SPRINCIPAL - IPRINCIPAL;
   SRECARGO := SRECARGO - IRECARGO;
   SCOSTAS := SCOSTAS - ICOSTAS;

END;
/
-- Realiza un ingreso de una carta de pago de un plazo de un fraccionamiento.
-- El plazo se paga completamente. Si tenía entregas a cuenta, estas pasan a posibles
-- plazos pendientes, y si no hay mas plazos pendientes, se anota como un ingreso indebido.
--
-- Modificado: 25/08/2003. Lucas Fernández Pérez. Añade los campos xCanalIngreso y 
--			xIDCartaPagoBanco en la	llamada al procedimiento paga_plazo
-- Modificado: 28/08/2003. Lucas Fernández Pérez. Cuando el ingreso de la carta de pago
--		se pasa a los siguientes plazos, se actualizan esos ingresos para añadir información
--		referente a que esos ingresos vienen de una carta de pago en banco. Además
--		genera el correspondiente movimiento de cuentas en mov_cuentas.
-- Modificado: 29/08/2003. Lucas Fernández Pérez. 
--		Cuando el ingreso de la carta de pago genera un ingreso indebido, inserta en 
--		ingresos_indebidos el codigo_operacion del ingreso.
--  	Incluye los campos xCanalIngreso y xIDCartapagoBanco en la llamada a pago_plazo_vol
-- Modificado: 29/08/2003. Agustín León Robles. Se ha añadido un parametro nuevo xCodOpeCartas 
--		que es para tener agrupadas todas las cartas de pago que vienen en el mismo disco del C60
-- Modificado: 01/09/2003. Lucas Fernández Pérez. 
--      Se añaden datos en ingresos, mov_cuentas e ingresos_indebidos (cod_ope) en
--		la opcion 'V'.
-- 		En la llamada a paga_plazo y paga_plazovol se añade el parámetro xCodOpeCartas.
-- Modificado: 23/10/2003.Lucas Fernández Pérez. Inserta en ingresosindebidos los nuevos
--		campos fecha,f_cobro_banco,entidad_cobro,oficina_cobro.
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Inserta en incidencias_r los nuevos
--		campos f_cobro_banco,entidad_cobro,oficina_cobro.
--

CREATE OR REPLACE PROCEDURE IngresosBancoCartaPagoFrac(
	xIDCartaPagoBanco	IN	INTEGER,
	xIDCUENTA			IN	INTEGER,
	xIMPORTEING			IN	FLOAT,
	xFIngreBanco		IN	DATE,
	xFIngre				IN	DATE,
	xEntidadPago		IN	CHAR,
	xOficinaPago		IN	CHAR,
	xCanalIngreso		IN	CHAR,
	xVol_Eje			IN 	CHAR,
	xCodOpeCartas		IN	integer,
	xEncontrado			OUT	CHAR)
AS

  xIDFrac  INTEGER;
  xFecha	DATE;
  xIDIngresosIndebidos INTEGER;

  xPendiente FLOAT;
  xImporte	FLOAT;
  xEntregas FLOAT;
  xIngresado CHAR(1);

  xIDExpe 		INTEGER;
  xESTADO 		CHAR(7);
  xESTADOOLD 	CHAR(7);
  xIDValor_VOL 	INTEGER;
  xDeudaValor_VOL FLOAT;
  xZONA		CHAR(2);
  xCodOpe		INTEGER;
  xSuma		FLOAT;
  xParte 	INTEGER;

  CURSOR CVALORESCARTAPAGO IS
	SELECT ID,(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA
	FROM VALORES WHERE ID IN (
	SELECT VALOR FROM PLAZOS_FRAC WHERE FRACCIONA=xIDFrac AND FECHA=xFecha);

BEGIN

   xEncontrado:='S';

   IF xVOL_EJE='E' THEN

	begin

   	   SELECT FRACCIONA,FECHA INTO xIDFrac, xFecha FROM PLAZOS_FRAC WHERE ID=
		(SELECT PLAZO FROM RECIBOSCARTAPAGOBANCO WHERE CARTAPAGOBANCO=xIDCartaPagoBanco);

	   -- xIngresado va a indicar si todo el plazo está ya ingresado o no
	   -- (si vale 'S' esta ingresado completamente)
   	   SELECT SUM(PENDIENTE),SUM(IMPORTE),SUM(ENTREGAS),MIN(INGRESADO)
	   INTO xPENDIENTE,xIMPORTE,xENTREGAS,xIngresado
	   FROM vwPLAZOS_FRAC
     	   WHERE FRACCIONA= xIDFrac AND FECHA = xFecha;

	   -- IMPORTANTE: xImporte indica el importe real del ingreso que estamos realizando.

   	   SELECT EXPEDIENTE,ESTADO INTO xIDExpe,xEstadoOLD
		FROM VW_FRACCIONAMIENTO WHERE ID=xIDFrac;

	exception
		when no_data_found then
			begin
				xEncontrado:='N';
				return;
			end;
	end;

	PkIngresos.PAGA_PLAZO(xIDFrac,xIDExpe,xFIngre,xFecha,xFIngreBanco,xEntidadPago,
			xOficinaPago,xCanalIngreso,xPendiente,xPendiente,xIDCuenta,
			xIDCartaPagoBanco,xCodOpeCartas);

	IF xIngresado='S' THEN -- Si está ingresado, realmente no hay nada pendiente,aunque
		-- pendiente podia tener algun valor puesto que solo descuenta las entregas, no
		-- los ingresos totales del plazo
	   xPendiente:=0;
	END IF;

	IF xImporte > xPendiente THEN  -- Ingreso mas de lo que hay pendiente en el plazo
	-- Si estaba pendiente de ingresar y tiene entregas, como he pagado el plazo entero, paso
	-- el importe de la entrega a posibles plazos pendientes.

	-- Aqui puede estar el fraccionamiento pagado o no. Si esta pagado, Ingresos indebidos.
	-- Si no esta pagado, entrega a cuenta

	   SELECT ESTADO INTO xESTADO FROM VW_FRACCIONAMIENTO WHERE ID=xIDFrac;

	   if xESTADO <> 'CERRADO' then
		-- El fraccionamiento aun esta abierto, hago una entrega
		-- por el importe que sobra tras ingresar lo pendiente del plazo
		put_entrega_frac(xIDFrac,xIDExpe,xImporte-xPendiente,xFIngre,xIDCartaPagoBanco);
		
		-- Actualizo los ingresos añadiendo información sobre el pago en banco.
	    SELECT CODIGO_OPERACION INTO xCodOpe FROM USUARIOS WHERE USUARIO=USER;

	    -- Para el movimiento de cuentas, obtengo lo ingresado realmente
		select sum(principal+recargo+costas+demora) into xSuma
		from ingresos where codigo_operacion=xCodOpe;
		
		IN_MOV_CUE(xIDCUENTA, 'Ingreso carta de pago banco número: '||xIDCartaPagoBanco,
				'VR', xImporte-xPendiente, xSuma,
				xIDCUENTA, 'H', xFIngreBanco, xPARTE);
	    
		UPDATE INGRESOS SET CUENTA=xIDCuenta, F_COBRO_BANCO=xFIngreBanco,
					CANAL_INGRESO=xCanalIngreso, 
					ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago,
					PARTE_DEL_DIA=xPARTE,IDCARTAPAGOBANCO=xIDCartaPagoBanco,
					COD_OPERACION_CARTAS_PAGO=xCodOpeCartas
		WHERE CODIGO_OPERACION=xCodOpe;
		
		-- Si hay ingresos indebidos en put_entrega_frac, pongo los datos que faltan
		UPDATE INGRESOS_INDEBIDOS SET FECHA=xFIngre, F_COBRO_BANCO=xFIngreBanco,
			ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago
		WHERE CODIGO_OPERACION=xCodOpe;

		UPDATE INCIDENCIASR SET F_COBRO_BANCO=xFIngreBanco,
			ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago
		WHERE ID_ING_INDE=(SELECT ID FROM INGRESOS_INDEBIDOS 
			WHERE CODIGO_OPERACION=xCodOpe);
		
		--este update se pone aqui para no tocar el procedimiento in_mov_cue porque es 
		--llamado desde varios sitios
		UPDATE MOV_CUENTAS SET IDCARTAPAGOBANCO=xIDCartaPagoBanco WHERE ID=xPARTE;

	   else -- Ha ingresado de más

	    -- El código de operación se rellena al llamar a paga_plazo.
		SELECT CODIGO_OPERACION,ZONA INTO xCodOpe,xZONA FROM USUARIOS WHERE USUARIO=USER;

		INSERT INTO INGRESOS_INDEBIDOS
		(IDCARTAPAGO,CODIGO_OPERACION,IMPORTE,ZONA,
			FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
		VALUES (xIDCartaPagoBanco,xCodOpe,xImporte-xPendiente,xZONA,
			xFIngre,xFIngreBanco,xEntidadPago,xOficinaPago)
		RETURN ID INTO xIDIngresosIndebidos;

		
		--Insertamos el detalle de que recibos comprende
		FOR v_Valores IN CVALORESCARTAPAGO LOOP
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,
				F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
			VALUES (xIDIngresosIndebidos,v_Valores.ID,v_Valores.DEUDA,
			DECODE(xESTADOOLD,'CERRADO','S','N'),xFIngreBanco,xEntidadPago,xOficinaPago);
		END LOOP;

	   end if;

	END IF;

   ELSIF xVOL_EJE='V' THEN -- Se trata de un fraccionamiento en Voluntaria.

	begin

	   -- xIngresado va a indicar si todo el plazo está ya ingresado o no
	   -- (si vale 'S' esta ingresado completamente)
   	   SELECT FRACCIONA,FECHA,PENDIENTE,IMPORTE,ENTREGAS,INGRESADO
		 INTO xIDFrac, xFecha,xPENDIENTE,xIMPORTE,xENTREGAS,xIngresado
	   FROM VWPLAZOS_FRAC_VOL WHERE ID=
	     (SELECT PLAZO_VOL FROM RECIBOSCARTAPAGOBANCO WHERE CARTAPAGOBANCO=xIDCartaPagoBanco);

	   -- IMPORTANTE: xImporte indica el importe real del ingreso que estamos realizando.

	   SELECT ESTADO INTO xESTADOOLD FROM VW_FRACCIONAMIENTO_VOL WHERE ID=xIDFrac;

	exception
		when no_data_found then
			begin
				xEncontrado:='N';
				return;
			end;
	end;

	PKFraccionamientosVol.PAGA_PLAZO_VOL(xIDFrac,xFIngre,xFecha,xFIngreBanco,
					xEntidadPago,xOficinaPago,xCanalIngreso,xPendiente,xPendiente,
					xIDCuenta,xIDCartaPagoBanco,xCodOpeCartas);

	IF xIngresado='S' THEN -- Si está ingresado, realmente no hay nada pendiente,aunque
		-- pendiente podia tener algun valor puesto que solo descuenta las entregas, no
		-- los ingresos totales del plazo
	   xPendiente:=0;
	END IF;

	IF xImporte > xPendiente THEN  -- Ingreso mas de lo que hay pendiente en el plazo
	-- Si estaba pendiente de ingresar y tiene entregas, como he pagado el plazo entero, paso
	-- el importe de la entrega a posibles plazos pendientes.

	-- Aqui puede estar el fraccionamiento pagado o no. Si esta pagado, Ingresos indebidos.
	-- Si no esta pagado, entrega a cuenta

	   SELECT ESTADO INTO xESTADO FROM VW_FRACCIONAMIENTO_VOL WHERE ID=xIDFrac;

	   if xESTADO <> 'CERRADO' then
		-- El fraccionamiento aun esta abierto, hago una entrega
		-- por el importe que sobra tras ingresar lo pendiente del plazo
		put_entrega_frac_vol(xIDFrac,xImporte-xPendiente,xFIngre,xIDCartaPagoBanco);

		-- Actualizo los ingresos añadiendo información sobre el pago en banco.
	    SELECT CODIGO_OPERACION INTO xCodOpe FROM USUARIOS WHERE USUARIO=USER;

	    -- Para el movimiento de cuentas, obtengo lo ingresado realmente
		select sum(principal+recargo+costas+demora) into xSuma
		from ingresos where codigo_operacion=xCodOpe;
		
		IN_MOV_CUE(xIDCUENTA, 'Ingreso carta de pago banco número: '||xIDCartaPagoBanco,
				'VR', xImporte-xPendiente, xSuma,
				xIDCUENTA, 'H', xFIngreBanco, xPARTE);
	    
		UPDATE INGRESOS SET CUENTA=xIDCuenta, F_COBRO_BANCO=xFIngreBanco,
					CANAL_INGRESO=xCanalIngreso, 
					ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago,
					PARTE_DEL_DIA=xPARTE,IDCARTAPAGOBANCO=xIDCartaPagoBanco,
					COD_OPERACION_CARTAS_PAGO=xCodOpeCartas
		WHERE CODIGO_OPERACION=xCodOpe;

		-- Si hay ingresos indebidos en put_entrega_frac_vol, pongo los datos que faltan
		UPDATE INGRESOS_INDEBIDOS SET FECHA=xFIngre, F_COBRO_BANCO=xFIngreBanco,
			ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago
		WHERE CODIGO_OPERACION=xCodOpe;

		UPDATE INCIDENCIASR SET F_COBRO_BANCO=xFIngreBanco,
			ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago
		WHERE ID_ING_INDE=(SELECT ID FROM INGRESOS_INDEBIDOS 
			WHERE CODIGO_OPERACION=xCodOpe);

		--este update se pone aqui para no tocar el procedimiento in_mov_cue porque es 
		--llamado desde varios sitios
		UPDATE MOV_CUENTAS SET IDCARTAPAGOBANCO=xIDCartaPagoBanco WHERE ID=xPARTE;

	   else -- Ha ingresado de más

	    -- El código de operación se rellena al llamar a paga_plazovol.
		SELECT CODIGO_OPERACION,ZONA INTO xCodOpe,xZONA FROM USUARIOS WHERE USUARIO=USER;

		INSERT INTO INGRESOS_INDEBIDOS
		(IDCARTAPAGO,CODIGO_OPERACION,IMPORTE,ZONA,
			FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
		VALUES (xIDCartaPagoBanco,xCodOpe,xImporte-xPendiente,xZONA,
			xFIngre,xFIngreBanco,xEntidadPago,xOficinaPago)
		RETURN ID INTO xIDIngresosIndebidos;

		SELECT ID,(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE)
		INTO xIDValor_VOL,xDeudaValor_VOL
		FROM VALORES WHERE ID=(SELECT VALOR FROM FRACCIONAMIENTO_VOL WHERE ID=xIDFrac);

		--Insertamos el detalle del recibo que comprende
		INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,
				F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
		VALUES (xIDIngresosIndebidos,xIDValor_VOL,xDeudaValor_VOL,
			DECODE(xESTADOOLD,'CERRADO','S','N'),xFIngreBanco,xEntidadPago,xOficinaPago);

	   end if;

	END IF;


   END IF;

END;
/


--
-- Creado: 27 de Agosto de 2002. Agustín León Robles.
--	Ajustar los importes en la tabla de valores con los que se emitieron en la carta de
--	pago al contribuyente. Puede ocurrir que:
--			1) Cambiar el recargo del 10 al 20% o viceversa.
--			2) Que añadan o quiten costas.
--			3) Que el valor pase de notificado o no notificado o viceversa
--
-- Modificado: 28 Noviembre 2002. Agustín León Robles.
--	Cuando se actualize en la tabla de valores el importe del recargo y de las costas
--	hay que sumar los importes de las entregas a cuenta para que cuadre los datos.
--
-- Modificado: 27/08/2004. Lucas Fernández Pérez.
--
--  Se ajustan las costas, recargo y demora_pendiente del valor a lo que había cuando se generó la carta de pago.
--   RECARGO: Sabe que había cuando se generó la carta de pago por el campo RECARGOVALOR de reciboscartapagobanco.
--				Si ahora el recargo es distinto en el valor, pongo el recargo que había antes, salvo que se haya
--				ingresado más recargo de lo que había cuando se creó la carta de pago, en cuyo caso se pone el recargo
--				ingresado como nuevo recargo del valor.
--   COSTAS: Sucede igual que con el recargo, pero además, si hay un cambio de costas en el valor se inserta en 
--				Costas_valores un registro indicando el reajuste.
--   DEMORA_PENDIENTE: Se toma la que había en RECIBOSCARTAPAGOBANCO. Cuando se ingresa se supone que entre 
--						la creacion de la carta de pago (paso A) y el ingreso de la misma (paso B) no se produce un 
--						ingreso que afecte a la demora, porque si se ingresa parte de la demora pendiente entre
--						el paso A y el paso B, al hacer el paso B vuelve a poner como demora pendiente la que había en
--						el paso A, y la demora ingresada en el ingreso hecho entre el paso A y B no se descontaría.
--						Se descarta controlar esto porque no tiene sentido que se haga una entrega que llegue a la demora
--						pendiente y que luego ingrese la carta de pago.
--
create or replace procedure AjustaImportesCartaPago
			(xIDCartaPagoBanco	IN	INTEGER)
as
	xRecargoValor	float default 0;
	xCostasValor	float default 0;
	xF_Ingreso		date;
	xFecha_de_Baja	date;
	xIngreCostas	float default 0;
	xIngreRecargo	float default 0;
	xAjusteRecargo  float default 0;
	xAjusteCostas   float default 0;
	cursor cAjustaCartaPago is select * from RecibosCartaPagoBanco
				where CartaPagoBanco=xIDCartaPagoBanco;
begin

	for vCartaPago in cAjustaCartaPago loop

		--este if, esta puesto para salvar a las cartas de pago emitidas con anterioridad
		--a este procedimiento.
		if vCartaPago.Principal>0 then

			--costas que tiene actualmente grabadas el valor
			select recargo,costas,f_ingreso,fecha_de_baja
			into xRecargoValor,xCostasValor,xF_Ingreso,xFecha_de_Baja
			from valores where id=vCartaPago.Valor;

			--si el recibo está ya ingresado o suspendido no se ha de hacer nada
			if ((xF_Ingreso is null) and (xFecha_de_baja is null)) then

				--hay que sumar las costas y el recargo de las entregas a cuenta
				select sum(costas),sum(recargo) into xIngreCostas,xIngreRecargo
				from ingresos where valor=vCartaPago.Valor;

				if xIngreCostas is null then
					xIngreCostas:=0;
				end if;

				if xIngreRecargo is null then
					xIngreRecargo:=0;
				end if;

				xAjusteCostas:=xCostasValor;
				
				--hay alguna variacion en el importe de las costas
				if xCostasValor <> vCartaPago.CostasValor then
				
					-- El campo costasvalor de reciboscartapagobanco da el valor de las costas al crearse la carta pago
					if xIngreCostas > vCartaPago.CostasValor then
						xAjusteCostas:=xIngreCostas;
					else
						xAjusteCostas:= vCartaPago.CostasValor;
					end if;
					
					if xAjusteCostas<>xCostasValor then 
						-- Si el ajuste de la costa es el mismo importe que tiene el valor, no se inserta (insertaría importe 0)
						INSERT INTO COSTAS_VALORES
							(VALOR,Concepto,Importe,FECHA,codigo_operacion)
						VALUES (vCartaPago.Valor,'AJUSTE DE COSTAS',
							ROUND(xAjusteCostas-xCostasValor,2),SYSDATE, 0);
					end if;
					
				end if;
				
				xAjusteRecargo:=xRecargoValor;
				
				-- El campo RecargoValor de reciboscartapagobanco da el valor del recargo al crearse la carta de pago
				if xRecargoValor <> vCartaPago.RecargoValor then
					if xIngreRecargo > vCartaPago.RecargoValor then
						xAjusteRecargo:=xIngreRecargo;
					else
						xAjusteRecargo:= vCartaPago.RecargoValor;
					end if;
				end if;

				update valores set 
					recargo=xAjusteRecargo,
					costas=xAjusteCostas,
					demora_pendiente=vCartaPago.Demora

				where id=vCartaPago.Valor;
			end if;
		end if;

	end loop;

end;
/



-- ****************************************************************************************
-- Acción: Dar por ingresado las cartas que los contribuyentes pagan 
-- 	en las entidades colaboradoras.
-- 	    xCanalIngreso= 'PB' Pago en ventanilla entidad
--                     'PI' Pago a traves de Internet, banca virtual
-- 		      		   'PA' Pago autoservicio (cajero automatico)
-- MODIFICACIÓN: 12/03/2002. Lucas Fernández Pérez. Ingresar primero las costas por
--    			  configuración
-- MODIFICACIÓN: 27/08/2002. Agustin Leon Robles. En vez de mirar en la configuracion
-- 			  para saber si ha pagado fuera de plazo, lo miramos directamente
-- 			  en el campo f_juliana de la tabla cobros_bancos_ventanilla,
-- 			  porque los usuarios pueden cambiar los plazos cada vez que quieran.
-- Modificación: 30/01/2003. Agustín León Robles. Se actualiza en ingresos y en mov_cuentas
-- 				el campo idcartapagobanco.			
-- Modificado: 29/08/2003. Agustín León Robles. Se ha añadido un parametro nuevo 
--				xCodOpeCartas que es para tener agrupadas todas las cartas de pago 
--				que vienen en el mismo disco del C60
-- Modificado: 23/10/2003.Lucas Fernández Pérez. Inserta en ingresosindebidos los nuevos
--		campos fecha,f_cobro_banco,entidad_cobro,oficina_cobro.
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Inserta en incidencias_r los nuevos
--		campos f_cobro_banco,entidad_cobro,oficina_cobro.
-- Modificado: 22/12/2003. Lucas Fernández Pérez. No comprueba si la carta de pago está 
--	fuera de plazo porque se supone que el banco no la aceptaría. Si la f.juliana supera
--	la fecha de ingreso el banco no puede aceptar la carta de pago. Antes comprobaba esto 
--	con la f.juliana pero no consultaba el año, por lo que daba errores en un cambio
--	de año (ej: f.Juliana=005 digito_year=4, con fingreso=360 del 2003, daba error por 
--	suponer que 005 era el 5 de enero de 2003, e interpretaba que estaba fuera de plazo).
-- Modificado: 27/08/2004. Lucas Fernández Pérez. Elimina la llamada a RecalcularDemoraCartaPago,
--   que calculaba la demora a fecha de la carta de pago y la grababa en valores, porque despues
--	 llamaba a AjustaImportesCartaPago, que grababa en valores la demora de reciboscartapagobanco,
--	 dejando sin efecto la funcion que realizaba el primer procedimiento (que se elimina por desuso)
-- ************************************************************************************************

CREATE OR REPLACE PROCEDURE IngresosBancoCartaPago(
	xIDCartaPagoBanco	IN	INTEGER,
	xIDCUENTA			IN	INTEGER,
	xIMPORTEING			IN	FLOAT,
	xFIngreBanco		IN	DATE,
	xFIngre				IN	DATE,
	xFJuliana			IN	CHAR,
	xEntidadPago		IN	CHAR,
	xOficinaPago		IN	CHAR,
	xCanalIngreso		IN	CHAR,
	xCodOpeCartas		IN	integer,
	xEncontrado			OUT	CHAR)
AS
	xIDIngresosIndebidos	integer;
	xMaximaDiferencia	float;
	xFEmision		date;
	xTotal_Deuda 	float default 0;
	xPrincipal   	float default 0;
	xRecargo     	float default 0;
	xCostas      	float default 0;
	xDemora      	float default 0;
	xCodigoOperacion	integer;
	xTexto	    	CHAR(80);
	xPARTE       	INTEGER;
	xTotalIngresoReal	float default 0;
	xRestoIngreso	float default 0;
	xError		integer;
	xFIngresoBanco	date;
	xTipoIngreso	CHAR(2);
	xEmbargo		char(1);

	xConfigPrimeCostas CHAR(1);
	xTodasCostas	Boolean;
	xCostasTotales	FLOAT;

	xEs_Plazo		integer;
	xEs_PlazoVol 	integer;

	xZona			char(2);
	xCuantos 		integer;
	
	--Criterio para dar por ingresado los valores a traves de banco:
	-- 		1: voluntaria por orden de antiguedad
	--		2: ejecutiva por orden de antiguedad
	CURSOR cValores IS SELECT ID,F_INGRESO,FECHA_DE_BAJA,EXPEDIENTE,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE) AS DEUDA

		FROM VALORES WHERE ID in (select valor from RecibosCartaPagoBanco
					where CartaPagoBanco=xIDCartaPagoBanco)
		ORDER BY VOL_EJE DESC, FIN_PE_VOL;

BEGIN

	-- Lo primero que se hace es comprobar si la carta de pago es de
	-- VALORES O FRACCIONAMIENTOS

	SELECT MAX(PLAZO),MAX(PLAZO_VOL) INTO xEs_Plazo,xEs_PlazoVol
	FROM RECIBOSCARTAPAGOBANCO WHERE CARTAPAGOBANCO=xIDCartaPagoBanco;

	IF xEs_Plazo IS NOT NULL THEN  -- Fraccionamiento en ejecutiva
		IngresosBancoCartaPagoFrac(xIDCartaPagoBanco,xIDCUENTA,xIMPORTEING,xFIngreBanco,
		xFIngre,xEntidadPago,xOficinaPago,xCanalIngreso,'E',xCodOpeCartas,xEncontrado);
		RETURN;

	ELSIF xEs_PlazoVol IS NOT NULL THEN -- Fraccionamiento en voluntaria.
		IngresosBancoCartaPagoFrac(xIDCartaPagoBanco,xIDCUENTA,xIMPORTEING,xFIngreBanco,
					xFIngre,xEntidadPago,xOficinaPago,xCanalIngreso,'V',xCodOpeCartas,xEncontrado);
		RETURN;
	END IF;

	-- Llegados aqui, se sabe que la carta de pago es sobre un conjunto de valores.


	--se pone a null estos 2 campos porque cuando llamamos al write_ingreso
	--con la fecha del banco hace un select de estos 2 campos para
	--insertarlo en ingresos. En este procedure se hace un update en ingresos poniendo
	--los campos parte_del_dia y cuenta a sus valores correspondientes
	UPDATE USUARIOS SET LAST_NUMERO=NULL,LAST_BAJA=NULL WHERE USUARIO=USER;

	-- No sabemos la hora en la que se realizó el ingreso en la entidad financiera,
	-- y por eso se trunca.
	xFIngresoBanco:=Trunc(xFIngreBanco,'dd');

	--Averiguamos si el ingreso lo ha realizado fuera de plazo o no
	--para ello buscamos la fecha de emision de la carta de pago,
	--le sumamos los dias de plazo que tiene para pagar en el banco,
	--y el resultado tiene que ser superior o igual a la fecha de ingreso en el banco
	xEncontrado:='S';
	begin
		select F_CREACION into xFEmision from CartaPagoBanco where ID=xIDCartaPagoBanco;
	exception
		when no_data_found then
			begin
				xEncontrado:='N';
				return;
			end;
	end;

	--se genera el código de operación para los ingresos
	CODIGO_OPERACION(xCodigoOperacion);

	SELECT ZONA into xZona FROM USUARIOS WHERE USUARIO=USER;

	select MAXIMA_DIFERENCIA,DECODE(ORDENINGRESO,'CPRD','S','N')
	into xMaximaDiferencia,xConfigPrimeCostas from configuracion WHERE ZONA=xZona;

	--reajustar los importes de los valores con los que se emitieron en la carta de pago
	AjustaImportesCartaPago(xIDCartaPagoBanco);

	xRestoIngreso:=xIMPORTEING;

	-- Si tengo que cobrar primero las costas tengo que saber si puedo cobrarlas todas.
	-- Estamos ingresando un conjunto de valores, y si primero cobro las costas, se ingresaran
	-- primero las costas de cada valor.No puedo ir ingresando completamente recibo a recibo,
	-- tengo que ingresar primero las costas de todos los recibos, y si queda algo, ingreso
	-- completamente recibo a recibo
	IF xConfigPrimeCostas='S' THEN
	   PENDIENTE_CARTA_PAGO(xIDCartaPagoBanco,xPrincipal,xRecargo,xCostasTotales,xDemora,xTOTAL_DEUDA);
	   if xCostasTotales<=xRestoIngreso then
		xTODASCOSTAS:=True;
	   else
		xTODASCOSTAS:=False;
	   end if;

	END IF;

	FOR v_Valores IN cValores LOOP

		EXIT WHEN xRestoIngreso=0;

		--esta pendiente de cobro
		if (v_Valores.F_INGRESO is null and v_Valores.FECHA_DE_BAJA is null) then

			PkIngresos.Get_Pendiente(v_Valores.ID,xPrincipal,xRecargo,
							xCostas,xDemora,xTOTAL_DEUDA);

			IF xConfigPrimeCostas='S' THEN
			-- Dispongo para ingresar el valor completamente: del restoingreso menos
			-- lo que voy a ingresar de costas en los otros valores
			-- (todos menos el actual)
			   xCostasTotales:=xCostasTotales - xCostas;
			   xRestoIngreso:=xRestoIngreso-xCostasTotales;
			END IF;

			-- xRestoIngreso=cantidad de la que dispongo para hacer el ingreso al valor
			-- actual una vez descontada la cantidad que necesito para ingresar las
			-- costas de todos los otros valores no tratados aún.

			if xRestoIngreso >= xTOTAL_DEUDA then

				DimeTipoIngreso(v_Valores.EXPEDIENTE,'C',xTipoIngreso,xEmbargo);

				PkIngresos.WRITE_INGRESO(v_Valores.ID,
					'Pago mediante carta de pago en banco número: '
								||xIDCartaPagoBanco,
					xTipoIngreso,xFIngre,xPrincipal,xRecargo,
					xCostas,xDemora,xCodigoOperacion,'C',
					xFIngresoBanco,null,null,xCanalIngreso,xEmbargo);

				xTotalIngresoReal:=xTotalIngresoReal + xTOTAL_DEUDA;
				xRestoIngreso:=xRestoIngreso - xTOTAL_DEUDA;

				IF xConfigPrimeCostas='S' THEN -- Reajusto lo cambiado arriba
				   -- Si entra aquí es que sobra importe en la entrega realizada
				   -- como para pagar completamente este recibo que se esta tratando.
			   	   -- Repongo las costas pendientes de ingresar
				   xRestoIngreso:=xRestoIngreso + xCostasTotales;
				END IF;

			else
				--entrega
				-- este if es para el umbral
				--if (xTOTAL_DEUDA - xRestoIngreso) > xMaximaDiferencia then
				DimeTipoIngreso(v_Valores.EXPEDIENTE,'P',xTipoIngreso,xEmbargo);

				IF xConfigPrimeCostas='S' THEN -- Ingresar primero LAS COSTAS

				   -- Puedo entregar xRestoingreso cuando:
				   -- 1. TodasCostas=True.
				   -- 2. Siendo TodasCostas=False, no se cubran las costas del valor.
				   if (xTODASCOSTAS=True)
					or ((xTODASCOSTAS=False) and (xRestoIngreso<xCostas))
					then
					-- Aquí siempre xRestoIngreso < Deuda total del valor. Luego
					-- entrego todo lo que me queda.

					IF xRestoIngreso>0 THEN --Evito ingresos negativos

					   ENTREGA_VALOR(v_Valores.ID,xRestoIngreso,xFIngre,
						xFIngresoBanco,
						'Entrega mediante carta de pago en banco número: '
					   	||xIDCartaPagoBanco, xTipoIngreso,xCodigoOperacion,
					   	xCanalIngreso,xEmbargo,xError);

				   	   xTotalIngresoReal:=xTotalIngresoReal + xRestoIngreso ;

				         xRestoIngreso:=0;

					END IF;


				   elsif  xTODASCOSTAS=False and xRestoIngreso>=xCostas then
					-- Sólo puedo entregar las costas.

					   ENTREGA_VALOR(v_Valores.ID,xCostas,xFIngre,
						xFIngresoBanco,
						'Entrega mediante carta de pago en banco número: '
					   	||xIDCartaPagoBanco, xTipoIngreso,xCodigoOperacion,
					   	xCanalIngreso,xEmbargo,xError);

				   	   xTotalIngresoReal:=xTotalIngresoReal + xCostas ;
					   xRestoIngreso:=xRestoIngreso-xCostas;

				   end if;

				   -- Repongo las costas pendientes de ingresar
				   xRestoIngreso:=xRestoIngreso + xCostasTotales;


				ELSIF xConfigPrimeCostas='N' THEN

					ENTREGA_VALOR(v_Valores.ID,xRestoIngreso,xFIngre, xFIngresoBanco,
				  	'Entrega mediante carta de pago en banco número: '
					||xIDCartaPagoBanco, xTipoIngreso,xCodigoOperacion,
					xCanalIngreso,xEmbargo,xError);

					xTotalIngresoReal:=xTotalIngresoReal + xRestoIngreso;
					xRestoIngreso:=0;

				END IF;
			end if;


		--esta ingresado o anulado
		else
			--expediente de devolucion de ingresos indebidos

			--Solo para la primera vez
			IF xIDIngresosIndebidos IS NULL THEN

				INSERT INTO INGRESOS_INDEBIDOS
					(IDCARTAPAGO,CODIGO_OPERACION,IMPORTE,ZONA,
						FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
				VALUES (xIDCartaPagoBanco,xCodigoOperacion,v_Valores.DEUDA,xZONA,
						xFIngre,xFIngreBanco,xEntidadPago,xOficinaPago)

				RETURN ID INTO xIDIngresosIndebidos;

			END IF;

			--Insertamos el detalle de que recibos comprende
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,
					F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
				VALUES (xIDIngresosIndebidos,v_Valores.ID,v_Valores.DEUDA,'S',
					xFIngreBanco,xEntidadPago,xOficinaPago);
		end if;

	END LOOP;

	xTexto:='Ingreso carta de pago banco número: '||xIDCartaPagoBanco;

	IN_MOV_CUE(xIDCUENTA, xTexto, 'VR', xIMPORTEING, xTotalIngresoReal,
				xIDCUENTA, 'H', xFIngresoBanco, xPARTE);

	UPDATE INGRESOS SET PARTE_DEL_DIA=xPARTE,Cuenta=xIDCUENTA,
					ENTIDAD_COBRO=xEntidadPago, OFICINA_COBRO=xOficinaPago,
					IDCARTAPAGOBANCO=xIDCartaPagoBanco,COD_OPERACION_CARTAS_PAGO=xCodOpeCartas
	WHERE CODIGO_OPERACION=xCodigoOperacion;

	--este update se pone aqui para no tocar el procedimiento in_mov_cue porque es 
	--llamado desde varios sitios
	UPDATE MOV_CUENTAS SET IDCARTAPAGOBANCO=xIDCartaPagoBanco WHERE ID=xPARTE;
	
	
	if xIDIngresosIndebidos is not null then
	   UPDATE INGRESOS_INDEBIDOS SET IDMOVCUENTAS=xPARTE,
		IMPORTE=ABS(xIMPORTEING-xTotalIngresoReal)
	   WHERE ID=xIDIngresosIndebidos;

	else
		--esto ocurrira cuando haya pagado mas importe en el banco
		--de lo que realmente se debe
		if xRestoIngreso > 0 then
			INSERT INTO INGRESOS_INDEBIDOS
					(IDCARTAPAGO,IDMOVCUENTAS,CODIGO_OPERACION,IMPORTE,ZONA,
						FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
			VALUES (xIDCartaPagoBanco,xParte,xCodigoOperacion,xRestoIngreso,xZONA,
						xFIngre,xFIngreBanco,xEntidadPago,xOficinaPago)
			RETURN ID INTO xIDIngresosIndebidos;

		end if;
	end if;

	-- esto ocurrira cuando haya pagado mas importe en el banco
	-- de lo que realmente se debe. Se ponen en incidenciasr los recibos de la carta de pago,
	-- que no han podido ingresarse, y que no estuviesen ya ingresados antes de
	-- nuestro ingreso, ya que esos recibos se meten en incidenciasr más arriba
	-- en este procedimiento.
	if xRestoIngreso > 0 then

	   --Insertamos el detalle de que recibos comprende
	   FOR v_Valores IN CVALORES LOOP

		SELECT COUNT(*) INTO xCuantos FROM INCIDENCIASR WHERE
			ID_ING_INDE=xIDIngresosIndebidos AND VALOR=v_Valores.ID;

		if xCuantos=0 then --Este recibo no estaba ingresado antes de nuestro ingreso
			-- Se ha ingresado completamente en nuestro ingreso, y ha sobrado importe
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,
									F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
			VALUES (xIDIngresosIndebidos,v_Valores.ID,v_Valores.DEUDA,'N',
									xFIngreBanco,xEntidadPago,xOficinaPago);
	
		end if;

	   END LOOP;

	end if;


	--actualizo el codigo de operacion en asistencia, para poder reimprimir la carta de pago
	Update Asistencia Set IDINGRESO=xCodigoOperacion
				where IDCARTAPAGOBANCO=xIDCartaPagoBanco;

	--Revisar los expedientes tras los ingresos en que situacion han quedado
	RevisarExpeTrasIngre(xCodigoOperacion,'VB');

END;
/

/******************************************************************************************
Autor: Agustin Leon Robles 21/01/2002
Acción: Dar por pagado todos los ingresos de las cartas de pago que vienen
		en soporte magnetico (cuaderno 60, modalidad 2)

MODIFICACIÓN: 27/08/2002. Agustin Leon Robles. En vez de mirar en la configuracion
			  para saber si ha pagado fuera de plazo, lo miramos directamente
			  en el campo f_juliana de la tabla cobros_bancos_ventanilla,
			  porque los usuarios pueden cambiar los plazos
			  cada vez que quieran.
MODIFICACIÓN: 20/01/2003. Mª del Carmen Junco Gómez. Si la carta de pago se ha encontrado
		      y se le ha aplicado el cobro, se marcará como estado='AP' de aplicado en vez
		      de dejar el estado a null.
MODIFICACIÓN: 21/01/2003. Mª del Carmen Junco Gómez. Se añade a la tabla 
			  COBROS_BANCOS_VENTANILLA un campo que diferencia si se han leído 
			  liquidaciones o cartas de pago. Debemos filtrar ahora por 
			  este nuevo campo, ya que en el mismo disco pueden venir liquidaciones
			  y cartas de pago.
MODIFICACIÓN: 23/01/2003. Mª del Carmen Junco Gómez. Si la carta de pago no se encuentra,
			  se inserta una tupla en la tabla INCIDENCIAS_C60.
MODIFICACIÓN: 27/01/2003. Mª del Carmen Junco Gómez. En el histórico de soportes, el
			  campo aplicado tendrá ahora tres posibles valores:
			  		'N' no se ha aplicado nada. Sólo se ha leído el disco
			  		'P' disco parcialmente aplicado
			  		'S' disco completamente aplicado
MODIFICACIÓN: 29/01/2003. Mª del Carmen Junco Gómez. Se va a indicar en el desglose
			  del histórico de soportes que se ha aplicado el cobro de estas cartas
			  de pago
Modificado: 29/08/2003. Agustín León Robles. Se ha añadido un nuevo codigo de operacion
		que es para tener agrupadas todas las cartas de pago que vienen en el mismo disco del C60			  
******************************************************************************************/
-- Modificación: 24/10/2003. Lucas Fernández Pérez. Si se genera algún ingreso indebido,
--	se inserta una tupla en incidencias_c60 de estado 'CO'.
--	Se calculan y rellenan los campos cobrado_banco y total_valores de Histo_soportes.
-- Modificación: 28/10/2003. Lucas Fernández Pérez. En cobros_bancos_ventanilla añade el 
--	tipo de estado 'CO' cuando la carta de pago ha generado una incidencia por estar 
--  parcial o totalmente cobrada o anulada anteriormente
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Todos los ingresos indebidos que se 
--	generen en una aplicación de un disco tendrán la misma fecha de ingreso en banco, así
--	como la misma entidad y oficina de cobro. En incidenciasr e incidencias_c60 ya sí se
--	indicará la fecha de ingreso en banco real de cada una de las cartas de pago

CREATE OR REPLACE PROCEDURE PAGAR_CARTAS_PAGO_C60(
			xFecha	IN DATE,
			xIDCUENTA   IN INTEGER)

AS
mCanalIngreso	char(2);
xEstado		    char(2);
xEncontrado		char(1);
xCuantosPendi	integer;
xIDHISTO		integer;
xCodOpeCartas	integer;
xCobrado		float;
xTotal			float;
xIndebido		float;
xCodOpeUnaCP	integer;
xIDIngreIndebido integer;
xEntPresen		char(4);
xOfiPresen		char(4);
xFechaSoporte	date;

CURSOR CRECIBOS IS SELECT *
    FROM COBROS_BANCOS_VENTANILLA
	WHERE USUARIO=UID
	AND MODALIDAD='MOD2CP'
	for update of ESTADO;

BEGIN

   SELECT DISTINCT ID_HISTO_SOPORTES INTO xIDHISTO FROM COBROS_BANCOS_VENTANILLA
   WHERE USUARIO=UID AND MODALIDAD='MOD2CP';

   SELECT ENT_PRESENTADORA,OFI_PRESENTADORA,to_date(substr(fecha_soporte,1,2)||'/'||
   			substr(fecha_soporte,3,2)||'/'||substr(fecha_soporte,5,2),'dd/mm/yy')
   INTO xEntPresen,xOfiPresen,xFechaSoporte
   FROM HISTO_SOPORTES WHERE ID=xIDHISTO;

    --se genera el código de operación para todas las cartas de pago de un mismo disco, 
   	--este datos se grabara en un nuevo campo de la tabla de ingresos COD_OPERACION_CARTAS_PAGO
	CODIGO_OPERACION(xCodOpeCartas);   

	xCobrado:=0;
	xTotal:=0;
   
   FOR v_Recibos IN CRECIBOS
   LOOP

	--Tendra los siguientes valores:
	--	'1': Pago en ventanilla o mediante adeudo en cuenta personal
	--	'2': Pago en autoservicio (cajeros automaticos y similares)
	--	'3': Pago efectuado por Banca Virtual
	if v_Recibos.MEDIO_PAGO='1' then
		mCanalIngreso:='PB';
	elsif v_Recibos.MEDIO_PAGO='2' then
		mCanalIngreso:='PA';
	else
		mCanalIngreso:='PI';
	end if;

	IngresosBancoCartaPago(v_Recibos.Recibo,xIDCUENTA,v_Recibos.Importe,
				v_Recibos.F_COBRO,xFecha,v_Recibos.F_JULIANA,
				v_Recibos.ENTIDAD_RECEP,v_Recibos.OFICINA_RECEP,
				mCanalIngreso,xCodOpeCartas,xEncontrado);

	-- La tabla usuarios guarda el codigo de operación de los ingresos de la carta de pago.
    SELECT CODIGO_OPERACION INTO xCodOpeUnaCP FROM USUARIOS WHERE USUARIO=USER;
		
	begin -- Mira si se ha ingresado indebidamente algún importe.
		SELECT IMPORTE,ID into xIndebido,xIDIngreIndebido FROM INGRESOS_INDEBIDOS 
			WHERE CODIGO_OPERACION=xCodOpeUnaCP AND IDCARTAPAGO=v_Recibos.Recibo;
	exception
		when no_data_found then
			xIndebido:=0;
	end;
	
	-- Se pone en ingresos_indebidos la fecha, entidad y oficina de cobro que viene en 
	--	el disco que se está aplicando. Es la misma para todas las cartas de pago.
	if xIndebido>0 then
		UPDATE INGRESOS_INDEBIDOS SET F_COBRO_BANCO=xFechaSoporte, 
			ENTIDAD_COBRO=xEntPresen, OFICINA_COBRO=xOfiPresen
			WHERE ID=xIDIngreIndebido;
	end if;

	if xEncontrado='N' then
	  xEstado:='NE';
	else
	  if xIndebido=0 then -- El ingreso ha sido total
		xEstado:='AP';
	  else
		xEstado:='CO';--El ingreso ha generado incidencia por tener algo ingresado antes
	  end if;
	end if;		
	
	update Cobros_Bancos_Ventanilla set Estado=xEstado where current of CRecibos;	

	if xEncontrado<>'N' then
		xTotal:=xTotal+v_Recibos.IMPORTE-xIndebido; -- Ingresado en la aplicación
	end if;
	xCobrado:=xCobrado+v_Recibos.IMPORTE; -- Ingresado en el banco.

	if ( (xIndebido>0) or (xEncontrado='N') )then		
	   INSERT INTO INCIDENCIAS_C60 (
		 RECIBO, EMISOR, ENTIDAD_RECEP, OFICINA_RECEP, F_COBRO, IMPORTE, PENDIENTE, 
		 MEDIO_PAGO, DOMICILIADO, ENTIDAD, OFICINA, DC, CUENTA, ESTADO, CODIGO_TRIBUTO, 
		 EJERCICIO, REMESA, DIGITO_YEAR, F_JULIANA, DISCRI_PERIODO, ID_HISTO_SOPORTES,
		 MODALIDAD,ID_ING_INDE)
	   VALUES(		 
		 v_Recibos.RECIBO, v_Recibos.EMISOR,	v_Recibos.ENTIDAD_RECEP,
		 v_Recibos.OFICINA_RECEP, v_Recibos.F_COBRO, v_Recibos.IMPORTE, 0,
		 v_Recibos.MEDIO_PAGO, v_Recibos.DOMICILIADO, v_Recibos.ENTIDAD, v_Recibos.OFICINA,
		 v_Recibos.DC, v_Recibos.CUENTA, 
		 DECODE(xEncontrado,'N','NE','CO'),-- No Encontrado o Cobrado
		 v_Recibos.CODIGO_TRIBUTO,
		 v_Recibos.EJERCICIO, v_Recibos.REMESA, v_Recibos.DIGITO_YEAR,
		 v_Recibos.F_JULIANA, v_Recibos.DISCRI_PERIODO, v_Recibos.ID_HISTO_SOPORTES,
		 'MOD2CP', DECODE(xEncontrado,'N',null,xIDIngreIndebido));
	end if;
	

   END LOOP;
   
   -- Se busca si se ha tratado todo el soporte
   SELECT COUNT(*) INTO xCuantosPendi FROM COBROS_BANCOS_VENTANILLA
   WHERE USUARIO=UID AND ESTADO IS NULL;

   -- Indicamos en el histo_soportes que ya se ha aplicado, o no, todo el disco
   UPDATE HISTO_SOPORTES SET
     APLICADO=DECODE(xCuantosPendi,0,'S','P'),
	 ID_CUENTA_INGRESO= xIDCuenta , FECHA_INGRESO_APLICACION=xFecha,
	 COBRADO_BANCO=COBRADO_BANCO+xCobrado, TOTAL_VALORES=TOTAL_VALORES+xTotal
   WHERE ID = xIDHISTO;
	 
   UPDATE DESGLOSE_HISTO_SOPORTES SET APLICADO='S'
   WHERE ID_HISTO_SOPORTES=xIDHISTO AND MODALIDAD='MOD2CP';
   
END;
/

-- ****************************************************************************************
-- Acción: Ingresos de entidades colaboradoras a traves de transferencias
--         Ejemplo: un contribuyente llama por telefono a la recaudacion,
-- 	  pregunta por lo que debe y hace una transferencia a la recaudacion por la deuda.
-- MODIFICACIÓN: 5/03/2002 M. Carmen Junco Gómez. Se da la posibilidad de hacer el ingreso
-- 	  	sin intereses, calculando demora o con demora manual.
-- MODIFICACIÓN: 12/03/2002 Lucas Fernández Pérez. 
--		Ingresar primero las costas por configuración
-- Modificación: 13/12/2002. Agustín León Robles.  
--		Si el ingreso del banco fue anterior al final del periodo voluntaria
-- 		el recibo se pasa a voluntaria, tipico en los casos en los que se
-- 		traspapela el justificante del ingreso y lo encontramos una vez vencido
-- 		el periodo voluntario, para evitar que el usuario tenga que reponer a
-- 		voluntaria y luego aplicar el ingreso por banco
-- Modificado: 23/10/2003.Lucas Fernández Pérez. 
--		Inserta en ingresosindebidos los nuevos campos fecha,f_cobro_banco.
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Inserta en incidencias_r el nuevo
--		campo f_cobro_banco.
-- DELPHI
-- *******************************************************************************************

CREATE OR REPLACE PROCEDURE INGRESOS_VENTANABANCO(
	xCodOperacion	IN	INTEGER,
	xIDCUENTA		IN	INTEGER,
	xIMPORTEING		IN	FLOAT,
	xFIngreBanco	IN	DATE,
	xFIngre		IN	DATE,
	xIncluirDemora	IN	CHAR)
AS

	xIDIngresosIndebidos	integer;
	xDias			integer;
	xMaximaDiferencia	float;
	xFEmision		date;
	xTotal_Deuda 	float default 0;
	xPrincipal   	float default 0;
	xRecargo     	float default 0;
	xCostas      	float default 0;
	xDemora      	float default 0;
	xCodigoOperacion	integer;
	xTexto	    	CHAR(80);
	xPARTE       	INTEGER;
	xTotalIngresoReal	float default 0;
	xRestoIngreso	float default 0;
	xError		integer;
	xFIngresoBanco	date;
	xTipoIngreso	CHAR(2);
	xEmbargo		char(1);

	xConfigPrimeCostas CHAR(1);
	xTodasCostas	Boolean;
	xCostasTotales	FLOAT;

	xCuantos 		Integer;
	xZONA			CHAR(2);

	--Criterio para dar por ingresado los valores a traves de banco:
	--	1: voluntaria por orden de antiguedad
	--	2: ejecutiva por orden de antiguedad

	CURSOR cValores IS SELECT ID,F_INGRESO,FECHA_DE_BAJA,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE)
			AS DEUDA , EXPEDIENTE

		FROM VALORES WHERE CODIGO_OPERACION=xCodOperacion
		ORDER BY VOL_EJE DESC, FIN_PE_VOL;

	CURSOR cValoresCODOPE IS SELECT ID,
			(PRINCIPAL+RECARGO+COSTAS+DEMORA+DEMORA_PENDIENTE)AS DEUDA
		FROM VALORES WHERE CODIGO_OPERACION=xCodigoOperacion;

BEGIN

      --se pone a null estos 2 campos porque cuando llamamos al write_ingreso
	--con la fecha del banco hace un select de estos 2 campos para
	--insertarlo en ingresos. En este procedure se hace un update en ingresos poniendo
	--los campos parte_del_dia y cuenta a sus valores correspondientes
	UPDATE USUARIOS SET LAST_NUMERO=NULL,LAST_BAJA=NULL WHERE USUARIO=USER;

	-- No sabemos la hora en la que se realizó el ingreso en la entidad financiera,
	-- y por eso se trunca.
	xFIngresoBanco:=Trunc(xFIngreBanco,'dd');

	--se genera el código de operación para los ingresos
	CODIGO_OPERACION(xCodigoOperacion);

	--calcular los intereses a la fecha de ingreso en el banco
	INFORME_DEUDAS(xCodOperacion,xFIngresoBanco,xIncluirDemora,'VB');

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	SELECT DECODE(ORDENINGRESO,'CPRD','S','N') INTO xCONFIGPRIMECOSTAS
	FROM CONFIGURACION WHERE ZONA=xZONA;

	xRestoIngreso:=xIMPORTEING;

	-- Si tengo que cobrar primero las costas tengo que saber si puedo cobrarlas todas.
	-- Estamos ingresando un conjunto de valores, y si primero cobro las costas, se ingresaran
	-- primero las costas de cada valor.No puedo ir ingresando completamente recibo a recibo,
	-- tengo que ingresar primero las costas de todos los recibos, y si queda algo, ingreso
	-- completamente recibo a recibo
	IF xConfigPrimeCostas='S' THEN
	   PENDIENTE_CODIGO_OPERACION(xCodOperacion,xPrincipal,xRecargo,xCostasTotales,xDemora,xTOTAL_DEUDA);
	   if xCostasTotales<=xRestoIngreso then
		xTODASCOSTAS:=True;
	   else
		xTODASCOSTAS:=False;
	   end if;

	END IF;

	FOR v_Valores IN cValores LOOP

		EXIT WHEN xRestoIngreso=0;

		--esta pendiente de cobro
		if (v_Valores.F_INGRESO is null and v_Valores.FECHA_DE_BAJA is null) then


			-- Si el ingreso del banco fue anterior al final del periodo voluntaria
			-- el recibo se pasa a voluntaria, tipico en los casos en los que se
			-- traspapela el justificante del ingreso y lo encontramos una vez vencido
			-- el periodo voluntario, para evitar que el usuario tenga que reponer a
			-- voluntaria y luego aplicar el ingreso por banco
			--
			UPDATE VALORES SET RECARGO=0,VOL_EJE='V',F_APREMIO=NULL,DEMORA_PENDIENTE=0
			WHERE ID=v_Valores.ID
			AND TRUNC(FIN_PE_VOL,'DD') >= TRUNC(xFIngresoBanco,'DD')
			AND VOL_EJE='E';


			PkIngresos.Get_Pendiente(v_Valores.ID,xPrincipal,xRecargo,
							xCostas,xDemora,xTOTAL_DEUDA);


			IF xConfigPrimeCostas='S' THEN
			-- Dispongo para ingresar el valor completamente: del restoingreso menos
			-- lo que voy a ingresar de costas en los otros valores
			-- (todos menos el actual)
			   xCostasTotales:=xCostasTotales - xCostas;
			   xRestoIngreso:=xRestoIngreso-xCostasTotales;
			END IF;

			-- xRestoIngreso=cantidad de la que dispongo para hacer el ingreso al valor
			-- actual una vez descontada la cantidad que necesito para ingresar las
			-- costas de todos los otros valores no tratados aún.

			if xRestoIngreso >= xTOTAL_DEUDA then

				DimeTipoIngreso(v_Valores.EXPEDIENTE,'C',xTipoIngreso,xEmbargo);

				PkIngresos.WRITE_INGRESO(v_Valores.ID,
					'Pago mediante transferencia ',
					xTipoIngreso,xFIngre,xPrincipal,xRecargo,
					xCostas,xDemora,xCodigoOperacion,'C',
					xFIngresoBanco,null,null,'PB',xEmbargo);

				xTotalIngresoReal:=xTotalIngresoReal + xTOTAL_DEUDA;
				xRestoIngreso:=xRestoIngreso - xTOTAL_DEUDA;

				IF xConfigPrimeCostas='S' THEN -- Reajusto lo cambiado arriba
				   -- Si entra aquí es que sobra importe en la entrega realizada
				   -- como para pagar completamente este recibo que se esta tratando.
			   	   -- Repongo las costas pendientes de ingresar
				   xRestoIngreso:=xRestoIngreso + xCostasTotales;
				END IF;

			else

				DimeTipoIngreso(v_Valores.EXPEDIENTE,'P',xTipoIngreso,xEmbargo);

				IF xConfigPrimeCostas='S' THEN -- Ingresar primero LAS COSTAS

				   -- Puedo entregar xRestoingreso cuando:
				   -- 1. TodasCostas=True.
				   -- 2. Siendo TodasCostas=False, no se cubran las costas del valor.
				   if (xTODASCOSTAS=True)
					or ((xTODASCOSTAS=False) and (xRestoIngreso<xCostas))
					then
					-- Aquí siempre xRestoIngreso < Deuda total del valor. Luego
					-- entrego todo lo que me queda.

					IF xRestoIngreso>0 THEN --Evito ingresos negativos
				   	   ENTREGA_VALOR(v_Valores.ID,xRestoIngreso,xFIngre,
					   	xFIngresoBanco,'Entrega mediante transferencia ',
					   	xTipoIngreso,xCodigoOperacion,'PB',xEmbargo,xError);

				   	   xTotalIngresoReal:=xTotalIngresoReal + xRestoIngreso ;

				         xRestoIngreso:=0;

					END IF;


				   elsif  xTODASCOSTAS=False and xRestoIngreso>=xCostas then
					-- Sólo puedo entregar las costas.

				   	   ENTREGA_VALOR(v_Valores.ID,xCostas,xFIngre,
					      xFIngresoBanco,'Entrega mediante transferencia ',
					      xTipoIngreso,xCodigoOperacion,'PB',xEmbargo,xError);

				   	   xTotalIngresoReal:=xTotalIngresoReal + xCostas ;
					   xRestoIngreso:=xRestoIngreso-xCostas;

				   end if;

				   -- Repongo las costas pendientes de ingresar
				   xRestoIngreso:=xRestoIngreso + xCostasTotales;


				ELSIF xConfigPrimeCostas='N' THEN

				   ENTREGA_VALOR(v_Valores.ID,xRestoIngreso,xFIngre,
					xFIngresoBanco,
					'Entrega mediante transferencia ',
					xTipoIngreso,xCodigoOperacion,'PB',xEmbargo,xError);

				   xTotalIngresoReal:=xTotalIngresoReal + xRestoIngreso;
				   xRestoIngreso:=0;
				END IF;
			end if;


		--esta ingresado o anulado
		else
			--expediente de devolucion de ingresos indebidos

			--Solo para la primera vez
			IF xIDIngresosIndebidos IS NULL THEN

				INSERT INTO INGRESOS_INDEBIDOS
					(CODIGO_OPERACION,IMPORTE,ZONA,FECHA,F_COBRO_BANCO)
				VALUES (xCodigoOperacion,v_Valores.DEUDA,xZONA,xFIngre,xFIngreBanco)

				RETURN ID INTO xIDIngresosIndebidos;
			END IF;

			--Insertamos el detalle de que recibos comprende
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO)
				VALUES (xIDIngresosIndebidos,v_Valores.ID,v_Valores.DEUDA,'S',xFIngreBanco);
		end if;

	END LOOP;

	xTexto:='Ingreso mediante transferencia ';

	IN_MOV_CUE(xIDCUENTA, xTexto, 'VR', xIMPORTEING, xTotalIngresoReal,
				xIDCUENTA, 'H', xFIngresoBanco, xPARTE);

	UPDATE INGRESOS SET PARTE_DEL_DIA=xPARTE,Cuenta=xIDCUENTA
	WHERE CODIGO_OPERACION=xCodigoOperacion;

	if xIDIngresosIndebidos is not null then
		UPDATE INGRESOS_INDEBIDOS SET IDMOVCUENTAS=xPARTE,
				IMPORTE=ABS(xIMPORTEING-xTotalIngresoReal)
			WHERE ID=xIDIngresosIndebidos;
	else
		--esto ocurrira cuando haya pagado mas importe en el banco
		--de lo que realmente se debe
		if xRestoIngreso > 0 then
			INSERT INTO INGRESOS_INDEBIDOS
				(IDMOVCUENTAS,CODIGO_OPERACION,IMPORTE,ZONA,FECHA,F_COBRO_BANCO)
			VALUES (xParte,xCodigoOperacion,xRestoIngreso,xZONA,xFIngre,xFIngreBanco)
			RETURN ID INTO xIDIngresosIndebidos;
		end if;
	end if;

	-- esto ocurrira cuando haya pagado mas importe en el banco
	-- de lo que realmente se debe. Se ponen en incidenciasr los recibos
	-- que no han podido ingresarse, y que no estuviesen ya ingresados antes de
	-- nuestro ingreso, ya que esos recibos se meten en incidenciasr más arriba
	-- en este procedimiento.
	if xRestoIngreso > 0 then

	   --Insertamos el detalle de que recibos comprende
	   FOR v_Valores IN CVALORESCODOPE LOOP

		SELECT COUNT(*) INTO xCuantos FROM INCIDENCIASR WHERE
			ID_ING_INDE=xIDIngresosIndebidos AND VALOR=v_Valores.ID;

		if xCuantos=0 then --Este recibo no estaba ingresado antes de nuestro ingreso
			-- Se ha ingresado completamente en nuestro ingreso, y ha sobrado importe
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO)
			VALUES (xIDIngresosIndebidos,v_Valores.ID,v_Valores.DEUDA,'N',xFIngreBanco);
		end if;

	   END LOOP;

	end if;

	--Revisar los expedientes tras los ingresos en que situacion han quedado
	RevisarExpeTrasIngre(xCodigoOperacion,'VB');

END;
/

-- ****************************************************************************************
-- Autor:  01/10/2002 M. Carmen Junco Gómez.
-- Acción: Entrega a Cuenta sobre un valor de un ingreso realizado en un Organismo Externo.
-- 	  Se considerará un ingreso de tipo 'EB' (o 'VB') y la cuenta seleccionada será
-- 	  una dada de alta como perteneciente a un Organismo externo.
--
-- 07/10/2002 Agustin Leon Robles. Se añade el parametro 'xOrgExterno' para saber sin es un
--		ingreso en otro organismo (S) o si es un ingreso de entregas a cuenta
--		no aplicadas (R).
--		Si fuera éste último en la tabla de ingresos se graba lo siguiente:
--			En el campo CUENTA se graba el id de la cuenta de regularizacion
--			En el campo DATA_ENTIDAD se graba el id de la cuenta donde esta ingresado
-- Modificado: 23/10/2003.Lucas Fernández Pérez. 
--		Inserta en ingresosindebidos los nuevos campos fecha,f_cobro_banco.
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Inserta en incidencias_r el nuevo
--		campo f_cobro_banco.
--
-- DELPHI
-- ***************************************************************************************

CREATE OR REPLACE PROCEDURE ENTREGA_ORGANISMO_EXT(
	xVALOR		IN	INTEGER,
	xIDCUENTA		IN	INTEGER,
	xIMPORTEING		IN	FLOAT,
	xFIngreBanco	IN	DATE,
	xFIngre		IN	DATE,
	xOrgExterno		IN	CHAR)
AS

	xIDIngresosIndebidos	integer;
	xTotal_Deuda 		float default 0;
	xPrincipal   		float default 0;
	xRecargo     		float default 0;
	xCostas      		float default 0;
	xDemora      		float default 0;
	xCodigoOperacion		integer;
	xTexto	    		CHAR(80);
	xPARTE       		INTEGER;
	xTotalIngresoReal		float default 0;
	xRestoIngreso		float default 0;
	xError			integer;
	xFIngresoBanco		date;
	xTipoIngreso		CHAR(2);
	xEmbargo			char(1);

	xCuantos 			Integer;
	xZONA				CHAR(2);

	vVALOR			VALORES%ROWTYPE;
	xIDRegularizacion		integer;
BEGIN

	-- recogemos la tupla del valor al que se le va a hacer la entrega
	SELECT * INTO vVALOR FROM VALORES WHERE ID=xVALOR;

      --se pone a null estos 2 campos porque cuando llamamos al write_ingreso
	--con la fecha del banco hace un select de estos 2 campos para
	--insertarlo en ingresos. En este procedure se hace un update en ingresos poniendo
	--los campos parte_del_dia y cuenta a sus valores correspondientes
	UPDATE USUARIOS SET LAST_NUMERO=NULL,LAST_BAJA=NULL WHERE USUARIO=USER
		RETURN ZONA INTO xZONA;

	-- No sabemos la hora en la que se realizó el ingreso en la entidad financiera,
	-- y por eso se trunca.
	xFIngresoBanco:=Trunc(xFIngreBanco,'dd');

	--se genera el código de operación para los ingresos
	CODIGO_OPERACION(xCodigoOperacion);

	xRestoIngreso:=xIMPORTEING;

	PkIngresos.Get_Pendiente(xVALOR,xPrincipal,xRecargo,
	 				 xCostas,xDemora,xTOTAL_DEUDA);

	--esta pendiente de cobro
	IF (vValor.F_INGRESO is null and vValor.FECHA_DE_BAJA is null) THEN

	   if xRestoIngreso >= xTOTAL_DEUDA then

	      DimeTipoIngreso(vValor.EXPEDIENTE,'C',xTipoIngreso,xEmbargo);

		if xOrgExterno='R' then
			xTexto:='Ingreso por regularización';
		else
			xTexto:='Ingreso en Organismo Externo';
		end if;

		PkIngresos.WRITE_INGRESO(xValor,xTexto,xTipoIngreso,xFIngre,
 					xPrincipal,xRecargo,xCostas,xDemora,xCodigoOperacion,'C',
					xFIngresoBanco,null,null,'PB',xEmbargo);

		xTotalIngresoReal:=xTotalIngresoReal + xTOTAL_DEUDA;
		xRestoIngreso:=xRestoIngreso - xTOTAL_DEUDA;

	   else

		DimeTipoIngreso(vValor.EXPEDIENTE,'P',xTipoIngreso,xEmbargo);

		IF xRestoIngreso > 0 THEN --Evito ingresos negativos

			if xOrgExterno='R' then
				xTexto:='Entrega a cuenta por regularización';
			elsif xOrgExterno='S' then
				xTexto:='Entrega a cuenta en Organismo Externo';
			elsif xOrgExterno='A' then
				xTexto:='Ingresado fuera del plazo voluntario en O.E.';
			end if;

			ENTREGA_VALOR(xVALOR,xRestoIngreso,xFIngre,
				xFIngresoBanco,xTexto,xTipoIngreso,xCodigoOperacion,'PB',
				xEmbargo,xError);

			if xError=0 then
			     xTotalIngresoReal:=xTotalIngresoReal + xRestoIngreso ;
			     xRestoIngreso:=0;
			end if;

		END IF;

	   end if;

	--esta ingresado o anulado
	ELSE
         INSERT INTO INGRESOS_INDEBIDOS
		(CODIGO_OPERACION,IMPORTE,ZONA,ORGANISMO_EXT,FECHA,F_COBRO_BANCO)
	   VALUES (xCodigoOperacion,vVALOR.PRINCIPAL+vVALOR.RECARGO+vVALOR.COSTAS+
		     vVALOR.DEMORA+vVALOR.DEMORA_PENDIENTE,xZONA,xOrgExterno,xFIngre,xFIngreBanco)
    	   RETURN ID INTO xIDIngresosIndebidos;

	   --Insertamos el detalle del recibo
	   INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO)
	   VALUES (xIDIngresosIndebidos,xVALOR,vVALOR.PRINCIPAL+vVALOR.RECARGO+vVALOR.COSTAS+
		     vVALOR.DEMORA+vVALOR.DEMORA_PENDIENTE,'S',xFIngreBanco);
	END IF;

	if xOrgExterno='R' then

		SELECT MIN(ID) INTO xIDRegularizacion FROM CUENTAS_SERVICIO
		WHERE ZONA=xZONA AND REGULARIZACION='S';

		IN_MOV_CUE(xIDRegularizacion, xTexto, 'VR', xIMPORTEING, xTotalIngresoReal,
		     xIDRegularizacion, 'H', xFIngresoBanco, xPARTE);

		UPDATE INGRESOS SET PARTE_DEL_DIA=xPARTE,Cuenta=xIDRegularizacion,
			ORGANISMO_EXT=xOrgExterno,DATA_ENTIDAD=xIDCUENTA
		WHERE CODIGO_OPERACION=xCodigoOperacion;

	else

		-- tanto para organismo_ext 'S','A'
		IN_MOV_CUE(xIDCUENTA, xTexto, 'VR', xIMPORTEING, xTotalIngresoReal,
		     xIDCUENTA, 'H', xFIngresoBanco, xPARTE);

		UPDATE INGRESOS SET PARTE_DEL_DIA=xPARTE,Cuenta=xIDCUENTA,
			ORGANISMO_EXT=xOrgExterno
		WHERE CODIGO_OPERACION=xCodigoOperacion;

	end if;

	if xIDIngresosIndebidos is not null then
	   UPDATE INGRESOS_INDEBIDOS SET IDMOVCUENTAS=xPARTE,
		    IMPORTE=ABS(xIMPORTEING-xTotalIngresoReal)
	   WHERE ID=xIDIngresosIndebidos;
	else
	   --esto ocurrira cuando haya pagado mas importe en el organismo externo
	   --de lo que realmente se debe
	   if xRestoIngreso > 0 then
	      INSERT INTO INGRESOS_INDEBIDOS
			(IDMOVCUENTAS,CODIGO_OPERACION,IMPORTE,ZONA,ORGANISMO_EXT,FECHA,F_COBRO_BANCO)
		VALUES (xParte,xCodigoOperacion,xRestoIngreso,xZONA,xOrgExterno,xFIngre,xFIngreBanco)
		RETURN ID INTO xIDIngresosIndebidos;

		SELECT COUNT(*) INTO xCuantos FROM INCIDENCIASR WHERE
		ID_ING_INDE=xIDIngresosIndebidos AND VALOR=xVALOR;

		if xCuantos=0 then
               --Este recibo no estaba ingresado antes de esta operación
		   -- Se ha ingresado completamente ahora, y ha sobrado importe
		   INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO)
		   VALUES (xIDIngresosIndebidos,xVALOR,vVALOR.PRINCIPAL+vVALOR.RECARGO+
			     vVALOR.COSTAS+vVALOR.DEMORA+vVALOR.DEMORA_PENDIENTE,'N',xFIngreBanco);
		end if;
	   end if;
	end if;

	--Revisar los expedientes tras los ingresos en que situacion han quedado
	RevisarExpeTrasIngre(xCodigoOperacion,'VB');

END;
/


/********************************************************************************************/
/********************************************************************************************/
--                           DESDE AQUI PARA LAS DOMICILIACIONES
/********************************************************************************************/
/********************************************************************************************/

/********************************************************************************************
Acción: realizar el proceso de marcar el recibo como devuelto
Modificación: 15/07/2002. Agustin Leon Robles. Antes se tenia en cuenta que el recibo
	        estuviera en voluntaria.
Modificación: 12/12/2002. M. Carmen Junco Gómez. Se quita el municipio.
********************************************************************************************/
CREATE OR REPLACE PROCEDURE CHECK_MARCA_DEVU(
			xPADRON    IN CHAR,
			xYEAR      IN CHAR,
			xPERIODO   IN CHAR,
			xRECIBO    IN INTEGER,
			xCDevolu   IN CHAR)
AS
BEGIN
	UPDATE VALORES SET ESTADO_BANCO='DB',
				 COD_DEVUELTO_BANCO=xCDevolu
	WHERE ESTADO_BANCO='EB'
		AND PADRON=xPADRON
		AND YEAR=xYEAR
		AND PERIODO=xPERIODO
		AND RECIBO=xRECIBO;
END;
/


/*************************************************************************************/
--Grabar manualmente un grupo de recibos como devuelto por el banco
--Tambien se utiliza para quitarle la marca de devuelto por el banco
CREATE OR REPLACE PROCEDURE MARCA_RECIBO_DEVUELTO(
		xMarca 	IN CHAR,
		xGRUPO	IN INTEGER,
		xCDevolu 	IN CHAR)
AS
   xID			INTEGER;
   xIDCUENTA		INTEGER;
   xIDMOV_CUENTAS 	INTEGER;
   xImporteIngresado 	FLOAT;
   xMENSAJE   		VARCHAR2(150);
   xSuma			FLOAT;
   xError 			INTEGER;
   xCuantos			INTEGER;
   xF_INGRESO		DATE;
   xVALOR			INTEGER;

   CURSOR c_valores IS SELECT * FROM VALORES WHERE CODIGO_OPERACION=xGRUPO;

BEGIN

   --marcar los recibos como devueltos
   IF (xMarca='S') THEN

	xImporteIngresado:=0;
      xCuantos:=0;

      FOR v_valores IN c_valores
      LOOP
	   xF_INGRESO:=v_valores.F_INGRESO;
	   xVALOR:=v_valores.ID;

         -- marcamos el recibo como devuelto
	   CHECK_MARCA_DEVU(v_valores.PADRON,v_valores.YEAR,
		  	        v_valores.PERIODO,v_valores.RECIBO,xCDevolu);

  	   IF (v_valores.F_INGRESO IS NOT NULL) THEN

		-- recogemos el id del ingreso y el número de la cuenta de ingreso
		SELECT ID,CUENTA,PRINCIPAL+RECARGO+COSTAS+DEMORA INTO xID,xIDCUENTA,xSuma
		FROM INGRESOS WHERE VALOR=v_valores.ID;

	      xImporteIngresado:=xImporteIngresado+xSuma;
		xCuantos:=xCuantos+1;

		-- Si se ha ingresado por la opcion de domiciliación reponemos el ingreso.
		-- Si el ingreso se hubiera realizado en la ventanilla no se repone el ingreso
	      IF (v_valores.COD_INGRESO='PD') THEN

               -- Para comprobar que no haya ingresos datados
               SELECT COUNT(*) INTO xERROR FROM INGRESOS
               WHERE ID=xID
 	         AND NUMERO_DE_DATA IS NOT NULL;

               IF xERROR >0 THEN
                  raise_application_error(-20006,'No se puede reponer un Ingreso Datado');
               END IF;

               DELETE FROM INGRESOS WHERE ID=xID;

	      END IF;
	   END IF;
	END LOOP;

	IF (xCuantos>0) THEN
	   IF xCuantos=1 THEN
		xMENSAJE:='REPOSICIÓN INGRESO DÍA: '||to_char(xF_INGRESO,'dd/mm/yyyy')||
			    'VALOR: '||xVALOR||' POR DEVOLUCIÓN DEL BANCO';
	   ELSE
  	      xMENSAJE:='REPOSICIÓN DE '||xCUANTOS||' RECIBOS POR DEVOLUCIÓN DEL BANCO';
	   END IF;

	   IN_MOV_CUE(xIDCUENTA,xMENSAJE,'RI',xImporteIngresado,xImporteIngresado,
   	              xIDCUENTA,'D',SYSDATE,xIDMOV_CUENTAS);
	END IF;
   ELSE
	--volver a dejarlos como entregados a banco
	FOR v_valores IN c_valores
	LOOP
	   UPDATE VALORES SET ESTADO_BANCO='EB',
		 		    COD_DEVUELTO_BANCO=NULL
	   WHERE ID=v_valores.ID
		   AND ESTADO_BANCO='DB'
		   AND TIPO_DE_OBJETO='R'
		   AND F_INGRESO IS NULL
		   AND FECHA_DE_BAJA IS NULL
		   AND F_SUSPENSION IS NULL
		   AND VOL_EJE='V';
	END LOOP;
   END IF;

END;
/

/*****************************************************************************************
Acción: Marcar los valores como devueltos por el banco, pero solo los 'EB'
Modificación: 24/01/2002. Agustin Leon Robles
Modificación: 15/07/2002. Agustin Leon Robles. No se tenia en cuenta que puede
		  un valor tener mas de un ingreso. Ahora se ha cambiado por un MAX en el select
		  de ingresos.
Modificación: 3/12/2002. Agustín León Robles. Solamente se hara un apunte en
	   	  banco de la devolucion si son ingresos 'PD', con lo que las siguientes lineas
		  'xImporteIngresado:=xImporteIngresado+xSuma;' 'xCuantos:=xCuantos+1;' se meten
		  dentro del 'IF (xTIPO='PD') THEN'.
Modificación: 12/12/2002. M. Carmen Junco  Gómez. Se quita el campo municipio.
Modificacion: 08/07/2004. Gloria Maria Calle Hernandez. Se filtra por tipo_de_objeto='R'
*******************************************************************************************/
CREATE OR REPLACE PROCEDURE DEVOLUCIONES_DE_DOMICILIADOS(
			xPADRON    IN CHAR,
			xYEAR      IN CHAR,
			xPERIODO   IN CHAR)
AS

   xID			INTEGER;
   xValor	  		INTEGER;
   xTIPO 	  		CHAR(2);
   xMENSAJE   		VARCHAR2(150);
   xF_INGRESO 		DATE;
   xIDCuenta  		INTEGER;
   xIDMov_Cuentas 	INTEGER;
   xError 			INTEGER;
   xImporte			FLOAT;
   xImporteIngresado 	FLOAT;
   xSuma			FLOAT;
   xCuantos			INTEGER;

CURSOR C1 IS SELECT RECIBO,IMPORTE,CODIGO_DEVOLU
		    FROM COBROS_BANCOS_DOMICILIADOS
		    WHERE USUARIO=USER
			AND PADRON=xPADRON
			AND YEAR=xYEAR
			AND PERIODO=xPERIODO;

BEGIN

   xImporteIngresado:=0;
   xCuantos:=0;

   FOR v_Cursor IN C1
   LOOP

	begin
	      SELECT ID,F_INGRESO,COD_INGRESO INTO xVALOR,xF_INGRESO,xTIPO
      	FROM VALORES
		WHERE PADRON=xPADRON AND YEAR=xYEAR
			AND PERIODO=xPERIODO AND RECIBO=v_Cursor.RECIBO AND TIPO_DE_OBJETO='R';
	exception
		when no_data_found then
			xValor:=null;
	end;

	if xValor is not null then

	    -- marcamos el recibo como devuelto update de valores:
		-- set ESTADO_BANCO='DB',COD_DEVUELTO_BANCO=xCDevolu
		CHECK_MARCA_DEVU(xPADRON,xYEAR,xPERIODO,
				     v_Cursor.Recibo,v_Cursor.Codigo_devolu);

		IF (xF_INGRESO IS NOT NULL) THEN

	  	   -- recogemos el id del ingreso y el número de la cuenta de ingreso
		   -- puede el recibo tener mas de un ingreso
		   SELECT MAX(ID),MAX(CUENTA),SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA)
			INTO xID,xIDCUENTA,xSuma
		   FROM INGRESOS WHERE VALOR=xVALOR;

		   -- Si se ha ingresado por la opcion de domiciliación reponemos el ingreso.
		   --	Si el ingreso se hubiera realizado en la ventanilla no se repone el ingreso
		   IF (xTIPO='PD') THEN

			xImporteIngresado:=xImporteIngresado+xSuma;
			xCuantos:=xCuantos+1;

	            -- Para comprobar que no haya ingresos datados
      	      SELECT COUNT(*) INTO xERROR FROM INGRESOS
            	WHERE ID=xID AND NUMERO_DE_DATA IS NOT NULL;
	            IF xERROR >0 THEN
      	         raise_application_error(-20006,'No se puede reponer un Ingreso Datado');
            	END IF;

	            DELETE FROM INGRESOS WHERE ID=xID;

		   END IF;

		END IF; --fin del IF (xF_INGRESO IS NOT NULL) THEN
	end if;

   END LOOP;

   IF xCUANTOS > 0 THEN

	IF xCUANTOS=1 THEN
	   xMENSAJE:='REPOSICIÓN INGRESO DÍA: '||to_char(xF_INGRESO,'DD/MM/YYYY')||
	  	       'VALOR: '||xVALOR||' POR DEVOLUCIÓN DEL BANCO';
	ELSE
  	   xMENSAJE:='REPOSICIÓN DE '||xCUANTOS||' RECIBOS POR DEVOLUCIÓN DEL BANCO';
	END IF;

      IN_MOV_CUE(xIDCUENTA,xMENSAJE,'RI',xImporteIngresado,xImporteIngresado,
   	   	     xIDCUENTA,'D',SYSDATE,xIDMOV_CUENTAS);
   END IF;

END;
/

-- ****************************************************************************************
-- Acción: Dar por ingresados todos los valores que estén en 'EB' de los municipios y 
--		el padrón seleccionado por el usuario
--  PARAMETROS ENTRADA:
-- 			xPADRON Código de padron que se desea pagar
-- 			xYEAR   Año al que pertenecen los valores a pagar
-- 			xFecha  Fecha de la operacion
-- 			xFecha_Ingreso Fecha en la que se realizo el ingreso en banco
-- 			xIDCuenta  Identificador de la cuenta donde se ingreso
-- MODIFICACIÓN: 12/12/2002 M. Carmen Junco Gómez. En vez de pasar como parámetro el 
--			municipio, el procedimiento se ejecutará para todos los municipios que el
--			usuario	haya seleccionado.
-- Modificacion: 18/12/2002 Agustín León Robles. Si el recibo se encuentra en ejecutiva 
--			lo pasamos a Voluntaria.
-- MODIFICACIÓN: 19/05/2003 M. Carmen Junco Gómez. Si la suma de lo ingresado es nulo
-- 			(p.ej. error al introducir los datos del padrón y cursor vacío), se quedaba el
-- 			saldo de la cuenta y del nuevo movimiento a nulo, en vez de a cero)
-- MODIFICACIÓN: 10/06/2003 M. Carmen Junco Gómez. Para dejar el valor en voluntaria se 
-- 			borran también las costas y posible notificación.
-- Modificado: 23/10/2003.Lucas Fernández Pérez. 
--		Inserta en ingresosindebidos los nuevos campos fecha,f_cobro_banco.
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Inserta en incidencias_r el nuevo
--		campo f_cobro_banco.
-- Modificado: 22/01/2004. Lucas Fernández Pérez. Tratamiento de Bonificaciones.
-- Ejemplo: Tenemos un recibo de 100 euros de Vehiculos, que tienen bonificación del 2%
--  por domiciliación. El procedimiento pone de principal 98 al recibo e ingresa los 98.
--	Cada recibo que vaya a ingresar aminora antes el principal del valor si el concepto del
--	recibo tiene bonificación, para hacer el ingreso sobre el principal aminorado. Igual
--	con los ingresos indebidos. Si hay un ingreso indebido, se calcula el importe que
--	se ingresó en el banco (que si era un importe bonificado no coincide con el principal)
--  y se pone como el importe de ingreso indebido.
-- DELPHI
-- ***************************************************************************************
CREATE OR REPLACE PROCEDURE PAGAR_BANCOS_DOMICILIADOS(
		 	xPADRON        	IN CHAR,
			xYEAR          	IN CHAR,
			xPERIODO       	IN CHAR,
			xFecha         	IN DATE,
			xFecha_Ingreso 	IN DATE,
			xFEmisionDisco	IN DATE,
			xIDCuenta	   	IN INTEGER)
AS
	xMUNICIPIO    		CHAR(3);
	xCodOpe 	  		INTEGER;
	xSaldo	  			FLOAT DEFAULT 0;
	xIngresoTotal 		FLOAT DEFAULT 0;
	xSaldoActual  		FLOAT DEFAULT 0;
	xIDMov_cuentas 		INTEGER;
	xIDIngresosIndebidos 	integer;
	xZONA				CHAR(2);
	xSumaIngIndebidos		FLOAT DEFAULT 0;
	xContador			INTEGER;
	xIMPOBONI			FLOAT DEFAULT 0;
	xIMPOBONIEXAC		FLOAT DEFAULT 0;
	xPrincipalBONI		FLOAT;

	CURSOR CAYTOS IS SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER;

	--para dar por ingresados solo los pendientes de ingreso y que no tengan entregas a cuenta
	CURSOR CVALORES IS SELECT ID,PADRON,PRINCIPAL,RECIBO,N_CARGO,YEAR_CONTRAIDO
		       FROM VALORES
	  	       WHERE AYTO=xMUNICIPIO
				 AND PADRON=xPADRON
		 		 AND YEAR=xYEAR
				 AND PERIODO=xPERIODO
				 AND TIPO_DE_OBJETO='R'
				 AND F_INGRESO IS NULL
				 AND FECHA_DE_BAJA IS NULL
				 AND ESTADO_BANCO='EB'
				 AND ENTREGAS_A_CUENTA=0
				 for update of principal,recargo,costas,vol_eje,f_apremio,relacion_apremio,
				 	orden_apremio,notificado,f_notificacion,demora_pendiente;
			       
	CURSOR cPagados IS SELECT ID,PADRON,PRINCIPAL,F_INGRESO
		       FROM VALORES
	  	       WHERE AYTO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
				 AND PADRON=xPADRON
		 		 AND YEAR=xYEAR
				 AND PERIODO=xPERIODO
				 AND TIPO_DE_OBJETO='R'
				 AND F_INGRESO IS NOT NULL
				 AND COD_INGRESO<>'PD'
				 AND ESTADO_BANCO='EB';

	CURSOR cAnulados IS SELECT ID,PADRON,PRINCIPAL,FECHA_DE_BAJA
		       FROM VALORES
	  	       WHERE AYTO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
				 AND PADRON=xPADRON
		 		 AND YEAR=xYEAR
				 AND PERIODO=xPERIODO
				 AND TIPO_DE_OBJETO='R'
				 AND FECHA_DE_BAJA IS NOT NULL
				 AND ESTADO_BANCO='EB';

BEGIN

	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	CODIGO_OPERACION(xCodOpe);

	-- INSERTAR EN MOVIMIENTOS CUENTAS, NECESARIO PARA WRITE_INGRESO
	-- PONEMOS SALDO,IMPORTE Y RECIBOS PUESTOS A 0
	-- PERO AL FINAL LO ACTUALIZAMOS
	INSERT INTO MOV_CUENTAS
		(CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
	VALUES
		(xIDCuenta,'PAGO DOMICILIADO EN EL BANCO','PD',0,0,xIDCuenta,'H',xFecha_ingreso,0)
	RETURN ID INTO xIDMov_cuentas;


	xIngresoTotal:=0;
	
	-- Se hace esta consulta una sola vez mejor que dentro de los bucles.
	SELECT PORC_BONIFI_DOMI into xImpoBoniExac FROM PROGRAMAS WHERE PROGRAMA='EXACCIONES';
	
	--para dar por ingresados solo los pendientes de ingreso
	--y que no tengan entregas a cuenta
	FOR vAYTOS IN CAYTOS LOOP

		xMUNICIPIO:=vAYTOS.MUNICIPIO;

		FOR v_domi IN CVALORES LOOP

			-- SE MIRA SI EL RECIBO SE HA COBRADO CON BONIFICACIÓN.		
			-- Tomo el importe bonificado si el valor es de IBI,RUSTICA,IAE,AGUA o VEHICULOS.
			SELECT COUNT(*), MAX(PORC_BONIFI_DOMI) into xCONTADOR, xIMPOBONI 
			FROM PROGRAMAS WHERE CONCEPTO=v_domi.PADRON;
			
			IF xContador=0 THEN -- No es un valor de esos conceptos			
				 -- Busco si es una exacción
				 SELECT COUNT(*) into xCONTADOR FROM CONTADOR_CONCEPTOS 
				 WHERE CARACTER_TRIBUTO='O' AND CONCEPTO=v_domi.PADRON;
				 	
				 if xContador>0 then -- Es una exacción, obtengo el % bonificacion
				   	xIMPOBONI:=xImpoBoniExac;
				 end if;
				 
			END IF;
			
			xPrincipalBONI:=ROUND(v_domi.PRINCIPAL*(1-(xIMPOBONI/100)),2);
			
			xIngresoTotal:=xIngresoTotal+xPrincipalBONI;
			
		    DELETE FROM COSTAS_VALORES WHERE VALOR=v_domi.ID;		    
		    DELETE FROM NOTIFICACIONES WHERE VALOR=v_domi.ID AND TIPO_NOTI<>'VOL';
			 UPDATE VALORES SET 
			 	   PRINCIPAL=xPrincipalBONI,
				   RECARGO=0,COSTAS=0,
			       VOL_EJE='V',F_APREMIO=NULL,RELACION_APREMIO=NULL,ORDEN_APREMIO=NULL,
			       NOTIFICADO='N',F_NOTIFICACION=NULL,DEMORA_PENDIENTE=0
			WHERE current of cvalores;

			PkIngresos.WRITE_INGRESO(v_domi.ID,'PAGO DOMICILIADO EN EL BANCO',
				                 'PD',xFECHA,xPrincipalBONI,0,0,0,xCodOpe,'C',
				                 xFecha_Ingreso,NULL,NULL,null,'0');

		END LOOP;		
		
	END LOOP;

	-- Hacer ingresos indebidos de los recibos que se han pagado en ventanilla o ventanilla
	-- banco desde la emision del disco hasta este día. Son recibos que estando domiciliados
	-- han pagado en ventanilla o ventanilla banco.
	
	FOR vIngresados in cPagados LOOP

		IF Trunc(vIngresados.F_INGRESO,'dd') > Trunc(xFEmisionDisco,'dd') then

			if xIDIngresosIndebidos is null then
				INSERT INTO INGRESOS_INDEBIDOS 
					(CODIGO_OPERACION,ZONA,DOMICILIACIONES,FECHA,F_COBRO_BANCO)
				VALUES (xCodOpe,xZONA,'S',xFecha,xFecha_Ingreso)

				RETURN ID INTO xIDIngresosIndebidos;
			end if;

			-- SE MIRA SI EL RECIBO SE HA COBRADO CON BONIFICACIÓN.		
			-- Tomo el importe bonificado si el valor es de IBI,RUSTICA,IAE,AGUA o VEHICULOS.
			SELECT COUNT(*), MAX(PORC_BONIFI_DOMI) into xCONTADOR, xIMPOBONI 
			FROM PROGRAMAS WHERE CONCEPTO=vIngresados.PADRON;
			
			IF xContador=0 THEN -- No es un valor de esos conceptos			
				 -- Busco si es una exacción
				 SELECT COUNT(*) into xCONTADOR FROM CONTADOR_CONCEPTOS 
				 WHERE CARACTER_TRIBUTO='O' AND CONCEPTO=vIngresados.PADRON;
				 	
				 if xContador>0 then -- Es una exacción, obtengo el % bonificacion
				  	xIMPOBONI:=xImpoBoniExac;
				 end if;
			END IF;
			
			xPrincipalBONI:=ROUND(vIngresados.PRINCIPAL*(1-(xIMPOBONI/100)),2);

						--Insertamos el detalle de que recibos comprende
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO)
				VALUES (xIDIngresosIndebidos,vIngresados.ID,xPrincipalBONI,'S',xFecha_Ingreso);

		END IF;

	END LOOP;

	--Hacer ingresos indebidos de los recibos que se han anulado con posterioridad a la
	--emision del disco, estando domiciliados
	
	FOR vAnulados in cAnulados LOOP

		if Trunc(vAnulados.FECHA_DE_BAJA,'dd') > Trunc(xFEmisionDisco,'dd') then

			if xIDIngresosIndebidos is null then
				INSERT INTO INGRESOS_INDEBIDOS 
					(CODIGO_OPERACION,ZONA,DOMICILIACIONES,FECHA,F_COBRO_BANCO)
				VALUES (xCodOpe,xZONA,'S',xFecha,xFecha_Ingreso)

				RETURN ID INTO xIDIngresosIndebidos;
			end if;

			-- SE MIRA SI EL RECIBO SE HA COBRADO CON BONIFICACIÓN.		
			-- Tomo el importe bonificado si el valor es de IBI,RUSTICA,IAE,AGUA o VEHICULOS.
			SELECT COUNT(*), MAX(PORC_BONIFI_DOMI) into xCONTADOR, xIMPOBONI 
			FROM PROGRAMAS WHERE CONCEPTO=vAnulados.PADRON;
			
			IF xContador=0 THEN -- No es un valor de esos conceptos			
				 -- Busco si es una exacción
				 SELECT COUNT(*) into xCONTADOR FROM CONTADOR_CONCEPTOS 
				 WHERE CARACTER_TRIBUTO='O' AND CONCEPTO=vAnulados.PADRON;
				 	
				 if xContador>0 then -- Es una exacción, obtengo el % bonificacion
				  	xIMPOBONI:=xImpoBoniExac;
				 end if;
			END IF;
			
			xPrincipalBONI:=ROUND(vAnulados.PRINCIPAL*(1-(xIMPOBONI/100)),2);

			--Insertamos el detalle de que recibos comprende
			INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO)
				VALUES (xIDIngresosIndebidos,vAnulados.ID,xPrincipalBONI,'S',xFecha_Ingreso);
		end if;

	END LOOP;

	SELECT SUM(IMPORTE) INTO xSumaIngIndebidos FROM INCIDENCIASR
			WHERE ID_ING_INDE=xIDIngresosIndebidos;

	if xSumaIngIndebidos is null then
		xSumaIngIndebidos:=0;
	end if;

	UPDATE INGRESOS_INDEBIDOS SET IDMOVCUENTAS=xIDMov_cuentas,IMPORTE=xSumaIngIndebidos
			WHERE ID=xIDIngresosIndebidos;

	-- Actualizamos el SALDO de la cuenta con el total de los ingresos 
	--	(lo ingresado más los ingresos indebidos)
	UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xIngresoTotal + xSumaIngIndebidos 
	WHERE ID=xIDCuenta
	RETURN SALDO INTO xSaldoActual;

	--Actualizamos en IMPORTE el importe total ingresado en el proceso más 
	-- los que se han ingresado por ventanilla o ventanilla banco (que son la suma
	--  de los ingresos indebidos) y en RECIBOS el importe total ingresado en el proceso
	UPDATE MOV_CUENTAS SET
				IMPORTE=xIngresoTotal+xSumaIngIndebidos,
				RECIBOS=xIngresoTotal,
				SALDO=xSaldoActual
	WHERE ID=xIDMov_cuentas;

/*	--Importe total que tienen ingresado en la cuenta
	SELECT SUM(PRINCIPAL) INTO xIngresoTotal
	       FROM VALORES
  	       WHERE AYTO IN (SELECT MUNICIPIO FROM TMP_AYTOS WHERE USUARIO=USER)
			 AND PADRON=xPADRON
	 		 AND YEAR=xYEAR
			 AND PERIODO=xPERIODO
			 AND TIPO_DE_OBJETO='R'
			 AND ESTADO_BANCO='EB'
			 AND ( Trunc(F_INGRESO,'dd') > Trunc(xFEmisionDisco,'dd')
				OR Trunc(FECHA_DE_BAJA,'dd') > Trunc(xFEmisionDisco,'dd') );
				
    IF xIngresoTotal is null then
       xIngresoTotal:=0;
    END IF;

	-- Actualizamos el SALDO de la cuenta con el total de los ingresos
	UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xIngresoTotal WHERE ID=xIDCuenta
	RETURN SALDO INTO xSaldoActual;

	--Actualizamos en IMPORTE el importe total de los domiciliados
	--y en RECIBOS el importe total de los domiciliados menos los que se han ingresado
	--por ventanilla o ventanilla banco (que son la suma de los ingresos indebidos)
	UPDATE MOV_CUENTAS SET
				IMPORTE=xIngresoTotal,
				RECIBOS=xIngresoTotal-xSumaIngIndebidos,
				SALDO=xSaldoActual
	WHERE ID=xIDMov_cuentas;
*/
END;
/

/*************************************************************************************/
/* desde el zoom de un valor se pueden cambiar los datos de la domiciliacion bancaria 
MODIFICACIÓN: 31/01/2005 Lucas Fernandez Pérez. Se añade el parámetro xMotivoCambioDomi.
		  Se eliminan los campos USR_CHG__CUENTA y F_CHG__CUENTA.
		  La información del cambio (y su motivo) se almacenará ahora en la tabla HISTO_DOMICILIACIONES.
*/
CREATE OR REPLACE PROCEDURE ADD_MODI_DOMICILIACION (
			xPROGRAMA		  IN	CHAR,
			xID			      IN	INTEGER,
			xDOMICILIADO	  IN	CHAR,
			xDNI_TITULAR	  IN	CHAR,
			xENTIDAD		  IN	CHAR,
			xSUCURSAL		  IN	CHAR,
			xDC			      IN	CHAR,
			xCUENTA		      IN	CHAR,
			xF_DOMICILIACION  IN    DATE,
	        xMotivoCambioDomi IN  VARCHAR2)
AS
BEGIN

	-- Se pone el posible motivo del cambio en la domiciliación en USUARIOSGT (campo TEXTO2).
    UPDATE USUARIOSGT SET TEXTO2=xMotivoCambioDomi WHERE USUARIO=USER;

    if (xPROGRAMA='AGUA') then

      if (xDOMICILIADO='S') then
         update agua set domiciliado='S',
				 dni_titular=xDNI_TITULAR,
				 entidad=xENTIDAD,
				 sucursal=xSUCURSAL,
				 dc=xDC,
				 cuenta=xCUENTA,
				 f_domiciliacion=xF_DOMICILIACION
	   where id=xID;
      else
         update agua set domiciliado='N'
	   where id=xID;
	end if;

   elsif (xPROGRAMA='EXACCIONES') then

      if (xDOMICILIADO='S') then
         update exacciones set domiciliado='S',
				 dni_titular=xDNI_TITULAR,
				 entidad=xENTIDAD,
				 sucursal=xSUCURSAL,
				 dc=xDC,
				 cuenta=xCUENTA,
				 f_domiciliacion=xF_DOMICILIACION
	   where abonado=xID;
      else
         update exacciones set domiciliado='N'
	   where abonado=xID;
	end if;

   elsif (xPROGRAMA='IAE') then

      if (xDOMICILIADO='S') then
         update iae set domiciliado='S',
				 dni_factura=xDNI_TITULAR,
				 entidad=xENTIDAD,
				 sucursal=xSUCURSAL,
				 dc=xDC,
				 cuenta=xCUENTA,
				 f_domiciliacion=xF_DOMICILIACION
	   where id=xID;
      else
         update iae set domiciliado='N'
	   where id=xID;
	end if;

   elsif (xPROGRAMA='IBI') then

      if (xDOMICILIADO='S') then
         update ibi set domiciliado='S',
				 dni_factura=xDNI_TITULAR,
				 entidad=xENTIDAD,
				 sucursal=xSUCURSAL,
				 dc=xDC,
				 cuenta=xCUENTA,
				 f_domiciliacion=xF_DOMICILIACION
	   where id=xID;
      else
         update ibi set domiciliado='N'
	   where id=xID;
	end if;

   elsif (xPROGRAMA='RUSTICA') then

      if (xDOMICILIADO='S') then
         update rus80 set domiciliado='S',
				 dni_factura=xDNI_TITULAR,
				 entidad=xENTIDAD,
				 sucursal=xSUCURSAL,
				 dc=xDC,
				 cuenta=xCUENTA,
				 f_domiciliacion=xF_DOMICILIACION
	   where id=xID;
      else
         update rus80 set domiciliado='N'
	   where id=xID;
	end if;

   elsif (xPROGRAMA='VEHICULOS') then

      if (xDOMICILIADO='S') then
         update vehiculos set domiciliado='S',
				 titular=xDNI_TITULAR,
				 entidad=xENTIDAD,
				 sucursal=xSUCURSAL,
				 dc=xDC,
				 cuenta=xCUENTA,
				 f_domiciliacion=xF_DOMICILIACION
	   where abonado=xID;
      else
         update vehiculos set domiciliado='N'
	   where abonado=xID;
	end if;

   end if;

END;
/

-- ************************************************************************************
-- A PARTIR DE AQUI INGRESOS POR CUADERNO 60 */
-- ************************************************************************************

-- **************************************************************************************
-- Acción: Dar por ingresados los recibos en voluntaria que se cobran
--         en la ventanilla del banco a traves del cuaderno  60
-- MODIFICACIÓN: 27/09/2002 Mª Carmen Junco Gómez. Se incorpora el concepto de emisora
-- 	  global.
-- MODIFICACIÓN: 18/11/2002 M. Carmen Junco Gómez. Si el recibo viene cobrado en voluntaria
-- 	  y está en ejecutiva en la aplicación, quitar el recargo y pasar de nuevo el valor
-- 	  a voluntaria para aplicar el pago del banco.
-- MODIFICACIÓN: 23/01/2003 Mª del Carmen Junco Gómez. Se incorpora el campo MODALIDAD en 
-- 	  la tabla INCIDENCIAS_C60.
-- MODIFICACIÓN: 27/01/2003. Mª del Carmen Junco Gómez. En el histórico de soportes, el
-- 			  campo aplicado tendrá ahora tres posibles valores:
-- 			  		'N' no se ha aplicado nada. Sólo se ha leído el disco
-- 			  		'P' disco parcialmente aplicado
-- 			  		'S' disco completamente aplicado
-- MODIFICACIÓN: 29/01/2003. Se va a indicar en el desglose del histórico del soporte
-- 			  que se ha aplicado el cobro para los parámetros de entrada.
-- MODIFICACIÓN: 14/04/2003. M. Carmen Junco Gómez. Si el ingreso se hizo en voluntaria y
-- 			  el valor está en ejecutiva, hay que anular las costas.
-- MODIFICACIÓN: 21/05/2003 M. Carmen Junco Gómez. Al comprobar si existe el valor se añade
-- 			  a la consulta que el tipo de objeto='R', ya que puede existir una 
-- 			  liquidación con el mismo número de recibo.
-- MODIFICACIÓN: 03/06/2003 M. Carmen Junco Gómez. Si el recibo estaba ya ingresado no
-- 			  se hacía un insert en ingresos_indebidos.
-- Modificación: 30/06/2003. Agustín León Robles. Aunque el recibo estuviera anulado o 
--				ingresado o no se encontrara en los recibos de la base de datos tiene 
-- 				que hacer el apunte en las cuentas corrientes.
-- Modificado: 24/10/2003.Lucas Fernández Pérez. Inserta en ingresosindebidos los nuevos
--		campos fecha,f_cobro_banco,entidad_cobro,oficina_cobro. 
--		Se reajusta el movimiento de cuentas. Si el disco no tenía ningún ingreso aplicable,
--		no metía nada en el movimiento de cuentas.
--		Se reajusta el campo xTotal, que sumaba cuando no se ingresaba si no coincidian los
--		importes, indicando un ingreso en la aplicación que no era real.
--		Si se genera ingreso indebido, en la tabla de incidencias_c60 se apunta al mismo.
-- Modificado: 29/10/2003.Lucas Fernández Pérez. Para el mov.cuentas, pone la fecha de 
--		ingreso en aplicación a la que el usuario indica en delphi (antes ponia sysdate),
-- 		y la f.ingreso en banco la recoge de histo_soportes, el campo fecha_soporte, que 
-- 		indica la fecha en la que se cargan en el banco todos esos ingresos.
--		Se rellena el campo IDMovcuentas de la tabla de Ingresos Indebidos
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Todos los ingresos indebidos que se 
--	generen en una aplicación de un disco tendrán la misma fecha de ingreso en banco, así
--	como la misma entidad y oficina de cobro. En incidenciasr e incidencias_c60 ya sí se
--	indicará la fecha de ingreso, entidad y oficina real de cada uno de los recibos
-- Delphi
-- *************************************************************************************

CREATE OR REPLACE PROCEDURE PAGAR_BANCOS_VENTANILLA(
			xMUNICIPIO  IN CHAR,
	 		xPADRON 	IN CHAR,
			xYEAR		IN CHAR,
			xPERIODO 	IN CHAR,
			xFecha	IN DATE,
			xIDCUENTA   IN INTEGER,
			xCuantos    OUT INTEGER,
			xTotal 	OUT FLOAT,
			xPagados    OUT INTEGER,
			xBajas      OUT INTEGER,
			xNE         OUT INTEGER,
			xCobrado    OUT FLOAT,
			zEje 		OUT INTEGER,
			zEjeVol 	OUT INTEGER,
			zVol 		OUT INTEGER,
			zVolEje 	OUT INTEGER)

AS

xPRINCIPAL_va	FLOAT;
xRECARGO_va		FLOAT;
xCOSTAS_va		FLOAT;
xCodOpe		integer;
xIDMovCuentas	INTEGER;
xESTADO 		char(2);
xVOL_EJE 		char(1);
xF_Ingreso 		date;
xF_Baja 		date;
xIngEje		char(1);
SiInserto		char(1);
xValor		integer;
xSaldoActual      FLOAT DEFAULT 0;
mCanalIngreso	char(2);
xPendiente 		FLOAT;
xCuantosPendi	INTEGER;
xHayIngresos	INTEGER;
xIDHISTO		INTEGER;
xZONA			CHAR(2);
xIDIngresosIndebidos INTEGER;
xAsociaInci_C60 INTEGER;
xFechaSoporte	DATE;
xEntPresen		CHAR(4);
xOfiPresen		CHAR(4);

CURSOR CRECIBOS IS SELECT *
    FROM COBROS_BANCOS_VENTANILLA
	WHERE USUARIO=UID
	AND MUNICIPIO=xMUNICIPIO
	AND PADRON=xPADRON
	AND YEAR=xYEAR
	AND PERIODO=xPERIODO
	AND RTRIM(MODALIDAD)='MOD1'
	AND ESTADO IS NULL
	for update of estado;

BEGIN

	xPRINCIPAL_va:=0;
	xRECARGO_va:=0;
	xCOSTAS_va:=0;
	xCuantos:=0;
	zEje:=0;
	zEjeVol:=0;
	zVol:=0;
	zVolEje:=0;
	xPagados:=0;
	xBajas:=0;
	xTotal:=0;
	xCobrado:=0;
	xNE:=0;
   
	SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

	CODIGO_OPERACION(xCodOpe);
   
	SELECT DISTINCT ID_HISTO_SOPORTES INTO xIDHISTO FROM COBROS_BANCOS_VENTANILLA
	WHERE USUARIO=UID AND
		MUNICIPIO=xMUNICIPIO AND
		PADRON=xPADRON AND
		YEAR=xYEAR AND
		PERIODO=xPERIODO AND
		RTRIM(MODALIDAD)='MOD1';

    -- Movimiento de cuentas. Se inserta aquí porque el triger rellena la tabla usuarios y
    -- hace que los ingresos apunten	a este movimiento de cuentas.
    -- Se lee fecha_soporte (el campo es un char de tipo 110803, se pasa a 11/08/2003)
	SELECT to_date(substr(FECHA_SOPORTE,1,2)||'/'||substr(FECHA_SOPORTE,3,2)||'/'
	  			||substr(FECHA_SOPORTE,5,2),'dd/mm/yy'),ENT_PRESENTADORA,OFI_PRESENTADORA
	into xFechaSoporte,xEntPresen,xOfiPresen
  	FROM HISTO_SOPORTES WHERE ID=xIDHisto;
    
  	INSERT INTO MOV_CUENTAS(
		CUENTA,TEXTO,TIPO_INGRESO,ORIGEN,OPERACION,FECHA,F_INGRESO)
	VALUES(xIDCuenta,'PAGO BANCO VENTANILLA','VB',xIDCuenta,'H',xFecha,xFechaSoporte)
	RETURN ID INTO xIDMovCuentas;

	FOR v_Recibos IN CRECIBOS
	LOOP

		--Tendra los siguientes valores:
		--	'1': Pago en ventanilla o mediante adeudo en cuenta personal
		--	'2': Pago en autoservicio (cajeros automaticos y similares)
		--	'3': Pago efectuado por Banca Virtual
		if (v_Recibos.MEDIO_PAGO='1') or (v_Recibos.MEDIO_PAGO=' ') then
			mCanalIngreso:='PB';
		elsif v_Recibos.MEDIO_PAGO='2' then
			mCanalIngreso:='PA';
		else
			mCanalIngreso:='PI';
		end if;


		xPRINCIPAL_va:=NULL;
		xESTADO:=NULL;
		xIngEje:='N';
		SiInserto:='N';

		--buscamos el importe del valor
		begin
			IF xMUNICIPIO='XXX' THEN
				SELECT ID,PRINCIPAL,RECARGO,COSTAS,VOL_EJE,F_INGRESO,FECHA_DE_BAJA
					INTO xVALOR,xPRINCIPAL_va,xRECARGO_va,xCOSTAS_va,xVol_Eje,xF_Ingreso,xF_Baja
				FROM VALORES
				WHERE PADRON=xPADRON
				AND YEAR=xYEAR
				AND PERIODO=xPERIODO
				AND RECIBO=v_recibos.RECIBO
				AND TIPO_DE_OBJETO='R';
			ELSE
				SELECT ID,PRINCIPAL,RECARGO,COSTAS,VOL_EJE,F_INGRESO,FECHA_DE_BAJA
					INTO xVALOR,xPRINCIPAL_va,xRECARGO_va,xCOSTAS_va,xVol_Eje,xF_Ingreso,xF_Baja
				FROM VALORES
				WHERE AYTO=xMUNICIPIO
				AND PADRON=xPADRON
				AND YEAR=xYEAR
				AND PERIODO=xPERIODO
				AND RECIBO=v_recibos.RECIBO
				AND TIPO_DE_OBJETO='R';
			END IF;
		Exception
			When no_data_found then
				xPRINCIPAL_va:=Null;
		end;

		--el recibo no existe
		IF (xPRINCIPAL_va IS NULL) then
			xEstado:='NE'; --recibo no encontrado
			xNE:=xNE+1;
			SiInserto:='N';
		ELSE
			--Se trata de un ingreso en ejecutiva
			if xPRINCIPAL_va < v_recibos.Importe then
				xIngEje:='S';
			end if;

			if (xF_Ingreso is not null) then	--recibo cobrado
				xPagados:=xPagados+1;
				xEstado:='CO';
			else
				if (xF_Baja is not null) then	--recibo anulado
					xBajas:=xBajas+1;
					xEstado:='BA';
				else
					if (xVol_Eje ='E') then
						if (xIngEje='S') then
							SiInserto:='S';
							xEstado:='EE'; --recibo en ejecutiva e ingreso en ejecutiva
							zEje:=zEje+1;
						else
							--recibo en ejecutiva e ingreso en voluntaria
							--pasamos el valor a voluntaria para grabar el cobro del banco.
							--sólo se hará si no se ha ingresado nada en ejecutiva
							SELECT count(*) INTO xHayIngresos FROM INGRESOS
							WHERE VALOR=xVALOR AND RECARGO>0;

							IF xHayIngresos > 0 then
								SiInserto:='N';
								xEstado:='EV';
								zEjeVol:=zEjeVol+1;
							ELSE
								-- si tiene costas habrá que reajustarlas
								IF xCOSTAS_va > 0 THEN
									INSERT INTO COSTAS_VALORES
									(VALOR,Concepto,Importe,FECHA,codigo_operacion)
									VALUES (xValor,'AJUSTE DE COSTAS',-xCOSTAS_va,SYSDATE,0);
								END IF;  

								UPDATE VALORES SET RECARGO=0,COSTAS=0,VOL_EJE='V',F_APREMIO=NULL,
											DEMORA_PENDIENTE=0
								WHERE ID=xVALOR;

								xVol_Eje:='V';
								xRECARGO_va:=0;
								xCOSTAS_vA:=0;
								SiInserto:='S';
								xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
								zVol:=zVol+1;
							END IF; --del IF xHayIngresos>0 
						end if; --del (xIngEje='S') 
					else
						if (xIngEje='S') then
							SiInserto:='N';
							xEstado:='VE'; --recibo en voluntaria e ingreso en ejecutiva
							zVolEje:=zVolEje+1;
						else
							SiInserto:='S';
							xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
							zVol:=zVol+1;
						end if;
					end if; --del if (xVol_Eje ='E')
				end if; --del if (xF_Baja is not null)
			end if; --del if (xF_Ingreso is not null)

		END IF; -- del IF (xPRINCIPAL_va IS NULL)


		--esta variable contiene el importe ingresado en el banco
		xCobrado:= xCobrado + v_Recibos.IMPORTE;

		--realizar el ingreso
		if (SiInserto='S') then

			IF v_recibos.IMPORTE=xPRINCIPAL_va+xRECARGO_va+xCOSTAS_va THEN

				--esta variable contiene lo que realmente se ingresa en la aplicacion
				xTotal:= xTotal + xPRINCIPAL_va + xRECARGO_va + xCOSTAS_va;

				xCuantos:=xCuantos+1;

				PkIngresos.WRITE_INGRESO(xVALOR,'INGRESADO EN LA VENTANILLA DEL BANCO',
						'VB',xFECHA,xPrincipal_va,xRecargo_va,xCOSTAS_va,0,xCodOpe,'C',
						v_recibos.F_COBRO,v_recibos.ENTIDAD_RECEP,v_recibos.OFICINA_RECEP,
						mCanalIngreso,'0');

			ELSE -- No se inserta por no coincidir los importes

				SiInserto:='N';

			END IF;

		end if; -- del if SiInserto='S'


		UPDATE COBROS_BANCOS_VENTANILLA SET ESTADO=xESTADO
		WHERE current of cRecibos;

		IF SiInserto='N' THEN
			-- En PENDIENTE ponemos el principal+recargo del valor para compararlo con el 
			-- IMPORTE del banco.
			if ((xEstado='NE') or (xEstado='CO') or (xEstado='BA') ) then
				xPendiente:=0;
			else
				xPendiente:=xPRINCIPAL_va+xRECARGO_va;
			end if;

			xAsociaInci_C60:=0;

			-- si no se inserta debido a que ya estaba Cobrado o Anulado, tendremos que hacer un
			-- insert en ingresos_indebidos
			IF xEstado in ('CO','BA') THEN				
			
				xAsociaInci_C60:=1; -- Así, en incidencias_c60 se apuntará al ing_ind.
		
				--Solo para la primera vez
				IF xIDIngresosIndebidos IS NULL THEN
					INSERT INTO INGRESOS_INDEBIDOS(CODIGO_OPERACION,IMPORTE,ZONA,C60MOD1,
						FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO,IDMOVCUENTAS)
					VALUES (xCodOpe,v_Recibos.IMPORTE,xZONA,'S',xFecha, 
						xFechaSoporte,xEntPresen,xOfiPresen,xIDMovCuentas)
					RETURN ID INTO xIDIngresosIndebidos;			
				ELSE		   
					UPDATE INGRESOS_INDEBIDOS SET IMPORTE=IMPORTE+v_Recibos.IMPORTE
					WHERE ID=xIDIngresosIndebidos;
				END IF;

				--Insertamos el detalle de que recibos comprende
				INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,
						F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO)
				VALUES (xIDIngresosIndebidos,xVALOR,v_Recibos.IMPORTE,'S',v_Recibos.F_COBRO, 
						v_Recibos.ENTIDAD_RECEP,v_Recibos.OFICINA_RECEP);				
			END IF;

			INSERT INTO INCIDENCIAS_C60 (
				MUNICIPIO, PADRON, YEAR, PERIODO, RECIBO, EMISOR,
				ENTIDAD_RECEP, OFICINA_RECEP, F_COBRO, IMPORTE, PENDIENTE, MEDIO_PAGO, DOMICILIADO,
				ENTIDAD, OFICINA, DC, CUENTA, ESTADO, CODIGO_TRIBUTO, EJERCICIO, REMESA, DIGITO_YEAR,
				F_JULIANA, DISCRI_PERIODO, ID_HISTO_SOPORTES,MODALIDAD,ID_ING_INDE)
			VALUES(
				v_Recibos.MUNICIPIO, v_Recibos.PADRON, v_Recibos.YEAR, v_Recibos.PERIODO,
				v_Recibos.RECIBO, v_Recibos.EMISOR,	v_Recibos.ENTIDAD_RECEP,
				v_Recibos.OFICINA_RECEP, v_Recibos.F_COBRO, v_Recibos.IMPORTE, xPendiente,
				v_Recibos.MEDIO_PAGO, v_Recibos.DOMICILIADO, v_Recibos.ENTIDAD, v_Recibos.OFICINA,
				v_Recibos.DC, v_Recibos.CUENTA, xESTADO, v_Recibos.CODIGO_TRIBUTO,
				v_Recibos.EJERCICIO, v_Recibos.REMESA, v_Recibos.DIGITO_YEAR,
				v_Recibos.F_JULIANA, v_Recibos.DISCRI_PERIODO, v_Recibos.ID_HISTO_SOPORTES,
				'MOD1',DECODE(xAsociaInci_C60,1,xIDIngresosIndebidos,null));
			
		END IF;

	END LOOP;

	-- Actualizamos el SALDO de la cuenta con el total de los ingresos
	UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xCobrado WHERE ID=xIDCuenta
	RETURN SALDO INTO xSaldoActual;
	  
	-- Actualizamos IMPORTE, RECIBOS, SALDO del movimiento con lo Cobrado
	UPDATE MOV_CUENTAS SET IMPORTE=xCobrado,RECIBOS=xTotal,SALDO=xSaldoActual
	  WHERE ID=xIDMovCuentas;
    	
	-- Se busca si todos los municipio-padron-año-periodo del soporte se han tratado
	SELECT COUNT(*) INTO xCuantosPendi FROM COBROS_BANCOS_VENTANILLA WHERE USUARIO=UID AND ESTADO IS NULL;

	-- Indicamos en el histo_soportes que ya se ha aplicado la lectura de un ayto-padron-año-period.
	UPDATE HISTO_SOPORTES SET
		APLICADO=DECODE(xCuantosPendi,0,'S','P'),
		ID_CUENTA_INGRESO= xIDCuenta , FECHA_INGRESO_APLICACION=xFecha,
		COBRADO_BANCO=COBRADO_BANCO+xCobrado, TOTAL_VALORES=TOTAL_VALORES+xTotal
	WHERE ID = xIDHISTO;
			
	-- Indicamos en el desglose del histórico del soporte que se ha aplicado el cobro
	UPDATE DESGLOSE_HISTO_SOPORTES SET APLICADO='S'
	WHERE ID_HISTO_SOPORTES=xIDHISTO AND MUNICIPIO=xMUNICIPIO AND
	PADRON=xPADRON AND YEAR=xYEAR AND PERIODO=xPERIODO AND RTRIM(MODALIDAD)='MOD1';   

END;
/



/*************************************************************************************
Acción: Dar por ingresadas las liquidaciones en voluntaria que se cobran
        en la ventanilla del banco a traves del cuaderno 60 modalidad 2
Autor:  08/10/2002 Mª Carmen Junco Gómez.
MODIFICACIÓN: 16/12/2002 Mª Carmen Junco Gómez. Si el valor se ha pasado a
	  		  ejecutiva pero el ingreso se hizo dentor del plazo (f_juliana>=f_cobro en
	  		  banco), pasamos el valor a voluntaria y aplicamos el cobro.
MODIFICACIÓN: 21/01/2003. Mª del Carmen Junco Gómez. Se añade a la tabla 
			  COBROS_BANCOS_VENTANILLA un campo que diferencia si se han leído 
			  liquidaciones o cartas de pago. Debemos filtrar ahora por 
			  este nuevo campo, ya que en el mismo disco pueden venir liquidaciones
			  y cartas de pago.
MODIFICACIÓN: 23/01/2003. Mª del Carmen Junco Gómez. Se incluye el campo MODALIDAD
			  en la tabla INCIDENCIAS_C60.
MODIFICACIÓN: 27/01/2003. Mª del Carmen Junco Gómez. En el histórico de soportes, el
			  campo aplicado tendrá ahora tres posibles valores:
			  		'N' no se ha aplicado nada. Sólo se ha leído el disco
			  		'P' disco parcialmente aplicado
			  		'S' disco completamente aplicado	
MODIFICACIÓN: 29/01/2003. Mª del Carmen Junco Gómez. Vamos a añadir tres parámetros más
			  para identificar las liquidaciones que queremos cobrar, ya que ahora se
			  desglosan por municipio, concepto y año. Además vamos a indicar en la
			  tabla DESGLOSE_HISTO_SOPORTES que este cobro ha sido aplicado.
MODIFICACIÓN: 04/06/2003. Mª del Carmen Junco Gómez. Si la liquidación ya estaba ingresada
			  no se estaba insertando en la tabla de ingresos_indebidos.
Modificación: 30/06/2003. Agustín León Robles. Aunque las liquidaciones estuvieran anuladas o ingresadas o no se 
				encontraran en la base de datos tiene que hacer el apunte en las cuentas corrientes.
Modificación: 21/10/2003. Lucas Fernández Pérez. Si no se inserta debido a que ya estaba
							Anulado, hace un insert en ingresos_indebidos
*************************************************************************************/
-- Modificación: 24/10/2003.Lucas Fernández Pérez. Inserta en ingresosindebidos los nuevos
-- 							campos fecha,f_cobro_banco,entidad_cobro,oficina_cobro.
-- 				Se reajusta el movimiento de cuentas. Si el disco no tenía ningún ingreso
-- 				 aplicable, no metía nada en el movimiento de cuentas.
--		Se reajusta el campo xTotal, que sumaba cuando no se ingresaba si no coincidian los
--		importes, indicando un ingreso en la aplicación que no era real.
--		Si se genera ingreso indebido, en la tabla de incidencias_c60 se apunta al mismo.
--		Se graba en el historico de soportes lo ingresado en banco y en la aplicación
-- Modificado: 29/10/2003.Lucas Fernández Pérez. Para el mov.cuentas, pone la fecha de 
--		ingreso en aplicación a la que el usuario indica en delphi (antes ponia sysdate),
-- 		y la f.ingreso en banco la recoge de histo_soportes, el campo fecha_soporte, que 
-- 		indica la fecha en la que se cargan en el banco todos esos ingresos.
--		Se rellena el campo IDMovcuentas de la tabla de Ingresos Indebidos
-- Modificado: 12/12/2003. Lucas Fernández Pérez. Todos los ingresos indebidos que se 
--	generen en una aplicación de un disco tendrán la misma fecha de ingreso en banco, así
--	como la misma entidad y oficina de cobro. En incidenciasr e incidencias_c60 ya sí se
--	indicará la fecha de ingreso, entidad y oficina real de cada una de las liquidaciones
--

CREATE OR REPLACE PROCEDURE PAGAR_VB_VOL_MOD2(
			xFecha	IN DATE,
			xIDCUENTA   IN INTEGER,
			xMUNICIPIO	IN	CHAR,
			xPADRON		IN	CHAR,
			xYEAR		IN	CHAR,
			xCuantos    OUT INTEGER,
			xTotal 	OUT FLOAT,
			xPagados    OUT INTEGER,
			xBajas      OUT INTEGER,
			xNE         OUT INTEGER,
			xCobrado    OUT FLOAT,
			zEje 		OUT INTEGER,
			zEjeVol 	OUT INTEGER,
			zVol 		OUT INTEGER,
			zVolEje 	OUT INTEGER)

AS

	xPRINCIPAL_va	FLOAT;
	xRECARGO_va		FLOAT;
	xCodOpe		integer;
    xIDMovCuentas	INTEGER;
	xESTADO 		char(2);
	xVOL_EJE 		char(1);
	xF_Ingreso 		date;
	xF_Baja 		date;
	xIngEje		char(1);
	SiInserto		char(1);
	xValor		integer;
	xSaldoActual      FLOAT DEFAULT 0;
	mCanalIngreso	char(2);
	xPendiente 		FLOAT;
	xCuantosPendi	INTEGER;
	xIDValor		INTEGER;
	xFIN_PE_VOL 	DATE;
	xIDHISTO		INTEGER;
	xZona			CHAR(2);
	xIDIngresosIndebidos INTEGER;
	xAsociaInci_C60 INTEGER;
	xFechaSoporte 	DATE;
	xEntPresen		CHAR(4);
	xOfiPresen		CHAR(4);

CURSOR CLIQUI IS SELECT * 
    FROM COBROS_BANCOS_VENTANILLA
	WHERE USUARIO=UID AND MUNICIPIO=xMUNICIPIO AND
		  PADRON=xPADRON AND YEAR=xYEAR AND 
		  ESTADO IS NULL AND MODALIDAD='MOD2LI'
	for update of estado;

BEGIN

   xPRINCIPAL_va:=0;
   xRECARGO_va:=0;
   xCuantos:=0;
   zEje:=0;
   zEjeVol:=0;
   zVol:=0;
   zVolEje:=0;
   xPagados:=0;
   xBajas:=0;
   xTotal:=0;
   xCobrado:=0;
   xNE:=0;
   
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   CODIGO_OPERACION(xCodOpe);
   
   SELECT DISTINCT ID_HISTO_SOPORTES INTO xIDHISTO FROM COBROS_BANCOS_VENTANILLA
   WHERE USUARIO=UID AND MUNICIPIO=xMUNICIPIO AND PADRON=xPADRON AND 
         YEAR=xYEAR AND MODALIDAD='MOD2LI';

   -- Movimiento de cuentas. Se inserta aquí porque el triger rellena la tabla usuarios y
   -- hace que los ingresos apunten	a este movimiento de cuentas.
   -- Se lee fecha_soporte (el campo es un char de tipo 110803, se pasa a 11/08/2003)
   SELECT to_date(substr(FECHA_SOPORTE,1,2)||'/'||substr(FECHA_SOPORTE,3,2)||'/'
	  			||substr(FECHA_SOPORTE,5,2),'dd/mm/yy'),ENT_PRESENTADORA,OFI_PRESENTADORA
	  		 into xFechaSoporte,xEntPresen, xOfiPresen
   FROM HISTO_SOPORTES WHERE ID=xIDHisto;
    
   INSERT INTO MOV_CUENTAS(
		CUENTA,TEXTO,TIPO_INGRESO,ORIGEN,OPERACION,FECHA,F_INGRESO)
   VALUES(xIDCuenta,'PAGO BANCO VENTANILLA','VB',xIDCuenta,'H',xFecha,xFechaSoporte)
   RETURN ID INTO xIDMovCuentas;

   FOR v_Liqui IN CLIQUI
   LOOP

	--Tendra los siguientes valores:
	--	'1': Pago en ventanilla o mediante adeudo en cuenta personal
	--	'2': Pago en autoservicio (cajeros automaticos y similares)
	--	'3': Pago efectuado por Banca Virtual
	if (v_Liqui.MEDIO_PAGO='1') or (v_Liqui.MEDIO_PAGO=' ') then
		mCanalIngreso:='PB';
	elsif v_Liqui.MEDIO_PAGO='2' then
		mCanalIngreso:='PA';
	else
		mCanalIngreso:='PI';
	end if;


      xPRINCIPAL_va:=NULL;
	xESTADO:=NULL;
	xIngEje:='N';
	SiInserto:='N';

	-- recogemos el id del valor y la fecha de final del periodo voluntario que la
	-- liquidación tenía en el momento de emitir el documento de pago
	begin	
	   SELECT IDVALOR,TO_DATE(F_JULIANA,'DDD') INTO xIDVALOR,xFIN_PE_VOL
	   FROM LIQUIDACIONES WHERE ID=v_Liqui.RECIBO;
	   Exception
	      When no_data_found then
	         xIDVALOR:=0;
	end;

	--buscamos el importe del valor
      begin
	   SELECT ID,PRINCIPAL,RECARGO,VOL_EJE,F_INGRESO,FECHA_DE_BAJA
	   INTO xVALOR,xPRINCIPAL_va,xRECARGO_va,xVol_Eje,xF_Ingreso,xF_Baja
	   FROM VALORES
	   WHERE ID=xIDVALOR;
      Exception
	      When no_data_found then
		   xPRINCIPAL_va:=Null;
	end;

	--el recibo no existe
	IF (xPRINCIPAL_va IS NULL) then
	   xEstado:='NE'; --recibo no encontrado
	   xNE:=xNE+1;
	   SiInserto:='N';
	ELSE
	   --Se trata de un ingreso en ejecutiva
	   if xPRINCIPAL_va<v_Liqui.Importe then
		xIngEje:='S';
	   end if;

	   if (xF_Ingreso is not null) then	--recibo cobrado
	      xPagados:=xPagados+1;
		xEstado:='CO';
	   else
	     if (xF_Baja is not null) then	--recibo anulado
		  xBajas:=xBajas+1;
		  xEstado:='BA';
	     else
	        if (xVol_Eje ='E') then
		     if (xIngEje='S') then
			   SiInserto:='S';
			   xEstado:='EE'; --recibo en ejecutiva e ingreso en ejecutiva
			   zEje:=zEje+1;
		     else
			   --recibo en ejecutiva e ingreso en voluntaria
			   --debemos comprobar si el ingreso en el banco no sobrepasó la fecha
			   --límite dada por la fecha de final del periodo voluntario que la
			   --liquidación poseía en el momento de emitir el documento de pago.
			   --Si está dentro del plazo pasamos el valor a voluntaria y se aplica
			   --el cobro.
			   if xfin_pe_vol>=v_liqui.f_cobro then
			      UPDATE VALORES SET RECARGO=0,VOL_EJE='V',F_APREMIO=NULL,
			             DEMORA_PENDIENTE=0
				WHERE ID=xIDVALOR;
				xPRINCIPAL_va:=v_liqui.IMPORTE;
				xRECARGO_va:=0;
				xVol_Eje:='V';
				SiInserto:='S';
				xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
			   	zVol:=zVol+1;
			   else
			      SiInserto:='N';
			      xEstado:='EV';
			      zEjeVol:=zEjeVol+1;
    			   end if;
		     end if;
		  else
		     if (xIngEje='S') then
			   SiInserto:='N';
			   xEstado:='VE'; --recibo en voluntaria e ingreso en ejecutiva
			   zVolEje:=zVolEje+1;
		     else
			   SiInserto:='S';
			   xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
			   zVol:=zVol+1;
		     end if;
		   end if;
		end if;
	   end if;

	END IF; -- IF (xPRINCIPAL_va IS NULL) then

	--esta variable contiene el importe ingresado en el banco
      xCobrado:=xCobrado+v_Liqui.IMPORTE;

	--realizar el ingreso
	if (SiInserto='S') then

	   IF v_Liqui.IMPORTE=xPRINCIPAL_va+xRECARGO_va THEN

	      --esta variable contiene lo que realmente se ingresa en la aplicacion
	      xTotal:=xTotal+xPRINCIPAL_va+xRECARGO_va;
	      
		  xCuantos:=xCuantos+1;

	      PkIngresos.WRITE_INGRESO(xVALOR,'INGRESADO EN LA VENTANILLA DEL BANCO',
			 'VB',xFECHA,xPrincipal_va,xRecargo_va,0,0,xCodOpe,'C',
 			  v_Liqui.F_COBRO,v_Liqui.ENTIDAD_RECEP,v_Liqui.OFICINA_RECEP,
			 mCanalIngreso,'0');

	   ELSE -- No se inserta por no coincidir los importes

		  SiInserto:='N';

	   END IF;

	end if; -- del if SiInserto='S'


	UPDATE COBROS_BANCOS_VENTANILLA SET ESTADO=xESTADO
	WHERE current of cLiqui;

	IF SiInserto='N' THEN

	-- En PENDIENTE ponemos el principal+recargo del valor para compararlo
	-- con el IMPORTE del banco.
	   if ((xEstado='NE') or (xEstado='CO') or (xEstado='BA') ) then
		xPendiente:=0;
	   else
		xPendiente:=xPRINCIPAL_va+xRECARGO_va;
	   end if;
   
	    xAsociaInci_C60:=0;
	    
		-- si no se inserta debido a que ya estaba Cobrado o Anulado, tendremos que hacer un
		-- insert en ingresos_indebidos
		IF xEstado in ('CO','BA') THEN				
		
		  xAsociaInci_C60:=1; -- Así, en incidencias_c60 se apuntará al ing_ind.

	      --Solo para la primera vez
	      IF xIDIngresosIndebidos IS NULL THEN
	   	     INSERT INTO INGRESOS_INDEBIDOS
			    (CODIGO_OPERACION,IMPORTE,ZONA,C60LIQUIDACIONES,
			    	FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO,IDMOVCUENTAS)
			 VALUES (xCodOpe,v_Liqui.IMPORTE,xZONA,'S',xFecha,xFechaSoporte,
			 			xEntPresen,xOfiPresen,xIDMovCuentas)
			 RETURN ID INTO xIDIngresosIndebidos;			
		  ELSE		   
		     UPDATE INGRESOS_INDEBIDOS SET IMPORTE=IMPORTE+v_Liqui.IMPORTE
		     WHERE ID=xIDIngresosIndebidos;
		  END IF;

		  --Insertamos el detalle de que recibos comprende
		  INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO,
		  		    ENTIDAD_COBRO,OFICINA_COBRO)
		  VALUES (xIDIngresosIndebidos,xVALOR,v_Liqui.IMPORTE,'S',v_Liqui.F_COBRO,
			 		v_Liqui.ENTIDAD_RECEP,v_Liqui.OFICINA_RECEP);				
			
	   END IF;

	   INSERT INTO INCIDENCIAS_C60 (
		MUNICIPIO,PADRON,YEAR,RECIBO, EMISOR,
		ENTIDAD_RECEP, OFICINA_RECEP, F_COBRO, IMPORTE, PENDIENTE, MEDIO_PAGO,
		DOMICILIADO, ENTIDAD, OFICINA, DC, CUENTA, ESTADO, CODIGO_TRIBUTO, EJERCICIO,REMESA,
		DIGITO_YEAR, F_JULIANA, DISCRI_PERIODO, ID_HISTO_SOPORTES,MODALIDAD,ID_ING_INDE)
	   VALUES(
		xMUNICIPIO,xPADRON,xYEAR,v_Liqui.RECIBO, v_Liqui.EMISOR,v_Liqui.ENTIDAD_RECEP,
		v_Liqui.OFICINA_RECEP,v_Liqui.F_COBRO,v_Liqui.IMPORTE,xPendiente,
		v_Liqui.MEDIO_PAGO,v_Liqui.DOMICILIADO,v_Liqui.ENTIDAD,v_Liqui.OFICINA,
		v_Liqui.DC,v_Liqui.CUENTA,xESTADO,v_Liqui.CODIGO_TRIBUTO,
		v_Liqui.EJERCICIO,v_Liqui.REMESA,v_Liqui.DIGITO_YEAR,
		v_Liqui.F_JULIANA,v_Liqui.DISCRI_PERIODO,v_Liqui.ID_HISTO_SOPORTES,
		'MOD2LI',DECODE(xAsociaInci_C60,1,xIDIngresosIndebidos,null));

	END IF;

   END LOOP;

   -- Actualizamos el SALDO de la cuenta con el total de los ingresos
   UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xCobrado WHERE ID=xIDCuenta
   RETURN SALDO INTO xSaldoActual;

   -- Actualizamos IMPORTE, RECIBOS, SALDO del movimiento con lo Cobrado
   UPDATE MOV_CUENTAS SET IMPORTE=xCobrado,RECIBOS=xTotal,SALDO=xSaldoActual
   WHERE ID=xIDMovCuentas;

   -- Se busca si se ha aplicado ya todo el disco
   SELECT COUNT(*) INTO xCuantosPendi FROM COBROS_BANCOS_VENTANILLA
	WHERE USUARIO=UID AND ESTADO IS NULL;

   -- Indicamos en el histo_soportes que ya se ha aplicado, o no, todo el disco
   UPDATE HISTO_SOPORTES SET
  	APLICADO=DECODE(xCuantosPendi,0,'S','P'),
	ID_CUENTA_INGRESO= xIDCuenta , FECHA_INGRESO_APLICACION=xFecha	,
	COBRADO_BANCO=COBRADO_BANCO+xCobrado, TOTAL_VALORES=TOTAL_VALORES+xTotal
   WHERE ID = xIDHISTO;
   
   -- Indicamos en el desglose del histórico que se ha aplicado este cobro
   UPDATE DESGLOSE_HISTO_SOPORTES SET APLICADO='S' 
   WHERE ID_HISTO_SOPORTES=xIDHISTO AND MUNICIPIO=xMUNICIPIO AND
         PADRON=xPADRON AND YEAR=xYEAR AND MODALIDAD='MOD2LI';	

END;
/


-- *************************************************************************************
-- Acción: 	Dar por ingresadas las liquidaciones en voluntaria de MULTAS que se cobran				
--         	en la ventanilla del banco a traves del cuaderno 60 modalidad 2
-- Autor:  	17/03/2003 Mª Carmen Junco Gómez.
-- MODIFICACIÓN: 04/06/2003 Mª Del Carmen Junco Gómez. Si la multa ya estaba pagada no
--         	se estaba insertando en ingresos_indebidos.
-- MODIFICACIÓN: 30/06/2003. Agustín León Robles. Aunque las multas estuvieran anuladas 
--				o ingresadas o no se encontraran en la base de datos tiene que hacer el
--			 	apunte en las cuentas corrientes.
-- MODIFICACIÓN: 21/10/2003. Lucas Fernández Pérez. Si no se inserta debido a que ya estaba
-- 			Anulado, hace un insert en ingresos_indebidos
-- MODIFICACIÓN: 24/10/2003.Lucas Fernández Pérez. Inserta en ingresosindebidos los nuevos
-- 			campos fecha,f_cobro_banco,entidad_cobro,oficina_cobro.
--				Se reajusta el movimiento de cuentas. Si el disco no tenía ningún ingreso
--			 	aplicable, no metía nada en el movimiento de cuentas.
--				Se reajusta el campo xTotal, que sumaba cuando no se ingresaba si no coincidian
--			 	los importes, indicando un ingreso en la aplicación que no era real.
--				Si se genera ingreso indebido, en la tabla de incidencias_c60 se apunta al mismo.
--				Se graba en el historico de soportes lo ingresado en banco y en la aplicación
-- MODIFICACIÓN: 29/10/2003.Lucas Fernández Pérez. Para el mov.cuentas, pone la fecha de 
--				ingreso en aplicación a la que el usuario indica en delphi (antes ponia sysdate),
-- 			y la f.ingreso en banco la recoge de histo_soportes, el campo fecha_soporte, que 
-- 			indica la fecha en la que se cargan en el banco todos esos ingresos.
--				Se rellena el campo IDMovcuentas de la tabla de Ingresos Indebidos
-- MODIFICACIÓN: 12/12/2003. Lucas Fernández Pérez. Todos los ingresos indebidos que se 
--				generen en una aplicación de un disco tendrán la misma fecha de ingreso en banco, así
--				como la misma entidad y oficina de cobro. En incidenciasr e incidencias_c60 ya sí se
--				indicará la fecha de ingreso, entidad y oficina real de cada una de las liquidaciones
--	MODIFICACIÓN: 19/04/2005. Mª Del Carmen Junco Gómez. Se reestructuran las condiciones del 
--				procedimiento basándonos en los importes PRINCIPAL_va Y v_Multas.Importe.
--				Si el importe ingresado coincide con el importe bonificado, y el valor ya no tiene
--				dicha bonificación, se repondrá la bonificación para aplicar el ingreso.
-- ***************************************************************************************

CREATE OR REPLACE PROCEDURE PAGAR_MULTAS_VOL_MOD2(
			xFecha	IN DATE,
			xIDCUENTA   IN INTEGER,
			xMUNICIPIO	IN	CHAR,
			xPADRON		IN	CHAR,
			xYEAR		IN	CHAR,
			xCuantos    OUT INTEGER,
			xTotal 	OUT FLOAT,
			xPagados    OUT INTEGER,
			xBajas      OUT INTEGER,
			xNE         OUT INTEGER,
			xCobrado    OUT FLOAT,
			zEje 		OUT INTEGER,
			zEjeVol 	OUT INTEGER,
			zVol 		OUT INTEGER,
			zVolEje 	OUT INTEGER)

AS

	xPRINCIPAL_va	FLOAT;
	xRECARGO_va		FLOAT;
	xIMPORTE_BONIFICADO_va	FLOAT;
	xF_ANULACION_BONI_va		DATE;
	xCodOpe		integer;
   xIDMovCuentas	INTEGER;
	xESTADO 		char(2);
	xVOL_EJE 		char(1);
	xF_Ingreso 		date;
	xF_Baja 		date;
	xIngEje		char(1);
	SiInserto		char(1);
	xValor		integer;
	xSaldoActual      FLOAT DEFAULT 0;
	mCanalIngreso	char(2);
	xPendiente 		FLOAT;
	xCuantosPendi	INTEGER;
	xIDValor		INTEGER;
	xIDHISTO		INTEGER;
	xZona			CHAR(2);
	xIDIngresosIndebidos INTEGER;
	xAsociaInci_C60 INTEGER;
	xFechaSoporte 	DATE;
	xEntPresen		CHAR(4);
	xOfiPresen		CHAR(4);

CURSOR CMULTAS IS SELECT * FROM COBROS_BANCOS_VENTANILLA
				  WHERE USUARIO=UID AND MUNICIPIO=xMUNICIPIO AND
		  		  PADRON=xPADRON AND YEAR=xYEAR AND 
		  		  ESTADO IS NULL AND MODALIDAD='MOD2LI'
				  for update of estado;

BEGIN

   xPRINCIPAL_va:=0;
   xRECARGO_va:=0;
   xCuantos:=0;
   zEje:=0;
   zEjeVol:=0;
   zVol:=0;
   zVolEje:=0;
   xPagados:=0;
   xBajas:=0;
   xTotal:=0;
   xCobrado:=0;
   xNE:=0;
   
   SELECT ZONA INTO xZONA FROM USUARIOS WHERE USUARIO=USER;

   CODIGO_OPERACION(xCodOpe);
   
   SELECT DISTINCT ID_HISTO_SOPORTES INTO xIDHISTO FROM COBROS_BANCOS_VENTANILLA
   WHERE USUARIO=UID AND MUNICIPIO=xMUNICIPIO AND PADRON=xPADRON AND 
         YEAR=xYEAR AND MODALIDAD='MOD2LI';

   -- Movimiento de cuentas. Se inserta aquí porque el triger rellena la tabla usuarios y
   -- hace que los ingresos apunten	a este movimiento de cuentas.
   -- Se lee fecha_soporte (el campo es un char de tipo 110803, se pasa a 11/08/2003)
   SELECT to_date(substr(FECHA_SOPORTE,1,2)||'/'||substr(FECHA_SOPORTE,3,2)||'/'
	  			||substr(FECHA_SOPORTE,5,2),'dd/mm/yy'), ENT_PRESENTADORA, OFI_PRESENTADORA
	  			 into xFechaSoporte, xEntPresen, xOfiPresen
   FROM HISTO_SOPORTES WHERE ID=xIDHisto;
    
   INSERT INTO MOV_CUENTAS
   	(CUENTA,TEXTO,TIPO_INGRESO,ORIGEN,OPERACION,FECHA,F_INGRESO)
   VALUES(xIDCuenta,'PAGO BANCO VENTANILLA','VB',xIDCuenta,'H',xFecha,xFechaSoporte)
   RETURN ID INTO xIDMovCuentas;

   FOR v_Multas IN CMULTAS
   LOOP

		--Tendra los siguientes valores:
		--	'1': Pago en ventanilla o mediante adeudo en cuenta personal
		--	'2': Pago en autoservicio (cajeros automaticos y similares)
		--	'3': Pago efectuado por Banca Virtual
		if (v_Multas.MEDIO_PAGO='1') or (v_Multas.MEDIO_PAGO=' ') then
			mCanalIngreso:='PB';
		elsif v_Multas.MEDIO_PAGO='2' then
			mCanalIngreso:='PA';
		else
			mCanalIngreso:='PI';
		end if;


   	xPRINCIPAL_va:=NULL;
		xESTADO:=NULL;
		xIngEje:='N';
		SiInserto:='N';

		-- recogemos el id del valor de la tabla de multas
		begin	
	   	SELECT IDVALOR INTO xIDVALOR
	   	FROM MULTAS WHERE ID=v_Multas.RECIBO;
       	Exception
	      	When no_data_found then
	         	xIDVALOR:=0;
		end;

		--buscamos el importe del valor
    	begin
	   	SELECT ID,PRINCIPAL,RECARGO,VOL_EJE,F_INGRESO,FECHA_DE_BAJA,IMPORTE_BONIFICADO,F_ANULACION_BONI
	   	INTO xVALOR,xPRINCIPAL_va,xRECARGO_va,xVol_Eje,xF_Ingreso,xF_Baja,xIMPORTE_BONIFICADO_va,xF_ANULACION_BONI_va
	   	FROM VALORES
	   	WHERE ID=xIDVALOR;
       	Exception
	      	When no_data_found then
		   		xPRINCIPAL_va:=Null;
		end;

		--el recibo no existe
		IF (xPRINCIPAL_va IS NULL) THEN
	   	xEstado:='NE'; --recibo no encontrado
	   	xNE:=xNE+1;
	   	SiInserto:='N';
	   ELSE 
	   	IF (xF_Ingreso is not null) THEN	--recibo cobrado
	   		xEstado:='CO';
	   		xPagados:=xPagados+1;		   
		   	SiInserto:='N';
			ELSE 
				IF (xF_Baja is not null) THEN	--recibo anulado
					xEstado:='BA';
		   		xBajas:=xBajas+1;		  	
		  			SiInserto:='N';
				ELSE				
					IF (xPRINCIPAL_va<v_Multas.Importe) THEN
			
						xIngEje:='S';  --ingreso en ejecutiva
						IF (xVol_Eje='E') THEN
		   				SiInserto:='S';
			   			xEstado:='EE'; --recibo en ejecutiva e ingreso en ejecutiva
			   			zEje:=zEje+1;
		     			ELSE
		     				SiInserto:='N';
			   			xEstado:='VE'; --recibo en voluntaria e ingreso en ejecutiva
			   			zVolEje:=zVolEje+1;
			   		END IF;
			   
					ELSE 
						IF (xPRINCIPAL_va=v_Multas.Importe) THEN
			
							IF (xVol_Eje='E') THEN
								--recibo en ejecutiva e ingreso en voluntaria
			   				--Si el banco aceptó el pago es porque no se sobrepasó la fecha de vencimiento			   	
			   				--que la multa poseía en el momento de emitir el documento de pago.
			   				--Pasamos el valor a voluntaria y se aplica el cobro.	
			   				--Si estuviera emitida la notificación de la providencia, aunque se anule la
			   				--fecha de notificación y la costa en el valor, no se borra de  la tabla
			   				--COSTAS_VALORES y NOTIFICACIONES para mantener un rastro.		   	
			      			UPDATE VALORES SET RECARGO=0,
			      									 COSTAS=0,
			       									 VOL_EJE='V',
			       									 F_APREMIO=NULL,
			       									 RELACION_APREMIO=NULL,
			       									 ORDEN_APREMIO=NULL,
			       									 NOTIFICADO='N',
			       									 F_NOTIFICACION=NULL,
			       									 DEMORA_PENDIENTE=0
								WHERE ID=xIDVALOR;					
								xRECARGO_va:=0;
								xVol_Eje:='V';
								SiInserto:='S';
								xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
			   				zVol:=zVol+1;			   
			   			ELSE
			   				SiInserto:='S';
								xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
			   				zVol:=zVol+1;	
			   			END IF;			   		
			   					   					   
						ELSE 
							IF (xPRINCIPAL_va>v_Multas.Importe) THEN
	     	
								IF (xVol_Eje='E') THEN
									--recibo en ejecutiva e ingreso en voluntaria
			   					--Si el banco aceptó el pago es porque no se sobrepasó la fecha de vencimiento			   	
			   					--que la multa poseía en el momento de emitir el documento de pago.
			   					--Pasamos el valor a voluntaria.
			   					--Si estuviera emitida la notificación de la providencia, aunque se anule la
			   					--fecha de notificación y la costa en el valor, no se borra de  la tabla
			   					--COSTAS_VALORES y NOTIFICACIONES para mantener un rastro.		   	
			      				UPDATE VALORES SET RECARGO=0,
			      									 	 COSTAS=0,
			       									 	 VOL_EJE='V',
			       									 	 F_APREMIO=NULL,
			       									 	 RELACION_APREMIO=NULL,
			       									 	 ORDEN_APREMIO=NULL,
			       									 	 NOTIFICADO='N',
			       									 	 F_NOTIFICACION=NULL,
			       									 	 DEMORA_PENDIENTE=0
									WHERE ID=xIDVALOR;					
									xRECARGO_va:=0;
									xVol_Eje:='V';	
								END IF;
				
								-- si se ingresó el importe bonificado de la multa, y después se anuló la bonificación,
								-- la reponemos (la bonificación) y realizamos el ingreso
								IF (xIMPORTE_BONIFICADO_va=v_Multas.Importe) THEN
					
									UPDATE VALORES SET PRINCIPAL=IMPORTE_BONIFICADO,
															 F_ANULACION_BONI=NULL
									WHERE ID=xIDVALOR;
									xPRINCIPAL_va:=v_Multas.Importe;
									SiInserto:='S';
									xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
									zVol:=zVol+1;
								ELSE
		
									SiInserto:='N';  --No se inserta por no coincidir los importes
				
								END IF;
								
							END IF;
							
						END IF;
						
					END IF;	
					
				END IF;					

			END IF; 
			
		END IF; -- IF (xPRINCIPAL_va IS NULL) then
		

		--esta variable contiene el importe ingresado en el banco
      xCobrado:=xCobrado+v_Multas.IMPORTE;

		--realizar el ingreso
		IF (SiInserto='S') THEN

	   	IF v_Multas.IMPORTE=xPRINCIPAL_va+xRECARGO_va THEN

	      	--esta variable contiene lo que realmente se ingresa en la aplicacion
 	      	xTotal:=xTotal+xPRINCIPAL_va+xRECARGO_va;
 	      
		  		xCuantos:=xCuantos+1;

	      	PkIngresos.WRITE_INGRESO(xVALOR,'INGRESADO EN LA VENTANILLA DEL BANCO',
			 	'VB',xFECHA,xPrincipal_va,xRecargo_va,0,0,xCodOpe,'C',
 			  	v_Multas.F_COBRO,v_Multas.ENTIDAD_RECEP,v_Multas.OFICINA_RECEP,
			 	mCanalIngreso,'0');

	   	ELSE -- No se inserta por no coincidir los importes

		  		SiInserto:='N';

	   	END IF;

		END IF; -- del if SiInserto='S'


		UPDATE COBROS_BANCOS_VENTANILLA SET ESTADO=xESTADO
		WHERE current of cMultas;

		IF SiInserto='N' THEN

			-- En PENDIENTE ponemos el principal+recargo del valor para compararlo
			-- con el IMPORTE del banco.
	   	IF ((xEstado='NE') or (xEstado='CO') or (xEstado='BA') ) THEN
				xPendiente:=0;
	   	ELSE
				xPendiente:=xPRINCIPAL_va+xRECARGO_va;
	   	END IF;

	   	xAsociaInci_C60:=0;
	   	
			-- si no se inserta debido a que ya estaba Cobrado o Anulado, tendremos que hacer un
			-- insert en ingresos_indebidos
			IF xEstado in ('CO','BA') THEN				
		
		  		xAsociaInci_C60:=1; -- Así, en incidencias_c60 se apuntará al ing_ind.

	     		--Solo para la primera vez
	     		IF xIDIngresosIndebidos IS NULL THEN
	     		
	   	     	INSERT INTO INGRESOS_INDEBIDOS
			    		(CODIGO_OPERACION,IMPORTE,ZONA,C60LIQUIDACIONES,
			    		FECHA,F_COBRO_BANCO,ENTIDAD_COBRO,OFICINA_COBRO,IDMOVCUENTAS)
			 		VALUES (xCodOpe,v_Multas.IMPORTE,xZONA,'S', 
			 			xFecha,xFechaSoporte,xEntPresen,xOfiPresen,xIDMovCuentas)
			 		RETURN ID INTO xIDIngresosIndebidos;			
			 	
		  		ELSE		   
		  		
		     		UPDATE INGRESOS_INDEBIDOS SET IMPORTE=IMPORTE+v_Multas.IMPORTE
		     		WHERE ID=xIDIngresosIndebidos;
		     
		  		END IF;

		  		--Insertamos el detalle de que recibos comprende
		  		INSERT INTO INCIDENCIASR(ID_ING_INDE,VALOR,IMPORTE,INGRESADO_ANTES,F_COBRO_BANCO,
		  			ENTIDAD_COBRO,OFICINA_COBRO)
		  		VALUES (xIDIngresosIndebidos,xVALOR,v_Multas.IMPORTE,'S',v_Multas.F_COBRO,
			 		v_Multas.ENTIDAD_RECEP,v_Multas.OFICINA_RECEP);				
			
	   	END IF;
	   
	   	INSERT INTO INCIDENCIAS_C60 (
				MUNICIPIO,PADRON,YEAR,RECIBO, EMISOR,
				ENTIDAD_RECEP, OFICINA_RECEP, F_COBRO, IMPORTE, PENDIENTE, MEDIO_PAGO,
				DOMICILIADO, ENTIDAD, OFICINA, DC, CUENTA, ESTADO, CODIGO_TRIBUTO, EJERCICIO,REMESA,
				DIGITO_YEAR, F_JULIANA, DISCRI_PERIODO, ID_HISTO_SOPORTES,MODALIDAD,ID_ING_INDE)
	   	VALUES(
				xMUNICIPIO,xPADRON,xYEAR,v_Multas.RECIBO, v_Multas.EMISOR,v_Multas.ENTIDAD_RECEP,
				v_Multas.OFICINA_RECEP,v_Multas.F_COBRO,v_Multas.IMPORTE,xPendiente,
				v_Multas.MEDIO_PAGO,v_Multas.DOMICILIADO,v_Multas.ENTIDAD,v_Multas.OFICINA,
				v_Multas.DC,v_Multas.CUENTA,xESTADO,v_Multas.CODIGO_TRIBUTO,
				v_Multas.EJERCICIO,v_Multas.REMESA,v_Multas.DIGITO_YEAR,
				v_Multas.F_JULIANA,v_Multas.DISCRI_PERIODO,v_Multas.ID_HISTO_SOPORTES,
				'MOD2LI',DECODE(xAsociaInci_C60,1,xIDIngresosIndebidos,null));

		END IF;

   END LOOP;

   -- Actualizamos el SALDO de la cuenta con el total de los ingresos
   UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xCobrado WHERE ID=xIDCuenta
   RETURN SALDO INTO xSaldoActual;

   -- Actualizamos IMPORTE, RECIBOS, SALDO del movimiento con lo Cobrado
   UPDATE MOV_CUENTAS SET IMPORTE=xCobrado,RECIBOS=xTotal,SALDO=xSaldoActual
   WHERE ID=xIDMovCuentas;

   -- Se busca si se ha aplicado ya todo el disco
   SELECT COUNT(*) INTO xCuantosPendi FROM COBROS_BANCOS_VENTANILLA
	WHERE USUARIO=UID AND ESTADO IS NULL;

   -- Indicamos en el histo_soportes que ya se ha aplicado, o no, todo el disco
   UPDATE HISTO_SOPORTES SET
  	APLICADO=DECODE(xCuantosPendi,0,'S','P'),
	ID_CUENTA_INGRESO= xIDCuenta , FECHA_INGRESO_APLICACION=xFecha,
	COBRADO_BANCO=COBRADO_BANCO+xCobrado, TOTAL_VALORES=TOTAL_VALORES+xTotal
   WHERE ID = xIDHISTO;
   
   -- Indicamos en el desglose del histórico que se ha aplicado este cobro
   UPDATE DESGLOSE_HISTO_SOPORTES SET APLICADO='S' 
   WHERE ID_HISTO_SOPORTES=xIDHISTO AND MUNICIPIO=xMUNICIPIO AND
         PADRON=xPADRON AND YEAR=xYEAR AND MODALIDAD='MOD2LI';	

END;
/


/*************************************************************************************/

CREATE OR REPLACE TRIGGER T_INS_CAIXARESUMEN
BEFORE INSERT ON COBROS_CAIXA_RESUMEN
FOR EACH ROW
BEGIN

	IF :NEW.F_DEVOLUCION=TO_DATE('01-01-1901','DD-MM-YY') THEN
		:NEW.F_DEVOLUCION:=NULL;
	END IF;


	IF :NEW.F_COBRO=TO_DATE('01-01-1901','DD-MM-YY') THEN
		:NEW.F_COBRO:=NULL;
	END IF;

	IF :NEW.F_TRAMITE_DOMI=TO_DATE('01-01-1901','DD-MM-YY') THEN
		:NEW.F_TRAMITE_DOMI:=NULL;
	END IF;

	IF :NEW.F_AVISO_DOMI=TO_DATE('01-01-1901','DD-MM-YY') THEN
		:NEW.F_AVISO_DOMI:=NULL;
	END IF;

	IF :NEW.F_SEGUNDO_AVISO=TO_DATE('01-01-1901','DD-MM-YY') THEN
		:NEW.F_SEGUNDO_AVISO:=NULL;
	END IF;

END T_INS_CAIXARESUMEN;
/


-- ****************************************************************************************
-- Autor: M. Carmen Junco Gomez. 14/03/2002
-- Acción: Dar por ingresados los recibos de La Caixa por el formato de comunicacion de
-- 	  cobros y anulaciones.
-- Modificado: 26/11/2003. Lucas Fernández Pérez. Nuevos códigos de dato número 45 y 46.
--	El código de ingreso en domiciliaciones se pone a vacío (antes era PB)
-- Modificado: 01/03/2004. Lucas Fernández Pérez. 
--	Se cambia mCanalIngreso='' por mCanalIngreso=NULL
-- ****************************************************************************************
-- DELPHI

CREATE OR REPLACE PROCEDURE UPDATE_CAIXA_COMUNICACION(
			xMUNICIPIO  IN CHAR,
	 		xPADRON     IN CHAR,
			xYEAR 	IN CHAR,
			xPERIODO 	IN CHAR,
			xFecha	IN DATE,
			xIDCUENTA	IN INTEGER,
			xCuantos_C  OUT INTEGER,
			xCuantos_A	OUT INTEGER,
			xTotal_C 	OUT FLOAT,
			xTotal_A	OUT FLOAT,
			xPagados 	OUT INTEGER,
			xBajas 	OUT INTEGER,
			xNE 		OUT INTEGER,
			xCobrado 	OUT FLOAT,
			xAnulado	OUT FLOAT,
			zEje 		OUT INTEGER,
			zEjeVol 	OUT INTEGER,
			zVol 		OUT INTEGER,
			zVolEje 	OUT INTEGER)


AS

	xPRINCIPAL_va	FLOAT;
	xRECARGO_va		FLOAT;
	xCodOpe 		integer;
	xESTADO 		char(2);
	xF_Ingreso 		date;
	xF_Baja 		date;

	SiIngreso		char(1);
	SiCompruebo		char(1);
	xDescrip		VARCHAR(150);
	xTipoIngre		char(2);

	xVALOR		INTEGER;

	xSaldoActual      FLOAT DEFAULT 0;
	xIDMov_cuentas    INTEGER;
	xIteracion	      INTEGER DEFAULT 0;
	xERROR		INTEGER;
	mCanalIngreso	CHAR(2);

	xVOL_EJE 		char(1);
	xIngEje		char(1);


	CURSOR C1 IS SELECT RECIBO,F_COBRO,IMPORTE_COBRADO,SITUACION_RECIBO,
		              MOTIVO_DEVO,ENTIDAD_COBRO,OFICINA_COBRO
		  	 FROM COBROS_CAIXA_RESUMEN
			 WHERE USUARIO=USER AND
			       MUNICIPIO=xMUNICIPIO AND
				 PADRON=xPADRON AND
				 YEAR=xYEAR AND
				 PERIODO=xPERIODO AND
				 ESTADO IS NULL;

BEGIN

   xPRINCIPAL_va:=0;
   xRECARGO_va:=0;
   xCuantos_C:=0;
   xCuantos_A:=0;
   xPagados:=0;
   xBajas:=0;
   xTotal_C:=0;
   xTotal_A:=0;
   xCobrado:=0;
   xAnulado:=0;
   xNE:=0;
   zEje:=0;
   zEjeVol:=0;
   zVol:=0;
   zVolEje:=0;

   CODIGO_OPERACION(xCodOpe);

   FOR v_caixa IN C1
   LOOP

    xPRINCIPAL_va:=NULL;
    xRECARGO_va:=NULL;
    xESTADO:=NULL;
    SiIngreso:='N';
    SiCompruebo:='S';
    mCanalIngreso:=NULL;
    xIngEje:='N';

	--buscamos el importe del valor
      begin
	   SELECT ID,PRINCIPAL,RECARGO,F_INGRESO,FECHA_DE_BAJA,VOL_EJE
	   INTO xVALOR,xPRINCIPAL_va,xRECARGO_va,xF_Ingreso,xF_Baja,xVOL_EJE
	   FROM VALORES
	   WHERE AYTO=xMUNICIPIO AND
		   PADRON=xPADRON AND
		   YEAR=xYEAR AND
		   PERIODO=xPERIODO AND
		   RECIBO=v_caixa.RECIBO AND
		   TIPO_DE_OBJETO='R';

	   Exception
	      When no_data_found then
	         null;
      end;

 	IF v_caixa.SITUACION_RECIBO IN ('40','41','43','45','46') THEN
	   xCobrado:=xCobrado+v_caixa.IMPORTE_COBRADO;
	ELSE
	   xAnulado:=xAnulado+v_caixa.IMPORTE_COBRADO;
	END IF;

	--el recibo no existe
	IF (xPRINCIPAL_va IS NULL) then
         --el recibo no existe
	   xEstado:='NE';
	   xNE:=xNE+1;
	ELSE
         --Se trata de un ingreso en ejecutiva
	   if (ROUND(xPRINCIPAL_va,2)<ROUND(v_caixa.Importe_Cobrado,2)) then
		xIngEje:='S';
	   end if;

	   -- si está ingresado y no es una devolución
	   if ((xF_Ingreso is not null) and (v_caixa.SITUACION_RECIBO not in ('42','44'))) then
		--recibo cobrado
	    xPagados:=xPagados+1;
		xEstado:='CO';
		SiCompruebo:='N';
	   else
	      -- si está ingresado y me viene como devolución ('42' o '44')
	      -- solo lo contabilizamos para hacer un apunte al final del proceso.
	      IF ((xF_Ingreso is not null) and (v_caixa.SITUACION_RECIBO in ('42','44'))) THEN
		   xCuantos_A:=xCuantos_A+1;
		   xTotal_A:=xTotal_A+xPRINCIPAL_va+xRECARGO_va;
		   SiCompruebo:='N';
		   xEstado:='AN';
	      ELSE
            if (xF_Baja is not null) then
		      --recibo anulado
		      xBajas:=xBajas+1;
		      xEstado:='BA';
		      SiCompruebo:='N';
		   	else
              IF (xVol_Eje ='E') THEN
		         if (xIngEje='S') then
			      xEstado:='EE'; --recibo en ejecutiva e ingreso en ejecutiva
			      zEje:=zEje+1;
		         else
			      --recibo en ejecutiva e ingreso en voluntaria
				  SiCompruebo:='N';
			      xEstado:='EV';
			      zEjeVol:=zEjeVol+1;
		         end if;
		      ELSE
		         if (xIngEje='S') then
				  SiCompruebo:='N';
			      xEstado:='VE'; --recibo en voluntaria e ingreso en ejecutiva
			      zVolEje:=zVolEje+1;
		         else
			      xEstado:='VV';  --recibo en voluntaria e ingreso en voluntaria
			      zVol:=zVol+1;
		         end if;
		      END IF;
		    end if;
		 END IF;
	   end if;

	   -- el recibo no está ingresado, ni dado de baja, ni viene como devuelto,
	   -- ni está en ejecutiva y el ingreso en voluntaria ni al revés.
	   if ((SiCompruebo='S') and (v_caixa.SITUACION_RECIBO not in ('42','44'))) then

        -- 40  Cobros por Domiciliación
        -- 43  Domiciliaciones Órdenes de Pago Aplazado abonadas
		if ((v_caixa.Situacion_Recibo='40') or (v_caixa.Situacion_Recibo='43')) then
		   xDescrip:='PAGO DOMICILIADO EN EL BANCO';
		   xTipoIngre:='PD';
		   SiIngreso:='S';
		   mCanalIngreso:=NULL;
		end if;

		-- 41 Cobros por Ventanilla
		-- 45 Cobros propia Emisora
		-- 46 Cobros de recibos DOM antes de la emisión
		if (v_Caixa.Situacion_Recibo IN ('41') or (v_caixa.Situacion_Recibo='45')
			or (v_caixa.Situacion_Recibo='46')) then
		   xDescrip:='INGRESADO EN LA VENTANILLA DEL BANCO';
		   xTipoIngre:='VB';
		   SiIngreso:='S';
		   mCanalIngreso:='PB';
		end if;

	   end if;	--if (SiCompruebo='S') then

	END IF; -- IF (xPRINCIPAL_va IS NULL) then


	if (SiIngreso='S') then
	   xTotal_C:=xTotal_C+xPRINCIPAL_va+xRECARGO_va;
	   xCuantos_C:=xCuantos_C+1;

	   IF xIteracion=0 THEN

            INSERT INTO MOV_CUENTAS
            (CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
            VALUES
            (xIDCuenta,'COBROS A TRAVES DE LA CAIXA','CX',0,0,xIDCuenta,
             'H',xFecha,0)
		RETURN ID INTO xIDMov_cuentas;

		xIteracion:=1; -- Para realizar solo UNA insercion en la tabla MOV_CUENTAS

	   END IF;

	   IF v_caixa.IMPORTE_COBRADO=xPRINCIPAL_va+xRECARGO_va THEN
	      PkIngresos.WRITE_INGRESO(xVALOR,xDescrip,xTipoIngre,xFecha,xPrincipal_va,
			  xRecargo_va,0,0,xCodOpe,'C',
 			  v_caixa.F_COBRO,v_caixa.ENTIDAD_COBRO,v_caixa.OFICINA_COBRO,
			  mCanalIngreso,'0');
	   END IF;

	end if;


	UPDATE COBROS_CAIXA_RESUMEN SET ESTADO=xESTADO
	WHERE MUNICIPIO=xMUNICIPIO AND
		PADRON=xPADRON AND
		YEAR=xYEAR AND
		PERIODO=xPERIODO AND
		RECIBO=v_caixa.RECIBO AND
		ESTADO IS NULL;

   END LOOP;

   -- Actualizamos el SALDO de la cuenta con el total de los ingresos
   UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xCobrado WHERE ID=xIDCuenta
   RETURN SALDO INTO xSaldoActual;

   -- Actualizamos IMPORTE, RECIBOS, SALDO del movimiento con lo Cobrado
   UPDATE MOV_CUENTAS SET IMPORTE=xCobrado,RECIBOS=xTotal_C,SALDO=xSaldoActual
   WHERE ID=xIDMov_Cuentas;

   -- Actualizamos el SALDO de la cuenta con el total de las Anulaciones
--   UPDATE CUENTAS_SERVICIO SET SALDO = SALDO - xAnulado WHERE ID=xIDCuenta
--   RETURN SALDO INTO xSaldoActual;

   -- Insertamos movimiento bancario
--   INSERT INTO MOV_CUENTAS
--      (CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
--   VALUES
--      (xIDCuenta,'DEVOLUCIONES A TRAVES DE LA CAIXA','CX',xAnulado,xTotal_A,xIDCuenta,
--       'D',xFecha,xSaldoActual);

END;
/

/*************************************************************************************/

CREATE OR REPLACE PROCEDURE ESTADOS_CAIXA_RESUMEN(
			xMUNICIPIO  IN CHAR,
	 		xPADRON     IN CHAR,
			xYEAR 	IN CHAR,
			xPERIODO 	IN CHAR)

AS

	xESTADO 		char(2);

	xPRINCIPAL_va	FLOAT;
	xF_Ingreso 		date;
	xF_Baja 		date;


	CURSOR C1 IS SELECT RECIBO
		  	 FROM COBROS_CAIXA_RESUMEN
			 WHERE USUARIO=USER AND
			       MUNICIPIO=xMUNICIPIO AND
				 PADRON=xPADRON AND
				 YEAR=xYEAR AND
				 PERIODO=xPERIODO AND
				 ESTADO IS NULL;

BEGIN

   FOR v_caixa IN C1
   LOOP

	xESTADO:=NULL;

	--buscamos el importe del valor
      begin
	   SELECT PRINCIPAL,F_INGRESO,FECHA_DE_BAJA INTO xPRINCIPAL_va,xF_Ingreso,xF_Baja
	   FROM VALORES

	   WHERE AYTO=xMUNICIPIO AND
		PADRON=xPADRON AND
		YEAR=xYEAR AND
		PERIODO=xPERIODO AND
		RECIBO=v_caixa.RECIBO AND
		TIPO_DE_OBJETO='R';

	   Exception
	      When no_data_found then
	         null;
      end;

	--el recibo no existe
	IF (xPRINCIPAL_va IS NULL) then
         --recibo no encontrado
	   xEstado:='NE';
	ELSE

	   if (xF_Ingreso is not null) then
		--recibo cobrado
		xEstado:='CO';
	   end if;

         if (xF_Baja is not null) then
		-- recibo dado de baja
		xEstado:='BA';
	   end if;

	END IF; -- IF (xPRINCIPAL_va IS NULL) then

	UPDATE COBROS_CAIXA_RESUMEN SET ESTADO=xESTADO
	WHERE MUNICIPIO=xMUNICIPIO AND
		PADRON=xPADRON AND
		YEAR=xYEAR AND
		PERIODO=xPERIODO AND
		RECIBO=v_caixa.RECIBO AND
		ESTADO IS NULL;

   END LOOP;

END;
/

-- Dar por ingresados los recibos de La Caixa por el formato del resumen de Gestión 
-- Modificado: 26/11/2003. Lucas Fernández Pérez. Nuevos códigos de dato número
--	 15-16-17-62-63-67-68-69-70-71-72-73-74-75-76-77-78-79-80-90-91-92
-- Se añaden codigos antiguos que no se trataban: 31-32-33-34-35-36-47-48-57-58-65-66-83-84
CREATE OR REPLACE PROCEDURE UPDATE_CAIXA_RESUMEN(
			xMUNICIPIO  IN CHAR,
	 		xPADRON     IN CHAR,
			xYEAR 	IN CHAR,
			xPERIODO 	IN CHAR,
			xFecha	IN DATE,
			xIDCUENTA	IN INTEGER,
			xCuantos    OUT INTEGER,
			xTotal 	OUT FLOAT,
			xPagados 	OUT INTEGER,
			xBajas 	OUT INTEGER,
			xNE 		OUT INTEGER,
			xCobrado 	OUT FLOAT)

AS

	xPRINCIPAL_va	FLOAT;
	xRECARGO_va		FLOAT;
	xCodOpe 		integer;
	xESTADO 		char(2);
	xVOL_EJE 		char(1);
	xF_Ingreso 		date;
	xF_Baja 		date;

	SiIngreso		char(1);
	SiCompruebo		char(1);
	xDescrip		VARCHAR(150);
	xTipoIngre		char(2);

	xVALOR		INTEGER;


	xSaldoActual      FLOAT DEFAULT 0;
	xIDMov_cuentas    INTEGER;
	xIteracion	      INTEGER DEFAULT 0;
	xERROR		INTEGER;
	mCanalIngreso	CHAR(2);

	CURSOR C1 IS SELECT RECIBO,F_COBRO,IMPORTE_COBRADO,IMPORTE_PADRON,SITUACION_RECIBO,
		              MOTIVO_DEVO,ENTIDAD_COBRO,OFICINA_COBRO
		  	 FROM COBROS_CAIXA_RESUMEN
			 WHERE USUARIO=USER AND
			       MUNICIPIO=xMUNICIPIO AND
				 PADRON=xPADRON AND
				 YEAR=xYEAR AND
				 PERIODO=xPERIODO AND
				 ESTADO IS NULL;

BEGIN

   xPRINCIPAL_va:=0;
   xRECARGO_va:=0;
   xCuantos:=0;
   xPagados:=0;
   xBajas:=0;
   xTotal:=0;
   xCobrado:=0;
   xNE:=0;

   CODIGO_OPERACION(xCodOpe);

   FOR v_caixa IN C1
   LOOP

      xPRINCIPAL_va:=NULL;
	xESTADO:=NULL;
	SiIngreso:='N';
	SiCompruebo:='S';
	mCanalIngreso:=NULL;


	--buscamos el importe del valor
      begin
	   SELECT ID,PRINCIPAL,RECARGO,VOL_EJE,
		F_INGRESO,FECHA_DE_BAJA

	   INTO xVALOR,xPRINCIPAL_va,xRECARGO_va,
		xVol_Eje,xF_Ingreso,xF_Baja

	   FROM VALORES

	   WHERE AYTO=xMUNICIPIO AND
		PADRON=xPADRON AND
		YEAR=xYEAR AND
		PERIODO=xPERIODO AND
		RECIBO=v_caixa.RECIBO AND
		TIPO_DE_OBJETO='R';

	   Exception
	      When no_data_found then
	         null;
      end;


	xCobrado:=xCobrado+v_caixa.IMPORTE_COBRADO;

	--el recibo no existe
	IF (xPRINCIPAL_va IS NULL) then
         --recibo no encontrado
	   xEstado:='NE';
	   xNE:=xNE+1;
	   SiIngreso:='N';
	ELSE

	   if (xF_Ingreso is not null) then
		--recibo cobrado
	      xPagados:=xPagados+1;
		xEstado:='CO';
		SiCompruebo:='N';
	   end if;

         if (xF_Baja is not null) then
		--recibo anulado
		xBajas:=xBajas+1;
		xEstado:='BA';
		SiCompruebo:='N';
	   end if;

	   -- si el recibo esta ya pagado o anulado no sigo comprobando
	   if (SiCompruebo='S') then

		--	01- Domiciliación propia
		--	02- Domiciliación cobrado domiciliación
		--	03- Domiciliación administrador
		if (v_caixa.Situacion_Recibo='01' or v_caixa.Situacion_Recibo='02'
                or v_caixa.Situacion_Recibo='03') then
		   xDescrip:='PAGO DOMICILIADO EN EL BANCO';
		   xTipoIngre:='PD';
		   mCanalIngreso:=NULL;
		   SiIngreso:='S';
		end if;

		--  15- Cobro ventanilla Caixa y domiciliación no emitida
		--  16- Cobro ventanilla entidad colaboradora y domiciliación no emitida
		--  17- Cobro ServiCaixa y domiciliación no emitida
		-- 	21- Cobro ventanilla Caixa                /31- Con Recargo/ 67- Con Bonificación
		--	22- Cobro ventanilla Entidad colaboradora /32- Con Recargo/ 68- Con Bonificación
		--	23- Cobro ventanilla Caixa y duplicados   /33- Con Recargo/ 69- Con Bonificación
		--	24- Cobro ventanilla EECC y duplicados    /34- Con Recargo/ 70- Con Bonificación
		--	25- Cobro ServiCaixa                      /35- Con Recargo/ 71- Con Bonificación
		--	26- Cobro ServiCaixa y duplicados         /36- Con Recargo/ 72- Con Bonificación
		--	91- Cobro propia emisora		          /92- Con Recargo/ 90- Con Bonificación

		if (v_Caixa.Situacion_Recibo IN ('15','16','17','21','22','23','24','25','26',
		'31','32','33','34','35','36','67','68','69','70','71','72','83','84','90','91','92')) then
		  
		  xTipoIngre:='VB';
		  SiIngreso:='S';

		  IF (v_Caixa.Situacion_Recibo IN ('15','16','21','22','23','24',
		  		'31','32','33','34','67','68','69','70','83','84','90','91','92')) then
		  
		  	mCanalIngreso:='PB';
 			IF (v_Caixa.Situacion_Recibo IN ('15','16','21','22','23','24','83','84','91')) then
		    	xDescrip:='INGRESADO EN LA VENTANILLA DEL BANCO';
		    ELSE
	 			if (v_Caixa.Situacion_Recibo IN ('31','32','33','34','92')) then
			    	xDescrip:='INGRESADO CON RECARGO EN LA VENTANILLA DEL BANCO';
			    else
		    		xDescrip:='INGRESADO CON BONIFICACION EN LA VENTANILLA DEL BANCO';
		    	end if;
		    END IF;
		    
		  ELSE
			mCanalIngreso:='PA';
 			if (v_Caixa.Situacion_Recibo IN ('17','25','26')) then
		      xDescrip:='INGRESADO POR SERVICAIXA';
		    else
		    	if (v_Caixa.Situacion_Recibo IN ('35','36')) then
 		  	  		xDescrip:='INGRESADO CON RECARGO POR SERVICAIXA';
 		  	  	else
 		  	  		xDescrip:='INGRESADO CON BONIFICACION POR SERVICAIXA';
 		  	  	end if;
 		  	end if;
		  END IF;

		end if;

		--pagos por Línia Oberta
		if (v_caixa.Situacion_Recibo IN ('60','61','62','63','65','66')) then
			mCanalIngreso:='PI';
		   	xTipoIngre:='VB';
		   	SiIngreso:='S';
	   	
 			IF (v_Caixa.Situacion_Recibo IN ('60','61')) then
	 		    xDescrip:='INGRESADO POR LINEA ABIERTA';
		    ELSE
	 			if (v_Caixa.Situacion_Recibo IN ('62','63')) then
		 		    xDescrip:='INGRESADO CON BONIFICACION POR LINEA ABIERTA';
			    else
 				    xDescrip:='INGRESADO CON RECARGO POR LINEA ABIERTA';
 		  		end if;
 		  	END IF;
 		  	
		end if;


		--pagos por Internet
		if (v_caixa.Situacion_Recibo IN ('41','42','43','44','45','46','47','48',
		    '51','52','53','54','55','56','57','58','73','74','75','76','77','78','79','80')) then
			mCanalIngreso:='PI';
		   	xTipoIngre:='VB';
		   	SiIngreso:='S';
 			IF (v_Caixa.Situacion_Recibo IN ('41','42','43','44','45','46','47','48')) then
	 		    xDescrip:='INGRESADO A TRAVES DE INTERNET';
		    ELSE
	 			if (v_Caixa.Situacion_Recibo IN ('51','52','53','54','55','56','57','58')) then
		 		    xDescrip:='INGRESADO CON RECARGO A TRAVES DE INTERNET';
			    else
		 		    xDescrip:='INGRESADO CON BONIFICACION A TRAVES DE INTERNET';
 		  		end if;
 		  	END IF;
 		  	
 			if (v_Caixa.Situacion_Recibo IN ('47','48','57','58','79','80')) then
			   CHECK_MARCA_DEVU(xPADRON,xYEAR,xPERIODO,
				        v_caixa.RECIBO,v_caixa.MOTIVO_DEVO);
			end if;
 		  	
		end if;


		-- 	05- Pendiente de cobro por domiciliacion no atendida
		--	06- Pendiente de cobro por anulación
		if (v_caixa.Situacion_Recibo='05' or v_caixa.Situacion_Recibo='06') then
		   CHECK_MARCA_DEVU(xPADRON,xYEAR,xPERIODO,
				        v_caixa.RECIBO,v_caixa.MOTIVO_DEVO);
		end if;

	   end if;	--if (SiCompruebo='S') then

	END IF; -- IF (xPRINCIPAL_va IS NULL) then


	if (SiIngreso='S') then
	   xTotal:=xTotal+xPRINCIPAL_va+xRECARGO_va;
	   xCuantos:=xCuantos+1;

	   IF xIteracion=0 THEN

            INSERT INTO MOV_CUENTAS
            (CUENTA,TEXTO,TIPO_INGRESO,IMPORTE,RECIBOS,ORIGEN,OPERACION,F_INGRESO,SALDO)
            VALUES
            (xIDCuenta,'COBROS A TRAVES DE LA CAIXA','CX',0,0,xIDCuenta,
             'H',xFecha,0)
		RETURN ID INTO xIDMov_cuentas;

		xIteracion:=1; -- Para realizar solo UNA insercion en la tabla MOV_CUENTAS

	   END IF;

	   IF v_caixa.IMPORTE_COBRADO=xPRINCIPAL_va+xRECARGO_va THEN
	      PkIngresos.WRITE_INGRESO(xVALOR,xDescrip,xTipoIngre,xFecha,xPrincipal_va,
			  xRecargo_va,0,0,xCodOpe,'C',
 			  v_caixa.F_COBRO,v_caixa.ENTIDAD_COBRO,v_caixa.OFICINA_COBRO,
			  mCanalIngreso,'0');
	   END IF;

	end if;


	UPDATE COBROS_CAIXA_RESUMEN SET ESTADO=xESTADO
	WHERE MUNICIPIO=xMUNICIPIO AND
		PADRON=xPADRON AND
		YEAR=xYEAR AND
		PERIODO=xPERIODO AND
		RECIBO=v_caixa.RECIBO AND
		ESTADO IS NULL;

   END LOOP;

   --diferencia de lo que se ha cobrado y lo que se tendría que haber cobrado

   -- Actualizamos el SALDO de la cuenta con el total de los ingresos
   UPDATE CUENTAS_SERVICIO SET SALDO = SALDO + xCobrado WHERE ID=xIDCuenta
   RETURN SALDO INTO xSaldoActual;

   -- Actualizamos IMPORTE, RECIBOS, SALDO del movimiento con lo Cobrado
   UPDATE MOV_CUENTAS SET IMPORTE=xCobrado,RECIBOS=xTotal,SALDO=xSaldoActual
   WHERE ID=xIDMov_Cuentas;

END;
/

/******************************************************************************************
Autor: Mª Carmen Junco Gómez. 26/09/2002
Acción: Añadir o modificar una relación entre códigos de concepto de la aplicación y
	  códigos de tributo bancarios.
	  El parámetro de salida nos indicará cualquier incidencia que se pueda dar.
	  0: Proceso realizado correctamente
	  1: Esta relación ya existía para los datos proporcionados
DELPHI
******************************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_MOD_RELA_APLI(
		xID			IN	INTEGER,
		xAYTO			IN	CHAR,
		xEMISORA		IN	CHAR,
		xGLOBAL		IN	CHAR,
		xCODIGOBANCO 	IN	CHAR,
		xCODIGOCAIXA 	IN	CHAR,
		xCONCEPTO		IN	CHAR,
		xTRIBUTO		IN	CHAR,
		xOUT			OUT	INTEGER)
AS
	xEMIGLOBAL CHAR(1);
	mID	     INTEGER;
	xCUANTOS   INTEGER;
	CURSOR CMUNI IS SELECT AYTO FROM MUNICIPIOS
			    WHERE AYTO<>xAYTO;
BEGIN
	xOUT:=0;

	IF xID=0 THEN
		SELECT COUNT(*) INTO xCUANTOS FROM RELA_APLI_BANCOS
		WHERE AYTO=xAYTO AND AYTO_BANCO=xCODIGOBANCO AND
			AYTO_CAIXA=xCODIGOCAIXA AND CONCEPTO=xCONCEPTO AND
			CONCEPTO_BANCO=xTRIBUTO;
		IF xCUANTOS > 0 THEN
	   		xOUT:=1;
	   		RETURN;
		END IF;

		INSERT INTO RELA_APLI_BANCOS (AYTO,AYTO_BANCO,AYTO_CAIXA,CONCEPTO,
			CONCEPTO_BANCO,EMISORA,EMISORA_GLOBAL)
		VALUES (xAYTO,xCODIGOBANCO,xCODIGOCAIXA,xCONCEPTO,xTRIBUTO,
			xEMISORA,xGLOBAL);
	ELSE
		UPDATE RELA_APLI_BANCOS SET AYTO_BANCO=xCODIGOBANCO,
						    AYTO_CAIXA=xCODIGOCAIXA,
						    CONCEPTO=xCONCEPTO,
						    CONCEPTO_BANCO=xTRIBUTO,
						    EMISORA=xEMISORA,
						    EMISORA_GLOBAL=xGLOBAL
		WHERE ID=xID;
	END IF;

	-- Si la emisora es global, tendremos que insertar (o modificar) para cada municipio
	-- de la tabla municipios una tupla que indique esta misma relación
	-- entre código de aplicación y código de tributo bancario.
	-- Sólo se insertará si esta relación no está ya definida para el
	-- municipio en cuestión con emisora no global.
	-- como códigos de ayuntamiento para caixa y c60 pondremos por defecto
	-- el mismo código de ayuntamiento que en la tabla municipios.

	IF xGLOBAL='S' THEN
	  FOR vAYTO IN CMUNI
        LOOP
		xEMIGLOBAL:='N';
		begin
		   SELECT ID,EMISORA_GLOBAL INTO mID,xEMIGLOBAL FROM RELA_APLI_BANCOS
		   WHERE AYTO=vAYTO.AYTO AND CONCEPTO_BANCO=xTRIBUTO;
		   Exception
			When no_data_found then
			   -- si no existe lo insertamos
			   INSERT INTO RELA_APLI_BANCOS (AYTO,AYTO_BANCO,AYTO_CAIXA,CONCEPTO,
			   CONCEPTO_BANCO,EMISORA,EMISORA_GLOBAL)
			   VALUES (vAYTO.AYTO,vAYTO.AYTO,vAYTO.AYTO,xCONCEPTO,xTRIBUTO,
			   xEMISORA,xGLOBAL);
		end;

		-- si exite y es global, cambiamos los datos por los de entrada al procedimiento
		IF xEMIGLOBAL='S' THEN
		   UPDATE RELA_APLI_BANCOS SET CONCEPTO=xCONCEPTO,
						    	 EMISORA=xEMISORA
		   WHERE ID=mID;
		END IF;

	  END LOOP;
	END IF;
END;
/

/*************************************************************************************
Autor: Mª del Carmen Junco Gómez. 28/01/2003
Acción: Borrar todo lo leído de un disco de cobros por ventanilla banco 
*************************************************************************************/
CREATE OR REPLACE PROCEDURE COBROS_BANCOS_VENTANILLA_DEL(			
			xID_HISTO_SOPORTES	IN	INTEGER,
			xMUNICIPIO			IN	CHAR,
			xPADRON				IN	CHAR,
			xYEAR				IN	CHAR,
			xPERIODO			IN	CHAR,
			xMODALIDAD			IN	CHAR)
AS
   xAPLICADO_DISCO CHAR(1);      
   xCOBROS	       INTEGER;
   xIMPORTE        FLOAT;      
   
BEGIN
 
    SELECT APLICADO INTO xAPLICADO_DISCO FROM HISTO_SOPORTES
    WHERE ID=xID_HISTO_SOPORTES;        
    
	-- 1º caso: que no haya nada aplicado
	IF xAPLICADO_DISCO='N' THEN
	   DELETE FROM HISTO_SOPORTES WHERE ID=xID_HISTO_SOPORTES;	      
	      
	-- 2º caso: disco parcialmente aplicado
	ELSIF xAPLICADO_DISCO='P' THEN
	   DELETE FROM DESGLOSE_HISTO_SOPORTES 
	   WHERE ID_HISTO_SOPORTES=xID_HISTO_SOPORTES AND 
	         APLICADO='N';
	   SELECT SUM(NCOBROS),SUM(IMPORTE) INTO xCOBROS,xIMPORTE 
	   FROM DESGLOSE_HISTO_SOPORTES WHERE ID_HISTO_SOPORTES=xID_HISTO_SOPORTES;
	      
	   UPDATE HISTO_SOPORTES SET NCOBROS=xCOBROS,
	    						 IMPORTE=xIMPORTE
	   WHERE ID=xID_HISTO_SOPORTES;	   
	   
	END IF;
	   
	DELETE FROM COBROS_BANCOS_VENTANILLA 
	WHERE ID_HISTO_SOPORTES=xID_HISTO_SOPORTES AND USUARIO=UID;	
	
END;
/