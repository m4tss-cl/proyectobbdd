-- ------------------------------------------------
-- Definiciones de tipos de datos compuestos
-- ------------------------------------------------
CREATE OR REPLACE TYPE producto_rec IS OBJECT (
    id_pro      NUMBER,
    cantidad    NUMBER,
    precio_unitario NUMBER
);
/

CREATE OR REPLACE TYPE lista_productos_varray IS VARRAY(100) OF producto_rec;
/


-- ------------------------------------------------
-- 1. PROCEDIMIENTO ALMACENADO
--    Inserta una nueva cotización y todos sus detalles en una sola operación.
--    Ahora utiliza el tipo VARRAY.
-- ------------------------------------------------

CREATE OR REPLACE PROCEDURE insertar_cotizacion_completa (
    p_cotizacion_id   IN  NUMBER,
    p_fecha           IN  DATE,
    p_estado          IN  VARCHAR2,
    p_cliente_id_cli  IN  NUMBER,
    p_detalles_prod   IN  lista_productos_varray
)
IS
    v_monto_total NUMBER(10, 2) := 0;
BEGIN
    FOR i IN 1..p_detalles_prod.COUNT LOOP
        v_monto_total := v_monto_total + (p_detalles_prod(i).cantidad * p_detalles_prod(i).precio_unitario);
    END LOOP;

    INSERT INTO COTIZACION (
        id_coti,
        fecha,
        monto_total,
        estado,
        CLIENTE_id_cli
    ) VALUES (
        p_cotizacion_id,
        p_fecha,
        v_monto_total,
        p_estado,
        p_cliente_id_cli
    );

    FOR i IN 1..p_detalles_prod.COUNT LOOP
        INSERT INTO DETALLE_COT (
            id_det,
            cantidad,
            precio_unitario,
            COTIZACION_id_coti,
            PRODUCTO_id_pro
        ) VALUES (
            p_cotizacion_id * 1000 + i,
            p_detalles_prod(i).cantidad,
            p_detalles_prod(i).precio_unitario,
            p_cotizacion_id,
            p_detalles_prod(i).id_pro
        );
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Cotización insertada con éxito. ID: ' || p_cotizacion_id);

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al insertar cotización completa: ' || SQLERRM);
END insertar_cotizacion_completa;
/


-- ------------------------------------------------
-- 2. FUNCIÓN ALMACENADA
--    Calcula el monto total de una cotización específica.
-- ------------------------------------------------

CREATE OR REPLACE FUNCTION calcular_monto_total_cot (
    p_cotizacion_id IN NUMBER
)
RETURN NUMBER
IS
    v_total_monto NUMBER(10, 2) := 0;
BEGIN
    SELECT
        SUM(cantidad * precio_unitario)
    INTO
        v_total_monto
    FROM
        DETALLE_COT
    WHERE
        COTIZACION_id_coti = p_cotizacion_id;

    RETURN v_total_monto;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en la función calcular_monto_total_cot: ' || SQLERRM);
        RETURN -1;
END calcular_monto_total_cot;
/


-- ------------------------------------------------
-- 3. TRIGGER
--    Actualiza el monto total de la cotización después de una inserción,
--    actualización o eliminación en los detalles.
-- ------------------------------------------------
CREATE OR REPLACE TRIGGER actualizar_monto_cotizacion
AFTER INSERT OR UPDATE OR DELETE ON DETALLE_COT
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_cotizacion_id NUMBER;
BEGIN
    IF INSERTING OR UPDATING THEN
        v_cotizacion_id := :NEW.COTIZACION_id_coti;
    ELSE
        v_cotizacion_id := :OLD.COTIZACION_id_coti;
    END IF;

    UPDATE COTIZACION
    SET
        monto_total = calcular_monto_total_cot(v_cotizacion_id)
    WHERE
        id_coti = v_cotizacion_id;
    
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error en el trigger actualizar_monto_cotizacion: ' || SQLERRM);
END actualizar_monto_cotizacion;
/


-- ------------------------------------------------
-- 4. CURSOR EXPLÍCITO COMPLEJO
--    Busca productos por ID con información detallada de proveedores y ubicación.
-- ------------------------------------------------

DECLARE
    CURSOR cursor_producto_detallado(p_producto_id NUMBER) IS
        SELECT p.id_pro,
               p.nom_pro,
               p.ref,
               pr.id_prov,
               pr.nom_prov,
               c.nom_com AS comuna_proveedor,
               r.nom_reg AS region_proveedor,
               COUNT(pp.PROV_id_prov) AS total_proveedores
        FROM PROD p
        LEFT JOIN PRODUCTO_PROVEEDOR pp ON p.id_pro = pp.PROD_id_pro
        LEFT JOIN PROV pr ON pp.PROV_id_prov = pr.id_prov
        LEFT JOIN COMUNA c ON pr.COMUNA_id_com = c.id_com
        LEFT JOIN REGION r ON c.REGION_id_reg = r.id_reg
        WHERE p.id_pro = p_producto_id
        GROUP BY p.id_pro, p.nom_pro, p.ref, pr.id_prov, pr.nom_prov, c.nom_com, r.nom_reg
        ORDER BY pr.nom_prov;

    v_producto_id NUMBER := 1;
    v_registro cursor_producto_detallado%ROWTYPE;
    v_encontrado BOOLEAN := FALSE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== BÚSQUEDA DETALLADA DE PRODUCTO ===');
    DBMS_OUTPUT.PUT_LINE('Buscando producto ID: ' || v_producto_id);
    DBMS_OUTPUT.PUT_LINE('');
    
    OPEN cursor_producto_detallado(v_producto_id);
    
    LOOP
        FETCH cursor_producto_detallado INTO v_registro;
        EXIT WHEN cursor_producto_detallado%NOTFOUND;
        
        v_encontrado := TRUE;
        
        IF cursor_producto_detallado%ROWCOUNT = 1 THEN
            DBMS_OUTPUT.PUT_LINE('Producto: ' || v_registro.nom_pro);
            DBMS_OUTPUT.PUT_LINE('ID: ' || v_registro.id_pro || ' | Referencia: ' || NVL(TO_CHAR(v_registro.ref), 'Sin referencia'));
            DBMS_OUTPUT.PUT_LINE('Proveedores disponibles:');
            DBMS_OUTPUT.PUT_LINE('------------------------');
        END IF;
        
        IF v_registro.id_prov IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('- ' || v_registro.nom_prov || 
                                 ' (ID: ' || v_registro.id_prov || ')');
            DBMS_OUTPUT.PUT_LINE('  Ubicación: ' || v_registro.comuna_proveedor || 
                                 ', ' || v_registro.region_proveedor);
        END IF;
    END LOOP;
    
    IF NOT v_encontrado THEN
        DBMS_OUTPUT.PUT_LINE('No se encontró el producto con ID: ' || v_producto_id);
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Total de registros procesados: ' || cursor_producto_detallado%ROWCOUNT);
    END IF;
    
    CLOSE cursor_producto_detallado;
    
EXCEPTION
    WHEN OTHERS THEN
        IF cursor_producto_detallado%ISOPEN THEN
            CLOSE cursor_producto_detallado;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error en cursor de producto: ' || SQLERRM);
END;
/


-- ------------------------------------------------
-- 5. PROCEDIMIENTO CON LOOPS ANIDADOS
--    Genera reporte de cotizaciones agrupadas por cliente y región.
-- ------------------------------------------------

CREATE OR REPLACE PROCEDURE generar_reporte_cotizaciones_region
IS
    CURSOR cursor_regiones IS
        SELECT id_reg, nom_reg
        FROM REGION
        ORDER BY nom_reg;
    
    CURSOR cursor_clientes_region(p_region_id NUMBER) IS
        SELECT c.id_cli, c.nom_emp, c.p_nom, c.p_ape, com.nom_com
        FROM CLIENTE c
        INNER JOIN COMUNA com ON c.COMUNA_id_com = com.id_com
        WHERE com.REGION_id_reg = p_region_id
        ORDER BY c.nom_emp;
    
    CURSOR cursor_cotizaciones_cliente(p_cliente_id NUMBER) IS
        SELECT cot.id_coti, cot.fecha, cot.monto_total, cot.estado,
               COUNT(det.id_det) AS total_items
        FROM COTIZACION cot
        LEFT JOIN DETALLE_COT det ON cot.id_coti = det.COTIZACION_id_coti
        WHERE cot.CLIENTE_id_cli = p_cliente_id
        GROUP BY cot.id_coti, cot.fecha, cot.monto_total, cot.estado
        ORDER BY cot.fecha DESC;
    
    v_total_cotizaciones_region NUMBER;
    v_monto_total_region NUMBER(12,2);
    v_total_cotizaciones_cliente NUMBER;
    v_monto_total_cliente NUMBER(12,2);
    v_total_general NUMBER(12,2) := 0;
    v_contador_regiones NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('======================================');
    DBMS_OUTPUT.PUT_LINE('REPORTE DE COTIZACIONES POR REGIÓN');
    DBMS_OUTPUT.PUT_LINE('======================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    FOR reg IN cursor_regiones LOOP
        v_contador_regiones := v_contador_regiones + 1;
        v_total_cotizaciones_region := 0;
        v_monto_total_region := 0;
        
        DBMS_OUTPUT.PUT_LINE('REGIÓN: ' || reg.nom_reg || ' (ID: ' || reg.id_reg || ')');
        DBMS_OUTPUT.PUT_LINE(RPAD('=', LENGTH('REGIÓN: ' || reg.nom_reg || ' (ID: ' || reg.id_reg || ')'), '='));
        
        FOR cli IN cursor_clientes_region(reg.id_reg) LOOP
            v_total_cotizaciones_cliente := 0;
            v_monto_total_cliente := 0;
            
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('  Cliente: ' || cli.nom_emp);
            DBMS_OUTPUT.PUT_LINE('  Contacto: ' || NVL(cli.p_nom, '') || ' ' || NVL(cli.p_ape, ''));
            DBMS_OUTPUT.PUT_LINE('  Comuna: ' || cli.nom_com);
            DBMS_OUTPUT.PUT_LINE('  ' || RPAD('-', 50, '-'));
            
            FOR cot IN cursor_cotizaciones_cliente(cli.id_cli) LOOP
                v_total_cotizaciones_cliente := v_total_cotizaciones_cliente + 1;
                v_monto_total_cliente := v_monto_total_cliente + cot.monto_total;
                
                DBMS_OUTPUT.PUT_LINE('    Cotización #' || cot.id_coti || 
                                     ' | Fecha: ' || TO_CHAR(cot.fecha, 'DD/MM/YYYY') ||
                                     ' | Estado: ' || cot.estado);
                DBMS_OUTPUT.PUT_LINE('    Monto: $' || TO_CHAR(cot.monto_total, '999,999,990.00') ||
                                     ' | Items: ' || cot.total_items);
                DBMS_OUTPUT.PUT_LINE('');
            END LOOP;
            
            IF v_total_cotizaciones_cliente > 0 THEN
                DBMS_OUTPUT.PUT_LINE('  RESUMEN CLIENTE: ' || v_total_cotizaciones_cliente || 
                                     ' cotizaciones, Total: $' || 
                                     TO_CHAR(v_monto_total_cliente, '999,999,990.00'));
                
                v_total_cotizaciones_region := v_total_cotizaciones_region + v_total_cotizaciones_cliente;
                v_monto_total_region := v_monto_total_region + v_monto_total_cliente;
            ELSE
                DBMS_OUTPUT.PUT_LINE('  Sin cotizaciones registradas');
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('RESUMEN REGIÓN ' || reg.nom_reg || ':');
        DBMS_OUTPUT.PUT_LINE('Total cotizaciones: ' || v_total_cotizaciones_region);
        DBMS_OUTPUT.PUT_LINE('Monto total: $' || TO_CHAR(v_monto_total_region, '999,999,990.00'));
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE(RPAD('=', 60, '='));
        DBMS_OUTPUT.PUT_LINE('');
        
        v_total_general := v_total_general + v_monto_total_region;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('RESUMEN GENERAL DEL REPORTE:');
    DBMS_OUTPUT.PUT_LINE('============================');
    DBMS_OUTPUT.PUT_LINE('Regiones procesadas: ' || v_contador_regiones);
    DBMS_OUTPUT.PUT_LINE('Monto total general: $' || TO_CHAR(v_total_general, '999,999,990.00'));
    DBMS_OUTPUT.PUT_LINE('Fecha del reporte: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'));

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en reporte de cotizaciones: ' || SQLERRM);
END generar_reporte_cotizaciones_region;
/

-- ================================================
-- PROCEDIMIENTOS Y FUNCIONES ADICIONALES
-- ================================================

-- ------------------------------------------------
-- PROCEDIMIENTO SIN PARÁMETROS
-- Actualiza el estado de cotizaciones vencidas
-- ------------------------------------------------
CREATE OR REPLACE PROCEDURE actualizar_cotizaciones_vencidas
IS
    v_actualizados NUMBER := 0;
BEGIN
    UPDATE COTIZACION
    SET estado = 'VENCIDA'
    WHERE estado = 'PENDIENTE'
    AND fecha < SYSDATE - 30; -- Cotizaciones con más de 30 días
    
    v_actualizados := SQL%ROWCOUNT;
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Cotizaciones actualizadas a VENCIDA: ' || v_actualizados);
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error al actualizar cotizaciones vencidas: ' || SQLERRM);
END actualizar_cotizaciones_vencidas;
/

-- ------------------------------------------------
-- FUNCIÓN SIN PARÁMETROS
-- Obtiene el total de órdenes de compra pendientes
-- ------------------------------------------------
CREATE OR REPLACE FUNCTION obtener_total_ordenes_pendientes
RETURN NUMBER
IS
    v_total NUMBER := 0;
BEGIN
    SELECT COUNT(*)
    INTO v_total
    FROM ORDEN_COM
    WHERE estado_pedido = 'PENDIENTE';
    
    RETURN v_total;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al contar órdenes pendientes: ' || SQLERRM);
        RETURN -1;
END obtener_total_ordenes_pendientes;
/

-- ------------------------------------------------
-- FUNCIÓN SIN PARÁMETROS
-- Calcula el monto total de todas las cotizaciones activas
-- ------------------------------------------------
CREATE OR REPLACE FUNCTION calcular_monto_total_general
RETURN NUMBER
IS
    v_total NUMBER(12,2) := 0;
BEGIN
    SELECT NVL(SUM(monto_total), 0)
    INTO v_total
    FROM COTIZACION
    WHERE estado IN ('PENDIENTE', 'APROBADA');
    
    RETURN v_total;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al calcular monto total general: ' || SQLERRM);
        RETURN 0;
END calcular_monto_total_general;
/