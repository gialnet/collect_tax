/**********************************************************************************************
Autor:  M.Carmen Junco G�mez. 15/11/2002
Acci�n: Inserta o modifica una tupla en la tabla que guarda las distintas opciones 
	  de los programas de Reca y GT a las que puede pertenecer un informe access.
Par�metros: xOpcion: nuevo nombre de opci�n u opci�n a modificar
		xTabla:  nombre del origen de datos (tabla access)
		xPrograma: programa al que pertenece la opci�n (RECA o GT)
**********************************************************************************************/
CREATE OR REPLACE PROCEDURE AccessAddModOpcion(
		xOpcion	in	char,	
		xTabla	in	char,
		xPrograma	in	char)
AS
BEGIN
	UPDATE ACCESSOPCIONESPROG SET TABLA=xTABLA,
						PROGRAMA=xPROGRAMA
	WHERE OPCION=xOPCION;
	
	IF SQL%NOTFOUND THEN
		INSERT INTO ACCESSOPCIONESPROG (OPCION,TABLA,PROGRAMA)
		VALUES (xOPCION,xTABLA,xPROGRAMA);
	END IF;
END;
/

/**********************************************************************************************
Autor:  M.Carmen Junco G�mez. 15/11/2002
Acci�n: Inserta o modifica una tupla en la tabla que guarda la informaci�n de los
	  informes que hemos creado para Access.
Par�metros: xInforme: nombre del informe.
		xOpcion:  opci�n del programa a la que pertenece el informe.
		xDescripcion: descripci�n opcional de la finalidad del informe Access.
**********************************************************************************************/
CREATE OR REPLACE PROCEDURE AccessAddModInforme(
		xInforme		in	char,	
		xOpcion		in	char,
		xDescripcion	in	char)
AS
BEGIN
	UPDATE ACCESSINFORMES SET OPCION=xOPCION,
					  DESCRIPCION=xDESCRIPCION
	WHERE INFORME=xINFORME;
	
	IF SQL%NOTFOUND THEN
		INSERT INTO ACCESSINFORMES (INFORME,OPCION,DESCRIPCION)
		VALUES (xINFORME,xOPCION,xDESCRIPCION);
	END IF;
END;
/


