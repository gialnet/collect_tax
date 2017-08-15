/**********************************************************************************************
Autor:  M.Carmen Junco Gómez. 15/11/2002
Acción: Inserta o modifica una tupla en la tabla que guarda las distintas opciones 
	  de los programas de Reca y GT a las que puede pertenecer un informe access.
Parámetros: xOpcion: nuevo nombre de opción u opción a modificar
		xTabla:  nombre del origen de datos (tabla access)
		xPrograma: programa al que pertenece la opción (RECA o GT)
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
Autor:  M.Carmen Junco Gómez. 15/11/2002
Acción: Inserta o modifica una tupla en la tabla que guarda la información de los
	  informes que hemos creado para Access.
Parámetros: xInforme: nombre del informe.
		xOpcion:  opción del programa a la que pertenece el informe.
		xDescripcion: descripción opcional de la finalidad del informe Access.
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


