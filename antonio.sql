

--
-- Para saber el día que se graba un acuse de recibo.
--
-- Ocurre en ocasiones que se cobra con el 10% de recargo pues el sujeto pasivo 
-- paga antes de que nos llega el acuse de recibo. Posteriormente nos llega la tarjeta rosa
-- y el valor está ya ingresado por lo tanto no tiene que variar el importe del recargo.
--
-- es decir si la fecha de ingreso es menor que la fecha de grabación del acuse de recibo
-- el importe del recargo no variará
--

SELECT * FROM VALORES V, NOTIFICACIONES N
WHERE V.ID=N.VALOR
AND N.TIPO_NOTI= -> NOTIFICACIÓN PROVIDENCIA DE APREMIO
AND V.F_INGRESO > N.F_GRABA;


ALTER TABLE NOTIFICACIONES ADD F_GRABA DATE DEFAULT SYSDATE;

-- ****************** F_INTENTO en notificaciones averiguar para que sirve ********************


CREATE OR REPLACE PROCEDURE ADD_HIS_ANTICIPO(
	xIDAnti IN Integer,
	xFecha IN Date, 
	xImporte IN Float)
AS
BEGIN

INSERT INTO HISTORICO_ANTICIPOS (ANTICIPO,FECHA,IMPORTE)
	VALUES (xIDAnti, Trunc(xFecha,'dd'), xImporte);

END;
/