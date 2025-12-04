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



