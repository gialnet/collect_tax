/****************************************************************************************
Autor:  M.Carmen Junco Gómez. 18/12/2002
Acción: Crear y aplicar política de seguridad para que un usuario trabaje
	    con valores que pertenezcan a su municipio únicamente.
****************************************************************************************/
-- privilegios necesarios

--CONNECT sys/change_on_install@ATECO AS sysdba;

CREATE ANY CONTEXT TO "GIALNET";
GRANT EXECUTE
    ON "SYS"."DBMS_RLS" TO "GIALNET";

--CONNECT GIALNET/A1@ATECO;

-- creación del contexto
CREATE OR REPLACE CONTEXT CTX_VALORES_MUNI USING pkValoresAyto;

-- *****************************************************************************
-- creación del paquete que configura el contexto y que contiene la función de
-- implementación de la política de seguridad
-- *****************************************************************************
CREATE OR REPLACE PACKAGE pkValoresAyto AS

--
-- procedimiento que configura el contexto
--
PROCEDURE GetAyto;

--
-- función que implementa la política de seguridad
--
-- Se cesitan las dos variables de entrada, aUnque no está documentado
-- 

FUNCTION SOLO_VALORES_Ayto(D1 VARCHAR2, D2 VARCHAR2) return varchar2;

END pkValoresAyto;
/

-- *******************************************************
--
--
--
-- *******************************************************
CREATE OR REPLACE PACKAGE BODY pkValoresAyto AS

--
-- procedimiento que configura el contexto
--
PROCEDURE GetAyto 
AS
   xAyto CHAR(3);
BEGIN

	SELECT MUNICIPIO INTO xAyto FROM USUARIOSGT
	WHERE USUARIO=USER;

	DBMS_SESSION.SET_CONTEXT('CTX_VALORES_MUNI','AYTO', xAyto);	
END;

--
-- función que implementa la política de seguridad
--
-- Se cesitan las dos variables de entrada, aunque no está documentado
-- 
FUNCTION SOLO_VALORES_Ayto(D1 VARCHAR2, D2 VARCHAR2)
return VarChar2 
AS
	xPredicado VARCHAR2(2000);
BEGIN    

	xPredicado:='AYTO = SYS_CONTEXT(''CTX_VALORES_MUNI'', ''AYTO'')';

	RETURN xPredicado;
END;

END pkValoresAyto;
/

GRANT EXECUTE ON pkValoresAyto TO public;
CREATE PUBLIC SYNONYM pkValoresAyto FOR GIALNET.pkValoresAyto;

-- ejecutar el procedimiento que incluye la política en la base de datos

BEGIN
 DBMS_RLS.ADD_POLICY('GIALNET','VALORES','POLITICA_VALORES_AYTO','GIALNET',
							    'pkValoresAyto.SOLO_VALORES_AYTO',
							    'SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
END;


BEGIN
	DBMS_RLS.REFRESH_POLICY('GIALNET','VALORES','POLITICA_VALORES_AYTO');
END;

-- trigger que activa la política de seguridad cada vez que un usuario
-- se concecta a la base de datos

--CONNECT sys/change_on_install@ATECO AS sysdba;

GRANT ADMINISTER DATABASE TRIGGER TO GIALNET;

CREATE OR REPLACE TRIGGER T_POLITICA_VALORES_AYTO
AFTER LOGON ON DATABASE
DECLARE
   mUSUARIO VarChar2(30);
BEGIN    
    GIALNET.pkValoresAyto.GetAyto;
END;
/
