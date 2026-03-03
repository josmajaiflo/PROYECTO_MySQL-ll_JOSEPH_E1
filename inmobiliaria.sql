DROP DATABASE IF EXISTS inmobiliaria;
CREATE DATABASE inmobiliaria;
USE inmobiliaria;

-- TABLAS DE APOYO (NORMALIZACIÓN)

CREATE TABLE tipo_propiedad (
    tipo_propiedad_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE estado_propiedad (
    estado_propiedad_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE tipo_contrato (
    tipo_contrato_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE estado_contrato (
    estado_contrato_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE estado_pago (
    estado_pago_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE metodo_pago (
    metodo_pago_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

-- TABLAS PRINCIPALES

CREATE TABLE agente (
    agente_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    licencia VARCHAR(50),
    telefono VARCHAR(20),
    email VARCHAR(100)
);

CREATE TABLE cliente (
    cliente_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    documento VARCHAR(50),
    telefono VARCHAR(20),
    email VARCHAR(100),
    direccion VARCHAR(150)
);

CREATE TABLE propiedad (
    propiedad_id INT AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    direccion VARCHAR(150) NOT NULL,
    ciudad VARCHAR(100) NOT NULL,
    area_m2 FLOAT,
    habitaciones INT,
    banos INT,
    precio DECIMAL(12,2) NOT NULL,
    fecha_registro DATE NOT NULL,
    tipo_propiedad_id INT NOT NULL,
    estado_propiedad_id INT NOT NULL,
    agente_id INT NOT NULL,
    FOREIGN KEY (tipo_propiedad_id) REFERENCES tipo_propiedad(tipo_propiedad_id),
    FOREIGN KEY (estado_propiedad_id) REFERENCES estado_propiedad(estado_propiedad_id),
    FOREIGN KEY (agente_id) REFERENCES agente(agente_id)
);

CREATE TABLE contrato (
    contrato_id INT AUTO_INCREMENT PRIMARY KEY,
    numero VARCHAR(50) UNIQUE NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE,
    fecha_firma DATE NOT NULL,
    valor_total DECIMAL(12,2) NOT NULL,
    tipo_contrato_id INT NOT NULL,
    estado_contrato_id INT NOT NULL,
    propiedad_id INT NOT NULL,
    cliente_id INT NOT NULL,
    agente_id INT NOT NULL,
    FOREIGN KEY (tipo_contrato_id) REFERENCES tipo_contrato(tipo_contrato_id),
    FOREIGN KEY (estado_contrato_id) REFERENCES estado_contrato(estado_contrato_id),
    FOREIGN KEY (propiedad_id) REFERENCES propiedad(propiedad_id),
    FOREIGN KEY (cliente_id) REFERENCES cliente(cliente_id),
    FOREIGN KEY (agente_id) REFERENCES agente(agente_id)
);

CREATE TABLE pago (
    pago_id INT AUTO_INCREMENT PRIMARY KEY,
    contrato_id INT NOT NULL,
    fecha_pago DATE NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    estado_pago_id INT NOT NULL,
    metodo_pago_id INT NOT NULL,
    referencia VARCHAR(100),
    FOREIGN KEY (contrato_id) REFERENCES contrato(contrato_id),
    FOREIGN KEY (estado_pago_id) REFERENCES estado_pago(estado_pago_id),
    FOREIGN KEY (metodo_pago_id) REFERENCES metodo_pago(metodo_pago_id)
);

-- AUDITORÍA Y REPORTES

CREATE TABLE auditoria_propiedad (
    auditoria_id INT AUTO_INCREMENT PRIMARY KEY,
    propiedad_id INT,
    fecha_evento DATETIME,
    usuario VARCHAR(100),
    accion VARCHAR(50),
    detalle VARCHAR(255),
    FOREIGN KEY (propiedad_id) REFERENCES propiedad(propiedad_id)
);

DROP TABLE IF EXISTS reporte_pagos_pendientes;

CREATE TABLE reporte_pagos_pendientes (
    reporte_id INT AUTO_INCREMENT PRIMARY KEY,
    contrato_id INT,
    cliente_id INT,
    propiedad_id INT,
    deuda DECIMAL(12,2),
    fecha_generacion DATETIME,
    FOREIGN KEY (contrato_id) REFERENCES contrato(contrato_id),
    FOREIGN KEY (cliente_id) REFERENCES cliente(cliente_id),
    FOREIGN KEY (propiedad_id) REFERENCES propiedad(propiedad_id)
);
-- FUNCIONES

DROP FUNCTION IF EXISTS calcular_comision;

DELIMITER $$

CREATE FUNCTION calcular_comision(p_contrato_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(12,2);
    DECLARE tipo VARCHAR(50);

    SELECT c.valor_total, tc.nombre
    INTO total, tipo
    FROM contrato c
    JOIN tipo_contrato tc ON c.tipo_contrato_id = tc.tipo_contrato_id
    WHERE c.contrato_id = p_contrato_id;

    IF tipo = 'Venta' THEN
        RETURN total * 0.03;
    ELSE
        RETURN 0;
    END IF;
END$$

DELIMITER ;

DELIMITER $$

DROP FUNCTION IF EXISTS deuda_contrato$$

CREATE FUNCTION deuda_contrato(p_contrato_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(12,2);
    DECLARE pagado DECIMAL(12,2);

    SELECT valor_total INTO total
    FROM contrato
    WHERE contrato_id = p_contrato_id;

    SELECT IFNULL(SUM(monto),0) INTO pagado
    FROM pago
    WHERE contrato_id = p_contrato_id
      AND estado_pago_id = (
          SELECT estado_pago_id
          FROM estado_pago
          WHERE nombre = 'Aprobado'
      );

    RETURN total - pagado;
END$$

DELIMITER ;
DELIMITER $$

DROP FUNCTION IF EXISTS total_propiedades_disponibles$$

CREATE FUNCTION total_propiedades_disponibles(p_tipo_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total INT;

    SELECT COUNT(*)
    INTO total
    FROM propiedad
    WHERE tipo_propiedad_id = p_tipo_id
      AND estado_propiedad_id = (
          SELECT estado_propiedad_id
          FROM estado_propiedad
          WHERE nombre = 'Disponible'
      );

    RETURN total;
END$$

DELIMITER ;


-- TRIGGERS
DROP TRIGGER IF EXISTS trg_propiedad_cambio_estado;

DELIMITER $$

CREATE TRIGGER trg_propiedad_cambio_estado
AFTER UPDATE ON propiedad
FOR EACH ROW
BEGIN
    DECLARE estado_old VARCHAR(50);
    DECLARE estado_new VARCHAR(50);

    IF OLD.estado_propiedad_id <> NEW.estado_propiedad_id THEN

        SELECT nombre INTO estado_old
        FROM estado_propiedad
        WHERE estado_propiedad_id = OLD.estado_propiedad_id;

        SELECT nombre INTO estado_new
        FROM estado_propiedad
        WHERE estado_propiedad_id = NEW.estado_propiedad_id;

        INSERT INTO auditoria_propiedad
        (propiedad_id, fecha_evento, usuario, accion, detalle)
        VALUES
        (OLD.propiedad_id, NOW(), USER(), 'CAMBIO_ESTADO',
         CONCAT(estado_old, ' -> ', estado_new));
    END IF;
END$$

DELIMITER ;

DROP TRIGGER IF EXISTS trg_actualizar_estado_propiedad;

DELIMITER $$

CREATE TRIGGER trg_actualizar_estado_propiedad
AFTER INSERT ON contrato
FOR EACH ROW
BEGIN
    DECLARE v_estado INT;
    DECLARE v_tipo VARCHAR(50);

    SELECT nombre
    INTO v_tipo
    FROM tipo_contrato
    WHERE tipo_contrato_id = NEW.tipo_contrato_id;

    IF v_tipo = 'Venta' THEN
        SELECT estado_propiedad_id INTO v_estado
        FROM estado_propiedad WHERE nombre = 'Vendida';
    ELSE
        SELECT estado_propiedad_id INTO v_estado
        FROM estado_propiedad WHERE nombre = 'Arrendada';
    END IF;

    UPDATE propiedad
    SET estado_propiedad_id = v_estado
    WHERE propiedad_id = NEW.propiedad_id;
END$$

DELIMITER ;
DROP TRIGGER IF EXISTS trg_nuevo_contrato;

DELIMITER $$

CREATE TRIGGER trg_nuevo_contrato
AFTER INSERT ON contrato
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_propiedad
    (propiedad_id, fecha_evento, usuario, accion, detalle)
    VALUES
    (NEW.propiedad_id, NOW(), USER(), 'NUEVO_CONTRATO',
     CONCAT('Contrato ID ', NEW.contrato_id, ' creado'));
END$$

DELIMITER ;

-- SEGURIDAD (ROLES)

-- ELIMINAR ROLES SI YA EXISTEN
DROP ROLE IF EXISTS rol_admin;
DROP ROLE IF EXISTS rol_agente;
DROP ROLE IF EXISTS rol_contador;

-- CREAR ROLES
CREATE ROLE rol_admin;
CREATE ROLE rol_agente;
CREATE ROLE rol_contador;

DROP USER IF EXISTS 'admin_inmo'@'%';
DROP USER IF EXISTS 'agente_inmo'@'%';
DROP USER IF EXISTS 'contador_inmo'@'%';

CREATE USER 'admin_inmo'@'%' IDENTIFIED BY 'Admin123!';
CREATE USER 'agente_inmo'@'%' IDENTIFIED BY 'Agente123!';
CREATE USER 'contador_inmo'@'%' IDENTIFIED BY 'Contador123!';

GRANT ALL PRIVILEGES ON inmobiliaria.* TO rol_admin;

GRANT SELECT, INSERT, UPDATE ON inmobiliaria.propiedad TO rol_agente;
GRANT SELECT, INSERT ON inmobiliaria.contrato TO rol_agente;
GRANT SELECT ON inmobiliaria.cliente TO rol_agente;

GRANT SELECT ON inmobiliaria.pago TO rol_contador;
GRANT SELECT ON inmobiliaria.contrato TO rol_contador;
GRANT SELECT ON inmobiliaria.reporte_pagos_pendientes TO rol_contador;

GRANT rol_admin TO 'admin_inmo'@'%';
GRANT rol_agente TO 'agente_inmo'@'%';
GRANT rol_contador TO 'contador_inmo'@'%';

SET DEFAULT ROLE ALL TO
    'admin_inmo'@'%',
    'agente_inmo'@'%',
    'contador_inmo'@'%';

-- OPTIMIZACIÓN (ÍNDICES)

CREATE INDEX idx_propiedad_estado
ON propiedad(estado_propiedad_id);
CREATE INDEX idx_contrato_cliente 
ON contrato(cliente_id);
CREATE INDEX idx_contrato_propiedad 
ON contrato(propiedad_id);
CREATE INDEX idx_pago_contrato 
ON pago(contrato_id);
CREATE INDEX idx_pago_estado 
ON pago(estado_pago_id);

-- EVENTO PROGRAMADO

DROP EVENT IF EXISTS evt_reporte_pagos_pendientes;

SET GLOBAL event_scheduler = ON;

DELIMITER $$

CREATE EVENT evt_reporte_pagos_pendientes
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO reporte_pagos_pendientes
    (contrato_id, cliente_id, propiedad_id, deuda, fecha_generacion)
    SELECT
        c.contrato_id,
        c.cliente_id,
        c.propiedad_id,
        deuda_contrato(c.contrato_id),
        NOW()
    FROM contrato c
    JOIN tipo_contrato tc ON c.tipo_contrato_id = tc.tipo_contrato_id
    JOIN estado_contrato ec ON c.estado_contrato_id = ec.estado_contrato_id
    WHERE tc.nombre = 'Arriendo'
      AND ec.nombre = 'Activo'
      AND deuda_contrato(c.contrato_id) > 0;
END$$

DELIMITER ;

-- DATOS DE PRUEBA

INSERT INTO tipo_propiedad VALUES (NULL,'Casa'),(NULL,'Apartamento'),(NULL,'Local');
INSERT INTO estado_propiedad VALUES (NULL,'Disponible'),(NULL,'Arrendada'),(NULL,'Vendida');
INSERT INTO tipo_contrato VALUES (NULL,'Venta'),(NULL,'Arriendo');
INSERT INTO estado_contrato VALUES (NULL,'Activo'),(NULL,'Finalizado');
INSERT INTO estado_pago VALUES (NULL,'Pendiente'),(NULL,'Aprobado');
INSERT INTO metodo_pago VALUES (NULL,'Transferencia'),(NULL,'Efectivo');

INSERT INTO agente VALUES (NULL,'Carlos Pérez','LIC-001','3001112222','carlos@inmo.com');
INSERT INTO cliente VALUES (NULL,'Ana Gómez','CC123','3015556666','ana@gmail.com','Calle 10');

INSERT INTO propiedad
VALUES (NULL,'PROP-001','Av Central 123','Bogotá',120,3,2,350000000,CURDATE(),1,1,1);

INSERT INTO contrato
VALUES (NULL,'CONT-001','2025-01-01','2025-12-31',CURDATE(),350000000,1,1,1,1,1);

INSERT INTO pago
VALUES (NULL,1,CURDATE(),50000000,2,1,'REF001');