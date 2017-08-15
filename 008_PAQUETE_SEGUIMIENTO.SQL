-- ------------------------------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.Round al insertar en seguimiento (importe)
-- ------------------------------------------------------------------------

/* *************************************************************************** */
-- Al final del fichero hay algún procedimiento que utiliza este paquete
--

CREATE OR REPLACE PACKAGE PkSeguimiento
AS

-- Añade una nota informativa

PROCEDURE NotaInformativa(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type);

-- Añade una nota informativa y la fecha en la que se realiza
PROCEDURE NotaInformativa(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type,
	xFecha	IN DATE);

-- Añade una nota informativa para los tramites de cuentas
-- el parametro ID_RETENIDO_CUENTA es el ID de la tabla CUENTAS_LOTES
PROCEDURE NotaInformativa(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type,
	xIDCuenta 	IN SEGUIMIENTO.ID_RETENIDO_CUENTA%Type);

-- Anotación por tramites negativos

PROCEDURE AnotaTramiteNegativo(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type,
	xTramite 	IN SEGUIMIENTO.TIPO_TRAMITE%Type,
	xFecha	IN DATE);


-- por acumulación o aminoración de debitos en un expediente

PROCEDURE AnotaAcumulacion(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type);

-- Anotaciones que provienen del registro general de documentos

PROCEDURE AnotaRegistroES(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xIDRegistro	IN SEGUIMIENTO.ID_REGISTRO%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type);

-- Ingresos como entregas a cuenta

PROCEDURE AnotaIngreso(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xIDCodOperacion 	IN SEGUIMIENTO.ID_INGRESOS%Type,
	xImporte		IN SEGUIMIENTO.IMPORTE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type);

-- Ingresos por embargos

PROCEDURE AnotaIngreso(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xIDCodOperacion 	IN SEGUIMIENTO.ID_INGRESOS%Type,
	xImporte		IN SEGUIMIENTO.IMPORTE%Type,
	xDescrip 		IN SEGUIMIENTO.DESCRIPCION%Type,
	xIDCuenta 		IN SEGUIMIENTO.ID_RETENIDO_CUENTA%Type);


-- Anotaciones que proviene de costas

PROCEDURE AnotaCostas(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xImporte		IN SEGUIMIENTO.IMPORTE%Type,
	xDescrip 		IN SEGUIMIENTO.DESCRIPCION%Type,
	xIDCostas 		IN SEGUIMIENTO.ID_COSTAS%Type);


-- Para saber desde el seguimiento las distintas cartas de pago emitidas del expediente
PROCEDURE AnotaCartaPago(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
		xDescrip 		IN SEGUIMIENTO.DESCRIPCION%Type,
		xTramite 		IN SEGUIMIENTO.TIPO_TRAMITE%Type,
		xIDCartaPago	IN SEGUIMIENTO.ID_CARTA_PAGO%Type);

END;
/



CREATE OR REPLACE PACKAGE BODY PkSeguimiento
AS


PROCEDURE NotaInformativa(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type)
AS
BEGIN


-- Por defecto nota informativa, con fecha del sistema

INSERT INTO SEGUIMIENTO 
     (ID_EXPE, DESCRIPCION)
  VALUES
     (xIDExpe, xDescrip);

END;

PROCEDURE NotaInformativa(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type,
	xFecha	IN DATE)
AS
BEGIN


-- Por defecto nota informativa, con fecha del sistema

INSERT INTO SEGUIMIENTO 
     (ID_EXPE, DESCRIPCION, F_ACTUACION)
  VALUES
     (xIDExpe, xDescrip, xFecha);

END;

PROCEDURE NotaInformativa(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type,
	xIDCuenta 	IN SEGUIMIENTO.ID_RETENIDO_CUENTA%Type)
AS
BEGIN


-- Por defecto nota informativa, con fecha del sistema

INSERT INTO SEGUIMIENTO 
     (ID_EXPE, DESCRIPCION, ID_RETENIDO_CUENTA)
  VALUES
     (xIDExpe, xDescrip, xIDCuenta);
END;


PROCEDURE AnotaTramiteNegativo(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type,
	xTramite 	IN SEGUIMIENTO.TIPO_TRAMITE%Type,
	xFecha 	IN DATE)
AS
BEGIN


INSERT INTO SEGUIMIENTO 
     (ID_EXPE, DESCRIPCION, DEBE_O_HABER, TIPO_TRAMITE,F_ACTUACION)
  VALUES
     (xIDExpe, xDescrip, 'N', xTramite, xFecha);

IF xTramite='1' THEN
   UPDATE EXPEDIENTES SET NOCUENTAS='S' WHERE ID=xIDExpe;
END IF;

IF xTramite='3' THEN
   UPDATE EXPEDIENTES SET NOSALARIOS='S' WHERE ID=xIDExpe;
END IF;

IF xTramite='4' THEN
   UPDATE EXPEDIENTES SET NOINMUEBLES='S' WHERE ID=xIDExpe;
END IF;

IF xTramite='8' THEN
   UPDATE EXPEDIENTES SET NOAUTOS='S' WHERE ID=xIDExpe;
END IF;

IF xTramite='X' THEN
   UPDATE EXPEDIENTES SET NOOTROS='S' WHERE ID=xIDExpe;
END IF;

END;

PROCEDURE AnotaAcumulacion(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type)
AS
BEGIN


INSERT INTO SEGUIMIENTO 
     (ID_EXPE, DESCRIPCION, DEBE_O_HABER)
  VALUES
     (xIDExpe, xDescrip, 'A');

END;


-- Anotar el vinculo a un dodumento del registro de entrada-salida

PROCEDURE AnotaRegistroES(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xIDRegistro	IN SEGUIMIENTO.ID_REGISTRO%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type)
AS
BEGIN

-- xDescrip se le pregunta al usuario si desea poner un comentario al registro
-- de entrada al vincular el expediente.

INSERT INTO SEGUIMIENTO 
     (ID_EXPE, ID_REGISTRO, DESCRIPCION, DEBE_O_HABER)
  VALUES
     (xIDExpe, xIDRegistro, xDescrip, 'R');

END;


PROCEDURE AnotaIngreso(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xIDCodOperacion 	IN SEGUIMIENTO.ID_INGRESOS%Type,
	xImporte		IN SEGUIMIENTO.IMPORTE%Type,
	xDescrip 	IN SEGUIMIENTO.DESCRIPCION%Type)
AS
BEGIN

INSERT INTO SEGUIMIENTO
      (ID_EXPE, DESCRIPCION, IMPORTE, DEBE_O_HABER, ID_INGRESOS)
   VALUES
      (xIDExpe, xDescrip, ROUND(xImporte,2), 'H', xIDCodOperacion);

END;

--
--
--
PROCEDURE AnotaIngreso(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xIDCodOperacion 	IN SEGUIMIENTO.ID_INGRESOS%Type,
	xImporte		IN SEGUIMIENTO.IMPORTE%Type,
	xDescrip 		IN SEGUIMIENTO.DESCRIPCION%Type,
	xIDCuenta 		IN SEGUIMIENTO.ID_RETENIDO_CUENTA%Type)
AS
BEGIN

INSERT INTO SEGUIMIENTO
      (ID_EXPE, DESCRIPCION, IMPORTE, DEBE_O_HABER, ID_INGRESOS, ID_RETENIDO_CUENTA)
   VALUES
      (xIDExpe, xDescrip, ROUND(xImporte,2), 'H', xIDCodOperacion, xIDCuenta);

END;

PROCEDURE AnotaCostas(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
	xImporte		IN SEGUIMIENTO.IMPORTE%Type,
	xDescrip 		IN SEGUIMIENTO.DESCRIPCION%Type,
	xIDCostas 		IN SEGUIMIENTO.ID_COSTAS%Type)
AS
BEGIN

INSERT INTO SEGUIMIENTO
      (ID_EXPE, DESCRIPCION, IMPORTE, DEBE_O_HABER, ID_COSTAS)
   VALUES
      (xIDExpe, xDescrip, ROUND(xImporte,2), 'D', xIDCostas);

END;


--
-- para saber desde el seguimiento las cartas de pago que se han emitido
--
PROCEDURE AnotaCartaPago(xIDExpe IN SEGUIMIENTO.ID_EXPE%Type,
		xDescrip 		IN SEGUIMIENTO.DESCRIPCION%Type,
		xTramite 		IN SEGUIMIENTO.TIPO_TRAMITE%Type,
		xIDCartaPago	IN SEGUIMIENTO.ID_CARTA_PAGO%Type)
AS
BEGIN


INSERT INTO SEGUIMIENTO 
     (ID_EXPE, DESCRIPCION, TIPO_TRAMITE, ID_CARTA_PAGO)
  VALUES
     (xIDExpe, xDescrip, xTramite, xIDCartaPago);

END;


END;
/


/* *********************************************************************** */
/* Delphi formulario AnotarPrelacion.dfm */
CREATE OR REPLACE PROCEDURE ANOTA_NOTIENE
(
	xIDExpe	IN	INTEGER,
      xFECHA 	IN 	DATE,
      xCodTramite	IN 	CHAR)

AS
    	xCOMENT VARCHAR2(90);
BEGIN

	SELECT TEXTO INTO xCOMENT FROM EMBARGOS
		WHERE EMBARGO=xCodTramite;

	xCOMENT:='SIN DATOS DE, ' || LTRIM(xCOMENT);

	PkSeguimiento.AnotaTramiteNegativo(xIDExpe, xCOMENT, xCodTramite,xFECHA);

END;
/

