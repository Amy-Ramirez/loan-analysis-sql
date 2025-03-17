# EJERCICIO 1
	# Modelo Físico
    
-- Creamos un esquema de base de datos con el nombre prestamos_2015
CREATE SCHEMA prestamos_2015;

-- Creamos las tres tablas correspondientes a los 3 archivos:
CREATE TABLE prestamos_2015.merchants(
merchant_id varchar(50),
name varchar(50)
);

CREATE TABLE prestamos_2015.orders(
order_id varchar(50),
created_at DATE,
status varchar(50),
amount FLOAT,
merchant_id varchar(50),
country varchar(50)
);

CREATE TABLE prestamos_2015.refunds(
order_id varchar(50),
refunded_at DATE,
amount FLOAT
);



# EJERCICIO 2

# 1.- Realizamos una consulta para obtener por país y estado de la operación el total de operaciones y su importe promedio

-- Seleccionamos las columnas que queremos obtener en la consulta: país y estado de la operación, total de operaciones y su importe promedio
SELECT o.country, 
	o.status, 
    COUNT(*) AS total_operaciones, -- Obtenemos el conteo de las operaciones
    ROUND(AVG(o.amount),2) AS importe_promedio  -- Redondeamos el importe promedio a dos decimales
FROM 
	orders AS o  -- Obtenemos los datos de la tabla orders
WHERE o.created_at > '2015-07-01 23:59:59'  -- Operaciones posteriores al 01-07-2015
  AND o.country IN ('Francia', 'Portugal', 'España') -- Operaciones realizadas en Francia, Portugal y España
  AND o.amount BETWEEN 100 AND 1500 -- Operaciones con un valor mayor de 100 € y menor de 1500€
GROUP BY o.country, o.status  -- Agrupamos los resultados por país y estado de la operación
ORDER BY importe_promedio DESC;  -- Ordenamos los resultados por el promedio del importe de manera descendente


# 2.- Realizamos una consulta para obtener los 3 países con el mayor número de operaciones, el total de operaciones, la operación con un valor máximo y la operación con el valor mínimo para cada país

-- Seleccionamos las columnas que queremos obtener en la consulta: país, total de operaciones por país e importe máximo y mínimo por país
SELECT o.country, 
    COUNT(*) AS total_operaciones, -- Obtenemos el conteo de operaciones
    MAX(o.amount) AS importe_maximo, 
    MIN(o.amount) AS importe_minimo
FROM 	
	orders AS o  -- Obtenemos los datos de la tabla orders
WHERE o.status NOT IN ('Delinquent', 'Cancelled')  -- Excluimos las operaciones con el estado “Delinquent” y “Cancelled”
    AND o.amount > 100  -- Operaciones con un valor mayor de 100 €
GROUP BY o.country   -- Agrupamos los resultados por país
ORDER BY total_operaciones DESC  -- Ordenamos de forma descendente para que los países con el mayor número de operaciones aparezcan primero en la lista
LIMIT 3; -- Solo queremos los 3 países con el mayor número de operaciones 



# EJERCICIO 3

# 1.- Realizamos una consulta para obtener por país y comercio, el total de operaciones, su valor promedio y el total de devoluciones

-- Seleccionamos las columnas que queremos obtener en la consulta: país, ID del comercio y su nombre, total de operaciones, su valor promedio y el total de devoluciones
SELECT o.country, 
    m.merchant_id, 
    m.name AS nombre_comercio, 
    COUNT(o.merchant_id) AS total_operaciones,  -- Obtenemos el conteo de operaciones
    ROUND(AVG(o.amount),2) AS valor_promedio,   -- Redondeamos el valor promedio a dos decimales
    COALESCE(SUM(r.conteo_devoluciones),0) AS conteo_devoluciones,  -- Obtenemos el conteo de las devoluciones
CASE WHEN SUM(r.suma_devoluciones) > 0 THEN 'Sí' ELSE 'No' END AS acepta_devoluciones  -- Para identificar si el comercio acepta o no devoluciones
FROM orders AS o  -- Obtenemos los datos de la tabla orders	
LEFT JOIN merchants AS m ON o.merchant_id = m.merchant_id  -- Unimos las tablas orders y merchants por el campo 'merchant_id'.
LEFT JOIN (
SELECT order_id,
	ROUND(SUM(amount),2) AS suma_devoluciones,
	COUNT(*) AS conteo_devoluciones
FROM refunds
GROUP BY order_id
) AS r ON o.order_id = r.order_id -- Realizamos una subquery para unir las tablas orders y refunds por el campo order_id
WHERE o.country IN ('Marruecos', 'Italia', 'España', 'Portugal')  -- Comercios de Marruecos, Italia, España y Portugal
GROUP BY o.country, m.merchant_id, m.name  -- Agrupamos los resultados por país, ID del comercio y su nombre
HAVING total_operaciones > 10  -- Comercios con más de 10 ventas
ORDER BY total_operaciones ASC;  -- Ordenamos los resultados por el total de operaciones de manera ascendente
    
    
# 2.- Realizamos una consulta para el conteo de devoluciones

-- Seleccionamos todos los campos de las tablas orders y merchants
SELECT o.*, 
    m.merchant_id AS merch_id, -- Cambiamos el nombre puesto que en orders también existe una columna llamada 'mechant_id' y habría error de duplicados
    m.name AS nombre_comercio,
    COALESCE(r.conteo_devoluciones,0) AS conteo_devoluciones, -- Obtenemos el conteo de devoluciones por operación
    COALESCE(r.suma_devoluciones,0) AS suma_devoluciones -- Obtenemos la suma del valor de las devoluciones
FROM orders AS o  --  Obtenemos los datos de la tabla orders
LEFT JOIN merchants AS m ON o.merchant_id = m.merchant_id  -- Unimos las tablas orders y merchants por el campo merchant_id
LEFT JOIN (
SELECT order_id,
	ROUND(SUM(amount),2) AS suma_devoluciones,
	COUNT(*) AS conteo_devoluciones
FROM refunds
GROUP BY order_id
) AS r ON o.order_id = r.order_id;  -- Realizamos una subquery para unir las tablas orders y refunds por el campo order_id

-- Creamos la vista      
CREATE VIEW orders_view AS 
SELECT o.*, 
    m.merchant_id AS merch_id,
    m.name AS nombre_comercio,
    COALESCE(r.conteo_devoluciones,0) AS conteo_devoluciones, 
    COALESCE(r.suma_devoluciones,0) AS suma_devoluciones 
FROM orders AS o  
LEFT JOIN merchants AS m ON o.merchant_id = m.merchant_id 
LEFT JOIN (
SELECT order_id,
	ROUND(SUM(amount),2) AS suma_devoluciones,
	COUNT(*) AS conteo_devoluciones
FROM refunds
GROUP BY order_id
) AS r ON o.order_id = r.order_id;
     
 SELECT * FROM prestamos_2015.orders_view;
 
 
 
 # EJERCICIO 4: Detección de fraude en transacciones

-- Objetivo de análisis: Detectar posibles casos de fraude en las operaciones financieras mediante la identificación de patrones
	
# 1.- Análisis de transacciones con importes significativamente altos o bajos en comparación con el promedio del país

SELECT o.country, 
	o.order_id, 
    o.amount, 
    o_avg.promedio_pais AS promedio_pais,
    CASE
        WHEN o.amount > o_avg.promedio_pais * 2 THEN 'Importe alto'	-- Se considera 'Importe alto' si es más de dos veces el promedio
        WHEN o.amount < o_avg.promedio_pais / 2 THEN 'Importe bajo'	-- Se considera 'Importe bajo' si es menos de la mitad
        ELSE 'Normal'  -- En el resto de casos se considera 'Normal'
    END AS tipo_transaccion
FROM orders AS o
LEFT JOIN (
    SELECT country, 
		ROUND(AVG(amount),2) AS promedio_pais
		FROM orders
		GROUP BY country
) AS o_avg ON o.country = o_avg.country  -- Unimos la tabla orders con la subquery de promedio por país
GROUP BY o.country, o.order_id, o.amount, o_avg.promedio_pais 
HAVING tipo_transaccion != 'Normal';  -- Excluimos las transacciones consideradas 'Normal'


# 2.- Análisis de transacciones con importes significativamente altos o bajos en comparación con el promedio del comercio 

-- Hacemos el mismo código pero sustituyendo la variable 'country' por 'merchant_id'
SELECT m.name AS nombre_comercio, 
	o.country,
    o.order_id, 
    o.amount, 
    o_avg.promedio_comercio AS promedio_comercio,
    CASE
        WHEN o.amount > o_avg.promedio_comercio * 2 THEN 'Importe alto'
        WHEN o.amount < o_avg.promedio_comercio / 2 THEN 'Importe bajo'	
        ELSE 'Normal'
    END AS tipo_transaccion
FROM orders AS o
LEFT JOIN merchants AS m ON o.merchant_id = m.merchant_id
LEFT JOIN (
    SELECT merchant_id, 
		ROUND(AVG(amount),2) AS promedio_comercio
		FROM orders
		GROUP BY merchant_id
) AS o_avg ON o.merchant_id = o_avg.merchant_id
GROUP BY m.name, o.country, o.order_id, o.amount, o_avg.promedio_comercio
HAVING tipo_transaccion != 'Normal';