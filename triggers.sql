-- TRIGGERS A NIVEL DE SENTENCIA Y DE FILA

-- crear tabla de auditoría si no existe
CREATE TABLE AUDITORIA_LOG (
    id_log NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_operacion DATE DEFAULT SYSDATE,
    usuario VARCHAR2(50),
    tabla_afectada VARCHAR2(50),
    tipo_operacion VARCHAR2(10),
    cantidad_registros NUMBER
);
/

-- trigger a nivel de sentencia (sin FOR EACH ROW)
-- audita operaciones sobre la tabla ORDEN_COM
CREATE OR REPLACE TRIGGER auditoria_ordenes_compra
AFTER INSERT OR UPDATE OR DELETE ON ORDEN_COM
DECLARE
    v_usuario VARCHAR2(50);
    v_tipo_operacion VARCHAR2(10);
    v_cantidad NUMBER := 0;
BEGIN
    -- obtener usuario actual
    SELECT USER INTO v_usuario FROM DUAL;
    
    -- determinar tipo de operación
    IF INSERTING THEN
        v_tipo_operacion := 'INSERT';
        -- Contar registros insertados
        SELECT COUNT(*) INTO v_cantidad FROM ORDEN_COM 
        WHERE fecha_pedido >= SYSDATE - INTERVAL '1' SECOND;
    ELSIF UPDATING THEN
        v_tipo_operacion := 'UPDATE';
        v_cantidad := 1; -- a nivel de sentencia, estimamos
    ELSIF DELETING THEN
        v_tipo_operacion := 'DELETE';
        v_cantidad := 1;
    END IF;
    
    -- registrar en tabla de auditoría
    INSERT INTO AUDITORIA_LOG (
        fecha_operacion,
        usuario,
        tabla_afectada,
        tipo_operacion,
        cantidad_registros
    ) VALUES (
        SYSDATE,
        v_usuario,
        'ORDEN_COM',
        v_tipo_operacion,
        v_cantidad
    );
    
    DBMS_OUTPUT.PUT_LINE('[AUDITORÍA] Operación ' || v_tipo_operacion || 
                         ' registrada en ORDEN_COM por usuario ' || v_usuario);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en trigger de auditoría: ' || SQLERRM);
        -- No hacer ROLLBACK para no afectar la operación principal
END auditoria_ordenes_compra;
/

-- TRIGGER A NIVEL DE SENTENCIA
-- valida que no se inserten más de 100 cotizaciones por día
CREATE OR REPLACE TRIGGER validar_limite_cotizaciones
BEFORE INSERT ON COTIZACION
DECLARE
    v_cotizaciones_hoy NUMBER;
    v_limite CONSTANT NUMBER := 100;
BEGIN
    -- contar cotizaciones del día
    SELECT COUNT(*)
    INTO v_cotizaciones_hoy
    FROM COTIZACION
    WHERE TRUNC(fecha) = TRUNC(SYSDATE);
    
    IF v_cotizaciones_hoy >= v_limite THEN
        RAISE_APPLICATION_ERROR(-20003, 
            'se ha alcanzado el límite de ' || v_limite || 
            ' cotizaciones por día. Total actual: ' || v_cotizaciones_hoy);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('validación de límite ok. cotizaciones hoy: ' || v_cotizaciones_hoy);

EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20003 THEN
            RAISE; -- Re-lanzar el error personalizado
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error en validación de límite: ' || SQLERRM);
        END IF;
END validar_limite_cotizaciones;
/

-- TRIGGER A NIVEL DE FILA
-- valida que la cantidad en detalles sea positiva
CREATE OR REPLACE TRIGGER validar_cantidad_detalle
BEFORE INSERT OR UPDATE ON DETALLE_COT
FOR EACH ROW
BEGIN
    IF :NEW.cantidad <= 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 
            'La cantidad debe ser mayor a cero. Valor recibido: ' || :NEW.cantidad);
    END IF;
    
    IF :NEW.precio_unitario < 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 
            'El precio unitario no puede ser negativo');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END validar_cantidad_detalle;
/