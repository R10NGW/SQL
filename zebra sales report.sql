select 
  'Auto' AS `Policy Type`
  ,date_format(least(p.date_created, p.date_entered, p.date_effective), '%m/%d/%Y') AS `Quote Date`
  ,date_format(p.date_effective, '%m/%d/%Y') AS `Policy Effective Date`
  ,date_format((select min(date(payment_collections_date)) from Recurring_Schedule_cc where policy_id = p.policy_id), '%m/%d/%Y') AS `Purchase Date`
  ,p.policy_id AS `Policy Number`
  ,d.state AS `State`
  ,d.zip AS `Zipcode`
 ,case 
    when d.coverage_source = case when least(p.date_created, p.date_entered, p.date_effective) between '2020-08-01' and '9999-12-31' then 'the zebra'          
    else 'both' end and d.carrierid <> '' then 'TRUE' else 'FALSE' 
  end AS `Currently Insured`
  ,case when cr.channel_referrence_id = '' or cr.channel_referrence_id is null then zri.channel_referrence_id else cr.channel_referrence_id end AS `Carrier Quote Reference ID`
  ,null as `Payout`
  ,case 
    when d.homeowner = 'Rent' then 'Renter'
    when d.homeowner in ('Y', 'YES', 'Own home', 'true', 'Own Manufactured/ Mobile', 'Own Manufactured/Mobile H') then 'Homeowner'
    when d.homeowner = 'Own Condominium' then 'Condo Owner'
    else 'Other'      
  end as `Home Ownership`
  ,'TRUE' as `Bind Online`
  ,case when coalesce(nullif(nullif(max(v.comp_limit), ''), 'declined'), nullif(nullif(max(v.coll_limit), ''), 'declined')) is not null then 'TRUE' else 'FALSE' end AS `FULL COVERAGE`
  ,count(distinct v.vin) as `Number of Vehicles`
  ,p.rate AS `Premium`
  ,coalesce(nullif(p.policy_terms, ''), nullif(p.policy_tenure, ''), 6) AS `Policy Term`
  ,case
    when v.bi_limit = '100/300' then '100000/300000'
    when v.bi_limit = '50/100' then '50000/100000'
    when v.bi_limit = '15/30' then '15000/30000'
    when v.bi_limit = '25/65' then '25000/65000'
    when v.bi_limit = '25/50' then '25000/50000'
    when v.bi_limit = '250/500' then '250000/500000'
  end as `Liability Limits`
  ,case when record_type = 'cancel' then nullif(date_format(p.cancellation_date, '%m/%d/%Y'), '00/00/0000') end AS `Cancellation Date`
  ,case when record_type = 'cancel' then p.cancel_reason end AS `Cancellation Reason`
  ,case when agent_code = '0' then null when agent_code = 'none' then null when agent_code like 'zeb%' then null else agent_code end as `Agent Id`
  ,motionauto_transaction_id
from
  (
    select 
      'bind' as record_type
      ,Policy_2.* 
    from 
      Policy_2 
    where 
      current_flag = 'Y' 
      and test_flag = 'N' 
      and active <> 'quote' 
      and channel_field like '%zebra%' 
      and term_sequence = 1
      and [least(date_created, date_entered,date_effective)=daterange_no_tz]   
      and agent_code not like 'zeb%'
    union all
    select 
      'cancel'
      ,Policy_2.* 
    from 
      Policy_2 
    where 
      current_flag = 'Y' 
      and test_flag = 'N' 
      and active = 'cancelled' 
      and channel_field = 'The Zebra' 
      and term_sequence = 1
      and datediff(cancellation_date, least(date_created, date_entered,date_effective)) < 31 
      and [cancellation_date=daterange_no_tz]   
      and agent_code not like 'zeb%'
  ) as p
  join Link_Table l on l.policy_id = p.policy_id and l.current_flag = 'y'
  join drivers_rc3 d on l.driver_id = d.driver_id and d.relationship_to_pni in ('true', 'self')
  join vehicles_rc3 v on v.vin = l.vin
  join channel_lookup cl on cl.channel_id = p.channel_field
  left join [zebra_reference_ids as zri] on zri.policy_id = p.policy_id
  left join 
    (
      select distinct
        policy_id
        ,channel_referrence_id 
      from 
        Policy_2
      where 
        channel_referrence_id <> ''
        and policy_id <> ''
        and channel_field like '%zeb%'
        and channel_referrence_id not like '%mot%'
      ) as cr on cr.policy_id = p.policy_id
group by
  `Policy Type`
  ,`Quote Date`
  ,`Policy Effective Date`
  ,`Purchase Date`
  ,`Policy Number`
  ,`State`
  ,`Zipcode`
  ,`Currently Insured`
  ,`Carrier Quote Reference ID`
  ,`Home Ownership`
  ,`Premium`
  ,`Policy Term`
  ,`Liability Limits`
  ,`Prior Carrier BI Limits`
  ,`Cancellation Date`
  ,`Cancellation Reason`
  ,`Agent Id`
order by
  p.date_effective desc