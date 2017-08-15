--
-- Para poder emitir recordatorios de deudas
-- lo que hacemos es crear cartas de pago
-- 20/06/2002 Antonio Pérez Caballero
--
CREATE OR REPLACE PACKAGE PKAvisosDeudas
AS


PROCEDURE EntreImportes(xDESDE IN FLOAT, xHASTA IN FLOAT);

PROCEDURE ByYearEmision(xYEAR IN CHAR);

PROCEDURE ByCargos;

PROCEDURE EntreFechasCargo(xDesde IN DATE, xHasta IN DATE);

-- ***********************************************************
-- MODELO ASP 
-- MULTIPLES AYUNTAMIENTOS EN UNA SOLA BASE DE DATOS
-- ***********************************************************

PROCEDURE EntreImportes(xAYTO IN CHAR, xDESDE IN FLOAT, xHASTA IN FLOAT);

PROCEDURE ByYearEmision(xAYTO IN CHAR, xYEAR IN CHAR);

PROCEDURE ByCargos(xAYTO IN CHAR);

PROCEDURE EntreFechasCargo(xAYTO IN CHAR, xDesde IN DATE, xHasta IN DATE);


--
-- Variables públicas
--

xPKZona Char(2);

--Tipo de entidad municipal: 
--Ayuntamientos pequeños (A).
--Ayuntamientos grandes (G): pueden tener mas de un alcalde por distrito, tesorero, etc.
--Entidades SupraMunicipales (S): Mancomunidades y Diputaciones.
--Comunidades Autonomas o Administración Central (C).
--Modo de funcionamiento ASP X

xPKTipoEntidad Char(1);

xPKIDRelacion  INTEGER;

xPKRelacionCorreos Char(10);

END PKAvisosDeudas;
/


CREATE OR REPLACE PACKAGE BODY PKAvisosDeudas
AS



--
-- Crear cartas de pago por criterio de importes de deudores
-- 
-- 20/06/2002 Antonio Pérez Caballero
--
PROCEDURE EntreImportes(xDESDE IN FLOAT, xHASTA IN FLOAT)
AS

CURSOR cDeudas IS SELECT NIF,SUM(PRINCIPAL) AS DEUDA FROM VALORES
	WHERE F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	HAVING SUM(PRINCIPAL) BETWEEN xDESDE AND xHASTA
	GROUP BY NIF;

BEGIN


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;


--
-- Crear cartas de pago por criterio de AÑOS DE EMISION
-- 
-- 20/06/2002 Antonio Pérez Caballero
--
PROCEDURE ByYearEmision(xYEAR IN CHAR)
AS

CURSOR cDeudas IS SELECT NIF FROM VALORES
	WHERE YEAR=xYEAR
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	GROUP BY NIF;

BEGIN


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF,xPKRelacionCorreos);

END LOOP;


END;


--
-- Crear cartas de pago por criterio de CARGOS
-- 
-- 20/06/2002 Antonio Pérez Caballero
--
PROCEDURE ByCargos
AS

xCuantosRecibos INTEGER DEFAULT 0;

-- Todos los valores  de un CARGO o conjunto de cargos 

CURSOR cDeudas IS	SELECT NIF FROM VALORES 
	WHERE N_CARGO IN (SELECT CARGO FROM TMP_LISTACARGOS WHERE SESIONID=GETSID())
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	GROUP BY NIF;

BEGIN

SELECT COUNT(*) INTO xCuantosRecibos FROM TMP_LISTACARGOS 
		WHERE SESIONID=GETSID();

-- Si no se elige cargo alguno nos salimos

   IF xCuantosRecibos = 0 THEN
      RETURN;
   END IF;


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;

--
-- Deudores desde una fecha de cargo hasta otra
--

PROCEDURE EntreFechasCargo(xDesde IN DATE, xHasta IN DATE)
AS

--  Deudores desde una fecha de cargo hasta otra

CURSOR cDeudas IS	SELECT NIF FROM VALORES 
	WHERE F_CARGO BETWEEN xDesde AND xHasta
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	GROUP BY NIF;

BEGIN


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;

-- ***********************************************************
-- MODELO ASP 
-- MULTIPLES AYUNTAMIENTOS EN UNA SOLA BASE DE DATOS
-- ***********************************************************


--
-- Crear cartas de pago por criterio de importes de deudores
-- 
-- 20/06/2002 Antonio Pérez Caballero
--
PROCEDURE EntreImportes(xAYTO IN CHAR, xDESDE IN FLOAT, xHASTA IN FLOAT)
AS

CURSOR cDeudas IS SELECT NIF,SUM(PRINCIPAL) AS DEUDA FROM VALORES
	WHERE AYTO=xAYTO
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	HAVING SUM(PRINCIPAL) BETWEEN xDESDE AND xHASTA
	GROUP BY NIF;

BEGIN


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;


--
-- Crear cartas de pago por criterio de AÑOS DE EMISION
-- 
-- 20/06/2002 Antonio Pérez Caballero
--
PROCEDURE ByYearEmision(xAYTO IN CHAR, xYEAR IN CHAR)
AS

CURSOR cDeudas IS SELECT NIF FROM VALORES
	WHERE AYTO=xAYTO
	AND YEAR=xYEAR
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	GROUP BY NIF;

BEGIN


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;


--
-- Crear cartas de pago por criterio de CARGOS
-- 
-- 20/06/2002 Antonio Pérez Caballero
--
PROCEDURE ByCargos(xAYTO IN CHAR)
AS

xCuantosRecibos INTEGER DEFAULT 0;

-- Todos los valores  de un CARGO o conjunto de cargos 

CURSOR cDeudas IS	SELECT NIF FROM VALORES 
	WHERE AYTO=xAYTO
	AND N_CARGO IN (SELECT CARGO FROM TMP_LISTACARGOS WHERE SESIONID=GETSID())
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	GROUP BY NIF;

BEGIN

SELECT COUNT(*) INTO xCuantosRecibos FROM TMP_LISTACARGOS 
		WHERE SESIONID=GETSID();

-- Si no se elige cargo alguno nos salimos

   IF xCuantosRecibos = 0 THEN
      RETURN;
   END IF;


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;

--
-- Deudores desde una fecha de cargo hasta otra
--

PROCEDURE EntreFechasCargo(xAYTO IN CHAR, xDesde IN DATE, xHasta IN DATE)
AS

--  Deudores desde una fecha de cargo hasta otra

CURSOR cDeudas IS	SELECT NIF FROM VALORES 
	WHERE AYTO=xAYTO
	AND F_CARGO BETWEEN xDesde AND xHasta
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL
	AND VOL_EJE='E'
	GROUP BY NIF;

BEGIN


FOR v_cDeudas IN cDeudas LOOP

	PkCartaPagoBanco.NewCartaPago(xPKIDRelacion);
	PkCartaPagoBanco.AddAllReciboDeudor(v_cDeudas.NIF, xPKRelacionCorreos);

END LOOP;


END;


--
-- Código de inicialización del paquete
--
BEGIN


SELECT ZONA INTO xPKZona FROM USUARIOS WHERE USUARIO=USER;

SELECT TIPO_ENTIDAD INTO xPKTipoEntidad FROM CONFIGURACION WHERE ZONA=xPKZona;

END PKAvisosDeudas;
/


-- **********************************************************************************
--  P R O C E D I M I E N T O S   D E   G E S T I O N   D E L    P A Q U E T E
-- **********************************************************************************


--
-- Para poder emitir recordatorios de deudas
-- lo que hacemos es crear cartas de pago
-- 20/06/2002 Antonio Pérez Caballero
--

CREATE OR REPLACE PROCEDURE AvisoDeudasEntreImportes(
	xAYTO  IN CHAR,
	xDESDE IN FLOAT, 
	xHASTA IN FLOAT,
	xPorque IN Varchar2,
	mNumero out char)
AS
xIDRelacion INTEGER;
xCuantos Integer default 0;
xNumero Char(10);
BEGIN

DAME_RELACION(xNumero);

INSERT INTO RELACIONES_NOTI
			(RELACION,FECHA,USUARIO,ZONA,TIPO_NOTI)
	VALUES (xNumero,sysdate,USER, PKAvisosDeudas.xPKZona,'A');

-- pequeña descripcón del porqué de estos avisos

  INSERT INTO CartasPagoRelaciones (PORQUE) VALUES (xPORQUE)
	RETURNING ID INTO xIDRelacion;

  PKAvisosDeudas.xPKRelacionCorreos:=xNumero;
  PKAvisosDeudas.xPKIDRelacion:=xIDRelacion;

  IF PKAvisosDeudas.xPKTipoEntidad='X' THEN
     	PKAvisosDeudas.EntreImportes(xAYTO, xDesde, xHasta);
  ELSE
	PKAvisosDeudas.EntreImportes(xDesde, xHasta);
  END IF;

-- Contar las cartas que se han creado

select count(*) INTO xCuantos from CartaPagoBanco 
	where IDCartasPagoRelaciones=xIDRelacion;

IF xCuantos=0 THEN
   delete from RELACIONES_NOTI where relacion=xNumero;
ELSE
   update RELACIONES_NOTI SET RECIBOS=xCuantos where relacion=xNumero;
END IF;

mNumero:=SubStr(xNumero,1,10);

END;
/


--
-- Desde fecha de cargoa a fecha de cargo
--
CREATE OR REPLACE PROCEDURE AvisoDeudasEntreFechasCargo(
	xAYTO  IN CHAR,
	xDESDE IN DATE, 
	xHASTA IN DATE,
	xPorque IN Varchar2,
	mNumero out char)
AS
xIDRelacion INTEGER;
xCuantos Integer default 0;
xNumero Char(10);
BEGIN

DAME_RELACION(xNumero);

INSERT INTO RELACIONES_NOTI
			(RELACION,FECHA,USUARIO,ZONA,TIPO_NOTI)
	VALUES (xNumero,sysdate,USER, PKAvisosDeudas.xPKZona,'A');

-- pequeña descripcón del porqué de estos avisos

  INSERT INTO CartasPagoRelaciones (PORQUE) VALUES (xPORQUE)
	RETURNING ID INTO xIDRelacion;

  PKAvisosDeudas.xPKRelacionCorreos:=xNumero;
  PKAvisosDeudas.xPKIDRelacion:=xIDRelacion;

  IF PKAvisosDeudas.xPKTipoEntidad='X' THEN
     	PKAvisosDeudas.EntreFechasCargo(xAYTO, xDesde, xHasta);
  ELSE
	PKAvisosDeudas.EntreFechasCargo(xDesde, xHasta);
  END IF;

-- Contar las cartas que se han creado

select count(*) INTO xCuantos from CartaPagoBanco 
	where IDCartasPagoRelaciones=xIDRelacion;

IF xCuantos=0 THEN
   delete from RELACIONES_NOTI where relacion=xNumero;
ELSE
   update RELACIONES_NOTI SET RECIBOS=xCuantos where relacion=xNumero;
END IF;

mNumero:=SubStr(xNumero,1,10);

END;
/

--
-- Por cargo o conjunto de cargos
--
CREATE OR REPLACE PROCEDURE AvisoDeudasByCargo(
	xAYTO  IN CHAR,
	xPorque IN Varchar2,
	mNumero out char)
AS
xIDRelacion INTEGER;
xCuantos Integer default 0;
xNumero Char(10);
BEGIN

DAME_RELACION(xNumero);

INSERT INTO RELACIONES_NOTI
			(RELACION,FECHA,USUARIO,ZONA,TIPO_NOTI)
	VALUES (xNumero,sysdate,USER, PKAvisosDeudas.xPKZona,'A');

-- pequeña descripcón del porqué de estos avisos

  INSERT INTO CartasPagoRelaciones (PORQUE) VALUES (xPORQUE)
	RETURNING ID INTO xIDRelacion;

  PKAvisosDeudas.xPKRelacionCorreos:=xNumero;
  PKAvisosDeudas.xPKIDRelacion:=xIDRelacion;

  IF PKAvisosDeudas.xPKTipoEntidad='X' THEN
     	PKAvisosDeudas.ByCargos(xAYTO);
  ELSE
	PKAvisosDeudas.ByCargos;
  END IF;

-- Contar las cartas que se han creado

select count(*) INTO xCuantos from CartaPagoBanco 
	where IDCartasPagoRelaciones=xIDRelacion;

IF xCuantos=0 THEN
   delete from RELACIONES_NOTI where relacion=xNumero;
ELSE
   update RELACIONES_NOTI SET RECIBOS=xCuantos where relacion=xNumero;
END IF;

mNumero:=SubStr(xNumero,1,10);

END;
/

--
-- Por año de emisión del valor
--
CREATE OR REPLACE PROCEDURE AvisoDeudasByYear(
	xAYTO  IN CHAR,
	xYear IN Char, 
	xPorque IN Varchar2,
	mNumero out char)
AS
xIDRelacion INTEGER;
xCuantos Integer default 0;
xNumero Char(10);
BEGIN

DAME_RELACION(xNumero);

INSERT INTO RELACIONES_NOTI
			(RELACION,FECHA,USUARIO,ZONA,TIPO_NOTI)
	VALUES (xNumero,sysdate,USER, PKAvisosDeudas.xPKZona,'A');

-- pequeña descripcón del porqué de estos avisos

  INSERT INTO CartasPagoRelaciones (PORQUE) VALUES (xPORQUE)
	RETURNING ID INTO xIDRelacion;

  PKAvisosDeudas.xPKRelacionCorreos:=xNumero;
  PKAvisosDeudas.xPKIDRelacion:=xIDRelacion;

  IF PKAvisosDeudas.xPKTipoEntidad='X' THEN
     	PKAvisosDeudas.ByYearEmision(xAYTO,xYear);
  ELSE
	PKAvisosDeudas.ByYearEmision(xYear);
  END IF;

-- Contar las cartas que se han creado

select count(*) INTO xCuantos from CartaPagoBanco 
	where IDCartasPagoRelaciones=xIDRelacion;

IF xCuantos=0 THEN
   delete from RELACIONES_NOTI where relacion=xNumero;
ELSE
   update RELACIONES_NOTI SET RECIBOS=xCuantos where relacion=xNumero;
END IF;

mNumero:=SubStr(xNumero,1,10);

END;
/


