select
    'Motion' as `Parter ID`,
    'Auto' as `Product`,
    channel_field as `Agency`,
    case when user_name not like '%motioninsurance.com' then user_name else '' end as `Agent Email`,
    purchase_date as `Quote Date`,
    first_name as `First Name`,
    last_name as `Last Name`,
    state as `State`,
    zip as `Zip Code`,
    `Policy #` as `Policy Reference`,
    purchase_date as `Purchase Date`,
    `EFF DATE` as `Effective Date`,
    case when term_sequence = 1 then 'New' else 'Renewal' end as `Policy Type`,
    `TRANS DATE` as `Payment Date`,
    premium as `Collected Premium`,
    commission_rate as `Commission Rate`,
    ROUND(premium * commission_rate, 2) as `Commission`,
    case when agent_id is not null then 'Agency' else 'Direct' end as `Bind Type`
from
    (
        select
            pnc.*,
            case 
                when pnc.term_sequence > 1 and `trans eff date` < (select date from [zebra_teir] where partner = 'zebra' and cumulative_sum >= 150000 limit 1) then 0.10 
                when pnc.term_sequence > 1 and `trans eff date` > (select date from [zebra_teir] where partner = 'zebra' and cumulative_sum >= 150000 limit 1) then 0.11
                when pnc.term_sequence < 1 and `trans eff date` < (select date from [zebra_teir] where partner = 'zebra' and cumulative_sum >= 150000 limit 1) then 0.11
                when pnc.term_sequence < 1 and `trans eff date` > (select date from [zebra_teir] where partner = 'zebra' and cumulative_sum >= 150000 limit 1) then 0.12      
                else 0.11 
            end as commission_rate,
            least(p2.date_created, p2.date_entered, p2.date_effective) as purchase_date,
            p2.channel_field,
            a.agent_id,
            a.user_name,
            dr.first_name,
            dr.last_name,
            dr.state,
            dr.zip
        from
            [policy_net_collected as pnc]
            join Policy_2 p2 on p2.policy_id = pnc.`policy #` and p2.term_sequence = 1 and p2.endorse_seq = 0 and p2.channel_field like '%zeb%'
            join Link_Table lt on p2.policy_id = lt.policy_id and lt.current_flag = 'y'
            join drivers_rc3 dr on lt.driver_id = dr.driver_id and dr.relationship_to_pni in ('true','self')
            left join agent_portal a on a.agent_id = p2.agent_code
        where
            [pnc.`TRANS DATE`=daterange_no_tz]
            and pnc.`EFF DATE` >= '2021-01-01'
    ) as p
order by
    `Payment Date` desc

