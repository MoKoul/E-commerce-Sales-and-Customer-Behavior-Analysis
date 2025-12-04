
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





