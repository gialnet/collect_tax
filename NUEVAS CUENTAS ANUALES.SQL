

-- Valores pendientes a la fecha indicada

SELECT SUM(PRINCIPAL),PADRON,YEAR_CONTRAIDO,AYTO
FROM VALORES
WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
        AND F_CARGO < xFechaIni
        AND TIPO_DE_OBJETO=xReciLiqui
	  AND AYTO=xZonaAyto
GROUP BY PADRON,YEAR_CONTRAIDO,AYTO;


-- Ingresos parciales de los valores pendientes a la fecha indicada

-- ************ NO FUNCIONA, PARA CADA VALOR CONSULTA TODOS VALORES PrinIngreValorFecha()

SELECT SUM(PrinIngreValorFecha(ID,xFechaIni),PADRON,YEAR_CONTRAIDO,AYTO 
FROM VALORES
WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni)
        AND F_CARGO < xFechaIni
        AND TIPO_DE_OBJETO=xReciLiqui
	  AND AYTO=xZonaAyto
GROUP BY PADRON,YEAR_CONTRAIDO,AYTO;



-- Leer los ingresos del periodo indicado

   Select SUM(I.PRINCIPAL),SUM(I.RECARGO),
          SUM(I.COSTAS),SUM(I.DEMORA)
   Into xPrin_Ingre,xReca_Ingre,
        xCostas_Ingre,xDemora_Ingre
   FROM Ingresos I, VALORES V
   WHERE V.ID=I.VALOR
        AND V.Padron = xPadron
        AND I.Year_contraido = xContraido
        AND I.Tipo_ingreso IN ('EE','ER','EC')
        AND I.year_ingre  <= xYear-1
        AND ((V.F_INGRESO IS NULL OR V.F_INGRESO >= xFechaIni)
        AND (V.FECHA_DE_BAJA IS NULL OR V.FECHA_DE_BAJA >= xFechaIni) )
        AND V.F_CARGO < xFechaIni
        AND TIPO_DE_OBJETO = xReciLiqui
        AND V.AYTO = xAYTO;


-- Suma del principal ingresado de un valor

CREATE OR REPLACE FUNCTION PrinIngreValorFecha(xIDValor IN INTEGER, xFechaTope In Date)
RETURN FLOAT

AS
	xPRINCIPAL FLOAT;
BEGIN

SELECT SUM(PRINCIPAL) Into xPRINCIPAL FROM INGRESOS
   WHERE VALOR=xIDValor and Fecha <=xFechaTope;

if xPRINCIPAL is null then
   RETURN 0;
else
   RETURN xPRINCIPAL;
end if;
	
END;
/


/******************************************************************************************/
/*	PROCEDIMIENTO ORACLE:   Genera las cuentas anuales de ingresos en base a un Ayuntam.*/
/*	PARAMETROS ENTRADA:											*/
/*        				xYear char 		Año de busqueda					*/
/*					xReciLiqui char	Tipo recibo o liquidacion			*/
/*					xZonaAyto char 	Codigo Ayuntamiento				*/
/*	PARAMETROS SALIDA:	No tiene.									*/
/******************************************************************************************/
CREATE OR REPLACE PROCEDURE MAKE_CUENTAS_ANUALES_AYTO(
        xYear		IN	 char,
        xReciLiqui 	IN	 char,
	  xZonaAyto		IN	 char)
AS

xEntregas		float;
xPrincipal 		float;
xRecargo 		float;
xCostas 		float;
xDemora 		float;
xPadron 		char(6);
xContraido 		char(4);
xFechaIni 		DATE;
xFechaFin		Date;
xPrin_Ingre 	float;
xReca_Ingre 	float;
xCostas_Ingre 	float;
xDemora_Ingre 	float;
xZona 		char(2);
xAyto 		char(3);
xCadena 		char(30);


/* PENDIENTE AL 1 DE ENERO DEL AÑO */

CURSOR cPENDIENTE IS
SELECT SUM(PRINCIPAL),PADRON,YEAR_CONTRAIDO,AYTO
FROM VALORES
WHERE ( (F_INGRESO IS NULL OR F_INGRESO >= xFechaIni)
        AND (FECHA_DE_BAJA IS NULL OR FECHA_DE_BAJA >= xFechaIni) )
        AND F_CARGO < xFechaIni
        AND TIPO_DE_OBJETO=xReciLiqui
	  AND AYTO=xZonaAyto
GROUP BY PADRON,YEAR_CONTRAIDO,AYTO;

-- CARGOS EN VOLUNTARIA

CURSOR cVOLUNTARIA IS
SELECT SUM(D.TOTAL_CARGO),D.PADRON,D.YEAR_CONTRAIDO,D.AYTO
FROM DESGLOSE_CARGOS D, CARGOS C
WHERE D.CARGO=C.CARGO 
AND C.AYTO=D.AYTO
AND C.F_CARGO BETWEEN xFechaIni AND xFechaFin
AND C.VOL_EJE='V'
AND D.TIPO_DE_OBJETO = xReciLiqui
AND D.AYTO=xZonaAyto
GROUP BY D.PADRON,D.YEAR_CONTRAIDO,D.AYTO;

/* CARGOS EN EJECUTIVA */

CURSOR cEJECUTIVA IS
SELECT SUM(D.TOTAL_CARGO),D.PADRON,D.YEAR_CONTRAIDO,D.AYTO
FROM DESGLOSE_CARGOS D, CARGOS C
WHERE D.CARGO=C.CARGO 
AND C.AYTO=D.AYTO
AND C.F_CARGO BETWEEN xFechaIni AND xFechaFin
AND C.VOL_EJE='E'
AND D.TIPO_DE_OBJETO = xReciLiqui
AND D.AYTO=xZonaAyto
GROUP BY D.PADRON,D.YEAR_CONTRAIDO,D.AYTO;

BEGIN

/* BORRAR LOS DATOS PREVIOS SI LOS HUBIERA */

Delete from cuentas_anuales
where vYear=xYear AND TIPO_RECIBO=xReciLiqui AND AYTO=xZonaAyto;


xCadena:='01/01/'||xYear;

xFechaIni:=TO_DATE(xCadena, 'dd/mm/yyyy');

xCadena:='31/12/'||xYear;

xFechaFin:=TO_DATE(xCadena, 'dd/mm/yyyy');


/* PENDIENTE AL 1 DE ENERO DEL AÑO */

xprincipal:=0;
xRecargo:=0;
xCostas:=0;
xDemora:=0;
xPrin_Ingre:=0;
xReca_Ingre:=0;
xCostas_Ingre:=0;
xDemora_Ingre:=0;


-- Valores pendientes a la fecha indicada

OPEN cPENDIENTE;
LOOP
   FETCH cPENDIENTE INTO xPrincipal,xPadron,xContraido,xAYTO;
   EXIT WHEN cPENDIENTE%NOTFOUND;

	xEntregas:=0;
	SELECT SUM(I.PRINCIPAL) INTO xENTREGAS
	FROM INGRESOS I, VALORES V
	WHERE ( (V.F_INGRESO IS NULL OR V.F_INGRESO >= xFechaIni)
      	AND (V.FECHA_DE_BAJA IS NULL OR V.FECHA_DE_BAJA >= xFechaIni) )
      	AND V.F_CARGO < xFechaIni
      	AND V.TIPO_DE_OBJETO=xReciLiqui
		AND V.AYTO=xZonaAyto
		AND V.PADRON=xPadron
		AND V.YEAR_CONTRAIDO=xContraido
		AND I.VALOR=V.ID;


	if xEntregas is null then
	   xEntregas:=0;
	end if;


   xPrincipal:= xPrincipal - xEntregas;

   SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=xAYTO;

   Insert Into Cuentas_anuales
        (vYear,Padron,Principal,Recargo,
         Costas,Demora,TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
   values
        (xYear,xPadron,xPrincipal,0,0,0,'PE',xContraido,xReciLiqui,xZONA,xAYTO);

END LOOP;
CLOSE cPENDIENTE;

-- CARGOS EN VOLUNTARIA

xPrincipal:=0;

OPEN cVOLUNTARIA;
LOOP
   FETCH cVOLUNTARIA INTO xPrincipal,xPadron,xContraido,xAYTO;
   EXIT WHEN cVOLUNTARIA%NOTFOUND;

   SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=xAYTO;

   Insert Into cuentas_anuales
        (vYear,Padron,Principal,Recargo,Costas,Demora,
         TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
   values
        (xYear,xPadron,xPrincipal,0,0,0,
         'CV',xContraido,xReciLiqui,xZONA,xAYTO);
END LOOP;
CLOSE cVOLUNTARIA;


/* ******************* */
/* CARGOS EN EJECUTIVA */
xprincipal:=0;
xRecargo:=0;
xCostas:=0;
xDemora:=0;


OPEN cEJECUTIVA;
LOOP
   FETCH cEJECUTIVA INTO xPrincipal,xPadron,xContraido,xAYTO;
   EXIT WHEN cEJECUTIVA%NOTFOUND;

   SELECT ZONA INTO xZONA FROM MUNICIPIOS WHERE AYTO=xAYTO;

   Insert Into cuentas_anuales
        (vYear,Padron,Principal,Recargo,Costas,Demora,
         TIPO,Contraido,TIPO_RECIBO,ZONA,AYTO)
   values
        (xYear,xPadron,xPrincipal,0,0,0,
         'CE',xContraido,xReciLiqui,xZONA,xAYTO);
END LOOP;
CLOSE cEJECUTIVA;

/* VALORES INGRESADOS EN EJECUTIVA */
INSERTA_CUENTAS_INGRESOS_AYTO(xYear,xReciLiqui,'E','IE',xZonaAyto);

/* VALORES INGRESADOS EN VOLUNTARIA */
INSERTA_CUENTAS_INGRESOS_AYTO(xYear,xReciLiqui,'V','IV',xZonaAyto);

/* VALORES INGRESADOS EN EJECUTIVA PERO SIN RECARGO */
INS_INGRESOS_SINRECA_AYTO(xYear,xReciLiqui,xZonaAyto);

/* bajas normales en ejecutiva */
INSERTA_CUENTAS_BAJAS_AYTO(xYear,xReciLiqui,'E','B','BE',xZonaAyto);

/* bajas por insolvencia en ejecutiva */
INSERTA_CUENTAS_BAJAS_AYTO(xYear,xReciLiqui,'E','I','BI',xZonaAyto);

/* bajas por prescripcion en ejecutiva */
INSERTA_CUENTAS_BAJAS_AYTO(xYear,xReciLiqui,'E','P','BP',xZonaAyto);

/* bajas reposicion a voluntaria en ejecutiva */
INSERTA_CUENTAS_BAJAS_AYTO(xYear,xReciLiqui,'E','R','BR',xZonaAyto);

/* bajas otros motivos en ejecutiva */
INSERTA_CUENTAS_BAJAS_AYTO(xYear,xReciLiqui,'E','O','BO',xZonaAyto);

/* bajas normales en voluntaria */
INSERTA_CUENTAS_BAJAS_AYTO(xYear,xReciLiqui,'V','B','BV',xZonaAyto);

END;
/
