--
-- Crear las cuentas anuales de todo el área de gestión
--
/*          TIPOS
     PE -> Pendiente
     PB -> Pendiente por bonificación
     CV -> Cargos en Voluntaria
     CE -> Cargos en Ejecutiva 
     IV -> Ingresos en Voluntaria
     IR -> Ingresos sin recargo
     IE -> Ingresos en Ejecutiva
     BV -> Bajas en Voluntaria
     BE -> Bajas en Ejecutiva
     BI -> Bajas en Ejecutiva por Insolvencia
     BO -> Bajas en Ejecutiva por Otros Motivos
     BP -> Bajas en Ejecutiva por Prescripcion
     BR -> Bajas en Ejecutiva por reposicion a voluntaria
*/
-- Modificado: 04/03/2004. Lucas Fernández Pérez. 
-- Obtiene también el importe bonificado de los valores pendientes a 31 de diciembre.
--
CREATE OR REPLACE PROCEDURE MAKE_CUENTAS_ANUALES_Todo(xYear IN Char)
AS
xCuantos Integer;
BEGIN

  -- Borrar los datos previos si los hubiera
  Delete from cuentas_anuales where vYear=xYear;

  -- Consulta si hay datos del año anterior
  SELECT COUNT(*) INTO xCuantos FROM CUENTAS_ANUALES WHERE VYEAR=xYear-1;

  if xCuantos=0 then -- Si no hay datos del año anterior, calcula el pendiente a 01/01
  
	-- Pendiente al 1 de enero.
	PkCuentasAnuales.PendienteUnoEnero(xYear);
	-- Entregas a cuenta se descuentan del pendiente a 1 de enero
    PkCuentasAnuales.RemoveEntregas(xYear);
    
  else -- Si hay datos del año anterior, obtiene el pendiente a partir de esos datos
  	-- No hace cálculos, toma los datos	del año anterior para saber el pendiente a 01/01
	PkCuentasAnuales.Pendiente1EneroSinCalcular(xYear,'',''); 
  end if;

  -- Cargos en Voluntaria
  PkCuentasAnuales.CargosVoluntaria(xYear);

  -- Cargos en ejecutiva
  PkCuentasAnuales.CargosEjecutiva(xYear);

  -- Lee los ingresos
  PkCuentasAnuales.LeeIngresos(xYear);

  -- Lee los ingresos sin recargo, ejecutiva sin recargo
  PkCuentasAnuales.LeeIngresosSinRecargo(xYear);

  -- Leer los importes de las bajas
  PkCuentasAnuales.LeeBajas(xYear);
  
  -- Leer los importes bonificados de los valores pendientes
  PkCuentasAnuales.BonifiPendienteUnoEnero(xYear);

END;
/


--
-- Cuentas anuales para una zona
--
-- Modificado: 04/03/2004. Lucas Fernández Pérez. 
-- Obtiene también el importe bonificado de los valores pendientes a 31 de diciembre.
--
CREATE OR REPLACE PROCEDURE MAKE_CUENTAS_ANUALES_Zona(xYear IN Char, xZona IN Char)
AS
xCuantos Integer;
BEGIN

  -- Borrar los datos previos si los hubiera
  Delete from cuentas_anuales where vYear=xYear and Zona=xZona;

  -- Consulta si hay datos del año anterior
  SELECT COUNT(*) INTO xCuantos FROM CUENTAS_ANUALES WHERE VYEAR=xYear-1 and Zona=xZona;

  if xCuantos=0 then -- Si no hay datos del año anterior, calcula el pendiente a 01/01
    -- Pendiente al 1 de enero.
    PkCuentasAnuales.PendienteUnoEneroZona(xYear, xZona);

    -- Entregas a cuenta se descuentan del pendiente a 1 de enero
    PkCuentasAnuales.RemoveEntregasZona(xYear, xZona);
  else -- Si hay datos del año anterior, obtiene el pendiente a partir de esos datos
  	-- No hace cálculos, toma los datos	del año anterior para saber el pendiente a 01/01
	PkCuentasAnuales.Pendiente1EneroSinCalcular(xYear,'',xZona); 
  end if;

  -- Cargos en Voluntaria
  PkCuentasAnuales.CargosVoluntaria(xYear);

  -- Cargos en ejecutiva
  PkCuentasAnuales.CargosEjecutiva(xYear);

  -- Lee los ingresos
  PkCuentasAnuales.LeeZonaIngresos(xYear,xZona);

  -- Lee los ingresos sin recargo, ejecutiva sin recargo
  PkCuentasAnuales.LeeZonaIngresosSinRecargo(xYear,xZona);

  -- Leer los importres de las bajas
  PkCuentasAnuales.LeeZonaBajas(xYear,xZona);

  -- Leer los importes bonificados de los valores pendientes
  PkCuentasAnuales.BonifiPendienteUnoEneroZona(xYear,xZona);
END;
/

--
-- Cuentas anuales para un municipio en concreto
--
-- Modificado: 04/03/2004. Lucas Fernández Pérez. 
-- Obtiene también el importe bonificado de los valores pendientes a 31 de diciembre.
--
CREATE OR REPLACE PROCEDURE MAKE_CUENTAS_ANUALES_Ayto(xYear IN Char, xAyto IN Char)
AS
xCuantos INTEGER;
BEGIN

Delete from cuentas_anuales where vYear=xYear and Ayto=xAyto;

  -- Consulta si hay datos del año anterior
  SELECT COUNT(*) INTO xCuantos FROM CUENTAS_ANUALES WHERE VYEAR=xYear-1 and Ayto=xAyto;

  if xCuantos=0 then -- Si no hay datos del año anterior, calcula el pendiente a 01/01
    -- Pendiente al 1 de enero.
    PkCuentasAnuales.PendienteUnoEneroAyto(xYear, xAyto);
    -- Entregas a cuenta se descuentan del pendiente a 1 de enero
    PkCuentasAnuales.RemoveEntregasAyto(xYear, xAyto);
  else -- Si hay datos del año anterior, obtiene el pendiente a partir de esos datos
  	-- No hace cálculos, toma los datos	del año anterior para saber el pendiente a 01/01
	PkCuentasAnuales.Pendiente1EneroSinCalcular(xYear,xAyto,''); 
  end if;

  -- Cargos en Voluntaria
  PkCuentasAnuales.CargosVoluntaria(xYear);

  -- Cargos en ejecutiva
  PkCuentasAnuales.CargosEjecutiva(xYear);

  -- Lee los ingresos
  PkCuentasAnuales.LeeIngresos(xYear);

  -- Lee los ingresos sin recargo, ejecutiva sin recargo
  PkCuentasAnuales.LeeIngresosSinRecargo(xYear);

  -- Leer los importes de las bajas
  PkCuentasAnuales.LeeBajas(xYear);

  -- Leer los importes bonificados de los valores pendientes
  PkCuentasAnuales.BonifiPendienteUnoEnero(xYear);


END;
/

--
-- Antonio Pérez Caballero 13/02/2.002
--
-- Módulo de entrada para las distintas opciones de las cuentas anuales, general,
-- por zona de gestión, por municipio
-- xYear será el año que se va a preparar
-- xTipo 'T' todo 'Z' zona 'A' ayto
-- xZonaAyto el código de zona o de municipio
--
CREATE OR REPLACE PROCEDURE MAKE_CUENTAS_ANUALES(
      xYear		IN Char,
	xTipo		IN Char,
	xZonaAyto	IN Char)
AS
BEGIN


-- Del año completo
IF xTipo='T' THEN
   MAKE_CUENTAS_ANUALES_Todo(xYear);
END IF;

-- de una zona
IF xTipo='Z' THEN
   MAKE_CUENTAS_ANUALES_Zona(xYear, xZonaAyto);
END IF;

-- de un ayuntamiento
IF xTipo='A' THEN
   MAKE_CUENTAS_ANUALES_Ayto(xYear,  xZonaAyto);
END IF;


END;
/

