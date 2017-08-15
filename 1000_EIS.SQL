CREATE TABLE TMP_EIS(
	USUARIO CHAR(30) DEFAULT USER,
	N_CARGO CHAR(10),
	CUANTOS INTEGER,
	IMPORTE FLOAT
)TABLESPACE TEMPORALES;


CREATE OR REPLACE PROCEDURE RELLENA_TMP_EIS 
	(xLIMITE IN INTEGER)

AS
 xContador 		INTEGER;
 xResto		FLOAT;
 xRestoCuantos 	INTEGER;

 Cursor CCARGOS IS SELECT N_CARGO,SUM(PRINCIPAL) AS IMPORTE ,COUNT(*) AS CUANTOS
		FROM VALORES WHERE F_INGRESO IS NULL AND FECHA_DE_BAJA IS NULL
		GROUP BY N_CARGO ORDER BY IMPORTE DESC;

BEGIN

   xContador:=0;
   xResto:=0;
   xRestoCuantos:=0;
   delete from tmp_eis where usuario=User;

   FOR vCargos in CCARGOS LOOP
	xContador:=xContador+1;

	if xContador<xLimite then
		insert into tmp_eis(n_cargo,cuantos,importe) 
		values (vCargos.n_cargo,vCargos.Cuantos,vCargos.Importe);
	else
		xResto:=xResto+vCargos.Importe;
		xRestoCuantos:=xRestoCuantos+vCargos.Cuantos;
	end if;

   END LOOP;

   if xRestoCuantos>0 then
	insert into tmp_eis(n_cargo,cuantos,importe) 
	values ('OTROS',xRestoCuantos,xResto);
   end if;

END;
/

CREATE PUBLIC SYNONYM TMP_EIS FOR .TMP_EIS;
CREATE PUBLIC SYNONYM RELLENA_TMP_EIS FOR .RELLENA_TMP_EIS;