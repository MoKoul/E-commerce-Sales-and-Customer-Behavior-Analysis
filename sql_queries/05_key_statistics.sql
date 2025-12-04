
/*
Key Statistics and Product Analysis:
This section calculates essential business metrics, including:
- Identification of top customers and associated revenue streams.
- Ranking of top 10 products by both units sold and total sales.
- Analysis of product affinity and co-purchase behavior among the top products.
*/

-- Total revenue, Total Customers, Average Order Value
select
	sum(Quantity * Price) as total_revenue,
	count(distinct CustomerID) as toatl_customers,
	count(distinct Invoiceno) as total_orders,
	round(sum(Quantity * Price)*1.0 / count(distinct Invoiceno), 2) as average_order_value
from ecommerce_data
where CustomerID is not null and Quantity > 0;

-- Top 10 Customers by Total Purchase together with frequencies.
select  
    CustomerID,
	count(distinct Invoiceno) count_invoice,
    sum(Quantity * Price) as total_purchase
from ecommerce_data
where CustomerID is not null and Quantity > 0
group by CustomerID
order by total_purchase desc
limit 10;

--Total sales by top 10 Customers and its percentage out of total sales in two years
with revenue as(
	select
		sum(Quantity * Price) as total_revenue
	from ecommerce_data 
	where CustomerID is not null and Quantity>0
),
top_10 as (
select 
	CustomerID,
	sum(Quantity * Price) as total_purchase
from ecommerce_data
where CustomerID is not null and Quantity>0
group by CustomerID
order by total_purchase desc
limit 10
)
select
	sum(total_purchase) as top10_total_revenue,
	(select total_revenue from revenue) as total_2years_revenue,
	round(sum(total_purchase) * 100.0 / (select total_revenue from revenue) , 2) as pct_revenue
from top_10

-- Top 10 Products by unit sold
select  
    Description,
    sum(Quantity) as total_sales_quantity,
    sum(Quantity*Price) total_sales
from ecommerce_data
where Quantity > 0 and Description is not null and TRIM(Description) != ''
group by Description
order by total_sales_quantity desc
limit 10;
-- Top 10 product by sales
select
	Description,
	sum(Quantity * Price) as total_sales
from ecommerce_data
where Quantity>0 and Description is not null and trim(Description) != ''
			and Description != 'Manual' and Description != 	'DOTCOM POSTAGE' and Description != 'POSTAGE'
group by Description
order by total_sales desc
limit 10;

-- Top 10 Products by Returns (absolute value)
select 
    Description,
    sum(Quantity) * (-1) as total_returns
from ecommerce_data
where Quantity < 0 and Description is not null and trim(Description) != '' and trim(Description) != '?'
group by Description
order by total_returns desc
limit 10;


-- Product Affinity: pairs most bought together. 
select 
    e1.Description as product_1,
    e2.Description as product_2,
    count(distinct e1.Invoiceno) as co_purchase_count
from ecommerce_data e1
join ecommerce_data e2 on e1.Invoiceno = e2.Invoiceno 
    and e1.StockCode < e2.StockCode  
    and e1.Quantity > 0 and e2.Quantity > 0
    and e1.Description is not null and e2.Description is not null
    and trim(e1.Description) != '' and trim(e2.Description) != ''
group by e1.Description, e2.Description
order by co_purchase_count desc
limit 10;
