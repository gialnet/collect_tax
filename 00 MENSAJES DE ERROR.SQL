
raise_application_error

(-20001,'No se pueden realizar ingresos con fecha: '
	||to_char(xFecha,'dd/mm/yyyy')||' porque hay una data ');
  
(-20002,'El importe que está intentando retener es superior a la deuda del expediente ');
(-20003,'Este valor ya está en un embargo de inmuebles con garantías afectadas');
(-20004,'No puedo desagrupar valor está en un Fraccionamiento');
(-20005,'No puedo desagrupar valor está en un Expediente con tramites');
(-20006,'No se puede reponer un Ingreso Datado');
(-20007,'Error en la fecha del final del periodo voluntario: '
			||to_char(mFinPeVol,'dd/mm/yyyy'));
(-20008,'No se puede embargar un inmueble para un expediente con menos de '||xMenor||' pesetas');
(-20009,'El valor debe estar notificado ');
(-20010,'Se rompe el orden en que se realizaron los ingresos ');
(-20011,'Error de conversión a valor numérico: comprobar valor de EMISORA');
(-20012,'Error de conversión a valor numérico: comprobar valor de SUFIJO');
(-20013,'No se puede reponer un Ingreso de fuera de plazo en O.E.');
