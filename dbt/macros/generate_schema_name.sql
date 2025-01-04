-- This macro is intended to override the "target_schema" specified in the profiles.yml file
-- If the target is "pro", every model will be materialized in the "<directory_name>" schema within the "pro" database. For instance: a model located in the "dbt/models/silver" directory will be materialized in the schema "pro.silver"
-- If the target is "dev", every model will be materialized in the "<user>_<directory_name>" shcema within the "dev" database. For instance: a model located in the "dbt/models/silver" directory will be materialized in the schema "dev.<user>_silver"

{% macro generate_schema_name(custom_schema_name, node) %}
  {% set user = target.user %}
  {% set environment = target.name %}
  
  {% set node_path = node.path %}
  {% set path_parts = node_path.split('/') %}
  {% set node_dir = path_parts[-2] %}
  
  {% if environment == 'pro' %}
    {{ node_dir }}
  {% else %}
    {{ user ~ '_' ~ node_dir | trim }}
  {% endif %}
  
{% endmacro %}