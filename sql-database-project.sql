# EXERCISE 1 
	# Physical Model
    
-- We create a database schema with the name prestamos_2015
CREATE SCHEMA prestamos_2015;

-- We create the three tables corresponding to the 3 files:
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



# EXERCISE 2

# 1.- We carry out a query to obtain by country and status of the operation the total number of operations and their average amount

-- Select the columns we want to obtain in the query: country and status of the operation, total operations and their average amount
SELECT o.country, 
	o.status, 
    COUNT(*) AS total_operaciones, -- We get the count of the operations
    ROUND(AVG(o.amount),2) AS importe_promedio  -- We round the average amount to two decimal places
FROM 
	orders AS o  -- We get the data from the orders table
WHERE o.created_at > '2015-07-01 23:59:59'  -- Operations after 01-07-2015
  AND o.country IN ('Francia', 'Portugal', 'España') -- Operations carried out in France, Portugal and Spain
  AND o.amount BETWEEN 100 AND 1500 -- Transactions with a value greater than €100 and less than €1500
GROUP BY o.country, o.status  -- We group the results by country and operation status
ORDER BY importe_promedio DESC;  -- We sort the results by the average amount in descending order


# 2.- We conduct a query to obtain the 3 countries with the highest number of trades, the total trades, the trade with a maximum value, and the trade with the minimum value for each country

-- Select the columns we want to obtain in the query: country, total operations by country and maximum and minimum amount by country
SELECT o.country, 
    COUNT(*) AS total_operaciones, -- We get the trade count
    MAX(o.amount) AS importe_maximo, 
    MIN(o.amount) AS importe_minimo
FROM 	
	orders AS o  -- We get the data from the orders table
WHERE o.status NOT IN ('Delinquent', 'Cancelled')  -- We exclude operations with the status "Delinquent" and "Cancelled"
    AND o.amount > 100  -- Transactions with a value greater than €100
GROUP BY o.country   -- We group the results by country
ORDER BY total_operaciones DESC  -- We sort in descending order so that the countries with the highest number of transactions appear first in the list
LIMIT 3; -- We only want the 3 countries with the highest number of trades



# EXERCISE 3

# 1.- We made a query to obtain by country and trade, the total of operations, their average value and the total of returns

-- We select the columns we want to obtain in the query: country, merchant ID and its name, total transactions, its average value and total returns
SELECT o.country, 
    m.merchant_id, 
    m.name AS nombre_comercio, 
    COUNT(o.merchant_id) AS total_operaciones,  -- We get the trade count
    ROUND(AVG(o.amount),2) AS valor_promedio,   -- We rounded the average value to two decimal places
    COALESCE(SUM(r.conteo_devoluciones),0) AS conteo_devoluciones,  -- We get the return count
CASE WHEN SUM(r.suma_devoluciones) > 0 THEN 'Sí' ELSE 'No' END AS acepta_devoluciones  -- To identify whether or not the merchant accepts returns
FROM orders AS o  -- We get the data from the orders table
LEFT JOIN merchants AS m ON o.merchant_id = m.merchant_id  -- Join the orders and merchants tables with the 'merchant_id' field
LEFT JOIN (
SELECT order_id,
	ROUND(SUM(amount),2) AS suma_devoluciones,
	COUNT(*) AS conteo_devoluciones
FROM refunds
GROUP BY order_id
) AS r ON o.order_id = r.order_id -- We perform a subquery to join the orders and refunds tables by the order_id field
WHERE o.country IN ('Marruecos', 'Italia', 'España', 'Portugal')  -- Shops in Morocco, Italy, Spain and Portugal
GROUP BY o.country, m.merchant_id, m.name  -- We group the results by country, merchant ID and its name
HAVING total_operaciones > 10  -- Businesses with more than 10 sales
ORDER BY total_operaciones ASC;  -- We sort the results by the total number of operations in ascending order
    
    
# 2.- We carry out a consultation for the count of returns

-- Select all fields from the orders and merchants tables
SELECT o.*, 
    m.merchant_id AS merch_id, -- We changed the name since in orders there is also a column called 'mechant_id' and there would be a duplicate error
    m.name AS nombre_comercio,
    COALESCE(r.conteo_devoluciones,0) AS conteo_devoluciones, -- We get the count of returns per operation
    COALESCE(r.suma_devoluciones,0) AS suma_devoluciones -- We get the sum of the value of the returns
FROM orders AS o  --  We get the data from the orders table
LEFT JOIN merchants AS m ON o.merchant_id = m.merchant_id  -- Join the orders and merchants tables by the merchant_id field
LEFT JOIN (
SELECT order_id,
	ROUND(SUM(amount),2) AS suma_devoluciones,
	COUNT(*) AS conteo_devoluciones
FROM refunds
GROUP BY order_id
) AS r ON o.order_id = r.order_id;  -- We perform a subquery to join the orders and refunds tables by the order_id field

-- We create the view      
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
 
 
 
 # EXERCISE 4

-- Objective of analysis: Detect possible cases of fraud in financial transactions by identifying patterns
	
# 1.- Analysis of transactions with significantly high or low amounts compared to the country average

SELECT o.country, 
	o.order_id, 
    o.amount, 
    o_avg.promedio_pais AS promedio_pais,
    CASE
        WHEN o.amount > o_avg.promedio_pais * 2 THEN 'Importe alto'	-- It is considered 'High Amount' if it is more than twice the average
        WHEN o.amount < o_avg.promedio_pais / 2 THEN 'Importe bajo'	-- It is considered 'Low Amount' if it is less than half
        ELSE 'Normal'  -- In all other cases, it is considered 'Normal'
    END AS tipo_transaccion
FROM orders AS o
LEFT JOIN (
    SELECT country, 
		ROUND(AVG(amount),2) AS promedio_pais
		FROM orders
		GROUP BY country
) AS o_avg ON o.country = o_avg.country  -- We join the orders table with the average subquery by country
GROUP BY o.country, o.order_id, o.amount, o_avg.promedio_pais 
HAVING tipo_transaccion != 'Normal';  -- We exclude transactions considered 'Normal'


# 2.- Analysis of transactions with significantly high or low amounts compared to the average merchant

-- We make the same code but replacing the variable 'country' with 'merchant_id'
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
