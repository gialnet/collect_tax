-- -----------------------------------------------------
-- Euro. Revisado el 3-12-2001. Lucas Fernández Pérez 
-- Se han realizado cambios.Rounds en insert/update
-- -----------------------------------------------------
/****************************************************************************/

--
-- Refrescar los importes del expediente, antes de entrara en el formulario ConsultaExpediente
-- controlará que si ya se ha refrescado no se vuelva a refrescar
-- 19/12/2001
--
/*DELPHI*/
CREATE OR REPLACE PROCEDURE RefreshExpe(xIDExpe	IN INTEGER)
AS

xINTERESES 		FLOAT default 0;
xDEUDA_TOTAL 	FLOAT;
xF_Visita 		DATE;

BEGIN

  -- Consultar la última vez que se abrio este expediente
  Select F_Visita INTO xF_Visita From Expedientes 
	Where ID=xIDExpe;

  -- si no ha sido hoy mismo
  IF (xF_Visita IS NULL) OR 
  (TO_CHAR(SYSDATE,'DD/MM/YYYY') <> TO_CHAR(xF_Visita,'DD/MM/YYYY')) THEN
 
     -- recalculamos los intereses
     CALCDEMORA_EXPE(xIDExpe, SysDate, 'S','E',xINTERESES, xDEUDA_TOTAL);

     -- indicamos que se le ha visitado, para no volver a pasar por aquí hoy mismo
     -- en el procedimiento CALCDEMORA_EXPE

  END IF;

END;
/

/* COMPROBAR SI EL EXPEDIENTE ESTA VIVO */
-- valores devueltos cero expediente ingresado o anulado
-- uno expediente vivo que puede seguir con actuaciones
-- Se utiliza en ventanilla de recaudación
/*DELPHI*/
CREATE OR REPLACE PROCEDURE CHECK_EXPE_ISLIVE( xIDExpe IN INT, xEstado OUT INT)
AS
BEGIN

SELECT COUNT(*) INTO xEstado FROM EXPEDIENTES
	WHERE ID=xIDExpe
	AND F_INGRESO IS NULL
	AND F_ANULACION IS NULL;


END;
/

--
-- Desagrupar un recibo de un expediente. 
--
-- Puede ocurrir que el expediente este en un fraccionamiento y entren nuevos recibos al 
-- expediente con lo que el expediente estara suspendido y el recibo pendiente. Tiene que dejar
-- desagruparlo del expediente.
-- Ultima modificación: 24/10/2001 Agustin Leon Robles
-- 11/12/2001 Antonio Pérez Caballero
-- 20/09/2002 M. Carmen Junco Gómez. La cadena xClaveValor es demasiado pequeña. Ahora tiene
-- 26 caracteres, y se va a insertar en un campo de 150. Se puede ampliar.
--
-- Modificado: 06/06/2003. Lucas Fernández Pérez. Si el expediente está en embargo con
--		diligencia en marcha no deja desagrupar el recibo. 
-- Tratamiento de distintos tipos de error.
--
-- Códigos de error que genera:
--
-- 	xError=0 : Se ha desagrupado y borrado las costas al expediente que tenía el recibo.
--
-- 	xError=1 : El valor esta ingresado o anulado. No se desagrupa.
--
-- 	xError=2 : El valor está suspendido y el expediente está fraccionado. No se desagrupa.
--
-- 	xError=3 : El expediente está en embargo de CC con diligencia en marcha. No se desagrupa.
--
-- Devueltos por el reajuste de costas, muestra los siguentes avisos (DELCostaValorPasaAExpe).
--
--  xError=4 : No se han borrado las costas al expediente que tenía el recibo, porque parte
--				de las mismas estan ya ingresadas
--  xError=5 : No se han borrado las costas al expediente que tenía el recibo, porque al   
--				desagrupar el recibo, el expediente queda sin recibos pendientes, y no se 
--				puede redistribuir el importe de las costas.
--  xError=6 : No se han borrado las costas al expediente que tenía el recibo, porque los  
--				recibos que quedan en el expediente no tienen importe pendiente, y no se 
--				puede redistribuir entre los mismos.
--
-- Modificado: 18/06/2003. Lucas Fernández Pérez. 
--	Descuenta el campo "RECIBOS" o "CUANTOS_R_SUSPEN" de la tabla EXPEDIENTES
--	 dependiendo de si el valor que se desagrupa estaba suspendido o no 
--	 (antes siempre descontaba del campo "RECIBOS")
--
CREATE OR REPLACE PROCEDURE DESAGRUPA_EXPE(xVALOR IN INTEGER, xERROR OUT INTEGER)
AS

  xIDExpe      INT;
  xFEntrada    DATE;
  xFIngreso	 DATE;
  xFBaja	 DATE;
  xFSuspension DATE;
  xEstado	 Expedientes.Estado%Type;
  xClaveValor	 varchar(50);

BEGIN

  SELECT AYTO||'-'||PADRON||'-'||YEAR||'-'||PERIODO||'-'||RECIBO,EXPEDIENTE,F_IN_EXPEDIENTE,
	F_INGRESO,FECHA_DE_BAJA,F_SUSPENSION
  INTO xClaveValor,xIDExpe,xFEntrada,xFIngreso,xFBaja,xFSuspension FROM VALORES
  WHERE ID=xVALOR;

  -- si el valor esta ingresado o anulado nos salimos sin hacer nada
  IF (xFIngreso is not null) or (xFBaja is not null) THEN
   	xError:=1;
   	RETURN;
  END IF;

  -- Si el expediente está fraccionado no se puede desagrupar
  SELECT Estado INTO xEstado FROM EXPEDIENTES WHERE ID=xIDExpe;
  -- si el valor esta suspendido y el expediente tambien no se puede desagrupar, 
  -- porque esta en un fraccionamiento. Si el valor esta suspendido pero no hay un 
  -- fraccionamiento si se puede desagrupar
  IF xFSuspension is not null AND xEstado='FRACCIO' THEN
   	xError:=2;
	RETURN;
  END IF;

  -- En expedientes en embargo de cuentas con diligencia en marcha no se puede desagrupar
  IF EmbargoCuentaEnMarcha(xIDExpe) THEN
  	xError:=3;
  	RETURN;
  END IF;

  -- Desagrupar el valor
  UPDATE VALORES SET EXPEDIENTE=NULL,F_IN_EXPEDIENTE=NULL,ID_INMUEBLES=NULL,EN_INMUEBLES='N'
  WHERE ID=xVALOR;

  if xFSuspension is null then --Actualizamos el contador de recibos del expediente
  
  	UPDATE EXPEDIENTES SET RECIBOS=RECIBOS-1
	WHERE ID=xIDExpe
         AND F_INGRESO IS NULL
         AND F_ANULACION IS NULL;
         
  else 	--Actualizamos el contador de recibos suspendidos del expediente

   	UPDATE EXPEDIENTES SET CUANTOS_R_SUSPEN=CUANTOS_R_SUSPEN-1
	WHERE ID=xIDExpe
         AND F_INGRESO IS NULL
         AND F_ANULACION IS NULL;
  end if;

  DELCostaValorPasaAExpe(xIDExpe, xFEntrada, xVALOR, xError);

  PkSeguimiento.NotaInformativa(xIDExpe, 'Se desagrupa el valor '|| To_Char(xVALOR)||
 	' ,Clave valor: '||Ltrim(RTrim(xClaveValor)));
 
END;
/

/***************************************************************************************
Acción: Anular o reponer la anulación de un expediente
MODIFICACIÓN: 30/07/2003 M. Carmen Junco Gómez. Si el expediente se anuló estando en 
			  el embargo de cuentas, se tendrá que reponer al estado en el que estaba
			  antes de la anulación, borrando el posible levantamiento.

***************************************************************************************/
CREATE OR REPLACE PROCEDURE ANULA_EXPE(
		xID		IN	INTEGER,
      	xTIPO 	IN	INTEGER,
      	xFECHA 	IN	DATE)
AS    
	xEMBARGO	char(1);
BEGIN

	IF xTIPO=0 THEN

		UPDATE EXPEDIENTES SET F_ANULACION=xFECHA,ISOPEN='N',IS_LIVE='N',
			   F_ESTADO=SYSDATE,ESTADO='ANULADO',TIPO_ANULACION='NO' 
		WHERE ID=xID RETURN EMBARGO INTO xEMBARGO;

		-- Control del levantamiento de embargos
		-- Levantar los trámites si hubiera alguno en marcha
		LEVANTA_CHECK(xID, xEMBARGO);

		PkSeguimiento.NotaInformativa(xID, 'Se anula el expediente');

   	ELSE -- Si el expediente estaba levantado en algun embargo, lo abro.

		UPDATE EXPEDIENTES SET F_ANULACION=NULL,ISOPEN='S',IS_LIVE='S',
		  	   F_ESTADO=SYSDATE, ESTADO='ABIERTO',TIPO_ANULACION=NULL 
		WHERE ID=xID
		RETURN EMBARGO INTO xEmbargo;

		--deshace el levantamiento que le corresponda para salarios, inmuebles y vehiculos
		IF xEmbargo not in ('0','1') then
		   DESHACE_LEVANTA(xID, null, xEMBARGO);
		ELSIF (xEmbargo='1') THEN
		   REPONEREMBARGOCUENTAS(xID);
		END IF;

		PkSeguimiento.NotaInformativa(xID, 'Se repone la anulación');
	END IF;

END;
/



/****************************************************************************/

CREATE OR REPLACE PROCEDURE BORRAR_EXPE(xID IN INTEGER, xERROR OUT INTEGER)
AS

  xCONT 		INTEGER;
  xF_SUSPENSION	DATE;
  xESTADO		CHAR(7);
  xTRAMITE		CHAR(1);

BEGIN

  /* Errores: 1.- El expediente tiene recibos
              2.- El expediente tiene notificaciones
		  3.- El expediente está suspendido
		  4.- El expediente tiene un fraccionamiento en marcha
		  5.- El expediente tiene asociado un trámite */

  SELECT COUNT(*) INTO xCONT FROM VALORES
  WHERE EXPEDIENTE=xID; 

  IF xCONT > 0 THEN 
    xERROR:=1;
    return;
  END IF;

  SELECT COUNT(*) INTO xCONT FROM NOTIFICACIONES
  WHERE EXPEDIENTE=xID;

  IF xCONT > 0 THEN
    xERROR:=2;
    return;
  END IF;

  SELECT F_SUSPENSION,ESTADO,EMBARGO
  INTO xF_SUSPENSION,xESTADO,xTRAMITE
  FROM EXPEDIENTES WHERE ID=xID;

  IF (xF_SUSPENSION IS NOT NULL AND xESTADO='SUSPEND') THEN
    xERROR:=3;
    return;
  END IF;

  IF (xF_SUSPENSION IS NOT NULL AND xESTADO='FRACCIO') THEN
    xERROR:=4;
    return;
  END IF;

  IF xTRAMITE<>'0' THEN
    xERROR:=5;
    return;
  END IF;  
      
  xERROR:=0;
  /*BORRAR EL SEGUIMIENTO*/
  DELETE FROM SEGUIMIENTO 
  WHERE ID_EXPE=xID;

  /*BORRAR LOS TERCEROS*/
  DELETE FROM TERCEROS 
  WHERE EXPEDIENTE=xID;

  /*BORRAR LOS INVITADOS*/
  DELETE FROM GUEST_EXPE 
  WHERE EXPEDIENTE=xID;

  /*BORRAR LOS AVISOS*/
  DELETE FROM AVISOS_EXPE 
  WHERE EXPEDIENTE=xID;

  /*BORRAR LOS EXPEDIENTES 
    DE ACUMULACION*/
  DELETE FROM ACUMULAR_DETALLE 
  WHERE IDEXPE=xID;
  DELETE FROM ACUMULAR
  WHERE IDEXPE=xID;

  /*BORRAR EL EXPEDIENTE*/
  DELETE FROM EXPEDIENTES 
  WHERE ID=xID;
  
END;
/

/****************************************************************************/
-- delphi

CREATE OR REPLACE PROCEDURE CONTROL_ENTREGA(xEXPE IN integer)
AS

xFDili DATE;

BEGIN

/*SI HAY UNA DILIGENCIA EN MARCHA*/
SELECT FECHA_DILIGENCIA Into xFDili 
	FROM EXPEDIENTES WHERE ID=xEXPE;

 if xFDili is not null then
    UPDATE EXPEDIENTES SET AVISO='015',F_AVISO=SYSDATE
    WHERE ID=xEXPE;
 end if;

END;
/

/****************************************************************************/

CREATE OR REPLACE PROCEDURE check_retenido(
	xIDExpe 	IN	INT, 
	xEntrega	IN	INT, 
	xSINO 	OUT	INT,
	xMaximo     OUT float)
AS

xRetenido  float DEFAULT 0;
xDeuda     float;

BEGIN

 xSINO:=1;

 /*HACE LA SUMA SOBRE EL PENDIENTE DE VALORES DEL EXPEDIENTE*/

 SELECT PENDIENTE INTO xDEUDA 
	FROM PENDIVALORESEXPE
 	WHERE EXPEDIENTE=xIDExpe;

if HayRetenidoCuentas(xIDExpe, xRetenido) then

       xMaximo := xDeuda - xRetenido;
       if xEntrega > xMaximo then
          xSINO:=0;
       END IF;
end IF;

END;
/

/****************************************************************************/

CREATE OR REPLACE PROCEDURE BORRA_AVISOS (
		xTIPO  IN CHAR,
		xFECHA IN DATE)
AS
BEGIN

   IF (xTIPO='TO') THEN
      UPDATE EXPEDIENTES SET AVISO='000',
				     F_AVISO=xFECHA
      WHERE AVISO<>'000';
   ELSE
      UPDATE EXPEDIENTES SET AVISO='000',
				     F_AVISO=xFECHA
      WHERE AVISO=xTIPO;
   END IF;
END;
/


/*******************************************************************************************/
--
-- Recalcular los intereses de demora antes de imprimir un informe de debitos
--
/*DELPHI*/
CREATE OR REPLACE PROCEDURE RecalculaDemoraExpe(
	xIDEXPE		IN INTEGER,
      xFECHA 		IN DATE,
      INCLUIRDEMORA 	IN CHAR,
      DEMORAMANUAL 	IN CHAR)
AS

xINTERESES 		FLOAT default 0;
xDEUDA_TOTAL 	FLOAT;

cursor cvalores is select id from valores 
					WHERE EXPEDIENTE=xIDEXPE 
					AND F_INGRESO IS NULL 
					AND FECHA_DE_BAJA IS NULL
		for update of demora_pendiente;

BEGIN

   IF INCLUIRDEMORA='S' THEN

	  IF DEMORAMANUAL='S' THEN
         CALCDEMORA_EXPE(xIDEXPE, xFECHA, 'S','E',xINTERESES, xDEUDA_TOTAL);
      ELSE
         CALCDEMORA_EXPE(xIDEXPE, xFECHA, 'S','N',xINTERESES, xDEUDA_TOTAL);
      END IF;

   ELSE
     for VVALO IN CVALORES loop
   
       IF PERMITO_CALCULAR_INTERESES(vValo.ID) THEN
         UPDATE VALORES SET DEMORA_PENDIENTE=0 
					WHERE CURRENT OF CVALORES;
	   END IF;
     end loop;
   END IF;


END;
/


/*****************************************************************************************/
-- Modificado: 08/01/2003. Lucas Fernández Pérez. 
-- Sólo pone el expediente a estado 'ABIERTO' si tiene recibos pendientes y estado 'PAGADO'
--
-- Modificado: 18/06/2003.Lucas Fernández Pérez.
-- 	Reajusta también el número de recibos suspendidos del expediente
CREATE OR REPLACE PROCEDURE AJUSTA_IMPORTE_EXPE(xEXPE	IN INTEGER)
AS
    	xCUANTOS INTEGER;
    	xCUANTOSSUSPEN INTEGER;
    	xRETENIDO FLOAT;
    	xEMBARGO CHAR(1);

BEGIN

   xRETENIDO:=0;

   SELECT COUNT(*) INTO xCUANTOS FROM VALORES 
   WHERE EXPEDIENTE=xEXPE 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NULL;

   SELECT COUNT(*) INTO xCUANTOSSUSPEN FROM VALORES 
   WHERE EXPEDIENTE=xEXPE 
	AND F_INGRESO IS NULL 
	AND FECHA_DE_BAJA IS NULL 
	AND F_SUSPENSION IS NOT NULL;


   SELECT EMBARGO INTO xEMBARGO FROM EXPEDIENTES 
   	WHERE ID=xEXPE;

   IF xEMBARGO<>'0' THEN
   	SELECT SUM(IMPORTE_RETENIDO) INTO xRETENIDO FROM CUENTAS_LOTES
      	WHERE IDEXPE=xEXPE AND HECHO='N';
   END IF;

   IF xCUANTOS > 0 THEN
      UPDATE EXPEDIENTES SET RECIBOS=xCUANTOS, CUANTOS_R_SUSPEN=xCUANTOSSUSPEN,
      	 RETENIDO=xRETENIDO,
		 ESTADO=DECODE(ESTADO,'PAGADO','ABIERTO',ESTADO),
		 F_INGRESO=NULL
   	WHERE ID=xEXPE;
   ELSE
      UPDATE EXPEDIENTES SET RECIBOS=xCUANTOS, CUANTOS_R_SUSPEN=xCUANTOSSUSPEN,
        RETENIDO=xRETENIDO
      	WHERE ID=xEXPE 
		AND F_INGRESO IS NULL 
		AND F_ANULACION IS NULL;
   END IF;
END;
/

/****************************************************************************************/
CREATE OR REPLACE PROCEDURE ADD_TERCERO_EXPE(
	xEXPE		IN	INTEGER,
      xRELA 	IN 	CHAR,
      xNIF 		IN 	CHAR,
      xTELEFO 	IN 	CHAR,
      xVTODOS 	IN 	CHAR,
      xOBSE 	IN 	VARCHAR2,
      xFTODAS 	IN 	CHAR,
	xTramite    IN    CHAR)
AS
BEGIN

INSERT INTO TERCEROS
(EXPEDIENTE, RELACION, NIF,TELEFONO, OBSERVACIONES, VEHI_TODAS, FINCAS_TODAS, TRAMITE)
   VALUES 
(xEXPE, xRELA, xNIF,xTELEFO, xOBSE, xVTODOS, xFTODAS, xTramite);

END;
/

/****************************************************************************************/

CREATE OR REPLACE PROCEDURE NOTIFICAR_EXPEDIENTE_ACUM(
	xID_ACUMULAR IN INT, 
	xIDEXPE IN INT)
AS
BEGIN

UPDATE ACUMULAR SET NOTIFICADO='S'
   WHERE ID=xID_ACUMULAR;

UPDATE EXPEDIENTES SET EXP_ACUM_NOTIF='S'
      WHERE ID=xIDEXPE
	AND EXP_ACUM_NOTIF='S';

END;
/

/*****************************************************************************
Autor: M. Carmen Junco Gómez.
Fecha: 04/10/2001
Acción: Añade un nuevo documento o imagen asociado al apunte en el seguimiento
	  de un Expediente.
cambio: Antonio Pérez Caballero.
Fecha.: 08/10/2001
causa.: Se desdobla en dos tablas las imagenes para poder almacenar más de una
        imagen por cada anotación en el historico.
*****************************************************************************/

CREATE OR REPLACE PROCEDURE ADD_DOCSEGUIEXPE(
	xIDSEGUI 	IN INTEGER,
	xFICHERO 	IN VARCHAR2,
	xReferencia IN VARCHAR2,
	xIDDOCS	OUT INTEGER)
AS
BEGIN

Insert Into DOCS_SEGUIMIENTO (IDSEGUI, FicherOriginal, Referencia, IMAGEN)
	VALUES (xIDSEGUI, xFICHERO, xReferencia, empty_blob())
	RETURNING ID INTO xIDDOCS;

END;
/

/*****************************************************************************************/
COMMIT;
/********************************************************************/
