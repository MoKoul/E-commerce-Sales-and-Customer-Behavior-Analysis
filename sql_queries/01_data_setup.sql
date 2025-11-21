/*
Dataset description:
The dataset used in this analysis is the Online Retail II dataset from the UCI Machine Learning Repository. 
It contains transactional data collected from a UK-based, online retail company over 
two years (December 1, 2009 to December 9, 2011). 

This analysis applies RFM (Recency, Frequency, Monetary) analysis for customer segmentation. 
RFM is a marketing technique that segments customers based on how recently they purchased (Recency), 
how often they purchase (Frequency), and how much they spend (Monetary value).
Using these metrics, customers will be grouped to identify valuable and loyal segments for targeted marketing strategies.
Additionally, seasonal trend analysis will be conducted to identify patterns and 
fluctuations in sales over time, such as monthly or quarterly seasonality.
Finally Performed cohort analysis to examine customer retention rates and behaviors over time.
*/


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




