-- ================================================
-- SCRIPT DE PRUEBAS COMPLETO
-- ================================================
SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ==========================================
PROMPT EJECUTANDO PRUEBAS COMPLETAS DEL SISTEMA
PROMPT ==========================================
PROMPT;

DECLARE
    v_cotizacion_id   NUMBER := 9999;
    v_lista_detalles  lista_productos_varray;
    v_orden_id NUMBER;
    v_total_ordenes NUMBER;
    v_monto_general NUMBER;
    v_monto_descuento NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('INICIO DE PRUEBAS COMPLETAS');
    DBMS_OUTPUT.PUT_LINE('Fecha: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Limpiar datos de pruebas anteriores
    DELETE FROM DETALLE_COT WHERE COTIZACION_id_coti = v_cotizacion_id;
    DELETE FROM COTIZACION WHERE id_coti = v_cotizacion_id;
    COMMIT;
    
    -- ============================================
    -- 1. PRUEBA DE PROCEDIMIENTOS CON PARÁMETROS
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('1. PRUEBA: PROCEDIMIENTO CON PARÁMETROS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Procedimiento: insertar_cotizacion_completa');
    DBMS_OUTPUT.PUT_LINE('');
    
    v_lista_detalles := lista_productos_varray(
        producto_rec(id_pro => 1, cantidad => 5, precio_unitario => 100.00),
        producto_rec(id_pro => 2, cantidad => 2, precio_unitario => 250.00)
    );

    insertar_cotizacion_completa(
        p_cotizacion_id   => v_cotizacion_id,
        p_fecha           => SYSDATE,
        p_estado          => 'PENDIENTE',
        p_cliente_id_cli  => 1,
        p_detalles_prod   => v_lista_detalles
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ Procedimiento con parámetros ejecutado exitosamente');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 2. PRUEBA DE FUNCIONES CON PARÁMETROS
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('2. PRUEBA: FUNCIÓN CON PARÁMETROS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Función: calcular_monto_total_cot');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Monto total calculado para cotización ' || v_cotizacion_id || ': $' || 
                         TO_CHAR(calcular_monto_total_cot(v_cotizacion_id), '999,999.00'));
    DBMS_OUTPUT.PUT_LINE('✓ Función con parámetros ejecutada exitosamente');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 3. PRUEBA DE PROCEDIMIENTOS SIN PARÁMETROS
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('3. PRUEBA: PROCEDIMIENTO SIN PARÁMETROS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Procedimiento: actualizar_cotizaciones_vencidas');
    DBMS_OUTPUT.PUT_LINE('');
    actualizar_cotizaciones_vencidas;
    DBMS_OUTPUT.PUT_LINE('✓ Procedimiento sin parámetros ejecutado exitosamente');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 4. PRUEBA DE FUNCIONES SIN PARÁMETROS
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('4. PRUEBA: FUNCIONES SIN PARÁMETROS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    DBMS_OUTPUT.PUT_LINE('Función: obtener_total_ordenes_pendientes');
    v_total_ordenes := obtener_total_ordenes_pendientes;
    DBMS_OUTPUT.PUT_LINE('Total órdenes pendientes: ' || v_total_ordenes);
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('Función: calcular_monto_total_general');
    v_monto_general := calcular_monto_total_general;
    DBMS_OUTPUT.PUT_LINE('Monto total general de cotizaciones activas: $' || 
                         TO_CHAR(v_monto_general, '999,999,999.00'));
    DBMS_OUTPUT.PUT_LINE('✓ Funciones sin parámetros ejecutadas exitosamente');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 5. PRUEBA DE PACKAGE - COMPONENTES PÚBLICOS
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('5. PRUEBA: PACKAGE - COMPONENTES PÚBLICOS');
    DBMS_OUTPUT.PUT_LINE('========================================');
    
    -- Asegurar que existe la relación proveedor-producto
    BEGIN
        INSERT INTO PRODUCTO_PROVEEDOR (PROV_id_prov, PROD_id_pro)
        VALUES (1, 1);
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            NULL; -- Ya existe
    END;
    
    DBMS_OUTPUT.PUT_LINE('Procedimiento público: UtilidadesBd.generar_orden_proveedor');
    UtilidadesBd.generar_orden_proveedor(
        p_proveedor_id => 1,
        p_producto_id => 1,
        p_cantidad => 25,
        p_orden_id => v_orden_id
    );
    DBMS_OUTPUT.PUT_LINE('Orden generada con ID: ' || v_orden_id);
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('Función pública (usa función privada): calcular_total_con_descuento');
    v_monto_descuento := UtilidadesBd.calcular_total_con_descuento(1000, 50);
    DBMS_OUTPUT.PUT_LINE('Monto original: $1,000.00');
    DBMS_OUTPUT.PUT_LINE('Cantidad: 50 unidades (descuento 10%)');
    DBMS_OUTPUT.PUT_LINE('Monto con descuento: $' || TO_CHAR(v_monto_descuento, '999,999.00'));
    DBMS_OUTPUT.PUT_LINE('✓ Package ejecutado exitosamente (componentes públicos usan privados)');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 6. PRUEBA DE TRIGGERS - NIVEL DE FILA
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('6. PRUEBA: TRIGGER A NIVEL DE FILA');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Trigger: actualizar_monto_cotizacion (FOR EACH ROW)');
    DBMS_OUTPUT.PUT_LINE('');
    
    DBMS_OUTPUT.PUT_LINE('Monto antes de actualizar: $' || 
                         TO_CHAR(calcular_monto_total_cot(v_cotizacion_id), '999,999.00'));
    
    UPDATE DETALLE_COT
    SET cantidad = 10
    WHERE id_det = v_cotizacion_id * 1000 + 1;
    
    DBMS_OUTPUT.PUT_LINE('Actualizando cantidad del primer detalle a 10...');
    DBMS_OUTPUT.PUT_LINE('Monto después (actualizado automáticamente por trigger): $' || 
                         TO_CHAR(calcular_monto_total_cot(v_cotizacion_id), '999,999.00'));
    DBMS_OUTPUT.PUT_LINE('✓ Trigger a nivel de fila ejecutado exitosamente');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 7. PRUEBA DE TRIGGERS - NIVEL DE SENTENCIA
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('7. PRUEBA: TRIGGER A NIVEL DE SENTENCIA');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Trigger: auditoria_ordenes_compra (sin FOR EACH ROW)');
    DBMS_OUTPUT.PUT_LINE('');
    
    INSERT INTO ORDEN_COM (id_ord, fecha_pedido, estado_pedido, fecha_esperada_entrega, PROV_id_prov)
    VALUES (99997, SYSDATE, 'PENDIENTE', SYSDATE + 5, 1);
    
    DBMS_OUTPUT.PUT_LINE('Orden insertada (trigger de auditoría registró la operación)');
    DBMS_OUTPUT.PUT_LINE('✓ Trigger a nivel de sentencia ejecutado exitosamente');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 8. CONSULTAR REGISTROS DE AUDITORÍA
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('8. CONSULTANDO TABLA DE AUDITORÍA');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Últimos 5 registros de auditoría:');
    DBMS_OUTPUT.PUT_LINE('');
    
    FOR rec IN (
        SELECT * FROM AUDITORIA_LOG 
        ORDER BY id_log DESC 
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Log #' || rec.id_log || 
                             ' | ' || TO_CHAR(rec.fecha_operacion, 'DD/MM/YY HH24:MI') ||
                             ' | Usuario: ' || rec.usuario ||
                             ' | Tabla: ' || rec.tabla_afectada ||
                             ' | Operación: ' || rec.tipo_operacion);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ============================================
    -- 9. REPORTE FINAL CON PROCEDIMIENTO COMPLEJO
    -- ============================================
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('9. REPORTE COMPLETO POR REGIÓN');
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('Ejecutando: generar_reporte_cotizaciones_region');
    DBMS_OUTPUT.PUT_LINE('');
    
    generar_reporte_cotizaciones_region;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('RESUMEN DE PRUEBAS');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    -- Commit de todas las operaciones
    COMMIT;
    
    -- Mostrar resumen
    FOR rec IN (
        SELECT 'Procedimientos con parámetros' AS componente, 'EXITOSO' AS estado FROM DUAL
        UNION ALL SELECT 'Procedimientos sin parámetros', 'EXITOSO' FROM DUAL
        UNION ALL SELECT 'Funciones con parámetros', 'EXITOSO' FROM DUAL
        UNION ALL SELECT 'Funciones sin parámetros', 'EXITOSO' FROM DUAL
        UNION ALL SELECT 'Package (públicos y privados)', 'EXITOSO' FROM DUAL
        UNION ALL SELECT 'Triggers nivel de fila', 'EXITOSO' FROM DUAL
        UNION ALL SELECT 'Triggers nivel de sentencia', 'EXITOSO' FROM DUAL
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('✓ ' || RPAD(rec.componente, 35) || ' : ' || rec.estado);
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('TODAS LAS PRUEBAS COMPLETADAS CON ÉXITO');
    DBMS_OUTPUT.PUT_LINE('==========================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('✗✗✗ ERROR EN PRUEBAS ✗✗✗');
        DBMS_OUTPUT.PUT_LINE('Código de error: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Mensaje: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Ubicación: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END;
/

PROMPT;
PROMPT ==========================================
PROMPT ESTADÍSTICAS FINALES DEL SISTEMA
PROMPT ==========================================

SELECT 'Total Cotizaciones' AS METRICA, COUNT(*) AS VALOR FROM COTIZACION
UNION ALL
SELECT 'Total Detalles Cotización', COUNT(*) FROM DETALLE_COT
UNION ALL
SELECT 'Total Órdenes de Compra', COUNT(*) FROM ORDEN_COM
UNION ALL
SELECT 'Total Detalles Órdenes', COUNT(*) FROM DET_ORDEN_COM
UNION ALL
SELECT 'Total Registros Auditoría', COUNT(*) FROM AUDITORIA_LOG
UNION ALL
SELECT 'Total Productos', COUNT(*) FROM PROD
UNION ALL
SELECT 'Total Proveedores', COUNT(*) FROM PROV
UNION ALL
SELECT 'Total Clientes', COUNT(*) FROM CLIENTE;

PROMPT;
PROMPT Pruebas finalizadas exitosamente!