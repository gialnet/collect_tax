--
-- 16/09/2002 Antonio Pérez Caballero
--
-- Paquete de gestión de liquidaciones de la Junta de Andalucía
--
-- Tipos de bajas
-- 'BA' Anulación
-- 'BR' Reposición a voluntaria
-- 'BI' Insolvencia
-- 'BP' Prescripción
-- 'BO' Otros motivos
--

--
-- NOTA IMPORTANTE:
-- Fecha: 14/11/2002. Sentencias que hay que lanzar antes de realizar una data a la Junta
--			hasta que terminemos de procesar los ingresos de Regularización
--	Cuando se haga la data especial de regularizacion en el cursor de ingresos
--		hay que quitar esta condicion: AND entra_en_la_data='S'. Tambien hay que quitarlo de todos los sitios
--			donde este la condicion entra_en_la_data='S'
--
--	entra_en_la_data ='N' significa que no tenemos que enviarle estos ingresos a la Junta hasta que
--			finalice el proceso de regularizacion. Estos ingresos entraran en la data
--			especial
-- UPDATE INGRESOS SET entra_en_la_data='N'
-- WHERE VALOR IN (SELECT VALOR FROM INGRESOS WHERE ORGANISMO_EXT='R' GROUP BY VALOR)
--
-- UPDATE BAJAS SET entra_en_la_data='N'
-- WHERE VALOR IN (SELECT VALOR FROM INGRESOS WHERE ORGANISMO_EXT='R' GROUP BY VALOR)
--
CREATE OR REPLACE PACKAGE PkJuntaResult
AS

-- *******************************************
-- Variables del paquete
-- *******************************************

xYearEnvio 			Char(4);
xMesEnvio 			Char(2);
xNumeroEnvio 		Char(2);
xFechaInicial		Date;
xFechaFinal			Date;
xFechaSoporte		Date;

-- *******************************************
-- Variables del premio de cobranza
-- *******************************************
xPorcentPrincipal Float default 15;
xPorcentDemora Float default 10;
xPorcentInsolvencias Float default 1;

--
-- 17 noviembre 2002 Antonio Pérez Caballero
--
-- ORGANISMO_EXT<>'A' nos filtra para que no entren aquellos ingresos que se realizaron
-- antes del cargo es decir el fuera de plazo.
--
-- entra_en_la_data='N' significa que no entra en la data,
-- en caso de entra_en_la_data='S' es que si tiene que entrar en la data que enviamos a la Junta
--

CURSOR cINGRESOS IS SELECT I.VALOR,I.YEAR_CONTRAIDO,I.FECHA,I.F_COBRO_BANCO,I.PRINCIPAL,I.RECARGO,
		I.COSTAS,I.DEMORA,I.PARCIAL_O_COBRO,I.ORGANISMO_EXT
	FROM INGRESOS I, MUNICIPIOS M
         	WHERE I.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN'
		AND TRUNC(I.FECHA,'DD') BETWEEN xFechaInicial AND xFechaFinal
		AND entra_en_la_data='S'
		AND ORGANISMO_EXT<>'A'
	order by i.valor;


CURSOR cBAJA IS SELECT B.VALOR,B.YEAR_CONTRAIDO,B.FECHA,B.PRINCIPAL,B.RECARGO,
		B.COSTAS,B.DEMORA, B.TIPO_BAJA
	FROM BAJAS B, MUNICIPIOS M
         	WHERE B.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN'
		AND B.TIPO_BAJA<>'BN'
		AND entra_en_la_data='S'
		AND TRUNC(B.FECHA,'DD') BETWEEN xFechaInicial AND xFechaFinal
	order by b.valor;


TYPE T_Valores IS RECORD (
	OFICINA_LIQUI 	VALORES_AS400.OFICINA_LIQUI%TYPE,
	RECARGO_JUNTA 	VALORES_AS400.RECARGO_JUNTA%TYPE,
	CLAVE_EXTERNA 	VALORES.CLAVE_EXTERNA%TYPE,
	CLAVE_CONCEPTO 	VALORES.CLAVE_CONCEPTO%TYPE,
	NIF 			VALORES.NIF%TYPE,
	NOMBRE 		VALORES.NOMBRE%TYPE,
	F_NOTIFICACION 	VALORES.F_NOTIFICACION%TYPE,
	CUOTA_INICIAL	VALORES.CUOTA_INICIAL%TYPE,
	FUERA_PLAZO		VALORES.ENTREGAS_ANTESDEL_CARGO%TYPE,
	PRINCIPAL		VALORES.PRINCIPAL%TYPE,
	RECARGO		VALORES.RECARGO%TYPE,
	F_CARGO		VALORES.F_CARGO%TYPE,
	DEMORA		VALORES.DEMORA%TYPE,
	COSTAS		VALORES.COSTAS%TYPE,
	ENTREGAS_A_CUENTA VALORES.ENTREGAS_A_CUENTA%TYPE,
	F_INGRESO		VALORES.F_INGRESO%TYPE,
	ID			VALORES.ID%TYPE
);



--
-- Nos devuelve el importe del premio de cobranza
--
FUNCTION CalcPremioCobranza(cValores IN  T_Valores) RETURN FLOAT;

-- Fecha de intervalo de liquidación de ingresos desde xFECHA1 hasta xFECHA2

PROCEDURE MAIN(xFECHA1 IN DATE, xFECHA2 IN DATE);

-- Cabecera del soporte para los ingresos
PROCEDURE NEW_TIPO_0(xOFILIQ IN Char);

-- Cabecera del soporte para las bajas
PROCEDURE NEW_TIPO_0(xOFILIQ IN Char, xBaja IN Char);

PROCEDURE ADD_TIPO_1(xOFILIQ IN Char, cValores IN  T_Valores, xFechaInicio IN  date, xFechaFin IN  date);

PROCEDURE ADD_TIPO_2(xOFILIQ IN Char, cValores IN  T_Valores, xFechaInicio IN  date, xFechaFin IN  date);

PROCEDURE ADD_TIPO_3(xOFILIQ IN Char,xClave IN Char, xIndicardor IN Char,
	xImporte IN Float, xFReal IN Date, xFContable IN Date);

PROCEDURE NEW_TIPO_7(xOFILIQ IN Char);

PROCEDURE ADD_BAJATIPO_1(xOFILIQ IN Char,
		v_cBaja IN cBAJA%ROWTYPE, cValores IN  T_Valores);

PROCEDURE ADD_BAJATIPO_2(xOFILIQ IN Char,
		v_cBaja IN cBAJA%ROWTYPE, cValores IN  T_Valores);

PROCEDURE TOTALIZAR;

PROCEDURE ADD_ANEXO_I(xOFILIQ IN Char, xImporte in float, xTipo in char);

PROCEDURE PENDIENTE_A_FECHA(xVALOR IN INTEGER,xFECHA IN DATE,
				xPRINCIPAL OUT FLOAT,xRECARGO OUT FLOAT);

END;
/


-- *****************************************************************************
--
-- Desarrollo de las funciones y procedimientos
--
-- *****************************************************************************
CREATE OR REPLACE PACKAGE BODY PkJuntaResult
AS

-- *******************************************
--
-- Cálculo del premio de cobranza
--
-- *******************************************
FUNCTION CalcPremioCobranza(cValores IN  T_Valores) RETURN FLOAT
AS
xImporteCoste Float;
xImporteCostePrinci Float;
xImporteCosteDemora Float;
BEGIN

--
-- Convenio con la Junta de Andalucía de 22 de Marzo de 1.993 página 11
-- QUINTA.- Coste del servicio
--
--	a) El 15% del importe principal de los títulos ejecutivos datados por ingreso
-- o el 15% del importe recaudado, cuando este sea inferior al principal de la deuda,
-- en aquellas mixtas con ingreso, pudiendo la Diputación Provincial retener dicho
-- porcentaje en el momento del cobro.
--
--	b) Un 10% del importe de intereses de demora cobrados en los títulos datados por ingreso
--
--	c) Un 1% del importe principal de los títulos ejecutivos datados y declarados por la
-- Tesoreria como créditos incobrables.
--

-- ¡oJo! Se utiliza este algoritmo por que no se liquida el premio de cobranza hasta
-- que se ultima el expediente de apremio

IF cValores.FUERA_PLAZO > 0 THEN

   -- En este caso el premio de cobranza del 15% es sobre lo que quede de principal más
   -- recargo

   xImporteCostePrinci:= (cValores.PRINCIPAL + cValores.RECARGO - cValores.FUERA_PLAZO)
						* 15 / 100;

ELSE

   -- Cobrado por el Servicio !lo normal¡, el premio es 15% sobre el principal

      xImporteCostePrinci:=cValores.PRINCIPAL * 15 / 100;

END IF;

-- Premio sobre los intereses de demora es 10 %

IF cValores.DEMORA > 0 THEN
   xImporteCosteDemora:=cValores.DEMORA * 10 /100;
ELSE
   xImporteCosteDemora:=0;
END IF;


xImporteCoste:=Round( (xImporteCostePrinci + xImporteCosteDemora), 2);
xImporteCoste:= xImporteCoste * 100;

RETURN xImporteCoste;


END;

-- *******************************************
--
-- Gestión de ingresos de la Junta de Andalucía
--
-- *******************************************
PROCEDURE MAIN(xFECHA1 IN DATE, xFECHA2 IN DATE)
AS
xIDValor Integer default 0;

-- Averiguar para cuantas delegaciones hay liquidaciones

CURSOR cDELEGAIngre IS SELECT distinct OFICINA_LIQUI FROM VALORES_AS400
	WHERE VALOR IN (SELECT I.VALOR FROM INGRESOS I, MUNICIPIOS M
         	WHERE I.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN' AND entra_en_la_data='S'
		AND TRUNC(I.FECHA,'DD') BETWEEN xFECHA1 AND xFECHA2);

-- Por bajas

CURSOR cDELEGABajas IS SELECT distinct OFICINA_LIQUI FROM VALORES_AS400
	WHERE VALOR IN (SELECT B.VALOR FROM BAJAS B, MUNICIPIOS M
         	WHERE B.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN'
		AND entra_en_la_data='S'
		AND TRUNC(B.FECHA,'DD') BETWEEN xFECHA1 AND xFECHA2);

vValores T_Valores;

BEGIN

xFechaInicial:=xFecha1;
xFechaFinal:=xFecha2;
xFechaSoporte:=SYSDATE;
xYearEnvio:=to_char(xFecha1,'YYYY');
xMesEnvio:=to_char(xFecha1,'MM');

-- Añadir un registro de cabecera y totales por cada una de las delegaciones

FOR v_cDELEGAIngre IN cDELEGAIngre LOOP

    PkJuntaResult.NEW_TIPO_0( v_cDELEGAIngre.OFICINA_LIQUI );

END LOOP;


-- CURSOR DE LOS INGRESOS

FOR v_cINGRESOS IN cINGRESOS LOOP


	IF xIDValor <> v_cINGRESOS.VALOR THEN

		SELECT A.OFICINA_LIQUI, A.RECARGO_JUNTA, V.CLAVE_EXTERNA, V.CLAVE_CONCEPTO,
			V.NIF,V.NOMBRE,V.F_NOTIFICACION, V.CUOTA_INICIAL, V.ENTREGAS_ANTESDEL_CARGO,
			V.PRINCIPAL, V.RECARGO,	V.F_CARGO, V.DEMORA, V.COSTAS,
			V.ENTREGAS_A_CUENTA, V.F_INGRESO,V.ID

		INTO vValores

		FROM VALORES V JOIN VALORES_AS400 A ON V.ID=A.VALOR
         	WHERE V.ID=v_cINGRESOS.VALOR;

		xIDValor := v_cINGRESOS.VALOR;

		PkJuntaResult.ADD_TIPO_1(vValores.OFICINA_LIQUI, vValores, xFecha1, xFecha2);
		PkJuntaResult.ADD_TIPO_2(vValores.OFICINA_LIQUI, vValores, xFecha1, xFecha2);
	end if;

-- El registro tipo 3 está condicionado por el tipo de registro número dos
-- y es en función de si es una entrega a cuenta, una aminoración del principal
-- por ingreso en la Junta

	IF v_cIngresos.ORGANISMO_EXT IN ('N','R') THEN

		IF v_cIngresos.PRINCIPAL+v_cIngresos.RECARGO > 0 THEN
	   		PkJuntaResult.ADD_TIPO_3(vValores.OFICINA_LIQUI, vValores.CLAVE_EXTERNA,
					'1',v_cIngresos.PRINCIPAL+v_cIngresos.RECARGO,
					v_cIngresos.F_COBRO_BANCO,v_cIngresos.FECHA);

		END IF;

		IF v_cIngresos.DEMORA > 0 THEN
	   	   	PkJuntaResult.ADD_TIPO_3(vValores.OFICINA_LIQUI, vValores.CLAVE_EXTERNA,
					'2',v_cIngresos.DEMORA,
					v_cIngresos.F_COBRO_BANCO,v_cIngresos.FECHA);

		END IF;
	ELSE

		IF v_cIngresos.PRINCIPAL+v_cIngresos.RECARGO > 0 THEN
	   		PkJuntaResult.ADD_TIPO_3(vValores.OFICINA_LIQUI, vValores.CLAVE_EXTERNA,
					'3',v_cIngresos.PRINCIPAL+v_cIngresos.RECARGO,
					v_cIngresos.F_COBRO_BANCO,v_cIngresos.FECHA);

		END IF;

		IF v_cIngresos.DEMORA > 0 THEN
	   	   	PkJuntaResult.ADD_TIPO_3(vValores.OFICINA_LIQUI, vValores.CLAVE_EXTERNA,
					'4',v_cIngresos.DEMORA,
					v_cIngresos.F_COBRO_BANCO,v_cIngresos.FECHA);

		END IF;

	END IF;

END LOOP;

-- Añadir un registro de cabecera y totales por cada una de las delegaciones
-- Si no existe el registro para esa delegación añado una nueva y sino no se inserta de nuevo
FOR v_cDELEGABajas IN cDELEGABajas LOOP

    PkJuntaResult.NEW_TIPO_0( v_cDELEGABajas.OFICINA_LIQUI, 'B' );

END LOOP;


xIDValor:=0;

-- Cursor de las bajas
FOR v_cBajas IN cBaja LOOP

	IF xIDValor <> v_cBajas.VALOR THEN

		SELECT A.OFICINA_LIQUI, A.RECARGO_JUNTA,V.CLAVE_EXTERNA, V.CLAVE_CONCEPTO,
			V.NIF,V.NOMBRE,V.F_NOTIFICACION, V.CUOTA_INICIAL,V.ENTREGAS_ANTESDEL_CARGO,
			V.PRINCIPAL, V.RECARGO, V.F_CARGO,V.DEMORA, V.COSTAS, V.ENTREGAS_A_CUENTA,
			V.F_INGRESO, V.ID

		INTO vValores

		FROM VALORES V JOIN VALORES_AS400 A ON V.ID=A.VALOR

         	WHERE V.ID=v_cBajas.VALOR;

		xIDValor:=v_cBajas.VALOR;

		ADD_BAJATIPO_1(vValores.OFICINA_LIQUI, v_cBajas, vValores);

		ADD_BAJATIPO_2(vValores.OFICINA_LIQUI, v_cBajas, vValores);
	end if;

END LOOP;

-- Genera el registro de totales y
-- pone los números secuenciales de fichero

TOTALIZAR;

--Tabla de apoyo para imprimir el Anexo I que contiene algunos totalizadores que no
--están en el registro Tipo 7
ADD_ANEXO_I(vValores.OFICINA_LIQUI, 0, 'E');


END;

-- *******************************************
--
-- Registro de cabecera de las liquidaciones
--
-- *******************************************
PROCEDURE NEW_TIPO_0(xOFILIQ IN Char)
AS
xSinSoporte FLOAT;
xNoAceptado FLOAT;
BEGIN


BEGIN

SELECT ACUENTA_NOENSOPORTE,TRANSFE_NOACEPTADO INTO xSinSoporte,xNoAceptado
	FROM JUNTA_NOACEPTADO
	WHERE DELEGACION=xOFILIQ;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		xSinSoporte:=0;
		xNoAceptado:=0;
END;


INSERT INTO JUNTA_RESULT_T0 (DESTINO,YEAR_ENVIO,MES_ENVIO,N_ENVIO,
	F_INI,F_FIN,F_SOPORTE, INGRESADO_ACUENTA, TRANSFERIDO_NOACEPTADO)
	VALUES (xOFILIQ, xYearEnvio, xMesEnvio, xNumeroEnvio,
	TO_CHAR(xFechaInicial,'YYYYMMDD'),TO_CHAR(xFechaFinal,'YYYYMMDD'),
	TO_CHAR(xFechaSoporte,'YYYYMMDD'),
	LPAD(xSinSoporte,13,'0'), LPAD(xNoAceptado,13,'0'));

END;

-- *******************************************
--
-- Registro de cabecera de las liquidaciones desde el proceso para la data de bajas
--
-- *******************************************
PROCEDURE NEW_TIPO_0(xOFILIQ IN Char, xBaja IN Char)
AS
BEGIN

-- Intento actualizar
UPDATE JUNTA_RESULT_T0 SET DESTINO=xOFILIQ
	WHERE DESTINO=xOFILIQ;

-- Si no existe el registro para esa delegación añado una nueva

IF SQL%NOTFOUND THEN
   NEW_TIPO_0(xOFILIQ);
END IF;

END;

-- *******************************************
--
-- Identificación liquidación Ingresos
--
-- *******************************************
PROCEDURE ADD_TIPO_1(xOFILIQ IN Char, cValores IN  T_Valores, xFechaInicio IN date, xFechaFin IN date)
AS

xImporteGestionar Float;
xImporteCoste Float;

BEGIN


--Sólo se comunica a la Junta la aminoración del 10% cuando el recargo que tengamos nosotros
--	sea inferior al Recargo que nos envia la Junta. Ejemplo: la Junta nos envia el 20%
--	de recargo y nosotros hemos cobrado el 10% porque el contribuyente ha venido a pagar
--	antes de hacerle la notificacion de la providencia de apremio.
IF (cValores.RECARGO - cValores.RECARGO_JUNTA) < 0 THEN

	xImporteGestionar:=((cValores.PRINCIPAL+cValores.RECARGO_JUNTA)-cValores.FUERA_PLAZO)*100;

	-- El importe en el Anexo I va en Euros, no en centimos de Euro
	ADD_ANEXO_I(xOFILIQ,(cValores.PRINCIPAL+cValores.RECARGO_JUNTA)-cValores.FUERA_PLAZO,'G');
ELSE

	xImporteGestionar:=((cValores.PRINCIPAL+cValores.RECARGO)-cValores.FUERA_PLAZO)*100;

	-- El importe en el Anexo I va en Euros, no en centimos de Euro
	ADD_ANEXO_I(xOFILIQ,(cValores.PRINCIPAL+cValores.RECARGO)-cValores.FUERA_PLAZO,'G');

END IF;


-- Cálcular el premio de cobranza sólo cuando se ultima la deuda, de las entregas a cuenta nada de nada.
-- Puede darse el caso que estemos generando el disco del mes de Octubre del 2002 pero haya ingresos hasta el mes
-- de Enero del 2003, y la deuda se ultime por ejemplo en el mes de Diciembre del 2002, por eso está este if de abajo
--
IF (trunc(cValores.F_INGRESO,'dd') >= xFechaInicio) and (trunc(cValores.F_INGRESO,'dd') <= xFechaFin) THEN
   xImporteCoste:=CalcPremioCobranza(cValores);
ELSE
   xImporteCoste:=0;
END IF;

INSERT INTO JUNTA_RESULT_T1(DESTINO,CLAVE_DEUDA,N_SUR,IMPORTE,F_LIMITE,
	NIF,NOMBRE,F_NOTI_APREMIO,IMPORTE_COSTE,
	IMPORTE_ANTICIPADO,TRANSFERIDO_NOACEPTADO)
VALUES
	(xOFILIQ, SubStr(cValores.CLAVE_EXTERNA,1,17) , SubStr(cValores.CLAVE_CONCEPTO,1,13),
	LPAD(xImporteGestionar,11,'0'),LPAD('0',8,'0'),
	SubStr(cValores.NIF,1,9),cValores.NOMBRE,
	DECODE(cValores.F_NOTIFICACION,NULL,LPAD('0',8,'0'),to_char(cValores.F_NOTIFICACION,'YYYYMMDD')),
	LPAD(xImporteCoste,11,'0'), LPAD('0',11,'0'), LPAD('0',11,'0') );

END;

-- *************************************************
--
-- Registro de bajas
--
-- *************************************************
PROCEDURE ADD_BAJATIPO_1(xOFILIQ IN Char,
		v_cBaja IN cBAJA%ROWTYPE, cValores IN  T_Valores)
AS

xImporteGestionar Float;
xImporteCoste Float;

BEGIN

xImporteGestionar:=((cValores.PRINCIPAL+cValores.RECARGO_JUNTA)-cValores.FUERA_PLAZO)*100;

--
-- Cácular el premio de cobranza
-- En caso de una baja con ingresos parciales ¿Que hacer?
--
-- Sólamente hay premio de cobranza sobre las insolvencias

IF v_cBaja.TIPO_BAJA='BI' THEN

   IF cValores.PRINCIPAL > 0 THEN
   	xImporteCoste:=Round( (cValores.PRINCIPAL*1/100), 2);
   	xImporteCoste:=xImporteCoste * 100;
   ELSE
	xImporteCoste:=0;
   END IF;

ELSE
  xImporteCoste:=0;
END IF;

INSERT INTO JUNTA_RESULT_T1(DESTINO,CLAVE_DEUDA,N_SUR,IMPORTE,F_LIMITE,
	NIF,NOMBRE,F_NOTI_APREMIO,IMPORTE_COSTE,
	IMPORTE_ANTICIPADO,TRANSFERIDO_NOACEPTADO)
VALUES
	(xOFILIQ, SubStr(cValores.CLAVE_EXTERNA,1,17), SubStr(cValores.CLAVE_CONCEPTO,1,13),
	LPAD(xImporteGestionar,11,'0'),LPAD('0',8,'0'),
	SubStr(cValores.NIF,1,9),cValores.NOMBRE,
	DECODE(cValores.F_NOTIFICACION,NULL,LPAD('0',8,'0'),to_char(cValores.F_NOTIFICACION,'YYYYMMDD')),
	LPAD(xImporteCoste,11,'0'), LPAD('0',11,'0'), LPAD('0',11,'0') );

END;


-- *******************************************
--
-- Registro de detalle de la liquidación para ingresos
--
-- *******************************************
PROCEDURE ADD_TIPO_2(xOFILIQ IN Char, cValores IN  T_Valores, xFechaInicio IN date, xFechaFin IN date)
AS

xIndicador 				Char(1);
xNumero 				Char(11) default '00000000000';
xIngreEnte 				Char(11);
xIMPORTE_DEMORA_ENTE	float default 0;
xPendienteFinal 		Float;
xPendientePeri 			Float;
xSumaIngresos			float default 0;
xPRINCIPAL				FLOAT DEFAULT 0;
xRECARGO				FLOAT DEFAULT 0;
xIMPORTE_APLICADO_DEUDA	FLOAT DEFAULT 0;
xF_REAL_ULTIMO_INGRESO	DATE;
xIMPORTE_INTERESES_DIPU	FLOAT DEFAULT 0;
xF_REAL_INTERESES		DATE;
xF_CONTABLE_INTERESES	DATE;
xAminoraRecargo			FLOAT DEFAULT 0;
xTotalMociones			FLOAT DEFAULT 0;
xIDIngresos				integer;

begin

--  Sólo se comunica a la Junta la aminoración del 10% cuando el recargo que tengamos nosotros
--	sea inferior al Recargo que nos envia la Junta. Ejemplo: la Junta nos envia el 20%
--	de recargo y nosotros hemos cobrado el 10% porque el contribuyente ha venido a pagar
--	antes de hacerle la notificacion de la providencia de apremio.
IF (cValores.RECARGO - cValores.RECARGO_JUNTA) < 0 THEN

	--solo cuando se ultime la deuda es cuando comunicamos la aminoración del recargo
	IF (Trunc(cValores.F_INGRESO,'dd') >= xFechaInicio) and (Trunc(cValores.F_INGRESO,'dd') <= xFechaFin) THEN
		xAminoraRecargo:=ABS(cValores.RECARGO - cValores.RECARGO_JUNTA);
	ELSE
		xAminoraRecargo:=0;
	END IF;

	xPendientePeri:=(cValores.PRINCIPAL + cValores.RECARGO_JUNTA)-cValores.FUERA_PLAZO;

	--Descontar las mociones de la Junta
	SELECT SUM(PRINCIPAL+RECARGO) INTO xTotalMociones
		FROM INGRESOS
			WHERE VALOR=cValores.ID
			AND FECHA < xFechaInicial
			AND ORGANISMO_EXT='S';

	if xTotalMociones is null then
		xTotalMociones:=0;
	end if;

	xPendientePeri:=xPendientePeri-xTotalMociones;

	--Suma de los ingresos en el periodo
	SELECT sum(I.PRINCIPAL+I.RECARGO) into xSumaIngresos
	FROM INGRESOS I, MUNICIPIOS M
        WHERE I.VALOR=cValores.ID
        AND I.AYTO=M.AYTO
		AND M.TIPO_CLI='JUN'
		AND TRUNC(I.FECHA,'DD') BETWEEN xFechaInicio AND xFechaFin
		AND entra_en_la_data='S'
		AND ORGANISMO_EXT<>'A';

	if xSumaIngresos is null then
		xSumaIngresos:=0;
	end if;

	xPendienteFinal:=xPendientePeri-xSumaIngresos-xAminoraRecargo;

ELSE
	xAminoraRecargo:=0;

	PENDIENTE_A_FECHA(cValores.ID,xFechaInicial,xPRINCIPAL,xRECARGO);
	xPendientePeri:=xPRINCIPAL + xRECARGO;

	PENDIENTE_A_FECHA(cValores.ID,xFechaFinal+1,xPRINCIPAL,xRECARGO);
	xPendienteFinal:=xPRINCIPAL + xRECARGO;

END IF;

IF cValores.F_CARGO >= xFechaInicial AND cValores.F_CARGO <=xFechaFinal THEN
   xIndicador:='2';
ELSE
   xIndicador:='1';
END IF;

-- Suma de los ingresos habidos en el periodo
SELECT SUM(PRINCIPAL+RECARGO),SUM(DEMORA) INTO xIMPORTE_APLICADO_DEUDA,xIMPORTE_INTERESES_DIPU
FROM INGRESOS WHERE VALOR=cValores.ID
		AND TRUNC(FECHA,'DD') BETWEEN xFechaInicial AND xFechaFinal
		AND ORGANISMO_EXT='N';

--
SELECT MAX(FECHA) INTO xF_REAL_ULTIMO_INGRESO
FROM INGRESOS WHERE VALOR=cValores.ID AND ORGANISMO_EXT='N' AND (PRINCIPAL+RECARGO)>0;

-- Suma total de las mociones (Ingresos en la Junta de Andalucia)
SELECT SUM(PRINCIPAL+RECARGO),SUM(DEMORA) INTO xIngreEnte,xIMPORTE_DEMORA_ENTE
FROM INGRESOS WHERE VALOR=cValores.ID
		AND TRUNC(FECHA,'DD') BETWEEN xFechaInicial AND xFechaFinal
		AND ORGANISMO_EXT='S';

-- Mostramos el último ingreso de los intereses de demora
SELECT MAX(ID) INTO xIDIngresos
FROM INGRESOS WHERE VALOR=cValores.ID AND ORGANISMO_EXT='N' AND DEMORA>0;

IF xIDIngresos IS NOT NULL THEN
	SELECT FECHA,F_COBRO_BANCO INTO xF_CONTABLE_INTERESES,xF_REAL_INTERESES
	FROM INGRESOS WHERE ID=xIDIngresos;
END IF;

if xIMPORTE_DEMORA_ENTE is null then
   xIMPORTE_DEMORA_ENTE:=0;
end if;

--Si es un cobro en ventanilla la fecha contable y la real coinciden
IF xF_REAL_INTERESES IS NULL THEN
	xF_REAL_INTERESES:=xF_CONTABLE_INTERESES;
END IF;

INSERT INTO JUNTA_RESULT_T2(
	DESTINO,CLAVE_DEUDA,INDICADOR_PENDIENTE,
	IMPORTE_INICIAL,

	IMPORTE_REHABILITADO,IMPORTE_REACTIVADO,

	IMPORTE_APLICADO_DEUDA,	F_CONTA_ULTIMO_INGRESO,	F_REAL_ULTIMO_INGRESO,

	IMPORTE_ANULACION,
	IMPORTE_INSOLVENCIA,
	IMPORTE_OTRAS_CAUSAS,
	IMPORTE_PRESCRIPCION,

	IMPORTE_INGRESADO_ENTE,

	F_ANULACION,
	F_INSOLVENCIA,
	F_BAJA_OTRAS,
	F_PRESCRIPCION,

	IMPORTE_PENDIENTE,

	IMPORTE_INTERESES_ENTE,
	IMPORTE_INTERESES_DIPU,
	F_CONTA_INTERESES,
	F_REAL_INTERESES,

	IMPORTE_COSTAS_SIN,
	IMPORTE_DISMI_RECARGO)
VALUES
	(xOFILIQ, SubStr(cValores.CLAVE_EXTERNA,1,17), xIndicador, LPAD(xPendientePeri*100,11,'0'),
	xNumero, xNumero,
	DECODE(xIMPORTE_APLICADO_DEUDA,NULL,xNumero,LPAD( (xIMPORTE_APLICADO_DEUDA*100), 11, '0')),

	DECODE(xF_REAL_ULTIMO_INGRESO,NULL,LPAD('0',8,'0'),TO_CHAR(xF_REAL_ULTIMO_INGRESO,'YYYYMMDD')),
	DECODE(xF_REAL_ULTIMO_INGRESO,NULL,LPAD('0',8,'0'),TO_CHAR(xF_REAL_ULTIMO_INGRESO,'YYYYMMDD')),

	xNumero, xNumero, xNumero, xNumero,
	DECODE(xIngreEnte,NULL,xNumero,LPAD(xIngreEnte*100,11,'0')),
	LPAD('0',8,'0'), LPAD('0',8,'0'), LPAD('0',8,'0'), LPAD('0',8,'0'),
	LPAD(xPendienteFinal*100,11,'0'),

	DECODE(xIMPORTE_DEMORA_ENTE,NULL,xNumero,LPAD(xIMPORTE_DEMORA_ENTE*100,11,'0')),

	DECODE(xIMPORTE_INTERESES_DIPU,NULL,xNumero,LPAD(xIMPORTE_INTERESES_DIPU*100,11,'0')),

	DECODE(xF_CONTABLE_INTERESES,NULL,LPAD('0',8,'0'),TO_CHAR(xF_CONTABLE_INTERESES,'YYYYMMDD')),
	DECODE(xF_REAL_INTERESES,NULL,LPAD('0',8,'0'),TO_CHAR(xF_REAL_INTERESES,'YYYYMMDD')),
	LPAD('0',11,'0'),
	LPAD(xAminoraRecargo*100,11,'0') );

end;

-- *******************************************
--
-- Resgistro tipo 2 para las bajas
--
-- Tipos de bajas
-- 'BA' Anulación
-- 'BR' Reposición a voluntaria
-- 'BI' Insolvencia
-- 'BP' Prescripción
-- 'BO' Otros motivos
--
-- *******************************************

PROCEDURE ADD_BAJATIPO_2(xOFILIQ IN Char,
		v_cBaja IN cBAJA%ROWTYPE, cValores IN  T_Valores)

AS

xIndicador Char(1);
xNumero Char(11) default '00000000000';
xPendientePeri Float default 0;

xAnula float default 0;
xInsolvencia float default 0;
xOtros float default 0;
xPrescri float default 0;

xImporteCostasSinImputar Float;
xFAnula		char(8) default '00000000';
xFInsolvencia	char(8) default '00000000';
xFOtros		char(8) default '00000000';
xFPrescripcion	char(8) default '00000000';
xTotalMociones	float default 0;
BEGIN


IF cValores.F_CARGO >= xFechaInicial AND cValores.F_CARGO <=xFechaFinal THEN
   xIndicador:='2';
ELSE
   xIndicador:='1';
END IF;


xPendientePeri:= (cValores.PRINCIPAL + cValores.RECARGO_JUNTA)-cValores.FUERA_PLAZO;

--Descontar las mociones de la Junta
SELECT SUM(PRINCIPAL+RECARGO) INTO xTotalMociones
	FROM INGRESOS
		WHERE VALOR=cValores.ID
		AND FECHA < xFechaInicial
		AND ORGANISMO_EXT='S';

if xTotalMociones is null then
	xTotalMociones:=0;
end if;

xPendientePeri:= xPendientePeri - xTotalMociones;

-- Anulación
IF v_cBaja.TIPO_BAJA='BA' THEN
	xAnula:=(v_cBaja.PRINCIPAL+cValores.RECARGO_JUNTA)*100;
	xFAnula:=TO_CHAR(v_cBaja.FECHA,'YYYYMMDD');
END IF;

-- Insolvencia
IF v_cBaja.TIPO_BAJA='BI' THEN
	xInsolvencia:=(v_cBaja.PRINCIPAL+cValores.RECARGO_JUNTA)*100;
	xFInsolvencia:=TO_CHAR(v_cBaja.FECHA,'YYYYMMDD');
END IF;

-- Otros motivos y reposicion a voluntaria
IF v_cBaja.TIPO_BAJA IN ('BO','BR') THEN
	xOtros:=(v_cBaja.PRINCIPAL+cValores.RECARGO_JUNTA)*100;
	xFOtros:=TO_CHAR(v_cBaja.FECHA,'YYYYMMDD');
END IF;

--Prescripción
IF v_cBaja.TIPO_BAJA='BP' THEN
	xPrescri:=(v_cBaja.PRINCIPAL+cValores.RECARGO_JUNTA)*100;
	xFPrescripcion:=TO_CHAR(v_cBaja.FECHA,'YYYYMMDD');
END IF;

-- Costas que se dan de baja y por lo tnato son imposibles de imputar a la Junta Andalucía.

IF v_cBaja.COSTAS > 0 THEN
   xImporteCostasSinImputar:=v_cBaja.COSTAS*100;
ELSE
   xImporteCostasSinImputar:=0;
END IF;


INSERT INTO JUNTA_RESULT_T2(
	DESTINO,CLAVE_DEUDA,INDICADOR_PENDIENTE,
	IMPORTE_INICIAL,

	IMPORTE_REHABILITADO,IMPORTE_REACTIVADO,

	IMPORTE_APLICADO_DEUDA,	F_CONTA_ULTIMO_INGRESO,	F_REAL_ULTIMO_INGRESO,

	IMPORTE_ANULACION, IMPORTE_INSOLVENCIA,
	IMPORTE_OTRAS_CAUSAS, IMPORTE_PRESCRIPCION,

	IMPORTE_INGRESADO_ENTE,

	F_ANULACION,
	F_INSOLVENCIA,
	F_BAJA_OTRAS,
	F_PRESCRIPCION,

	IMPORTE_PENDIENTE,

	IMPORTE_INTERESES_ENTE,
	IMPORTE_INTERESES_DIPU,
	F_CONTA_INTERESES,
	F_REAL_INTERESES,

	IMPORTE_COSTAS_SIN,
	IMPORTE_DISMI_RECARGO)
VALUES
	(xOFILIQ, SubStr(cValores.CLAVE_EXTERNA,1,17), xIndicador, LPAD(xPendientePeri*100,11,'0'),
	xNumero, xNumero, xNumero, LPAD('0',8,'0'),LPAD('0',8,'0'),

	LPAD(xAnula, 11,'0'), LPAD(xInsolvencia, 11,'0'),
	LPAD(xOtros, 11,'0'), LPAD(xPrescri, 11,'0'),

	xNumero,

	xFAnula, xFInsolvencia, xFOtros, xFPrescripcion,
	xNumero, xNumero, xNumero,
	LPAD('0',8,'0'), LPAD('0',8,'0'), LPAD(xImporteCostasSinImputar,11,'0'), xNumero);

END;


-- *******************************************
--
-- Registro de detalle de ingresos
--
-- El registro tipo 3 está condicionado por el tipo de registro número dos
-- y es en función de si es una entrega a cuenta, una aminoración del principal
-- por ingreso en la Junta
--
-- *******************************************
PROCEDURE ADD_TIPO_3(
		xOFILIQ IN Char,
		xClave IN Char,
		xIndicardor IN Char,
		xImporte IN Float,
		xFReal IN Date,
		xFContable IN Date)
AS
BEGIN

-- Indicador
-- 1 entrega a cuenta sobre principal + recargo
-- 2 entrega a cuenta sobre demora
-- 3 ingreso en la junta sobre principal + recargo
-- 4 ingreso en la junta demora
--

--Fecha real es la del ingreso en banco, si hubiera
--Fecha contable es la fecha de ingreso en la aplicacion
--en caso de ingreso en ventanilla la fecha real y la contable coinciden

INSERT INTO JUNTA_RESULT_T3(
	DESTINO,CLAVE_DEUDA,
	INDICADOR_INGRESO,
	IMPORTE,
	F_REAL,
	F_CONTABLE)
VALUES
	(xOFILIQ, SubStr(xClave, 1, 17), xIndicardor, LPAD(xImporte*100, 11, '0'),
	DECODE(xFReal,NULL,TO_CHAR(xFContable,'YYYYMMDD'),TO_CHAR(xFReal,'YYYYMMDD')),
	TO_CHAR(xFContable,'YYYYMMDD'));

END;

-- *******************************************
--
-- Registro totalizador del soporte
--
-- *******************************************
PROCEDURE NEW_TIPO_7(xOFILIQ IN Char)
AS
BEGIN

INSERT INTO JUNTA_RESULT_T7(DESTINO) VALUES (xOFILIQ);

END;

-- *******************************************
--
-- Totalizar los resultados
--
-- *******************************************
PROCEDURE TOTALIZAR
AS


xDest Char(2);
xT1 INTEGER;
xT2 INTEGER;
xT3 INTEGER;

xImporteDeudas FLOAT;
xCoste FLOAT;
xAnticipado FLOAT;
xImporteInicial FLOAT;
xImporteCargoPeri FLOAT;
xPendienteFinal FLOAT;
xRehabilitado FLOAT;
xReactivado FLOAT;
xApliDeuda FLOAT;
xApliDemora FLOAT;
xImpoInsol FLOAT;
xImpoAnulacion FLOAT;
xImpoOtras FLOAT;
xImpoPrescri FLOAT;
xImpoEnte FLOAT;
xImpoCostas FLOAT;
xImpoDismiReca FLOAT;

-- A cuantas delegaciones hay que enviarles

CURSOR cTOTALES IS SELECT distinct DESTINO FROM JUNTA_RESULT_T0;

CURSOR cDELEGA IS SELECT * FROM JUNTA_RESULT_T7
	ORDER BY DESTINO;

BEGIN


-- Generar los registro de totales

FOR v_cTOTALES IN cTOTALES LOOP

    NEW_TIPO_7(v_cTOTALES.DESTINO);

END LOOP;


FOR v_cDELEGA IN cDELEGA LOOP

	xDest:=v_cDELEGA.DESTINO;


    SELECT COUNT(*),SUM(IMPORTE),SUM(IMPORTE_COSTE),SUM(IMPORTE_ANTICIPADO)
		 INTO xT1,xImporteDeudas,xCoste,xAnticipado FROM JUNTA_RESULT_T1
		WHERE DESTINO=v_cDELEGA.DESTINO;

    SELECT SUM(IMPORTE_INICIAL) INTO xImporteInicial FROM JUNTA_RESULT_T2
		WHERE DESTINO=v_cDELEGA.DESTINO
		AND INDICADOR_PENDIENTE IN ('1','3','4','5');

    SELECT SUM(IMPORTE_INICIAL) INTO xImporteCargoPeri FROM JUNTA_RESULT_T2
		WHERE DESTINO=v_cDELEGA.DESTINO
		AND INDICADOR_PENDIENTE IN ('2','6','7');

    SELECT COUNT(*),SUM(IMPORTE_PENDIENTE),SUM(IMPORTE_REHABILITADO),SUM(IMPORTE_REACTIVADO),
		SUM(IMPORTE_APLICADO_DEUDA),SUM(IMPORTE_INTERESES_DIPU),SUM(IMPORTE_ANULACION),
		SUM(IMPORTE_INSOLVENCIA),SUM(IMPORTE_OTRAS_CAUSAS),SUM(IMPORTE_PRESCRIPCION),
		SUM(IMPORTE_INGRESADO_ENTE),SUM(IMPORTE_COSTAS_SIN),SUM(IMPORTE_DISMI_RECARGO)
		INTO xT2, xPendienteFinal,xRehabilitado,xReactivado,
		xApliDeuda,xApliDemora,
		xImpoAnulacion,xImpoInsol,xImpoOtras,xImpoPrescri,
		xImpoEnte,xImpoCostas,xImpoDismiReca
		FROM JUNTA_RESULT_T2
		WHERE DESTINO=v_cDELEGA.DESTINO;

    SELECT COUNT(*) INTO xT3 FROM JUNTA_RESULT_T3
		WHERE DESTINO=v_cDELEGA.DESTINO;


UPDATE JUNTA_RESULT_T7 SET IMPORTE_DEUDAS=LPAD(xImporteDeudas, 13, '0'),

	IMPORTE_INICIAL=LPAD(xImporteInicial, 13, '0'),

	IMPORTE_FINAL=LPAD(xPendienteFinal, 13, '0'),
	IMPORTE_CARGO=DECODE(xImporteCargoPeri,NULL,LPAD('0', 13, '0'),LPAD(xImporteCargoPeri, 13, '0')),
	IMPORTE_REACTIVADO=LPAD(xReactivado, 13, '0'),
	IMPORTE_REHABILITADO=LPAD(xRehabilitado, 13, '0'),
	IMPORTE_APL_ADEUDA=LPAD(xApliDeuda, 13, '0'),
	IMPORTE_INTERESES=LPAD(xApliDemora, 13, '0'),

	IMPORTE_ANULACION=LPAD(xImpoAnulacion, 13, '0'),
	IMPORTE_INSOLVENCIA=LPAD(xImpoInsol, 13, '0'),
	IMPORTE_BAJAS_OTRAS=LPAD(xImpoOtras, 13, '0'),
	IMPORTE_PRESCRIPCION=LPAD(xImpoPrescri, 13, '0'),
	IMPORTE_INGRESADO_ENTE=LPAD(xImpoEnte, 13, '0'),
	IMPORTE_COSTAS_SIN=LPAD(xImpoCostas, 13, '0'),
	IMPORTE_DISMINUCION_REC=LPAD(xImpoDismiReca, 13, '0'),

	REGISTROS_T1=LPAD(xT1, 7, '0'),
	REGISTROS_T2=LPAD(xT2, 7, '0'),
	REGISTROS_T3=LPAD(xT3, 7, '0'),
	REGISTROS_TOTAL=LPAD((xT1+xT2+xT3+2), 8, '0'),
	TOTAL_COSTE_SERVICIO=LPAD(xCoste, 13, '0'),
	TOTAL_ANTICIPADO=LPAD(xAnticipado, 13, '0')

	WHERE DESTINO=v_cDELEGA.DESTINO;

END LOOP;


END;

--
--
--
PROCEDURE ADD_ANEXO_I(xOFILIQ IN Char, xImporte in float, xTipo in char)
AS
xCuantos integer default 0;
xPendiente float default 0;
CURSOR cTOTALES IS SELECT distinct DESTINO FROM JUNTA_RESULT_T0;
BEGIN

	IF xTIPO='G' THEN
		UPDATE JUNTA_ANEXO1 set NUMERO_CERTIFI_CONINGRESOS=NUMERO_CERTIFI_CONINGRESOS+1,
			GESTIONADO_INGRESOS=GESTIONADO_INGRESOS+xIMPORTE
		WHERE DESTINO=xOFILIQ;

		IF SQL%NOTFOUND THEN
			INSERT INTO JUNTA_ANEXO1
			(DESTINO,NUMERO_CERTIFI_CONINGRESOS,GESTIONADO_INGRESOS)
			VALUES (xOFILIQ,1,xIMPORTE);
		END IF;
	END IF;


	IF xTIPO='E' THEN

		for vTotales in cTotales loop

			select count(*),sum(principal+recargo) into xCuantos,xPendiente
			from valores v, valores_as400 a
			where v.id=a.valor and a.oficina_liqui=vTotales.Destino
			and F_CARGO <= xFechaFinal
			and (f_ingreso is null or f_ingreso>xFechaFinal)
			and (fecha_de_baja is null or fecha_de_baja>xFechaFinal);

			UPDATE JUNTA_ANEXO1 set NUMERO_ENTREGAS=xCuantos,
					IMPORTE_PENDIENTE_FP=xPendiente
			WHERE DESTINO=vTotales.Destino;

			IF SQL%NOTFOUND THEN
				INSERT INTO JUNTA_ANEXO1 (DESTINO,NUMERO_ENTREGAS,IMPORTE_PENDIENTE_FP)
				VALUES (vTotales.Destino,xCuantos,xPendiente);
			END IF;

		end loop;

	END IF;

END;

--
-- ORGANISMO_EXT<>'A' antes del cargo es decir el fuera de plazo. Tiene que restar
-- del pendiente.
--
PROCEDURE PENDIENTE_A_FECHA(
			xVALOR IN INTEGER,
			xFECHA IN DATE,
			xPRINCIPAL OUT FLOAT,
			xRECARGO OUT FLOAT)
AS
xPRIN_VALOR		FLOAT DEFAULT 0;
xRECARGO_VALOR 	FLOAT DEFAULT 0;
BEGIN

		SELECT PRINCIPAL,RECARGO INTO xPRIN_VALOR,xRECARGO_VALOR
		FROM VALORES
			WHERE ID=xVALOR;

		SELECT SUM(PRINCIPAL),SUM(RECARGO) INTO xPRINCIPAL,xRECARGO
		FROM INGRESOS
			WHERE VALOR=xVALOR
			AND FECHA < xFECHA;

		IF xPRINCIPAL IS NULL THEN
			xPRINCIPAL:=0;
		END IF;

		IF xRECARGO IS NULL THEN
			xRECARGO:=0;
		END IF;

		xPRINCIPAL := xPRIN_VALOR - xPRINCIPAL;
		xRECARGO   := xRECARGO_VALOR - xRECARGO;

END;

/* ************************************************************ */
/* INICIALIZACION DEL PAQUETE.
BEGIN*/


END;
/
