
--
-- Para poder organizar el orden de aplicación de ingresos en las entregas parciales
-- Podrá ser global para toda la organización base de datos de la tabla DATOSPERR
-- Por tipo de cliente Ayuntamientos, Junta tabla CLIENTES
-- Por cliente en función de la tabla MUNICIPIOS
--
-- Orden de aplicación en las entregas a cuenta
-- [P]rincipal [R]ecargo [C]ostas [D]emora
-- [+]Reparto proporcional de principal y recargo
--
--
-- Modo de uso: llamar al procedimiento main indicando el valor y el importe a entregar
-- nos muestra el resultado en las variables públicas xImportePRINCIPAL,xImporteRECARGO 
-- xImporteCOSTAS, xImporteDEMORA 
--
--
CREATE OR REPLACE PACKAGE PkEntregas
AS


TYPE T_Entrega IS RECORD (
	ID			VALORES.ID%TYPE,
	NOTIFICADO		VALORES.NOTIFICADO%TYPE,
	F_NOTIFICACION 	VALORES.F_NOTIFICACION%TYPE,
	CUOTA_INICIAL	VALORES.CUOTA_INICIAL%TYPE default 0,
	FUERA_PLAZO		VALORES.ENTREGAS_ANTESDEL_CARGO%TYPE default 0,
	PRINCIPAL		VALORES.PRINCIPAL%TYPE default 0,
	RECARGO		VALORES.RECARGO%TYPE default 0,
	DEMORA		VALORES.DEMORA%TYPE default 0,
	COSTAS		VALORES.COSTAS%TYPE default 0,
	ENTREGAS_A_CUENTA VALORES.ENTREGAS_A_CUENTA%TYPE default 0
);

--
-- Orden de aplicación en las entregas a cuenta
-- [P]rincipal [R]ecargo [C]ostas [D]emora
-- [+]Reparto proporcional de principal y recargo
--
xORDEN Char(4);
xIDValor INTEGER;
xImporteEntrega FLOAT;
--
-- Variables de resultado
--
xImportePRINCIPAL FLOAT;
xImporteRECARGO FLOAT;
xImporteCOSTAS FLOAT;
xImporteDEMORA FLOAT;
--
--
--
PROCEDURE EntregasReparto(xValor IN INTEGER, vcResultado OUT T_Entrega);

--
-- Recoger de la configuración el orden de aplicación de los ingresos
--
PROCEDURE GetConfig(xValor IN INTEGER);

--
-- Punto de entrada al paquete, función principal
--
PROCEDURE main(xValor IN INTEGER, xEntrega IN FLOAT);


END PkEntregas;
/

-- **************************************
--
-- **************************************
CREATE OR REPLACE PACKAGE BODY PkEntregas
AS


PROCEDURE EntregasReparto(xValor IN INTEGER, vcResultado OUT T_Entrega)
AS
xEntrega Float;
mParReca Float;
xoPrincipal Float;
xoRecargo Float;
xoCostas Float;
xoDemora Float;
xoPendiente Float;
xCiclo   Integer default 1;
BEGIN


xEntrega:=xImporteEntrega;

-- Obtengo los importes pendientes de cobrar
PkIngresos.Get_Pendiente(xValor, xoPrincipal, xoRecargo, 
								xoCostas, xoDemora, xoPendiente);


-- Mientras que quede algo por repartir

WHILE xEntrega > 0 LOOP

	-- Proporcional Principal Recargo
	IF SubStr(xORDEN, xCiclo, 1)='+' THEN

   		-- parte del principal y recargo en partes proporcionales
   		IF (xEntrega >= (xoPRINCIPAL + xoRECARGO))  THEN
         		xEntrega := xEntrega - (xoPRINCIPAL + xoRECARGO);
			vcResultado.PRINCIPAL:=xoPRINCIPAL;
			vcResultado.RECARGO:=xoRECARGO;
   		ELSE
			IF (xoPRINCIPAL > 0) THEN
			    -- Para obtener el grado de proporción
         		    mParReca   := xoRECARGO * 100 / xoPRINCIPAL; 
         		    mParReca   := (mParReca + 100) / 100;
         		    vcResultado.PRINCIPAL := Round((xEntrega / mParReca), 2);
         		    vcResultado.RECARGO   := xEntrega - vcResultado.PRINCIPAL;
			ELSE
         		    vcResultado.PRINCIPAL := 0;
         		    vcResultado.RECARGO   := xEntrega;
			END IF;

			xEntrega:=0;

   		END IF;


	END IF;

	-- Principal
	IF SubStr(xORDEN, xCiclo, 1)='P' THEN

	   IF xEntrega >= xoPRINCIPAL THEN

		xEntrega:= xEntrega - xoPRINCIPAL;
		vcResultado.PRINCIPAL:=xoPRINCIPAL;

	   ELSE
		vcResultado.PRINCIPAL:=xEntrega;
		xEntrega:=0;
	   END IF;

	END IF;

	-- Recargo
	IF SubStr(xORDEN, xCiclo, 1)='R' THEN

	   IF xEntrega >= xoRECARGO THEN

		xEntrega:= xEntrega - xoRECARGO;
		vcResultado.RECARGO:=xoRECARGO;

	   ELSE
		vcResultado.RECARGO:=xEntrega;
		xEntrega:=0;
	   END IF;

	END IF;

	-- Costas
	IF SubStr(xORDEN, xCiclo, 1)='C' THEN

	   IF xEntrega >= xoCOSTAS THEN

		xEntrega:= xEntrega - xoCOSTAS;
		vcResultado.COSTAS:=xoCOSTAS;

	   ELSE
		vcResultado.COSTAS:=xEntrega;
		xEntrega:=0;
	   END IF;

	END IF;

	-- Demora
	IF SubStr(xORDEN, xCiclo, 1)='D' THEN

	   IF xEntrega >= xoDEMORA THEN

		xEntrega:= xEntrega - xoDEMORA;
		vcResultado.DEMORA:=xoDEMORA;

	   ELSE
		vcResultado.DEMORA:=xEntrega;
		xEntrega:=0;
	   END IF;


	END IF;


      xCiclo:=xCiclo + 1;

END LOOP;

END;


--
-- Recoger la configuración
--
PROCEDURE GetConfig(xValor IN INTEGER)
AS
xMODO Char(1);
BEGIN

SELECT MODOENTREGA, ORDENINGRESO INTO xModo, xORDEN FROM DATOSPERR;

IF xModo<>'G' THEN

   IF xModo='T' THEN
      SELECT ORDENINGRESO INTO xORDEN FROM CLIENTES 
		WHERE TIPO = (SELECT TIPO_CLI FROM MUNICIPIOS 
		WHERE AYTO = (SELECT AYTO FROM VALORES WHERE ID=xValor));
   END IF;

   IF xModo='C' THEN
      SELECT ORDENINGRESO INTO xORDEN FROM MUNICIPIOS 
		WHERE AYTO = (SELECT AYTO FROM VALORES WHERE ID=xValor);
   END IF;

END IF;

END;

--
--
--
PROCEDURE main(xValor IN INTEGER, xEntrega IN FLOAT)
AS
vcResultado T_Entrega;
BEGIN

-- Asignar variables globales
xIDValor:=xValor;
xImporteEntrega:=xEntrega;

-- Leer la configuración
GetConfig(xIDValor);

-- Realizar el reparto de la entrega
EntregasReparto(xIDValor, vcResultado);

xImportePRINCIPAL:=vcResultado.PRINCIPAL;
xImporteRECARGO:=vcResultado.RECARGO;
xImporteCOSTAS:=vcResultado.COSTAS;
xImporteDEMORA:=vcResultado.DEMORA;


END;



END;
/