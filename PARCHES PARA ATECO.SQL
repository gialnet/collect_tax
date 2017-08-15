--
-- volver a meter los recibos que se desagruparon de caja castilla la mancha
--
--
create or replace procedure PegarExpeCajaCastillaLaMancha
as
xExpediente	integer;
xPosible	integer;
cursor cValores is select id,expediente,NIF
	from valores where ayto='102' and padron in ('000002','000003')
	and f_ingreso is null and fecha_De_baja is null and expediente is null;
begin

	for vValores in cValores loop

		begin
			Select ID into xExpediente from Expedientes 
				where ayto='102' and Deudor=vValores.NIF
				and f_ingreso is null and f_anulacion is null;
		exception
			when no_data_found then
				xExpediente:=null;			
		end;

		if xExpediente is not null then
			PEGA_EXPE(xExpediente,vValores.ID,1,xPosible);
		else
			PkEXPEDIENTES.MakeExpe(vValores.NIF, '102', '02',SYSDATE);
		end if;

	end loop;

end;
/

drop procedure PegarExpeCajaCastillaLaMancha;

--
-- desagrupar de los expedientes de CCM (caja castilla la mancha) que superen los 60 euros quitar los recibos
-- de los conceptos 2 y 3 (irpf e impuesto de sociedades)
--
create or replace procedure QuitaExpeCajaCastillaLaMancha
as

xExpediente integer;

cursor cEmbargos is select expediente from PendiValoresExpe where expediente in 
	(Select idexpe from embargos_cuentas
	where ZONA='02' AND Lote='2003/00001'
			and PUEDO_DILIGENCIA='S' 
			and IDExpe in (select IDExpe from cuentas_lotes
		       where entidad='2105' and diligencia='N')
			and IDExpe in (Select ID from expedientes 
      					where f_ingreso is null
						and f_anulacion is null)) and pendiente>60;

cursor cValores is select id from valores where expediente=xExpediente and padron in ('000002','000003')
	and f_ingreso is null and fecha_De_baja is null;

begin

	for vEmbargos in cEmbargos loop

		xExpediente:=vEmbargos.Expediente;

		for vValores in cValores loop

			DESAGRUPA_EXPE(vValores.ID);

		end loop;

	end loop;

end;
/


drop procedure QuitaExpeCajaCastillaLaMancha;





--
-- 
--
create or replace procedure UpdateImporteDili
as
xDeudaTotal float DEFAULT 0;

cursor cEmbargos is select * from embargos_cuentas where trunc(f_diligencia,'dd')='02/04/2003'
for update of deuda_total;
begin


	for vEmbargos in cEmbargos loop


			PkIngresos.Get_PendienteRetenido(vEmbargos.IDExpe, xDeudaTotal);

			UPDATE EMBARGOS_CUENTAS SET DEUDA_TOTAL = round(xDeudaTotal,2)
			WHERE current of cEmbargos;

			update cuentas_lotes set DEUDA_A_EMBARGAR=round(xDeudaTotal,2)
			where trunc(f_diligencia,'dd')='02/04/2003' and IdExpe=vEmbargos.IdExpe;

	end loop;

end;
/

drop procedure UpdateImporteDili;

--
-- Añadir costas a un expediente de forma que cada 7 recibos tenían 5.70 de costas y ahora tienen que pasar a 10.10
--
--	Este procedimiento es especial para ATECO
--
create or replace procedure AddCostasAtecoEmbargo(xAyto in char, xCostasYaGrabadas in float)
as
xCodigoOperacion	float;
xImporteCosta	float;
xCostas		float;
xCuantos		integer;

cursor cCostas is select id from expedientes where f_ingreso is null and f_anulacion is null
	and ayto=xAyto and embargo='1' and esta_embargo='O';

begin

	xImporteCosta:=10.10 - xCostasYaGrabadas;

	for vCostas in cCostas loop

		select count(*) into xCuantos from valores where expediente=vCostas.ID;

		--cada 7 recibos es un envio
		-- Cuando el resto sea 0 no hay que incrementar la variable ya que sera 7/7 14/7 21/7 etc.

		if Mod(xCuantos , 7) = 0 then
			xCostas := xImporteCosta * Trunc(xCuantos/7);
		else
			xCostas := xImporteCosta * (Trunc(xCuantos/7)+1);
		end if;

		ADD_COSTA_EXPE(vCostas.ID,xCostas,'COSTA DE CORREO EMBARGO CUENTAS FASE 3',xCodigoOperacion);

	end loop;

end;
/





--
-- Añadir costas a un expediente de forma que cada 7 recibos tenían 4.70 de costas y ahora tienen que pasar a 10.10
--
--	Este procedimiento es especial para ATECO, es igual que el de arriba pero se añaden costas por conceptos, o sea
--		10.10 de costas por cada concepto
create or replace procedure AddCostasAtecoEmbargo
				(xAyto 				in		char, 
				xPadron				in		char,
				xCostasYaGrabadas 	in		float)
as
xCodigoOperacion	float;
xImporteCosta		float;
xCostas				float;
xCuantos			integer;

cursor cCostas is select id from expedientes where f_ingreso is null and f_anulacion is null
	and ayto=xAyto and embargo='1' and esta_embargo='O';

begin

	xImporteCosta:=10.10 - xCostasYaGrabadas;

	for vCostas in cCostas loop

		select count(*) into xCuantos 
		from valores 
		where expediente=vCostas.ID --xand N_Cargo IN ('2003/00004','2003/00005','2003/00006')
		and Padron=xPadron;

		-- cada 7 recibos es un envio
		-- Cuando el resto sea 0 no hay que incrementar la variable ya que sera 7/7 14/7 21/7 etc.

		if Mod(xCuantos , 7) = 0 then
			xCostas := xImporteCosta * Trunc(xCuantos/7);
		else
			xCostas := xImporteCosta * (Trunc(xCuantos/7)+1);
		end if;
		
		if xCuantos > 0 then
		
			ADD_COSTA_EXPE(vCostas.ID,xCostas,'COSTA DE CORREO EMBARGO CUENTAS FASE 3',xCodigoOperacion);
			
		end if;

	end loop;

end;
/





create or replace procedure AddCuentasCajaCastillaLaMancha
as

cursor cCuentas is select id,Deudor,expediente from expedientes where f_ingreso is null and f_anulacion is null
	and ayto=xAyto and embargo='1' and esta_embargo='O';

begin


	for vCuentas in cCuentas loop

		PASA_CUENTAS_DEL_CONTRI(vCuentas.Deudor,'2003/00061','02',vCuentas.Expediente,vCuentas.ID);

	end loop;

end;
/
