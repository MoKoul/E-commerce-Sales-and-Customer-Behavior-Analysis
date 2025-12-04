


/*  
RFM (Recency, Frequency, Monetary) analysis on customers in the ecommerce_data table. 
Segmenting customers based on their purchase history into categories such 
as Champions, Loyal, Potential Loyalist, New Customers, At Risk  
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
            when recency_score >= 4 and frequency_score >=2 and monetary_score >= 0 then 'Potential Loyalist'
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

