CREATE TABLE sales
(customer_ID nvarchar(55),
order_date date,
product_ID int
)

SELECT *
FROM W1DannysDiner..sales

INSERT INTO sales VALUES
('A', '2021-01-01', '1'),
('A', '2021-01-01', '2'),
('A', '2021-01-07', '2'),
('A', '2021-01-10', '3'),
('A', '2021-01-11', '3'),
('A', '2021-01-11', '3'),
('B', '2021-01-01', '2'),
('B', '2021-01-02', '2'),
('B', '2021-01-04', '1'),
('B', '2021-01-11', '1'),
('B', '2021-01-16', '3'),
('B', '2021-02-01', '3'),
('C', '2021-01-01', '3'),
('C', '2021-01-01', '3'),
('C', '2021-01-07', '3');

CREATE TABLE menu
(product_id int,
product_name nvarchar(255),
price int)

SELECT *
FROM W1DannysDiner..menu

INSERT INTO menu VALUES
('1', 'sushi', '10'),
('2', 'curry', '15'),
('3', 'ramen', '12');
  
CREATE TABLE members
(customer_ID nvarchar(55),
join_date date)

SELECT *
FROM W1DannysDiner..members

INSERT INTO members VALUES
('A', '2021-01-07'),
('B', '2021-01-09');



--Questions:
--What is the total amount each customer spent at the restaurant?

WITH TotalSpent AS(
SELECT customer_ID, SUM(price) OVER (PARTITION BY customer_ID) as total_spent
FROM W1DannysDiner..sales s
JOIN W1DannysDiner..menu m ON s.product_id = m.product_id
)

SELECT DISTINCT customer_ID, total_spent
FROM TotalSpent


--How many days has each customer visited the restaurant?

SELECT customer_ID, COUNT(DISTINCT order_date) AS total_visits
FROM W1DannysDiner..sales
GROUP BY customer_ID

--What was the first item from the menu purchased by each customer?
DROP TABLE IF EXISTS total

SELECT s.customer_ID, s.order_date, m.product_ID, m.product_name, m.price INTO W1DannysDiner.[dbo].total
FROM W1DannysDiner..sales s
INNER JOIN W1DannysDiner..menu m ON s.product_ID = m.product_id

WITH ordered_sales AS (
SELECT customer_ID, order_date, product_name, DENSE_RANK() OVER (
PARTITION BY customer_ID
ORDER by order_date) as ranked
FROM W1DannysDiner..total)

SELECT customer_ID, order_date, product_name
FROM ordered_sales
WHERE ranked = 1

--What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, COUNT(product_ID) AS total_orders
FROM W1DannysDiner..total
GROUP BY product_name
ORDER by total_orders DESC

--Which item was the most popular for each customer?

WITH fav_order as (
SELECT customer_ID, product_name, COUNT(product_ID) as times_ordered, DENSE_RANK() OVER (
PARTITION BY customer_ID ORDER BY COUNT(product_ID) DESC) as ranked
FROM W1DannysDiner..total
GROUP by customer_ID, product_name
)

SELECT customer_ID, product_name, times_ordered
FROM fav_order
WHERE ranked = 1

--Which item was purchased first by the customer after they became a member?

WITH after_member AS (
SELECT t.customer_ID, t.product_name, t.order_date, ROW_NUMBER () OVER (
PARTITION BY t.customer_ID 
ORDER BY t.order_date) as rownum
FROM W1DannysDiner..total t
JOIN W1DannysDiner..members m ON t.customer_ID = m.customer_ID
WHERE t.order_date > m.join_date)

SELECT customer_ID, product_name
FROM after_member
WHERE rownum = 1

--Which item was purchased just before the customer became a member?

WITH before_member AS (
SELECT t.customer_ID, t.product_name, t.order_date, DENSE_RANK () OVER (
PARTITION BY t.customer_ID 
ORDER BY t.order_date) as ranked
FROM W1DannysDiner..total t
JOIN W1DannysDiner..members m ON t.customer_ID = m.customer_ID
WHERE t.order_date < m.join_date)

SELECT customer_ID, product_name
FROM before_member
WHERE ranked = 1

--What is the total items and amount spent for each member before they became a member?
SELECT t.customer_ID, COUNT(product_id) as total_items, SUM(price) as total_spent
FROM W1DannysDiner..total t
JOIN W1DannysDiner..members m ON t.customer_ID = m.customer_ID
WHERE t.order_date < m.join_date 
GROUP BY t.customer_ID;

--If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_CTE AS (
SELECT t.customer_ID, CASE
	WHEN product_name = 'sushi' THEN price*20
	ELSE price*10
	END AS points
FROM W1DannysDiner..total t
)

SELECT customer_ID, SUM(points) as total_points
FROM points_CTE
GROUP BY customer_ID;

--In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH week_points AS (
SELECT t.customer_ID, m.join_date, t.order_date, t.product_name, t.price, CASE
	WHEN t.order_date >= m.join_date AND t.order_date <= DATEADD(day, 6, m.join_date) THEN price*20
	WHEN product_name = 'sushi' THEN price*20
	ELSE price*10
	END AS points
FROM W1DannysDiner..total t
JOIN W1DannysDiner..members m ON t.customer_ID = m.customer_ID
)

SELECT customer_ID, SUM(points) as total_points
FROM week_points
GROUP BY customer_ID
