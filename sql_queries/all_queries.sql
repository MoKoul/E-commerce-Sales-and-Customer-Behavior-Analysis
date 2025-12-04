
/*
Dataset description:
The dataset used in this analysis is the Online Retail II dataset from the UCI Machine Learning Repository. 
It contains transactional data collected from a UK-based, online retail company over 
two years (December 1, 2009 to December 9, 2011). 

This analysis applies RFM (Recency, Frequency, Monetary) analysis for customer segmentation. 
RFM is a marketing technique that segments customers based on how recently they purchased (Recency), 
how often they purchase (Frequency), and how much they spend (Monetary value).
Using these metrics, customers will be grouped to identify valuable and loyal segments for targeted marketing strategies.
Next, we examine customer retention and we perform cohort analysis to examine customer retention rates and behaviors over time.
Afterward we find key statistics like top 10 customers, top 10 pruducts, by both quantity and sales. 
Finally, seasonal trend analysis will be conducted to identify patterns and 
fluctuations in sales over time, such as monthly and quarterly seasonality.
*/

----------------------------------------------------------01_data_setup.sql-------------------------------------------------------------------------

/* creating table and importing data. */

create table ecommerce_data(
	InvoiceNo varchar(20),
	StockCode varchar(20),
	Description text,
	Quantity int,
	InvoiceDate timestamp,
	Price  decimal(10, 2),
	CustomerID float,
	Country varchar(50)
);



/* 
List of all columns and their data type from the table.    
It shows that CustomerID is float.     
*/

select column_name, data_type
from  information_schema.columns
where table_schema='public' and table_name = 'ecommerce_data';


/*
Checking if CustomerID has decimal part.
It does not have non zero decimal.
*/  
select  
    count(*) as non_integer_id, 
    sum(case when (CustomerID - floor(CustomerID)) != 0 then 1 else 0 end) as num_id_decimal
from ecommerce_data
where CustomerID is not null;

-- Convert CustomerID to INT 
alter table ecommerce_data
alter column CustomerID type int using floor(CustomerID)::int;


/*  
Checking for any NULL CustomerID or negative Quantity values.
If such rows exist, they should be excluded from the analysis.
There are more than 2% negative quantities and 22% null CustomerID.
*/

select 
    count(*) as total_rows,
    sum(case when CustomerID is null then 1 else 0 end) as count_null_customerid,
    round(sum(case when CustomerID is null then 1 else 0 end) * 100.0 / count(*), 2) as pct_null_customerid,
    sum(case when Quantity < 0 then 1 else 0 end) as count_neg_quantity,
    round(sum(case when Quantity < 0 then 1 else 0 end) * 100.0 / count(*), 2) as pct_neg_quantity
from ecommerce_data;


-- Indexing for efficiency
create index idx_invoicedate on ecommerce_data (InvoiceDate);
create index idx_customerid on ecommerce_data (CustomerID);
create index idx_quantity on ecommerce_data (Quantity) where Quantity > 0;

-- View index names and the columns they cover in PostgreSQL
select 
    tablename,
    indexname,
    indexdef
from pg_indexes
where tablename = 'ecommerce_data';

---------------------------------------------------------------02_RFM_analysis.sql--------------------------------------------------------------------------------------------------

/*  
RFM (Recency, Frequency, Monetary) analysis on customers in the ecommerce_data table. 
Segmenting customers based on their purchase history into categories such 
as Champions, Loyal, Potential Loyalist, New Customers , At Risk  
and Dormant, then summarizing the average RFM metrics and customer counts for each segment. 
 */

-- RFM Metrics: calculating recency, frequency and monetary
with rfm_metrics as (
    select 
        CustomerID,
        date_part('day', (select max(InvoiceDate) from ecommerce_data) - max(InvoiceDate)) as recency,
        count(distinct Invoiceno) as frequency,
        sum(Quantity * Price) as monetary
    from ecommerce_data
    where CustomerID is not null and Quantity > 0
    group by CustomerID
),
-- Scoring for recency, frequency and monetary
scoring as (
    select 
        CustomerID,
        recency,
        frequency,
        monetary,
        NTILE(5) over (order by recency desc) as recency_score,  -- Lower recency = higher score
        NTILE(5) over (order by frequency asc) as frequency_score,
        NTILE(5) over (order by monetary asc) as monetary_score
    from rfm_metrics
),
-- Segmentation with RFM, creating different group of customers based on recency, frequency and monetary scores
segment as (
    select 
        CustomerID,
        recency,
        frequency,
        monetary,
        recency_score,
        frequency_score,
        monetary_score,
        round((recency_score + frequency_score + monetary_score) / 3.0, 2) AS rfm_score,
        case 
            when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 5 then 'Champions'
            when recency_score >= 0 and frequency_score >= 4 and monetary_score >= 0 then 'Loyal'
            when recency_score >= 4 and frequency_score >= 2 and monetary_score >=0 then 'Potential Loyalist'
            when recency_score >= 4 and frequency_score = 1 then 'New Customers'
            when recency_score <= 3 and frequency_score >= 3 and monetary_score >= 3 then 'At Risk'
            when recency_score <= 3 and frequency_score <= 3 and monetary_score <= 5 then 'Dormant'
            else 'Others'
        end as customer_segment
    from scoring
)
-- Aggregatting the results
select 
	customer_segment,
    count(*) as customer_count,
    round(count(*) * 100.0 / (select count(distinct CustomerId) from ecommerce_data where CustomerId is not null and Quantity>0), 2) as pct_segment,
    round(sum(monetary) * 100.0 / (select sum(monetary) from rfm_metrics), 2) as pct_revenue,
    round(avg(recency)::numeric, 2) as avg_recency,
    round(avg(frequency)::numeric, 2) as avg_frequency,
    round(avg(monetary)::numeric, 2) as avg_monetary,
    round(avg(rfm_score)::numeric, 2) as avg_rfm_score
from segment
group by customer_segment
order by 
    case customer_segment
        when 'Champions' then 1
        when 'Loyal' then 2
        when 'Potential Loyalist' then 3
        when 'New Customers' then 4
        when 'At Risk' then 5
        when 'Dormant' then 6
        else 7
    end;


------------------------------------------------------------------03_customer_retention.sql-----------------------------------------------------------------------
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


-- Average Order Value (AOV) of the second purchase for 90 days repeat buyers
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


--------------------------------------------------04_cohort_analysis.sql-----------------------------------------------------
/* 
Cohort analysis tracks retention by acquisition month.
*/

with cohorts as (
    select  
        CustomerID,
        to_char(min(InvoiceDate), 'YYYY-MM') as cohort_month
    from ecommerce_data
    where CustomerID is not null and Quantity > 0
    group by CustomerID
),
purchases as (
    select 
        c.CustomerID,
        c.cohort_month,
        to_char(e.InvoiceDate, 'YYYY-MM') as purchase_month
    from cohorts c
    join ecommerce_data e on e.CustomerID = c.CustomerID and e.Quantity > 0
    group by c.CustomerID, c.cohort_month, purchase_month
),
cohort_sizes AS (
    select cohort_month, 
    count(distinct CustomerID) as cohort_size
    from cohorts
    group by cohort_month
),
retention as (
    select 
        cohort_month,
        purchase_month,
        (date_part('year', age(to_date(purchase_month, 'YYYY-MM'), to_date(cohort_month, 'YYYY-MM'))) * 12 +
         date_part('month', age(to_date(purchase_month, 'YYYY-MM'), to_date(cohort_month, 'YYYY-MM')))) as months_since_acquisition,
        count(distinct CustomerID) as retained_customers
    from purchases
    group by cohort_month, purchase_month, months_since_acquisition
)
select 
    r.cohort_month,
    r.months_since_acquisition,
    r.retained_customers,
    cs.cohort_size,
    round(r.retained_customers * 100.0 / cs.cohort_size, 2) as retention_rate_pct
from retention r
join cohort_sizes cs on cs.cohort_month = r.cohort_month
order by r.cohort_month, r.months_since_acquisition;

-- New customers by acquisition month (first purchase month)
with first_purchase as (
    select
        CustomerID,
        min(InvoiceDate) as first_purchase_date
    from ecommerce_data
    where CustomerID is not null and Quantity > 0
    group by CustomerID
)
select
    to_char(first_purchase_date, 'YYYY-MM') AS year_month,
    count(distinct CustomerID) as new_customers
from first_purchase
group by year_month
order by year_month;


-- Monthly new customers average in one year
with first_purchase as ( 
	select 
		CustomerID,
		min(Invoicedate) as first_date
	from ecommerce_data
	where CustomerID is not null and Quantity > 0
	group by CustomerID
),
count_new_customers as (
	select
		to_char(first_date, 'YYYY') as year,
		to_char(first_date, 'YYYY-MM') as year_month,
		count(distinct CustomerID) as new_customers
	from first_purchase
	group by year, year_month
	order by year_month
)
select
	(sum(new_customers) * 1.0 / count(*)) as avg_new_customers_monthly
from count_new_customers
group by year
order by year;

-----------------------------------------------------------05_key_statistics.sql----------------------------------------------------------------------------------------
/*
Key Statistics and Product Analysis:
This section calculates essential business metrics, including:
- Identification of top customers and associated revenue streams.
- Ranking of top 10 products by both units sold and total sales.
- Analysis of product affinity and co-purchase behavior among the top products.
*/
-- Total sales, Total Customers, Average Order Value
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

-- Top 10 Products by units sold
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


-------------------------------------------------------------------06_sales_trends.sql------------------------------------------------------------
/*
The following queries analyze sales trends:
- Identifying monthly and quarterly sales patterns.
- Determining total sales for each day of the week summed from Dec 2009 to Dec 2011.
*/

-- Monthly statistics: Sales, total units sold, average sales per invoice

select  
    to_char(InvoiceDate, 'YYYY-MM') as year_month,
    sum(Price * Quantity) as total_sales,
    sum(Quantity) as total_units,
    count(distinct Invoiceno) as total_invoices,
    round(sum(Price * Quantity)::numeric / count(distinct Invoiceno), 2) as avg_sales_per_invoice
from ecommerce_data
where Quantity > 0
group by year_month
order by year_month asc;

-- Quarterly statistics: Sales, total units, average sale per invoice.

select 
    to_char(InvoiceDate, 'YYYY-"Q"Q') as year_quarter,
    sum(Price * Quantity) as total_sales,
    sum(Quantity) as total_units,
    count(distinct Invoiceno) as total_invoices,
    round(sum(Price * Quantity)::numeric / count(distinct Invoiceno), 2) as avg_sales_per_invoice
from ecommerce_data
where Quantity > 0
group by year_quarter
order by year_quarter asc;


-- Total sales for everyday of the week summed from december 2009 to december 2011.

select 
    extract(DOW from InvoiceDate) as day_of_week,
    to_char(InvoiceDate, 'DAY') as day_name,
    count(distinct Invoiceno) as count_invoices,
    sum(Price * Quantity) as total_sales
from ecommerce_data
where Quantity > 0
group by day_of_week, day_name
order by day_of_week;

---------------------------------------------07_seasonal_analysis.sql-------------------------------------------------------------------------
/*
Seasonal Sales (Christmas, Black Friday)
*/

-- Christmas Period (Dec)
select  
    to_char(InvoiceDate, 'YYYY-MM') AS year_month,
    count(DISTINCT Invoiceno) AS count_invoices,
    sum(Quantity * Price) AS total_sales,
    round(sum(Quantity * Price)::numeric / count(distinct Invoiceno), 2) as avg_sales_per_invoice
from ecommerce_data
where Quantity > 0 and extract(month from InvoiceDate) = 12
group by year_month;

-- Black Friday Period (Nov 23-30)
select 
    to_char(InvoiceDate, 'YYYY-MM') as year_month,
    count(distinct Invoiceno) as count_invoices,
    sum(Quantity * Price) as total_sales,
    round(sum(Quantity * Price)::numeric / count(distinct Invoiceno), 2) as avg_sales_per_invoice
from ecommerce_data
where Quantity > 0 
    and extract(month from InvoiceDate) = 11 
    and extract(day from InvoiceDate) between 23 and 30
group by year_month;

/*
Seasonal Product Popularity and Trend Analysis:
This section identifies seasonal sales patterns by determining the top 5 best-selling products 
by quantity for each month and quarter from December 2009 to December 2011.
*/

-- Top 5 Products per Month
with monthly_sales as (
    select 
        to_char(InvoiceDate, 'YYYY-MM') as year_month,
        Description,
        sum(Price * Quantity) as total_sales,
        sum(Quantity) as total_quantity,
        dense_rank() over (partition by to_char(InvoiceDate, 'YYYY-MM') order by sum(Quantity) desc) as rank
    from ecommerce_data
    where Quantity>0 and Description is not null and trim(Description) != ''
			and Description != 'Manual' and Description != 	'DOTCOM POSTAGE' and Description != 'POSTAGE'
    group by year_month, Description
)
select *
from monthly_sales
where rank <= 5
order by year_month, rank;


-- Top 5 Products per Quarter 
with quarterly_sales as (
    select 
        to_char(InvoiceDate, 'YYYY-"Q"Q') as year_quarter,
        Description,
        sum(Price * Quantity) as total_sales,
        sum(Quantity) AS total_quantity,
        dense_rank() OVER (partition by to_char(InvoiceDate, 'YYYY-"Q"Q') order by sum(Quantity) desc) as rank
    FROM ecommerce_data
    where Quantity>0 and Description is not null and trim(Description) != ''
			and Description != 'Manual' and Description != 	'DOTCOM POSTAGE' and Description != 'POSTAGE'
    group by year_quarter, Description
)
select *
from quarterly_sales
where rank <= 5
order by year_quarter, rank;

---------------------------------------------08_cohort_analysis_champions.sql-------------------------------------------------------------------------

-- Cohort Analysis For Champions

with champions as (
	select distinct CustomerID 
	from (
			select
				CustomerID,
				ntile(5) over ( order by recency desc) as recency_score,
				ntile(5) over (order by frequency asc) as frequency_score,
				ntile(5) over (order by monetary asc) as monetary_score			
			from ( 
			select 
				CustomerID,
				date_part('day',((select max(InvoiceDate) from ecommerce_data)- max(InvoiceDate)) ) as recency,
				count(distinct InvoiceNO) as frequency,
				sum(Quantity * Price) as monetary
			from ecommerce_data 
			where CustomerID is not null and Quantity > 0
			group by CustomerID	
			)
		)
	where recency_score >=4 and frequency_score >= 4 and monetary_score >= 5 
),
cohorts as (
    select  
        e.CustomerID,
        to_char(min(e.InvoiceDate), 'YYYY-MM') as cohort_month
    from ecommerce_data e
    join champions cc on cc.CustomerID = e.CustomerID
    where e.CustomerID is not null and e.Quantity > 0
    group by e.CustomerID
),
purchases as (
    select 
        c.CustomerID,
        c.cohort_month,
        to_char(e.InvoiceDate, 'YYYY-MM') as purchase_month
    from cohorts c
    join ecommerce_data e on e.CustomerID = c.CustomerID and e.Quantity > 0
    group by c.CustomerID, c.cohort_month, purchase_month
),
cohort_sizes AS (
    select cohort_month, 
    count(distinct CustomerID) as cohort_size
    from cohorts
    group by cohort_month
),
retention as (
    select 
        cohort_month,
        purchase_month,
        (date_part('year', age(to_date(purchase_month, 'YYYY-MM'), to_date(cohort_month, 'YYYY-MM'))) * 12 +
         date_part('month', age(to_date(purchase_month, 'YYYY-MM'), to_date(cohort_month, 'YYYY-MM')))) as months_since_acquisition,
        count(distinct CustomerID) as retained_customers
    from purchases
    group by cohort_month, purchase_month, months_since_acquisition
)
select 
    r.cohort_month,
    r.months_since_acquisition,
    r.retained_customers,
    cs.cohort_size,
    round(r.retained_customers * 100.0 / cs.cohort_size, 2) as retention_rate_pct
from retention r
join cohort_sizes cs on cs.cohort_month = r.cohort_month
order by r.cohort_month, r.months_since_acquisition;


---------------------------------------------09_CLV_metrics.sql-------------------------------------------------------------------------

-------------------------------------------All Customers-----------------------------------------------------

-- Calculating average frequency of all customers in 2011
-- Calculating AOV of all customers in 2011

/*
avg_frequency|aov   |
-------------+------+
         4.06|486.62|
*/

select
	round (count(distinct Invoiceno) * 1.0 /count( distinct CustomerID), 2) as avg_frequency,
	round(sum(Quantity * Price) * 1.0 / count(distinct Invoiceno), 2) as aov
from ecommerce_data
where extract(year from InvoiceDate) = 2011 and CustomerID is not null and Quantity > 0 and InvoiceNo is not null

-- Over All Cuatomer Retention Rate 2010 to 2011
/*
 total_customers_2010|returning_customers_in_2011|pct_retention_year|
--------------------+---------------------------+------------------+
                4233|                       2661|             62.86|
 */

with customers_2010 as (
	select distinct CustomerID
	from ecommerce_data
	where extract(year from Invoicedate) = 2010 and CustomerId is not null and Quantity > 0
),
customers_2011 as (
	select distinct CustomerID
	from ecommerce_data
	where extract(year from InvoiceDate) = 2011 and CustomerID is not null and Quantity > 0
)
select 
	(select count(*) from customers_2010) as total_customers_2010,
	count(c10.CustomerID) as returning_customers_in_2011,
	round( count(c11.CustomerID) * 100.0 / (select count(*) from customers_2010) , 2) as pct_retention_year
from customers_2010 c10
inner join customers_2011 c11 on c10.CustomerID = c11.CustomerID


-------------------------------------------------------------------------------------------------------------
---------------------------------------------Champions-------------------------------------------------------

-- Calculating average frequency of Champion customers in 2011
-- Calculating AOV of Champion customers in 2011
/*
 avg_frequency_2011|aov_2011|
------------------+--------+
             13.44|  624.54|
 */ 

with champions as (
	select distinct CustomerID 
	from (
			select
				CustomerID,
				ntile(5) over ( order by recency desc) as recency_score,
				ntile(5) over (order by frequency asc) as frequency_score,
				ntile(5) over (order by monetary asc) as monetary_score			
			from ( 
			select 
				CustomerID,
				date_part('day',((select max(InvoiceDate) 
								 from ecommerce_data 
								 where extract(year from InvoiceDate) = 2011
								   and CustomerID is not null
								   and Quantity > 0
								   )
								   - max(InvoiceDate)) ) as recency,
				count(distinct InvoiceNO) as frequency,
				sum(Quantity * Price) as monetary
			from ecommerce_data 
			where CustomerID is not null and Quantity > 0 and extract(year from InvoiceDate) = 2011
			group by CustomerID	
			)
		)
	where recency_score >=4 and frequency_score >= 4 and monetary_score >= 5 
)
select
	round(count(distinct e.InvoiceNO) * 1.0 / count(distinct e.CustomerID), 2) as avg_frequency_2011,
	round(sum(e.Quantity * e.Price) * 1.0 / count(distinct e.InvoiceNo), 2) as aov_2011
from champions c
join ecommerce_data e on c.CustomerID = e.CustomerID
where e.CustomerID is not null and e.Quantity > 0 and extract(year from e.InvoiceDate) = 2011



--Champion Customers in 2010 and their retention rate in 2011
/*
 total_champions_2010|returning_champions_in_2011|pct_retention_champions|
--------------------+---------------------------+-----------------------+
                 580|                        561|                  96.72|
 */

with champions as (
	select distinct CustomerID 
	from (
			select
				CustomerID,
				ntile(5) over ( order by recency desc) as recency_score,
				ntile(5) over (order by frequency asc) as frequency_score,
				ntile(5) over (order by monetary asc) as monetary_score			
			from ( 
			select 
				CustomerID,
				date_part('day',((select max(InvoiceDate) 
								 from ecommerce_data 
								 where extract(year from InvoiceDate) = 2010 
								   and CustomerID is not null
								   and Quantity > 0
								   )
								   - max(InvoiceDate)) ) as recency,
				count(distinct InvoiceNO) as frequency,
				sum(Quantity * Price) as monetary
			from ecommerce_data 
			where CustomerID is not null and Quantity > 0 and extract(year from InvoiceDate) = 2010
			group by CustomerID	
			)
		)
	where recency_score >=4 and frequency_score >= 4 and monetary_score >= 5 
),
customers_2010 as (
	select distinct c.CustomerID
	from champions c
	join ecommerce_data e on c.CustomerID = e.CustomerID
	where extract(year from e.Invoicedate) = 2010 and c.CustomerId is not null and e.Quantity > 0
),
customers_2011 as (
	select distinct c.CustomerID
	from champions c
	join ecommerce_data e on c.CustomerID = e.CustomerID
	where extract(year from e.InvoiceDate) = 2011 and c.CustomerID is not null and e.Quantity > 0
)
select 
	(select count(*) from customers_2010) as total_champions_2010,
	count(c10.CustomerID) as returning_champions_in_2011,
	round( count(c10.CustomerID) * 100.0 / (select count(*) from customers_2010) , 2)as pct_retention_champions
from customers_2010 c10
inner join customers_2011 c11 on c10.CustomerID = c11.CustomerID



-------------------------------------------------------------------------------------------------------------
---------------------------------------------Non Champions---------------------------------------------------

-- Calculating average frequency of Non-Champions in 2011
-- Calculating AOV of Non-Champions in 2011
/*
 avg_frequency_non_champ_2011|aov_non_champ_2011|
----------------------------+------------------+
                        2.59|            374.10|
 */
with champions as (
    select distinct CustomerID 
    from (
            select
                CustomerID,
                ntile(5) over ( order by recency desc) as recency_score,
                ntile(5) over (order by frequency asc) as frequency_score,
                ntile(5) over (order by monetary asc) as monetary_score         
            from ( 
            select 
                CustomerID,
                date_part('day',((select max(InvoiceDate) 
                                 from ecommerce_data 
                                 where extract(year from InvoiceDate) = 2011
                                   and CustomerID is not null
                                   and Quantity > 0
                                   )
                                   - max(InvoiceDate)) ) as recency,
                count(distinct InvoiceNO) as frequency,
                sum(Quantity * Price) as monetary
            from ecommerce_data 
            where CustomerID is not null and Quantity > 0 and extract(year from InvoiceDate) = 2011
            group by CustomerID 
            ) as rfm_scores
        ) as scored_customers
    where recency_score >=4 and frequency_score >= 4 and monetary_score >= 5 
),
all_customers_2011 as (
    select distinct CustomerID
    from ecommerce_data
    where extract(year from Invoicedate) = 2011 and CustomerID is not null and Quantity > 0
),
non_champions as (
    select distinct ac.CustomerID
    from all_customers_2011 ac
    left join champions c on ac.CustomerID = c.CustomerID  -- left join is the key
    where c.CustomerID is null
)
select
	round(count(distinct e.InvoiceNo) * 1.0 / count(distinct e.CustomerID) , 2) as avg_frequency_non_champ_2011,
	round(sum(e.Quantity * e.Price) * 1.0 / count(distinct e.InvoiceNo), 2) as aov_non_champ_2011
from non_champions  nc
join ecommerce_data e on nc.CustomerID = e.CustomerID
where extract(year from e.InvoiceDate) = 2011 and e.CustomerID is not null and e.Quantity > 0



-- Non Champion Customers Retention 2010 to 2011
/*
 non_champs_2010|returning_non_champ_2011|pct_non_champ_retention|
---------------+------------------------+-----------------------+
           3653|                    2100|                  57.49|
 */

with champions as (
    -- Defines the list of Champion CustomerIDs based on the 2010 data RFM scores
    select distinct CustomerID 
    from (
            select
                CustomerID,
                ntile(5) over ( order by recency desc) as recency_score,
                ntile(5) over (order by frequency asc) as frequency_score,
                ntile(5) over (order by monetary asc) as monetary_score         
            from ( 
            select 
                CustomerID,
                date_part('day',((select max(InvoiceDate) 
                                 from ecommerce_data 
                                 where extract(year from InvoiceDate) = 2010 
                                   and CustomerID is not null
                                   and Quantity > 0
                                   )
                                   - max(InvoiceDate)) ) as recency,
                count(distinct InvoiceNO) as frequency,
                sum(Quantity * Price) as monetary
            from ecommerce_data 
            where CustomerID is not null and Quantity > 0 and extract(year from InvoiceDate) = 2010
            group by CustomerID 
            ) as rfm_scores
        ) as scored_customers
    where recency_score >=4 and frequency_score >= 4 and monetary_score >= 5 
),
non_champions_2010 as (
    select distinct e.CustomerID
    from ecommerce_data e
    left join champions c on e.CustomerID = c.CustomerID
    where c.CustomerID is null                             -- Because of left join null gives non-champ
    	and extract(year from e.InvoiceDate) = 2010
    	and e.CustomerID is not null 
    	and e.Quantity > 0
),
non_champions_2011 as (
    select distinct nc.CustomerID
    from non_champions_2010 nc
    join ecommerce_data e on nc.CustomerID = e.CustomerID
    where extract(year from e.InvoiceDate) = 2011 and e.CustomerID is not null and e.Quantity > 0
)
select 
    (select count(*) from non_champions_2010) as non_champs_2010,
    count(c10.CustomerID) as returning_non_champ_2011,
    round( count(c10.CustomerID) * 100.0 / (select count(*) from non_champions_2010) , 2) as pct_non_champ_retention
from non_champions_2010 c10
inner join non_champions_2011 c11 on c10.CustomerID = c11.CustomerID;



-- All the results in one Table

select *
from (
    values 
    -- (Customer Group, Avg Order Value, Avg Frequency, Retention %, 	clv )
    ('All',             486.62,     4.06,     62.86,  round(486.62 * 4.06 * (1 / (1 - 0.6286)), 0)),
    ('Champions',       624.54,  13.44,  96.72,       round(624.54 * 13.44 * (1 / (1 - 0.9672)), 0)),
    ('Non-Champions',   374.1, 2.59, 57.49,           round(374.10 * 2.59 * (1 / (1 - 0.5749)), 0))
) as final_metrics("Customer Group", "Avg Order Value (2011)", "Avg Frequency (2011)", "Retention % (2010-2011)", "Estimated CLV");




---------------------------------------- The End ------------------------------


