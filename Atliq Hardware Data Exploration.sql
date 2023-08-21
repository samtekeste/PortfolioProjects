

-- Task 1: generate a report of individual product sales 
-- (aggregated on a monthly basis at the product code level) for Croma India customer for FY = 2021
-- the report should include:
		-- month
		-- product name
		-- variant
		-- sold quantity
		-- gross price per item
		-- gross price total
select
	s.date
,	s.product_code
,	p.product
,	p.variant
,	s.sold_quantity
, 	g.gross_price
,	Round(g.gross_price * s.sold_quantity,2) as gross_price_total
from
	fact_sales_monthly s
join 
	dim_product p
on 
	p.product_code = s.product_code
join 
	fact_gross_price g
on 
	g.product_code = s.product_code and 
    	g.fiscal_year = get_fiscal_year(s.date)
where
	customer_code = '90002002' and
	get_fiscal_year(date) = 2021
order by
	date desc
;
-- Task 2: Generate a report for aggregate monthly gross sales for Croma India customer
-- report should include:
	-- month
    -- total gross sales amount for Croma in India
select
	s.date
,	round(sum(g.gross_price * s.sold_quantity),2) as monthly_gross_sales_amount
from
	fact_sales_monthly s
join
	fact_gross_price g
on 
	g.product_code = s.product_code and
    	g.fiscal_year = get_fiscal_year(s.date)
where
	s.customer_code = 90002002
group by
	s.date
order by
	s.date asc
 ;   
-- Task 3: Generate a report for aggregate yearly gross sales for Croma India customer
-- report should include:
	-- fiscal year
    -- total gross sales amount for Croma in India
select
	get_fiscal_year(s.date) as fiscal_year
,	round(sum(g.gross_price * s.sold_quantity),2) as yearly_gross_sales_amount
from
	fact_sales_monthly s
join
	fact_gross_price g
on
	g.product_code = s.product_code and
   	 g.fiscal_year = get_fiscal_year(s.date)
where
	customer_code = 90002002
group by
	get_fiscal_year(s.date)
order by
	get_fiscal_year(s.date) desc;
    
    
-- Performance Issues
-- Create a fiscal_year column in fact_sales_monthly to reduce fetching time


-- Task 4: Generate a report for top markets, products and customers by fiscal year

-- Subtask 1: determine net_invoice_sales
explain analyze
with cte as (
select
	s.fiscal_year
,	c.market
,	s.product_code
,	p.product
,	p.variant
,	s.sold_quantity
, 	g.gross_price
,	Round(g.gross_price * s.sold_quantity,2) as gross_sales
,	pre_invoice_discount_pct

from
	fact_sales_monthly s
join 
	dim_product p
on 
	p.product_code = s.product_code
join
	dim_customer c
on
	c.customer_code = s.customer_code
join 
	fact_gross_price g
on 
	g.fiscal_year = s.fiscal_year and
	g.product_code = s.product_code 
join
	fact_pre_invoice_deductions pre
on
	s.customer_code = pre.customer_code and
    	pre.fiscal_year = s.fiscal_year
where
	s.fiscal_year = 2021
order by
	date )
	
select
	*
,	round((1-pre_invoice_discount_pct) * gross_sales,2) as net_invoice_sales
from
	cte
;

-- Subtask 2: calculate post invoice deductions
select
	*
,	(1-pre_invoice_discount_pct) * gross_sales as net_invoice_sales
,	discounts_pct + other_deductions_pct as post_invoice_deductions
from
	s_pre_invoice_discount ps
join
	fact_post_invoice_deductions po
on
	po.customer_code = ps.customer_code and
    	po.product_code = ps.product_code and
    	po.date = ps.date
;
-- Subtask 3: Calculate Net Sales

select
	sp.*
,	(1-post_invoice_deductions) * net_invoice_sales as net_sales
from
	s_post_invoice_discount sp
;
-- Find top market by Net Sales

select
	market
,	round(sum(net_sales)/1000000,2) as net_sales_mln
from
	net_sales ns
where
	fiscal_year = 2021
group by
	market
order by
	net_sales_mln desc
limit 5
;

-- write the query for top customers by net sales
select
	c.customer
,	round(sum(net_sales)/1000000,2) as net_sales_mln
from
	net_sales ns
join
	dim_customer c
on 
	ns.customer_code = c.customer_code
where
	fiscal_year = 2021
group by
	customer
order by
	net_sales_mln desc
limit 5
;

-- find top products by net sales
select
	product
,	round(sum(net_sales)/1000000,2) as net_sales_mln
from
	net_sales ns
where
	fiscal_year = 2021
group by
	product
order by
	net_sales_mln desc
limit 5
;
-- Task 4: Generate an aggregate forecast accuracy report for all customers in a given fiscal year
-- the report should include:
	-- customer code, customer, market
    -- total sold quantity
    -- forecast accuracy
    -- net error
    -- absolute error
    -- forecast accuracy %
    
    -- Subtask 1: Create table with sold quantity and forecast quantity
    
    create table facts_actuals_estimates 
    (
		select
			s.date as date
		,	s.fiscal_year as fiscal_year
        ,	s.product_code as product_code
        ,	s.customer_code as customer_code
        ,	s.sold_quantity as sold_quantity
        ,	f.forecast_quantity as forecast_quantity
        from
			fact_sales_monthly s
		left join
			fact_forecast_monthly f
		using (date, customer_code, product_code)
        union
        select
			f.date as date
		,	f.fiscal_year as fiscal_year
        ,	f.product_code as product_code
        ,	f.customer_code as customer_code
        ,	s.sold_quantity as sold_quantity
		,	f.forecast_quantity as forecast_quantity
        from
			fact_forecast_monthly f
		left join
			fact_sales_monthly s
		using(date, customer_code, product_code)
    )
;

update facts_actuals_estimates
set sold_quantity = 0
where sold_quantity is null
; 

update facts_actuals_estimates
set forecast_quantity = 0
where forecast_quantity is null
; 
 -- Generates desired report  
  with fca as (
  
	select
		customer_code
	,	sum(sold_quantity) as sold_quantity
	,	sum(forecast_quantity - sold_quantity) as net_error
	,	sum(forecast_quantity - sold_quantity)*100/ sum(forecast_quantity) as net_error_pct
	,	sum(abs(forecast_quantity - sold_quantity)) as abs_error
	,	sum(abs(forecast_quantity - sold_quantity)*100)/ sum(forecast_quantity) as abs_error_pct
	from
		facts_actuals_estimates
	where
		fiscal_year = 2021
	group by
		customer_code
)
	
    select
		f.*
	,	c.customer
    ,	c.market
    ,	if(abs_error_pct > 100, 0, 100 - abs_error_pct) as forecast_accuracy_pct
    from
		fca f
	join
		dim_customer c
	using(customer_code)
;

-- comparison between 2021 and 2020 forecast accuracy
-- report should include:
	-- customer code, name, market
    -- forecast accuracy (2020,2021)
create temporary table temp1 (
	with fca as (
		select
			customer_code
		,	sum(sold_quantity) as sold_quantity
		,	sum(forecast_quantity - sold_quantity) as net_error
		,	sum(forecast_quantity - sold_quantity)*100/ sum(forecast_quantity) as net_error_pct
		,	sum(abs(forecast_quantity - sold_quantity)) as abs_error
		,	sum(abs(forecast_quantity - sold_quantity)*100)/ sum(forecast_quantity) as abs_error_pct
		from
			facts_actuals_estimates
		where
			fiscal_year = 2021
		group by
			customer_code
)
		select
			f.*
		,	c.customer
		,	c.market
		,	if(abs_error_pct > 100, 0, 100 - abs_error_pct) as forecast_accuracy_pct
		from
			fca f
		join
			dim_customer c
		using(customer_code)
)
 ; 
  create temporary table temp2 (
	with fca2 as (
		select
			customer_code
		,	sum(sold_quantity) as sold_quantity
		,	sum(forecast_quantity - sold_quantity) as net_error
		,	sum(forecast_quantity - sold_quantity)*100/ sum(forecast_quantity) as net_error_pct
		,	sum(abs(forecast_quantity - sold_quantity)) as abs_error
		,	sum(abs(forecast_quantity - sold_quantity)*100)/ sum(forecast_quantity) as abs_error_pct
		from
			facts_actuals_estimates
		where
			fiscal_year = 2020
		group by
			customer_code
	)
	select
			f.*
		,	c.customer
		,	c.market
		,	if(abs_error_pct > 100, 0, 100 - abs_error_pct) as forecast_accuracy_pct
		from
			fca2 f
		join
			dim_customer c
		using
			(customer_code)
		order by
			forecast_accuracy_pct desc
)
  ;
select
	customer_code
,	customer
,	market
,	t.forecast_accuracy_pct as forecast_accuracy_pct_2020
,	te.forecast_accuracy_pct as forecast_accuracy_pct_2021
from
	temp2 t
join
	temp1 te
using
	(customer_code, customer, market)
order by
	forecast_accuracy_pct_2020 desc
        
