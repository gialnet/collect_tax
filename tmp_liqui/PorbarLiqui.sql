
-- Para borrar los datos de todas las liquidaciones


UPDATE INGRESOS SET LIQUIDACION=NULL,F_LIQUIDACION=NULL;

UPDATE BAJAS SET LIQUIDACION=NULL,F_LIQUIDACION=NULL;

UPDATE ANTICIPOS SET LAST_LIQUIDR=NULL,PENDIENTE=IMPORTE,ESTADO='P';

DELETE FROM HISTORICO_ANTICIPOS WHERE MOVIMIENTO <> 'PR';

DELETE FROM LIQUIDR_CONCEPTOS;

DELETE FROM LIQUIDR_CTO_RESUMEN;

DELETE FROM LIQUIDACIONESR;



-- Lanzar las liquidaciones de todos los ayuntamientos


declare

xAYTO Char(3);

CURSOR cMUNICIPIOS IS SELECT AYTO FROM MUNICIPIOS WHERE TIPO_CLI='LOC' AND AYTO IN ('018','004','091','100');

CURSOR cAnticipos IS SELECT ID FROM ANTICIPOS WHERE AYTO=xAYTO;

begin

FOR v_cMUNICIPIOS IN cMUNICIPIOS LOOP

	LiquidaUnAyto('01/01/2002', '31/03/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('01/04/2002', '30/06/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('01/07/2002', '05/07/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('06/07/2002', '20/07/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('21/07/2002', '05/08/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('06/08/2002', '20/08/2002', v_cMUNICIPIOS.AYTO);	
	LiquidaUnAyto('21/08/2002', '05/09/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('06/09/2002', '20/09/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('21/09/2002', '05/10/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('06/10/2002', '20/10/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('21/10/2002', '05/11/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('06/11/2002', '20/11/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('21/11/2002', '05/12/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('06/12/2002', '20/12/2002', v_cMUNICIPIOS.AYTO);
	LiquidaUnAyto('21/12/2002', '31/12/2002', v_cMUNICIPIOS.AYTO);

	xAYTO:=v_cMUNICIPIOS.AYTO;

	FOR V_cAnticipos IN cAnticipos LOOP

	    PkAmortizaciones.EspecialDipuGranada2002(V_cAnticipos.ID);

	END LOOP;

END LOOP;

end;
/




Create Or Replace Procedure ProbarLiqui
as

begin

	--
	-- Quitando este comentario har�a una amortizaci�n con inter�s simple
	-- por defecto utiliza inter�s compuesto es decir los intereses se suman
	-- a la deuda.
	--PkAmortizaciones.xInteresCompuesto:=False;

	PkAmortizaciones.AmortizarAnticiposAyto(v_cMUNICIPIOS.AYTO,'01/01/2002', '31/03/2002');

	LiquidaUnAyto('01/01/2002','31/03/2002', v_cMUNICIPIOS.AYTO);


	PkAmortizaciones.AmortizarAnticiposAyto(v_cMUNICIPIOS.AYTO,'01/04/2002', '30/06/2002');

	LiquidaUnAyto('01/04/2002','30/06/2002', v_cMUNICIPIOS.AYTO);



	PkAmortizaciones.AmortizarAnticiposAyto(v_cMUNICIPIOS.AYTO,'01/07/2002', '30/09/2002');

	LiquidaUnAyto('01/07/2002','30/09/2002', v_cMUNICIPIOS.AYTO);




	PkAmortizaciones.AmortizarAnticiposAyto(v_cMUNICIPIOS.AYTO,'01/10/2002', '31/12/2002');

	LiquidaUnAyto('01/10/2002','31/12/2002', v_cMUNICIPIOS.AYTO);



end;
/


--
--
--
Create Or Replace Procedure ProbarLiqui
as


CURSOR cMUNICIPIOS IS SELECT AYTO
	FROM MUNICIPIOS WHERE TIPO_CLI='LOC';

begin

	PkAmortizaciones.AmortizarAnticipos('01/01/2002', '31/03/2002');

	FOR v_MUN IN CMUNICIPIOS LOOP

		LiquidaUnAyto('01/01/2002','31/03/2002', v_MUN.AYTO);

	END LOOP;



	PkAmortizaciones.AmortizarAnticipos('01/04/2002', '30/06/2002');

	FOR v_MUN IN CMUNICIPIOS LOOP

		LiquidaUnAyto('01/04/2002','30/06/2002', v_MUN.AYTO);

	END LOOP;


	PkAmortizaciones.AmortizarAnticipos('01/07/2002', '30/09/2002');

	FOR v_MUN IN CMUNICIPIOS LOOP

		LiquidaUnAyto('01/07/2002','30/09/2002', v_MUN.AYTO);

	END LOOP;


	PkAmortizaciones.AmortizarAnticipos('01/10/2002', '31/12/2002');

	FOR v_MUN IN CMUNICIPIOS LOOP

		LiquidaUnAyto('01/10/2002','31/12/2002', v_MUN.AYTO);

	END LOOP;


	--UPDATE LIQUIDACIONESR SET FECHA='02/09/2002' WHERE TRUNC(FECHA,'DD')='20/12/2002';
	--UPDATE LIQUIDR_CONCEPTOS SET FECHA='02/09/2002' WHERE TRUNC(FECHA,'DD')='20/12/2002';
	--UPDATE LIQUIDR_CTO_RESUMEN SET FECHA='02/09/2002' WHERE TRUNC(FECHA,'DD')='20/12/2002';
	--UPDATE INGRESOS SET F_LIQUIDACION='02/09/2002' WHERE TRUNC(F_LIQUIDACION,'DD')='20/12/2002';
	--UPDATE BAJAS SET F_LIQUIDACION='02/09/2002' WHERE TRUNC(F_LIQUIDACION,'DD')='20/12/2002';


end;
/


CREATE OR REPLACE PROCEDURE AJUSTACABEZA
AS

xINGRE FLOAT;
xPREMIO FLOAT;

CURSOR cAJUSTA IS SELECT * FROM LIQUIDACIONESR
	FOR UPDATE OF INGRESOS,PREMIO;

BEGIN

FOR vAJUSTA IN cAJUSTA LOOP

    SELECT SUM(INGRESOS),SUM(PREMIO) INTO xINGRE,xPREMIO
    FROM LIQUIDR_CTO_RESUMEN
    WHERE IDLIQ=vAJUSTA.ID;

    UPDATE LIQUIDACIONESR SET INGRESOS=xINGRE,PREMIO=xPREMIO
    	WHERE CURRENT OF cAJUSTA;

END LOOP;

END;
/


SELECT LC.ID_LIQ, LC.CONCEPTO,LC.YEAR,LC.PERIODO,
LC.INGRESADO,LC.DESCONTADO,LC.COMISIONES,LC.TOTAL_RECARGO_O_E,
(LC.INGRESADO+LC.COMISIONES) AS INGRESOSTOTALES,
(LC.INGRESADO-LC.DESCONTADO) AS LIBRE,C.DESCRIPCION
FROM LIQUIDR_CONCEPTOS LC, CONCEPTOS C
WHERE LC.ID_LIQ=:xIDLiq AND C.CONCEPTO=LC.CONCEPTO
