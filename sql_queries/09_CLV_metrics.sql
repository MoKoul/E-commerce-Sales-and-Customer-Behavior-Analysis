

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

-------------------------------------------------------------------------------------------------------------
-- All the results in one Table

select *
from (
    values 
    -- (Customer Group, Avg Order Value, Avg Frequency, Retention %, 	clv )
    ('All',             486.62,     4.06,     62.86,  round(486.62 * 4.06 * (1 / (1 - 0.6286)), 0)),
    ('Champions',       624.54,  13.44,  96.72,       round(624.54 * 13.44 * (1 / (1 - 0.9672)), 0)),
    ('Non-Champions',   374.1, 2.59, 57.49,           round(374.10 * 2.59 * (1 / (1 - 0.5749)), 0))
) as final_metrics("Customer Group", "Avg Order Value (2011)", "Avg Frequency (2011)", "Retention % (2010-2011)", "Estimated CLV");




