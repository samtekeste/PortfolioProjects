-- Task 1: Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region --
select
	c.market
from
	dim_customer c
where
	customer = 'Atliq Exclusive' and
    region = 'APAC'
;    
-- Task 2: What is the percentage of unique product increase in 2021 vs 2020? The final output should contain:
			-- unique products 2020
            -- unique products 2021
            -- percentage change
with temp as (
	select
		year(s.date) as year
	,	count(distinct(s.product_code)) as unique_product_2020
	from
		fact_sales_monthly s
	group by
		year(s.date)
	having
		year = 2020
),
temp2 as (
	select
		year(s.date) as year
	,	count(distinct(s.product_code)) as unique_product_2021
	from
		fact_sales_monthly s
	group by
		year(s.date)
	having
		year = 2021
)

select
	t.unique_product_2020
,	te.unique_product_2021
,	round((te.unique_product_2021 - t.unique_product_2020)/t.unique_product_2020 * 100,2) as percent_change
from
	temp t
cross join
	temp2 te
;
-- Task 3: Provide a report with all the unqiue product counts each segment and sort them in descending order of product counts. 
-- The final output should contain:
				-- segment
                -- product_count
select
	p.segment
,	count(distinct(p.product_code)) as product_count
from
	dim_product p
group by
	p.segment
order by
	product_count desc
;
    
 -- Task 4: Follow Up on Task 2. Which segment had the most increase in unique products in 2021 vs 2020. The final output contains:
			-- segment
			-- product_count_2020
			-- product_count_2021
			-- difference
with pc20 as (
	select
		year(s.date) as year
	,	p.segment
	,	count(distinct(s.product_code)) as unique_product_2020
	from
		fact_sales_monthly s
	join
		dim_product p
	using
		(product_code)
	group by
		year(s.date)
	,	p.segment
	having
		year = 2020
),
	pc21 as (
	select
		year(s.date) as year
	,	p.segment
	,	count(distinct(s.product_code)) as unique_product_2021
	from
		fact_sales_monthly s
	join
		dim_product p
	using 
		(product_code)
	group by
		year(s.date)
	,	p.segment
	having
		year = 2021
)
	select
		p.segment
	,	p.unique_product_2020 as product_count_2020
    ,	pc.unique_product_2021 as product_count_2021
    ,	pc.unique_product_2021 - p.unique_product_2020 as difference
	from
		pc20 p
	join
		pc21 pc
	using
		(segment)
	order by
		difference desc
;	
	
 -- Task 5: Get the products that have the highest and lowest manufacturing costs. Results should include:
			-- product_code
            -- product
            -- manufacturing_cost
        select
            p.product_code
		,	p.product
        ,	m.manufacturing_cost
        from
			dim_product p
		join
			fact_manufacturing_cost m
		using
        (product_code)
        where
			(
				select
					max(manufacturing_cost)
				from
					fact_manufacturing_cost
			) = manufacturing_cost 
            or
            (
				select
					min(manufacturing_cost)
				from
					fact_manufacturing_cost
				) = manufacturing_cost
	;
-- Task 6: Generate a report which contains the top 5 customers who recieved an average high pre_invoice_discount_pct 
-- for the fiscal year 2021 and in the Indian market. The final output should contain:
			-- customer_code
            -- customer
            -- average_discount_percentage
select
	c.customer_code
,	c.customer
,	avg(pi.pre_invoice_discount_pct) as average_discount_pct
from
	dim_customer c
join
	fact_pre_invoice_deductions pi
using
	(customer_code)
where
	pi.fiscal_year = 2021 and
    c.market = 'India'
group by
	c.customer_code
,	c.customer
order by
	average_discount_pct desc
limit 5
;

-- Task 7: Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions. The final report should contain:
			-- Month
			-- Year
			-- Gross sales Amount
select
	s.date
,	sum(s.sold_quantity * g.gross_price) as gross_sales_amount
from
	fact_sales_monthly s
join
	dim_customer c
using
	(customer_code)
join
	fact_gross_price g
using
	(product_code, fiscal_year)
where
	customer = 'Atliq Exclusive'
group by
	s.date
order by
	s.date asc
;
-- Task 8: In which quarter of 2020, got the maximum total_sold_quantity? The final output should contain:
		-- Quarter
		-- total_sold_quantity
        
select
	case
		when month(date) in (9,10,11) then 1
        when month(date) in(12,1,2) then 2
        when month(date) in(3,4,5) then 3
        else 4
	end as quarter
,	sum(s.sold_quantity) as total_sold_quantity
from
	fact_sales_monthly s
where
	year(date) = 2020
group by
	quarter
order by
	total_sold_quantity desc
;
-- Task 9: Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
-- The final output contains these fields:
		-- channel
		-- gross_sales_mln
		-- percentage
with gsc as (	
    select
		c.channel
	,	sum(s.sold_quantity * g.gross_price)/1000000 as gross_sales_mln
	from
		dim_customer c
	join
		fact_sales_monthly s
	using
		(customer_code)
	join
		fact_gross_price g
	using
		(product_code)
	where 
		s.fiscal_year = 2021
	group by
		c.channel
	)
    select
		gs.channel
	,	round(gs.gross_sales_mln,2) as gross_sales_mln
    ,	round(gs.gross_sales_mln * 100/sum(gs.gross_sales_mln) over(),2) as percentage
    from
		gsc gs		
;
-- Task 10: Get the Top 3 Products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
-- The final output contains these:
			-- division
			-- product_code
            -- product
			-- total_sold_quantity
			-- rank_order
with wrank as (
	select
		p.division
	,	p.product_code
	,	p.product
	,	sum(s.sold_quantity) as total_sold_quantity
	,	rank () over(partition by division order by sum(s.sold_quantity) desc)  as rn
	from
		dim_product p
	join
		fact_sales_monthly s
	using	
		(product_code)
	where
		s.fiscal_year = 2021
	group by
		p.division
	,	p.product_code
	,	p.product
)
select
	*
from
	wrank
where
	rn <= 3
	