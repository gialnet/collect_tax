--
-- Amortizaciones de capital
--
-- Las amotizaciones podrán ser conjuntas con las liquidaciones de ingresos y premio
-- de cobranza, en periodos de tiempo, diarias, semanales, mensuales,trimestrales,
-- semestrales o anuales.
--
--
CREATE OR REPLACE PACKAGE PkAmortizaciones
AS

xCapital Float;

-- número de días para la amortización los bancos utilizan 360 día para trimestres de
-- 90 días, si a esta variable se le pone el valor de 365 se utilizará el valor real
-- es decir el no bancario.

xNDiasYear Integer default 360;
xInteresCompuesto Boolean default true;

function InteresAnual(xCapital In Float, xInteres IN Float) return float;

function InteresDiario(xCapital In Float, xInteres IN Float) return float;

Function Amortizar(xNDias IN Integer, xCapital IN Float, xInteres IN Float) return float;

function GetMaxFechaTrimestre(xQuarter Char, xIDAnti IN Integer) return date;

-- Para todos los aytos
PROCEDURE AmortizarAnticipos(xFDesde IN Date, xFHasta IN Date);

-- Para un ayto determinado
PROCEDURE AmortizarAnticiposAyto(xAyto In Char, xFDesde IN Date, xFHasta IN Date);

-- Saldo meio pendiente en el intervalo de fechas
function SaldoMedio(xAYTO IN CHAR, xPendiente IN Float, xFDesde IN Date, xFHasta IN Date) return Float;

procedure EspecialDipuGranada2002(xIDAnti IN Integer);

END;
/


-- ************************************************************************************
-- 									CUERPO DEL PAQUETE
-- ************************************************************************************
CREATE OR REPLACE PACKAGE BODY PkAmortizaciones
AS

--
-- Devuelve el interés anual de un capital
--
function InteresAnual(xCapital In Float, xInteres IN Float) return float
as
begin

return xCapital*xInteres/100;

end;

--
-- Devuelve el interés diario de un capital
--
function InteresDiario(xCapital In Float, xInteres IN Float) return float
as
begin

return (xCapital*xInteres/100)/xNDiasYear;

end;


--
-- Amortizar
--
Function Amortizar(xNDias IN Integer, xCapital IN Float, xInteres IN Float)
	return float
as
begin

return InteresDiario(xCapital, xInteres) * xNDias;

end;

--
-- Para todos los aytos
--
-- xFHasta indica hasta que fecha se deben calcular
-- los intereses de los anticipos/descuentos.
--
PROCEDURE AmortizarAnticipos(xFDesde IN Date, xFHasta IN Date)
AS

xCapitalAmortiza Float default 0;
xSumaInteres Float default 0;
xDias		Integer;

-- 	Si el anticipo es posterior a la liquidación, no se tiene en cuenta

CURSOR cANTICIPOS IS SELECT ID,TIPO,PENDIENTE,TRUNC(FECHA,'DD') AS FECHA,AYTO
	FROM ANTICIPOS
		WHERE TRUNC(FECHA,'DD') < xFHasta
			AND ESTADO = 'P'
		ORDER BY AYTO,PRIORIDAD
		for update of Pendiente;

--
-- Posibles tipos de interés en el intervalo de amortización
--
CURSOR cTiposInteres IS SELECT INTERES,FECHA_FIN,FECHA_INICIO
		FROM INTERES_ANTICIPOS
		WHERE (FECHA_INICIO < xFHasta AND FECHA_FIN > xFDesde)
		OR (FECHA_FIN IS NULL AND FECHA_INICIO < xFHasta)
	ORDER BY FECHA_INICIO;


BEGIN


	FOR v_Anti IN cANTICIPOS LOOP

		xSumaInteres := 0;
		-- Calcula la amortización para los distintos intervalos de tipos de interés
		FOR vCTiposInteres IN cTiposInteres LOOP

			select  decode(vCTiposInteres.FECHA_FIN, Null,
							xFHasta, vCTiposInteres.FECHA_FIN) - v_Anti.FECHA into xDias
					from dual;

			xCapitalAmortiza:= v_Anti.Pendiente - SaldoMedio(v_Anti.Ayto, v_Anti.Pendiente, xFDesde, xFHasta);

			xSumaInteres := xSumaInteres +
				Amortizar(xDias, xCapitalAmortiza, vCTiposInteres.Interes);

			-- actualizamos el histórico de anticipos
			INSERT INTO HISTORICO_ANTICIPOS
				(ANTICIPO, FDESDE, FHASTA, PENDIENTE, INTERESES,
					CAPITAL_AMORTIZADO, DIAS, TIPO)
			VALUES
				(v_Anti.ID, xFDesde, xFHasta, v_Anti.Pendiente, xSumaInteres,
				xCapitalAmortiza, xDias, vCTiposInteres.Interes);

		END LOOP;

		--
		-- Sumamos los intereses de la amortización a la deuda
		-- si el interes es compuesto
		--
		if xInteresCompuesto then
			Update Anticipos Set Pendiente=Pendiente+xSumaInteres
				where current of cANTICIPOS;
		end if;

	END LOOP;


END;


--
-- xFHasta indica hasta que fecha se deben calcular
-- los intereses de los anticipos/descuentos.
--
PROCEDURE AmortizarAnticiposAyto(xAyto In Char, xFDesde IN Date, xFHasta IN Date)
AS


xSumaInteres Float default 0;
xDias		Integer;
xCapitalAmortiza Float default 0;

-- 	Si el anticipo es posterior a la liquidación, no se tiene en cuenta

CURSOR cANTICIPOS IS SELECT ID,TIPO,PENDIENTE,TRUNC(FECHA,'DD') AS FECHA
	 FROM ANTICIPOS
		WHERE AYTO=xAYTO
			AND TRUNC(FECHA,'DD') < xFHasta
			AND ESTADO = 'P'
		ORDER BY PRIORIDAD for update of Pendiente;

--
-- Posibles tipos de interés en el intervalo de amortización
--
CURSOR cTiposInteres IS SELECT INTERES,FECHA_FIN,FECHA_INICIO
		FROM INTERES_ANTICIPOS
		WHERE (FECHA_INICIO < xFHasta AND FECHA_FIN > xFDesde)
		OR (FECHA_FIN IS NULL AND FECHA_INICIO < xFHasta)
	ORDER BY FECHA_INICIO;


BEGIN


	FOR v_Anti IN cANTICIPOS LOOP

		xSumaInteres := 0;
		-- Calcula la amortización para los distintos intervalos de tipos de interés
		FOR vCTiposInteres IN cTiposInteres LOOP

			select  decode(vCTiposInteres.FECHA_FIN, Null,
							xFHasta, vCTiposInteres.FECHA_FIN) - v_Anti.FECHA into xDias
					from dual;

			xCapitalAmortiza:= v_Anti.Pendiente - SaldoMedio(xAyto, v_Anti.Pendiente, xFDesde, xFHasta);

			xSumaInteres := xSumaInteres +
				Amortizar(xDias, xCapitalAmortiza, vCTiposInteres.Interes);

			-- actualizamos el histórico de anticipos
			INSERT INTO HISTORICO_ANTICIPOS
				(ANTICIPO, FDESDE, FHASTA, PENDIENTE, INTERESES,
					CAPITAL_AMORTIZADO, DIAS, TIPO)
			VALUES
				(v_Anti.ID, xFDesde, xFHasta, v_Anti.Pendiente, xSumaInteres,
				xCapitalAmortiza, xDias, vCTiposInteres.Interes);

		END LOOP;


		--
		-- Sumamos los intereses de la amortización a la deuda
		-- si el interes es compuesto
		--
		if xInteresCompuesto then
			Update Anticipos Set Pendiente=Pendiente+xSumaInteres
				where current of cANTICIPOS;
		end if;

	END LOOP;


END;


--
-- Saldo medio dispuesto en el intervalo de fechas
-- nos devolverá un valor que será un porcentaje del pendiente anticipado
--
function SaldoMedio(xAYTO IN CHAR, xPendiente IN Float, xFDesde IN Date, xFHasta IN Date) return Float
as

xCuantos Integer default 0;
xSuma Float default 0;
xSumPendiente Float default 0;
xSumPendienteIni Float;
xMediaDispuesto Float default 0;
xPorDis Float default 0;

CURSOR cINGRESOS IS SELECT TRUNC(FECHA, 'DD') AS INTERVALO,
		SUM(PRINCIPAL+RECARGO+COSTAS+DEMORA) AS TOTAL
		FROM INGRESOS
		WHERE AYTO=xAYTO
		AND TRUNC(FECHA, 'DD') BETWEEN xFDesde AND xFHasta
		AND ORGANISMO_EXT='N'
		AND TIPO_INGRESO NOT IN ('CM','EC')
		GROUP BY TRUNC(FECHA, 'DD');

begin


-- Sumamos el pendiente en el intervalo

SELECT SUM(PENDIENTE) INTO xSumPendiente
	 FROM ANTICIPOS
		WHERE AYTO=xAYTO
			AND TRUNC(FECHA,'DD') < xFHasta
			AND ESTADO = 'P';

xSumPendienteIni:=xSumPendiente;

-- Si da nulo es por que ya no se debe nada
-- nos salimos con cero
IF xSumPendiente IS NULL THEN
   return 0;
END IF;

FOR v_cINGRESOS IN cINGRESOS LOOP

	xCuantos:=xCuantos+1;
	xSumPendiente:= xSumPendiente - v_cINGRESOS.Total;
	xSuma:= xSuma + xSumPendiente;

END LOOP;

IF xCuantos > 0 THEN

	-- La media del capital dispuesto en el intervalo de fechas
	xMediaDispuesto:=xSuma/xCuantos;

	-- regla de tres para saber si xSumPendiente es el 100% de lo pendiente
	-- xMediaDispuesto será el x %
	--
	-- porcentaje dispuesto sobre el 100% de la deuda
	--
	xPorDis:=100 - (xMediaDispuesto * 100 / xSumPendienteIni);

	-- devolvemos el porcentaje de lo que le corresponde a este anticipo
   return Round((xPendiente * xPorDis /100), 2);

ELSE
   return 0;
END IF;

end;


--
-- Función recursiva que nos da la mayor de las fechas de un adelanto
--
function GetMaxFechaTrimestre(xQuarter Char, xIDAnti IN Integer) return date
as
xFecha Date;
begin

if xQuarter='1' then

	select max(fecha) into xFecha from HISTORICO_ANTICIPOS
	where anticipo=xIDAnti
	and fecha between '01/01/2002' and '31/03/2002';

	if xFecha is null then
	   return xFecha;
	end if;

end if;

if xQuarter='2' then

	select max(fecha) into xFecha from HISTORICO_ANTICIPOS
	where anticipo=xIDAnti
	and fecha between '01/04/2002' and '30/06/2002';

	if xFecha is null then
	   xFecha:=GetMaxFechaTrimestre('1', xIDAnti);
	else
	   return xFecha;
	end if;

end if;

if xQuarter='3' then

	select max(fecha) into xFecha from HISTORICO_ANTICIPOS
	where anticipo=xIDAnti
	and fecha between '01/07/2002' and '30/09/2002';

	if xFecha is null then
	   xFecha:=GetMaxFechaTrimestre('2', xIDAnti);
	else
	   return xFecha;
	end if;

end if;

if xQuarter='4' then

	select max(fecha) into xFecha from HISTORICO_ANTICIPOS
	where anticipo=xIDAnti
	and fecha between '01/10/2002' and '31/12/2002';

	if xFecha is null then
	   xFecha:=GetMaxFechaTrimestre('3', xIDAnti);
	else
	   return xFecha;
	end if;


end if;


return xFecha;

end;


--
--
--
procedure EspecialDipuGranada2002(xIDAnti IN Integer)
as

xSaldo float default 0;
nDias Integer default 0;
xFecha Date;
xTipoInteres	float default 0;
xIntereses		float default 0;
xFind boolean default false;

cursor cAnti IS Select * from HISTORICO_ANTICIPOS
	where anticipo=xIDAnti
	order by fecha for update of PENDIENTE,DIAS,TIPO,INTERESES;

cursor cAntiDes IS Select * from HISTORICO_ANTICIPOS
	where anticipo=xIDAnti
	order by fecha desc for update of DIAS,TIPO,INTERESES;

begin

--
-- Calcular los Saldos
--

for v_cAnti in cAnti loop

    if v_cAnti.movimiento='PR' then
       xSaldo:= xSaldo + v_cAnti.Importe;
    end if;

    if v_cAnti.movimiento='RE' then
       xSaldo:= xSaldo - v_cAnti.Importe;
    end if;

    update HISTORICO_ANTICIPOS SET PENDIENTE=xSaldo
    	where current of cAnti;

end loop;

--
-- Para el primer trimestre
--
--

xFecha:=GetMaxFechaTrimestre('1', xIDAnti);

if xFecha is not null then

	select max(pendiente) into xSaldo from HISTORICO_ANTICIPOS
		where anticipo=xIDAnti and fecha = xFecha;

	if xSaldo > 0 and xFecha<>to_date('31/03/2002','DD/MM/YYYY') then
   		INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,MOVIMIENTO,FECHA,IMPORTE,PENDIENTE)
		VALUES (xIDAnti, 'IN', '31/03/2002' , 0, xSaldo);
	end if;

end if;

--
-- Para el segundo trimestre
--
--
xFecha:=GetMaxFechaTrimestre('2', xIDAnti);

if xFecha is not null then
	select max(pendiente) into xSaldo from HISTORICO_ANTICIPOS
		where anticipo=xIDAnti and fecha = xFecha;

	if xSaldo > 0 and xFecha<>to_date('30/06/2002','DD/MM/YYYY') then
   		INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,MOVIMIENTO,FECHA,IMPORTE,PENDIENTE)
		VALUES (xIDAnti, 'IN', '30/06/2002', 0, xSaldo);
	end if;
end if;

--
-- Para el tercer trimestre
--
--
xFecha:=GetMaxFechaTrimestre('3', xIDAnti);

if xFecha is not null then

	select max(pendiente) into xSaldo from HISTORICO_ANTICIPOS
		where anticipo=xIDAnti and fecha = xFecha;

	if xSaldo > 0 and xFecha<>to_date('30/09/2002','DD/MM/YYYY') then
   		INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,MOVIMIENTO,FECHA,IMPORTE,PENDIENTE)
		VALUES (xIDAnti, 'IN', '30/09/2002', 0, xSaldo);
	end if;

end if;

--
-- Para el cuarto trimestre 
--
--
xFecha:=GetMaxFechaTrimestre('4', xIDAnti);

if xFecha is not null then

	select max(pendiente) into xSaldo from HISTORICO_ANTICIPOS
		where anticipo=xIDAnti and fecha = xFecha;

	if xSaldo > 0 and xFecha<>to_date('31/12/2002','DD/MM/YYYY') then
   		INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,MOVIMIENTO,FECHA,IMPORTE,PENDIENTE)
		VALUES (xIDAnti, 'IN', '31/12/2002', 0, xSaldo);
	end if;

end if;


--
-- Días transcurridos desde un movimiento hasta otro
--
xFecha:=null;

for v_cAntiDes in cAntiDes loop

	if xFecha is not null then

		nDias:=xFecha - v_cAntiDes.FECHA;

		if v_cAntiDes.movimiento='IN' then
		   nDias:=nDias-1;
		   xFind:=True;
		end if;

		if v_cAntiDes.movimiento<>'IN' and xFind then
		   nDias:=nDias+1;
		   xFind:=False;
		end if;

		if v_cAntiDes.Pendiente > 0 then

/*		   if v_cAntiDes.movimiento<>'IN' then
			  select interes into xTipoInteres from INTERES_ANTICIPOS
			  WHERE v_cAntiDes.FECHA >= FECHA_INICIO AND v_cAntiDes.FECHA <= FECHA_FIN;
			  
		   else
		      if trunc(v_cAntiDes.FECHA,'dd')=to_date('31/12/2002','dd/mm/yyyy') then
			     xTipoInteres:=3.44;
			  else
   			     select interes into xTipoInteres from INTERES_ANTICIPOS
			     WHERE v_cAntiDes.FECHA >= FECHA_INICIO AND v_cAntiDes.FECHA <= FECHA_FIN;
			  end if;
		   end if;
*/
		   if v_cAntiDes.movimiento<>'IN' or trunc(v_cAntiDes.FECHA,'dd')=to_date('31/12/2002','dd/mm/yyyy') then
		   	  select interes into xTipoInteres from INTERES_ANTICIPOS
			  WHERE v_cAntiDes.FECHA >= FECHA_INICIO AND v_cAntiDes.FECHA <= FECHA_FIN;
		   else 
		   	  select interes into xTipoInteres from INTERES_ANTICIPOS
			  WHERE v_cAntiDes.FECHA < FECHA_INICIO AND rownum=1 order by FECHA_INICIO;
		   end if;
			  
		   xIntereses:=Round(Amortizar(nDias, v_cAntiDes.Pendiente, xTipoInteres),2);
		else
			xIntereses:=0;
		end if;

    	update HISTORICO_ANTICIPOS SET DIAS=nDias,intereses=xIntereses
    		where current of cAntiDes;

    else
    	--Saldo final antes de intereses
    	xSaldo:=v_cAntiDes.Pendiente;
    end if;

	xFecha:=v_cAntiDes.FECHA;

end loop;



select sum(intereses) into xIntereses from HISTORICO_ANTICIPOS
where anticipo=xIDAnti;

INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,MOVIMIENTO,FECHA,IMPORTE,PENDIENTE)
VALUES (xIDAnti, 'CI', '31/12/2002', xIntereses, xSaldo+xIntereses);

end;


END;
/
