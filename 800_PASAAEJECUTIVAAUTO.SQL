-- -----------------------------------------------------
-- Euro. Revisado el 5-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.Cambios en rounds.
-- -----------------------------------------------------

-- Va a comprobar diariamente todas las liquidaciones las cuales deben pasar a ejecutiva
-- y también aquellos cargos que van a vencer dentro de cinco días para avisar al 
-- jefe de zona, utilizamos la tabla PASA_CARGO como almacén de información de los cargos
-- que debemos pasar a ejecutiva.
-- Ejecución diaria

CREATE OR REPLACE PROCEDURE JOB_GOTO_EJECUTIVA
AS

xPRINCIPAL FLOAT;
xRECARGO FLOAT;
xCOSTAS FLOAT;
xDEMORA FLOAT;

CURSOR cPaseEjecutiva IS
  SELECT ID FROM VALORES 
	WHERE TIPO_DE_OBJETO='L' 
	AND VOL_EJE='V'
	AND FIN_PE_VOL <= SYSDATE
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND CUOTA_INICIAL > 0
	AND ENTREGAS_A_CUENTA > 0
	AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES)
FOR UPDATE OF RECARGO,VOL_EJE,F_APREMIO;

CURSOR cRECIBOS IS
SELECT D.CARGO,D.AYTO,D.PADRON,D.YEAR,D.PERIODO,D.FIN_PER_VOLUN 
	FROM DESGLOSE_CARGOS D, CARGOS C
	WHERE C.CARGO=D.CARGO
	AND C.AYTO=D.AYTO
	AND C.VOL_EJE='V'
	AND D.TIPO_DE_OBJETO='R'
	AND D.FIN_PER_VOLUN<=SYSDATE-5
	AND D.PASADO='N'
FOR UPDATE OF PASADO;

BEGIN

/* ----------------------- LIQUIDACIONES ------------------------------------- */

-- PASAR A EJECUTIVA TODAS LAS LIQUIDACIONES EXCEPTO LAS DE LOS ORGANISMOS INAPREMIABLES
-- QUE NO TENGAN ENTREGAS A CUENTA

UPDATE VALORES SET VOL_EJE='E', 
	RECARGO=ROUND(CUOTA_INICIAL * 10 / 100, 2),
	F_APREMIO=TO_DATE(SYSDATE,'DD-MM-YYY')

	WHERE TIPO_DE_OBJETO='L' 
	AND VOL_EJE='V'
	AND FIN_PE_VOL <= SYSDATE
	AND F_INGRESO IS NULL
	AND FECHA_DE_BAJA IS NULL
	AND CUOTA_INICIAL > 0
	AND ENTREGAS_A_CUENTA=0
	AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES);


--Los que tienen entregas a cuenta se calcula el recargo sobre el principal pendiente
FOR xPaseEjecutiva IN cPaseEjecutiva loop

	pkIngresos.GET_INGRESADO(xPaseEjecutiva.ID, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA);

	update valores set recargo=ROUND((principal-xPrincipal)*10/100, 2),
			VOL_EJE='E',F_APREMIO=TO_DATE(SYSDATE,'DD-MM-YYY')
	where current of cPaseEjecutiva;

end loop;


-- Los insolventes proponerlos para baja

UPDATE VALORES SET PROPU_INSOLVENTE='S'
  WHERE TIPO_DE_OBJETO='L'
	AND VOL_EJE='E' 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND PROPU_INSOLVENTE='N'
	AND NIF IN (SELECT NIF FROM INSOLVENTES);

/* --------------------------- RECIBOS ----------------------------------- */

-- Un cargo no se puede repetir, pero un cargo puede contener varios conceptos
-- y por lo tanto varias fechas de vencimiento.

FOR v_cRECIBOS IN cRECIBOS LOOP

      INSERT INTO PASA_CARGO (CARGO,AYTO,FECHA_FPV,YYEAR,PERIODO)
	   VALUES (v_cRECIBOS.CARGO, v_cRECIBOS.AYTO, v_cRECIBOS.FIN_PER_VOLUN,
		v_cRECIBOS.YEAR, v_cRECIBOS.PERIODO);

	UPDATE DESGLOSE_CARGOS SET PASADO='S'
		WHERE CURRENT OF cRECIBOS;
END LOOP;



END;
/


-- PASAR UN CARGO A EJECUTIVA, ATENIENDO A SU DESGLOSE PUES UN CARGO PUEDE CONTENER
-- RECIBOS DE VARIOS CONCEPTOS Y DISTINTOS VENCIMIENTOS
-- Ejecución diaria

CREATE OR REPLACE PROCEDURE JOB_PASA_A_EJECUTIVA
AS

xCargo CHAR(10);
xAYTO	 CHAR(3);
xYEAR  CHAR(4);
xPERIODO CHAR(2);

CURSOR cPaseEjecutiva IS
  SELECT ID FROM VALORES 
	WHERE N_CARGO=xCARGO
	AND AYTO=xAYTO
	AND YEAR=xYEAR
	AND PERIODO=xPERIODO  
	AND VOL_EJE='V' 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND CUOTA_INICIAL > 0
	AND ENTREGAS_A_CUENTA > 0
	AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES)
FOR UPDATE OF RECARGO,VOL_EJE,F_APREMIO;

xPRINCIPAL	FLOAT	DEFAULT 0;
xRECARGO  	FLOAT DEFAULT 0;
xCOSTAS  	FLOAT DEFAULT 0;
xDEMORA  	FLOAT DEFAULT 0;
xSiRecargo  INTEGER;
xPorcentaje	FLOAT;

CURSOR cCARGOS IS
SELECT CARGO,AYTO,YYEAR,PERIODO 
	FROM PASA_CARGO
	WHERE FECHA_FPV <= SYSDATE;

BEGIN

   --  Busco en CONFIGURACION si el recargo del 20% se aplica al pasar a ejecutiva (RECARGO=0)
   --  o si el recargo del 20% se aplica al recibir acuse de notificación (RECARGO=1), en cuyo
   --  caso los valores tendran el 10% de recargo hasta ese momento.
   SELECT RECARGO INTO xSiRecargo FROM CONFIGURACION 
	WHERE ZONA=(SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);

   IF (xSiRecargo=0) THEN 
	xPorcentaje:=20; -- Recargo del 20% a todos los valores
   ELSE
	xPorcentaje:=10; -- Recargo del 10% a todos los valores
   END IF;

FOR v_cCARGOS IN cCARGOS LOOP


-- Los valores de los organismos que no pueden ser embargados
-- se siguen dejando en voluntaria

UPDATE VALORES 
  SET VOL_EJE='E',
      RECARGO=ROUND(CUOTA_INICIAL*xPorcentaje/100, 2),
      F_APREMIO=SYSDATE
  WHERE N_CARGO=v_cCARGOS.CARGO
	AND AYTO=v_cCARGOS.AYTO
	AND YEAR=v_cCARGOS.YYEAR
	AND PERIODO=v_cCARGOS.PERIODO
	AND VOL_EJE='V' 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND CUOTA_INICIAL > 0
	AND ENTREGAS_A_CUENTA=0
	AND NIF NOT IN (SELECT NIF FROM INAPREMIABLES);

-- Los insolventes proponerlos para baja
UPDATE VALORES SET PROPU_INSOLVENTE='S'
  WHERE N_CARGO=v_cCARGOS.CARGO
	AND AYTO=v_cCARGOS.AYTO
	AND YEAR=v_cCARGOS.YYEAR
	AND PERIODO=v_cCARGOS.PERIODO 
	AND VOL_EJE='E' 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND NIF IN (SELECT NIF FROM INSOLVENTES);

xCargo:=v_cCARGOS.CARGO;
xAYTO:=v_cCARGOS.AYTO;
xYEAR:=v_cCARGOS.YYEAR;
xPERIODO:=v_cCARGOS.PERIODO;


--Los que tienen entregas a cuenta se calcula el recargo sobre el principal pendiente
FOR xPaseEjecutiva IN cPaseEjecutiva loop

	pkIngresos.GET_INGRESADO(xPaseEjecutiva.ID, xPRINCIPAL, xRECARGO, xCOSTAS, xDEMORA);

	update valores set recargo=ROUND((principal-xPrincipal)*xPorcentaje/100, 2),
			VOL_EJE='E',F_APREMIO=SYSDATE
	where current of cPaseEjecutiva;

end loop;


END LOOP;


-- Una vez pasados los cargos a ejecutiva borrar la lista de cargos a pasar

DELETE FROM PASA_CARGO
	WHERE FECHA_FPV <= SYSDATE;


END;
/



-- Propuestas de bajas por insolvencias autómaticas.
-- Este procedimiento va realizando propuestas de bajas por insolvencias de forma automática
-- cada día, lo hace para todas las zonas simultaneamente.
-- Ejecución diaria

CREATE OR REPLACE PROCEDURE JOB_PROPU_PRESCRIPCION
AS 

   CURSOR CVALORES IS 
      SELECT ID FROM VALORES 
      WHERE PROPU_INSOLVENTE='N' 
	AND FIN_PE_VOL <= ADD_MONTHS(SYSDATE,-48)
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL 
	AND EXPEDIENTE IS NULL 
	AND (F_NOTIFICACION <= ADD_MONTHS(SYSDATE,-48) OR F_NOTIFICACION IS NULL)
   FOR UPDATE OF PROPU_INSOLVENTE,CODIGO_DE_BAJA,FECHA_PROPUESTA_BAJA;


BEGIN

      FOR v_valores IN CVALORES
      LOOP     
     
         UPDATE VALORES SET PROPU_INSOLVENTE='V',CODIGO_DE_BAJA='BP',
	   FECHA_PROPUESTA_BAJA=SYSDATE
   	   WHERE current of CVALORES;

      END LOOP;

END;
/


-- Cambia los estados de los expedientes de parado a activo una vez trasncurrido el plazo
-- de paralización temporal
-- Ejecución diaria

CREATE OR REPLACE PROCEDURE JOB_GO_AWAY_EXPE
AS
BEGIN

UPDATE EXPEDIENTES SET EMBARGO='0',
	ESTA_EMBARGO='P',
	F_AVISO_OUTLOOK=NULL
	WHERE EMBARGO='P'
	AND ESTA_EMBARGO='P'
	AND F_AVISO_OUTLOOK <= SYSDATE;

END;
/



CREATE TABLE MENSAJES(
	ID			INT NOT NULL,
	USUARIO 		CHAR(30),
	FECHA			DATE DEFAULT SYSDATE,
	TEXTO			VARCHAR2(80),
	PRIMARY KEY (ID)
);

CREATE SEQUENCE GEN_MENSAJES INCREMENT BY 1 START WITH 1;

CREATE OR REPLACE TRIGGER T_MENSAJES
BEFORE INSERT ON MENSAJES
FOR EACH ROW
BEGIN
   SELECT GEN_MENSAJES.NEXTVAL INTO :NEW.ID FROM DUAL;
END;
/


CREATE TABLE MENSAJE_TEXTO (
	MENSAJE	INT NOT NULL,
	LINEA		INT,
	TEXTO		VARCHAR2(150),
	CONSTRAINT MENSAJESTEXTO
	FOREIGN KEY (MENSAJE)
	REFERENCES MENSAJES(ID) ON DELETE CASCADE
);


-- AÑADE UN NUEVO MENSAJE

CREATE OR REPLACE PROCEDURE MAKE_MENSAJE(
	xUSUARIO IN CHAR, 
	xTEXTO IN CHAR,
	xID OUT INTEGER)
AS
BEGIN

INSERT INTO MENSAJES (USUARIO,TEXTO) 
	VALUES (xUSUARIO, xTEXTO)
	RETURNING ID INTO xID;

END;
/

-- Poner una línea del listado

CREATE OR REPLACE PROCEDURE PUT_MENSAJE(
	xID IN INT,
	xMensaje IN VARCHAR2,
	nLINEA   IN INT)
AS
BEGIN

INSERT INTO MENSAJE_TEXTO (MENSAJE,LINEA,TEXTO)
	VALUES (xID, nLINEA, xMensaje);

END;
/

-- Relación de mandamientos de anotación preventiva que prescriben
-- Este procedimiento se debería de ejecutar cada tres meses

CREATE OR REPLACE PROCEDURE JOB_PRES_ANOTAPREVEN
AS

xUsuario char(30);
xTexto varchar2(80);
xMensaje varchar2(150);
xID INT;
xZona char(2):='';
nLINEA   INT :=0;

CURSOR cVENCI IS 
SELECT E.IDEXPE,E.EXPEDIENTE,E.ZONA,E.AYTO,E.NIF,C.NOMBRE
FROM EMBARGOS_INMUEBLES E, CONTRIBUYENTES C, FINCAS_EMBARGADAS F
WHERE E.NIF=C.NIF
AND F.IDEMBINMU=E.ID
AND F.FECHA_EMBARGO BETWEEN ADD_MONTHS(SYSDATE,-47) AND ADD_MONTHS(SYSDATE,-44)
ORDER BY E.ZONA,C.NOMBRE;

BEGIN

FOR v_cVENCI IN cVENCI LOOP

	xMensaje:=to_char(v_cVENCI.IDEXPE)|| ' ' || v_cVENCI.EXPEDIENTE || '' ||
	v_cVENCI.ZONA || ' ' ||	v_cVENCI.AYTO || ' ' || 
	v_cVENCI.NIF || ' ' || v_cVENCI.NOMBRE;

	nLINEA:=nLINEA+1;

	if xZona <> v_cVENCI.ZONA then

         xZona:=v_cVENCI.ZONA;

       --Crear un nuevo mensaje
	xUSUARIO:=JEFE_ZONA(v_cVENCI.ZONA);
	xTexto:='Mandamientos de anotación preventiva que prescriben entre ' ||
	to_char(ADD_MONTHS(SYSDATE,-47),'dd-mm-yyyy') || ' y ' 
	|| to_char(ADD_MONTHS(SYSDATE,-44),'dd-mm-yyyy');
	MAKE_MENSAJE(xUSUARIO,xTexto,xID);

	 --Poner una línea
	PUT_MENSAJE(xID, xMensaje, nLINEA);
    else
      --Poner una linea
	PUT_MENSAJE(xID,xMensaje, nLINEA);
    end if;
    
    

END LOOP;

END;
/


-- Relación de vencimientos de cuentas
/*
select * from cuentas_lotes L, contribuyentes C
where L.NIF=C.NIF and L.FECHA_RETENCION <= :xFECHA
and L.HECHO='N'
order by L.ENTIDAD,L.EXPEDIENTE
*/



-- Fraccionamientos vencidos
-- Debería de ejecutarse dos veces por mes

CREATE OR REPLACE PROCEDURE JOB_PLAZOS_VENCIDOS
AS

xUsuario char(30);
xTexto varchar2(80);
xMensaje varchar2(150);
xID INT;
xZona char(2):='';
nLINEA   INT :=0;
xFecha date;

CURSOR cVENCI IS 
SELECT ID,EXPEDIENTEVALOR,ZONA,NIF,F_NEXT_PLAZO 
	FROM FRACCIONAMIENTOS_VOLEJE
	WHERE F_NEXT_PLAZO <= xFECHA
	ORDER BY ZONA;

BEGIN

-- Si estamos por encima del día 20 pedimos los del día cinco del mismo mes
if to_char(sysdate,'DD') > '20' then  
   xFecha:=to_date('05-'|| to_char(sysdate,'MM-YYYY'), 'DD-MM-YYYY');
else
-- si aún no es día 20 pediemos el día 20 del mes anterior
   xFecha:=to_date('20-'|| to_char(add_months(sysdate,-1),'MM-YYYY'), 'DD-MM-YYYY');
end if;

FOR v_cVENCI IN cVENCI LOOP

	xMensaje:=TO_CHAR(v_cVENCI.ID)||' '||TO_CHAR(v_cVENCI.EXPEDIENTEVALOR)
	||' '||v_cVENCI.ZONA||' '||v_cVENCI.NIF||' '||
	TO_CHAR(v_cVENCI.F_NEXT_PLAZO, 'dd-mm-yyyy');

	nLINEA:=nLINEA+1;

	if (xZona <> v_cVENCI.ZONA) then

         xZona:=v_cVENCI.ZONA;

       --Crear un nuevo mensaje
	xUSUARIO:=JEFE_ZONA(v_cVENCI.ZONA);

	xTexto:='Plazos vencidos y no ingresados al ' || to_char(xFecha,'dd-mm-yyyy');

	MAKE_MENSAJE(xUSUARIO,xTexto,xID);

	PUT_MENSAJE(xID, xMensaje, nLINEA);
    else
	PUT_MENSAJE(xID, xMensaje, nLINEA);
    end if;
    
    

END LOOP;


END;
/