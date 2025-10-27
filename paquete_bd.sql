-- PACKAGE CON COMPONENTES PÚBLICOS Y PRIVADOS
CREATE OR REPLACE PACKAGE UtilidadesBd IS
    -- DECLARACIONES PÚBLICAS (SPEC)
    -- procedimiento para generar órdenes de compra a proveedores
    PROCEDURE generar_orden_proveedor(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER,
        p_cantidad     IN NUMBER,
        p_orden_id     OUT NUMBER
    );
    
    -- función para verificar si un proveedor maneja un producto específico
    FUNCTION verificar_proveedor_producto(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER
    ) RETURN NUMBER;
    
    -- procedimiento para procesar múltiples órdenes de forma masiva
    PROCEDURE procesar_ordenes_masivas(
        p_proveedor_id IN NUMBER
    );
    
    -- función pública para calcular total con descuento
    FUNCTION calcular_total_con_descuento(
        p_monto IN NUMBER,
        p_cantidad IN NUMBER
    ) RETURN NUMBER;
    
END UtilidadesBd;
/

CREATE OR REPLACE PACKAGE BODY UtilidadesBd IS

    -- COMPONENTES PRIVADOS
    -- constante privada para descuento mínimo
    c_descuento_minimo CONSTANT NUMBER := 0.05;
    
    -- función privada: calcula porcentaje de descuento según cantidad
    FUNCTION calcular_porcentaje_descuento(p_cantidad IN NUMBER) 
    RETURN NUMBER 
    IS
        v_descuento NUMBER;
    BEGIN
        IF p_cantidad >= 100 THEN
            v_descuento := 0.15; -- 15% descuento
        ELSIF p_cantidad >= 50 THEN
            v_descuento := 0.10; -- 10% descuento
        ELSIF p_cantidad >= 20 THEN
            v_descuento := 0.05; -- 5% descuento
        ELSE
            v_descuento := 0;    -- Sin descuento
        END IF;
        
        RETURN v_descuento;
    END calcular_porcentaje_descuento;
    
    -- procedimiento PRIVADO: registra log interno
    PROCEDURE registrar_log_interno(
        p_mensaje IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- en un caso real, esto insertaría en una tabla de logs
        DBMS_OUTPUT.PUT_LINE('[LOG INTERNO] ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' || p_mensaje);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            NULL; -- Log silencioso
    END registrar_log_interno;

    -- implementacion de componentes publicos

    PROCEDURE generar_orden_proveedor(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER,
        p_cantidad     IN NUMBER,
        p_orden_id     OUT NUMBER
    ) IS
        v_siguiente_id  NUMBER;
        v_proveedor_existe NUMBER;
    BEGIN
        -- usar función privada para log
        registrar_log_interno('Iniciando generación de orden para proveedor ' || p_proveedor_id);
        
        -- verificar que el proveedor maneja este producto
        v_proveedor_existe := verificar_proveedor_producto(p_proveedor_id, p_producto_id);
        
        IF v_proveedor_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'El proveedor no maneja este producto');
        END IF;
        
        -- obtener siguiente ID para la orden
        SELECT NVL(MAX(id_ord), 0) + 1 
        INTO v_siguiente_id 
        FROM ORDEN_COM;
        
        -- insertar orden de compra
        INSERT INTO ORDEN_COM (
            id_ord,
            fecha_pedido,
            estado_pedido,
            fecha_esperada_entrega,
            PROV_id_prov
        ) VALUES (
            v_siguiente_id,
            SYSDATE,
            'PENDIENTE',
            SYSDATE + 7,
            p_proveedor_id
        );
        
        -- insertar detalle de la orden
        INSERT INTO DET_ORDEN_COM (
            id_det_com,
            cantidad,
            ORDEN_COM_id_ord,
            PROD_id_pro
        ) VALUES (
            v_siguiente_id * 1000 + 1,
            p_cantidad,
            v_siguiente_id,
            p_producto_id
        );
        
        p_orden_id := v_siguiente_id;
        
        registrar_log_interno('Orden generada exitosamente. ID: ' || p_orden_id);
        DBMS_OUTPUT.PUT_LINE('Orden de compra generada exitosamente. ID: ' || p_orden_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            registrar_log_interno('Error al generar orden: ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20002, 'Error al generar orden: ' || SQLERRM);
    END generar_orden_proveedor;

    FUNCTION verificar_proveedor_producto(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER
    ) RETURN NUMBER IS
        v_existe NUMBER := 0;
    BEGIN
        SELECT COUNT(*)
        INTO v_existe
        FROM PRODUCTO_PROVEEDOR
        WHERE PROV_id_prov = p_proveedor_id
        AND PROD_id_pro = p_producto_id;
        
        RETURN v_existe;
        
    EXCEPTION
        WHEN OTHERS THEN
            registrar_log_interno('Error al verificar proveedor-producto: ' || SQLERRM);
            RETURN 0;
    END verificar_proveedor_producto;
    
    -- procedimiento público que usa función privada
    PROCEDURE procesar_ordenes_masivas(
        p_proveedor_id IN NUMBER
    ) IS
        CURSOR cur_productos IS
            SELECT DISTINCT pp.PROD_id_pro, p.nom_pro
            FROM PRODUCTO_PROVEEDOR pp
            INNER JOIN PROD p ON pp.PROD_id_pro = p.id_pro
            WHERE pp.PROV_id_prov = p_proveedor_id;
        
        v_orden_id NUMBER;
        v_cantidad_fija NUMBER := 10;
    BEGIN
        registrar_log_interno('Procesando órdenes masivas para proveedor ' || p_proveedor_id);
        
        FOR rec IN cur_productos LOOP
            generar_orden_proveedor(
                p_proveedor_id => p_proveedor_id,
                p_producto_id => rec.PROD_id_pro,
                p_cantidad => v_cantidad_fija,
                p_orden_id => v_orden_id
            );
            
            DBMS_OUTPUT.PUT_LINE('Orden creada para producto: ' || rec.nom_pro);
        END LOOP;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Proceso de órdenes masivas completado.');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error en procesamiento masivo: ' || SQLERRM);
    END procesar_ordenes_masivas;
    
    -- función pública que usa función privada interna
    FUNCTION calcular_total_con_descuento(
        p_monto IN NUMBER,
        p_cantidad IN NUMBER
    ) RETURN NUMBER IS
        v_porcentaje NUMBER;
        v_total NUMBER;
    BEGIN
        -- usar la función privada
        v_porcentaje := calcular_porcentaje_descuento(p_cantidad);
        v_total := p_monto - (p_monto * v_porcentaje);
        
        registrar_log_interno('Descuento aplicado: ' || (v_porcentaje * 100) || '%');
        
        RETURN v_total;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN p_monto; -- devolver monto sin descuento en caso de error
    END calcular_total_con_descuento;

END UtilidadesBd;
/