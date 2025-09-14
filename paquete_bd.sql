CREATE OR REPLACE PACKAGE UtilidadesBd IS
    -- Procedimiento para generar órdenes de compra a proveedores
    PROCEDURE generar_orden_proveedor(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER,
        p_cantidad     IN NUMBER,
        p_orden_id     OUT NUMBER
    );
    
    -- Función para verificar si un proveedor maneja un producto específico
    FUNCTION verificar_proveedor_producto(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER
    ) RETURN NUMBER;
    
END UtilidadesBd;
/

CREATE OR REPLACE PACKAGE BODY UtilidadesBd IS

    PROCEDURE generar_orden_proveedor(
        p_proveedor_id IN NUMBER,
        p_producto_id  IN NUMBER,
        p_cantidad     IN NUMBER,
        p_orden_id     OUT NUMBER
    ) IS
        v_siguiente_id  NUMBER;
        v_proveedor_existe NUMBER;
    BEGIN
        -- Verificar que el proveedor maneja este producto
        v_proveedor_existe := verificar_proveedor_producto(p_proveedor_id, p_producto_id);
        
        IF v_proveedor_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'El proveedor no maneja este producto');
        END IF;
        
        -- Obtener siguiente ID para la orden
        SELECT NVL(MAX(id_ord), 0) + 1 
        INTO v_siguiente_id 
        FROM ORDEN_COM;
        
        -- Insertar orden de compra
        INSERT INTO ORDEN_COM (
            id_ord,
            fecha_pedido,
            estado_pedido,
            fecha_esperada_entrega,
            PROVEEDOR_id_prov
        ) VALUES (
            v_siguiente_id,
            SYSDATE,
            'PENDIENTE',
            SYSDATE + 7, -- 7 días de plazo por defecto
            p_proveedor_id
        );
        
        -- Insertar detalle de la orden
        INSERT INTO DET_ORDEN_COM (
            id_det_com,
            cantidad,
            ORDEN_COM_id_ord,
            PRODUCTO_id_pro
        ) VALUES (
            v_siguiente_id * 1000 + 1,
            p_cantidad,
            v_siguiente_id,
            p_producto_id
        );
        
        p_orden_id := v_siguiente_id;
        
        DBMS_OUTPUT.PUT_LINE('Orden de compra generada exitosamente. ID: ' || p_orden_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
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
        WHERE PROVEEDOR_id_prov = p_proveedor_id
        AND PRODUCTO_id_pro = p_producto_id;
        
        RETURN v_existe;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error al verificar proveedor-producto: ' || SQLERRM);
            RETURN 0;
    END verificar_proveedor_producto;

END UtilidadesBd; 