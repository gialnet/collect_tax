
SELECT TO_CHAR(FECHA,'DD-MM-YYYY HH24:MI:SS'),ID FROM BITACORAS
WHERE IDEXPE=1075 
AND FECHA<=TO_DATE('03-05-2001 21:00:00','DD-MM-YYYY HH24:MI:SS')


-- Informarnos si un valor estaba en un expediente en una fecha determinada
-- Devolvemos null si no esta en la fecha indicada y en caso contrario la fecha
-- de entrada
CREATE OR REPLACE FUNCTION ESTABA_ELVALOR(xIDVALOR IN INT, xIDEXPE IN INT, xFECHA IN DATE)
RETURN DATE
AS
xFECHABI DATE;
BEGIN

-- Estaba dentro del expediente

   begin
	SELECT MAX(FECHA) INTO xFECHABI FROM BITACORAS 
		WHERE IDEXPE=xIDEXPE
		AND IDVALOR=xIDVALOR
		AND TIPO_MOVIMIENTO='E' 
		AND FECHA <= xFECHA;
   exception
   when no_data_found then
     Return xFECHABI;
   end;

-- No salio en este intervalo
    begin
	SELECT MIN(FECHA) INTO xFECHABI FROM BITACORAS 
		WHERE IDEXPE=xIDEXPE
		AND IDVALOR=xIDVALOR
		AND TIPO_MOVIMIENTO='S' 
		AND FECHA >= xFECHA;
	-- Forzar a nulo para que la función llamadora sepa que no estába en esta fecha
	xFECHABI:=NULL;
   exception
   when no_data_found then
     xFECHABI:=NULL;
   end;

Return xFECHABI;

END;



-- Poner en la tabla temporal todos los valores que formaban parte del
-- expediente en la fecha señalada

CREATE OR REPLACE PROCEDURE EXPE_VALORES_FECHA(xIDEXPE IN INT, xFECHA IN DATE)
AS

xF_ENTRADA DATE;

CURSOR cVALORES IS 
	SELECT ID FROM VALORES 
		WHERE EXPEDIENTE=xIDEXPE;
BEGIN

-- Limpiar los posibles valores anteriores

DELETE FROM TMP_ACUMULA WHERE UUSER=UID;

FOR v_cVALORES IN cVALORES LOOP

    xF_ENTRADA:=ESTABA_ELVALOR(v_cVALORES.ID, xIDEXPE, xFECHA);
    IF  xF_ENTRADA IS NOT NULL THEN
	 INSERT INTO TMP_ACUMULA (IDVALOR,FECHA) VALUES (v_cVALORES.ID, xF_ENTRADA);
    END IF;

END LOOP;

END;
/

