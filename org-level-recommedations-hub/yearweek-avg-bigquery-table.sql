# This is a bigquery script designed to be used in Data Studio to properly display the data.
# Keep in mind this script is currently under development, and probably is not optimized or in a final state. 
# The reason this script was created is because I wanted to display the sum of potential cost savings over time per project_id
# It was easier to compute this in bigquery with SQL then make Datastudio display the informatino
# Known issues:
# Currently we dont handle additional currencies well.
# Some project names are missing
### *** Final Select ***
select 
  project_name,
  project_id,
  asset_type,
  name as recommender_name,
  location,
  recommender_subtype,
  date_week,
  primary_impact.category as impact_category,
  # As the cost savings can potentially change over time, we should grab the average of that timeframe
  ABS(AVG(primary_impact.cost_projection.cost.units)) as impact_avg_cost_unit,
  primary_impact.cost_projection.cost.currency_code as impact_currency_code,
  state as recommender_state,
  ARRAY_AGG(distinct folder_id ignore nulls) as folder_ids
  ## *** Query to extract date_week for aggregation, and joining assest inventory ***
  from (
    select * except(associated_insights, target_resources),
    format_date('%Y%W', last_refresh_time) as date_week,
    from `finOps.recommendations_export` as r
    #Cross join will remove nulls, and in our case we still need nulls
    left join unnest(ancestors.folder_ids) as folder_id
    left join  (
      select 
      REGEXP_EXTRACT(name, r'/([^/]+)/?$') as project_name,
      REGEXP_EXTRACT(ancestor,  r'/([^/]+)/?$') as project_id,
      asset_type from 
      (select * from `finOps.cloudAssets` 
      cross join unnest(ancestors) as ancestor
      where asset_type in ("compute.googleapis.com/Project")
      and ancestor like "projects/%")
    ) as a
    on r.cloud_entity_id = a.project_id
  )
  group by 1,2,3,4,5,6,7,8,10,11
  order by recommender_name