-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- No se han realizado cambios.
-- -----------------------------------------------------
/*----------------------------------------------------------------*/
/* ENERO - 2.001  AUTOR: LUCAS */
/*----------------------------------------------------------------*/
/*--------------------------------------------------------------------*/
/* Procedimiento que ejecuta una tarea de la cola de trabajos de la BD*/
CREATE OR REPLACE PROCEDURE RUN_JOB(
	xN_Trabajo		IN TRABAJOS_USUARIOS.N_TRABAJO%TYPE)

AS

BEGIN
	/* Para que el procedimiento ejecute la tarea deseada, 
	 se da maxima prioridad a la tarea en la tabla de trabajos_usuarios */
	UPDATE TRABAJOS_USUARIOS SET PRIORIDAD='0' WHERE N_TRABAJO=xN_Trabajo;
	DBMS_JOB.RUN(xN_TRABAJO);

END;
/

/*--------------------------------------------------------------*/
/* Procedimiento que elimina una tarea de la cola de trabajos de la BD*/
/* Ademas, elimina la tarea de la tabla trabajos_usuarios. */
CREATE OR REPLACE PROCEDURE REMOVE_JOB(
	xN_Trabajo		IN TRABAJOS_USUARIOS.N_TRABAJO%TYPE)

AS

BEGIN
	
	DBMS_JOB.REMOVE(xN_TRABAJO);

	DELETE FROM TRABAJOS_USUARIOS WHERE N_TRABAJO=xN_Trabajo;


END;
/

/*-------------------------------------------------------------------------------*/
/* Procedimiento que modifica una tarea de la cola de trabajos de la BD          */
/* Ademas, modifica la informacion de dicha tarea en la tabla trabajos_usuarios. */
CREATE OR REPLACE PROCEDURE CHANGE_JOB(
	xN_Trabajo		IN TRABAJOS_USUARIOS.N_TRABAJO%TYPE,
	xTrabajo		IN TRABAJOS_USUARIOS.TRABAJO%TYPE,
	xFecha_Sig		IN TRABAJOS_USUARIOS.PARAM_DATE1%TYPE,
	xIntervalo 		IN TRABAJOS_USUARIOS.CICLICO%TYPE
)

AS
BEGIN

	DBMS_JOB.CHANGE(xN_Trabajo,xTrabajo,xFecha_Sig,xIntervalo);

	UPDATE TRABAJOS_USUARIOS SET TRABAJO=xTrabajo, USUARIO=USER, CICLICO=xIntervalo
	WHERE N_TRABAJO=xN_Trabajo;


END;
/

