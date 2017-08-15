-- ************************************************************************************
-- Para realizar liquidaciones de gestión de recursos de otros entes
-- Cálculamos las comisiones que nos corresponden por la gestión de cobro de nuestros
-- clientes, así como los importes gestionados de ingresos y bajas. Indicando el líquido
-- a transferirle después de nuestra gestión de cobro.
--
-- Sobre una versión de Lucas Fernandez Pérez
--
-- Autor: Antonio Pérez Caballero
-- fecha: 10/12/2002
-- ************************************************************************************
CREATE OR REPLACE PACKAGE PkLiquiROE
AS

xTPC_Vol_Mun			MUNICIPIOS.TPC_VOL%TYPE;
xTPC_Eje_Mun 			MUNICIPIOS.TPC_EJE%TYPE;
xTPC_Recargo_Mun 		MUNICIPIOS.TPC_RECARGO%TYPE;
xTPC_Demora_Mun 		MUNICIPIOS.TPC_DEMORA%TYPE;
xTPC_Costas_Mun 		MUNICIPIOS.TPC_COSTAS%TYPE;
xTPC_Bajas_Vol_Mun		MUNICIPIOS.TPC_BAJAS_VOL%TYPE;
xTPC_Bajas_Eje_Mun		MUNICIPIOS.TPC_BAJAS_VOL%TYPE;
xTPC_Bajas_Eje_BR_Mun	MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BI_Mun	MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BP_Mun	MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BO_Mun	MUNICIPIOS.TPC_BAJAS_EJE%TYPE;

xIDLiqui INTEGER;
xAyuntamiento CHAR(3);


-- Agrupo los ingresos de una liquidacion por PADRON,AÑO,PERIODO,VOL_EJE
-- y calculo el principal, recargos ... y número de ingresos que hay en
-- cada tupla del cursor
-- Sólo los ingresos reales sin compensaciones ni entregas en organismos externos
CURSOR cINGRE IS
	SELECT V.PADRON, V.YEAR, V.PERIODO, I.VOL_EJE, COUNT(*) AS Count,
	SUM(I.PRINCIPAL) AS SumPrincipal,
	SUM(I.RECARGO) AS SumRecargo, SUM(I.DEMORA) AS SumDemora,
	SUM(I.COSTAS) AS SumCostas, SUM(I.RECARGO_O_E) AS SumRecargoOE
	FROM INGRESOS I, VALORES V
	WHERE I.LIQUIDACION=xIDLiqui
	AND V.ID=I.VALOR
	AND I.ORGANISMO_EXT='N'
	AND I.TIPO_INGRESO NOT IN ('CM','EC')
	GROUP BY V.PADRON, V.YEAR, V.PERIODO, I.VOL_EJE;


CURSOR cINGRECompe IS
	SELECT V.PADRON, V.YEAR, V.PERIODO, I.VOL_EJE, COUNT(*) AS Count,
	SUM(I.PRINCIPAL) AS SumPrincipal,
	SUM(I.RECARGO) AS SumRecargo, SUM(I.DEMORA) AS SumDemora,
	SUM(I.COSTAS) AS SumCostas, SUM(I.RECARGO_O_E) AS SumRecargoOE
	FROM INGRESOS I, VALORES V
	WHERE I.LIQUIDACION=xIDLiqui
	AND V.ID=I.VALOR
	AND I.ORGANISMO_EXT='N'
	AND I.TIPO_INGRESO IN ('CM','EC')
	GROUP BY V.PADRON, V.YEAR, V.PERIODO, I.VOL_EJE;

CURSOR cINGREMociones IS
	SELECT V.PADRON, V.YEAR, V.PERIODO, I.VOL_EJE, COUNT(*) AS Count,
	SUM(I.PRINCIPAL) AS SumPrincipal,
	SUM(I.RECARGO) AS SumRecargo, SUM(I.DEMORA) AS SumDemora,
	SUM(I.COSTAS) AS SumCostas, SUM(I.RECARGO_O_E) AS SumRecargoOE
	FROM INGRESOS I, VALORES V
	WHERE I.LIQUIDACION=xIDLiqui
	AND V.ID=I.VALOR
	AND I.ORGANISMO_EXT='S'
	GROUP BY V.PADRON, V.YEAR, V.PERIODO, I.VOL_EJE;


FUNCTION GetAyto RETURN CHAR;

PROCEDURE LiquiIngresos(v_INGRE IN cIngre%ROWTYPE, xTIPO IN CHAR);

PROCEDURE LiquiBajas;

PROCEDURE MakeResumen;

PROCEDURE MAIN;

PROCEDURE DescuentaIngrDtos(xIDLiq IN Integer, xID_Anti IN Integer);

PROCEDURE DescuentaIngrAnticipos(xIDLiq IN Integer, xID_Anti IN Integer);

PROCEDURE ActualizarAnticipos(xIDLiq IN ANTICIPOS.LAST_LIQUIDR%TYPE,
		xFecha IN ANTICIPOS.FECHA%TYPE);

--
-- Sobrecarga para funcionamiento de la Diputación de Granada
--
PROCEDURE ActualizarAnticipos(xYear IN Char, xAyto In Char, xIDLiqui IN Integer);

END;
/


-- ************************************************************************************
-- 									CUERPO DEL PAQUETE
-- ************************************************************************************
CREATE OR REPLACE PACKAGE BODY PkLiquiROE
AS

--
-- Módulo principal
--
PROCEDURE MAIN
AS
BEGIN

-- Averiguar el ayuntamiento
xAyuntamiento:=GetAyto;

-- Ingresos
FOR v_INGRE IN cINGRE LOOP

    LiquiIngresos(v_INGRE,'IN');

END LOOP;


-- Compensaciones
FOR v_INGRE IN cINGRECompe LOOP

    LiquiIngresos(v_INGRE,'CO');

END LOOP;

-- Mociones (ingresos en otros organismos)
FOR v_INGRE IN cINGREMociones LOOP

    LiquiIngresos(v_INGRE,'MO');

END LOOP;

-- PROCESAR LAS BAJAS
LiquiBajas;

-- Generar el fichero de resumen por ayto, concepto, periodo y año
MakeResumen;

END;

--
-- Averiguar el Ayto que estamos liquidando
--
FUNCTION GetAyto RETURN CHAR
AS
xAyto Char(3);
BEGIN

-- Obtengo el código de municipio

SELECT AYTO INTO xAyto FROM LIQUIDACIONESR WHERE ID=xIDLiqui;

-- Obtener los porcentajes del premio de cobranza para este municipio

SELECT TPC_VOL,TPC_EJE, TPC_RECARGO, TPC_DEMORA, TPC_COSTAS, TPC_BAJAS_VOL, TPC_BAJAS_EJE,
		 TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI, TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO
	INTO xTPC_Vol_Mun, xTPC_Eje_Mun, xTPC_Recargo_Mun, xTPC_Demora_Mun, xTPC_Costas_Mun,
		 xTPC_Bajas_Vol_Mun, xTPC_Bajas_Eje_Mun, xTPC_Bajas_Eje_BR_Mun,
		 xTPC_Bajas_Eje_BI_Mun, xTPC_Bajas_Eje_BP_Mun, xTPC_Bajas_Eje_BO_Mun
	FROM MUNICIPIOS
		WHERE AYTO=xAYto;



RETURN xAyto;

END;

--
-- Cálculos de comisiones sobre los ingresos
--
PROCEDURE LiquiIngresos(v_INGRE IN cIngre%ROWTYPE, xTIPO IN CHAR)
as

xTPC_Vol 				MUNICIPIOS.TPC_VOL%TYPE;
xTPC_Eje 				MUNICIPIOS.TPC_EJE%TYPE;
xTPC_Demora 			MUNICIPIOS.TPC_DEMORA%TYPE;
xTPC_Costas 			MUNICIPIOS.TPC_COSTAS%TYPE;
mPremioPrincipal 		Float default 0;

begin


	-- Obtengo los porcentajes de comisión a aplicar para este MUNICIPIO Y CONCEPTO
	-- Si para el concepto no hay comisiones especiales, se toman las del municipio.
	begin

			SELECT TPC_VOL,TPC_EJE, TPC_DEMORA, TPC_COSTAS
			INTO xTPC_Vol, xTPC_Eje, xTPC_Demora, xTPC_Costas
			FROM COMISIONES_AYTO_PADRON
			WHERE AYTO=xAyuntamiento
			AND PADRON=v_INGRE.PADRON;

	exception
		when no_data_found then
			xTPC_Vol:=xTPC_Vol_Mun;
			xTPC_Eje:=xTPC_Eje_Mun;
			xTPC_Demora:=xTPC_Demora_Mun;
			xTPC_Costas:=xTPC_Costas_Mun;

	end;


	-- El premio sobre el principal en voluntaria será un porcentaje sobre dicho importe
	-- El premio sobre el principal en ejecutiva será un porcentaje sobre el recargo de apremio
	if v_INGRE.VOL_EJE='E' then
	   mPremioPrincipal:= Round( ((v_INGRE.SumRecargo * xTPC_Eje) / 100), 2);
	else
	   mPremioPrincipal:= Round( ((v_INGRE.SumPrincipal * xTPC_Vol ) / 100), 2);
	end if;

	INSERT INTO LIQUIDR_CONCEPTOS (IDLIQ, AYTO, TIPO, VOLEJE, CONCEPTO, YEAR, PERIODO,
		  		PRINCIPAL, RECARGO,	COSTAS,	DEMORA,	RECARGO_OE,
		  		PPRINCIPAL,	PCOSTAS, PDEMORA)

  	VALUES( xIDLiqui, xAyuntamiento,xTIPO,v_INGRE.VOL_EJE, v_INGRE.PADRON,
  			v_INGRE.YEAR, v_INGRE.PERIODO,	v_INGRE.SumPrincipal,
  			v_INGRE.SumRecargo,	v_INGRE.SumCostas,
  			v_INGRE.SumDemora, v_INGRE.SumRecargoOE,
  			mPremioPrincipal,
  			ROUND((v_INGRE.SumCostas*(xTPC_Costas/100)),2),
  			ROUND((v_INGRE.SumDemora*(xTPC_Demora/100)),2)	);




end;


--
-- Cálculo de las comsiones sobre las bajas
--
PROCEDURE LiquiBajas
as

xCount			INTEGER;
xImporteAntes	FLOAT DEFAULT 0;


xTPC_Vol 				MUNICIPIOS.TPC_VOL%TYPE;
xTPC_Eje 				MUNICIPIOS.TPC_EJE%TYPE;
xTPC_Recargo 			MUNICIPIOS.TPC_RECARGO%TYPE;
xTPC_Demora 			MUNICIPIOS.TPC_DEMORA%TYPE;
xTPC_Costas 			MUNICIPIOS.TPC_COSTAS%TYPE;
xTPC_Bajas_Vol			MUNICIPIOS.TPC_BAJAS_VOL%TYPE;
xTPC_Bajas_Eje			MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BR		MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BI		MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BP		MUNICIPIOS.TPC_BAJAS_EJE%TYPE;
xTPC_Bajas_Eje_BO		MUNICIPIOS.TPC_BAJAS_EJE%TYPE;

xTPC_Bajas Float;


-- Agrupo las Bajas de una Liquidacion por PADRON,AÑO,PERIODO,VOL_EJE,TIPO_BAJA
-- y calculo el principal y número de bajas que hay en cada tupla del cursor
CURSOR CBAJAS IS
	SELECT V.PADRON, V.YEAR, V.PERIODO, B.VOL_EJE, B.TIPO_BAJA,
	SUM(B.PRINCIPAL) AS SumPrincipal, SUM(B.RECARGO) AS SumRecargo,
	SUM(B.DEMORA) AS SumDemora,	SUM(B.COSTAS) AS SumCostas,
	SUM(B.RECARGO_O_E) AS SumRecargoOE
	FROM BAJAS B, VALORES V
	WHERE B.LIQUIDACION=xIDLiqui
	AND V.ID=B.VALOR
	GROUP BY V.PADRON, V.YEAR, V.PERIODO, B.VOL_EJE,B.TIPO_BAJA;


begin

-- Cálculo de los valores de las bajas
FOR v_BAJAS IN CBAJAS LOOP

	-- Obtengo los porcentajes de comisión a aplicar para este MUNICIPIO Y CONCEPTO
	-- Si para el concepto no hay comisiones especiales, se toman las del municipio.
	begin

		SELECT TPC_BAJAS_VOL, TPC_BAJAS_EJE, TPC_BAJAS_EJE_BR, TPC_BAJAS_EJE_BI,
			   TPC_BAJAS_EJE_BP, TPC_BAJAS_EJE_BO
		INTO xTPC_Bajas_Vol, xTPC_Bajas_Eje, xTPC_Bajas_Eje_BR, xTPC_Bajas_Eje_BI,
			 xTPC_Bajas_Eje_BP, xTPC_Bajas_Eje_BO
		FROM COMISIONES_AYTO_PADRON
		WHERE AYTO=xAyuntamiento
		AND PADRON=v_BAJAS.PADRON;

	   exception
		when no_data_found then
			xTPC_Bajas_Vol:=xTPC_Bajas_Vol_Mun;
			xTPC_Bajas_Eje:=xTPC_Bajas_Eje_Mun;
			xTPC_Bajas_Eje_BR:=xTPC_Bajas_Eje_BR_Mun;
			xTPC_Bajas_Eje_BI:=xTPC_Bajas_Eje_BI_Mun;
			xTPC_Bajas_Eje_BP:=xTPC_Bajas_Eje_BP_Mun;
			xTPC_Bajas_Eje_BO:=xTPC_Bajas_Eje_BO_Mun;
	end;

	IF v_BAJAS.VOL_EJE='V' THEN
	   xTPC_Bajas:=xTPC_Bajas_Vol;
	ELSE
	   IF v_BAJAS.TIPO_BAJA='BR' THEN
	      xTPC_Bajas:=xTPC_Bajas_Eje_BR;
	   END IF;
	   IF v_BAJAS.TIPO_BAJA='BI' THEN
	      xTPC_Bajas:=xTPC_Bajas_Eje_BI;
	   END IF;
	   IF v_BAJAS.TIPO_BAJA='BP' THEN
	      xTPC_Bajas:=xTPC_Bajas_Eje_BP;
	   END IF;
	   IF v_BAJAS.TIPO_BAJA='BO' THEN
	      xTPC_Bajas:=xTPC_Bajas_Eje_BO;
	   END IF;

	END IF;

   	INSERT INTO LIQUIDR_CONCEPTOS (
   				IDLIQ, AYTO, TIPO, VOLEJE, CONCEPTO, YEAR, PERIODO,
		  		PRINCIPAL, RECARGO,	COSTAS, DEMORA, RECARGO_OE,
		  		PPRINCIPAL)
  	VALUES( xIDLiqui, xAyuntamiento,v_BAJAS.TIPO_BAJA,v_BAJAS.VOL_EJE, v_BAJAS.PADRON,
  			v_BAJAS.YEAR, v_BAJAS.PERIODO,	v_BAJAS.SumPrincipal,
  			v_BAJAS.SumRecargo,	v_BAJAS.SumCostas, v_BAJAS.SumDemora, v_BAJAS.SumRecargoOE,
  	ROUND((v_BAJAS.SumPrincipal*xTPC_Bajas/100), 2)	);


END LOOP;


end;

--
-- Pasa a la tabla de resumen de conceptos liquidados
--
PROCEDURE MakeResumen
AS


--
cursor cIngresos is select ayto,concepto,year,periodo,
		sum(principal+recargo+costas+demora) as Total, sum(RECARGO_OE) AS SumROE
	 from LIQUIDR_CONCEPTOS where IDLIQ=xIDLiqui and tipo='IN'
	 group by ayto,concepto,year,periodo;

BEGIN

	 insert into LIQUIDR_CTO_RESUMEN(IDLIQ,AYTO,CONCEPTO,YEAR,PERIODO,PREMIO,RECARGO_OE)
	 select xIDLiqui,ayto,concepto,year,periodo,sum(PPRINCIPAL+PCOSTAS+PDEMORA),
	 sum(RECARGO_OE)
	 from LIQUIDR_CONCEPTOS where IDLIQ=xIDLiqui
	 group by ayto,concepto,year,periodo;


	 for vIngresos in cIngresos loop

	 	update LIQUIDR_CTO_RESUMEN set ingresos=vIngresos.Total,
	 		RECARGO_OE=vIngresos.SumROE
	 		where IDLIQ=xIDLiqui and ayto=vIngresos.ayto
	 			and concepto=vIngresos.concepto
	 			and year=vIngresos.year
	 			and periodo=vIngresos.periodo;

	 end loop;

END;


--
--
--
PROCEDURE DescuentaIngrDtos(xIDLiq IN Integer, xID_Anti IN Integer)

as

mDescontado float default 0;
mIngresado float default 0;
mDisponible float default 0;
mPendiente  float default 0;
mPorcentaje float default 0;

begin

SELECT PENDIENTE INTO mPendiente FROM ANTICIPOS
		WHERE ID=xID_Anti;


-- Sumamos las cantidades obtenidas en la liquidación
SELECT SUM(INGRESOS-Premio-RECARGO_OE),SUM(Dto) INTO mIngresado,mDescontado
		FROM LIQUIDR_CTO_RESUMEN
		WHERE IDLIQ=xIDLiq;

mDisponible:=mIngresado-mDescontado;

IF mDisponible > 0 THEN -- hay dinero, se puede descontar

		IF mPendiente > mDisponible THEN -- No se puede descontar todo

			mPendiente:=mPendiente-mDisponible;

			UPDATE ANTICIPOS SET PENDIENTE=mPendiente, LAST_LIQUIDR=xIDLiq
			WHERE ID=xID_Anti;

			mDisponible:=0;

		    -- marcamos todos los conceptos como totalmente descontados

			UPDATE LIQUIDR_CTO_RESUMEN SET Dto=INGRESOS-Premio-RECARGO_OE
				WHERE IDLIQ=xIDLiq;

		ELSE -- hay dinero suficiente para descontar todo.

			UPDATE ANTICIPOS SET PENDIENTE=0,LAST_LIQUIDR=xIDLiq,ESTADO='L'
			WHERE ID=xID_Anti;

			-- repartimos el cobro del descuento entre los conceptos
			mPorcentaje:=(mPendiente*100)/mDisponible;

			UPDATE LIQUIDR_CTO_RESUMEN
			SET DTO=ROUND(Dto+((((INGRESOS-Premio-RECARGO_OE)-Dto)*mPorcentaje)/100),2)
			WHERE IDLIQ=xIDLiq;

		END IF;

end if;


end;

--
-- Descuenta el neto de la liquidación a los posibles anticipos
--
PROCEDURE DescuentaIngrAnticipos(xIDLiq IN Integer, xID_Anti IN Integer)
AS

mPendiente float default 0;
mDto float default 0;
mPremio float default 0;
mDescontado float default 0;
mIngresado float default 0;
xSumaDescuentos float default 0;


-- Recorre los conceptos asociados con el anticipo

CURSOR cCONCEPTOS IS SELECT CONCEPTO,EJERCICIO,PERIODO
		FROM ConceptosAnticipos
		WHERE ANTICIPO=xID_Anti;


BEGIN

	SELECT PENDIENTE INTO mPendiente FROM ANTICIPOS
		WHERE ID=xID_Anti;

	FOR v_Con IN cCONCEPTOS LOOP


			SELECT Sum(Ingresos-Premio-RECARGO_OE),Sum(Dto) INTO mIngresado,mDescontado
				FROM LIQUIDR_CTO_RESUMEN
				WHERE IDLIQ=xIDLiq
				AND CONCEPTO=v_Con.CONCEPTO
				AND YEAR=v_Con.EJERCICIO
				AND PERIODO=v_Con.PERIODO;

			-- Si no se ha recaudado nada de un concepto
			-- poner la variables a cero
			if mIngresado is null then
			   mIngresado:=0;
			   mDescontado:=0;
			end if;

			-- Liquido pendiente
			mIngresado:=mIngresado-mDescontado;

			if mIngresado >= mPendiente then
		   		mDto:=mPendiente;
		   		mPendiente:=0;
			else
		   		mPendiente:=mPendiente-mIngresado;
		   		mDto:=mIngresado;
			end if;

			UPDATE LIQUIDR_CTO_RESUMEN SET DTO=DTO+mDto
				WHERE IDLIQ=xIDLiq
				AND CONCEPTO=v_Con.CONCEPTO
				AND YEAR=v_Con.EJERCICIO
				AND PERIODO=v_Con.PERIODO;

			-- Suma de los descuentos aplicados
			xSumaDescuentos:=xSumaDescuentos+mDto;

	END LOOP;

	-- Restamos al pendiente la suma de lo descontado
	-- Un trigger sobre anticipos ajusta el campo estado a 'L'
	UPDATE ANTICIPOS SET PENDIENTE=PENDIENTE - xSumaDescuentos, LAST_LIQUIDR=xIDLiq
			WHERE ID=xID_Anti;

END;

--
-- Actualizar los anticipos y descuentos
--
-- Un anticipo es un adelanto sobre un cocenpto, año y periodo o conjunto de estos
-- Un descuento es un adelanto sobre el total de lo recaudado sin restricción de conceptos
--
PROCEDURE ActualizarAnticipos(
	xIDLiq		IN ANTICIPOS.LAST_LIQUIDR%TYPE,
	xFecha	 	IN ANTICIPOS.FECHA%TYPE)

-- xFecha indica hasta que fecha se deben calcular los intereses de los anticipos/descuentos.

AS
	mDescontado float default 0;
	mIngresado 	float default 0;
	xAyto		ANTICIPOS.AYTO%TYPE;

--	Recorre los anticipos pendientes del ayuntamiento en cuestión.
-- 	Si el anticipo es posterior a la liquidación, no se tiene en cuenta

	CURSOR cANTICIPOS IS SELECT ID,TIPO FROM ANTICIPOS
		WHERE AYTO = xAyto
		AND ESTADO = 'P'
		AND FECHA < xFecha
		ORDER BY PRIORIDAD;


BEGIN

	-- Obtengo el código de municipio
	SELECT AYTO INTO xAyto FROM LIQUIDACIONESR WHERE ID=xIDLiq;

	-- Para cada anticipo y en orden de prioridad actualizamos su pendiente,
	--   comprobando si se puede liquidar

	FOR v_Anti IN cANTICIPOS LOOP

		-- Sumamos las cantidades obtenidas en la liquidación
		SELECT SUM(INGRESOS-PREMIO-RECARGO_OE),SUM(DTO) INTO mIngresado,mDescontado
		FROM LIQUIDR_CTO_RESUMEN
			WHERE IDLIQ=xIDLiq;

		-- Todo lo ingresado se ha descontado, no queda más.
		IF mIngresado=mDescontado THEN
			EXIT;
		END IF;

		IF v_Anti.TIPO='A' THEN -- es un anticipo
			DescuentaIngrAnticipos(xIDLiq, v_Anti.ID);
		ELSE -- es un descuento
  			DescuentaIngrDtos(xIDLiq, v_Anti.ID);
		END IF;

	END LOOP;

END;



--
-- Actualizar los anticipos y descuentos
--
-- Un anticipo es un adelanto sobre un cocenpto, año y periodo o conjunto de estos
-- Un descuento es un adelanto sobre el total de lo recaudado sin restricción de conceptos
--
PROCEDURE ActualizarAnticipos(xYear IN Char, xAyto In Char, xIDLiqui IN Integer)
AS

mDescontado float default 0;
mIngresado 	float default 0;
mSuma 	float default 0;
xIDAnti INTEGER;
xFECHA DATE;

--	Recorre los anticipos pendientes del ayuntamiento en cuestión.

	CURSOR cANTICIPOS IS SELECT ID,TIPO FROM ANTICIPOS
		WHERE AYTO = xAyto
		AND to_char(FECHA,'yyyy') = xYear
		AND TIPO='A'
		ORDER BY PRIORIDAD;



-- Recorre los conceptos asociados con el anticipo

CURSOR cCONCEPTOS IS SELECT CONCEPTO,EJERCICIO,PERIODO
		FROM ConceptosAnticipos
		WHERE ANTICIPO=xIDAnti;

BEGIN

	SELECT FECHA_FIN INTO xFECHA FROM LIQUIDACIONESR
		WHERE ID=xIDLiqui;

	-- Para cada anticipo y en orden de prioridad actualizamos su pendiente,
	--   comprobando si se puede liquidar

	FOR v_Anti IN cANTICIPOS LOOP

		-- Sumamos las cantidades obtenidas en la liquidación
		SELECT SUM(INGRESOS-PREMIO-RECARGO_OE),SUM(DTO) INTO mIngresado,mDescontado
		FROM LIQUIDR_CTO_RESUMEN
			WHERE IDLIQ=xIDLiqui;

		-- Todo lo ingresado se ha descontado, no queda más.
		IF mIngresado=mDescontado THEN
			EXIT;
		END IF;


		xIDAnti:=v_Anti.ID;

		-- Relación de conceptos del anticipo

		mSuma:=0;
		FOR V_cCONCEPTOS IN cCONCEPTOS LOOP


			select SUM(INGRESOS-PREMIO-RECARGO_OE) into mIngresado
				from LIQUIDR_CTO_RESUMEN
				where IDLIQ=xIDLiqui
				and CONCEPTO=V_cCONCEPTOS.CONCEPTO
				and YEAR=V_cCONCEPTOS.EJERCICIO
				and PERIODO=V_cCONCEPTOS.PERIODO;


			-- Si no hay un valor mIngresado será nulo en caso contrario
			-- es que existe el concepto y por lo tanto lo añadimos al historico
			if mIngresado is not null then
				mSuma:=mSuma+mIngresado;
			end if;

		END LOOP;

		if mSuma > 0 then
		   INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,MOVIMIENTO,FECHA,IMPORTE)
		   	VALUES (xIDAnti, 'RE', xFecha, mSuma);
		end if;

	END LOOP;

END;


END;
/
