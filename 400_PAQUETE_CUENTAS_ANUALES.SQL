CREATE OR REPLACE PACKAGE PkCuentasAnuales
AS


-- Leer el pendiente inicial de toda la gestión si no hay datos del año anterior
PROCEDURE PendienteUnoEnero(xYEAR IN CHAR);

-- Leer el pendiente inicial de un municipio si no hay datos del año anterior 
PROCEDURE PendienteUnoEneroAyto(xYEAR IN CHAR, xAYTO IN CHAR);

-- Leer el pendiente inicial de una zona si no hay datos del año anterior
PROCEDURE PendienteUnoEneroZona(xYEAR IN CHAR, xZona IN CHAR);

-- Quitar las entregas a cuenta al pendiente de toda la gestión (si no hay datos año anterior)
PROCEDURE RemoveEntregas(xYear IN char);

-- Quitar las entregas a cuenta al pendiente de un Ayto (si no hay datos año anterior)
PROCEDURE RemoveEntregasAyto(xYear IN char, xAyto IN CHAR);

-- Quitar las entregas a cuenta al pendiente de una Zona (si no hay datos año anterior)
PROCEDURE RemoveEntregasZona(xYear IN char, xZONA IN CHAR);

-- Leer el pendiente inicial de toda la gestión si hay datos del año anterior.
PROCEDURE Pendiente1EneroSinCalcular(xYear IN CHAR, xAyto IN CHAR, xZona IN CHAR);

-- Cargos en Voluntaria
PROCEDURE CargosVoluntaria(xYear IN Char);

-- Cargos en ejecutiva
PROCEDURE CargosEjecutiva(xYear IN Char);

-- Lee los ingresos
PROCEDURE LeeIngresos(xYear IN Char);

PROCEDURE LeeZonaIngresos(xYear IN Char, xZona In char);

-- Lee los ingresos sin recargo, ejecutiva sin recargo
PROCEDURE LeeIngresosSinRecargo(xYear IN Char);

PROCEDURE LeeZonaIngresosSinRecargo(xYear IN Char, xZona IN char);

-- Leer los importres de las bajas
PROCEDURE LeeBajas(xYear IN Char);

PROCEDURE LeeZonaBajas(xYear IN Char, xZona IN char);

-- Leer las bonificaciones de los valores pendientes a 31 de diciembre
PROCEDURE BonifiPendienteUnoEnero(xYEAR IN CHAR);

PROCEDURE BonifiPendienteUnoEneroZona(xYEAR IN CHAR, xZona IN CHAR);

END;
/

-- ---------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PkCuentasAnuales
AS

--
-- Lee el pendiente inicial de un determinado año. 
-- Se llama sólo si el año anterior no hay datos. 
--
PROCEDURE PendienteUnoEnero(xYEAR IN CHAR)
AS

  xFechaIni	DATE;
  xCadena 	Char(30);
  xZona		Char(2);

-- PENDIENTE AL 1 DE ENERO DEL AÑO AGRUPADO POR CONCEPTO AÑO DE CONTRAIDO Y AYTO.

  CURSOR cPENDIENTE IS
    SELECT SUM(PRINCIPAL) AS SUMPRINCIPAL, SUM(RECARGO) AS SUMRECARGO,
  	  SUM(COSTAS) AS SUMCOSTAS, SUM(DEMORA_PENDIENTE) AS SUMDEMORA,
	  PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO
    FROM VALORES
    WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
        AND F_CARGO < xFechaIni
    GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO;

BEGIN


  xCadena:='01/01/'||xYear||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  -- Pendiente al 1 de enero.

  FOR v_cPENDIENTE IN cPENDIENTE LOOP

    SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_cPENDIENTE.AYTO;

    Insert Into Cuentas_anuales
            (vYear,Padron,Principal,Recargo,
             Costas,Demora,TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
    values
        (xYear,v_cPENDIENTE.Padron,v_cPENDIENTE.SUMPrincipal,v_cPENDIENTE.SUMRecargo,
	  v_cPENDIENTE.SUMCostas, v_cPENDIENTE.SUMDemora,'PE',
	  v_cPENDIENTE.YEAR_CONTRAIDO,v_cPENDIENTE.TIPO_DE_OBJETO,xZONA,v_cPENDIENTE.AYTO);

  END LOOP;
  
END;

-- ---------------------------------------------------------------------------------------
-- Lee el pendiente inicial de un determinado año de un Ayto
-- Se llama sólo si el año anterior no hay datos. 
--
PROCEDURE PendienteUnoEneroAyto(xYEAR IN CHAR, xAYTO IN CHAR)
AS

  xFechaIni 	DATE;
  xCadena 	Char(30);
  xZona		Char(2);

-- PENDIENTE AL 1 DE ENERO DEL AÑO AGRUPADO POR CONCEPTO AÑO DE CONTRAIDO Y AYTO.

  CURSOR cPENDIENTE IS
    SELECT SUM(PRINCIPAL) AS SUMPRINCIPAL, SUM(RECARGO) AS SUMRECARGO,
	  SUM(COSTAS) AS SUMCOSTAS, SUM(DEMORA_PENDIENTE) AS SUMDEMORA,
	  PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO
    FROM VALORES
    WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
      AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
      AND F_CARGO < xFechaIni
	  AND AYTO=xAYTO
    GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO;
    
BEGIN

  xCadena:='01/01/'||xYear||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  -- Pendiente al 1 de enero.

  FOR v_cPENDIENTE IN cPENDIENTE LOOP

    SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_cPENDIENTE.AYTO;

    Insert Into Cuentas_anuales
            (vYear,Padron,Principal,Recargo,
             Costas,Demora,TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
    values
        (xYear,v_cPENDIENTE.Padron,v_cPENDIENTE.SUMPrincipal,v_cPENDIENTE.SUMRecargo,
	  v_cPENDIENTE.SUMCostas, v_cPENDIENTE.SUMDemora,'PE',
	  v_cPENDIENTE.YEAR_CONTRAIDO,v_cPENDIENTE.TIPO_DE_OBJETO,xZONA,v_cPENDIENTE.AYTO);

  END LOOP;

END;

-- ---------------------------------------------------------------------------------------
-- Lee el pendiente inicial de un determinado año de una Zona
-- Se llama sólo si el año anterior no hay datos. 
--
PROCEDURE PendienteUnoEneroZona(xYEAR IN CHAR, xZona IN CHAR)
AS

  xFechaIni DATE;
  xCadena 	Char(30);

  -- PENDIENTE AL 1 DE ENERO DEL AÑO AGRUPADO POR CONCEPTO AÑO DE CONTRAIDO Y AYTO.

  CURSOR cPENDIENTE IS
    SELECT SUM(PRINCIPAL) AS SUMPRINCIPAL, SUM(RECARGO) AS SUMRECARGO,
	  SUM(COSTAS) AS SUMCOSTAS, SUM(DEMORA_PENDIENTE) AS SUMDEMORA,
	  PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO
    FROM VALORES
    WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
      AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
      AND F_CARGO < xFechaIni
	  AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=xZona)
    GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO;

BEGIN
  
  xCadena:='01/01/'||xYear||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  -- Pendiente al 1 de enero.

  FOR v_cPENDIENTE IN cPENDIENTE LOOP

    Insert Into Cuentas_anuales
            (vYear,Padron,Principal,Recargo,
             Costas,Demora,TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
    values
        (xYear,v_cPENDIENTE.Padron,v_cPENDIENTE.SUMPrincipal,v_cPENDIENTE.SUMRecargo,
	  v_cPENDIENTE.SUMCostas, v_cPENDIENTE.SUMDemora,'PE',
	  v_cPENDIENTE.YEAR_CONTRAIDO,v_cPENDIENTE.TIPO_DE_OBJETO,xZONA,v_cPENDIENTE.AYTO);

  END LOOP;

END;

-- ---------------------------------------------------------------------------------------
-- Quitar al pendiente las entregas a cuenta de los recibos pendientes
-- Modificación: 09/01/2003 Lucas Fernández Pérez. No se han de seleccionar ingresos de la
-- 			  Junta (Organismo_Ext='A')
-- Se llama sólo si el año anterior no hay datos. 
--
PROCEDURE RemoveEntregas(xYear IN char)
AS

  xFechaIni 	DATE;
  xCadena 	Char(30);

  -- Las entregas a cuenta

  CURSOR cEntregas IS
   Select SUM(I.PRINCIPAL) AS SUMPRINCIPAL ,SUM(I.RECARGO) AS SUMRECARGO,
	SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
	V.PADRON, V.TIPO_DE_OBJETO, I.YEAR_CONTRAIDO,V.AYTO
   FROM Ingresos I, VALORES V
   WHERE I.VALOR=V.ID
      AND I.PARCIAL_O_COBRO='P'
	  AND I.ORGANISMO_EXT<>'A'
      AND I.year_ingre  <= xYear-1
      AND ((V.F_INGRESO IS NULL OR V.F_INGRESO >= xFechaIni)
      AND (V.FECHA_DE_BAJA IS NULL OR V.FECHA_DE_BAJA >= xFechaIni) )
      AND V.F_CARGO < xFechaIni
      GROUP BY V.PADRON,V.TIPO_DE_OBJETO,I.YEAR_CONTRAIDO,V.AYTO;

BEGIN

  xCadena:='01/01/'||xYear||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  FOR v_cEntregas IN cEntregas LOOP

	-- Descontamos las entregas a cuenta del pendiente a 1 de enero

	update Cuentas_anuales set Principal = Principal - v_cEntregas.SUMPrincipal,
			Recargo=Recargo - v_cEntregas.SUMRecargo,
			Costas=Costas - v_cEntregas.SUMCostas,
			Demora=Demora - v_cEntregas.SUMDemora
		where vYear=xYear
		AND PADRON=v_cEntregas.PADRON
		AND TIPO_RECIBO=v_cEntregas.TIPO_DE_OBJETO
		AND AYTO=v_cEntregas.AYTO
		AND CONTRAIDO=v_cEntregas.YEAR_CONTRAIDO
		AND TIPO='PE';

  END LOOP;

END;

-- ---------------------------------------------------------------------------------------
-- Quitar al pendiente las entregas a cuenta de los recibos pendientes de un Ayto
-- Modificación: 09/01/2003 Lucas Fernández Pérez. No se han de seleccionar ingresos de la
-- 			  Junta (Organismo_Ext='A')
-- Se llama sólo si el año anterior no hay datos. 
--
PROCEDURE RemoveEntregasAyto(xYear IN char, xAyto IN CHAR)
AS

  xFechaIni 	DATE;
  xCadena 	Char(30);


  -- Las entregas a cuenta

  CURSOR cEntregas IS
   Select SUM(I.PRINCIPAL) AS SUMPRINCIPAL ,SUM(I.RECARGO) AS SUMRECARGO,
	SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
	V.PADRON,V.TIPO_DE_OBJETO,I.YEAR_CONTRAIDO,V.AYTO
   FROM Ingresos I, VALORES V
   WHERE I.VALOR=V.ID
      AND I.PARCIAL_O_COBRO='P'
	  AND I.ORGANISMO_EXT<>'A'
      AND I.year_ingre  <= xYear-1
      AND ((V.F_INGRESO IS NULL OR V.F_INGRESO >= xFechaIni)
      AND (V.FECHA_DE_BAJA IS NULL OR V.FECHA_DE_BAJA >= xFechaIni) )
      AND V.F_CARGO < xFechaIni
	AND V.AYTO=xAYTO
      GROUP BY V.PADRON,V.TIPO_DE_OBJETO,I.YEAR_CONTRAIDO,V.AYTO;

BEGIN

  xCadena:='01/01/'||xYear||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  FOR v_cEntregas IN cEntregas LOOP

	-- Descontamos las entregas a cuenta del pendiente a 1 de enero

	update Cuentas_anuales set Principal = Principal - v_cEntregas.SUMPrincipal,
			Recargo=Recargo - v_cEntregas.SUMRecargo,
			Costas=Costas - v_cEntregas.SUMCostas,
			Demora=Demora - v_cEntregas.SUMDemora
		where vYear=xYear
		AND PADRON=v_cEntregas.PADRON
		AND TIPO_RECIBO=v_cEntregas.TIPO_DE_OBJETO
		AND AYTO=v_cEntregas.AYTO
		AND CONTRAIDO=v_cEntregas.YEAR_CONTRAIDO
		AND TIPO='PE';

  END LOOP;

END;

-- -----------------------------------------------------------------------------------
-- Quitar al pendiente las entregas a cuenta de los recibos pendientes DE UNA ZONA
-- Modificación: 09/01/2003 Lucas Fernández Pérez. No se han de seleccionar ingresos de la
-- 			  Junta (Organismo_Ext='A')
-- Se llama sólo si el año anterior no hay datos. 
--
PROCEDURE RemoveEntregasZona(xYear IN char, xZONA IN CHAR)
AS

  xFechaIni 	DATE;
  xCadena 	Char(30);

-- Las entregas a cuenta
  CURSOR cEntregas IS
   Select SUM(I.PRINCIPAL) AS SUMPRINCIPAL ,SUM(I.RECARGO) AS SUMRECARGO,
	SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
	V.PADRON,V.TIPO_DE_OBJETO,I.YEAR_CONTRAIDO,V.AYTO
   FROM Ingresos I, VALORES V
   WHERE I.VALOR=V.ID
      AND I.PARCIAL_O_COBRO='P'
	  AND I.ORGANISMO_EXT<>'A'
      AND I.year_ingre  <= xYear-1
      AND ((V.F_INGRESO IS NULL OR V.F_INGRESO >= xFechaIni)
      AND (V.FECHA_DE_BAJA IS NULL OR V.FECHA_DE_BAJA >= xFechaIni) )
      AND V.F_CARGO < xFechaIni
	AND V.AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=xZona)
      GROUP BY V.PADRON,V.TIPO_DE_OBJETO,I.YEAR_CONTRAIDO,V.AYTO;

BEGIN

  xCadena:='01/01/'||xYear||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  FOR v_cEntregas IN cEntregas LOOP

	-- Descontamos las entregas a cuenta del pendiente a 1 de enero

	update Cuentas_anuales set Principal = Principal - v_cEntregas.SUMPrincipal,
			Recargo=Recargo - v_cEntregas.SUMRecargo,
			Costas=Costas - v_cEntregas.SUMCostas,
			Demora=Demora - v_cEntregas.SUMDemora
		where vYear=xYear
		AND PADRON=v_cEntregas.PADRON
		AND TIPO_RECIBO=v_cEntregas.TIPO_DE_OBJETO
		AND AYTO=v_cEntregas.AYTO
		AND CONTRAIDO=v_cEntregas.YEAR_CONTRAIDO
		AND TIPO='PE';

  END LOOP;

END;

-- -----------------------------------------------------------------------------------
-- 12/01/2004. Lucas Fernández Pérez.
-- Lee el pendiente inicial de un determinado año. 
-- Se llama sólo si el año anterior hay datos. Obtiene el pendiente a uno de enero de 
-- este año a través de los datos que hay del año anterior en la tabla CUENTAS_ANUALES.
--
PROCEDURE Pendiente1EneroSinCalcular(xYear IN CHAR, xAyto IN CHAR, xZONA IN CHAR)
AS
  xCuantos      integer;
  xSumPrincipal float;
  xPendiente 	float;

  cursor cPendiAntes is 
    SELECT PADRON,TIPO_RECIBO,CONTRAIDO,AYTO,ZONA, sum(principal) as principal
    FROM CUENTAS_ANUALES
    WHERE VYEAR=TO_CHAR(TO_NUMBER(xYear)-1) and TIPO in ('PE','CV','CE')
    		and ZONA=DECODE(xZona,'',ZONA,xZona) and AYTO=DECODE(xAyto,'',AYTO,xAyto)
	GROUP BY PADRON,TIPO_RECIBO,CONTRAIDO,AYTO,ZONA;
	
BEGIN

  -- Miro lo pendiente el año anterior en la tabla cuentas_anuales.
  FOR vPendiAntes IN cPendiAntes LOOP
  
  	-- Obtengo lo ingresado y dado de baja el año anterior.
	SELECT count(*),sum(principal+bonificado)
	INTO xCuantos, xSumPrincipal
	FROM CUENTAS_ANUALES 
	WHERE VYEAR=TO_CHAR(TO_NUMBER(xYear)-1) and TIPO not in ('PE','PB','CV','CE') 
		and PADRON=vPendiAntes.PADRON
		and TIPO_RECIBO=vPendiAntes.TIPO_RECIBO and CONTRAIDO=vPendiAntes.CONTRAIDO
   		and ZONA=DECODE(xZona,'',ZONA,xZona) and AYTO=DECODE(xAyto,'',AYTO,xAyto);

	if xCuantos=0 then
		xSumPrincipal:=0;
	end if;
	
	-- El pendiente es el pendiente el año pasado menos lo ingresado o anulado el año pasado.
	xPendiente:=vPendiAntes.Principal-xSumPrincipal;
	
	-- Lo sobrante es el pendiente de este año. Si vale 0 ya se pagó el año pasado.
	if xPendiente>0 then
	
	  Insert Into Cuentas_anuales
            (vYear,Padron,Principal,TIPO,Contraido,TIPO_RECIBO,AYTO,ZONA)
  	   values
        (xYear,vPendiAntes.Padron,vPendiAntes.Principal-xSUMPrincipal,'PE',
			vPendiAntes.CONTRAIDO,vPendiAntes.TIPO_RECIBO,vPendiAntes.AYTO,vPendiAntes.ZONA);
	end if;
	
  END LOOP;
  
END;

-- ---------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------
--
-- Cargos en voluntaria
--
-- ---------------------------------------------------------------------------------------
-- ---------------------------------------------------------------------------------------

PROCEDURE CargosVoluntaria(xYear IN Char)
AS

xAyto 	Char(3);
xZona		Char(2);
xCargo	Char(10);

-- CARGOS EN VOLUNTARIA
CURSOR cVOLUNTARIA IS
SELECT CARGO,AYTO FROM CARGOS
WHERE F_YEAR(F_CARGO)=xYear
	AND VOL_EJE='V';

-- Desglose del cargo
CURSOR cDesglose is
select PADRON,YEAR_CONTRAIDO,SUM(TOTAL_CARGO) as TOTAL,TIPO_DE_OBJETO
	from desglose_cargos
	where cargo=xCargo
	and ayto=xAyto
GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO;


BEGIN


OPEN cVOLUNTARIA;
LOOP
	FETCH cVOLUNTARIA INTO xCargo,xAYTO;
	EXIT WHEN cVOLUNTARIA%NOTFOUND;

	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=xAyto;

	for vDesglose IN cDesglose
	loop
		--puede ocurrir que haya 2 o mas cargos diferentes con los mismos conceptos
		--entonces lo que hacemos es acumular el importe al registro que ya estuviera
		--grabado con anterioridad
		update cuentas_anuales set principal=principal+vDesglose.TOTAL
				where vYear=xYear
					and padron=vDesglose.Padron
					and tipo='CV'
					and contraido=vDesglose.Year_Contraido
					and tipo_recibo=vDesglose.TIPO_DE_OBJETO
					and zona=xZona
					and ayto=xAyto;

		IF SQL%NOTFOUND THEN
		   Insert Into cuentas_anuales
		        (vYear,Padron,Principal,
		         TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
		   values
		        (xYear,vDesglose.Padron,vDesglose.TOTAL,
		         'CV',vDesglose.Year_Contraido,vDesglose.TIPO_DE_OBJETO,xZONA,xAYTO);
		end if;

	end loop;
END LOOP;
CLOSE cVOLUNTARIA;

END;


--
-- Cargos en ejecutiva
--

PROCEDURE CargosEjecutiva(xYear IN Char)
AS

xAyto 	Char(3);
xZona		Char(2);
xCargo	Char(10);


-- CARGOS EN EJECUTIVA
CURSOR cEJECUTIVA IS
SELECT CARGO,AYTO FROM CARGOS
WHERE F_YEAR(F_CARGO)=xYear AND VOL_EJE='E';

-- desglose del cargo
CURSOR cDesglose is
	select PADRON,YEAR_CONTRAIDO,SUM(TOTAL_CARGO) as TOTAL,TIPO_DE_OBJETO
	from desglose_cargos
	where cargo=xCargo
	and ayto=xAyto
GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO;

BEGIN

--CARGOS EN EJECUTIVA
OPEN cEJECUTIVA;
LOOP
	FETCH cEJECUTIVA INTO xCargo,xAyto;
	EXIT WHEN cEJECUTIVA%NOTFOUND;

	SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=xAyto;

	for vDesglose IN cDesglose
	loop
		--puede ocurrir que haya 2 o mas cargos diferentes con los mismos conceptos
		--entonces lo que hacemos es acumular el importe al registro que ya estuviera
		--grabado con anterioridad
		update cuentas_anuales set principal=principal+vDesglose.TOTAL
			where vYear=xYear
				and padron=vDesglose.Padron
				and tipo='CE'
				and contraido=vDesglose.Year_Contraido
				and tipo_recibo=vDesglose.TIPO_DE_OBJETO
				and zona=xZona
				and ayto=xAyto;

		IF SQL%NOTFOUND THEN
			   Insert Into cuentas_anuales
		        (vYear,Padron,Principal,
		         TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
		   values
		        (xYear,vDesglose.Padron,vDesglose.TOTAL,
		         'CE',vDesglose.Year_Contraido,vDesglose.TIPO_DE_OBJETO,xZONA,xAYTO);
		end if;
	end loop;
END LOOP;
CLOSE cEJECUTIVA;

END;



--
-- Lee los ingresos
-- Modificación: 09/01/2003 Lucas Fernández Pérez. No se han de seleccionar ingresos de la
-- 			  Junta (Organismo_Ext='A')
-- Modificado: 03/03/2004. Lucas Fernández Pérez. 
--	Calcula lo que NO se ha ingresado de los valores por estar BONIFICADO.
--	Lo bonificado tiene de principal menos importe que de cuota inicial. 
--  Los cargos van sobre cuota inicial, luego para descontar de un valor ingresado toda 
--   la cuota inicial, hay que quitar el principal y lo bonificado (cuota_inicial-principal)
--

PROCEDURE LeeIngresos(xYear IN Char)
AS

xZONA 	CHAR(2);

CURSOR cINGRESOS IS
        SELECT SUM(I.PRINCIPAL) AS SUMPRINCIPAL, SUM(I.RECARGO) AS SUMRECARGO,
        SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
        SUM(DECODE(PARCIAL_O_COBRO,'C',V.CUOTA_INICIAL-V.PRINCIPAL,0)) AS SUMBONIFICADO,
        V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,I.VOL_EJE
FROM INGRESOS I, VALORES V
WHERE V.ID=I.VALOR
	AND I.YEAR_INGRE=xYear
	  AND I.ORGANISMO_EXT<>'A'
      AND I.SIN_RECARGO=0
GROUP BY V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,I.VOL_EJE;


BEGIN


FOR v_cINGRESOS IN cINGRESOS LOOP

  SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_cINGRESOS.AYTO;

  Insert into cuentas_anuales
      (ZONA,AYTO,vYear,Padron,Principal,Recargo,
       Costas,Demora,Bonificado,TIPO,Contraido,TIPO_RECIBO)
  values
      (xZONA,v_cINGRESOS.AYTO,xYear,v_cINGRESOS.Padron,
	v_cINGRESOS.SUMPrincipal,v_cINGRESOS.SUMRecargo,v_cINGRESOS.SUMCostas,
	v_cINGRESOS.SUMDemora,v_cINGRESOS.SUMBonificado,
	DECODE(v_cINGRESOS.VOL_EJE,'V','IV','IE'),
	v_cINGRESOS.YEAR_CONTRAIDO,v_cINGRESOS.TIPO_DE_OBJETO);

END LOOP;

END;


--
-- Lee los ingresos de una zona
-- Creación: 27/01/2003 Agustín León Robles
-- Modificado: 03/03/2004. Lucas Fernández Pérez. 
--	Calcula lo que NO se ha ingresado de los valores por estar BONIFICADO.
--
PROCEDURE LeeZonaIngresos(xYear IN Char, xZona In char)
AS

CURSOR cINGRESOS IS
        SELECT SUM(I.PRINCIPAL) AS SUMPRINCIPAL, SUM(I.RECARGO) AS SUMRECARGO,
        SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
        SUM(DECODE(PARCIAL_O_COBRO,'C',V.CUOTA_INICIAL-V.PRINCIPAL,0)) AS SUMBONIFICADO,
        V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,I.VOL_EJE
FROM INGRESOS I,VALORES V 
where V.ID=I.VALOR
        AND I.ZONA=xZona
		AND I.YEAR_INGRE=xYear
	  	AND I.ORGANISMO_EXT<>'A'
      	AND I.SIN_RECARGO=0
GROUP BY V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,I.VOL_EJE;


BEGIN


FOR v_cINGRESOS IN cINGRESOS LOOP

  Insert into cuentas_anuales
      (ZONA,AYTO,vYear,Padron,Principal,Recargo,
       Costas,Demora,Bonificado,TIPO,Contraido,TIPO_RECIBO)
  values
      (xZONA,v_cINGRESOS.AYTO,xYear,v_cINGRESOS.Padron,
	v_cINGRESOS.SUMPrincipal,v_cINGRESOS.SUMRecargo,v_cINGRESOS.SUMCostas,
	v_cINGRESOS.SUMDemora,v_cINGRESOS.SUMBonificado,
	DECODE(v_cINGRESOS.VOL_EJE,'V','IV','IE'),
	v_cINGRESOS.YEAR_CONTRAIDO,v_cINGRESOS.TIPO_DE_OBJETO);

END LOOP;

END;


--
-- Lee los ingresos sin recargo, ejecutiva sin recargo
-- Modificación: 09/01/2003 Lucas Fernández Pérez. No se han de seleccionar ingresos de la
-- 			  Junta (Organismo_Ext='A')
-- Modificado: 03/03/2004. Lucas Fernández Pérez. 
--	Calcula lo que NO se ha ingresado de los valores por estar BONIFICADO.
--
PROCEDURE LeeIngresosSinRecargo(xYear IN Char)
AS

xZONA 	CHAR(2);

CURSOR cINGRESOS IS
        SELECT SUM(I.PRINCIPAL) AS SUMPRINCIPAL, SUM(I.RECARGO) AS SUMRECARGO,
        SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
        SUM(DECODE(PARCIAL_O_COBRO,'C',V.CUOTA_INICIAL-V.PRINCIPAL,0)) AS SUMBONIFICADO,
        V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO
FROM INGRESOS I, VALORES V
      WHERE V.ID=I.VALOR
	AND I.YEAR_INGRE=xYear
	  AND I.ORGANISMO_EXT<>'A'
      AND I.RECARGO=0
      AND I.SIN_RECARGO > 0
GROUP BY V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO;


BEGIN

FOR v_cINGRESOS IN cINGRESOS LOOP

  SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_cINGRESOS.AYTO;

  Insert into cuentas_anuales
      (ZONA,AYTO,vYear,Padron,Principal,Recargo,
       Costas,Demora,Bonificado,TIPO,Contraido,TIPO_RECIBO)
  values
      (xZONA,v_cINGRESOS.AYTO,xYear,v_cINGRESOS.Padron,
	v_cINGRESOS.SUMPrincipal,v_cINGRESOS.SUMRecargo,v_cINGRESOS.SUMCostas,
	v_cINGRESOS.SUMDemora,v_cINGRESOS.SUMBonificado,'IR',v_cINGRESOS.YEAR_CONTRAIDO,
	v_cINGRESOS.TIPO_DE_OBJETO);

END LOOP;

END;

--
-- Lee los ingresos sin recargo, ejecutiva sin recargo de una zona
-- Creación: 27/01/2003 Agustín León Robles
-- Modificado: 03/03/2004. Lucas Fernández Pérez. 
--	Calcula lo que NO se ha ingresado de los valores por estar BONIFICADO.
--
PROCEDURE LeeZonaIngresosSinRecargo(xYear IN Char, xZona IN char)
AS

CURSOR cINGRESOS IS
        SELECT SUM(I.PRINCIPAL) AS SUMPRINCIPAL, SUM(I.RECARGO) AS SUMRECARGO,
        SUM(I.COSTAS) AS SUMCOSTAS, SUM(I.DEMORA) AS SUMDEMORA,
        SUM(DECODE(PARCIAL_O_COBRO,'C',V.CUOTA_INICIAL-V.PRINCIPAL,0)) AS SUMBONIFICADO,
        V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO
FROM INGRESOS I,VALORES V 
WHERE V.ID=I.VALOR
        AND I.zona=xZona
		AND I.YEAR_INGRE=xYear
	  	AND I.ORGANISMO_EXT<>'A'
      	AND I.RECARGO=0
      	AND I.SIN_RECARGO > 0
GROUP BY V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO;


BEGIN

FOR v_cINGRESOS IN cINGRESOS LOOP
  
  Insert into cuentas_anuales
      (ZONA,AYTO,vYear,Padron,Principal,Recargo,
       Costas,Demora,Bonificado,TIPO,Contraido,TIPO_RECIBO)
  values
      (xZONA,v_cINGRESOS.AYTO,xYear,v_cINGRESOS.Padron,
	v_cINGRESOS.SUMPrincipal,v_cINGRESOS.SUMRecargo,v_cINGRESOS.SUMCostas,
	v_cINGRESOS.SUMDemora,v_cINGRESOS.SUMBonificado,'IR',v_cINGRESOS.YEAR_CONTRAIDO,
	v_cINGRESOS.TIPO_DE_OBJETO);

END LOOP;

END;

--
-- Leer los importes de las bajas
-- Modificado: 03/03/2004. Lucas Fernández Pérez. 
--	Calcula lo que NO se ha anulado en principal de los valores por estar BONIFICADO.
-- Modificado: 19/01/2005. Lucas Fernández Pérez. 
--  Las bajas por aminoración del principal (son de tipo BA) no se deben tener en cuenta. La diferencia que queda
--   entre la cuota inicial y el principal despues de dar esa baja, se tiene en cuenta al calcular los importes
--   del valor, tanto si está pendiente, ingresado, o dado de baja definitivamente. 
--   Contará como bonificación, perdida si el valor está ingresado o anulado, o pendiente si está el valor pendiente. 
--   Antes se estaba tomando en cuenta ese importe doble, en la baja por aminoracion y en el ingreso/baja/pendiente.
--   La condición que se añade es: "AND V.FECHA DE BAJA=B.FECHA". 
--
PROCEDURE LeeBajas(xYear IN Char)
AS

xZONA 	CHAR(2);
xCodigoBaja Char(2);

CURSOR cBajas IS
        SELECT SUM(B.PRINCIPAL) AS SUMPRINCIPAL, SUM(B.RECARGO) AS SUMRECARGO,
        SUM(B.COSTAS) AS SUMCOSTAS, SUM(B.DEMORA) AS SUMDEMORA,
        SUM(V.CUOTA_INICIAL-V.PRINCIPAL) AS SUMBONIFICADO,
        V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,B.VOL_EJE,B.TIPO_BAJA
FROM BAJAS B, VALORES V
      WHERE V.ID=B.VALOR
	AND B.YEAR_BAJA=xYear AND B.TIPO_BAJA<>'BN' AND V.FECHA_DE_BAJA=B.FECHA
GROUP BY V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,B.VOL_EJE,B.TIPO_BAJA;


BEGIN


FOR v_cBajas IN cBajas LOOP


  SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_cBajas.AYTO;

   IF v_cBajas.TIPO_BAJA='BA' AND v_cBajas.VOL_EJE='E' THEN
      xCodigoBaja:='BE';
   END IF;
   IF v_cBajas.TIPO_BAJA='BI' THEN
      xCodigoBaja:='BI';
   END IF;
   IF v_cBajas.TIPO_BAJA='BP' THEN
      xCodigoBaja:='BP';
   END IF;
   IF v_cBajas.TIPO_BAJA='BR' THEN
      xCodigoBaja:='BR';
   END IF;
   IF v_cBajas.TIPO_BAJA='BO' THEN
      xCodigoBaja:='BO';
   END IF;
   IF v_cBajas.TIPO_BAJA='BA' AND v_cBajas.VOL_EJE='V' THEN
      xCodigoBaja:='BV';
   END IF;

  Insert into cuentas_anuales
     (ZONA,AYTO,vYear,Padron,Principal,Recargo,
      Costas,Demora,Bonificado,TIPO,Contraido,TIPO_RECIBO)
  values
     (xZONA,v_cBajas.AYTO,xYear,v_cBajas.Padron,v_cBajas.SUMPrincipal,
	v_cBajas.SUMRecargo,v_cBajas.SUMCostas,v_cBajas.SUMDemora,v_cBajas.SUMBonificado,
	xCodigoBaja,v_cBajas.YEAR_CONTRAIDO,v_cBajas.TIPO_DE_OBJETO);

END LOOP;

END;




--
-- Leer los importes de las bajas
-- Modificado: 03/03/2004. Lucas Fernández Pérez. 
--	Calcula lo que NO se ha anulado en principal de los valores por estar BONIFICADO.
-- Modificado: 19/01/2005. Lucas Fernández Pérez. 
--  Las bajas por aminoración del principal (son de tipo BA) no se deben tener en cuenta. La diferencia que queda
--   entre la cuota inicial y el principal despues de dar esa baja, se tiene en cuenta al calcular los importes
--   del valor, tanto si está pendiente, ingresado, o dado de baja definitivamente. 
--   Contará como bonificación, perdida si el valor está ingresado o anulado, o pendiente si está el valor pendiente. 
--   Antes se estaba tomando en cuenta ese importe doble, en la baja por aminoracion y en el ingreso/baja/pendiente.
--   La condición que se añade es: "AND V.FECHA DE BAJA=B.FECHA". 
--
PROCEDURE LeeZonaBajas(xYear IN Char, xZona IN char)
AS

xCodigoBaja Char(2);

CURSOR cBajas IS
        SELECT SUM(B.PRINCIPAL) AS SUMPRINCIPAL, SUM(B.RECARGO) AS SUMRECARGO,
        SUM(B.COSTAS) AS SUMCOSTAS, SUM(B.DEMORA) AS SUMDEMORA,
        SUM(V.CUOTA_INICIAL-V.PRINCIPAL) AS SUMBONIFICADO,
        V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,B.VOL_EJE,B.TIPO_BAJA
FROM BAJAS B,VALORES V 
      WHERE V.ID=B.VALOR
            AND B.zona=xZona
			AND B.YEAR_BAJA=xYear 
			AND B.TIPO_BAJA<>'BN'
			AND V.FECHA_DE_BAJA=B.FECHA
GROUP BY V.PADRON,V.TIPO_DE_OBJETO,V.YEAR_CONTRAIDO,V.AYTO,B.VOL_EJE,B.TIPO_BAJA;


BEGIN


FOR v_cBajas IN cBajas LOOP  

   IF v_cBajas.TIPO_BAJA='BA' AND v_cBajas.VOL_EJE='E' THEN
      xCodigoBaja:='BE';
   END IF;
   IF v_cBajas.TIPO_BAJA='BI' THEN
      xCodigoBaja:='BI';
   END IF;
   IF v_cBajas.TIPO_BAJA='BP' THEN
      xCodigoBaja:='BP';
   END IF;
   IF v_cBajas.TIPO_BAJA='BR' THEN
      xCodigoBaja:='BR';
   END IF;
   IF v_cBajas.TIPO_BAJA='BO' THEN
      xCodigoBaja:='BO';
   END IF;
   IF v_cBajas.TIPO_BAJA='BA' AND v_cBajas.VOL_EJE='V' THEN
      xCodigoBaja:='BV';
   END IF;

  Insert into cuentas_anuales
     (ZONA,AYTO,vYear,Padron,Principal,Recargo,
      Costas,Demora,Bonificado,TIPO,Contraido,TIPO_RECIBO)
  values
     (xZONA,v_cBajas.AYTO,xYear,v_cBajas.Padron,v_cBajas.SUMPrincipal,
	v_cBajas.SUMRecargo,v_cBajas.SUMCostas,v_cBajas.SUMDemora,v_cBajas.SUMBonificado,
	xCodigoBaja,v_cBajas.YEAR_CONTRAIDO,v_cBajas.TIPO_DE_OBJETO);

END LOOP;

END;


-- 04/03/2004. Lucas Fernández Pérez. 
-- Lee la bonificación de los valores pendientes de un año. 
--
PROCEDURE BonifiPendienteUnoEnero(xYEAR IN CHAR)
AS

  xFechaIni	DATE;
  xCadena 	Char(30);
  xZona		Char(2);

-- PENDIENTE AL 1 DE ENERO DEL AÑO SIGUIENTE AGRUPADO POR CONCEPTO AÑO DE CONTRAIDO Y AYTO.
  CURSOR cBONIPENDIENTE IS
    SELECT SUM(CUOTA_INICIAL-PRINCIPAL) AS SUMBONIFICADO,
	  PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO
    FROM VALORES
    WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
        AND F_CARGO < xFechaIni
    GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO;

BEGIN


  xCadena:='01/01/'||TO_CHAR(TO_NUMBER(xYear)+1)||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  -- Bonificaciones pendientes al 1 de enero.

  FOR v_cBONIPENDIENTE IN cBONIPENDIENTE LOOP

    SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=v_cBONIPENDIENTE.AYTO;

    Insert Into Cuentas_anuales
            (vYear,Padron,Bonificado,TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
    values
        (xYear,v_cBONIPENDIENTE.Padron,v_cBONIPENDIENTE.SUMBonificado,'PB',
	  v_cBONIPENDIENTE.YEAR_CONTRAIDO,v_cBONIPENDIENTE.TIPO_DE_OBJETO,xZONA,
	  v_cBONIPENDIENTE.AYTO);

  END LOOP;
  
END;

-- 04/03/2004. Lucas Fernández Pérez. 
-- Lee la bonificación de los valores pendientes de un año. 
-- 
PROCEDURE BonifiPendienteUnoEneroZona(xYEAR IN CHAR, xZona IN CHAR)
AS

  xFechaIni DATE;
  xCadena 	Char(30);

  -- PENDIENTE AL 1 DE ENERO DEL AÑO SIGUIENTE AGRUPADO POR CONCEPTO AÑO DE CONTRAIDO Y AYTO.
 
    CURSOR cBONIPENDIENTE IS
    SELECT SUM(CUOTA_INICIAL-PRINCIPAL) AS SUMBONIFICADO,
    		PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO
    FROM VALORES
    WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
        AND F_CARGO < xFechaIni
	    AND AYTO IN (SELECT AYTO FROM MUNICIPIOS WHERE ZONA=xZona)
    GROUP BY PADRON,TIPO_DE_OBJETO,YEAR_CONTRAIDO,AYTO;


BEGIN
  
  xCadena:='01/01/'||TO_CHAR(TO_NUMBER(xYear)+1)||' 00:00:00';

  xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy hh24:mi:ss');

  -- Bonificaciones pendientes al 1 de enero.

  FOR v_cBONIPENDIENTE IN cBONIPENDIENTE LOOP

    Insert Into Cuentas_anuales
            (vYear,Padron,Bonificado,TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
    values
        (xYear,v_cBONIPENDIENTE.Padron,v_cBONIPENDIENTE.SUMBonificado,'PB',
	  v_cBONIPENDIENTE.YEAR_CONTRAIDO,v_cBONIPENDIENTE.TIPO_DE_OBJETO,xZONA,
	  v_cBONIPENDIENTE.AYTO);

  END LOOP;

END;

END;
/
