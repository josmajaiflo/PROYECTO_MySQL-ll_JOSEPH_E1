  Autor

Joseph Manuel Jaimes
Sistema de Gestión Inmobiliaria – Proyecto MySQL II

 
 Sistema de Gestión Inmobiliaria

 Descripción del proyecto

- Propiedades (casas, apartamentos, locales comerciales)
- Clientes interesados en comprar o arrendar
- Contratos firmados
- Historial de pagos
- Auditoría de cambios y reportes automáticos


 Instalación y ejecución

1. Yo utilicé MySQL 8.x o superior instalado.
2. Puedes usar MySQL Workbench o tu cliente SQL preferido.
3. Ejecuta el script `inmobiliaria.sql` por bloques, en este orden:

   1. Creación de base de datos y uso (`CREATE DATABASE` / `USE`).
   2. Tablas de apoyo (catálogos).
   3. Tablas principales (`propiedad`, `cliente`, `contrato`, `pago`).
   4. Tablas de auditoría y reportes.
   5. Funciones personalizadas.
   6. Triggers.
   7. Roles y usuarios.
   8. Índices de optimización.
   9. Evento programado.
   10. Datos de prueba.

 Modelo de Datos

#ntidades principales

- agente: nombre, licencia, teléfono, email
- cliente: nombre, documento, teléfono, email, dirección
- propiedad: código, dirección, ciudad, área_m2, habitaciones, baños, precio, fecha_registro, tipo, estado, agente
- contrato: número, fechas (inicio, fin, firma), valor_total, tipo, estado, propiedad, cliente, agente
- pago: contrato, fecha_pago, monto, estado, método, referencia

#ntidades de apoyo (catálogos)

- tipo_propiedad (Casa, Apartamento, Local)
- estado_propiedad (Disponible, Arrendada, Vendida)
- tipo_contrato (Venta, Arriendo)
- estado_contrato (Activo, Finalizado)
- estado_pago (Pendiente, Aprobado)
- metodo_pago (Transferencia, Efectivo)


 Funciones personalizadas

- `calcular_comision(id)`: Calcula comisión del 3% para contratos de Venta
- `deuda_contrato(id)`: Retorna monto pendiente de pago de un contrato
- `total_propiedades_disponibles(tipo_id)`: Devuelve el total de propiedades Disponibles por tipo


 Triggers

- `trg_propiedad_cambio_estado`: Registra auditoría de cambios de estado
- `trg_nuevo_contrato`: Registra auditoría al crear un contrato
- `trg_actualizar_estado_propiedad`: Cambia el estado de propiedad según tipo de contrato


 Roles y permisos

- rol_admin: Todos los privilegios sobre la base de datos
- rol_agente: SELECT/INSERT/UPDATE en propiedad y contrato, SELECT en cliente
- rol_contador: SELECT en pagos, contratos y reportes de pagos pendientes

Usuarios de ejemplo:
- `admin_inmo` → rol_admin
- `agente_inmo` → rol_agente
- `contador_inmo` → rol_contador


 Consultas de ejemplo

- Ver deuda de un contrato: `SELECT deuda_contrato(1) AS deuda;`
- Ver comisión de un contrato de venta: `SELECT calcular_comision(1) AS comision;`
- Total de propiedades disponibles por tipo: `SELECT total_propiedades_disponibles(1) AS total_casas;`
- Ver auditoría de propiedades: `SELECT * FROM auditoria_propiedad ORDER BY fecha_evento DESC;`
- Reporte de pagos pendientes: `SELECT * FROM reporte_pagos_pendientes ORDER BY fecha_generacion DESC;`