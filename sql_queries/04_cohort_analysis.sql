

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


