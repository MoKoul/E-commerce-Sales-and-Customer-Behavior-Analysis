
/*   
Customer Retention Analysis: percentage of customer who returned for the second purchase with no other constraint.    
*/

-- Overall Repeat Purchases
with invoice_counts as (
    select 
        CustomerID,
        COUNT(distinct Invoiceno) as invoice_count,
        sum(Quantity*Price) as spending
    from ecommerce_data
    where CustomerID is not null and Quantity > 0
    group by CustomerID
)
select 
    count(*) as total_customers,
    sum(case when invoice_count >= 2 then 1 else 0 end) as repeat_customers,
    sum(case when invoice_count >=2 then spending else 0 end) as repeat_spending,
    round(sum(case when invoice_count >=2 then spending else 0 end) * 100.0 / sum(spending) , 2) as pct_repeat_spending, 
    sum(CASE WHEN invoice_count = 1 then 1 else 0 end) as single_purchase_customers,
    sum(case when invoice_count = 1 then spending else 0 end) as single_spending,
    round(sum(case when invoice_count = 1 then spending else 0 end) * 100.0 / sum(spending), 2) as pct_single_spending,
    round(sum(case when invoice_count >= 2 then 1 else 0 end) * 100.0 / count(*), 2) as pct_repeat,
    round(sum(case when invoice_count = 1 then 1 else 0 end) * 100.0 / count(*), 2) as pct_single
from invoice_counts;

/*   
Customer Retention Analysis: percentage of customer who returned for the second purchase during 90 days after the first one.    
*/

-- 90-Day Retention Rate
with first_purchases as (
    select 
        CustomerID,
        min(InvoiceDate) as first_buy,
        sum(Quantity * Price) as spending
    from ecommerce_data
    where CustomerID is not null and Quantity > 0
    group by CustomerID
),
repurchases as (
    select  
        fp.CustomerID,
        fp.spending  as repeat90_spending
    from first_purchases fp
    join ecommerce_data e on e.CustomerID = fp.CustomerID
        and e.InvoiceDate > fp.first_buy
        and e.InvoiceDate <= fp.first_buy + interval '90 days'
        and e.Quantity > 0
    group by fp.CustomerID, fp.spending
)
select 
    count(distinct fp.CustomerID) as total_first_buyers,
    sum(fp.spending) as total_spending,
    count(distinct rp.CustomerID) as repeat_buyers_90days,
    sum(rp.repeat90_spending) as total_repeat90_spending,
    round(sum(rp.repeat90_spending) * 100.0 / sum(fp.spending), 2) as pct_repeat_revenue, 
    round(count(distinct rp.CustomerID) * 100.0 / count(distinct fp.CustomerID), 2) as pct_repeat_90days,
    (count(distinct fp.CustomerID) - count(distinct rp.CustomerID)) as non_repeat_90days,
    round((count(distinct fp.CustomerID) - count(distinct rp.CustomerID)) * 100.0 / count(distinct fp.CustomerID), 2) as pct_non_repeat_90days
from first_purchases fp
left join repurchases rp on rp.CustomerID = fp.CustomerID;

---------------------------------------------
-- Average Order Value (AOV) of the first purchase
with purchase_1 as (
	select
		CustomerID,
		min(Invoicedate) as order_date
	from ecommerce_data
	where CustomerID is not null and Quantity > 0
	group by CustomerID
),
value as (
	select
		e.CustomerID,
		e.Invoiceno,
		sum(e.Quantity * e.Price) as order_value
	from ecommerce_data e
	join purchase_1 p on p.CustomerID = e.CustomerID
	where e.InvoiceDate= p.order_date
	group by e.CustomerID, e.Invoiceno
)
	select
		round(avg(order_value), 2) as avg_order_value
	from value



-- Average Order Value (AOV) of the Sscond purchase for 90 days repeat buyers
with first_purchases as (
    select 
        CustomerID,
        min(InvoiceDate) as  first_buy_date
    from ecommerce_data
    where  CustomerID is not null and Quantity > 0
    group by  CustomerID
),
second_purchases as (
    select
        e.CustomerID,
        min(e.InvoiceDate) as second_buy_date
    from ecommerce_data e
    join first_purchases fp on e.CustomerID = fp.CustomerID
    where e.InvoiceDate > fp.first_buy_date and e.Quantity > 0
    group by e.CustomerID
),
customers_returning_90 as (
    select 
        sp.CustomerID,
        sp.second_buy_date
    from second_purchases sp
    join first_purchases fp on sp.CustomerID = fp.CustomerID
    where sp.second_buy_date <= fp.first_buy_date + INTERVAL '90 days'
),
second_purchase_details as (
    select 
        c.CustomerID,
        e.Invoiceno,
        sum(e.Quantity * e.Price) as second_order_value
    from customers_returning_90 c
    join ecommerce_data e on c.CustomerID = e.CustomerID and c.second_buy_date = e.InvoiceDate
    group by c.CustomerID, e.Invoiceno
)
	select 
		round(avg(second_order_value), 2) as AOV
	from second_purchase_details;


