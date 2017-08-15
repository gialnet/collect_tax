-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
-- ***************************************************
--
-- Paquete de gestión de los logs de la base de datos
--
-- ***************************************************
CREATE OR REPLACE PACKAGE pkLogsDBS
AS

PROCEDURE CreateLogFile;

FUNCTION ChkLogFile RETURN INTEGER;

PROCEDURE LogConectaDataBase(USUARIO IN VarChar2);

PROCEDURE LogCreateObject(Usuario IN VarChar2, Tipo IN VarChar2, 
	Nombre IN VarChar2, Propietario IN VarChar2);

PROCEDURE LogDropObject(Usuario IN VarChar2, Tipo IN VarChar2, 
	Nombre IN VarChar2, Propietario IN VarChar2);

PROCEDURE LogAlterObject(Usuario IN VarChar2, Tipo IN VarChar2, 
	Nombre IN VarChar2, Propietario IN VarChar2);

	
xRuta		varchar2(250);
xRutaLogs	varchar2(250);
END pkLogsDBS;
/

-- **********************************************************************************
--
--
--
-- **********************************************************************************

CREATE OR REPLACE PACKAGE BODY pkLogsDBS
AS

--
-- Conectarse a la base de datos
--
PROCEDURE LogConectaDataBase(USUARIO IN VarChar2)
AS
vOutFile UTL_FILE.FILE_TYPE;
Resultado integer;
BEGIN

vOutFile:=UTL_FILE.FOPEN(xRutaLogs,'conecta.gialnet.log','a');
UTL_FILE.PUT_LINE(vOutFile,TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MM:SS')||' '||USUARIO);
UTL_FILE.FFLUSH(vOutFile);
UTL_FILE.FCLOSE(vOutFile);

-- Panic
--if to_char(sysdate,'ddd') > 1 then
--   Update DatosperR Set EstadoIani=9;
--   CreateLogFile;
--else

		-- Comprueba el estado de salud de la base de datos
		Resultado:=pkLogsDBS.ChkLogFile;

		if Resultado<>0 then
			Update DatosperR Set EstadoIani=Resultado;
		end if;
		
--end if;

END;

--
-- Crear un objeto en el esquema
--
PROCEDURE LogCreateObject(Usuario IN VarChar2, Tipo IN VarChar2, 
	Nombre IN VarChar2, Propietario IN VarChar2)
AS
vOutFile UTL_FILE.FILE_TYPE;
BEGIN

vOutFile:=UTL_FILE.FOPEN(xRutaLogs,'create.gialnet.log','a');
UTL_FILE.PUT_LINE(vOutFile,TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MM:SS')||' usuario: '||
	Usuario||' Tipo: '||Tipo||' Nombre: '||Nombre||' Propietario: '|| Propietario);
UTL_FILE.FFLUSH(vOutFile);
UTL_FILE.FCLOSE(vOutFile);

-- Panic
--CreateLogFile;


END;

--
-- Borrar un objeto del esquema
--
PROCEDURE LogDropObject(Usuario IN VarChar2, Tipo IN VarChar2, 
	Nombre IN VarChar2, Propietario IN VarChar2)
AS
vOutFile UTL_FILE.FILE_TYPE;
BEGIN

vOutFile:=UTL_FILE.FOPEN(xRutaLogs,'drop.gialnet.log','a');
UTL_FILE.PUT_LINE(vOutFile,TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MM:SS')||' usuario: '||
	Usuario||' Tipo: '||Tipo||' Nombre: '||Nombre||' Propietario: '|| Propietario);
UTL_FILE.FFLUSH(vOutFile);
UTL_FILE.FCLOSE(vOutFile);

-- Panic
--CreateLogFile;


END;

--
-- Modificar un objeto del esquema
--
PROCEDURE LogAlterObject(Usuario IN VarChar2, Tipo IN VarChar2, 
	Nombre IN VarChar2, Propietario IN VarChar2)
AS
vOutFile UTL_FILE.FILE_TYPE;
BEGIN

vOutFile:=UTL_FILE.FOPEN(xRutaLogs,'alter.gialnet.log','a');
UTL_FILE.PUT_LINE(vOutFile,TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MM:SS')||' usuario: '||
	Usuario||' Tipo: '||Tipo||' Nombre: '||Nombre||' Propietario: '|| Propietario);
UTL_FILE.FFLUSH(vOutFile);
UTL_FILE.FCLOSE(vOutFile);

-- Panic
--CreateLogFile;


END;

--
--
--
PROCEDURE CreateLogFile
AS
vOutFile 	UTL_FILE.FILE_TYPE;
Resultado 	INTEGER;
mSerie		varchar2(20);
BEGIN

select EstadoIani into Resultado from DatosperR;
mSerie:=Resultado||'.22af11c12b3632';

vOutFile:=UTL_FILE.FOPEN(xRuta,'oratcltemp.dll','w');
UTL_FILE.PUT_LINE(vOutFile,'[Dadi]=Gialnet Servicios S.L.');
UTL_FILE.PUT_LINE(vOutFile,'[Last update]=28/12/2004');
UTL_FILE.PUT_LINE(vOutFile,'[Version]=5.45');
UTL_FILE.PUT_LINE(vOutFile,'[State of I animate]=Fear');
UTL_FILE.PUT_LINE(vOutFile,'[Serial]='||mSerie);
UTL_FILE.PUT_LINE(vOutFile,'[Number]=02.13579-01.0');
UTL_FILE.PUT_LINE(vOutFile,'[Schema]=Gialnet');
UTL_FILE.PUT_LINE(vOutFile,'[Url]=http://www.recaudacion.org');
UTL_FILE.PUT_LINE(vOutFile,'[Ftp]=ftp://ftp.recaudacion.org');
UTL_FILE.PUT_LINE(vOutFile,'[User]=anonymous');
UTL_FILE.PUT_LINE(vOutFile,'[password]=');
UTL_FILE.PUT_LINE(vOutFile,'[Root]=/usr/help');
UTL_FILE.PUT_LINE(vOutFile,'[Shell]=bshell');
UTL_FILE.FFLUSH(vOutFile);
UTL_FILE.FCLOSE(vOutFile);

END;


--
--
--
FUNCTION ChkLogFile RETURN INTEGER
as
vOutFile 	UTL_FILE.FILE_TYPE;
vLee 		Varchar2(250);
Resultado 	INTEGER DEFAULT 9;
mRutaHTML	Varchar2(200);
begin

vOutFile:=UTL_FILE.FOPEN(xRuta,'oratcltemp.dll','r');

LOOP
BEGIN

	 UTL_FILE.GET_LINE(vOutFile,vLee);

	 if SubStr(vLee, 1, 9)='[Serial]=' then
	     Resultado:=To_Number(SubStr(vLee,10,1));
	 end if;
	 
	 --Obtengo la ruta web donde tengo que leer la pagina para controlar el estado de animo
	 if SubStr(vLee, 1, 10)='[RutaWeb]=' then
	     mRutaHTML:=RTRIM(SubStr(vLee,11,50));
	 end if;	 
	 
EXCEPTION
	WHEN NO_DATA_FOUND THEN
	 	EXIT;
	END;

END LOOP;

UTL_FILE.FCLOSE(vOutFile);

if Resultado<>9 then
	
	select substr(utl_http.request(mRutaHTML),InStr(utl_http.request(mRutaHTML),'gialnet',1,1)+18,1)  into Resultado from dual;

end if;


return resultado;

-- Ante cualquier excepción devuelve un valor nueve
EXCEPTION
 When Others then
	return resultado;
end;



--INICIALIZACION DEL PAQUETE

begin

	
	--Para recoger donde vamos a escribir el archivo DLL
	select substr(fname,1,InStr(fname,'\',1,2)) into xRuta from sys.sysfiles where tsname='INDICES';
	
	--Para recoger donde vamos a escribir los archivos LOGS
	select substr(fname,1,InStr(fname,'\',1,2)) into xRutaLogs from sys.sysfiles where tsname='DATOS';

end;
/

--
-- Para grabar el nic de la tarjeta de red del usuario que está conectando
--
-- Realiza una auditoria de las conexiones a la base de datos
-- DondeVa='E' que el usuario conecta
-- DondeVa='S' que el usuario sale de la aplicación
--
CREATE OR REPLACE PROCEDURE EntrarSalir(xNIC CHAR, DondeVa CHAR)
AS
Resultado Integer default 9;
BEGIN

INSERT INTO ACCESOS (NIC,OPERACION) VALUES (xNIC,DondeVa);

if DondeVa='E' then

   -- Comprueba el estado de salud de la base de datos
   Resultado:=pkLogsDBS.ChkLogFile;

   Update DatosperR Set EstadoIani=Resultado;

end if;

END;
/

