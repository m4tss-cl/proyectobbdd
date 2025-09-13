
-- definicion tipos de datos compuestos
CREATE OR REPLACE TYPE producto_rec IS OBJECT (
    id_pro      NUMBER,
    cantidad    NUMBER,
    precio_unitario NUMBER
);
/

CREATE OR REPLACE TYPE lista_productos_varray IS VARRAY(100) OF producto_rec;
/



--  PROCEDIMIENTO ALMACENADO
--  inserta una nueva cotización y todos sus detalles en una sola operación.

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


-- FUNCIÓN ALMACENADA
--   Calcula el monto total de una cotización específica.


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

--  BLOQUE DE PRUEBA
--    Ejecutar este bloque para probar los procedimientos y funciones.
SET SERVEROUTPUT ON;

DECLARE
    v_cotizacion_id   NUMBER := 999;
    v_lista_detalles  lista_productos_varray;
BEGIN
    DELETE FROM DETALLE_COT WHERE COTIZACION_id_coti = v_cotizacion_id;
    DELETE FROM COTIZACION WHERE id_coti = v_cotizacion_id;

    v_lista_detalles := lista_productos_varray(
        producto_rec(id_pro => 1, cantidad => 5, precio_unitario => 100.00),
        producto_rec(id_pro => 2, cantidad => 2, precio_unitario => 250.00)
    );

    insertar_cotizacion_completa(
        p_cotizacion_id   => v_cotizacion_id,
        p_fecha           => SYSDATE,
        p_estado          => 'Pendiente',
        p_cliente_id_cli  => 1,
        p_detalles_prod   => v_lista_detalles
    );

    DBMS_OUTPUT.PUT_LINE('El monto total de la cotización es: ' || calcular_monto_total_cot(v_cotizacion_id));

    COMMIT;
END;
/
