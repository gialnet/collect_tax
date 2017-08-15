-- -----------------------------------------------------
-- Euro. Revisado el 30-11-2001. Lucas Fernández Pérez
-- No se han realizado cambios.
-- -----------------------------------------------------
--
-- Comprueba si la fecha de ingreso está dentro del plazo del art.108 para poder cobrar
-- los intereses de demora.
-- a) Las notificadas entre los días 1 y 15 de cada mes, hasta el día 20 de dicho mes,
-- o inmediato hábil posterior.
-- b) Las notificadas entre los días 16 y último de cada mes, hasta el día 5 del mes
-- siguiente o inmediado hábil posterior.
--
-- Modificado: 18/07/2003. Lucas Fernández Pérez. 
--	Si por configuración se indica que se quieren poner intereses por adelantado,
--		se ignoran los plazos del artículo 108.
--
-- Modificado: 22/06/2004. Agustín León Robles. Cambios de la Nueva Ley General Tributaria
--					Se añade un nuevo parametro que es el Final del Periodo voluntario
-- BASE
CREATE OR REPLACE FUNCTION PLAZO_APREMIO(
				xIngresoC 	in DATE,
				xNotiC 		in DATE,
				xFinPeVol	in date)
RETURN INTEGER

AS

    SePuedeCobrar CHAR(1);
    NoSePuede  CHAR(1);
    SePuede  CHAR(1);
    iYear  INT;
    iMes   INT;
    iDia   INT;
    nYear  INT;
    nMes   INT;
    nDia   INT;
    xINGRESO DATE;
    xNOTI 	DATE;
    NumDia  Char(1);
    mFiesta Char(5);
    UnDiaMas Integer;
    xInteresAnticipado CHAR(1);

BEGIN

	if Trunc(xFinPeVol,'dd')<to_date('30/06/2004','dd/mm/yyyy') then

		-- recoger si hay que ignorar los plazos del artículo 108.
		SELECT DEMORA_ANTES_NOTI INTO xInteresAnticipado FROM CONFIGURACION 
		WHERE ZONA IN (SELECT ZONA FROM USUARIOS WHERE USUARIO=USER);   
   
		if xInteresAnticipado='S' then -- No mira plazos, y da acceso al cálculo de intereses
			RETURN 1;
		end if;
		
	end if;

   xINGRESO := xINGRESOC;
   xNOTI := xNOTIC;
   SePuedeCobrar:='S';
   NoSePuede:='N';
   SePuede:='N';
   iyear:= F_YEAR(xIngreso);
   iMes := MONTH(xIngreso);
   iDia := DAYOFMONTH(xIngreso);
   nyear:= F_YEAR(xNoti);
   nMes := MONTH(xNoti);
   nDia := DAYOFMONTH(xNoti);

   --
   -- 1 Lunes, 2 Martes...7 Domingo
   -- Si el último día del plazo cae en domingo, hay que dar un día más
   -- ponemos el día de pago menos uno cae en domingo, pues obviamente nadíe ira
   -- a pagar un domingo, vendrá el lunes y estará dentro del plazo del art. 108
   --
   NumDia:=to_char(xIngreso-1,'D');
   if NumDia='7' then
      UnDiaMas:=1;
   else
      UnDiaMas:=0;
   end if;

   --
   -- Fiestas nacionales mm/dd 01/01, 01/06, 05/01, 08/15, 10/12, 11/01, 12/06, 12/25
   --
   -- Como ninguna cae en día cinco o veinte no influyen, la única excepción es el día
   -- de reyes que caiga en lunes entonces no se cobrarían intereses de demora hasta el
   -- miércoles es decir día 5 + 2
   --
   mFiesta:=to_char(xIngreso-1,'mm/dd');
   NumDia:=to_char(xIngreso-1,'D');
   if (mFiesta = '01/06') and (NumDia='1') then
      UnDiaMas:=2;
   end if;

   -- El ingreso debe ser posterior a la notificación
   if (xINGRESO < xNOTI) then
	RETURN -1;
   end if;

   if (xIngresoC-xNotiC < 30) then -- Si han pasado menos de 30 dias (¿por que no 20?)
      if (nMes = iMes) then -- Si la notificación y el ingreso es el mismo mes
         if (nDia < 16) then -- Si la notificacion se hizo del 1 al 15
            if (iDia > (20+UnDiaMas)) then -- y el ingreso despues del 20 de ese mes, se puede cobrar
               SePuede:=SePuedeCobrar;
            else			  -- el ingreso se hizo antes del 20 cuando la notif.del 1 al 15.
               SePuede:=NoSePuede;
            end if;
         else -- Notificación del 16 al 31.El ingreso esta en el mismo mes.Nunca se cobrara
             SePuede:=NoSePuede;
         end if;
      else -- la notificacion se hizo en un mes y el ingreso en el mes siguiente.
         if (nDia < 16) then --Notificacion del 1 al 15.Estamos en otro mes,se puede cobrar
            SePuede:=SePuedeCobrar;
         else -- Notificación del 16 al 31.Si el ingreso es posterior al 5(mes siguiente)se puede cobrar
            if (iDia > (5+UnDiaMas)) then
               SePuede:=SePuedeCobrar;
            else
               SePuede:=NoSePuede;
            end if;
         end if;
      end if;
   else -- Hay mas de 30 dias de diferencia, se puede cobrar
      SePuede:=SePuedeCobrar;
   end if;

   if SePuede='S' then
      RETURN 1;
   else
      RETURN 0;
   end if;

END;
/


/*****************************************************************************************/
--
-- Cálcular los intereses de demora en función de su fecha de final de periodo voluntario
-- y su fecha de ingreso. Nos devuelve el importe de los intereses de demora
--
/*BASE*/
CREATE OR REPLACE PROCEDURE CAL_DEMORA(
		mFechaPago IN DATE,
		mFinPeVol  IN DATE,
		mTO 	     IN CHAR,
		mPrincipal IN float,
		intereses  OUT float)

AS

YearFin  integer;
INTEFIJO FLOAT DEFAULT 0;
INTEVARI FLOAT DEFAULT 0;

BEGIN

   INTERESES := 0;

   IF mFechaPago < mFinPeVol THEN
      raise_application_error(-20007,'Error en la fecha del final del periodo voluntario: '
			||to_char(mFinPeVol,'dd/mm/yyyy')
			||' Fecha de pago: '||to_char(mFechaPago,'dd/mm/yyyy'));
   END IF;

   IF (mFinPeVol is not null) then
      YearFin:=F_Year(mFinPeVol);
      IF (YEARFIN > 1994) THEN
         PkDemora.INT_VARIABLE(mFECHAPAGO,mFINPEVOL,mTO,mPRINCIPAL,INTEVARI);
      ELSE
         PkDemora.FIJO95(mFINPEVOL,mTO,mPRINCIPAL,INTEFIJO);
         PkDemora.VARIABLE95(mFECHAPAGO,mFINPEVOL,mTO,mPRINCIPAL,INTEVARI);
      END IF;

      INTERESES:=INTEVARI+INTEFIJO;
   END IF;
END;
/
/*****************************************************************************************/

--
-- PARA CALCULAR LOS INTERESES QUE DEBIERON INGRESARSE
--   EN UNA ENTREGA A CUENTA SOBRE UN VALOR
--
-- Indica la cantidad pendiente por demora del valor.
-- Mira todos los ingresos del valor, calcula las demoras de cada uno y descuenta lo
-- ingresado por demora.Asi para cada ingreso obtiene la demora pendiente y devuelve
-- la suma de todas esos intereses pendientes de cobrar.
-- Es decir, la demora pendiente del valor.
--
-- Modificado: 03/01/2003. Lucas Fernández Pérez. Si el ingreso es por banco, calcula los
-- 	intereses hasta la fecha de ingreso en el banco.
-- Modificado: 14/01/2003. Lucas Fernández Pérez. Los ingresos en voluntaria no se toman
--	en cuenta para el cálculo de intereses.
/*BASE*/
CREATE OR REPLACE PROCEDURE INT_ENTREGAS(
		xVALOR        IN INTEGER,
		xFINPEVOL     IN DATE,
		xTIPO         IN CHAR,
		INT_PENDIENTE OUT FLOAT)

AS

FECHA_COBRO DATE;
INTERESES  FLOAT DEFAULT 0;

-- Ingresos realizados sobre el valor, que se haya cobrado algo de principal
-- pues el calculo de intereses está vinculado al principal del recibo
CURSOR VALOR_EXPE IS
	SELECT PRINCIPAL,FECHA,F_COBRO_BANCO,DEMORA
	FROM INGRESOS
	WHERE VALOR=xVALOR AND VOL_EJE='E';

BEGIN

INT_PENDIENTE:=0;

   FOR v_INGRESO IN VALOR_EXPE LOOP

	INTERESES:=0;

	IF v_INGRESO.PRINCIPAL > 0 THEN
	
		IF v_INGRESO.F_COBRO_BANCO IS NOT NULL THEN
			FECHA_COBRO:=v_INGRESO.F_COBRO_BANCO;
		ELSE
			FECHA_COBRO:=v_INGRESO.FECHA;
		END IF;
		
        CAL_DEMORA(FECHA_COBRO,xFINPEVOL, xTIPO, v_INGRESO.PRINCIPAL, INTERESES);
        
 	END IF;

      INT_PENDIENTE:=INT_PENDIENTE + INTERESES - v_INGRESO.DEMORA;

   END LOOP;

END;
/

/*****************************************************************************************/

--
-- Calcular los intereses de demora de los valores vivos de un expediente
--
-- Modificado: 22/06/2004. Agustín León Robles. Cambios de la Nueva Ley General Tributaria
--					Se añade un nuevo parametro que es el Final del Periodo voluntario a la llamada del Plazo de Apremio
--
/*BASE*/
CREATE OR REPLACE PROCEDURE CALCDEMORA_EXPE(
		xEXPE        IN INTEGER,
		xFecha       IN DATE,
		ModValores   IN CHAR,
		xModo        IN CHAR,
		intereses    OUT FLOAT,
		xDeuda_Total OUT FLOAT)
AS

	 xFinPeVol 			DATE;
	 xTipo 			char(2);
	 xPrincipal 		float;
	 xSuma 			float DEFAULT 0;
	 xValor 			integer;
	 xDemora 			float;
	 xSumaDemora 		float DEFAULT 0;
	 xIngresado 		float DEFAULT 0;
	 InteresesPendientes 	float DEFAULT 0;
	 xInteresesIngresados 	float DEFAULT 0;
	 xDem_Pendiente 		float DEFAULT 0;
	 xPendiente 		float;
	 xPrinEntre 		float DEFAULT 0;
	 xFNoti 			DATE;
	 xPuedo 			integer default 0;

	 CURSOR CDemora IS select principal,FIN_PE_VOL,TIPO_DE_TRIBUTO,ID,F_Notificacion,
		(PRINCIPAL + RECARGO + COSTAS + DEMORA - ENTREGAS_A_CUENTA +
		 DEMORA_PENDIENTE)
  		from VALORES
		where EXPEdiente=xEXPE
			AND F_INGRESO IS NULL
                  AND FECHA_DE_BAJA IS NULL
                  AND F_SUSPENSION IS NULL;

BEGIN

   xDeuda_Total:=0;
   intereses:=0;


   -- Modo de cobrar los intereses de demora:
   --   xModo="N" solo sobre el ultimo pago
   --   xModo="E" calcular sobre las entregas

   OPEN CDemora;
   LOOP

      FETCH CDemora INTO xPrincipal,xFinPeVol,xTipo,xValor,xFNoti,xPendiente;
      EXIT WHEN CDemora%NOTFOUND;

      -- hacer la suma de todas sus entregas a cuenta 
      select sum(PRINCIPAL),sum(DEMORA)
             into xPrinEntre,xInteresesIngresados
      from ingresos where valor=xValor;

      IF (xPrinEntre is null) THEN
         xPrinEntre:=0;
      END IF;

      IF (xInteresesIngresados is null) THEN
         xInteresesIngresados:=0;
      END IF;

      -- solo sobre el principal restante
      xPrincipal:=xPrincipal-xPrinEntre;

      xPuedo:=PLAZO_APREMIO(xFecha,xFNoti,xFinPeVol);

      IF (xPuedo=1) then
         CAL_DEMORA(xFecha,xFinPeVol,xTipo,xPRINCIPAL,Intereses);
      ELSE
         intereses:=0;
      END IF;

      IF (intereses is null) then
         intereses:=0;
      END IF;


      -- CALCULA LOS INTERESES PENDIENTES DE LAS ENTREGAS, siempre que se pueda 
      if (xModo='E') then
         Int_entregas(xValor,xFinPeVol,xTIPO,InteresesPendientes);
      end if;

      xDem_Pendiente:=InteresesPendientes + intereses;

	-- xDem_Pendiente es un valor que se guarda en valores y se acumula en xSuma
	-- que devuelve la suma.Para mantener la consistencia de la B.D. se hace el ROUND.
      xSuma:=xSuma+ROUND(xDem_Pendiente,2);

      IF (ModValores='S') then
         update valores set demora=xInteresesIngresados,
                            demora_pendiente=ROUND(xDem_Pendiente,2)
         where id=xValor;

         select PRINCIPAL + RECARGO + COSTAS +
                DEMORA - ENTREGAS_A_CUENTA + DEMORA_PENDIENTE
         into xPendiente
	   from valores where id=xValor;
      END IF;

      -- deuda pendiente es la del recibo menos las entregas 
      xDeuda_total:=xDeuda_total + xPendiente;
      xDem_Pendiente:=0;

   END LOOP;
   CLOSE CDemora;

   -- los intereses totales a la fecha menos los ya ingresados
   Intereses:=xSuma;

   -- indicamos que se le ha visitado, para no volver a pasar por aquí hoy mismo
   -- el control de llamar al procedimiento se realiza desde delphi
   UPDATE EXPEDIENTES SET F_Visita=SYSDATE WHERE ID=xEXPE;

END;
/

/*****************************************************************************************/

-- 05/02/2002 Antonio Pérez Caballero
--
-- Intereses que produce un expediente mensualmente, es sólo una coletilla
-- para poner al pie de un docuemnto de expedientes
--
CREATE OR REPLACE PROCEDURE INTERES_MES_EXPEDIENTE(
	xIDEXPE	IN	INTEGER,
      INTERESES 	OUT 	FLOAT)

AS
    	xSUMA 	FLOAT DEFAULT 0;
    	xSUMARECI 	FLOAT DEFAULT 0;
    	xSUMALIQUI 	FLOAT DEFAULT 0;
    	xSUMARECI_INGRE 	FLOAT DEFAULT 0;
    	xSUMALIQUI_INGRE 	FLOAT DEFAULT 0;

    	INTERECI 	FLOAT DEFAULT 0;
    	INTELIQUI 	FLOAT DEFAULT 0;

BEGIN

   INTERESES:=0;

   -- SUMAR LOS PRINCIPALES PENDIENTES DE TRIBUTOS

	SELECT SUM(PRINCIPAL) INTO xSUMARECI FROM VALORES
	   WHERE EXPEDIENTE=xIDEXPE
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND TIPO_DE_TRIBUTO='IM';

   -- SUMAR LOS PRINCIPALES INGRESADOS DE TRIBUTOS

	SELECT SUM(PRINCIPAL) INTO xSUMARECI_INGRE FROM INGRESOS
	WHERE VALOR IN (SELECT ID FROM VALORES
	   WHERE EXPEDIENTE=xIDEXPE
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND TIPO_DE_TRIBUTO='IM');


   -- SUMAR LOS PRINCIPALES PENDIENTES DE TASAS

	SELECT SUM(PRINCIPAL) INTO xSUMALIQUI FROM VALORES
	   WHERE EXPEDIENTE=xIDEXPE
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND TIPO_DE_TRIBUTO<>'IM';

   -- SUMAR LOS PRINCIPALES INGRESADOS DE TASAS

	SELECT SUM(PRINCIPAL) INTO xSUMALIQUI_INGRE FROM INGRESOS
	WHERE VALOR IN (SELECT ID FROM VALORES
	   WHERE EXPEDIENTE=xIDEXPE
		AND F_INGRESO IS NULL
		AND FECHA_DE_BAJA IS NULL
		AND F_SUSPENSION IS NULL
		AND TIPO_DE_TRIBUTO<>'IM');

   	IF xSUMARECI IS NULL THEN
         xSUMARECI:=0;
   	END IF;
      IF xSUMARECI_INGRE IS NULL THEN
         xSUMARECI_INGRE:=0;
   	END IF;
   	IF xSUMALIQUI IS NULL THEN
         xSUMALIQUI:=0;
   	END IF;
   	IF xSUMALIQUI_INGRE IS NULL THEN
         xSUMALIQUI_INGRE:=0;
   	END IF;


   	xSUMARECI:=xSUMARECI-xSUMARECI_INGRE;
   	xSUMALIQUI:=xSUMALIQUI-xSUMALIQUI_INGRE;

   	IF xSUMARECI > 0 THEN
         PkDemora.INTERES_DIARIO_VALOR(xSUMARECI,'IM',INTERECI);
      END IF;

      IF xSUMALIQUI > 0 THEN
         PkDemora.INTERES_DIARIO_VALOR(xSUMALIQUI,'TA',INTELIQUI);
   	END IF;

   -- El,interes diario lo multiplicamos por 30 y pasamos los intereses
   -- mensuales, pues en euros si pasamos el interes diarios saldrá un valor
   -- cero centimos despues de redondear.

   	INTERESES:=(INTERECI*30)+(INTELIQUI*30);

   UPDATE USUARIOS SET IMPORTE = ROUND(INTERESES,2)
   WHERE USUARIO=USER;

END;
/



--
-- Los intereses díarios que debería pagar un valor
--
/*DELPHI*/

CREATE OR REPLACE PROCEDURE INTERES_VALOR(mPrincipal 	IN	float,
      Tipo_Valor 	IN	char,
      intereses 	OUT	float)
AS
BEGIN

   PkDemora.INTERES_DIARIO_VALOR(mPrincipal, Tipo_Valor, Intereses);

END;
/

--
--
--
-- Indica para un valor si se permite que se recalculen intereses para
-- dicho valor si se encuentra en alguna tramitación de embargo con diligencia emitida.
CREATE OR REPLACE FUNCTION PERMITO_CALCULAR_INTERESES(xIDValor  IN INTEGER)
RETURN BOOLEAN

AS
xLetra           CHAR(1);
xZona		     CHAR(2);
xIDExpe          INTEGER;
xEmbCuentas      CHAR(1);
xEmbSalarios     CHAR(1);
xEmbInmuebles    CHAR(1);
xEmbVehiculos    CHAR(1);
xF_DiliCuentas   DATE;
xF_DiliSalarios  DATE;
xF_DiliInmuebles DATE;
xF_DiliVehiculos DATE;


BEGIN

  SELECT EXPEDIENTE,ID_DILIG_ECC,ID_SALARIOS,ID_INMUEBLES,ID_VEHICULOS
     INTO xIDExpe,xEmbCuentas, xEmbSalarios, xEmbInmuebles, xEmbVehiculos
  FROM VALORES WHERE ID=xIDValor;

  IF xIDexpe IS NULL THEN -- si no tiene expediente, puede calcular intereses (Si cumple los requisitos del Art.108)
	RETURN true;
  END IF;

  SELECT FECHA_DILI_CUENTAS,FECHA_DILI_SALARIOS, FECHA_DILI_INMUEBLES, FECHA_DILI_VEHICULOS
   	INTO xF_DiliCuentas, xF_DiliSalarios, xF_DiliInmuebles, xF_DiliVehiculos
  FROM EXPEDIENTES WHERE ID=xIDExpe;

  SELECT ZONA INTO xZona FROM USUARIOS WHERE USUARIO=USER;

  -- Si el valor apunta a un embargo de cuentas con diligencia emitida, se busca en configuración si bloquear intereses
  if (xEmbCuentas IS NOT NULL) AND (xF_DiliCuentas IS NOT NULL) then 
  
     SELECT SUBSTR(INTERESES_EN_EMBARGO,1,1) INTO xLETRA FROM CONFIGURACION
     WHERE ZONA=xZona;
     
     IF xLETRA='X' THEN -- Indica que no se pueden generar intereses
       RETURN false;
     END IF;

  -- Si el valor apunta a un embargo de salarios con diligencia emitida, se busca en configuración si bloquear intereses
  elsif (xEmbSalarios IS NOT NULL) AND (xF_DiliSalarios IS NOT NULL) then
     SELECT SUBSTR(INTERESES_EN_EMBARGO,2,1) INTO xLETRA FROM CONFIGURACION
     WHERE ZONA=xZona;

     IF xLETRA='X' THEN -- Indica que no se pueden generar intereses
       RETURN false;
     END IF;

  -- Si el valor apunta a un embargo de inmuebles con diligencia emitida, se busca en configuración si bloquear intereses
  elsif (xEmbInmuebles IS NOT NULL) AND (xF_DiliInmuebles IS NOT NULL) then
     SELECT SUBSTR(INTERESES_EN_EMBARGO,3,1) INTO xLETRA FROM CONFIGURACION
     WHERE ZONA=xZona;

     IF xLETRA='X' THEN -- Indica que no se pueden generar intereses
       RETURN false;
     END IF;

  -- Si el valor apunta a un embargo de vehiculos con diligencia emitida, se busca en configuración si bloquear intereses
  elsif (xEmbVehiculos IS NOT NULL) AND (xF_DiliVehiculos IS NOT NULL) then
     SELECT SUBSTR(INTERESES_EN_EMBARGO,4,1) INTO xLETRA FROM CONFIGURACION
     WHERE ZONA=xZona;

     IF xLETRA='X' THEN -- Indica que no se pueden generar intereses
       RETURN false;
     END IF;

  end if;


  RETURN true;

END;
/
-- Para que delphi pueda acceder a la función PERMITO_CALCULAR_INTERESES,
-- tengo que hacerlo a traves de un procedimiento.
CREATE OR REPLACE PROCEDURE PERMITO_CALCULAR_INTERESES2(
			xIDValor  IN INTEGER,
			xPuedo OUT INTEGER)
AS
BEGIN
   IF PERMITO_CALCULAR_INTERESES(xIDValor) THEN
	xPuedo:=1;
   ELSE
	xPuedo:=0;
   END IF;
END;
/

/******************************************************************************************/
COMMIT;
/********************************************************************/
