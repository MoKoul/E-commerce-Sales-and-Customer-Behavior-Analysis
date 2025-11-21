
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


