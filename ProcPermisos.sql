--
-- Poner unos permisos a un usuario
--
CREATE OR REPLACE PROCEDURE SetAutUser(
	xUsuario IN Char,
	xFormu   IN Integer,
	xPermiso IN Integer)
AS
BEGIN

UPDATE UsuaPerForm SET PERMISO1=xPermiso 
	WHERE USUARIO=xUsuario
	AND FORMU=xFormu;

IF SQL%NOTFOUND THEN
   INSERT INTO UsuaPerForm (USUARIO,FORMU,PERMISO1) 
	VALUES (xUsuario, xFormu, xPermiso);
END IF;

END;
/