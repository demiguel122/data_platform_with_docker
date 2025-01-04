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