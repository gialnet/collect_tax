
-- para poner como ingresos parciales algunos ingresos anteriores a la version de Oracle
select concepto,fecha from ingresos where concepto like 'Pago%'
and parcial_o_cobro='C' and tipo_ingreso='EF'
and valor in (select id from valores where f_ingreso is null and fecha_de_baja is null)
order by fecha

update ingresos set parcial_o_cobro='P'
where concepto like 'Pago%'
and parcial_o_cobro='C' and tipo_ingreso='EF'
and valor in (select id from valores where f_ingreso is null and fecha_de_baja is null);





-- actualizar en la tabla de valores el ID del embargos de autos
create or replace procedure ActualizaValorVehiculos
as
cursor cVehiculos is select id,idexpe from embargos_autos;
begin

			
	for vVehiculos in cVehiculos loop

		update valores set id_inmuebles=vVehiculos.id where expediente=vVehiculos.idexpe
			and id_inmuebles is null
			and f_ingreso is null and fecha_de_baja is null and f_suspension is null;

	end loop;


end;
/
execute ActualizaValorVehiculos;
drop procedure ActualizaValorVehiculos;




--de los recibos que tengan costas acceder a la tabla de costas_valores y actualizar en valores
create or replace procedure Arregla_Costas
as
xCostas float default 0;
cursor cValores IS
	select id from valores where f_ingreso is null and fecha_de_baja is null
				and f_suspension is null and costas=0
	for update of costas;

begin

	for vValores IN cValores loop

		select sum(importe) into xCostas from costas_valores where valor=vValores.ID;

		if xCostas is null then
			xCostas:=0;
		end if;

		update valores set costas=xCostas where current of cValores;

	end loop;

end;
/
execute Arregla_Costas;
drop procedure Arregla_Costas;


create or replace procedure Arregla_Ingresos
as
cursor cIngresos IS
	select sum(principal+recargo+costas+demora) as TotalIngresos,sum(demora) AS DEMORA,
		sum(costas) as costas,valor 
	from ingresos group by valor;
begin


	for v_Ingresos IN cIngresos loop
		update valores set entregas_a_cuenta=v_ingresos.TotalIngresos,
					DEMORA=v_ingresos.DEMORA,
					COSTAS=v_ingresos.COSTAS
				where id=v_Ingresos.Valor;
	end loop;
end;
/
execute Arregla_Ingresos;
drop procedure Arregla_Ingresos;



alter TRIGGER TR_HISTORIA_VALORES disable;
alter TRIGGER T_UPD_VALORES disable;
alter TRIGGER T_UPDVALORES_EXPE disable;

create or replace procedure Pagado_SinIngresar
as
xFecha date;
cursor c_Valores IS select id,pendiente
	 from valoresexpe
	where f_ingreso is null
	and fecha_de_baja is null
	and f_suspension is null
	and pendiente<=0;
begin

for v_Valores IN c_valores loop

	select max(fecha) into xFecha from ingresos where valor=v_Valores.ID;

	if xFecha is not null then
		update valores set DEMORA_PENDIENTE=0,f_ingreso=xFecha
			where ID=v_Valores.ID;
	end if;

end loop;

end;
/
EXECUTE Pagado_SinIngresar;

alter TRIGGER TR_HISTORIA_VALORES enable;
alter TRIGGER T_UPD_VALORES enable;
alter TRIGGER T_UPDVALORES_EXPE enable;





--
-- ajustar los valores ingresados con lo realmente ingresado
--
create or replace procedure Arregla_Valores_Ingresos
as
xTotal 	float;
xDemora	float;
xCostas	float;
cursor cIngresos IS
	select id from valoresexpe where f_ingreso is not null
			and pendiente>0;
begin


	for v_Ingresos IN cIngresos loop

		select sum(principal+recargo+costas+demora) as TotalIngresos,
			sum(demora) AS DEMORA,
			sum(costas) as costas
		into xTotal,xDemora,xCostas
		from ingresos where valor=v_Ingresos.ID;

		update valores set entregas_a_cuenta=xTotal,
					DEMORA=xDemora,
					COSTAS=xCostas
				where id=v_Ingresos.ID;
	end loop;
end;
/
execute Arregla_Valores_Ingresos;
drop procedure Arregla_Valores_Ingresos;








--
--para salobreña
update valores set f_notificacion=null,notificado='N' where ayto='176' and n_cargo
in ('2001/00092','2001/00110','2001/00107','2001/00086','2001/00064','2001/00063','2001/00062',
'2001/00061','2001/00090','2001/00095','2001/00083','2001/00122','2001/00121','2001/00120',
'2001/00119','2001/00118','2001/00117','2001/00116','2001/00115','2001/00109','2001/00108',
'2001/00096','2001/00097','2001/00099','2001/00098','2001/00084','2001/00080','2001/00103',
'2001/00079','2001/00078','2001/00077','2001/00076','2001/00075','2001/00073','2001/00074',
'2001/00071','2001/00106','2001/00069','2001/00070','2001/00065','2001/00060','2001/00057',
'2001/00055','2001/00111','2001/00113','2001/00082','2001/00072','2001/00094','2001/00056',
'2001/00081','2001/00112','2001/00091','2001/00059','2001/00058','2001/00067','2001/00066',
'2001/00102','2001/00104','2001/00105','2001/00100','2001/00101','2001/00087','2001/00089',
'2001/00088','2001/00085')




select id from expedientes where embargo='4' and esta_embargo='C' 
and f_ingreso is null and f_anulacion is null and f_suspension is null
and id in (select idexpe from embargos_inmuebles);

update expedientes set esta_embargo='O' where embargo='4' and esta_embargo='C' 
and f_ingreso is null and f_anulacion is null and f_suspension is null
and id in (select idexpe from embargos_inmuebles);




update expedientes set fecha_diligencia=null where 
	embargo='0' and fecha_diligencia is not null;
update expedientes set fecha_diligencia=null where 
	embargo='1' and esta_embargo='P' and fecha_diligencia is not null;
update expedientes set fecha_diligencia=null where 
	embargo='3' and esta_embargo='P' and fecha_diligencia is not null;
update expedientes set fecha_diligencia=null where 
	embargo='4' and esta_embargo='P' and fecha_diligencia is not null;
update expedientes set fecha_diligencia=null where 
	embargo='8' and esta_embargo='P' and fecha_diligencia is not null;
update expedientes set fecha_diligencia=null where 
	embargo='X' and esta_embargo='P' and fecha_diligencia is not null;




--actualizar en expedientes si tiene fecha de diligencia
create or replace procedure Ajusta_Expedientes
as
xFDiligencia	date;

cursor cExpedientes IS select id,embargo,esta_embargo from expedientes 
			where f_ingreso is null and f_anulacion is null
		for update of fecha_diligencia;
begin

   FOR v_Expedientes IN cExpedientes LOOP

			xFDiligencia:=null;

			if v_Expedientes.Embargo='1' and v_Expedientes.esta_embargo='O' then
				begin
					select f_diligencia into xFDiligencia from embargos_cuentas 
						where idexpe=v_Expedientes.ID;
				exception
					when no_data_found then
						xFDiligencia:=null;
				end;			
			elsif v_Expedientes.Embargo='3' and v_Expedientes.esta_embargo='O' then
				begin
					select f_diligencia into xFDiligencia from embargos_salarios
						where idexpe=v_Expedientes.ID;
				exception
					when no_data_found then
						xFDiligencia:=null;
				end;
			elsif v_Expedientes.Embargo='4' and v_Expedientes.esta_embargo='O' then
				begin
					select f_diligencia into xFDiligencia from embargos_inmuebles
						where idexpe=v_Expedientes.ID;
				exception
					when no_data_found then
						xFDiligencia:=null;
				end;
			elsif v_Expedientes.Embargo='8' and v_Expedientes.esta_embargo='O' then
				begin
					select f_diligencia into xFDiligencia from embargos_autos
						where idexpe=v_Expedientes.ID;
				exception
					when no_data_found then
						xFDiligencia:=null;
				end;
			end if;

			if xFDiligencia is not null then
				update expedientes set fecha_diligencia=xFDiligencia
					where current of cExpedientes;
			end if;
   END LOOP;

end;
/
execute ajusta_expedientes;
drop procedure ajusta_expedientes;
